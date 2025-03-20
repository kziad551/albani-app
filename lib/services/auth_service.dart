import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final String _baseUrl = AppConfig.apiBaseUrl;
  final storage = const FlutterSecureStorage();
  
  // User state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  
  // Login method
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('Attempting login for user: $username to endpoint: $_baseUrl/api/Employees/login');
      
      // Try approach 1: Standard JSON request
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/Employees/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        ).timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        debugPrint('Login approach 1 - response status: ${response.statusCode}');
        if (response.body.length < 1000) {
          debugPrint('Login approach 1 - response body: ${response.body}');
        }
        
        if (response.statusCode == 200) {
          return _handleSuccessfulLogin(response);
        }
      } catch (e) {
        debugPrint('Login approach 1 failed: $e');
      }
      
      // Try approach 2: Form data
      try {
        debugPrint('Trying login approach 2 - form data');
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_baseUrl/api/Employees/login'),
        );
        
        request.fields['username'] = username;
        request.fields['password'] = password;
        
        final streamedResponse = await request.send().timeout(
          Duration(seconds: AppConfig.connectionTimeout)
        );
        
        final response = await http.Response.fromStream(streamedResponse);
        
        debugPrint('Login approach 2 - response status: ${response.statusCode}');
        if (response.body.length < 1000) {
          debugPrint('Login approach 2 - response body: ${response.body}');
        }
        
        if (response.statusCode == 200) {
          return _handleSuccessfulLogin(response);
        }
      } catch (e) {
        debugPrint('Login approach 2 failed: $e');
      }
      
      // Try approach 3: URL-encoded form
      try {
        debugPrint('Trying login approach 3 - url-encoded form');
        final response = await http.post(
          Uri.parse('$_baseUrl/api/Employees/login'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {
            'username': username,
            'password': password,
          },
        ).timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        debugPrint('Login approach 3 - response status: ${response.statusCode}');
        if (response.body.length < 1000) {
          debugPrint('Login approach 3 - response body: ${response.body}');
        }
        
        if (response.statusCode == 200) {
          return _handleSuccessfulLogin(response);
        }
      } catch (e) {
        debugPrint('Login approach 3 failed: $e');
      }
      
      // Try approach 4: Additional fields
      try {
        debugPrint('Trying login approach 4 - with additional fields');
        final response = await http.post(
          Uri.parse('$_baseUrl/api/Employees/login'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'username': username,
            'password': password,
            'rememberMe': true,
            'returnUrl': '/',
          }),
        ).timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        debugPrint('Login approach 4 - response status: ${response.statusCode}');
        if (response.body.length < 1000) {
          debugPrint('Login approach 4 - response body: ${response.body}');
        }
        
        if (response.statusCode == 200) {
          return _handleSuccessfulLogin(response);
        }
      } catch (e) {
        debugPrint('Login approach 4 failed: $e');
      }

      // If all approaches failed, check if we're in offline mode
      if (AppConfig.enableOfflineMode && username == 'SAdmin' && password == 'P@ssw0rd') {
        debugPrint('Using offline mode login');
        _isAuthenticated = true;
        _currentUser = {
          'id': 1,
          'name': 'Super Admin',
          'username': 'SAdmin',
          'email': 'admin@albani.com'
        };
        await storage.write(key: 'accessToken', value: 'mock-token-for-testing');
        return true;
      }
      
      debugPrint('All login approaches failed');
      _isAuthenticated = false;
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      _isAuthenticated = false;
      return false;
    }
  }
  
  // Helper method to handle successful login response
  Future<bool> _handleSuccessfulLogin(http.Response response) async {
    try {
      final data = jsonDecode(response.body);
      
      // Check if data is directly the response or inside a 'data' field
      final responseData = data is Map && data['data'] != null ? data['data'] : data;
      
      // Store tokens securely - matching website implementation
      if (responseData['accessToken'] != null) {
        await storage.write(key: 'accessToken', value: responseData['accessToken']);
        debugPrint('Stored access token');
      } else if (responseData['token'] != null) {
        await storage.write(key: 'accessToken', value: responseData['token']);
        debugPrint('Stored token as access token');
      }
      
      if (responseData['refreshToken'] != null) {
        await storage.write(key: 'refreshToken', value: responseData['refreshToken']);
        debugPrint('Stored refresh token');
      }
      
      // Set authenticated state
      _isAuthenticated = true;
      
      // Get user info
      await getCurrentUser();
      
      return true;
    } catch (e) {
      debugPrint('Error handling login response: $e');
      return false;
    }
  }
  
  // Logout method
  Future<void> logout() async {
    try {
      // Try to call the logout endpoint
      await http.post(
        Uri.parse('$_baseUrl/api/Employees/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
    } catch (e) {
      debugPrint('Logout API call failed: $e');
      // Continue with local logout even if API call fails
    }
    
    // Clear stored tokens
    await storage.delete(key: 'accessToken');
    await storage.delete(key: 'refreshToken');
    _isAuthenticated = false;
    _currentUser = null;
  }
  
  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated) return null;
    
    try {
      final token = await storage.read(key: 'accessToken');
      // Try the endpoint used by the website first
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/Employees/me'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ).timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final userData = data is Map && data['data'] != null ? data['data'] : data;
          _currentUser = userData;
          return userData;
        }
      } catch (e) {
        debugPrint('First endpoint for user info failed: $e');
        // Fall back to alternative endpoint
      }
      
      // Fall back to the original endpoint
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = data;
        return data;
      } else {
        return null;
      }
    } catch (e) {
      debugPrint('Get current user error: $e');
      return _currentUser; // Return cached user if available
    }
  }
  
  // Check if token is valid
  Future<bool> hasValidToken() async {
    final token = await storage.read(key: 'accessToken');
    if (token == null) return false;
    
    try {
      // Try the website's validation endpoint first
      try {
        final response = await http.get(
          Uri.parse('$_baseUrl/api/Employees/validate'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        ).timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        if (response.statusCode == 200) {
          _isAuthenticated = true;
          await getCurrentUser();
          return true;
        }
      } catch (e) {
        debugPrint('First token validation endpoint failed: $e');
        // Fall back to alternative endpoint
      }
      
      // Fall back to original endpoint
      final response = await http.get(
        Uri.parse('$_baseUrl/api/auth/validate'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      if (response.statusCode == 200) {
        _isAuthenticated = true;
        await getCurrentUser();
        return true;
      } else {
        _isAuthenticated = false;
        return false;
      }
    } catch (e) {
      debugPrint('Token validation error: $e');
      
      // For offline testing, consider the token valid if offline mode is enabled
      if (AppConfig.enableOfflineMode && token == 'mock-token-for-testing') {
        _isAuthenticated = true;
        return true;
      }
      
      return false;
    }
  }
} 