import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/permission_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const WallRingApp());
}

class WallRingApp extends StatelessWidget {
  const WallRingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WallRing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),
          secondary: Color(0xFFFFD166),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        fontFamily: 'Roboto',
      ),
      home: const PermissionGateScreen(),
    );
  }
}
