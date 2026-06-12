import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/user_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/splash_screen.dart';
import 'services/wifi_sensor_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DrivoraApp());
}

class DrivoraApp extends StatelessWidget {
  const DrivoraApp({super.key});

  @override
  Widget build(BuildContext context) => MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider()..initializeUser(),
        ),
        ChangeNotifierProvider<WiFiSensorService>(
          create: (_) => WiFiSensorService()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'DRIVORA U-ADAS',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/landing': (_) => const LandingScreen(),
          '/login': (_) => const LoginScreen(),
          '/registration': (_) => const RegistrationScreen(),
          '/onboarding': (_) => const OnboardingScreen(),
          '/dashboard': (_) => const DashboardScreen(),
        },
      ),
    );
}
