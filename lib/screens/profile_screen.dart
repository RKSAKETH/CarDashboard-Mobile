import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/ambient_light_overlay.dart';

/// Example screen demonstrating Firestore usage
/// Shows user profile and trip statistics
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final user = AuthService().currentUser;
    final mode   = AmbientLightProvider.of(context);
    final bg     = LightThemePalette.background(mode);
    final textPri = LightThemePalette.textPrimary(mode);
    final textSec = LightThemePalette.textSecondary(mode);
    final accent  = LightThemePalette.accent(mode);

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          foregroundColor: textPri,
          elevation: 0,
          title: Text(l10n.profile, style: TextStyle(color: textPri)),
        ),
        body: Center(
          child: Text(l10n.pleaseLogin, style: TextStyle(color: textPri)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPri,
        elevation: 0,
        title: Text(l10n.profile, style: TextStyle(color: textPri)),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: textPri),
            onPressed: () async {
              await AuthService().signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Profile Card
            _buildUserProfileCard(context, user.uid, textPri, textSec, bg, accent),

            const SizedBox(height: 24),

            // Trip Statistics Card
            _buildTripStatisticsCard(context, user.uid, textPri, textSec, bg, accent),

            const SizedBox(height: 24),

            // Recent Trips
            _buildRecentTrips(context, user.uid, textPri, textSec, bg, accent),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                icon: const Icon(Icons.logout),
                label: Text(l10n.logout.toUpperCase()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                  foregroundColor: const Color(0xFFFF6B6B),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard(BuildContext context, String uid,
      Color textPri, Color textSec, Color bg, Color accent) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirestoreService().getUserProfileStream(uid),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: bg,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: bg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: textPri)),
            ),
          );
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>?;
        final displayName = userData?['displayName'] ?? 'Unknown User';
        final email = userData?['email'] ?? 'No email';

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F26).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withValues(alpha: 0.6), width: 3),
                        boxShadow: [
                          BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF14151A),
                      backgroundImage: userData?['photoUrl'] != null &&
                                     userData!['photoUrl'].toString().isNotEmpty
                          ? NetworkImage(userData['photoUrl'])
                          : null,
                      child: userData?['photoUrl'] == null ||
                             userData!['photoUrl'].toString().isEmpty
                          ? Icon(Icons.person, size: 40, color: accent)
                          : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: textPri,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.edit, size: 18, color: accent),
                                onPressed: () =>
                                    _showEditNameDialog(context, displayName),
                                tooltip: 'Edit Name',
                              ),
                            ],
                          ),
                          Text(
                            email,
                            style: TextStyle(fontSize: 14, color: textSec),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Member since: ${_formatDate(userData?['createdAt'])}',
                            style: TextStyle(fontSize: 12, color: textSec),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Divider(height: 32, color: textSec.withAlpha(60)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showChangePasswordDialog(context),
                      icon: Icon(Icons.lock_reset, color: textPri),
                      label: Text(l10n.changePassword,
                          style: TextStyle(color: textPri)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Future<void> _showEditNameDialog(BuildContext context, String currentName) async {
    final nameController = TextEditingController(text: currentName);
    
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(l10n.editName, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: l10n.displayName,
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                try {
                  final user = AuthService().currentUser;
                  if (user != null) {
                    await user.updateDisplayName(newName);
                    await FirestoreService().createOrUpdateUserProfile(
                      uid: user.uid,
                      email: user.email ?? '',
                      displayName: newName,
                    );
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.nameUpdatedSuccessfully)),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating name: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: Text(l10n.save, style: const TextStyle(color: Color(0xFF00FF00))),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    final l10n = AppLocalizations.of(context)!;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(l10n.changePassword, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.newPassword,
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.confirmPassword,
                labelStyle: const TextStyle(color: Colors.grey),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF00))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel, style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              if (passwordController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.passwordsDoNotMatch), backgroundColor: Colors.red),
                );
                return;
              }
              if (passwordController.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.passwordTooShort), backgroundColor: Colors.red),
                );
                return;
              }

              try {
                final user = AuthService().currentUser;
                if (user != null) {
                  await user.updatePassword(passwordController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.passwordUpdatedSuccessfully)),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(l10n.update, style: const TextStyle(color: Color(0xFF00FF00))),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatisticsCard(BuildContext context, String uid,
      Color textPri, Color textSec, Color bg, Color accent) {
    return FutureBuilder<Map<String, dynamic>>(
      future: FirestoreService().getTripStatistics(uid),
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context)!;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            color: bg,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: bg,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snapshot.error}',
                  style: TextStyle(color: textPri)),
            ),
          );
        }

        final stats = snapshot.data ?? {};

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1F26).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tripStatistics,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textPri,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      l10n.totalTrips,
                      '${stats['totalTrips'] ?? 0}',
                      Icons.route,
                      textPri, textSec, accent,
                    ),
                    _buildStatItem(
                      l10n.distance,
                      '${(stats['totalDistance'] ?? 0.0).toStringAsFixed(1)} km',
                      Icons.straighten,
                      textPri, textSec, accent,
                    ),
                    _buildStatItem(
                      l10n.max,
                      '${(stats['maxSpeed'] ?? 0.0).toStringAsFixed(0)} km/h',
                      Icons.speed,
                      textPri, textSec, accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  Widget _buildStatItem(
      String label, String value, IconData icon,
      Color textPri, Color textSec, Color accent) {
    return Container(
      width: 105,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF14151A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 0.8),
                  duration: const Duration(milliseconds: 1500),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return CircularProgressIndicator(
                      value: value,
                      strokeWidth: 3,
                      strokeCap: StrokeCap.round,
                      color: accent,
                      backgroundColor: Colors.white12,
                    );
                  }
                ),
              ),
              Icon(icon, color: accent, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textPri,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: textSec),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrips(BuildContext context, String uid,
      Color textPri, Color textSec, Color bg, Color accent) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.recentTrips,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textPri,
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getUserTripsStream(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}',
                  style: TextStyle(color: textPri));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Card(
                color: bg,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      l10n.noTripsYet,
                      style: TextStyle(color: textSec),
                    ),
                  ),
                ),
              );
            }

            // Show only first 5 recent trips
            final trips = snapshot.data!.docs.take(5).toList();

            return Column(
              children: trips.map((doc) {
                final trip = doc.data() as Map<String, dynamic>;
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1F26).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20),
                    ],
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accent,
                      child: Icon(
                        _getVehicleIcon(trip['vehicleType']),
                        color: Colors.black,
                      ),
                    ),
                    title: Text(
                      '${trip['distance']?.toStringAsFixed(2) ?? '0.00'} km',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textPri,
                      ),
                    ),
                    subtitle: Text(
                      'Max: ${trip['maxSpeed']?.toStringAsFixed(0) ?? '0'} km/h • '
                      'Avg: ${trip['avgSpeed']?.toStringAsFixed(0) ?? '0'} km/h\n'
                      '${_formatDate(trip['timestamp'])}',
                      style: TextStyle(color: textSec),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFFF6B6B)), // Coral red
                      onPressed: () async {
                        final confirmed = await _showDeleteDialog(context);
                        if (confirmed == true) {
                          await FirestoreService().deleteTrip(doc.id);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  IconData _getVehicleIcon(String? vehicleType) {
    switch (vehicleType) {
      case 'motorcycle':
        return Icons.motorcycle;
      case 'car':
        return Icons.directions_car;
      case 'bicycle':
        return Icons.directions_bike;
      default:
        return Icons.directions;
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      final Timestamp ts = timestamp as Timestamp;
      final DateTime date = ts.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(l10n.deleteTrip, style: const TextStyle(color: Colors.white)),
        content: Text(
          l10n.confirmDelete,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
