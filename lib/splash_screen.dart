import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Set system UI properties
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    
    // Immediately navigate to login
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    // Skip showing any UI and navigate directly to login
    // This avoids showing a second splash screen
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;

    // Navigate to login screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Return an empty container instead of showing another splash
    return const Scaffold(
      backgroundColor: Colors.white,
    );
  }
} 