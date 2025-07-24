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
import 'firebase_service.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal() {
    // Initialize Dio instance with appropriate configurations
    _dio = Dio()
      ..options.baseUrl = AppConfig.apiBaseUrl
      ..options.connectTimeout = Duration(seconds: AppConfig.connectionTimeout)
      ..options.receiveTimeout = Duration(seconds: AppConfig.connectionTimeout)
      ..options.validateStatus = (status) => status! < 500;

    // Configure SSL certificate handling
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) {
          debugPrint('Validating certificate for $host:$port');
          return true; // Accept all certificates in release mode
        };
        return client;
      };
    }
  }
  
  final String _baseUrl = AppConfig.apiBaseUrl;
  final String _ipUrl = AppConfig.apiIpUrl; // Add fallback IP URL
  final storage = const FlutterSecureStorage();
  late final Dio _dio; // Dio instance for HTTP requests
  
  // User state
  bool _isAuthenticated = false;
  Map<String, dynamic>? _currentUser;
  
  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get currentUser => _currentUser;
  
  // Login method
  Future<bool> login(String username, String password, {bool rememberMe = true}) async {
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
        'RememberMe': rememberMe
      };

      debugPrint('Request body: ${jsonEncode(requestBody)}');

      // Try domain URL first
      try {
        debugPrint('Attempting login with domain URL: ${AppConfig.apiBaseUrl}');
        final response = await _dio.post(
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
              
              // Store user data if available
              try {
                // Check if user data is in the response
                if (data['user'] != null) {
                  final userData = data['user'] as Map<String, dynamic>;
                  _currentUser = userData;
                  
                  // Store important user fields
                  if (userData['name'] != null) {
                    await storage.write(key: 'userName', value: userData['name']);
                  }
                  if (userData['userName'] != null || userData['username'] != null) {
                    await storage.write(key: 'username', value: userData['userName'] ?? userData['username']);
                  }
                  if (userData['role'] != null) {
                    await storage.write(key: 'userRole', value: userData['role']);
                  }
                  debugPrint('Stored user data from login response');
                } else {
                  // Try to get user information immediately after login
                  await getCurrentUser();
                }
              } catch (e) {
                debugPrint('Error storing user data: $e');
              }
              
              _isAuthenticated = true;
              debugPrint('Login successful with domain URL');
              
              // Register FCM token with backend
              try {
                debugPrint('🔥🔥🔥 [AUTH] Initializing Firebase Service after login...');
                final firebaseService = FirebaseService();
                await firebaseService.initialize();
                debugPrint('🔥 [AUTH] Firebase Service initialized, registering FCM token...');
                final registrationResult = await firebaseService.registerTokenWithBackend();
                debugPrint('🔥 [AUTH] FCM token registration result: $registrationResult');
              } catch (e) {
                debugPrint('⚠️⚠️⚠️ [AUTH] FCM token registration failed: $e');
                // Don't fail login if FCM registration fails
              }
              
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
        _dio.options.baseUrl = AppConfig.apiIpUrl;
        
        final response = await _dio.post(
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
              
              // Store user data if available
              try {
                // Check if user data is in the response
                if (data['user'] != null) {
                  final userData = data['user'] as Map<String, dynamic>;
                  _currentUser = userData;
                  
                  // Store important user fields
                  if (userData['name'] != null) {
                    await storage.write(key: 'userName', value: userData['name']);
                  }
                  if (userData['userName'] != null || userData['username'] != null) {
                    await storage.write(key: 'username', value: userData['userName'] ?? userData['username']);
                  }
                  if (userData['role'] != null) {
                    await storage.write(key: 'userRole', value: userData['role']);
                  }
                  debugPrint('Stored user data from login response (IP-based)');
                } else {
                  // Try to get user information immediately after login
                  await getCurrentUser();
                }
              } catch (e) {
                debugPrint('Error storing user data: $e');
              }
              
              _isAuthenticated = true;
              debugPrint('Login successful with IP URL');
              
              // Register FCM token with backend
              try {
                debugPrint('🔥🔥🔥 [AUTH] Initializing Firebase Service after IP login...');
                final firebaseService = FirebaseService();
                await firebaseService.initialize();
                debugPrint('🔥 [AUTH] Firebase Service initialized, registering FCM token...');
                final registrationResult = await firebaseService.registerTokenWithBackend();
                debugPrint('🔥 [AUTH] FCM token registration result: $registrationResult');
              } catch (e) {
                debugPrint('⚠️⚠️⚠️ [AUTH] FCM token registration failed: $e');
                // Don't fail login if FCM registration fails
              }
              
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
      debugPrint('🚪 Logging out user...');
        
      // Unregister FCM token
      try {
        final firebaseService = FirebaseService();
        await firebaseService.unregisterToken();
        debugPrint('🔥 FCM token unregistered on logout');
        } catch (e) {
        debugPrint('⚠️ FCM token cleanup failed: $e');
        // Don't fail logout if FCM cleanup fails
        }
      
      // Preserve saved credentials if Remember Me was checked
      final savedUsername = await storage.read(key: 'saved_username');
      final savedPassword = await storage.read(key: 'saved_password');
      await storage.deleteAll();
      if (savedUsername != null && savedPassword != null) {
        await storage.write(key: 'saved_username', value: savedUsername);
        await storage.write(key: 'saved_password', value: savedPassword);
      }
      
      // Reset authentication state
      _isAuthenticated = false;
      _currentUser = null;
      
      debugPrint('✅ User logged out successfully');
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      // Even if there's an error, clear local state
      _isAuthenticated = false;
      _currentUser = null;
    }
  }
  
  // Get current user info
  Future<Map<String, dynamic>?> getCurrentUser() async {
    if (!_isAuthenticated) {
      debugPrint('Not authenticated, returning null from getCurrentUser');
      return null;
    }
    
    try {
      final token = await storage.read(key: 'accessToken') ?? await storage.read(key: 'token');
      if (token == null) {
        debugPrint('No token available for getCurrentUser');
        return null;
      }
      
      debugPrint('Using token for getCurrentUser: ${token.substring(0, min(10, token.length))}...');
      
      // First, try to fetch from domain URL
      try {
        debugPrint('Fetching user info from domain URL: $_baseUrl/api/Employees/info');
        
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
        
        debugPrint('User info response status from domain: ${response.statusCode}');
        debugPrint('User info response body: ${response.body.substring(0, min(100, response.body.length))}...');
        
        if (response.statusCode == 200) {
          return _processUserResponse(response.body);
        }
      } catch (e) {
        debugPrint('Error fetching user from domain URL: $e');
      }
      
      // If domain URL fails, try IP URL
      try {
        debugPrint('Fetching user info from IP URL: $_ipUrl/api/Employees/info');
        
        final response = await http.get(
          Uri.parse('$_ipUrl/api/Employees/info'),
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
        
        debugPrint('User info response status from IP: ${response.statusCode}');
        debugPrint('User info response body from IP: ${response.body.substring(0, min(100, response.body.length))}...');
        
        if (response.statusCode == 200) {
          return _processUserResponse(response.body);
        }
      } catch (e) {
        debugPrint('Error fetching user from IP URL: $e');
      }
      
      // As a last resort, try to fetch the user profile endpoint
      try {
        debugPrint('Trying alternative endpoint: $_baseUrl/api/Employees/profile');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/api/Employees/profile'),
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
        
        debugPrint('User profile response status: ${response.statusCode}');
        debugPrint('User profile response body: ${response.body.substring(0, min(100, response.body.length))}...');
        
        if (response.statusCode == 200) {
          return _processUserResponse(response.body);
        }
      } catch (e) {
        debugPrint('Error fetching user profile: $e');
      }
      
      // Return cached user if available or null
      debugPrint('All API attempts failed, trying to load from secure storage');
      
      // Try to load user data from secure storage
      if (_currentUser == null) {
        try {
          final storedName = await storage.read(key: 'userName');
          final storedUsername = await storage.read(key: 'username');
          final storedRole = await storage.read(key: 'userRole');
          
          if (storedName != null || storedUsername != null) {
            _currentUser = {
              'name': storedName ?? 'User',
              'userName': storedUsername ?? 'user',
              'username': storedUsername ?? 'user',
              'role': storedRole ?? 'User',
            };
            debugPrint('Loaded user data from secure storage: $_currentUser');
          }
        } catch (e) {
          debugPrint('Error loading user data from secure storage: $e');
        }
      }
      
      debugPrint('Returning cached user: $_currentUser');
      return _currentUser;
    } catch (e) {
      debugPrint('Get current user error: $e');
      return _currentUser; // Return cached user if available
    }
  }
  
  // Helper to process user response
  Map<String, dynamic>? _processUserResponse(String responseBody) {
    try {
      debugPrint('Processing user response: ${responseBody.substring(0, min(100, responseBody.length))}...');
      
      final data = jsonDecode(responseBody);
      if (data is Map) {
        if (data['data'] != null) {
          _currentUser = data['data'] as Map<String, dynamic>;
          debugPrint('Found user in data field: ${_currentUser.toString().substring(0, min(100, _currentUser.toString().length))}...');
        } else if (data['result'] != null) {
          _currentUser = data['result'] as Map<String, dynamic>;
          debugPrint('Found user in result field');
        } else {
          _currentUser = data as Map<String, dynamic>;
          debugPrint('Using entire response as user data');
        }
        
        // Debug available fields
        debugPrint('Available user fields: ${_currentUser!.keys.toList()}');
        
        // Try to get username/name from various possible fields
        final username = _currentUser!['username'] ?? 
                         _currentUser!['userName'] ?? 
                         _currentUser!['Username'] ?? 
                         _currentUser!['UserName'] ?? 'unknown';
                         
        final name = _currentUser!['name'] ?? 
                    _currentUser!['Name'] ?? 
                    _currentUser!['fullName'] ?? 
                    _currentUser!['displayName'] ?? username;
                    
        debugPrint('Retrieved user info - Name: $name, Username: $username');
        
        return _currentUser;
      } else {
        debugPrint('Response is not a Map: ${data.runtimeType}');
        return null;
      }
    } catch (e) {
      debugPrint('Error processing user response: $e');
      return null;
    }
  }
  
  // Validate token on app start
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

      // Try to check token validity and refresh if needed
      try {
        // First try using common auth validation endpoint
        final validationResponse = await _dio.get(
          '/api/Employees/validate',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        
        // Check if token is valid
        if (validationResponse.statusCode == 200) {
          debugPrint('Token validated successfully');
          return true;
        } 
        
        // If token is invalid or expired (401), try to refresh it
        if (validationResponse.statusCode == 401) {
          debugPrint('Token validation failed (401), attempting to refresh token');
          
          // Try to refresh token - Implementation depends on API's refresh mechanism
          final refreshToken = await storage.read(key: 'refreshToken');
          if (refreshToken != null) {
            try {
              final refreshResponse = await _dio.post(
                '/api/Employees/refreshToken',
                data: {
                  'refreshToken': refreshToken,
                },
                options: Options(
                  validateStatus: (status) => true,
                ),
              );
              
              if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
                final refreshData = refreshResponse.data;
                
                // Extract new tokens
                final newToken = refreshData['accessToken'] ?? refreshData['token'];
                final newRefreshToken = refreshData['refreshToken'];
                
                if (newToken != null) {
                  // Save the new tokens
                  await storage.write(key: 'accessToken', value: newToken);
                  await storage.write(key: 'token', value: newToken);
                  
                  if (newRefreshToken != null) {
                    await storage.write(key: 'refreshToken', value: newRefreshToken);
                  }
                  
                  debugPrint('Token refreshed successfully');
                  return true;
                }
              }
            } catch (e) {
              debugPrint('Error refreshing token: $e');
            }
          }
          
          // If refresh fails, user needs to login again
          debugPrint('Token refresh failed, user needs to login again');
          return false;
        }
      } catch (e) {
        debugPrint('Error during token validation: $e');
      }
      
      // If we reached here, the token could not be validated
      debugPrint('Token validation failed');
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