import 'package:flutter/material.dart';

/// A service to handle navigation without BuildContext
class NavigationService {
  // Singleton pattern
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();
  
  // Callback to be set by a widget that has navigation context
  VoidCallback? _logoutCallback;
  
  // Set callback from a widget that has navigation context
  void setLogoutCallback(VoidCallback callback) {
    _logoutCallback = callback;
  }
  
  // Navigate to login screen when token expires
  void navigateToLogin() {
    if (_logoutCallback != null) {
      _logoutCallback!();
    } else {
      debugPrint('Warning: Logout callback not set. Cannot navigate to login screen.');
    }
  }
} 