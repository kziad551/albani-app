import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();
  
  final String _baseUrl = AppConfig.apiBaseUrl;
  final String _ipUrl = AppConfig.apiIpUrl; // Add fallback IP URL
  final storage = const FlutterSecureStorage();
  
  // User state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  
  // Login method
  Future<bool> login(String username, String password) async {
    try {
      debugPrint('\n=== Starting Login Process ===');
      debugPrint('Username: $username');
      debugPrint('Password length: ${password.length}');
      
      // Check internet connectivity first
      if (!await hasInternetConnection()) {
        debugPrint('No internet connection');
        throw Exception('No internet connection. Please check your network settings.');
      }

      // Create request body matching website format exactly
      final requestBody = {
        'Username': username,
        'Password': password,
        'RememberMe': true
      };

      debugPrint('Request body: ${jsonEncode(requestBody)}');

      // Create a Dio instance with SSL certificate handling
      final dio = Dio()
        ..options.baseUrl = AppConfig.apiBaseUrl
        ..options.connectTimeout = Duration(seconds: AppConfig.connectionTimeout)
        ..options.receiveTimeout = Duration(seconds: AppConfig.connectionTimeout)
        ..options.validateStatus = (status) => status! < 500;

      // Configure SSL certificate handling for release mode
      if (dio.httpClientAdapter is IOHttpClientAdapter) {
        (dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
          client.badCertificateCallback = (cert, host, port) {
            debugPrint('Validating certificate for $host:$port');
            return true; // Accept all certificates in release mode
          };
          return client;
        };
      }

      // Try domain URL first
      try {
        debugPrint('Attempting login with domain URL: ${AppConfig.apiBaseUrl}');
        final response = await dio.post(
          '/api/Employees/login',
          data: requestBody,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );

        debugPrint('Domain login response status: ${response.statusCode}');
        debugPrint('Domain login response data: ${response.data}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (response.data != null) {
            final data = response.data;
            final accessToken = data['accessToken'] ?? data['token'];
            
            if (accessToken != null) {
              await storage.write(key: 'accessToken', value: accessToken);
              await storage.write(key: 'token', value: accessToken);
              
              if (data['refreshToken'] != null) {
                await storage.write(key: 'refreshToken', value: data['refreshToken']);
              }
              
              _isAuthenticated = true;
              debugPrint('Login successful with domain URL');
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('Domain login attempt failed: $e');
      }

      // Try IP-based URL as fallback
      try {
        debugPrint('Attempting login with IP URL: ${AppConfig.apiIpUrl}');
        dio.options.baseUrl = AppConfig.apiIpUrl;
        
        final response = await dio.post(
          '/api/Employees/login',
          data: requestBody,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );

        debugPrint('IP login response status: ${response.statusCode}');
        debugPrint('IP login response data: ${response.data}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (response.data != null) {
            final data = response.data;
            final accessToken = data['accessToken'] ?? data['token'];
            
            if (accessToken != null) {
              await storage.write(key: 'accessToken', value: accessToken);
              await storage.write(key: 'token', value: accessToken);
              
              if (data['refreshToken'] != null) {
                await storage.write(key: 'refreshToken', value: data['refreshToken']);
              }
              
              _isAuthenticated = true;
              debugPrint('Login successful with IP URL');
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('IP login attempt failed: $e');
      }

      debugPrint('Login failed: Invalid credentials or server error');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> _tryLogin(Map<String, dynamic> requestBody, String baseUrl) async {
    HttpClient? client;
    try {
      debugPrint('\n=== Login Attempt Details ===');
      debugPrint('Base URL: $baseUrl');
      
      // Create headers based on whether we're using IP or domain
      final isIpBased = baseUrl.contains(AppConfig.apiIpAddress);
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/plain, */*',
        'Origin': 'https://albani.smartsoft-me.com',
        'Referer': 'https://albani.smartsoft-me.com/',
        'Host': 'albani.smartsoft-me.com', // Always use domain name in Host header
        'Connection': 'keep-alive'
      };

      final url = '$baseUrl/api/Employees/login';
      debugPrint('Full URL: $url');
      debugPrint('Request Headers:');
      headers.forEach((key, value) => debugPrint('  $key: $value'));

      // Log request body (excluding password)
      final logSafeBody = Map<String, dynamic>.from(requestBody);
      logSafeBody['password'] = '*****';
      debugPrint('Request Body: ${jsonEncode(logSafeBody)}');

      // Create a custom HTTP client that accepts the server's certificate
      client = HttpClient()
        ..badCertificateCallback = (X509Certificate cert, String host, int port) {
          debugPrint('Validating certificate for $host:$port');
          // Accept the certificate if it's our IP address
          if (host == AppConfig.apiIpAddress) {
            debugPrint('Accepting certificate for IP address');
            return true;
          }
          // For domain name, use normal validation
          return false;
        };

      final request = await client.postUrl(Uri.parse(url));
      headers.forEach((key, value) => request.headers.add(key, value));
      request.write(jsonEncode(requestBody));
      
      final httpResponse = await request.close();
      final responseBody = await httpResponse.transform(utf8.decoder).join();
      
      // Convert HttpHeaders to Map<String, String>
      final responseHeaders = <String, String>{};
      httpResponse.headers.forEach((name, values) {
        responseHeaders[name] = values.join(',');
      });
      
      final response = http.Response(responseBody, httpResponse.statusCode, headers: responseHeaders);

      debugPrint('\n=== Login Response Details ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers:');
      response.headers.forEach((key, value) => debugPrint('  $key: $value'));
      
      if (response.statusCode == 200) {
        debugPrint('Login successful, processing response body...');
        return await _handleSuccessfulLogin(response);
      } else if (response.statusCode == 301 || response.statusCode == 302) {
        // Handle redirection
        final location = response.headers['location'];
        debugPrint('Redirection detected to: $location');
        if (location != null) {
          // Follow the redirect manually
          final redirectResponse = await http.post(
            Uri.parse(location),
            headers: headers,
            body: jsonEncode(requestBody),
          );
          return await _handleSuccessfulLogin(redirectResponse);
        }
        return false;
      } else if (response.statusCode == 401) {
        debugPrint('Invalid credentials (401)');
        try {
          final errorBody = jsonDecode(response.body);
          debugPrint('Error Response: $errorBody');
        } catch (e) {
          debugPrint('Raw Error Response: ${response.body}');
        }
        return false;
      } else {
        debugPrint('Unexpected status code: ${response.statusCode}');
        try {
          final errorBody = jsonDecode(response.body);
          debugPrint('Error Response: $errorBody');
        } catch (e) {
          debugPrint('Raw Error Response: ${response.body}');
        }
        return false;
      }
    } catch (e) {
      debugPrint('\n=== Login Error Details ===');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Error Message: $e');
      if (e is http.ClientException) {
        debugPrint('Network Error Details: ${e.message}');
      }
      return false;
    } finally {
      client?.close();
    }
  }
  
  // Helper method to handle successful login response
  Future<bool> _handleSuccessfulLogin(http.Response response) async {
    try {
      debugPrint('\n=== Processing Login Response ===');
      final responseBody = response.body;
      debugPrint('Response Body Length: ${responseBody.length}');
      
      try {
        final data = jsonDecode(responseBody);
        debugPrint('JSON Parse Successful');
        debugPrint('Response Structure: ${data.runtimeType}');
        if (data is Map) {
          debugPrint('Available Keys: ${data.keys.toList()}');
        }
        
        String? token;
        Map<String, dynamic>? userData;
        
        if (data is Map) {
          // Try to find token
          if (data.containsKey('token')) {
            token = data['token'] as String?;
            debugPrint('Found token in root level');
          } else if (data.containsKey('data') && data['data'] is Map) {
            final dataMap = data['data'] as Map;
            token = dataMap['token'] as String?;
            userData = dataMap as Map<String, dynamic>;
            debugPrint('Found token in data object');
          } else if (data.containsKey('accessToken')) {
            token = data['accessToken'] as String?;
            debugPrint('Found token as accessToken');
          }
          
          if (userData == null) {
            userData = data as Map<String, dynamic>;
          }
        }
        
        if (token != null) {
          debugPrint('Token found (length: ${token.length})');
          await storage.write(key: 'accessToken', value: token);
          await storage.write(key: 'token', value: token);
          
          _isAuthenticated = true;
          _currentUser = userData;
          
          debugPrint('Stored token and updated authentication state');
          debugPrint('Fetching user details...');
          
          await getCurrentUser();
          return true;
        } else {
          debugPrint('No token found in response');
          debugPrint('Response Data: $data');
          return false;
        }
      } catch (jsonError) {
        debugPrint('JSON Parse Error: $jsonError');
        debugPrint('Raw Response: $responseBody');
        return false;
      }
    } catch (e) {
      debugPrint('Login Response Processing Error: $e');
      return false;
    }
  }
  
  // Logout method
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('No token available for logout');
      } else {
        debugPrint('Logging out with token');
        
        // Call the same endpoint as the website with the same headers
        try {
          // From the network tab, we can see the correct logout endpoint and headers
          final response = await http.post(
            Uri.parse('$_baseUrl/api/Employees/logout'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json, text/plain, */*',
              'Authorization': 'Bearer $token',
              'Origin': 'https://albani.smartsoft-me.com',
              'Referer': 'https://albani.smartsoft-me.com/',
              'Host': 'albani.smartsoft-me.com',
              'Connection': 'keep-alive'
            },
          ).timeout(Duration(seconds: AppConfig.connectionTimeout));
          
          debugPrint('Logout response: ${response.statusCode}');
        } catch (e) {
          debugPrint('Logout API call failed: $e');
          // Continue with local logout even if API call fails
        }
      }
    } catch (e) {
      debugPrint('Logout operation error: $e');
    } finally {
      // Always clear tokens and user data locally
      debugPrint('Clearing local authentication data');
      await storage.delete(key: 'accessToken');
      await storage.delete(key: 'refreshToken');
      await storage.delete(key: 'token');
      _isAuthenticated = false;
      _currentUser = null;
      
      debugPrint('Logout complete');
    }
  }
  
  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated) return null;
    
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('No token available for getCurrentUser');
        return null;
      }
      
      // Use the exact endpoint from network tab: /api/Employees/info
      debugPrint('Fetching user info from: $_baseUrl/api/Employees/info');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/api/Employees/info'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/plain, */*',
          'Authorization': 'Bearer $token',
          'Origin': 'https://albani.smartsoft-me.com',
          'Referer': 'https://albani.smartsoft-me.com/',
          'Host': 'albani.smartsoft-me.com',
          'Connection': 'keep-alive'
        },
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      debugPrint('User info response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          if (data['data'] != null) {
            _currentUser = data['data'] as Map<String, dynamic>;
          } else {
            _currentUser = data as Map<String, dynamic>;
          }
          
          debugPrint('Retrieved user info: ${_currentUser!['username'] ?? 'unknown'}');
          return _currentUser;
        }
      } else if (response.statusCode == 401) {
        // Token expired or invalid
        _isAuthenticated = false;
        return null;
      }
      
      return _currentUser; // Return cached user if available
    } catch (e) {
      debugPrint('Get current user error: $e');
      return _currentUser; // Return cached user if available
    }
  }
  
  // Check if token is valid
  Future<bool> validateToken() async {
    try {
      debugPrint('\n=== Token Validation Started ===');
      
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        debugPrint('No internet connection for token validation');
        return false;
      }
      
      final token = await storage.read(key: 'accessToken');
      if (token == null || token.isEmpty) {
        debugPrint('No token available to validate');
        return false;
      }

      // Create HttpClient with custom settings
      final client = HttpClient()
        ..connectionTimeout = Duration(seconds: 30)
        ..badCertificateCallback = (cert, host, port) {
          debugPrint('Validating certificate for $host:$port');
          return true; // Accept all certificates for now
        };

      try {
        debugPrint('Attempting token validation with domain URL');
        final request = await client.getUrl(
          Uri.parse('${AppConfig.apiBaseUrl}/api/Employees/validate')
        );
        
        // Add headers
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('Accept', 'application/json');
        request.headers.set('Host', 'albani.smartsoft-me.com');
        
        final response = await request.close();
        if (response.statusCode == 200) {
          debugPrint('Token validated successfully with domain URL');
          return true;
        }
      } catch (e) {
        debugPrint('Domain-based validation failed: $e');
      }

      // If domain validation fails, try IP-based validation
      try {
        debugPrint('Attempting token validation with IP URL');
        final request = await client.getUrl(
          Uri.parse('${AppConfig.apiIpUrl}/api/Employees/validate')
        );
        
        // Add headers
        request.headers.set('Authorization', 'Bearer $token');
        request.headers.set('Accept', 'application/json');
        request.headers.set('Host', 'albani.smartsoft-me.com');
        
        final response = await request.close();
        if (response.statusCode == 200) {
          debugPrint('Token validated successfully with IP URL');
          return true;
        }
      } catch (e) {
        debugPrint('IP-based validation failed: $e');
      } finally {
        client.close();
      }

      debugPrint('All token validation attempts failed');
      return false;
    } catch (e) {
      debugPrint('Error validating token: $e');
      return false;
    }
  }

  Future<String?> getToken() async {
    try {
      // Get the token and type
      final token = await storage.read(key: 'accessToken') ?? await storage.read(key: 'token');
      if (token == null) return null;

      // Get the token type (default to Bearer if not found)
      final tokenType = await storage.read(key: 'tokenType') ?? 'Bearer';
      
      // Return properly formatted token
      return '$tokenType $token';
    } catch (e) {
      debugPrint('Error getting token: $e');
      return null;
    }
  }

  // Check for internet connectivity
  Future<bool> hasInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Try to reach the server domain
      try {
        final response = await Dio().head(AppConfig.apiBaseUrl);
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint('Error checking domain connectivity: $e');
      }

      // Try to reach the server IP as fallback
      try {
        final response = await Dio().head(AppConfig.apiIpUrl);
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint('Error checking IP connectivity: $e');
      }

      return false;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }
} 