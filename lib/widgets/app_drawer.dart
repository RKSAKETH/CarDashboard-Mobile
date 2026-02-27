import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/incident_logger_screen.dart';
import '../services/ambient_light_service.dart';
import 'ambient_light_overlay.dart';
import '../l10n/app_localizations.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      throw Exception('Could not launch $url');
    }
  }

  void _shareApp() {
    Share.share(
      'Check out this amazing Speedometer app!',
      subject: 'Speedometer App',
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = AmbientLightProvider.of(context);
    final bg = LightThemePalette.background(mode);
    final surface = LightThemePalette.surface(mode);
    final accent = LightThemePalette.accent(mode);
    final textPri = LightThemePalette.textPrimary(mode);
    final textSec = LightThemePalette.textSecondary(mode);
    final isDark = isDarkModeNotifier.value;
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = localeNotifier.value;
    final localeName = switch (currentLocale.languageCode) {
      'hi' => 'Hindi',
      'te' => 'Telugu',
      'ta' => 'Tamil',
      'ml' => 'Malayalam',
      _ => 'English',
    };

    return Drawer(
      backgroundColor: bg,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: surface, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.speed,
                      color: isDark ? Colors.black : Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speedometer',
                        style: TextStyle(
                          color: textPri,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'GPS Speed Tracker',
                        style: TextStyle(
                          color: textSec,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.emoji_events,
                    iconColor: const Color(0xFFFFD700),
                    title: 'Premium',
                    subtitle: 'Unlock all features',
                    onTap: () {
                      Navigator.pop(context);
                      _showPremiumDialog(context);
                    },
                  ),
                  const Divider(color: Color(0xFF2A2A2A), height: 1),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    title: l10n.settings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),

                  // -- Dark Mode Toggle --
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? const Color(0xFF00FF00) : Colors.amber.shade700,
                      size: 28,
                    ),
                    title: Text(
                      l10n.darkMode,
                      style: TextStyle(
                        color: textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Switch(
                      value: isDark,
                      activeColor: accent,
                      onChanged: (val) {
                        isDarkModeNotifier.value = val;
                      },
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.shield,
                    iconColor: const Color(0xFFFF1744),
                    title: 'Black Box Logger',
                    subtitle: 'Incident detection & SOS',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IncidentLoggerScreen(),
                        ),
                      );
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.brightness_auto,
                    iconColor: const Color(0xFFFF8C00),
                    title: 'Adaptive Light UI',
                    subtitle: 'Auto cockpit theme by lux',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(
                            initialSection: SettingsSection.ambientLight,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  _buildMenuItem(
                    context,
                    icon: Icons.language,
                    title: l10n.language,
                    subtitle: localeName,
                    onTap: () {
                      Navigator.pop(context);
                      showLanguageDialog(context);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.star,
                    title: l10n.rateUs,
                    subtitle: 'Rate on Play Store',
                    onTap: () {
                      Navigator.pop(context);
                      // Launch Play Store
                      _launchURL('https://play.google.com');
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.feedback,
                    title: l10n.feedback,
                    subtitle: 'Send us your thoughts',
                    onTap: () {
                      Navigator.pop(context);
                      _showFeedbackDialog(context);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.share,
                    title: l10n.shareWithFriends,
                    onTap: () {
                      _shareApp();
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.privacy_tip,
                    title: l10n.privacyPolicy,
                    onTap: () {
                      Navigator.pop(context);
                      _showPrivacyPolicy(context);
                    },
                  ),

                  const Divider(color: Color(0xFF2A2A2A), height: 1),

                  _buildMenuItem(
                    context,
                    icon: Icons.info,
                    title: l10n.about,
                    subtitle: 'Version 1.0.0',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    final mode = AmbientLightProvider.of(context);
    final accent = LightThemePalette.accent(mode);
    final textPri = LightThemePalette.textPrimary(mode);
    final textSec = LightThemePalette.textSecondary(mode);

    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? accent,
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textPri,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: textSec,
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 12),
            Text(
              l10n.premium,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'Unlock premium features:\n\n'
          '• Ad-free experience\n'
          '• Advanced statistics\n'
          '• Export trip history\n'
          '• Custom themes\n'
          '• Priority support',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF00),
            ),
            child: const Text(
              'Upgrade Now',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void showLanguageDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = localeNotifier.value;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          l10n.selectLanguage,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', const Locale('en'), currentLocale == const Locale('en')),
            _buildLanguageOption(context, 'Hindi', const Locale('hi'), currentLocale == const Locale('hi')),
            _buildLanguageOption(context, 'Telugu', const Locale('te'), currentLocale == const Locale('te')),
            _buildLanguageOption(context, 'Tamil', const Locale('ta'), currentLocale == const Locale('ta')),
            _buildLanguageOption(context, 'Malayalam', const Locale('ml'), currentLocale == const Locale('ml')),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String language, Locale locale, bool isSelected) {
    return ListTile(
      title: Text(
        language,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF00FF00))
          : null,
      onTap: () {
        localeNotifier.value = locale;
        Navigator.pop(context);
      },
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Send Feedback',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: feedbackController,
          maxLines: 5,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Tell us what you think...',
            hintStyle: TextStyle(color: Colors.white38),
            border: OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white38),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF00),
            ),
            child: const Text(
              'Send',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(color: Colors.white),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            'This app uses your location data to calculate speed and distance. '
            'Your location data is only used locally on your device and is not '
            'shared with any third parties.\n\n'
            'We do not collect, store, or transmit any personal information.\n\n'
            'GPS data is used solely for the purpose of providing speedometer '
            'and tracking functionality.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00FF00))),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'About Speedometer',
          style: TextStyle(color: Colors.white),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speedometer GPS Speed Tracker',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Text(
              'A GPS-based speedometer app with real-time speed tracking, '
              'distance measurement, and trip history.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00FF00))),
          ),
        ],
      ),
    );
  }
}

enum SettingsSection { general, ambientLight }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialSection = SettingsSection.general,
  });

  final SettingsSection initialSection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = localeNotifier.value;
    final localeName = switch (currentLocale.languageCode) {
      'hi' => 'Hindi',
      'te' => 'Telugu',
      'ta' => 'Tamil',
      'ml' => 'Malayalam',
      _ => 'English',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // ─── General ───────────────────────────────────────────────────
          _SectionHeader(title: l10n.general),
          SwitchListTile(
            title: Text(l10n.keepScreenOn, style: const TextStyle(color: Colors.white)),
            subtitle: const Text('Prevent screen from turning off', style: TextStyle(color: Colors.white70)),
            value: true,
            onChanged: (value) {},
            activeThumbColor: LightThemePalette.accent(AmbientLightProvider.of(context)),
          ),
          SwitchListTile(
            title: Text(l10n.soundEffects, style: const TextStyle(color: Colors.white)),
            subtitle: const Text('Play sounds during tracking', style: TextStyle(color: Colors.white70)),
            value: false,
            onChanged: (value) {},
            activeThumbColor: LightThemePalette.accent(AmbientLightProvider.of(context)),
          ),
          ListTile(
            title: Text(l10n.speedUnit, style: const TextStyle(color: Colors.white)),
            subtitle: const Text('km/h', style: TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {},
          ),
          ListTile(
            title: Text(l10n.distanceUnit, style: const TextStyle(color: Colors.white)),
            subtitle: const Text('Kilometers', style: TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {},
          ),
          ListTile(
            title: Text(l10n.language, style: const TextStyle(color: Colors.white)),
            subtitle: Text(localeName, style: const TextStyle(color: Colors.white70)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white70),
            onTap: () {
              const AppDrawer().showLanguageDialog(context);
            },
          ),

          // ─── Ambient Light ─────────────────────────────────────────────
          _SectionHeader(title: l10n.ambientLightTitle),
          const _AmbientLightSettings(),
        ],
      ),
    );
  }
}

// ─── Section Header ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = LightThemePalette.accent(AmbientLightProvider.of(context));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

// ─── Ambient Light Settings Panel ────────────────────────────────────────────

class _AmbientLightSettings extends StatefulWidget {
  const _AmbientLightSettings();

  @override
  State<_AmbientLightSettings> createState() => _AmbientLightSettingsState();
}

class _AmbientLightSettingsState extends State<_AmbientLightSettings> {
  LightMode? _override; // null = auto

  void _applyOverride(LightMode? mode) {
    setState(() => _override = mode);
    if (mode != null) {
      AmbientLightService.instance.forceMode(mode);
    } else {
      // Re-enable sensor
      AmbientLightService.instance.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode   = AmbientLightProvider.of(context);
    final accent = LightThemePalette.accent(mode);
    final lux    = AmbientLightService.instance.currentLux;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Live Lux Card ──
          _LiveLuxCard(mode: mode, accent: accent, lux: lux),

          const SizedBox(height: 16),

          // ── Mode Description ──
          _ModeDescriptionCard(mode: mode, accent: accent),

          const SizedBox(height: 16),

          // ── Manual Override ──
          Text(
            'Override Mode (for testing)',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _OverrideSelector(
            selectedOverride: _override,
            accent: accent,
            onChanged: _applyOverride,
          ),

          const SizedBox(height: 20),

          // ── Hysteresis explainer ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: LightThemePalette.surface(mode),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withAlpha(40)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: accent, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'How It Works',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _InfoRow(
                  icon: Icons.wb_sunny,
                  color: Color(0xFF00FF00),
                  title: '☀️ Day  (> 200 lux)',
                  body: 'Neon green, high-contrast whites. Legible in direct sunlight.',
                ),
                const _InfoRow(
                  icon: Icons.wb_twilight,
                  color: Color(0xFFFFBF00),
                  title: '🌆 Twilight  (10–200 lux)',
                  body: 'Soft amber, reduced brightness. Ideal for dusk or garages.',
                ),
                const _InfoRow(
                  icon: Icons.nightlight_round,
                  color: Color(0xFFFF2400),
                  title: '🌙 Night  (< 10 lux)',
                  body: 'Aviation red-shift. Preserves rhodopsin / night vision.',
                ),
                const SizedBox(height: 8),
                Text(
                  '⟳  Hysteresis: transitions are debounced by 600 ms to prevent flicker when a shadow briefly passes over the sensor.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Live Lux Meter Card ─────────────────────────────────────────────────────

class _LiveLuxCard extends StatelessWidget {
  const _LiveLuxCard({
    required this.mode,
    required this.accent,
    required this.lux,
  });

  final LightMode mode;
  final Color accent;
  final double lux;

  @override
  Widget build(BuildContext context) {
    // Normalise lux to 0-1 for the progress bar (cap at 1000 lux)
    final ratio = (lux / 1000.0).clamp(0.0, 1.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightThemePalette.surface(mode),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: accent.withAlpha(30),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Ambient Light',
                style: TextStyle(
                  color: LightThemePalette.textSecondary(mode),
                  fontSize: 12,
                ),
              ),
              const LuxIndicator(),
            ],
          ),
          const SizedBox(height: 12),
          // Big lux number
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                lux.round().toString(),
                style: TextStyle(
                  color: accent,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 6),
                child: Text(
                  'lux',
                  style: TextStyle(
                    color: accent.withAlpha(160),
                    fontSize: 16,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                LightThemePalette.icon(mode),
                color: accent,
                size: 40,
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Lux bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0', style: TextStyle(color: Colors.white24, fontSize: 10)),
              Text('500', style: TextStyle(color: Colors.white24, fontSize: 10)),
              Text('1 000 lux', style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Mode Description Card ───────────────────────────────────────────────────

class _ModeDescriptionCard extends StatelessWidget {
  const _ModeDescriptionCard({required this.mode, required this.accent});
  final LightMode mode;
  final Color accent;

  String get _description => switch (mode) {
        LightMode.day      => 'High-contrast display. Optimised for bright sunlight and open roads.',
        LightMode.twilight => 'Amber dimmed UI. Comfortable for dusk driving and underground parking.',
        LightMode.night    => 'Aviation red-shift active. Your eyes\' rhodopsin is preserved — natural night vision intact.',
      };

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withAlpha(30), accent.withAlpha(10)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(LightThemePalette.icon(mode), color: accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LightThemePalette.label(mode),
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Override Selector ────────────────────────────────────────────────────────

class _OverrideSelector extends StatelessWidget {
  const _OverrideSelector({
    required this.selectedOverride,
    required this.accent,
    required this.onChanged,
  });

  final LightMode? selectedOverride;
  final Color accent;
  final ValueChanged<LightMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    final modes = [
      (null,               '🔄 Auto',     const Color(0xFFFFFFFF).withAlpha(130)),
      (LightMode.day,      '☀️ Day',      const Color(0xFF00FF00)),
      (LightMode.twilight, '🌆 Twilight', const Color(0xFFFFBF00)),
      (LightMode.night,    '🌙 Night',    const Color(0xFFFF2400)),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: modes.map((entry) {
        final (modeVal, label, color) = entry;
        final isSelected = selectedOverride == modeVal;
        return GestureDetector(
          onTap: () => onChanged(modeVal),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color.withAlpha(40) : Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : Colors.white24,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white54,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Info Row ────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
