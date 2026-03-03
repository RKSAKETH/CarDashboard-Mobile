import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ── Tyre state model ──────────────────────────────────────────────────────────

enum TireStatus { healthy, low, flat }

class TireData {
  final String id;       // 'TIRE_FL' etc.
  final String label;    // 'Front Left' etc.
  final int    rssi;
  final TireStatus status;
  final double pressure;

  const TireData({
    required this.id,
    required this.label,
    required this.rssi,
    required this.status,
    required this.pressure,
  });

  TireData copyWith({int? rssi, TireStatus? status, double? pressure}) =>
      TireData(
        id: id, label: label,
        rssi:     rssi     ?? this.rssi,
        status:   status   ?? this.status,
        pressure: pressure ?? this.pressure,
      );

  /// 0-100% bar. Maps RSSI -95..-40 → 0..100.
  int get signalPercent {
    if (status == TireStatus.flat) return 0;
    return ((rssi + 95) / 55 * 100).clamp(0, 100).toInt();
  }
}

// ── Constants ─────────────────────────────────────────────────────────────────

const int _rssiHealthy = -70; // ≥ → Green  32 PSI
const int _rssiLow     = -85; // ≥ → Yellow proportional PSI
//                              <  → Red     0 PSI

const double _psiHealthy = 32.0;
const double _psiFlat    =  0.0;

/// SHORT scan window so Android clears its result-cache on every restart.
/// This is the KEY fix for fast disconnect detection:
/// once the scan restarts, stale (disconnected) devices are gone immediately.
const Duration _scanWindow       = Duration(seconds: 2);
const Duration _scanPause        = Duration(milliseconds: 150);

/// How long a tyre can go unseen before it's declared flat.
/// Must be slightly longer than one scan cycle (_scanWindow + _scanPause).
const Duration _lostTimeout      = Duration(seconds: 3);

/// Watchdog polling interval.
const Duration _watchdogInterval = Duration(milliseconds: 400);

/// All four monitored tyre names.
const List<String> _tyreIds = ['TIRE_FL', 'TIRE_FR', 'TIRE_RL', 'TIRE_RR'];

const Map<String, String> _tyreLabels = {
  'TIRE_FL': 'Front Left',
  'TIRE_FR': 'Front Right',
  'TIRE_RL': 'Rear Left',
  'TIRE_RR': 'Rear Right',
};

// ── TPMS Service ──────────────────────────────────────────────────────────────

class TpmsService {
  static final TpmsService instance = TpmsService._();
  TpmsService._();

  bool _initialised = false;

  // ── Per-tyre public notifiers ─────────────────────────────────────────────
  final ValueNotifier<TireData> flNotifier =
      ValueNotifier(_initial('TIRE_FL'));
  final ValueNotifier<TireData> frNotifier =
      ValueNotifier(_initial('TIRE_FR'));
  final ValueNotifier<TireData> rlNotifier =
      ValueNotifier(_initial('TIRE_RL'));
  final ValueNotifier<TireData> rrNotifier =
      ValueNotifier(_initial('TIRE_RR'));

  final ValueNotifier<bool>   isScanning = ValueNotifier(false);
  final ValueNotifier<bool>   btOn       = ValueNotifier(false);
  final ValueNotifier<String> statusText =
      ValueNotifier('Tap TPMS to start monitoring…');

  // ── Internal ─────────────────────────────────────────────────────────────
  /// Timestamp of the last seen scan result for each tyre.
  final Map<String, DateTime> _lastSeen = {};

  StreamSubscription<List<ScanResult>>?      _resultSub;
  StreamSubscription<bool>?                  _isScanSub;
  StreamSubscription<BluetoothAdapterState>? _btStateSub;
  Timer? _cycleTimer;
  Timer? _watchdogTimer;

  // Helper: get notifier by id
  ValueNotifier<TireData> _notifier(String id) => switch (id) {
        'TIRE_FL' => flNotifier,
        'TIRE_FR' => frNotifier,
        'TIRE_RL' => rlNotifier,
        _         => rrNotifier,
      };

  static TireData _initial(String id) => TireData(
        id: id, label: _tyreLabels[id]!,
        rssi: -100, status: TireStatus.flat, pressure: _psiFlat,
      );

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialised) return;
    _initialised = true;

    // Bluetooth adapter state — instant response when dashboard phone's BT changes
    _btStateSub = FlutterBluePlus.adapterState.listen((state) {
      final on = state == BluetoothAdapterState.on;
      btOn.value = on;
      if (on) {
        statusText.value = 'Scanning for tyre monitors…';
        _startAll();
      } else {
        // Dashboard phone's own BT turned off → all tyres flat immediately
        statusText.value = 'Bluetooth OFF — tyres unmonitored';
        _stopAll();
        _markAllFlat();
      }
    });

    _isScanSub = FlutterBluePlus.isScanning.listen((v) => isScanning.value = v);

    // Subscribe ONCE to the raw scan results stream
    _resultSub = FlutterBluePlus.scanResults.listen(_onResults);

    // Kick off if BT is already on
    final cur = await FlutterBluePlus.adapterState.first;
    if (cur == BluetoothAdapterState.on) {
      btOn.value = true;
      statusText.value = 'Scanning for tyre monitors…';
      _startAll();
    }
  }

  void stopMonitoring() {
    _stopAll();
    _resultSub?.cancel();
    _isScanSub?.cancel();
    _btStateSub?.cancel();
    _resultSub = null;
    _isScanSub = null;
    _btStateSub = null;
    _initialised = false;
  }

  // ── Scan cycle ────────────────────────────────────────────────────────────

  void _startAll() {
    _startWatchdog();
    _doScan();
  }

  void _stopAll() {
    _cycleTimer?.cancel();
    _watchdogTimer?.cancel();
    _cycleTimer    = null;
    _watchdogTimer = null;
    try {
      if (FlutterBluePlus.isScanningNow) FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  Future<void> _doScan() async {
    try {
      // Stop any running scan first.
      // This CLEARS the scanResults cache in flutter_blue_plus,
      // which is the KEY mechanism for fast disconnect detection.
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      await Future.delayed(_scanPause);

      debugPrint('[TPMS] → startScan (2 s window)');
      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidUsesFineLocation: false,
        timeout: _scanWindow,
      );

      // Schedule next cycle
      _cycleTimer?.cancel();
      _cycleTimer = Timer(
        _scanWindow + _scanPause + const Duration(milliseconds: 100),
        _doScan,
      );
    } catch (e) {
      debugPrint('[TPMS] startScan error: $e');
      statusText.value = 'Scan error — retrying…';
      _cycleTimer = Timer(const Duration(seconds: 3), _doScan);
    }
  }

  // ── Watchdog – checks every 400 ms ───────────────────────────────────────

  void _startWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(_watchdogInterval, (_) {
      _checkTimeouts();
    });
  }

  // ── Scan results handler ──────────────────────────────────────────────────

  void _onResults(List<ScanResult> results) {
    final now = DateTime.now();
    final seenIds = <String>{};

    for (final r in results) {
      final name = r.device.platformName.isNotEmpty
          ? r.device.platformName
          : r.advertisementData.advName;

      debugPrint('[TPMS] device: "$name"  rssi: ${r.rssi}');

      if (!_tyreIds.contains(name)) continue;

      // ── Only update THIS specific tyre ──────────────────────────────────
      seenIds.add(name);
      _lastSeen[name] = now;
      _updateTyre(name, r.rssi);
    }

    // Status line
    if (seenIds.isNotEmpty) {
      statusText.value = 'Live: ${seenIds.join(' · ')}';
    } else {
      final connected = _tyreIds
          .where((id) => _notifier(id).value.status != TireStatus.flat)
          .toList();
      if (connected.isNotEmpty) {
        statusText.value = 'Monitoring: ${connected.join(' · ')}';
      } else {
        statusText.value = 'Scanning… (open Tire Monitor on tyre phones)';
      }
    }
  }

  // ── Per-tyre RSSI → PSI mapping ───────────────────────────────────────────

  void _updateTyre(String id, int rssi) {
    final TireStatus status;
    final double pressure;

    if (rssi >= _rssiHealthy) {
      status   = TireStatus.healthy;
      pressure = _psiHealthy;
    } else if (rssi >= _rssiLow) {
      final t = ((rssi - _rssiLow) / (_rssiHealthy - _rssiLow))
          .clamp(0.0, 1.0);
      pressure = _psiFlat + t * (_psiHealthy - _psiFlat);
      status   = TireStatus.low;
    } else {
      status   = TireStatus.flat;
      pressure = _psiFlat;
    }

    _setTyre(id, rssi: rssi, status: status, pressure: pressure);
  }

  // ── Timeout check ─────────────────────────────────────────────────────────

  void _checkTimeouts() {
    final now = DateTime.now();
    for (final id in _tyreIds) {
      final last = _lastSeen[id];
      // Never seen OR not seen within lostTimeout → mark flat
      final lost = last == null || now.difference(last) > _lostTimeout;
      if (lost) {
        final n = _notifier(id);
        if (n.value.status != TireStatus.flat) {
          debugPrint('[TPMS] $id timed out → Flat');
          _setTyre(id, rssi: -100, status: TireStatus.flat, pressure: _psiFlat);
        }
      }
    }
  }

  void _markAllFlat() {
    for (final id in _tyreIds) {
      _setTyre(id, rssi: -100, status: TireStatus.flat, pressure: _psiFlat);
    }
    _lastSeen.clear();
  }

  void _setTyre(
    String id, {
    required int rssi,
    required TireStatus status,
    required double pressure,
  }) {
    final n = _notifier(id);
    final cur = n.value;
    if (cur.status == status && cur.rssi == rssi) return;
    n.value = cur.copyWith(rssi: rssi, status: status, pressure: pressure);
  }
}
