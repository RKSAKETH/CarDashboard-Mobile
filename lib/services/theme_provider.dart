import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _key = 'isDarkMode';

  bool _isDarkMode = true; // default to dark (original app look)

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadFromPrefs();
  }

  /// Load the saved theme preference from disk.
  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  /// Toggle between dark and light mode, then persist.
  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDarkMode);
  }

  // ─── Dark Theme ───────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        primaryColor: const Color(0xFF00FF00),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF00),
          secondary: Color(0xFF00FF00),
          surface: Color(0xFF1E1E1E),
          onSurface: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0D0D0D),
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF0D0D0D),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF00FF00)
                : Colors.grey,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF00FF00).withOpacity(0.4)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        dividerColor: const Color(0xFF2A2A2A),
        useMaterial3: true,
      );

  // ─── Light Theme ──────────────────────────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF0F4F8),
        primaryColor: const Color(0xFF007A00),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF007A00),
          secondary: Color(0xFF007A00),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFFFFFF),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF007A00)
                : Colors.grey,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF007A00).withOpacity(0.4)
                : Colors.grey.withOpacity(0.3),
          ),
        ),
        dividerColor: const Color(0xFFE0E0E0),
        useMaterial3: true,
      );
}
