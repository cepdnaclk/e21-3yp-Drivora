import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/wifi_sensor_service.dart';
import '../services/cloud_service.dart';
import '../providers/user_provider.dart';
import 'dashboard_screen.dart';
import 'dart:math' as math;

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _carModelController = TextEditingController();
  final _vehicleTypeController = TextEditingController();
  final _heightController = TextEditingController(text: '1.5');
  final _widthController = TextEditingController(text: '1.8');
  
  late AnimationController _animationController;
  bool _isRegistering = false;
  String? _errorMessage;

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
    _vehicleTypeController.dispose();
    _heightController.dispose();
    _widthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // Background Tech Art
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => CustomPaint(
                  painter: _TechArtPainter(rotation: _animationController.value),
                ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    _buildHeader(),
                    const SizedBox(height: 32),
                    
                    // ERROR MESSAGE
                    if (_errorMessage != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.accentRed.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.accentRed, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.accentRed,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // DRIVER INFO SECTION
                    _buildSectionTitle('DRIVER INFORMATION'),
                    const SizedBox(height: 12),
                    _buildInputLabel('FULL NAME'),
                    _buildTextField('John Doe', Icons.person_outline, _nameController, validator: _validateName),
                    const SizedBox(height: 16),
                    _buildInputLabel('EMAIL ADDRESS'),
                    _buildTextField('john@example.com', Icons.email_outlined, _emailController, validator: _validateEmail),
                    const SizedBox(height: 24),
                    
                    // VEHICLE INFO SECTION
                    _buildSectionTitle('VEHICLE CONFIGURATION'),
                    const SizedBox(height: 12),
                    _buildInputLabel('VEHICLE TYPE'),
                    _buildTextField('Sedan / SUV / Truck', Icons.directions_car_outlined, _vehicleTypeController, validator: _validateRequired),
                    const SizedBox(height: 16),
                    _buildInputLabel('VEHICLE MODEL'),
                    _buildTextField('Tesla Model 3', Icons.build_circle_outlined, _carModelController, validator: _validateRequired),
                    const SizedBox(height: 16),
                    
                    // CALIBRATION SECTION
                    _buildSectionTitle('VEHICLE CALIBRATION'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('HEIGHT (meters)'),
                              _buildTextField('1.5', Icons.height, _heightController, isNumber: true, validator: _validateNumber),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('WIDTH (meters)'),
                              _buildTextField('1.8', Icons.width_normal, _widthController, isNumber: true, validator: _validateNumber),
                            ],
                          ),
                        ),
                      ],
                    ),
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

  String? _validateRequired(String? value) {
    if (value == null || value.isEmpty) return 'FIELD REQUIRED';
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) return 'NAME REQUIRED';
    if (value.length < 2) return 'NAME TOO SHORT';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'EMAIL REQUIRED';
    if (!value.contains('@')) return 'INVALID EMAIL FORMAT';
    return null;
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return 'VALUE REQUIRED';
    final num = double.tryParse(value);
    if (num == null) return 'INVALID NUMBER';
    if (num <= 0) return 'VALUE MUST BE POSITIVE';
    return null;
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: GoogleFonts.rajdhani(
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      fontSize: 11,
      color: AppTheme.accentCyan,
    ),
  );

  Widget _buildHeader() => Column(
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

  Widget _buildInputLabel(String label) => Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: GoogleFonts.orbitron(
          fontSize: 10,
          letterSpacing: 1.5,
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );

  Widget _buildTextField(String hint, IconData icon, TextEditingController controller, {bool isNumber = false, String? Function(String?)? validator}) => Container(
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
        validator: validator,
      ),
    );

  Widget _buildCreateAccountButton() => Container(
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
        onPressed: _isRegistering ? null : _handleRegistration,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          disabledBackgroundColor: Colors.transparent,
        ),
        child: _isRegistering
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              )
            : Text(
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

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _errorMessage = 'Please fill all fields correctly');
      return;
    }

    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });

    try {
      final height = double.parse(_heightController.text);
      final width = double.parse(_widthController.text);

      print('🔴 Registration: Starting registration for ${_emailController.text}...');
      
      // 1. Save user data to Firebase Cloud
      final cloud = CloudService();
      final registered = await cloud.registerUserFirebase(
        name: _nameController.text,
        email: _emailController.text,
        carModel: _carModelController.text,
        height: height,
        width: width,
      );

      if (!registered) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Firebase registration failed. Check your connection.';
            _isRegistering = false;
          });
        }
        return;
      }

      print('🔴 Registration: Firebase registration successful');

      // 2. Save calibration data to Firebase
      if (mounted) {
        final cloud = CloudService();
        final onboardingSaved = await cloud.saveOnboardingData(
          driverName: _nameController.text,
          driverEmail: _emailController.text,
          driverExperience: 'NOT SET',
          vehicleType: _vehicleTypeController.text,
          vehicleModel: _carModelController.text,
          vehicleHeight: height,
          vehicleWidth: width,
          alertSensitivity: 5,
          audioVolume: 5,
          soundProfiles: const {
            'collision': 0,
            'lane': 1,
            'prox': 2,
            'lean': 3,
          },
        );
        print('🔴 Registration: Onboarding saved to Firebase: $onboardingSaved');
      }

      // 3. Update UserProvider with new registration data
      if (mounted) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        print('🔴 Registration: Calling userProvider.initializeUser()...');
        await userProvider.initializeUser();
        print('🔴 Registration: After initializeUser, isUserRegistered=${userProvider.isUserRegistered}, email=${userProvider.userEmail}');
      }

      // 4. Send Calibration directly to ESP32 Hardware (fire and forget)
      if (mounted) {
        final sensorService = Provider.of<WiFiSensorService>(context, listen: false);
        sensorService.sendCalibrationToHardware(
          height: height,
          width: width,
        );
      }

      // 5. Navigate to Dashboard
      if (mounted) {
        print('🔴 Registration: Navigating to Dashboard...');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Registration Successful! Welcome ${_nameController.text}'),
            backgroundColor: AppTheme.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        });
      }
    } catch (e) {
      print('🔴 Registration Error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Registration error: ${e.toString().split('\n').first}';
          _isRegistering = false;
        });
      }
    }
  }
}

class _TechArtPainter extends CustomPainter {
  _TechArtPainter({required this.rotation});
  final double rotation;

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
      canvas.drawCircle(markerPos, 4, Paint()..color = AppTheme.accentBlue.withOpacity(0.1));
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
