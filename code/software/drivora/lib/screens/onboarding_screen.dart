import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../services/wifi_sensor_service.dart';
import '../services/cloud_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentStep = 0;
  final int _totalSteps = 6;

  // Form data
  String _driverName = '';
  String _driverExperience = 'Experienced';
  String _vehicleType = 'Sedan';
  String _vehicleModel = '';
  double _vehicleHeight = 1.5;
  double _vehicleWidth = 1.8;
  int _alertSensitivity = 5;
  int _audioVolume = 7;
  final bool _calibrationComplete = false;
  bool _hardwareDetected = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _setupAnimations();
    _checkHardwareConnection();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
  }

  void _checkHardwareConnection() async {
    // Simulate checking if hardware is available
    // In real implementation, check WiFiSensorService connection
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _hardwareDetected = true;
      });
    }
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final cloudService = CloudService();
    final success = await cloudService.saveOnboardingData(
      driverName: _driverName,
      driverExperience: _driverExperience,
      vehicleType: _vehicleType,
      vehicleModel: _vehicleModel,
      vehicleHeight: _vehicleHeight,
      vehicleWidth: _vehicleWidth,
      alertSensitivity: _alertSensitivity,
      audioVolume: _audioVolume,
    );

    if (!mounted) {
      return;
    }

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    await userProvider.initializeUser();

    final wifiService = Provider.of<WiFiSensorService>(context, listen: false);
    await wifiService.sendCalibrationToHardware(
      height: _vehicleHeight,
      width: _vehicleWidth,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacementNamed('/dashboard');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentStep = index;
              });
              _fadeController.forward(from: 0);
            },
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildWelcomeStep(),
              _buildUserDataStep(),
              _buildVehicleDataStep(),
              _buildSensorCalibrationStep(),
              _buildHardwareCheckStep(),
              _buildReadyStep(),
            ],
          ),

          // Progress indicator
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: _buildProgressIndicator(),
          ),

          // Navigation buttons
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildNavigationButtons(),
          ),
        ],
      ),
    );

  Widget _buildProgressIndicator() => SafeArea(
      child: Column(
        children: [
          // Step counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SETUP WIZARD',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppTheme.accentCyan,
                ),
              ),
              Text(
                'STEP ${_currentStep + 1} / $_totalSteps',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Container(
            height: 4,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              widthFactor: (_currentStep + 1) / _totalSteps,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppTheme.blueGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );

  Widget _buildWelcomeStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.shield_rounded,
                size: 100,
                color: AppTheme.accentCyan,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to DRIVORA',
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your Universal Advanced Driver Assistance System',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              _buildFeatureItem('🎯 Real-time collision detection'),
              _buildFeatureItem('⚠️ Lane departure warnings'),
              _buildFeatureItem('🔄 Advanced vehicle monitoring'),
              _buildFeatureItem('🎵 Intelligent audio alerts'),
            ],
          ),
        ),
      ),
    );

  Widget _buildUserDataStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              Text(
                'Driver Information',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                label: 'Full Name',
                hintText: 'Enter your name',
                onChanged: (value) => _driverName = value,
              ),
              const SizedBox(height: 20),
              _buildDropdown(
                label: 'Driving Experience',
                value: _driverExperience,
                items: ['Beginner', 'Intermediate', 'Experienced', 'Professional'],
                onChanged: (value) => setState(() => _driverExperience = value),
              ),
            ],
          ),
        ),
      ),
    );

  Widget _buildVehicleDataStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              Text(
                'Vehicle Information',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              _buildDropdown(
                label: 'Vehicle Type',
                value: _vehicleType,
                items: ['Sedan', 'SUV', 'Truck', 'Hatchback', 'Wagon', 'Sports'],
                onChanged: (value) => setState(() => _vehicleType = value),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'Model/Name',
                hintText: 'e.g., Tesla Model 3',
                onChanged: (value) => _vehicleModel = value,
              ),
              const SizedBox(height: 20),
              _buildSliderField(
                label: 'Vehicle Height (m)',
                value: _vehicleHeight,
                min: 1,
                max: 2.5,
                onChanged: (value) => setState(() => _vehicleHeight = value),
              ),
              const SizedBox(height: 20),
              _buildSliderField(
                label: 'Vehicle Width (m)',
                value: _vehicleWidth,
                min: 1.5,
                max: 2.5,
                onChanged: (value) => setState(() => _vehicleWidth = value),
              ),
            ],
          ),
        ),
      ),
    );

  Widget _buildSensorCalibrationStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              Text(
                'Sensor Configuration',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderBlue),
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.surfaceElevated,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Alert Sensitivity',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _alertSensitivity.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      label: _alertSensitivity.toString(),
                      onChanged: (value) => setState(() => _alertSensitivity = value.toInt()),
                      activeColor: AppTheme.accentCyan,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Low', style: GoogleFonts.rajdhani(fontSize: 11, color: AppTheme.textMuted)),
                        Text('High', style: GoogleFonts.rajdhani(fontSize: 11, color: AppTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderBlue),
                  borderRadius: BorderRadius.circular(16),
                  color: AppTheme.surfaceElevated,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Volume',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Slider(
                      value: _audioVolume.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: _audioVolume.toString(),
                      onChanged: (value) => setState(() => _audioVolume = value.toInt()),
                      activeColor: AppTheme.accentCyan,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  Widget _buildHardwareCheckStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              Text(
                'Hardware Check',
                style: GoogleFonts.orbitron(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 40),
              _buildHardwareStatus('Front Unit', true),
              const SizedBox(height: 16),
              _buildHardwareStatus('Center Unit', _hardwareDetected),
              const SizedBox(height: 16),
              _buildHardwareStatus('Rear Unit', true),
              const SizedBox(height: 16),
              _buildHardwareStatus('Lane Unit', false),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentAmber),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.accentAmber.withOpacity(0.1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.accentAmber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ensure all hardware units are powered and connected to the same WiFi network.',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  Widget _buildReadyStep() => FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 100),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: 100,
                color: AppTheme.accentGreen,
              ),
              const SizedBox(height: 32),
              Text(
                'All Set!',
                style: GoogleFonts.orbitron(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your DRIVORA system is ready.',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.accentGreen),
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.accentGreen.withOpacity(0.1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Driver: $_driverName',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vehicle: $_vehicleModel ($_vehicleType)',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Dimensions: ${_vehicleHeight.toStringAsFixed(2)}m H × ${_vehicleWidth.toStringAsFixed(2)}m W',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

  // Helper widgets
  Widget _buildTextField({
    required String label,
    required String hintText,
    required Function(String) onChanged,
  }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          onChanged: onChanged,
          style: GoogleFonts.rajdhani(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.rajdhani(color: AppTheme.textMuted),
            filled: true,
            fillColor: AppTheme.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.borderBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentCyan, width: 2),
            ),
          ),
        ),
      ],
    );

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required Function(String) onChanged,
  }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderBlue),
            color: AppTheme.surfaceElevated,
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: const SizedBox.shrink(),
            value: value,
            items: items.map((item) => DropdownMenuItem(
                value: item,
                child: Text(item, style: GoogleFonts.rajdhani(color: AppTheme.textPrimary)),
              )).toList(),
            onChanged: (val) => onChanged(val!),
            dropdownColor: AppTheme.surfaceElevated,
          ),
        ),
      ],
    );

  Widget _buildSliderField({
    required String label,
    required double value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              '${value.toStringAsFixed(2)} m',
              style: GoogleFonts.rajdhani(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.accentCyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: value,
          min: min,
          max: max,
          onChanged: onChanged,
          activeColor: AppTheme.accentCyan,
        ),
      ],
    );

  Widget _buildFeatureItem(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(text, style: GoogleFonts.rajdhani(fontSize: 14, color: AppTheme.textPrimary)),
        ],
      ),
    );

  Widget _buildHardwareStatus(String name, bool online) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: online ? AppTheme.accentGreen : AppTheme.accentAmber),
        borderRadius: BorderRadius.circular(12),
        color: (online ? AppTheme.accentGreen : AppTheme.accentAmber).withOpacity(0.1),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online ? AppTheme.accentGreen : AppTheme.accentAmber,
              boxShadow: [
                BoxShadow(
                  color: (online ? AppTheme.accentGreen : AppTheme.accentAmber).withOpacity(0.5),
                  blurRadius: 8,
                )
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            online ? 'CONNECTED' : 'WAITING',
            style: GoogleFonts.rajdhani(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: online ? AppTheme.accentGreen : AppTheme.accentAmber,
            ),
          ),
        ],
      ),
    );

  Widget _buildNavigationButtons() => SafeArea(
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderBlue),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _previousStep,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: Text(
                        'BACK',
                        style: GoogleFonts.rajdhani(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentBlue,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.blueGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppTheme.neonShadow(AppTheme.accentBlue),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _nextStep,
                  borderRadius: BorderRadius.circular(12),
                  child: Center(
                    child: Text(
                      _currentStep == _totalSteps - 1 ? 'COMPLETE SETUP' : 'NEXT',
                      style: GoogleFonts.rajdhani(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
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
