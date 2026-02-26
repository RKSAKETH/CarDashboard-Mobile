import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/incident_service.dart';
import 'services/ambient_light_service.dart';
import 'widgets/ambient_light_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SpeedometerApp());
}

// ─── Root App ────────────────────────────────────────────────────────────────

class SpeedometerApp extends StatelessWidget {
  const SpeedometerApp({super.key});

  ThemeData _buildTheme(LightMode mode, bool isDark) {
    final accent  = LightThemePalette.accent(mode);
    final bg      = LightThemePalette.background(mode);
    final surface = LightThemePalette.surface(mode);

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      primaryColor: accent,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: accent,
        secondary: accent,
        surface: surface,
        onPrimary: isDark ? Colors.black : Colors.white,
        onSurface: LightThemePalette.textPrimary(mode),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: LightThemePalette.textPrimary(mode),
        elevation: 0,
      ),
      drawerTheme: DrawerThemeData(backgroundColor: bg),
      dividerColor: surface,
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AmbientLightProvider(
      child: Builder(
        builder: (ctx) {
          // AmbientLightProvider.of registers an InheritedWidget dependency —
          // this Builder rebuilds automatically when LightMode changes.
          final mode = AmbientLightProvider.of(ctx);
          final isDark = isDarkModeNotifier.value;
          return AnimatedTheme(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            data: _buildTheme(mode, isDark),
            child: MaterialApp(
              navigatorKey: incidentNavigatorKey,
              title: 'Speedometer',
              debugShowCheckedModeBanner: false,
              theme: _buildTheme(mode, isDark),
              home: const AuthWrapper(),
            ),
          );
        },
      ),
    );
  }
}

// ─── Auth Wrapper ─────────────────────────────────────────────────────────────

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: LightThemePalette.accent(AmbientLightProvider.of(context)),
              ),
            ),
          );
        } else if (snapshot.hasData) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
