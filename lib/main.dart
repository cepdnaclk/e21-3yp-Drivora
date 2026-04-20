import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/wifi_sensor_service.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DrivoraApp());
}

class DrivoraApp extends StatelessWidget {
  const DrivoraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<WiFiSensorService>(
          create: (_) => WiFiSensorService(),
        ),
      ],
      child: MaterialApp(
        title: 'DRIVORA - Driver Assistant',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: const MainApp(),
      ),
    );
  }
}

class MainApp extends StatefulWidget {
  const MainApp({Key? key}) : super(key: key);

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    // Initialize WiFi Sensor service
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sensorService =
          Provider.of<WiFiSensorService>(context, listen: false);
      await sensorService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DashboardScreen(),
    );
  }
}
