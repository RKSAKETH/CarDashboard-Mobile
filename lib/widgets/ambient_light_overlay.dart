import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ambient_light_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AmbientLightProvider  (InheritedNotifier-style state holder)
// ─────────────────────────────────────────────────────────────────────────────

final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(true);
final ValueNotifier<Locale> localeNotifier = ValueNotifier<Locale>(const Locale('en'));

/// Holds the current [LightMode] and notifies descendants when it changes.
/// Place this widget near the top of your widget tree so all children can
/// call [AmbientLightProvider.of(context)] to read the active mode.
class AmbientLightProvider extends StatefulWidget {
  const AmbientLightProvider({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// Set to false to disable sensor listening (e.g. in tests or when user
  final bool enabled;

  /// Set to true to temporarily prevent the banner from showing.
  static bool suppressBanner = false;

  /// Read the current [LightMode] from anywhere in the tree.
  static LightMode of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_AmbientLightScope>();
    return scope?.mode ?? LightMode.day;
  }

  /// Read without establishing a dependency (fire-and-forget).
  static LightMode peek(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<_AmbientLightScope>();
    return scope?.mode ?? LightMode.day;
  }

  @override
  State<AmbientLightProvider> createState() => _AmbientLightProviderState();
}

class _AmbientLightProviderState extends State<AmbientLightProvider> {
  LightMode _mode = LightMode.day;
  bool _showBanner = false;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    isDarkModeNotifier.addListener(_onThemeToggle);
    if (widget.enabled) {
      _mode = AmbientLightService.instance.currentMode;
      AmbientLightService.instance.onModeChanged = _onModeChanged;
      AmbientLightService.instance.start();
    }
  }

  void _onThemeToggle() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AmbientLightProvider old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !old.enabled) {
      AmbientLightService.instance.onModeChanged = _onModeChanged;
      AmbientLightService.instance.start();
    } else if (!widget.enabled && old.enabled) {
      AmbientLightService.instance.stop();
    }
  }

  @override
  void dispose() {
    isDarkModeNotifier.removeListener(_onThemeToggle);
    AmbientLightService.instance.onModeChanged = null;
    AmbientLightService.instance.stop();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _onModeChanged(LightMode newMode) {
    if (!mounted) return;
    setState(() {
      _mode = newMode;
      _showBanner = !AmbientLightProvider.suppressBanner;
    });
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showBanner = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AmbientLightScope(
      mode: _mode,
      isDark: isDarkModeNotifier.value,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            widget.child,
            // ── Animated mode-change banner ──
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              top: _showBanner ? 12 : -80,
              left: 0,
              right: 0,
              child: _ModeBanner(mode: _mode),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AmbientLightScope  (InheritedWidget)
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientLightScope extends InheritedWidget {
  const _AmbientLightScope({required this.mode, required this.isDark, required super.child});

  final LightMode mode;
  final bool isDark;

  @override
  bool updateShouldNotify(_AmbientLightScope old) => mode != old.mode || isDark != old.isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// _ModeBanner  — transient toast that slides in when theme changes
// ─────────────────────────────────────────────────────────────────────────────

class _ModeBanner extends StatelessWidget {
  const _ModeBanner({required this.mode});

  final LightMode mode;

  @override
  Widget build(BuildContext context) {
    final color  = LightThemePalette.accent(mode);
    final bg     = LightThemePalette.surface(mode);
    final label  = LightThemePalette.label(mode);
    final icon   = LightThemePalette.icon(mode);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: color.withAlpha(160), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AmbientThemedContainer  — convenience widget for colour-reactive surfaces
// ─────────────────────────────────────────────────────────────────────────────

/// A [Container] whose [color] automatically follows the ambient [LightMode].
/// Pass a [colorBuilder] that maps the current mode to the desired [Color].
///
/// Example:
/// ```dart
/// AmbientThemedContainer(
///   colorBuilder: LightThemePalette.surface,
///   borderRadius: BorderRadius.circular(12),
///   child: Text('Hello'),
/// )
/// ```
class AmbientThemedContainer extends StatelessWidget {
  const AmbientThemedContainer({
    super.key,
    required this.colorBuilder,
    this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius,
    this.border,
    this.boxShadow,
  });

  final Color Function(LightMode) colorBuilder;
  final Widget? child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;

  @override
  Widget build(BuildContext context) {
    final mode = AmbientLightProvider.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: colorBuilder(mode),
        borderRadius: borderRadius,
        border: border,
        boxShadow: boxShadow,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LuxIndicator  — a small always-visible HUD indicator showing live lux + mode
// ─────────────────────────────────────────────────────────────────────────────

/// A tiny chip that shows the current ambient lux reading and mode icon.
/// Intended for the top bar of the home screen.
class LuxIndicator extends StatefulWidget {
  const LuxIndicator({super.key});

  @override
  State<LuxIndicator> createState() => _LuxIndicatorState();
}

class _LuxIndicatorState extends State<LuxIndicator> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // Refresh lux display every second
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = AmbientLightProvider.of(context);
    final lux  = AmbientLightService.instance.currentLux;
    final color = LightThemePalette.accent(mode);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LightThemePalette.surface(mode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LightThemePalette.icon(mode), size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '${lux.round()} lx',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LightThemePalette  — maps LightMode → cockpit colour palette
// ─────────────────────────────────────────────────────────────────────────────

/// Static palette that maps a [LightMode] to a complete set of colours for
/// the cockpit UI. Based on:
///   • Day      : High-contrast bright whites & neon green (legible in sunlight)
///   • Twilight : Softened, amber-tinted yellows, reduced brightness
///   • Night    : Classic aviation red-shift preserving rhodopsin (night vision)
class LightThemePalette {
  const LightThemePalette._();

  // ── Accent (primary indicator colour) ──
  // Above 100 lx (day) → electric blue
  // Below 100 lx (twilight / night) → violet purple
  // ── NO green, orange, or red ──
  static Color accent(LightMode mode) {
    if (!isDarkModeNotifier.value) return const Color(0xFF00C2FF); // Light mode: always blue
    return switch (mode) {
      LightMode.day      => const Color(0xFF00C2FF), // Electric Blue
      LightMode.twilight => const Color(0xFFBF5FFF), // Violet Purple
      LightMode.night    => const Color(0xFFBF5FFF), // Violet Purple
    };
  }

  // ── Background ──
  static Color background(LightMode mode) {
    if (!isDarkModeNotifier.value) return const Color(0xFFF5F5F7);
    return switch (mode) {
      LightMode.day      => const Color(0xFF14151A), // Graphite Black
      LightMode.twilight => const Color(0xFF101014), // Darker Graphite
      LightMode.night    => const Color(0xFF0A0A0C), // Matte Black
    };
  }

  // ── Surface (card / panel) ──
  static Color surface(LightMode mode) {
    if (!isDarkModeNotifier.value) return Colors.white;
    return switch (mode) {
      LightMode.day      => const Color(0xFF1E1F26), // Glassmorphism base
      LightMode.twilight => const Color(0xFF18191E),
      LightMode.night    => const Color(0xFF121216),
    };
  }

  // ── Primary text ──
  static Color textPrimary(LightMode mode) {
    if (!isDarkModeNotifier.value) return const Color(0xFF2C2C2E);
    return switch (mode) {
      LightMode.day      => Colors.white,
      LightMode.twilight => Colors.white.withAlpha(240),
      LightMode.night    => Colors.white.withAlpha(220),
    };
  }

  // ── Secondary text ──
  static Color textSecondary(LightMode mode) {
    if (!isDarkModeNotifier.value) return const Color(0xFF8E8E93);
    return switch (mode) {
      LightMode.day      => Colors.white.withAlpha(160),
      LightMode.twilight => Colors.white.withAlpha(140),
      LightMode.night    => Colors.white.withAlpha(120),
    };
  }

  // ── Screen brightness target (0.0 – 1.0) ──
  static double screenBrightness(LightMode mode) => switch (mode) {
        LightMode.day      => 1.0,
        LightMode.twilight => 0.5,
        LightMode.night    => 0.2,
      };

  // ── Human-readable label for the current mode ──
  static String label(LightMode mode) => switch (mode) {
        LightMode.day      => '☀️ Day Mode  (►100 lx)',
        LightMode.twilight => '🌆 Dim Mode  (≪100 lx)',
        LightMode.night    => '🌙 Night Mode (≪10 lx)',
      };

  // ── Material icon for the current mode ──
  static IconData icon(LightMode mode) => switch (mode) {
        LightMode.day      => Icons.wb_sunny,
        LightMode.twilight => Icons.wb_twilight,
        LightMode.night    => Icons.nightlight_round,
      };
}

