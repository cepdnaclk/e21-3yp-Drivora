import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
<<<<<<< HEAD
=======
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
import 'services/wifi_sensor_service.dart';
import 'theme/app_theme.dart';
import 'screens/registration_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
<<<<<<< HEAD
=======
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
>>>>>>> 6db0122 (Added/Updated drivora project inside code/software/drivora)
  runApp(const DrivoraApp());
}

class DrivoraApp extends StatelessWidget {
  const DrivoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WiFiSensorService>(
          create: (_) => WiFiSensorService()..initialize(),
        ),
      ],
      child: MaterialApp(
        title: 'DRIVORA U-ADAS',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const RegistrationScreen(),
      ),
    );
  }
}
