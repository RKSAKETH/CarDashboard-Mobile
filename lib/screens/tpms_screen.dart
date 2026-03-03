import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/tpms_service.dart';
import '../services/ambient_light_service.dart';
import '../widgets/ambient_light_overlay.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TPMS colour palette — NO green / red / orange
//  lx > 10  →  blue mono   |   lx ≤ 10 (LightMode.night)  →  purple mono
// ─────────────────────────────────────────────────────────────────────────────

class _TpmsColors {
  final Color healthy; // bright active — all tyres good
  final Color low;     // dimmer active  — signal weak
  final Color flat;    // near-off       — pulsing makes it alarming
  const _TpmsColors({required this.healthy, required this.low, required this.flat});

  Color forStatus(TireStatus s) => switch (s) {
        TireStatus.healthy => healthy,
        TireStatus.low     => low,
        TireStatus.flat    => flat,
      };
}

// lx > 10 — electric cyan-blue
const _blueColors = _TpmsColors(
  healthy: Color(0xFF00C2FF), // electric cyan-blue
  low:     Color(0xFF0077CC), // mid blue
  flat:    Color(0xFF0D2035), // dark blue (near-off) — pulse shows alarm
);

// lx ≤ 10 — violet-purple
const _purpleColors = _TpmsColors(
  healthy: Color(0xFFBF5FFF), // bright violet
  low:     Color(0xFF7B35CC), // mid purple
  flat:    Color(0xFF200C35), // dark purple (near-off) — pulse shows alarm
);

// ─────────────────────────────────────────────────────────────────────────────
//  TPMS Screen  –  dual mode: Dashboard OR Tire Monitor
// ─────────────────────────────────────────────────────────────────────────────

class TpmsScreen extends StatefulWidget {
  const TpmsScreen({super.key});

  @override
  State<TpmsScreen> createState() => _TpmsScreenState();
}

class _TpmsScreenState extends State<TpmsScreen>
    with TickerProviderStateMixin {
  final _svc        = TpmsService.instance;
  final _peripheral = FlutterBlePeripheral();

  // ── mode: 0 = Dashboard, 1 = Tire Monitor ──────────────────────────────
  int  _mode         = 0;
  bool _advertising  = false;
  String _selectedTire = 'TIRE_FL'; // which tyre this phone broadcasts as

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  // Debug radar
  final List<String> _nearbyLog = [];
  bool _showDebug = false;

  // Lux polling timer — ensures build() re-runs frequently so the raw
  // lux value (lux ≤ 10 → purple, lux > 10 → blue) is always current.
  Timer? _luxTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    // Poll light sensor every 500 ms so the 10 lx boundary is caught promptly
    _luxTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    _requestPermsAndStart();
  }

  Future<void> _requestPermsAndStart() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
    ].request();

    await _svc.init();

    FlutterBluePlus.scanResults.listen((results) {
      if (!mounted) return;
      setState(() {
        _nearbyLog.clear();
        for (final r in results) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName.isNotEmpty
                  ? r.advertisementData.advName
                  : r.device.remoteId.str;
          _nearbyLog.add('$name  (${r.rssi} dBm)');
        }
        _nearbyLog.sort();
      });
    });
  }

  @override
  void dispose() {
    _luxTimer?.cancel();
    _pulseController.dispose();
    if (_advertising) _peripheral.stop();
    super.dispose();
  }

  // ── BLE Advertising ────────────────────────────────────────────────────────

  Future<void> _startAdvertising() async {
    try {
      await _peripheral.start(
        advertiseData: AdvertiseData(
          // includeDeviceName broadcasts whatever name is set in BT settings
          includeDeviceName: true,
          includePowerLevel: true,
          // Use a fixed service UUID so the dashboard can optionally filter
          serviceUuid: '0000180F-0000-1000-8000-00805F9B34FB',
        ),
        advertiseSettings: AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeBalanced,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: false,
          timeout: 0, // 0 = advertise indefinitely
        ),
      );
      if (mounted) setState(() => _advertising = true);
    } catch (e) {
      debugPrint('[TPMS] Advertise error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not start advertising: $e'),
            backgroundColor: const Color(0xFFFF453A),
          ),
        );
      }
    }
  }

  Future<void> _stopAdvertising() async {
    await _peripheral.stop();
    if (mounted) setState(() => _advertising = false);
  }

  void _switchMode(int mode) {
    if (mode == _mode) return;
    if (_advertising) _stopAdvertising();
    if (mode == 0) {
      _svc.init(); // re-init scanner if needed
    }
    setState(() => _mode = mode);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final lightMode  = AmbientLightProvider.of(context); // triggers rebuild on mode change
    // Read raw lux for the exact 10 lx threshold the user specified.
    // LightMode changes are used only for bg/text colours (structural palette).
    final lux        = AmbientLightService.instance.currentLux;
    // lx > 10  → blue    |    lx ≤ 10  → purple
    final tpmsColors = lux <= 200 ? _purpleColors : _blueColors;
    final accent     = tpmsColors.healthy;  // blue or purple — never green/orange
    final bg         = LightThemePalette.background(lightMode);
    final textPri    = LightThemePalette.textPrimary(lightMode);
    final textSec    = LightThemePalette.textSecondary(lightMode);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        title: Text('Tyre Monitor (TPMS)',
            style: TextStyle(
                color: textPri, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          if (_mode == 0) ...[
            IconButton(
              icon: Icon(Icons.radar,
                  color: _showDebug ? const Color(0xFFFFD60A) : textSec),
              tooltip: 'Nearby BT devices',
              onPressed: () => setState(() => _showDebug = !_showDebug),
            ),
            // Scan indicator
            ValueListenableBuilder<bool>(
              valueListenable: _svc.isScanning,
              builder: (_, scanning, c2) => Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scanning ? accent : Colors.grey,
                      boxShadow: scanning
                          ? [BoxShadow(
                              color: accent.withAlpha(140),
                              blurRadius: 6)]
                          : [],
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(scanning ? 'Scanning' : 'Idle',
                      style: TextStyle(color: textSec, fontSize: 11)),
                ]),
              ),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Mode toggle ─────────────────────────────────────────────────
            _buildModeToggle(accent, bg, textPri),
            const SizedBox(height: 8),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
              child: _mode == 0
                  ? _buildDashboardMode(accent, bg, textPri, textSec, tpmsColors)
                  : _buildTireMode(accent, bg, textPri, textSec),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mode toggle ────────────────────────────────────────────────────────────

  Widget _buildModeToggle(Color accent, Color bg, Color textPri) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Row(
        children: [
          _modeTab(0, Icons.speed_rounded, 'Dashboard', accent),
          _modeTab(1, Icons.sensors_rounded, 'Tire Monitor', accent),
        ],
      ),
    );
  }

  Widget _modeTab(int idx, IconData icon, String label, Color accent) {
    final selected = _mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withAlpha(30) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: selected
                ? Border.all(color: accent.withAlpha(80))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? accent : Colors.white54),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: selected ? accent : Colors.white54,
                    fontSize: 13,
                    fontWeight: selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DASHBOARD MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDashboardMode(
      Color accent, Color bg, Color textPri, Color textSec,
      _TpmsColors tpmsColors) {
    return Column(
      children: [
        // Status banner
        _buildStatusBanner(accent, textSec),
        // Debug radar
        if (_showDebug) _buildDebugPanel(textSec),
        const SizedBox(height: 8),
        // 4-tyre view — AnimatedBuilder listens to ALL 4 notifiers
        // so any individual tyre change triggers a rebuild
        Expanded(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _svc.flNotifier,
              _svc.frNotifier,
              _svc.rlNotifier,
              _svc.rrNotifier,
            ]),
            builder: (context, child) {
              final fl = _svc.flNotifier.value;
              final fr = _svc.frNotifier.value;
              final rl = _svc.rlNotifier.value;
              final rr = _svc.rrNotifier.value;
              return Column(children: [
                // Car diagram — each corner its own colour
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: _CarPainter(
                      flStatus: fl.status,
                      frStatus: fr.status,
                      rlStatus: rl.status,
                      rrStatus: rr.status,
                      colors: tpmsColors,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 12),
                // 2×2 cards
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.1,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _TyreCard(data: fl, pulseAnim: _pulseAnim, colors: tpmsColors),
                        _TyreCard(data: fr, pulseAnim: _pulseAnim, colors: tpmsColors),
                        _TyreCard(data: rl, pulseAnim: _pulseAnim, colors: tpmsColors),
                        _TyreCard(data: rr, pulseAnim: _pulseAnim, colors: tpmsColors),
                      ],
                    ),
                  ),
                ),
                // Signal bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 4),
                  child: _SignalRow(tire: fl, textSec: textSec, colors: tpmsColors),
                ),
              ]);
            },
          ),
        ),
        _buildLegend(textSec),
        const SizedBox(height: 10),
        _buildDashboardTip(textSec),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildStatusBanner(Color accent, Color textSec) {
    return ValueListenableBuilder<String>(
      valueListenable: _svc.statusText,
      builder: (_, status, c2) {
        final isAlert = status.contains('⚠️') || status.contains('lost');
        final c = isAlert ? const Color(0xFFFF453A) : accent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: c.withAlpha(isAlert ? 30 : 15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withAlpha(80)),
          ),
          child: Row(children: [
            Icon(
              isAlert
                  ? Icons.warning_amber_rounded
                  : Icons.bluetooth_searching,
              color: c,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(status,
                    style: TextStyle(color: c, fontSize: 12))),
          ]),
        );
      },
    );
  }

  Widget _buildDebugPanel(Color textSec) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: const Color(0xFFFFD60A).withAlpha(70)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.radar, color: Color(0xFFFFD60A), size: 13),
          const SizedBox(width: 6),
          Text('Nearby BT (${_nearbyLog.length})',
              style: const TextStyle(
                  color: Color(0xFFFFD60A),
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('TIRE_FL should appear GREEN',
              style: TextStyle(color: textSec, fontSize: 9)),
        ]),
        const SizedBox(height: 6),
        if (_nearbyLog.isEmpty)
          Text('No BLE devices seen yet…',
              style: TextStyle(color: textSec, fontSize: 11))
        else
          ...(_nearbyLog.take(10).map((d) {
            final isT = d.startsWith('TIRE_');
            return Text(d,
                style: TextStyle(
                  color: isT ? const Color(0xFF00FF88) : textSec,
                  fontSize: 11,
                  fontWeight:
                      isT ? FontWeight.bold : FontWeight.normal,
                ));
          })),
      ]),
    );
  }

  Widget _buildLegend(Color textSec) {
    const items = [
      (Color(0xFF00FF88), 'Good 32 PSI'),
      (Color(0xFFFFD60A), 'Low'),
      (Color(0xFFFF453A), 'Flat'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        final (color, label) = item;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: color,
                boxShadow: [
                  BoxShadow(color: color.withAlpha(80), blurRadius: 4)
                ],
              ),
            ),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: textSec, fontSize: 10)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _buildDashboardTip(Color textSec) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Text(
        '📡  Each tyre phone: open app → Tire Monitor tab → pick position → Start\n'
        '✅  Each tyre turns GREEN only when its own phone is broadcasting\n'
        '🔴  Turning off a tyre phone only flattens THAT tyre (others stay green)',
        style: TextStyle(color: textSec, fontSize: 11, height: 1.6),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TIRE MONITOR MODE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTireMode(
      Color accent, Color bg, Color textPri, Color textSec) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // ── Big status indicator ─────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: _advertising
                ? const Color(0xFF00FF88).withAlpha(20)
                : const Color(0xFF1E1F26),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _advertising
                  ? const Color(0xFF00FF88).withAlpha(120)
                  : Colors.white.withAlpha(20),
              width: 2,
            ),
            boxShadow: _advertising
                ? [
                    BoxShadow(
                      color: const Color(0xFF00FF88).withAlpha(50),
                      blurRadius: 30,
                      spreadRadius: 4,
                    )
                  ]
                : [],
          ),
          child: Column(children: [
            Icon(
              _advertising
                  ? Icons.sensors_rounded
                  : Icons.sensors_off_rounded,
              color: _advertising
                  ? const Color(0xFF00FF88)
                  : Colors.white30,
              size: 56,
            ),
            const SizedBox(height: 14),
            Text(
              _advertising
                  ? 'Broadcasting as'
                  : 'Not Broadcasting',
              style: TextStyle(
                color: _advertising
                    ? const Color(0xFF00FF88)
                    : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (_advertising) ...[
              const SizedBox(height: 6),
              Text(
                _selectedTire,
                style: const TextStyle(
                  color: Color(0xFF00FF88),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF88).withAlpha(15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '📡  Dashboard can now detect this phone',
                  style:
                      TextStyle(color: Color(0xFF00FF88), fontSize: 11),
                ),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 24),

        // ── Tire name selector ───────────────────────────────────────────
        if (!_advertising) ...[
          Text('Select which tyre this phone represents:',
              style: TextStyle(
                  color: textSec,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          // 2×2 grid — all 4 tyre positions
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _tireChip('TIRE_FL', 'Front Left',  accent),
              _tireChip('TIRE_FR', 'Front Right', accent),
              _tireChip('TIRE_RL', 'Rear Left',   accent),
              _tireChip('TIRE_RR', 'Rear Right',  accent),
            ],
          ),
          const SizedBox(height: 24),
        ],

        // ── Start / Stop button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed:
                _advertising ? _stopAdvertising : _startAdvertising,
            icon: Icon(
              _advertising
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline_rounded,
              size: 22,
            ),
            label: Text(
              _advertising ? 'Stop Broadcasting' : 'Start Broadcasting',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _advertising
                  ? const Color(0xFFFF453A)
                  : const Color(0xFF00FF88),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Instructions ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(15)),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              const Icon(Icons.info_outline,
                  color: Color(0xFF00C2FF), size: 15),
              const SizedBox(width: 8),
              Text('Setup Instructions',
                  style: TextStyle(
                      color: textSec,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ]),
            const SizedBox(height: 10),
            Text(
              '1. On this phone (Phone B):\n'
              '   • Go to Settings → Bluetooth\n'
              '   • Set Device Name to "TIRE_FL"\n'
              '   • Come back here and tap Start\n\n'
              '2. On the dashboard phone:\n'
              '   • Open the app → TPMS → Dashboard tab\n'
              '   • All 4 tyres will turn GREEN instantly\n\n'
              '3. To simulate a burst:\n'
              '   • Tap Stop (or turn off Bluetooth)\n'
              '   • Dashboard turns RED within ~1.5 seconds',
              style: TextStyle(
                  color: textSec, fontSize: 11, height: 1.65),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tireChip(String id, String label, Color accent) {
    final selected = _selectedTire == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedTire = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(25) : const Color(0xFF1E1F26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.white24,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.tire_repair_rounded,
              color: selected ? accent : Colors.white38, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(id,
                style: TextStyle(
                    color: selected ? accent : Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    color: selected ? accent.withAlpha(180) : Colors.white38,
                    fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tyre card
// ─────────────────────────────────────────────────────────────────────────────

class _TyreCard extends StatelessWidget {
  final TireData data;
  final Animation<double> pulseAnim;
  final _TpmsColors colors;
  const _TyreCard({
    required this.data,
    required this.pulseAnim,
    required this.colors,
  });

  static IconData _icon(TireStatus s) => switch (s) {
        TireStatus.healthy => Icons.check_circle_outline_rounded,
        TireStatus.low     => Icons.warning_amber_rounded,
        TireStatus.flat    => Icons.dangerous_rounded,
      };
  static String _label(TireStatus s) => switch (s) {
        TireStatus.healthy => 'GOOD',
        TireStatus.low     => 'LOW',
        TireStatus.flat    => 'FLAT',
      };

  @override
  Widget build(BuildContext context) {
    final c = colors.forStatus(data.status);
    // Make flat very obvious: boost the glow alpha even though color is dim
    final glowAlpha = data.status == TireStatus.flat ? 120 : 50;
    final borderAlpha = data.status == TireStatus.flat ? 200 : 100;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: data.status == TireStatus.flat ? pulseAnim.value : 1.0,
        child: child,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E).withAlpha(210),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withAlpha(borderAlpha), width: 1.8),
              boxShadow: [
                BoxShadow(
                    color: c.withAlpha(glowAlpha),
                    blurRadius: 14,
                    spreadRadius: 1)
              ],
            ),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withAlpha(25),
                  border: Border.all(color: c, width: 1.5),
                ),
                child: Icon(_icon(data.status), color: c, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.label,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 9,
                            fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      data.status == TireStatus.flat
                          ? _label(data.status)
                          : '${data.pressure.toStringAsFixed(0)} PSI',
                      style: TextStyle(
                          color: c,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Signal bar
// ─────────────────────────────────────────────────────────────────────────────

class _SignalRow extends StatelessWidget {
  final TireData tire;
  final Color    textSec;
  final _TpmsColors colors;
  const _SignalRow({
    required this.tire,
    required this.textSec,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final pct   = tire.signalPercent;
    final color = colors.forStatus(tire.status);
    return Row(children: [
      SizedBox(
        width: 90,
        child: Text('BT Signal',
            style: TextStyle(
                color: textSec,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Stack(children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(15),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            widthFactor: pct / 100,
            child: Container(
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(
                    colors: [color.withAlpha(180), color]),
                boxShadow: [
                  BoxShadow(color: color.withAlpha(80), blurRadius: 6)
                ],
              ),
            ),
          ),
        ]),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 38,
        child: Text('$pct%',
            textAlign: TextAlign.right,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Car painter
// ─────────────────────────────────────────────────────────────────────────────

class _CarPainter extends CustomPainter {
  final TireStatus flStatus;
  final TireStatus frStatus;
  final TireStatus rlStatus;
  final TireStatus rrStatus;
  final _TpmsColors colors;

  const _CarPainter({
    required this.flStatus,
    required this.frStatus,
    required this.rlStatus,
    required this.rrStatus,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const bW = 64.0, bH = 148.0;
    const tw = 16.0, th = 28.0;
    const tx = bW / 2 + 5;
    const fY = -bH / 2 + 42.0;
    const rY =  bH / 2 - 42.0;

    final bodyR = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: bW, height: bH),
      const Radius.circular(22),
    );
    canvas.drawRRect(bodyR, Paint()..color = const Color(0xFF2C2C2E));
    canvas.drawRRect(bodyR,
        Paint()
          ..color = Colors.white.withAlpha(22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);

    final wp = Paint()..color = const Color(0xFF3A3A5C).withAlpha(160);
    for (final topward in [true, false]) {
      final yBase = topward ? -bH / 2 : bH / 2;
      final ySign = topward ? 1 : -1;
      canvas.drawPath(
        Path()
          ..moveTo(cx - 20, cy + yBase + ySign * 24)
          ..lineTo(cx + 20, cy + yBase + ySign * 24)
          ..lineTo(cx + 16, cy + yBase + ySign * 46)
          ..lineTo(cx - 16, cy + yBase + ySign * 46)
          ..close(),
        wp,
      );
    }

    void drawTyre(double rx, double ry, TireStatus status) {
      final tc = colors.forStatus(status);
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx + rx, cy + ry), width: tw, height: th),
        const Radius.circular(5),
      );
      canvas.drawRRect(
          rect,
          Paint()
            ..color = tc.withAlpha(60)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawRRect(rect, Paint()..color = const Color(0xFF1C1C1E));
      canvas.drawRRect(
          rect,
          Paint()
            ..color = tc
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      canvas.drawCircle(Offset(cx + rx, cy + ry), 4,
          Paint()..color = tc.withAlpha(200));
    }

    drawTyre(-tx, fY, flStatus); // Front Left
    drawTyre( tx, fY, frStatus); // Front Right
    drawTyre(-tx, rY, rlStatus); // Rear Left
    drawTyre( tx, rY, rrStatus); // Rear Right

    // Direction arrow
    final ap = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final tip = Offset(cx, cy - bH / 2 - 8);
    canvas.drawLine(Offset(cx, cy - bH / 2 + 8), tip, ap);
    canvas.drawLine(tip, Offset(cx - 5, cy - bH / 2 - 2), ap);
    canvas.drawLine(tip, Offset(cx + 5, cy - bH / 2 - 2), ap);
  }

  @override
  bool shouldRepaint(_CarPainter old) =>
      old.flStatus != flStatus ||
      old.frStatus != frStatus ||
      old.rlStatus != rlStatus ||
      old.rrStatus != rrStatus ||
      old.colors.healthy != colors.healthy;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Animated width helper
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;
  const AnimatedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    required super.duration,
    super.curve,
  });

  @override
  ImplicitlyAnimatedWidgetState<AnimatedFractionallySizedBox> createState() =>
      _AFSBState();
}

class _AFSBState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _wf;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _wf = visitor(_wf, widget.widthFactor,
            (v) => Tween<double>(begin: v as double))
        as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: _wf?.evaluate(animation) ?? widget.widthFactor,
      child: widget.child,
    );
  }
}
