import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/fatigue_detection_service.dart';
import '../widgets/ambient_light_overlay.dart';

// ─── Eyes-On-Road Fatigue Detection Screen ────────────────────────────────────
//
//  Opens as a full-screen overlay from the home screen.
//  Shows the front camera feed with a real-time status HUD.
//

class FatigueDetectionScreen extends StatefulWidget {
  const FatigueDetectionScreen({super.key});

  @override
  State<FatigueDetectionScreen> createState() => _FatigueDetectionScreenState();
}

class _FatigueDetectionScreenState extends State<FatigueDetectionScreen>
    with TickerProviderStateMixin {
  // ── Service ─────────────────────────────────────────────────────────────────
  final FatigueDetectionService _service = FatigueDetectionService();

  // ── Notifiers for Granular Rebuilds ──────────────────────────────────────────
  final ValueNotifier<bool> _initialisingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _initFailedNotifier   = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isFatiguedNotifier   = ValueNotifier<bool>(false);
  final ValueNotifier<int>  _alarmCountNotifier   = ValueNotifier<int>(0);
  final ValueNotifier<String> _statusTextNotifier = ValueNotifier<String>('Initialising camera…');

  // Helpers to use local variables like before for simplicity in logic
  bool get _isFatigued => _isFatiguedNotifier.value;
  set _isFatigued(bool v) => _isFatiguedNotifier.value = v;

  // ── Animations ──────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;
  late AnimationController _alertController;
  late Animation<double>   _alertAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _alertController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _alertAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _alertController, curve: Curves.easeIn),
    );

    _init();
  }

  Future<void> _init() async {
    final ok = await _service.init();
    if (!mounted) return;

    if (!ok) {
      _initialisingNotifier.value = false;
      _initFailedNotifier.value   = true;
      _statusTextNotifier.value   = 'Camera unavailable';
      return;
    }

    _service.onFatigueChanged = (fatigued) {
      if (!mounted) return;
      _isFatigued = fatigued;
      _statusTextNotifier.value = fatigued ? 'FATIGUE DETECTED!' : 'Eyes on road ✓';

      if (fatigued) {
        _pulseController.repeat(reverse: true);
        _alertController.forward(from: 0.0);
      } else {
        _pulseController.stop();
        _pulseController.reset();
        _alertController.reverse();
      }
    };

    _service.onAlarmTriggered = () {
      if (!mounted) return;
      _alarmCountNotifier.value++;
    };

    await _service.start();

    if (mounted) {
      _initialisingNotifier.value = false;
      _statusTextNotifier.value   = 'Monitoring — eyes on road';
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _alertController.dispose();
    _initialisingNotifier.dispose();
    _initFailedNotifier.dispose();
    _isFatiguedNotifier.dispose();
    _alarmCountNotifier.dispose();
    _statusTextNotifier.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── UI ───────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lightMode = AmbientLightProvider.of(context);
    final accent    = LightThemePalette.accent(lightMode);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Camera Preview ───────────────────────────────────────────────
            // Wrapped in RepaintBoundary to isolate camera feed from HUD overlays
            RepaintBoundary(
              child: ValueListenableBuilder2<bool, bool>(
                _initialisingNotifier,
                _initFailedNotifier,
                (_, init, failed) => _buildCameraLayer(init, failed),
              ),
            ),

            // ── Red alarm flash overlay ──────────────────────────────────────
            AnimatedBuilder(
              animation: _alertAnim,
              builder: (_, __) => _alertAnim.value > 0
                  ? Container(
                      color: Colors.red.withAlpha((_alertAnim.value * 120).toInt()),
                    )
                  : const SizedBox.shrink(),
            ),

            // ── HUD ──────────────────────────────────────────────────────────
            _buildHUD(accent),

            // ── Top bar ──────────────────────────────────────────────────────
            _buildTopBar(accent),
          ],
        ),
      ),
    );
  }

  // ── Camera Layer ──────────────────────────────────────────────────────────────
  Widget _buildCameraLayer(bool initialising, bool initFailed) {
    if (initialising) {
      return _buildLoadingPlaceholder();
    }
    if (initFailed) {
      return _buildFailedPlaceholder();
    }
    final ctrl = _service.cameraController;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return _buildLoadingPlaceholder();
    }

    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: ctrl.value.previewSize!.height,
            height: ctrl.value.previewSize!.width,
            child: CameraPreview(ctrl),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Color(0xFF00E5FF)),
            SizedBox(height: 16),
            Text(
              'Starting front camera…',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );

  Widget _buildFailedPlaceholder() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.no_photography, color: Colors.white38, size: 72),
            SizedBox(height: 16),
            Text(
              'Camera unavailable',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Grant camera permission in app settings.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  // ── Top Bar ───────────────────────────────────────────────────────────────────
  Widget _buildTopBar(Color accent) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withAlpha(200), Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withAlpha(80)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.remove_red_eye_rounded, color: accent, size: 16),
                    const SizedBox(width: 6),
                    const Text(
                      'Eyes-On-Road Monitor',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'AI Fatigue Detection  •  ML Kit',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: _alarmCountNotifier,
              builder: (_, count, __) => count > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF1744).withAlpha(40),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFF1744)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFFF1744), size: 12),
                          const SizedBox(width: 4),
                          Text(
                            '$count alert${count > 1 ? "s" : ""}',
                            style: const TextStyle(
                              color: Color(0xFFFF1744),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // ── HUD ───────────────────────────────────────────────────────────────────────
  Widget _buildHUD(Color accent) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withAlpha(230), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator (animated pulse ring)
            ValueListenableBuilder<bool>(
              valueListenable: _isFatiguedNotifier,
              builder: (_, fatigued, __) => AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, child) => Transform.scale(
                  scale: fatigued ? _pulseAnim.value : 1.0,
                  child: child,
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: fatigued
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00C853),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (fatigued
                                ? const Color(0xFFFF1744)
                                : const Color(0xFF00C853))
                            .withAlpha(100),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (fatigued
                              ? const Color(0xFFFF1744)
                              : const Color(0xFF00C853))
                          .withAlpha(30),
                    ),
                    child: Icon(
                      fatigued
                          ? Icons.warning_amber_rounded
                          : Icons.remove_red_eye_rounded,
                      color: fatigued
                          ? const Color(0xFFFF1744)
                          : const Color(0xFF00C853),
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Status text
            ValueListenableBuilder2<String, bool>(
              _statusTextNotifier,
              _isFatiguedNotifier,
              (_, status, fatigued) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  key: ValueKey(status),
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fatigued
                        ? const Color(0xFFFF1744)
                        : Colors.white,
                    fontSize: fatigued ? 22 : 16,
                    fontWeight: fatigued
                        ? FontWeight.w900
                        : FontWeight.w500,
                    letterSpacing: fatigued ? 1.5 : 0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Sub text hint
            ValueListenableBuilder<bool>(
              valueListenable: _isFatiguedNotifier,
              builder: (_, fatigued, __) => Text(
                fatigued
                    ? 'Eyes closed or head turned away'
                    : 'Keep your eyes on the road',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),

            const SizedBox(height: 20),

            // Info chips row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip(
                  Icons.visibility_outlined,
                  'Eye open < 20%\ntriggers alert',
                  accent,
                ),
                const SizedBox(width: 10),
                _buildInfoChip(
                  Icons.screen_rotation_rounded,
                  'Head turn > 30°\ntriggers alert',
                  accent,
                ),
                const SizedBox(width: 10),
                _buildInfoChip(
                  Icons.timer_outlined,
                  'After 2 s\ncontinuous',
                  accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  const ValueListenableBuilder2(
    this.first,
    this.second,
    this.builder, {
    super.key,
    this.child,
  });

  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext context, A a, B b) builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<A>(
        valueListenable: first,
        builder: (context, a, _) => ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, b, _) => builder(context, a, b),
        ),
      );
}
