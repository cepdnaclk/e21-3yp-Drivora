import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
<<<<<<< HEAD
import '../theme/app_theme.dart';
import 'home_premium_screen.dart';
=======
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/wifi_sensor_service.dart';
import '../services/cloud_service.dart';
import 'dashboard_screen.dart';
import 'dart:math' as math;
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

<<<<<<< HEAD
class _RegistrationScreenState extends State<RegistrationScreen> {
=======
class _RegistrationScreenState extends State<RegistrationScreen> with SingleTickerProviderStateMixin {
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _carModelController = TextEditingController();
<<<<<<< HEAD
=======
  final _heightController = TextEditingController();
  final _widthController = TextEditingController();

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _carModelController.dispose();
    _heightController.dispose();
    _widthController.dispose();
    super.dispose();
  }
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
<<<<<<< HEAD
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.background, const Color(0xFFEFEFF2)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accentBlue, AppTheme.accentGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.shadowLg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'JOIN DRIVORA',
                          style: GoogleFonts.orbitron(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Advanced Driver Assistance System',
                          style: GoogleFonts.rajdhani(
                            fontSize: 13,
                            color: Colors.white70,
                            letterSpacing: 1,
=======
      body: Stack(
        children: [
          // Background Tech Art
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _TechArtPainter(rotation: _animationController.value),
                );
              },
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildInputLabel('FULL NAME'),
                    _buildTextField('John Doe', Icons.person_outline, _nameController),
                    const SizedBox(height: 16),
                    _buildInputLabel('EMAIL ADDRESS'),
                    _buildTextField('john@drivora.io', Icons.email_outlined, _emailController),
                    const SizedBox(height: 16),
                    _buildInputLabel('VEHICLE TYPE'),
                    _buildTextField('Tesla Model 3 / Truck', Icons.directions_car_filled_outlined, _carModelController),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('HEIGHT (m)'),
                              _buildTextField('1.5', Icons.height, _heightController, isNumber: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('WIDTH (m)'),
                              _buildTextField('1.8', Icons.straighten, _widthController, isNumber: true),
                            ],
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
                          ),
                        ),
                      ],
                    ),
<<<<<<< HEAD
                  ),
                  const SizedBox(height: 50),
                  
                  // Form Section
                  Text(
                    'VEHICLE INFORMATION',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildTextField('FULL NAME', Icons.person_outline, _nameController),
                  const SizedBox(height: 18),
                  _buildTextField('EMAIL ADDRESS', Icons.email_outlined, _emailController),
                  const SizedBox(height: 18),
                  _buildTextField('VEHICLE MODEL', Icons.directions_car_filled_outlined, _carModelController),
                  
                  const SizedBox(height: 50),
                  
                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const HomePremiumScreen()),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 12,
                        shadowColor: AppTheme.accentBlue.withOpacity(0.6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CREATE ACCOUNT',
                            style: GoogleFonts.orbitron(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Footer
                  Center(
                    child: Text(
                      'Your vehicle data is secure and encrypted',
                      style: GoogleFonts.rajdhani(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
=======
                    const SizedBox(height: 40),
                    _buildCreateAccountButton(),
                    const SizedBox(height: 30),
                    Center(
                      child: Text(
                        'DRIVORA U-ADAS CORE V1.0',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: AppTheme.textSecondary.withOpacity(0.4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.textPrimary,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.shadow,
          ),
          child: const Icon(Icons.shield_rounded, color: AppTheme.accentGreen, size: 32),
        ),
        const SizedBox(height: 24),
        Text(
          'Activate Shield',
          style: GoogleFonts.rajdhani(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            height: 1.1,
          ),
        ),
        Text(
          'UNIVERSAL ADAS INTERFACE',
          style: GoogleFonts.orbitron(
            fontSize: 12,
            letterSpacing: 3,
            color: AppTheme.accentBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.orbitron(
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
        ),
      ),
    );
  }

<<<<<<< HEAD
  Widget _buildTextField(String label, IconData icon, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.rajdhani(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.orbitron(
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
        hintStyle: GoogleFonts.rajdhani(
          color: AppTheme.textSecondary.withOpacity(0.6),
        ),
        prefixIcon: Icon(icon, color: AppTheme.accentBlue, size: 22),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: AppTheme.border,
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.accentBlue,
            width: 2.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.accentRed,
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppTheme.accentRed,
            width: 2.5,
          ),
        ),
        filled: true,
        fillColor: AppTheme.panel,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'This field is required';
        }
        if (label == 'EMAIL ADDRESS' && !value.contains('@')) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }
}
=======
  Widget _buildTextField(String hint, IconData icon, TextEditingController controller, {bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.panel,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.shadow,
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.rajdhani(
          fontSize: 16,
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.3)),
          prefixIcon: Icon(icon, color: AppTheme.accentBlue, size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
        validator: (value) => value!.isEmpty ? 'FIELD REQUIRED' : null,
      ),
    );
  }

  Widget _buildCreateAccountButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppTheme.accentBlue, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentBlue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          if (_formKey.currentState!.validate()) {
            final double height = double.tryParse(_heightController.text) ?? 1.5;
            final double width = double.tryParse(_widthController.text) ?? 1.8;
            
            // 1. Save user data to Firebase Cloud
            final cloud = CloudService();
            await cloud.registerUserFirebase(
              name: _nameController.text,
              email: _emailController.text,
              carModel: _carModelController.text,
              height: height,
              width: width,
            );

            // 2. Send Calibration directly to ESP32 Hardware (fire and forget)
            final sensorService = Provider.of<WiFiSensorService>(context, listen: false);
            sensorService.sendCalibrationToHardware(
              height: height,
              width: width,
            );

            // 3. Always navigate to Dashboard (Real-time Demo will start from there)
            if (mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen()));
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          'INITIALIZE SYSTEM',
          style: GoogleFonts.orbitron(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _TechArtPainter extends CustomPainter {
  final double rotation;
  _TechArtPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentBlue.withOpacity(0.03)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.8, size.height * 0.2);

    // Draw rotating tech rings
    for (var i = 0; i < 3; i++) {
      final radius = 100.0 + (i * 40.0);
      canvas.drawCircle(center, radius, paint);

      // Draw markers on rings
      final angle = (rotation * 2 * math.pi) + (i * math.pi / 4);
      final markerPos = center + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      canvas.drawCircle(markerPos, 4.0, Paint()..color = AppTheme.accentBlue.withOpacity(0.1));
    }

    // Draw grid lines
    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(0.01)
      ..strokeWidth = 0.5;

    for (var i = 0.0; i < size.width; i += 40.0) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (var i = 0.0; i < size.height; i += 40.0) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
