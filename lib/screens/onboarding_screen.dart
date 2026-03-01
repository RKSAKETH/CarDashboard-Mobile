import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../main.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  Velora Drive — Onboarding + Auth Flow
//
//  4 branded slides → "Get Started" → sliding auth sheet (Sign Up / Login / Google)
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Brand Palette ────────────────────────────────────────────────────────────
class _Brand {
  static const navy   = Color(0xFF0A1628);
  static const cyan   = Color(0xFF00D4FF);
  static const blue   = Color(0xFF0066FF);
  static const green  = Color(0xFF059669);
  static const purple = Color(0xFF7C3AED);
  static const white  = Colors.white;
}

// ─── Slide Model ──────────────────────────────────────────────────────────────
class _Slide {
  const _Slide({
    required this.icon,
    required this.accentColor,
    required this.tag,
    required this.title,
    required this.body,
    required this.topBg,
  });
  final IconData icon;
  final Color    accentColor;
  final String   tag;
  final String   title;
  final String   body;
  final Color    topBg;
}

const List<_Slide> _kSlides = [
  _Slide(
    icon: Icons.speed_rounded,
    accentColor: _Brand.cyan,
    tag: '01  ·  SPEEDOMETER',
    title: 'Live Speed\nIntelligence',
    body: 'GPS-precise speed down to ±1 km/h. Ambient-adaptive HUD, instant speed limit alerts, and a real-time trip dashboard.',
    topBg: Color(0xFFE8F7FF),
  ),
  _Slide(
    icon: Icons.map_rounded,
    accentColor: _Brand.blue,
    tag: '02  ·  GPS & NAVIGATION',
    title: 'Smart Route\nCommander',
    body: 'Voice-activated navigation, live traffic overlays, and simulation mode — plan every journey before you take the wheel.',
    topBg: Color(0xFFEBF0FF),
  ),
  _Slide(
    icon: Icons.remove_red_eye_rounded,
    accentColor: _Brand.purple,
    tag: '03  ·  FATIGUE DETECTION',
    title: 'Eyes-On-Road\nAI Guard',
    body: 'ML Kit tracks your eye posture in real time. Eyes closed for 2 seconds? Aggressive vibration + vocal alert: "STAY FOCUSED!"',
    topBg: Color(0xFFF0EBFF),
  ),
  _Slide(
    icon: Icons.shield_rounded,
    accentColor: _Brand.green,
    tag: '04  ·  DRIVE ANALYTICS',
    title: 'Black Box\nDrive Memory',
    body: 'Every trip logged — distance, max speed, average speed, incidents. Your personal driving intelligence vault, always with you.',
    topBg: Color(0xFFE8FFF4),
  ),
];

// ─── Onboarding Screen ────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int  _page      = 0;
  bool _showAuth  = false;

  late AnimationController _floatCtrl;
  late Animation<double>   _floatAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2800))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _kSlides.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic);
    } else {
      _openAuth();
    }
  }

  void _openAuth() => setState(() => _showAuth = true);

  @override
  Widget build(BuildContext context) {
    final slide  = _kSlides[_page];
    final accent = slide.accentColor;
    final isLast = _page == _kSlides.length - 1;

    return Scaffold(
      backgroundColor: _Brand.white,
      body: Stack(
        children: [

          // ── Page View ──────────────────────────────────────────────────────
          PageView.builder(
            controller: _pageCtrl,
            itemCount: _kSlides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => _SlidePage(
              slide: _kSlides[i],
              floatAnim: _floatAnim,
            ),
          ),

          // ── Bottom controls ────────────────────────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _BottomBar(
              page: _page,
              total: _kSlides.length,
              accent: accent,
              isLast: isLast,
              onNext: _next,
              onSkip: _openAuth,
            ),
          ),

          // ── Auth sheet ─────────────────────────────────────────────────────
          if (_showAuth)
            _AuthOverlay(
              onDismiss: () => setState(() => _showAuth = false),
            ),
        ],
      ),
    );
  }
}

// ─── Individual Slide ─────────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide, required this.floatAnim});

  final _Slide           slide;
  final Animation<double> floatAnim;

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return Container(
      color: _Brand.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Top illustrated panel ──────────────────────────────────────────
          AnimatedBuilder(
            animation: floatAnim,
            builder: (context2, child) => Container(
              height: MediaQuery.of(context).size.height * 0.46,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [slide.topBg, _Brand.white],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft:  Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Stack(
                children: [
                  // Decorative grid lines
                  CustomPaint(
                    size: Size(sw, MediaQuery.of(context).size.height * 0.46),
                    painter: _GridPainter(color: slide.accentColor),
                  ),

                  // Wordmark at top left
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 18,
                    left: 28,
                    child: _Wordmark(),
                  ),

                  // Center illustration
                  Center(
                    child: Transform.translate(
                      offset: Offset(0, -6 + floatAnim.value * 12),
                      child: _IllustrationOrb(
                        icon:  slide.icon,
                        color: slide.accentColor,
                        size:  sw * 0.44,
                        pulse: floatAnim.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Text content ───────────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 28, 30, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tag
                  Text(
                    slide.tag,
                    style: TextStyle(
                      color: slide.accentColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: _Brand.navy,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1.10,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Accent divider
                  Container(
                    width: 38,
                    height: 3,
                    decoration: BoxDecoration(
                      color: slide.accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Body
                  Text(
                    slide.body,
                    style: TextStyle(
                      color: _Brand.navy.withAlpha(145),
                      fontSize: 14.5,
                      height: 1.60,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Velora Drive Wordmark ────────────────────────────────────────────────────
class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: _Brand.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.speed, color: _Brand.cyan, size: 16),
        ),
        const SizedBox(width: 8),
        const Text(
          'Velora Drive',
          style: TextStyle(
            color: _Brand.navy,
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ─── Illustration Orb ────────────────────────────────────────────────────────
class _IllustrationOrb extends StatelessWidget {
  const _IllustrationOrb({
    required this.icon,
    required this.color,
    required this.size,
    required this.pulse,
  });

  final IconData icon;
  final Color    color;
  final double   size;
  final double   pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size * 1.5,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outermost glow
          Container(
            width: size * 1.4 + pulse * 14,
            height: size * 1.4 + pulse * 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha((pulse * 16).toInt()),
            ),
          ),
          // Ring 2
          Container(
            width: size * 1.1,
            height: size * 1.1,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(24),
              border: Border.all(color: color.withAlpha(40), width: 1),
            ),
          ),
          // Main orb
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withAlpha(70),
                  color.withAlpha(25),
                ],
              ),
              border: Border.all(color: color.withAlpha(90), width: 1.5),
            ),
            child: Icon(icon, color: color, size: size * 0.42),
          ),
          // Orbiting dots
          ..._dots(color, size * 0.55, pulse),
        ],
      ),
    );
  }

  List<Widget> _dots(Color c, double r, double t) {
    return List.generate(3, (i) {
      final angle = (i / 3 * 2 * math.pi) + t * math.pi * 0.25;
      return Positioned(
        left: size * 0.75 + r * math.cos(angle) - 5,
        top:  size * 0.75 + r * math.sin(angle) - 5,
        child: Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c.withAlpha(80 + (t * 80).toInt()),
            boxShadow: [BoxShadow(color: c.withAlpha(60), blurRadius: 6)],
          ),
        ),
      );
    });
  }
}

// ─── Grid Painter (decorative background) ─────────────────────────────────────
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color    = color.withAlpha(14)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

// ─── Bottom Controls Bar ──────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.page,
    required this.total,
    required this.accent,
    required this.isLast,
    required this.onNext,
    required this.onSkip,
  });

  final int page, total;
  final Color accent;
  final bool isLast;
  final VoidCallback onNext, onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 36),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withAlpha(0), Colors.white, Colors.white],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Row(
        children: [
          // Skip
          SizedBox(
            width: 60,
            child: TextButton(
              onPressed: isLast ? null : onSkip,
              style: TextButton.styleFrom(
                foregroundColor: _Brand.navy.withAlpha(100),
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
              child: Text(
                isLast ? '' : 'Skip',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),

          // Dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(total, (i) {
                final active = i == page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: active ? 22 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: active ? accent : accent.withAlpha(45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

          // Next / Get Started
          SizedBox(
            width: isLast ? 130 : 52,
            height: 52,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: accent.withAlpha(90),
                    blurRadius: 18,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(26),
                  onTap: onNext,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isLast) ...[
                          const Text(
                            'Get Started',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Auth Overlay (slide-up sheet) ───────────────────────────────────────────
class _AuthOverlay extends StatefulWidget {
  const _AuthOverlay({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  State<_AuthOverlay> createState() => _AuthOverlayState();
}

class _AuthOverlayState extends State<_AuthOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  final _formKey  = GlobalKey<FormState>();
  final _email    = TextEditingController();
  final _pass     = TextEditingController();
  final _confirm  = TextEditingController();
  final _name     = TextEditingController();

  bool _isLogin = false;   // default: Sign Up for new users
  bool _loading = false;
  bool _obscure = true;
  bool _agreed  = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_agreed) {
      _err('Please agree to the Terms & Conditions.');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isLogin) {
        await AuthService().signInWithEmailAndPassword(
            _email.text.trim(), _pass.text.trim());
      } else {
        await AuthService().registerWithEmailAndPassword(
            _email.text.trim(), _pass.text.trim(), _name.text.trim());
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) _err(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() => _loading = true);
    try {
      await AuthService().signInWithGoogle();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (_) => false,
        );
      }
    } catch (e) {
      if (mounted) _err(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _err(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Dim backdrop
        FadeTransition(
          opacity: _fade,
          child: GestureDetector(
            onTap: _dismiss,
            child: Container(color: Colors.black.withAlpha(55)),
          ),
        ),

        // Sheet
        SlideTransition(
          position: _slide,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 40,
                    spreadRadius: 0,
                    offset: Offset(0, -8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    28, 16, 28,
                    MediaQuery.of(context).viewInsets.bottom + 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Header
                    Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _Brand.navy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.speed,
                              color: _Brand.cyan, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Velora Drive',
                              style: TextStyle(
                                color: _Brand.navy,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _isLogin ? 'Welcome back!' : 'Create your account',
                              style: TextStyle(
                                color: _Brand.navy.withAlpha(120),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tab selector
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _Tab(
                            label: 'Sign Up',
                            active: !_isLogin,
                            onTap: () => setState(() => _isLogin = false),
                          ),
                          _Tab(
                            label: 'Log In',
                            active: _isLogin,
                            onTap: () => setState(() => _isLogin = true),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Form
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          if (!_isLogin) ...[
                            _Field(
                              ctrl: _name,
                              hint: 'Full name',
                              icon: Icons.person_outline_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? 'Enter your name' : null,
                            ),
                            const SizedBox(height: 14),
                          ],
                          _Field(
                            ctrl: _email,
                            hint: 'Email address',
                            icon: Icons.email_outlined,
                            keyboard: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter email';
                              if (!v.contains('@')) return 'Invalid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          _Field(
                            ctrl: _pass,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            isPassword: true,
                            onToggle: () =>
                                setState(() => _obscure = !_obscure),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Enter password';
                              if (v.length < 6) return 'Min 6 characters';
                              return null;
                            },
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            _Field(
                              ctrl: _confirm,
                              hint: 'Confirm password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscure,
                              isPassword: true,
                              onToggle: () =>
                                  setState(() => _obscure = !_obscure),
                              validator: (v) => v != _pass.text
                                  ? 'Passwords don\'t match'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            // Terms row
                            Row(
                              children: [
                                SizedBox(
                                  width: 22, height: 22,
                                  child: Checkbox(
                                    value: _agreed,
                                    activeColor: _Brand.blue,
                                    side: BorderSide(
                                        color: _Brand.navy.withAlpha(90)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(5)),
                                    onChanged: (v) =>
                                        setState(() => _agreed = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'I agree to the Terms of Service & Privacy Policy',
                                    style: TextStyle(
                                      color: _Brand.navy.withAlpha(130),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Primary CTA
                    if (_loading)
                      const Center(
                          child: CircularProgressIndicator(
                              color: _Brand.blue))
                    else
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _Brand.navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            _isLogin ? 'Log In' : 'Create Account',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),

                    const SizedBox(height: 18),

                    // Divider
                    Row(children: [
                      Expanded(
                          child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'or',
                          style: TextStyle(
                              color: _Brand.navy.withAlpha(100),
                              fontSize: 12),
                        ),
                      ),
                      Expanded(
                          child: Container(
                              height: 1,
                              color: const Color(0xFFE5E7EB))),
                    ]),

                    const SizedBox(height: 18),

                    // Google button
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _loading ? null : _google,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFE5E7EB), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google G
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const SweepGradient(
                                  colors: [
                                    Color(0xFF4285F4),
                                    Color(0xFF34A853),
                                    Color(0xFFFBBC05),
                                    Color(0xFFEA4335),
                                    Color(0xFF4285F4),
                                  ],
                                ),
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: const Center(
                                child: Text(
                                  'G',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Continue with Google',
                              style: TextStyle(
                                color: _Brand.navy,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tab Widget ───────────────────────────────────────────────────────────────
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool   active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: active
                ? const [
                    BoxShadow(
                        color: Color(0x18000000),
                        blurRadius: 6,
                        offset: Offset(0, 2))
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? _Brand.navy : _Brand.navy.withAlpha(100),
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Form Field ───────────────────────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.hint,
    required this.icon,
    this.keyboard,
    this.obscure = false,
    this.isPassword = false,
    this.onToggle,
    this.validator,
  });

  final TextEditingController ctrl;
  final String hint;
  final IconData icon;
  final TextInputType? keyboard;
  final bool obscure, isPassword;
  final VoidCallback? onToggle;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(
        color: _Brand.navy,
        fontSize: 14.5,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
            color: _Brand.navy.withAlpha(80), fontSize: 14.5),
        prefixIcon: Icon(icon, color: _Brand.navy.withAlpha(120), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _Brand.navy.withAlpha(100),
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _Brand.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        errorStyle: const TextStyle(
            color: Color(0xFFDC2626), fontSize: 11),
      ),
    );
  }
}
