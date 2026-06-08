import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure provider refresh when screen first appears
    print('🔵 AccountScreen.initState: Scheduling provider refresh...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        print('🔵 AccountScreen: Calling initializeUser() from post-frame callback');
        userProvider.initializeUser();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user data when screen comes to focus
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.initializeUser();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'MY DRIVORA PROFILE',
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        backgroundColor: AppTheme.panel,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Profile',
            onPressed: () {
              final userProvider =
                  Provider.of<UserProvider>(context, listen: false);
              userProvider.initializeUser();
            },
          ),
        ],
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, _) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!userProvider.isUserRegistered) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 80,
                    color: AppTheme.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NO PROFILE FOUND',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please complete registration first',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          if (userProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 80,
                    color: AppTheme.accentRed,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      userProvider.error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => userProvider.initializeUser(),
                    child: const Text('RETRY'),
                  ),
                ],
              ),
            );
          }

          final cloudData = userProvider.cloudData ?? {};
          final calib = cloudData['calibration'] as Map<String, dynamic>? ?? {};
          final onboarding =
              cloudData['onboarding'] as Map<String, dynamic>? ?? {};

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                Center(
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.accentBlue,
                        child: Icon(Icons.person,
                            size: 60, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        userProvider.userName?.toUpperCase() ?? 'DRIVER',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SYSTEM OPERATOR',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: AppTheme.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Driver Information Section
                _buildSectionTitle('DRIVER INFORMATION'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'FULL NAME',
                  userProvider.userName ?? 'NOT SET',
                  Icons.person_outline,
                ),
                _buildInfoCard(
                  'EMAIL',
                  userProvider.userEmail ?? 'NOT SET',
                  Icons.email_outlined,
                ),
                _buildInfoCard(
                  'EXPERIENCE LEVEL',
                  userProvider.driverExperience ?? 'NOT SET',
                  Icons.school_outlined,
                ),
                const SizedBox(height: 24),

                // Vehicle Information Section
                _buildSectionTitle('VEHICLE CONFIGURATION'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  'VEHICLE TYPE',
                  userProvider.vehicleType ?? 'NOT SET',
                  Icons.directions_car_outlined,
                ),
                _buildInfoCard(
                  'VEHICLE MODEL',
                  userProvider.vehicleModel ?? 'NOT SET',
                  Icons.build_circle_outlined,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        'HEIGHT',
                        '${(userProvider.vehicleHeight ?? 0.0).toStringAsFixed(2)}m',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildMetricTile(
                        'WIDTH',
                        '${(userProvider.vehicleWidth ?? 0.0).toStringAsFixed(2)}m',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // System Settings Section
                _buildSectionTitle('SYSTEM SETTINGS'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSettingTile(
                        'ALERT SENSITIVITY',
                        '${userProvider.alertSensitivity ?? 0}/10',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSettingTile(
                        'AUDIO VOLUME',
                        '${userProvider.audioVolume ?? 0}/10',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Cloud Sync Status
                _buildSectionTitle('SYNC STATUS'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done,
                          color: AppTheme.accentGreen, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATA SYNCHRONIZED',
                              style: GoogleFonts.rajdhani(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                                color: AppTheme.accentGreen,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Profile saved to Local & Firebase Cloud',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );

  Widget _buildSectionTitle(String title) => Text(
      title,
      style: GoogleFonts.rajdhani(
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        fontSize: 11,
        color: AppTheme.textSecondary,
      ),
    );

  Widget _buildInfoCard(String label, String value, IconData icon) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentBlue, size: 22),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildMetricTile(String label, String value) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );

  Widget _buildSettingTile(String label, String value) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentAmber.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentAmber.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentAmber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
}
