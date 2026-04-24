import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_service.dart';
import '../theme/app_theme.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('MY DRIVORA PROFILE'),
        backgroundColor: AppTheme.panel,
        elevation: 0,
      ),
      body: FutureBuilder<String?>(
        future: _getUserEmail(),
        builder: (context, emailSnapshot) {
          if (!emailSnapshot.hasData || emailSnapshot.data == null) {
            return const Center(child: Text('No User Registered'));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(emailSnapshot.data)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text('Profile not found in Cloud'));
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final calib = data['calibration'] as Map<String, dynamic>? ?? {};

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.accentBlue,
                      child: Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    _buildInfoCard('FULL NAME', data['name'] ?? 'N/A', Icons.person_outline),
                    _buildInfoCard('EMAIL ID', data['email'] ?? 'N/A', Icons.email_outlined),
                    _buildInfoCard('VEHICLE TYPE', data['carModel'] ?? 'N/A', Icons.directions_car_filled_outlined),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('VEHICLE CALIBRATION', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildMetricTile('HEIGHT', '${calib['height'] ?? "0.0"}m')),
                        const SizedBox(width: 16),
                        Expanded(child: _buildMetricTile('WIDTH', '${calib['width'] ?? "0.0"}m')),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<String?> _getUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
  }

  Widget _buildInfoCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.shadow,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentBlue, size: 24),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String val) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.accentBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentBlue)),
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
