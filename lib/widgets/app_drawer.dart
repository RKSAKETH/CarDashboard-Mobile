import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

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
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = theme.colorScheme.onSurface;
    final subColor = isDark ? Colors.white70 : Colors.black54;
    final dividerColor = theme.dividerColor;
    final accent = theme.primaryColor;

    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: dividerColor, width: 1),
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
                    child: const Icon(
                      Icons.speed,
                      color: Colors.black,
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
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'GPS Speed Tracker',
                        style: TextStyle(
                          color: subColor,
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
                  // ── Dark Mode Toggle ──────────────────────────────────
                  ListTile(
                    leading: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? const Color(0xFF00FF00) : const Color(0xFF007A00),
                      size: 28,
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      isDark ? 'On' : 'Off',
                      style: TextStyle(color: subColor, fontSize: 12),
                    ),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeColor: accent,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  ),

                  Divider(color: dividerColor, height: 1),

                  _buildMenuItem(
                    context,
                    icon: Icons.emoji_events,
                    iconColor: const Color(0xFFFFD700),
                    title: 'Premium',
                    subtitle: 'Unlock all features',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showPremiumDialog(context);
                    },
                  ),
                  Divider(color: dividerColor, height: 1),

                  _buildMenuItem(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    textColor: textColor,
                    subColor: subColor,
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

                  _buildMenuItem(
                    context,
                    icon: Icons.language,
                    title: 'Language',
                    subtitle: 'English',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showLanguageDialog(context);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.star,
                    title: 'Rate Us',
                    subtitle: 'Rate on Play Store',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      Navigator.pop(context);
                      _launchURL('https://play.google.com');
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.feedback,
                    title: 'Feedback',
                    subtitle: 'Send us your thoughts',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showFeedbackDialog(context);
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.share,
                    title: 'Share with Friends',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      _shareApp();
                    },
                  ),

                  _buildMenuItem(
                    context,
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    textColor: textColor,
                    subColor: subColor,
                    onTap: () {
                      Navigator.pop(context);
                      _showPrivacyPolicy(context);
                    },
                  ),

                  Divider(color: dividerColor, height: 1),

                  _buildMenuItem(
                    context,
                    icon: Icons.info,
                    title: 'About',
                    subtitle: 'Version 1.0.0',
                    textColor: textColor,
                    subColor: subColor,
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
    required Color textColor,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    final accent = Theme.of(context).primaryColor;
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor ?? accent,
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: subColor,
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }

  void _showPremiumDialog(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 12),
            Text(
              'Premium',
              style: TextStyle(color: onSurface),
            ),
          ],
        ),
        content: Text(
          'Unlock premium features:\n\n'
          '• Ad-free experience\n'
          '• Advanced statistics\n'
          '• Export trip history\n'
          '• Custom themes\n'
          '• Priority support',
          style: TextStyle(color: onSurface.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: TextStyle(color: onSurface.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Upgrade Now', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text(
          'Select Language',
          style: TextStyle(color: onSurface),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(context, 'English', true, onSurface, accent),
            _buildLanguageOption(context, 'Spanish', false, onSurface, accent),
            _buildLanguageOption(context, 'French', false, onSurface, accent),
            _buildLanguageOption(context, 'German', false, onSurface, accent),
            _buildLanguageOption(context, 'Hindi', false, onSurface, accent),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String language, bool isSelected, Color textColor, Color accent) {
    return ListTile(
      title: Text(language, style: TextStyle(color: textColor)),
      trailing: isSelected ? Icon(Icons.check, color: accent) : null,
      onTap: () => Navigator.pop(context),
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final TextEditingController feedbackController = TextEditingController();
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text('Send Feedback', style: TextStyle(color: onSurface)),
        content: TextField(
          controller: feedbackController,
          maxLines: 5,
          style: TextStyle(color: onSurface),
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            hintStyle: TextStyle(color: onSurface.withOpacity(0.38)),
            border: const OutlineInputBorder(),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: onSurface.withOpacity(0.38)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: onSurface.withOpacity(0.7))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Send', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text('Privacy Policy', style: TextStyle(color: onSurface)),
        content: SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            'This app uses your location data to calculate speed and distance. '
            'Your location data is only used locally on your device and is not '
            'shared with any third parties.\n\n'
            'We do not collect, store, or transmit any personal information.\n\n'
            'GPS data is used solely for the purpose of providing speedometer '
            'and tracking functionality.',
            style: TextStyle(color: onSurface.withOpacity(0.7)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).primaryColor;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surface,
        title: Text('About Speedometer', style: TextStyle(color: onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Speedometer GPS Speed Tracker',
              style: TextStyle(
                color: onSurface,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Version 1.0.0', style: TextStyle(color: onSurface.withOpacity(0.7))),
            const SizedBox(height: 16),
            Text(
              'A GPS-based speedometer app with real-time speed tracking, '
              'distance measurement, and trip history.',
              style: TextStyle(color: onSurface.withOpacity(0.7)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: accent)),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final subColor = theme.brightness == Brightness.dark ? Colors.white70 : Colors.black54;
    final accent = theme.primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // ── Dark Mode ─────────────────────────────────────────────────
          SwitchListTile(
            secondary: Icon(
              themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: accent,
            ),
            title: Text('Dark Mode', style: TextStyle(color: onSurface)),
            subtitle: Text(
              themeProvider.isDarkMode ? 'Enabled' : 'Disabled',
              style: TextStyle(color: subColor),
            ),
            value: themeProvider.isDarkMode,
            onChanged: (_) => themeProvider.toggleTheme(),
            activeColor: accent,
          ),
          const Divider(),
          SwitchListTile(
            title: Text('Keep screen on', style: TextStyle(color: onSurface)),
            subtitle: Text('Prevent screen from turning off', style: TextStyle(color: subColor)),
            value: true,
            onChanged: (value) {},
            activeColor: accent,
          ),
          SwitchListTile(
            title: Text('Sound effects', style: TextStyle(color: onSurface)),
            subtitle: Text('Play sounds during tracking', style: TextStyle(color: subColor)),
            value: false,
            onChanged: (value) {},
            activeColor: accent,
          ),
          ListTile(
            title: Text('Speed unit', style: TextStyle(color: onSurface)),
            subtitle: Text('km/h', style: TextStyle(color: subColor)),
            trailing: Icon(Icons.chevron_right, color: subColor),
            onTap: () {},
          ),
          ListTile(
            title: Text('Distance unit', style: TextStyle(color: onSurface)),
            subtitle: Text('Kilometers', style: TextStyle(color: subColor)),
            trailing: Icon(Icons.chevron_right, color: subColor),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
