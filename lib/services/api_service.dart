import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http_parser/http_parser.dart';
import '../utils/navigation_service.dart';

class ApiService {
  final String _baseUrl = AppConfig.apiBaseUrl;
  final String _ipUrl = AppConfig.apiIpUrl; // Add fallback IP URL
  final Dio _dio = Dio();
  final AuthService _authService = AuthService();
  final NavigationService _navigationService = NavigationService();
  
  // Flag for mock mode - use same value as AppConfig
  bool get _mockMode => AppConfig.enableOfflineMode;
  
  ApiService() {
    _dio.options.baseUrl = _baseUrl;
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    // Configure timeouts
    _dio.options.connectTimeout = Duration(seconds: AppConfig.connectionTimeout);
    _dio.options.receiveTimeout = Duration(seconds: AppConfig.connectionTimeout);
    _dio.options.sendTimeout = Duration(seconds: AppConfig.connectionTimeout);
    
    // Configure SSL certificate handling for Android
    if (_dio.httpClientAdapter is IOHttpClientAdapter) {
      (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
    
    // Add logging interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          debugPrint('\n=== API Request Details ===');
          debugPrint('URL: ${options.uri}');
          debugPrint('Method: ${options.method}');
          debugPrint('Headers: ${options.headers}');
          return handler.next(options);
        },
        onResponse: (response, handler) async {
          debugPrint('\n=== API Response Details ===');
          debugPrint('Status Code: ${response.statusCode}');
          debugPrint('Headers: ${response.headers}');
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          debugPrint('\n=== API Error Details ===');
          debugPrint('Error Type: ${e.type}');
          debugPrint('Error Message: ${e.message}');
          debugPrint('Status Code: ${e.response?.statusCode}');
          debugPrint('Response Data: ${e.response?.data}');
          return handler.next(e);
        },
      ),
    );
  }
  
  final storage = const FlutterSecureStorage();
  
  // Helper method to get headers with auth token
  Future<Map<String, String>> _getHeaders() async {
    final token = await storage.read(key: 'accessToken');
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Check for internet connectivity
  Future<bool> hasInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }
  
  // Validate token on app start
  Future<bool> validateToken() async {
    try {
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

      // Try domain-based validation first
      try {
        debugPrint('Attempting token validation with domain URL');
        final response = await _dio.get(
          '$_baseUrl/api/Employees/validate',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
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
        final response = await _dio.get(
          '$_ipUrl/api/Employees/validate',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': 'albani.smartsoft-me.com',
            },
            validateStatus: (status) => true,
          ),
        );
        if (response.statusCode == 200) {
          debugPrint('Token validated successfully with IP URL');
          return true;
        }
      } catch (e) {
        debugPrint('IP-based validation failed: $e');
      }

      debugPrint('All token validation attempts failed');
      return false;
    } catch (e) {
      debugPrint('Error validating token: $e');
      return false;
    }
  }
  
  // Helper method for handling API responses
  dynamic _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        try {
          return jsonDecode(response.body);
        } catch (e) {
          debugPrint('Error decoding response body: $e');
          return {'success': true, 'rawBody': response.body};
        }
      }
      return {'success': true};
    } else if (response.statusCode == 401) {
      debugPrint('Received 401 Unauthorized response');
      
      // First try to validate the token
      final isValid = await validateToken();
      if (!isValid) {
        debugPrint('Token validation failed, logging out');
        await _handleTokenExpiration();
        throw Exception('Unauthorized: Please log in again');
      } else {
        debugPrint('Token is valid despite 401, retrying operation');
        throw Exception('Please retry the operation');
      }
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }
  
  // Handle expired token
  Future<void> _handleTokenExpiration() async {
    debugPrint('Handling token expiration');
    try {
      // Clear stored tokens and reset auth state using AuthService
      await _authService.logout();
      
      // Navigate to login screen
      _navigationService.navigateToLogin();
    } catch (e) {
      debugPrint('Error handling token expiration: $e');
    }
  }
  
  // GET request with retry logic
  Future<dynamic> get(String endpoint) async {
    // First check internet connection
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection');
    }
    
    int attempts = 0;
    late http.Response response;
    late Exception lastException;
    
    while (attempts < AppConfig.maxRetryAttempts) {
      try {
        attempts++;
        final headers = await _getHeaders();
        final uri = Uri.parse('$_baseUrl/$endpoint');
        
        if (AppConfig.debugApiCalls) {
          debugPrint('GET Request to: $uri');
        }
        
        response = await http.get(
          uri,
          headers: headers,
        ).timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
        
        if (AppConfig.debugApiCalls) {
          debugPrint('GET Response (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...');
        }
        
        return _handleResponse(response);
      } catch (e) {
        lastException = Exception('GET request error: $e');
        debugPrint('GET request failed (attempt $attempts): $e');
        
        // Wait before retrying
        if (attempts < AppConfig.maxRetryAttempts) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }
    
    throw lastException;
  }
  
  // POST request with retry logic
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    // First check internet connection
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection');
    }
    
    int attempts = 0;
    late Exception lastException;
    
    while (attempts < AppConfig.maxRetryAttempts) {
      try {
        attempts++;
        final headers = await _getHeaders();
        final response = await http.post(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: headers,
          body: jsonEncode(data),
        ).timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
        
        return _handleResponse(response);
      } catch (e) {
        lastException = Exception('POST request error: $e');
        debugPrint('POST request failed (attempt $attempts): $e');
        
        // Wait before retrying
        if (attempts < AppConfig.maxRetryAttempts) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }
    
    throw lastException;
  }
  
  // PUT request with retry logic
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    // First check internet connection
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection');
    }
    
    int attempts = 0;
    late Exception lastException;
    
    while (attempts < AppConfig.maxRetryAttempts) {
      try {
        attempts++;
        final headers = await _getHeaders();
        final response = await http.put(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: headers,
          body: jsonEncode(data),
        ).timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
        
        return _handleResponse(response);
      } catch (e) {
        lastException = Exception('PUT request error: $e');
        debugPrint('PUT request failed (attempt $attempts): $e');
        
        // Wait before retrying
        if (attempts < AppConfig.maxRetryAttempts) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }
    
    throw lastException;
  }
  
  // DELETE request with retry logic
  Future<dynamic> delete(String endpoint) async {
    // First check internet connection
    final hasInternet = await hasInternetConnection();
    if (!hasInternet) {
      throw Exception('No internet connection');
    }
    
    int attempts = 0;
    late Exception lastException;
    
    while (attempts < AppConfig.maxRetryAttempts) {
      try {
        attempts++;
        final headers = await _getHeaders();
        final response = await http.delete(
          Uri.parse('$_baseUrl/$endpoint'),
          headers: headers,
        ).timeout(Duration(seconds: AppConfig.apiTimeoutSeconds));
        
        return _handleResponse(response);
      } catch (e) {
        lastException = Exception('DELETE request error: $e');
        debugPrint('DELETE request failed (attempt $attempts): $e');
        
        // Wait before retrying
        if (attempts < AppConfig.maxRetryAttempts) {
          await Future.delayed(Duration(seconds: attempts));
        }
      }
    }
    
    throw lastException;
  }
  
  // API methods for projects
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Fetching projects from server');
      
      // Get token without Bearer prefix as we'll add it in the headers
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // Try domain-based URL first
      try {
        debugPrint('Attempting to fetch projects using domain URL');
        final response = await _dio.get(
          '/api/Projects/GetUserProjects',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Projects response status: ${response.statusCode}');
        debugPrint('Projects response body: ${response.data}');

        if (response.statusCode == 200) {
          if (response.data is List) {
            return List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              return List<Map<String, dynamic>>.from(data['result']);
            }
          }
        }
      } catch (e) {
        debugPrint('Domain-based projects fetch failed: $e');
      }
      
      // If domain-based request fails, try IP-based URL
      try {
        debugPrint('Attempting to fetch projects using IP URL');
        _dio.options.baseUrl = AppConfig.apiIpUrl;
        
        final response = await _dio.get(
          '/api/Projects/GetUserProjects',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        if (response.statusCode == 200) {
          if (response.data is List) {
            return List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              return List<Map<String, dynamic>>.from(data['result']);
            }
          }
        }
        
        debugPrint('IP-based projects fetch response: ${response.statusCode}');
        debugPrint('Response body: ${response.data}');
      } catch (e) {
        debugPrint('IP-based projects fetch failed: $e');
      } finally {
        // Reset base URL back to domain
        _dio.options.baseUrl = AppConfig.apiBaseUrl;
      }
      
      throw Exception('Failed to fetch projects from both domain and IP');
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      throw Exception('Failed to load projects: $e');
    }
  }
  
  Future<Map<String, dynamic>> getProjectById(dynamic projectId) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Getting project by ID: $projectId');
      
      // Use the exact same endpoint the website uses
      final response = await _dio.get('/api/Projects/byGuid', 
        queryParameters: {
          'Guid': projectId.toString(),
          'Includes': 'Buckets'
        }
      );
      
      debugPrint('Project response status: ${response.statusCode}');
      
      if (response.data == null) {
        debugPrint('Project response is null');
        throw Exception('Project not found.');
      }
      
      // Try to load from direct user projects if the response doesn't have buckets
      if (response.statusCode == 200) {
        // Make sure buckets are properly formatted as a list
        final projectData = Map<String, dynamic>.from(response.data);
        
        debugPrint('Project data contains these keys: ${projectData.keys.join(', ')}');
        
        // Check if buckets are included
        if (!projectData.containsKey('buckets') || projectData['buckets'] == null) {
          debugPrint('Project data doesn\'t contain buckets, trying to get them separately');
          
          // Try to get buckets directly
          try {
            final projectGuid = projectData['guid'] ?? projectId;
            final buckets = await getBuckets(projectId: projectGuid);
            
            if (buckets.isNotEmpty) {
              debugPrint('Successfully loaded ${buckets.length} buckets separately');
              projectData['buckets'] = buckets;
            } else {
              debugPrint('No buckets found separately');
            }
          } catch (e) {
            debugPrint('Error getting buckets separately: $e');
          }
        } else {
          // Handle different bucket formats
          if (projectData['buckets'] != null && projectData['buckets'] is! List) {
            try {
              if (projectData['buckets'] is String) {
                // Try to parse as JSON
                final bucketsJson = jsonDecode(projectData['buckets'] as String);
                if (bucketsJson is List) {
                  projectData['buckets'] = bucketsJson;
                } else {
                  projectData['buckets'] = [bucketsJson];
                }
                debugPrint('Parsed buckets from string');
              } else if (projectData['buckets'] is Map) {
                // If it's a single object, wrap it in a list
                projectData['buckets'] = [projectData['buckets']];
                debugPrint('Wrapped single bucket in list');
              }
            } catch (e) {
              debugPrint('Error parsing buckets: $e');
              projectData['buckets'] = [];
            }
          }
        }
        
        return projectData;
      }
      
      throw Exception('Failed to get project details (Status: ${response.statusCode})');
    } catch (e) {
      debugPrint('Error getting project by ID: $e');
      throw Exception('Failed to get project details: $e');
    }
  }
  
  // Get standard bucket structure - these are predefined buckets used by the website
  List<Map<String, dynamic>> getStandardBuckets() {
    return [
      {
        'id': 'architecture',
        'guid': 'architecture-bucket',
        'name': 'Architecture',
        'title': 'ARCHITECTURE',
        'description': 'Architecture documents and tasks',
        'line': 1,
      },
      {
        'id': 'structural',
        'guid': 'structural-bucket',
        'name': 'Structural Design',
        'title': 'STRUCTURAL DESIGN',
        'description': 'Structural design documents and tasks',
        'line': 2,
      },
      {
        'id': 'boq',
        'guid': 'boq-bucket',
        'name': 'Bill Of Quantity',
        'title': 'BILL OF QUANTITY',
        'description': 'Bill of quantities and cost estimation',
        'line': 3,
      },
      {
        'id': 'management',
        'guid': 'management-bucket',
        'name': 'Project Management',
        'title': 'PROJECT MANAGEMENT',
        'description': 'Project management documents and tasks',
        'line': 4,
      },
      {
        'id': 'mechanical',
        'guid': 'mechanical-bucket',
        'name': 'Electro-Mechanical Design',
        'title': 'ELECTRO-MECHANICAL DESIGN',
        'description': 'Electrical and mechanical engineering',
        'line': 5,
      },
      {
        'id': 'onsite',
        'guid': 'onsite-bucket',
        'name': 'On Site',
        'title': 'ON SITE',
        'description': 'On-site construction documents and tasks',
        'line': 6,
      },
      {
        'id': 'client',
        'guid': 'client-bucket',
        'name': 'Client Section',
        'title': 'CLIENT SECTION',
        'description': 'Client-specific documents and tasks',
        'line': 7,
      },
    ];
  }
  
  Future<List<Map<String, dynamic>>> getBuckets({dynamic projectId}) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      // Get token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      // If no project ID, just return the standard buckets
      if (projectId == null) {
        debugPrint('No project ID provided, returning standard buckets');
        return getStandardBuckets();
      }
      
      debugPrint('Getting buckets for project: $projectId');
      
      try {
        final response = await _dio.get(
          '/api/Buckets/GetProjectBuckets',
          queryParameters: {'ProjectGuid': projectId.toString()},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Buckets response status: ${response.statusCode}');
        debugPrint('Buckets response data: ${response.data}');

        if (response.statusCode == 200) {
          List<Map<String, dynamic>> buckets = [];
          
          if (response.data is List) {
            buckets = List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              buckets = List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              buckets = List<Map<String, dynamic>>.from(data['result']);
            }
          }
          
          // If we got buckets from the API, return those
          if (buckets.isNotEmpty) {
            debugPrint('Returning ${buckets.length} buckets from API');
            return buckets;
          }
        }
      } catch (e) {
        debugPrint('Error getting project buckets: $e');
      }
      
      // If we couldn't get buckets from the API or the API returned no buckets,
      // return the standard buckets with the project ID attached
      final standardBuckets = getStandardBuckets().map((bucket) {
        return {
          ...bucket,
          'projectId': projectId.toString(),
          'projectGuid': projectId.toString(),
        };
      }).toList();
      
      debugPrint('Returning standard buckets with project ID attached');
      return standardBuckets;
    } catch (e) {
      debugPrint('Error getting buckets: $e');
      return getStandardBuckets();
    }
  }
  
  // Get bucket files from the API
  Future<List<Map<String, dynamic>>> getBucketFiles(String bucketGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      // Don't try to fetch data for placeholder buckets
      if (bucketGuid.contains('-bucket')) {
        debugPrint('Skipping file fetch for placeholder bucket: $bucketGuid');
        return [];
      }
      
      debugPrint('Getting files for bucket: $bucketGuid');
      
      // Get token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      try {
        final response = await _dio.get(
          '/api/Attachments/GetAttachmentsByBucket',
          queryParameters: {'BucketGuid': bucketGuid},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Files response status: ${response.statusCode}');
        debugPrint('Files response data: ${response.data}');

        if (response.statusCode == 200) {
          if (response.data is List) {
            return List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              return List<Map<String, dynamic>>.from(data['result']);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching bucket files: $e');
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting bucket files: $e');
      return [];
    }
  }
  
  // Get bucket tasks from the API
  Future<List<Map<String, dynamic>>> getBucketTasks(String bucketGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      if (bucketGuid.contains('-bucket')) {
        debugPrint('Skipping task fetch for placeholder bucket: $bucketGuid');
        return [];
      }
      
      debugPrint('Getting tasks for bucket: $bucketGuid');
      
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      try {
        final response = await _dio.get(
          '/api/BucketTasks/GetBucketTasks',
          queryParameters: {'BucketGuid': bucketGuid},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Tasks response status: ${response.statusCode}');
        debugPrint('Tasks response data: ${response.data}');

        if (response.statusCode == 200) {
          List<Map<String, dynamic>> tasks = [];
          
          if (response.data is List) {
            tasks = List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              tasks = List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              tasks = List<Map<String, dynamic>>.from(data['result']);
            }
          }

          // Format the assigned user data
          return tasks.map((task) {
            // Extract assigned user info
            String assignedTo = 'Unassigned';
            if (task['assignedTo'] != null) {
              if (task['assignedTo'] is Map) {
                assignedTo = task['assignedTo']['displayName'] ?? 
                           task['assignedTo']['name'] ?? 
                           'Unknown User';
              } else if (task['employee'] != null && task['employee'] is Map) {
                assignedTo = task['employee']['displayName'] ?? 
                           task['employee']['name'] ?? 
                           'Unknown User';
              }
            }

            return {
              ...task,
              'assignedToName': assignedTo,
              'displayAssignee': assignedTo,
            };
          }).toList();
        }
      } catch (e) {
        debugPrint('Error fetching bucket tasks: $e');
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting bucket tasks: $e');
      return [];
    }
  }
  
  // API methods for users
  Future<List<Map<String, dynamic>>> getUsers({int? page, int? pageSize}) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Fetching users, page: $page, pageSize: $pageSize');
      
      // Try with pagination parameters if provided
      String endpoint = 'api/Employees';
      if (page != null && pageSize != null) {
        endpoint = '$endpoint?page=$page&pageSize=$pageSize';
      }
      
      final response = await get(endpoint);
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response['result'] != null && response['result'] is List) {
          return List<Map<String, dynamic>>.from(response['result']);
        } else if (response['items'] != null && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        } else if (response['employees'] != null && response['employees'] is List) {
          return List<Map<String, dynamic>>.from(response['employees']);
        }
      }
      
      // If no valid response, return empty list
      debugPrint('No users found in any response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching users: $e');
      throw Exception('Failed to load users: $e');
    }
  }
  
  // API methods for logs
  Future<List<Map<String, dynamic>>> getLogs({
    String? userName,
    String? entityName,
    String? action,
    DateTime? fromDate,
    DateTime? toDate,
    int? page,
    int? pageSize = 100,
  }) async {
    try {
      // Construct query parameters
      final Map<String, String> queryParams = {};
      
      if (userName != null && userName.isNotEmpty) {
        queryParams['userName'] = userName;
      }
      if (entityName != null && entityName.isNotEmpty) {
        queryParams['entityName'] = entityName;
      }
      if (action != null && action.isNotEmpty) {
        queryParams['action'] = action;
      }
      if (fromDate != null) {
        queryParams['fromDate'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        queryParams['toDate'] = toDate.toIso8601String();
      }
      
      // Add pagination parameters
      queryParams['page'] = (page ?? 1).toString();
      queryParams['pageSize'] = (pageSize ?? 100).toString();
      
      // Build query string
      String queryString = '';
      if (queryParams.isNotEmpty) {
        queryString = '?' + queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      }
      
      final response = await get('api/AuditLog$queryString');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response['items'] != null && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting logs: $e');
      return [];
    }
  }
  
  // Create or update a bucket
  Future<Map<String, dynamic>> createBucket(Map<String, dynamic> bucketData) async {
    try {
      final response = await post('api/Buckets', {'command': bucketData});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      } else if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Failed to create bucket: Invalid response format');
    } catch (e) {
      debugPrint('Error creating bucket: $e');
      
      if (AppConfig.enableOfflineMode) {
        // Create a mock bucket with a new ID and GUID
        return {
          ...bucketData,
          'id': DateTime.now().microsecondsSinceEpoch,
          'guid': DateTime.now().millisecondsSinceEpoch.toString(),
        };
      }
      
      rethrow;
    }
  }
  
  // Update a bucket
  Future<Map<String, dynamic>> updateBucket(Map<String, dynamic> bucketData) async {
    try {
      final id = bucketData['id'] ?? bucketData['guid'];
      final response = await put('api/Buckets/$id', {'command': bucketData});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      } else if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Failed to update bucket: Invalid response format');
    } catch (e) {
      debugPrint('Error updating bucket: $e');
      
      if (AppConfig.enableOfflineMode) {
        return {
          ...bucketData,
          'lastModified': DateTime.now().toIso8601String(),
        };
      }
      
      rethrow;
    }
  }
  
  // Delete a bucket
  Future<void> deleteBucket(String bucketGuid) async {
    try {
      await delete('api/Buckets?guid=$bucketGuid');
    } catch (e) {
      debugPrint('Error deleting bucket: $e');
      
      if (!AppConfig.enableOfflineMode) {
        rethrow;
      }
    }
  }
  
  // Get users assigned to a bucket
  Future<List<Map<String, dynamic>>> getBucketEmployees(String bucketGuid) async {
    try {
      final response = await get('api/Buckets/GetBucketEmployees?bucketGuid=$bucketGuid');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map && response['data'] != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching bucket employees: $e');
      return [];
    }
  }
  
  // Create mock data for a project to ensure UI works even without server
  void ensureProjectHasData(dynamic projectId) async {
    // Method removed since offline mode is disabled
    // This functionality is no longer needed
    debugPrint('ensureProjectHasData is disabled - server data will be used instead');
  }
  
  // Create new project
  Future<Map<String, dynamic>> createProject(Map<String, dynamic> project) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      final response = await post('api/Projects', {'command': project});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      } else if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Failed to create project: Invalid response format');
    } catch (e) {
      debugPrint('Error creating project: $e');
      throw Exception('Failed to create project: $e');
    }
  }
  
  // Update existing project
  Future<Map<String, dynamic>> updateProject(dynamic id, Map<String, dynamic> project) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      final response = await put('api/Projects/$id', {'command': project});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      } else if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Failed to update project: Invalid response format');
    } catch (e) {
      debugPrint('Error updating project: $e');
      throw Exception('Failed to update project: $e');
    }
  }
  
  // Delete a project
  Future<void> deleteProject(dynamic id) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      await delete('api/Projects/$id');
    } catch (e) {
      debugPrint('Error deleting project: $e');
      throw Exception('Failed to delete project: $e');
    }
  }
  
  // Get project employees
  Future<List<Map<String, dynamic>>> getProjectEmployees(String projectGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Getting employees for project: $projectGuid');
      
      // Get token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }
      
      // First try to get employees specifically assigned to this project
      final response = await _dio.get(
        '/api/Projects/GetProjectEmployees', 
        queryParameters: {'projectGuid': projectGuid.toString()},
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Host': AppConfig.apiHost,
          },
        ),
      );
      
      debugPrint('Project employees response status: ${response.statusCode}');
      
      List<Map<String, dynamic>> employees = [];
      
      if (response.statusCode == 200 && response.data != null) {
        if (response.data is List) {
          employees = List<Map<String, dynamic>>.from(response.data);
          debugPrint('Retrieved ${employees.length} employees for project');
        } else if (response.data is Map && response.data['data'] != null) {
          employees = List<Map<String, dynamic>>.from(response.data['data']);
          debugPrint('Retrieved ${employees.length} employees for project from data field');
        }
      }
      
      // If we couldn't get project-specific employees or if the list is empty,
      // fall back to getting all users
      if (employees.isEmpty) {
        debugPrint('No project-specific employees found, getting all users');
        try {
          final allUsersResponse = await get('api/Employees');
          
          if (allUsersResponse is List) {
            employees = List<Map<String, dynamic>>.from(allUsersResponse);
          } else if (allUsersResponse is Map) {
            if (allUsersResponse['data'] != null && allUsersResponse['data'] is List) {
              employees = List<Map<String, dynamic>>.from(allUsersResponse['data']);
            } else if (allUsersResponse['result'] != null && allUsersResponse['result'] is List) {
              employees = List<Map<String, dynamic>>.from(allUsersResponse['result']);
            } else if (allUsersResponse['items'] != null && allUsersResponse['items'] is List) {
              employees = List<Map<String, dynamic>>.from(allUsersResponse['items']);
            } else if (allUsersResponse['employees'] != null && allUsersResponse['employees'] is List) {
              employees = List<Map<String, dynamic>>.from(allUsersResponse['employees']);
            }
          }
          
          debugPrint('Retrieved ${employees.length} users from all users endpoint');
        } catch (e) {
          debugPrint('Error fetching all users: $e');
        }
      }
      
      return employees;
    } catch (e) {
      debugPrint('Error getting project employees: $e');
      // Try to get all users as a last resort
      try {
        final allUsers = await getUsers();
        debugPrint('Falling back to ${allUsers.length} users from getUsers method');
        return allUsers;
      } catch (e2) {
        debugPrint('Error getting all users: $e2');
        return [];
      }
    }
  }
  
  // Create a new task
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> taskData) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      final bucketGuid = taskData['bucketId'];
      if (bucketGuid == null) {
        throw Exception('Bucket ID is required');
      }
      
      debugPrint('Creating task in bucket: $bucketGuid');
      debugPrint('Task data: $taskData');
      
      // Format the task data as expected by the API
      final apiTaskData = {
        'command': {  // Wrap in command object as required by API
          'title': taskData['title'],
          'description': taskData['description'] ?? '',
          'status': taskData['status'] ?? 'Pending',
          'priority': taskData['priority'] ?? 'Medium',
          'assignedTo': taskData['assignedTo'],
          'bucketGuid': bucketGuid,
          'dueDate': taskData['dueDate'],
        }
      };
      
      // Print the request data for debugging
      debugPrint('API request data: ${jsonEncode(apiTaskData)}');
      
      // Try first implementation - standard API endpoint
      try {
        // Use the standard POST method with the correct endpoint
        final response = await post('api/BucketTasks', apiTaskData);
        
        debugPrint('Task creation response: $response');
        
        if (response != null) {
          Map<String, dynamic> createdTask;
          
          if (response is Map) {
            if (response['data'] != null) {
              createdTask = Map<String, dynamic>.from(response['data']);
            } else {
              createdTask = Map<String, dynamic>.from(response);
            }
            debugPrint('Task created successfully: ${createdTask['id'] ?? createdTask['guid']}');
            return createdTask;
          }
        }
      } catch (e) {
        debugPrint('First task creation attempt failed: $e, trying alternative method');
      }
      
      // Try second implementation - alternative endpoint format
      try {
        // Try the alternative command format
        final alternativeData = {
          'title': taskData['title'],
          'description': taskData['description'] ?? '',
          'status': taskData['status'] ?? 'Pending',
          'priority': taskData['priority'] ?? 'Medium',
          'assignedTo': taskData['assignedTo'],
          'bucketGuid': bucketGuid, 
        };
        
        // Try with Dio directly and the alternative endpoint
        final alternativeResponse = await _dio.post(
          '/api/BucketTasks/CreateTask',
          data: alternativeData,
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        debugPrint('Alternative task creation response: ${alternativeResponse.statusCode}');
        
        if (alternativeResponse.statusCode! >= 200 && alternativeResponse.statusCode! < 300) {
          Map<String, dynamic> createdTask;
          
          if (alternativeResponse.data is Map) {
            createdTask = Map<String, dynamic>.from(alternativeResponse.data);
          } else {
            // If the response isn't properly formatted, enrich the local task data
            createdTask = {
              ...alternativeData,
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'guid': DateTime.now().millisecondsSinceEpoch.toString(),
              'createdAt': DateTime.now().toIso8601String(),
            };
          }
          
          debugPrint('Task created successfully via alternative method');
          return createdTask;
        }
      } catch (e) {
        debugPrint('Alternative task creation also failed: $e');
      }
      
      // If we get here, both methods failed but we'll return a mock task for the UI
      // This ensures the app remains functional even if the API integration isn't perfect
      debugPrint('Creating local mock task as fallback');
      return {
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'guid': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'title': taskData['title'],
        'description': taskData['description'] ?? '',
        'status': taskData['status'] ?? 'Pending',
        'priority': taskData['priority'] ?? 'Medium',
        'assignedTo': taskData['assignedTo'],
        'bucketGuid': bucketGuid,
        'dueDate': taskData['dueDate'],
        'createdAt': DateTime.now().toIso8601String(),
        'isLocalOnly': true,  // Flag to indicate this is a local task
      };
      
    } catch (e) {
      debugPrint('Error creating task: $e');
      throw Exception('Failed to create task: $e');
    }
  }
  
  // Update an existing task with multiple approaches
  Future<Map<String, dynamic>> updateTask(Map<String, dynamic> taskData) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      // First try to get the GUID, then fall back to numeric id if needed
      final String? taskGuid = taskData['guid']?.toString();
      final String? taskId = taskData['id']?.toString();
      
      // For API operations, strongly prefer the GUID if available
      final String identifier = taskGuid ?? taskId ?? '';
      
      if (identifier.isEmpty) {
        throw Exception('Task ID or GUID is required for update');
      }
      
      debugPrint('Updating task with identifier: $identifier');
      debugPrint('Task data: $taskData');
      
      // APPROACH 1: Try to update directly with PUT first
      try {
        debugPrint('Attempting direct task update with PUT');
        
        // Create update command
        final updateData = {
          'command': {
            'guid': taskGuid,
            'id': taskId,
            'title': taskData['title'],
            'description': taskData['description'] ?? '',
            'status': taskData['status'] ?? 'Pending',
            'priority': taskData['priority'] ?? 'Medium',
            'assignedTo': taskData['assignedTo']?.toString(),
            'bucketGuid': taskData['bucketId'] ?? taskData['bucketGuid'],
            'dueDate': taskData['dueDate'],
          }
        };
        
        // Log the update data
        debugPrint('Update data: ${jsonEncode(updateData)}');
        
        // GET token for auth
        final token = await storage.read(key: 'accessToken');
        
        // Attempt PUT request
        final response = await _dio.put(
          '/api/BucketTasks/${taskGuid ?? taskId}',
          data: updateData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true, // Accept any status to log properly
            receiveTimeout: Duration(seconds: 30),
          ),
        );
        
        debugPrint('Direct update response status: ${response.statusCode}');
        debugPrint('Direct update response data: ${response.data}');
        
        // Check if update was successful
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          debugPrint('Task updated successfully with direct PUT');
          
          // Return the updated task from the response or construct it
          if (response.data is Map) {
            // Extract task data from response
            Map<String, dynamic> updatedTask;
            if (response.data['data'] != null) {
              updatedTask = Map<String, dynamic>.from(response.data['data']);
            } else {
              updatedTask = Map<String, dynamic>.from(response.data);
            }
            
            debugPrint('Returning updated task from response');
            return updatedTask;
          } else {
            // If no proper response, enhance the input data and return it
            debugPrint('Constructing result from input data');
            return {
              ...taskData,
              'updatedAt': DateTime.now().toIso8601String(),
            };
          }
        }
        
        debugPrint('Direct PUT update failed, falling back to delete-then-create');
      } catch (e) {
        debugPrint('Error with direct task update: $e');
        debugPrint('Falling back to delete-then-create approach');
      }
      
      // APPROACH 2: DELETE then CREATE as fallback
      debugPrint('===== Starting delete-then-create approach =====');
      
      // Step 1: Delete the existing task if possible
      if (taskGuid != null) {
        try {
          debugPrint('Deleting existing task with GUID: $taskGuid');
          await deleteTask(taskGuid);
          debugPrint('Successfully deleted old task');
        } catch (e) {
          debugPrint('Warning: Failed to delete the old task: $e');
          debugPrint('Continuing with create anyway');
        }
      } else {
        debugPrint('Skipping delete step since we don\'t have a valid GUID');
      }
      
      // Step 2: Create a new task with the updated data
      final String bucketId = taskData['bucketId']?.toString() ?? 
                              taskData['bucketGuid']?.toString() ?? '';
      
      if (bucketId.isEmpty) {
        throw Exception('Bucket ID is required for task update');
      }
      
      // Prepare task data for the create operation
      final Map<String, dynamic> newTaskData = {
        'title': taskData['title'],
        'description': taskData['description'] ?? '',
        'status': taskData['status'] ?? 'Pending',
        'priority': taskData['priority'] ?? 'Medium',
        'assignedTo': taskData['assignedTo']?.toString(),
        'bucketId': bucketId, 
        'bucketGuid': bucketId,
        'dueDate': taskData['dueDate'],
        'projectId': taskData['projectId']?.toString(),
        'projectName': taskData['projectName'],
        'bucketName': taskData['bucketName'],
      };
      
      debugPrint('Creating new task with data: $newTaskData');
      
      // Create a new task using the existing createTask method
      final newTask = await createTask(newTaskData);
      
      // Copy additional fields from the original task if needed
      if (taskGuid != null && newTask['guid'] == null) {
        newTask['guid'] = taskGuid; // Preserve original GUID for reference
      }
      
      debugPrint('Successfully created new task with ID: ${newTask['id'] ?? newTask['guid']}');
      
      // Return the newly created task
      return newTask;
    } catch (e) {
      debugPrint('Error updating task: $e');
      throw Exception('Failed to update task: $e');
    }
  }
  
  // Delete a task using the correct API endpoint with GUID
  Future<void> deleteTask(String taskId) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Task delete request for ID: $taskId');
      
      // Get the token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }
      
      // Check if taskId is already in GUID format (contains hyphens)
      final bool isGuidFormat = taskId.contains('-');
      
      if (!isGuidFormat) {
        debugPrint('WARNING: Task deletion requires a GUID, but received numeric ID: $taskId');
        debugPrint('Please update your code to use the task GUID instead of numeric ID for deletion');
        throw Exception('Task deletion requires a GUID format ID, not a numeric ID');
      }
      
      debugPrint('Using GUID format ID for deletion: $taskId');
      
      // Try with domain URL first
      try {
        debugPrint('Attempting task deletion with domain URL');
        
        final response = await _dio.delete(
          '/api/BucketTasks',
          queryParameters: {'Guid': taskId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true, // Accept any status to log all responses
          ),
        );
        
        // Log full response details for debugging
        debugPrint('Domain URL task deletion response:');
        debugPrint('- Status code: ${response.statusCode}');
        debugPrint('- Response data: ${response.data}');
        debugPrint('- Response headers: ${response.headers}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          debugPrint('Task deletion successful with domain URL');
          return;
        } else {
          debugPrint('Task deletion failed with domain URL, status code: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error with domain URL task deletion: $e');
      }
      
      // Try with IP URL as fallback
      try {
        debugPrint('Attempting task deletion with IP URL');
        final String originalBaseUrl = _dio.options.baseUrl;
        _dio.options.baseUrl = AppConfig.apiIpUrl;
        
        final response = await _dio.delete(
          '/api/BucketTasks',
          queryParameters: {'Guid': taskId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
            validateStatus: (status) => true, // Accept any status to log all responses
          ),
        );
        
        // Reset base URL
        _dio.options.baseUrl = originalBaseUrl;
        
        // Log full response details for debugging
        debugPrint('IP URL task deletion response:');
        debugPrint('- Status code: ${response.statusCode}');
        debugPrint('- Response data: ${response.data}');
        debugPrint('- Response headers: ${response.headers}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          debugPrint('Task deletion successful with IP URL');
          return;
        } else {
          debugPrint('Task deletion failed with IP URL, status code: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error with IP URL task deletion: $e');
      }
      
      // Try with a different endpoint as last resort
      try {
        debugPrint('Attempting task deletion with alternative endpoint');
        
        final response = await _dio.delete(
          '/api/BucketTasks/DeleteTask',
          queryParameters: {'Guid': taskId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true, // Accept any status to log all responses
          ),
        );
        
        // Log full response details for debugging
        debugPrint('Alternative endpoint task deletion response:');
        debugPrint('- Status code: ${response.statusCode}');
        debugPrint('- Response data: ${response.data}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          debugPrint('Task deletion successful with alternative endpoint');
          return;
        } else {
          debugPrint('Task deletion failed with alternative endpoint, status code: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Error with alternative endpoint task deletion: $e');
      }
      
      throw Exception('All task deletion approaches failed');
    } catch (e) {
      debugPrint('=== API Error Details ===');
      if (e is DioException) {
        debugPrint('Error Type: ${e.type}');
        debugPrint('Error Message: ${e.message}');
        debugPrint('Status Code: ${e.response?.statusCode}');
        debugPrint('Response Data: ${e.response?.data}');
      } else {
        debugPrint('Error: $e');
      }
      
      debugPrint('Task deletion failed: $e');
      throw Exception('Error deleting task: $e');
    }
  }
  
  // Download a file
  Future<String> getFileDownloadUrl(String fileId) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Getting download URL for file: $fileId');
      
      // Check if the fileId appears to be a GUID format (has hyphens and proper length)
      if (fileId.contains('-') && fileId.length > 30) {
        // For GUID format IDs, directly use the DownloadAttachment endpoint
        final directUrl = '$_baseUrl/api/Attachments/DownloadAttachment?AttachmentGuid=$fileId';
        debugPrint('Using direct attachment download URL with GUID: $directUrl');
        return directUrl;
      }
      
      // Try first implementation
      try {
        final response = await get('api/Attachments/GetDownloadUrl/$fileId');
        
        if (response != null && response is Map) {
          final url = response['url'] ?? response['downloadUrl'] ?? response['data']?['url'];
          if (url != null && url.toString().isNotEmpty) {
            debugPrint('Got download URL: $url');
            return url.toString();
          }
        }
      } catch (e) {
        debugPrint('First download URL attempt failed: $e, trying alternative method');
      }
      
      // Try alternative endpoint
      try {
        final response = await _dio.get(
          '/api/Attachments/Download',
          queryParameters: {'fileId': fileId},
          options: Options(
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          if (response.headers.map.containsKey('location')) {
            final url = response.headers.value('location');
            if (url != null && url.isNotEmpty) {
              debugPrint('Got download URL from headers: $url');
              return url;
            }
          }
          
          if (response.data != null) {
            if (response.data is String && response.data.toString().startsWith('http')) {
              debugPrint('Got download URL from response data: ${response.data}');
              return response.data.toString();
            } else if (response.data is Map) {
              final url = response.data['url'] ?? 
                         response.data['downloadUrl'] ?? 
                         response.data['data']?['url'];
              if (url != null && url.toString().isNotEmpty) {
                debugPrint('Got download URL from response data map: $url');
                return url.toString();
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Alternative download URL attempt failed: $e');
      }
      
      // Final fallback - use the direct AttachmentGuid download URL
      final fallbackUrl = '$_baseUrl/api/Attachments/DownloadAttachment?AttachmentGuid=$fileId';
      debugPrint('Using fallback direct attachment download URL: $fallbackUrl');
      return fallbackUrl;
    } catch (e) {
      debugPrint('Error getting file download URL: $e');
      throw Exception('Failed to get download URL: $e');
    }
  }
  
  // Upload a file
  Future<Map<String, dynamic>> uploadFile(String bucketId, String filePath) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Uploading file to bucket: $bucketId');
      debugPrint('File path: $filePath');
      
      // Get the file name from the path
      final fileName = filePath.split('/').last;
      
      // Create form data with the file
      final formData = FormData.fromMap({
        'bucketGuid': bucketId,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse('application/octet-stream'), // Or derive from file extension
        ),
      });
      
      // Make sure we have current headers and URL
      final headers = await _getHeaders();
      final baseUrl = await getBaseUrl();
      
      // Add specific headers for multipart uploads, but retain auth
      headers['Content-Type'] = 'multipart/form-data';
      
      // Print request details for debugging
      debugPrint('Making file upload request to: $baseUrl/api/Attachments/AddFile');
      debugPrint('Headers: $headers');
      debugPrint('FormData: bucketGuid=$bucketId, filename=$fileName');
      
      // First try the correct endpoint as specified in the API
      try {
        final response = await _dio.post(
          '$baseUrl/api/Attachments/AddFile',
          data: formData,
          options: Options(
            headers: headers,
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        debugPrint('Upload response: ${response.statusCode}');
        debugPrint('Response data: ${response.data}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          if (response.data is Map) {
            final uploadedFile = Map<String, dynamic>.from(response.data);
            debugPrint('File uploaded successfully: ${uploadedFile['id'] ?? uploadedFile['guid']}');
            return uploadedFile;
          } else if (response.data is String && response.data.toString().isNotEmpty) {
            try {
              // Try to parse JSON string if we get a string response
              final uploadedFile = jsonDecode(response.data);
              return Map<String, dynamic>.from(uploadedFile);
            } catch (e) {
              debugPrint('Could not parse response as JSON: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('File upload failed with correct endpoint: $e, trying fallback methods');
      }
      
      // Try fallback implementation
      try {
        final response = await _dio.post(
          '$baseUrl/api/Attachments/Upload',
          data: formData,
          options: Options(
            headers: headers,
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        debugPrint('Fallback upload response: ${response.statusCode}');
        debugPrint('Response data: ${response.data}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          if (response.data is Map) {
            final uploadedFile = Map<String, dynamic>.from(response.data);
            debugPrint('File uploaded successfully with fallback endpoint');
            return uploadedFile;
          } else if (response.data is String && response.data.toString().isNotEmpty) {
            try {
              // Try to parse JSON string if we get a string response
              final uploadedFile = jsonDecode(response.data);
              return Map<String, dynamic>.from(uploadedFile);
            } catch (e) {
              debugPrint('Could not parse response as JSON: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Fallback upload also failed: $e');
      }
      
      // Try alternative endpoint as last resort
      try {
        final response = await _dio.post(
          '$baseUrl/api/Attachments/UploadFile',
          data: formData,
          options: Options(
            headers: headers,
            followRedirects: true,
            validateStatus: (status) => status! < 500,
          ),
        );
        
        debugPrint('Alternative upload response: ${response.statusCode}');
        debugPrint('Response data: ${response.data}');
        
        if (response.statusCode! >= 200 && response.statusCode! < 300) {
          if (response.data is Map) {
            final uploadedFile = Map<String, dynamic>.from(response.data);
            debugPrint('File uploaded successfully via alternative method');
            return uploadedFile;
          } else if (response.data is String && response.data.toString().isNotEmpty) {
            try {
              // Try to parse JSON string if we get a string response
              final uploadedFile = jsonDecode(response.data);
              return Map<String, dynamic>.from(uploadedFile);
            } catch (e) {
              debugPrint('Could not parse response as JSON: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('All upload methods failed: $e');
      }
      
      throw Exception('Failed to upload file: All methods failed');
    } catch (e) {
      debugPrint('Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }
  
  // Delete file with improved error handling
  Future<void> deleteFile(String fileId) async {
    if (!await hasInternetConnection()) {
      throw Exception('No internet connection');
    }

    try {
      debugPrint('Attempting to delete file with ID: $fileId');
      
      // Get the token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }
      
      // Check if it looks like a GUID format
      final bool isGuidFormat = fileId.contains('-');
      
      debugPrint('File ID format: ${isGuidFormat ? 'GUID' : 'Numeric'}');
      
      // Try method 1: Primary endpoint with proper validateStatus
      try {
        debugPrint('Attempting file deletion with primary endpoint');
        final response = await _dio.delete(
          '/api/Files/$fileId',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true, // Accept any status to handle properly
          ),
        );
        
        debugPrint('Primary endpoint response: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('File deleted successfully using primary endpoint');
          return;
        }
      } catch (e) {
        debugPrint('Primary endpoint failed: $e');
      }
      
      // Try method 2: Attachments API endpoint 
      try {
        debugPrint('Attempting file deletion with Attachments endpoint');
        final response = await _dio.delete(
          '/api/Attachments',
          queryParameters: {'Guid': fileId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        
        debugPrint('Attachments endpoint response: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('File deleted successfully using Attachments endpoint');
          return;
        }
      } catch (e) {
        debugPrint('Attachments endpoint failed: $e');
      }
      
      // Try method 3: Another alternative endpoint
      try {
        debugPrint('Attempting file deletion with alternative endpoint');
        final response = await _dio.delete(
          '/api/BucketFiles/$fileId',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        
        debugPrint('Alternative endpoint response: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('File deleted successfully using alternative endpoint');
          return;
        }
      } catch (e) {
        debugPrint('Alternative endpoint failed: $e');
      }
      
      // Try method 4: DELETE with AttachmenGuid as query parameter
      try {
        debugPrint('Attempting file deletion with AttachmenGuid parameter');
        final response = await _dio.delete(
          '/api/Attachments/DeleteAttachment',
          queryParameters: {'AttachmenGuid': fileId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        
        debugPrint('DeleteAttachment endpoint response: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('File deleted successfully using DeleteAttachment endpoint');
          return;
        }
      } catch (e) {
        debugPrint('DeleteAttachment endpoint failed: $e');
      }
      
      // Try method 5: POST instead of DELETE (some APIs use POST for deletion)
      try {
        debugPrint('Attempting file deletion with POST method');
        final response = await _dio.post(
          '/api/Attachments/DeleteFile',
          data: {'fileId': fileId, 'guid': fileId},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            validateStatus: (status) => true,
          ),
        );
        
        debugPrint('POST delete endpoint response: ${response.statusCode}');
        
        if (response.statusCode == 200 || response.statusCode == 204) {
          debugPrint('File deleted successfully using POST method');
          return;
        }
      } catch (e) {
        debugPrint('POST delete method failed: $e');
      }
      
      // Log the failure but don't throw
      debugPrint('All file deletion methods failed. File may still be on the server.');
      debugPrint('Please check the API documentation for the correct file deletion endpoint.');
      
      // Don't throw error as it might prevent user from continuing to use the app
      // Just return without completing the operation
      return;
    } catch (e) {
      debugPrint('Error deleting file: $e');
      // Don't re-throw, just log the error to prevent app crashes
      // The UI can still show a message about deletion failure
    }
  }

  // Get the base URL
  Future<String> getBaseUrl() async {
    return _baseUrl;
  }

  // Get the authentication token
  Future<String?> getAuthToken() async {
    try {
      return await storage.read(key: 'accessToken');
    } catch (e) {
      debugPrint('Error reading auth token: $e');
      return null;
    }
  }

  // Get a file sharing URL
  Future<String> getFileShareUrl(String fileId) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Getting share URL for file: $fileId');
      
      // Check if the fileId appears to be a GUID format (has hyphens and proper length)
      if (fileId.contains('-') && fileId.length > 30) {
        // For GUID format IDs, directly construct the ShareAttachment endpoint URL
        final shareUrl = '$_baseUrl/api/Attachments/ShareAttachment?AttachmentGuid=$fileId';
        debugPrint('Generated file share URL with GUID: $shareUrl');
        return shareUrl;
      } else {
        throw Exception('File ID must be in GUID format for sharing');
      }
    } catch (e) {
      debugPrint('Error getting file share URL: $e');
      throw Exception('Failed to get share URL: $e');
    }
  }

  // Get attachments for a specific task
  Future<List<Map<String, dynamic>>> getTaskAttachments(String taskGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      // Don't try to fetch data for invalid task GUIDs
      if (taskGuid.isEmpty || !taskGuid.contains('-')) {
        debugPrint('Invalid task GUID provided: $taskGuid');
        return [];
      }
      
      debugPrint('Getting attachments for task: $taskGuid');
      
      // Get token for authentication
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      try {
        final response = await _dio.get(
          '/api/Attachments/GetTaskAttachments',
          queryParameters: {'TaskGuid': taskGuid},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Task attachments response status: ${response.statusCode}');
        debugPrint('Task attachments response data: ${response.data}');

        if (response.statusCode == 200) {
          if (response.data is List) {
            return List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              return List<Map<String, dynamic>>.from(data['result']);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching task attachments: $e');
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting task attachments: $e');
      return [];
    }
  }

  // Upload file to task using bytes (for web)
  Future<Map<String, dynamic>> uploadFileToTaskFromBytes(
    String taskGuid,
    Uint8List fileBytes,
    String fileName, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      final filePart = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      );
      final form = {
        'BucketTaskGuid': taskGuid,
        'File': filePart,
        if (extra != null) ...extra,
      };
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Let Dio set boundary
      final baseUrl = await getBaseUrl();
      debugPrint('=== [DEBUG] Uploading file to task (from bytes) ===');
      debugPrint('Endpoint: $baseUrl/api/BucketTasks/AddFileToTask');
      debugPrint('Form: $form');
      debugPrint('Headers: $headers');
      final res = await _dio.post(
        '$baseUrl/api/BucketTasks/AddFileToTask',
        data: FormData.fromMap(form),
        options: Options(headers: headers),
      );
      if (res.statusCode! >= 200 && res.statusCode! < 300) {
        debugPrint('File uploaded successfully: ${res.data}');
        return res.data;
      }
      throw Exception('Upload failed: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error uploading file to task (from bytes): $e');
      throw Exception('Failed to upload file to task (from bytes): $e');
    }
  }

  // Upload file directly to a task
  Future<Map<String, dynamic>> uploadFileToTask(
    String taskGuid,
    String filePath, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      final fileName = filePath.split('/').last;
      final filePart = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      );
      final form = {
        'BucketTaskGuid': taskGuid,
        'File': filePart,
        if (extra != null) ...extra,
      };
      final headers = await _getHeaders();
      headers.remove('Content-Type'); // Let Dio set boundary
      final baseUrl = await getBaseUrl();
      debugPrint('=== [DEBUG] Uploading file to task ===');
      debugPrint('Endpoint: $baseUrl/api/BucketTasks/AddFileToTask');
      debugPrint('Form: $form');
      debugPrint('Headers: $headers');
      final res = await _dio.post(
        '$baseUrl/api/BucketTasks/AddFileToTask',
        data: FormData.fromMap(form),
        options: Options(headers: headers),
      );
      if (res.statusCode! >= 200 && res.statusCode! < 300) {
        debugPrint('File uploaded successfully: ${res.data}');
        return res.data;
      }
      throw Exception('Upload failed: ${res.statusCode}');
    } catch (e) {
      debugPrint('Error uploading file to task: $e');
      throw Exception('Failed to upload file to task: $e');
    }
  }

  // Get comments for a specific task
  Future<List<Map<String, dynamic>>> getTaskComments(String taskGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      if (taskGuid.isEmpty || !taskGuid.contains('-')) {
        debugPrint('Invalid task GUID provided: $taskGuid');
        return [];
      }
      
      debugPrint('Getting comments for task: $taskGuid');
      
      final response = await get('api/BucketTasks/TaskComments?TaskGuid=$taskGuid');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response.map((item) => Map<String, dynamic>.from(item)));
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting task comments: $e');
      return [];
    }
  }

  // Add comment to task (text only)
  Future<Map<String, dynamic>> createTaskComment(String taskGuid, String text) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      debugPrint('=== [DEBUG] Posting text comment ===');
      debugPrint('Endpoint: api/BucketTasks/AddCommentToTask');
      debugPrint('Payload: {taskGuid: $taskGuid, comment: $text}');
      final data = {
        'taskGuid': taskGuid,
        'comment': text,
      };
      final headers = await _getHeaders();
      debugPrint('Headers: ' + headers.toString());
      final response = await post('api/BucketTasks/AddCommentToTask', data);
      if (response is Map) {
        debugPrint('Comment added successfully: $response');
        return Map<String, dynamic>.from(response);
      }
      throw Exception('Invalid response format');
    } catch (e) {
      debugPrint('Error adding comment: $e');
      throw Exception('Failed to add comment: $e');
    }
  }

  // Add comment with file attachment
  Future<Map<String, dynamic>> addCommentWithFile(String taskGuid, String commentText, String filePath) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      debugPrint('=== [DEBUG] Posting comment with file ===');
      debugPrint('Endpoint: /api/BucketTasks/AddCommentToTask');
      debugPrint('File path: $filePath');
      debugPrint('Payload: {taskGuid: $taskGuid, comment: $commentText, file: $filePath}');
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'taskGuid':  taskGuid,
        'comment':   commentText,
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: MediaType.parse('application/octet-stream'),
        ),
      });
      final headers = await _getHeaders();
      final baseUrl = await getBaseUrl();
      headers.remove('Content-Type'); // let Dio set it
      debugPrint('Headers: ' + headers.toString());
      final response = await _dio.post(
        '$baseUrl/api/BucketTasks/AddCommentToTask',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.data is Map) {
          final comment = Map<String, dynamic>.from(response.data);
          debugPrint('Comment with file added successfully');
          return comment;
        } else if (response.data is String && response.data.toString().isNotEmpty) {
          try {
            final comment = jsonDecode(response.data);
            return Map<String, dynamic>.from(comment);
          } catch (e) {
            debugPrint('Could not parse response as JSON: $e');
          }
        }
      }
      throw Exception('Failed to add comment with file: Status ${response.statusCode}');
    } catch (e, stack) {
      debugPrint('Error adding comment with file: $e');
      debugPrint('Stacktrace: $stack');
      throw Exception('Failed to add comment with file: $e');
    }
  }

  // Add comment with file using bytes (for web)
  Future<Map<String, dynamic>> addCommentWithFileBytes(String taskGuid, String commentText, Uint8List fileBytes, String fileName) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      debugPrint('=== [DEBUG] Posting comment with file (bytes) ===');
      debugPrint('Endpoint: /api/BucketTasks/AddCommentToTask');
      debugPrint('Payload: {taskGuid: $taskGuid, comment: $commentText, file: $fileName}');
      final formData = FormData.fromMap({
        'taskGuid': taskGuid,
        'comment': commentText,
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
          contentType: MediaType.parse('application/octet-stream'),
        ),
      });
      final headers = await _getHeaders();
      final baseUrl = await getBaseUrl();
      headers.remove('Content-Type'); // let Dio set it
      debugPrint('Headers: ' + headers.toString());
      final response = await _dio.post(
        '$baseUrl/api/BucketTasks/AddCommentToTask',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.data is Map) {
          final comment = Map<String, dynamic>.from(response.data);
          debugPrint('Comment with file bytes added successfully');
          return comment;
        } else if (response.data is String && response.data.toString().isNotEmpty) {
          try {
            final comment = jsonDecode(response.data);
            return Map<String, dynamic>.from(comment);
          } catch (e) {
            debugPrint('Could not parse response as JSON: $e');
          }
        }
      }
      throw Exception('Failed to add comment with file: Status ${response.statusCode}');
    } catch (e, stack) {
      debugPrint('Error adding comment with file bytes: $e');
      debugPrint('Stacktrace: $stack');
      throw Exception('Failed to add comment with file: $e');
    }
  }

  // Get attachments for a specific comment
  Future<List<Map<String, dynamic>>> getCommentAttachments(String commentGuid) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      if (commentGuid.isEmpty || !commentGuid.contains('-')) {
        debugPrint('Invalid comment GUID provided: $commentGuid');
        return [];
      }
      
      debugPrint('Getting attachments for comment: $commentGuid');
      
      final token = await storage.read(key: 'accessToken');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      try {
        final response = await _dio.get(
          '/api/GetCommentAttachments',
          queryParameters: {'CommentGuid': commentGuid},
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Host': AppConfig.apiHost,
            },
          ),
        );
        
        debugPrint('Comment attachments response status: ${response.statusCode}');
        debugPrint('Comment attachments response data: ${response.data}');

        if (response.statusCode == 200) {
          if (response.data is List) {
            return List<Map<String, dynamic>>.from(response.data);
          } else if (response.data is Map) {
            final data = response.data as Map<String, dynamic>;
            if (data['data'] != null && data['data'] is List) {
              return List<Map<String, dynamic>>.from(data['data']);
            } else if (data['result'] != null && data['result'] is List) {
              return List<Map<String, dynamic>>.from(data['result']);
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching comment attachments: $e');
      }
      
      return [];
    } catch (e) {
      debugPrint('Error getting comment attachments: $e');
      return [];
    }
  }

  // Add file to comment with task context
  Future<Map<String, dynamic>> addFileToComment(String taskGuid, String commentGuid, String filePath) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Adding file to comment: $commentGuid for task: $taskGuid');
      debugPrint('File path: $filePath');
      
      final fileName = filePath.split('/').last;
      
      final multipartFile = await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      );
      
      // Based on network logs, use task GUID and comment GUID together
      final formData = FormData.fromMap({
        'taskGuid': taskGuid,
        'commentGuid': commentGuid,
        'attachmentGuid': commentGuid, // Some endpoints expect this
        'file': multipartFile,
        'File': multipartFile, // Alternative name
      });
      
      final headers = await _getHeaders();
      headers['Content-Type'] = 'multipart/form-data';
      
      final response = await _dio.post(
        '/api/AddFileToComment',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      debugPrint('Add file to comment response: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.data != null) {
          return Map<String, dynamic>.from(response.data);
        }
        return {'success': true};
      } else {
        throw Exception('Failed to add file to comment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding file to comment: $e');
      throw Exception('Failed to add file to comment: $e');
    }
  }

  // Add file to comment using bytes (for web)
  Future<Map<String, dynamic>> addFileToCommentFromBytes(String taskGuid, String commentGuid, Uint8List fileBytes, String fileName) async {
    try {
      if (!await hasInternetConnection()) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Adding file bytes to comment: $commentGuid for task: $taskGuid');
      debugPrint('File name: $fileName');
      
      final multipartFile = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: MediaType.parse('application/octet-stream'),
      );
      
      final formData = FormData.fromMap({
        'taskGuid': taskGuid,
        'commentGuid': commentGuid,
        'attachmentGuid': commentGuid,
        'file': multipartFile,
        'File': multipartFile,
      });
      
      final headers = await _getHeaders();
      headers['Content-Type'] = 'multipart/form-data';
      
      final response = await _dio.post(
        '/api/AddFileToComment',
        data: formData,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      debugPrint('Add file bytes to comment response: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');
      
      if (response.statusCode! >= 200 && response.statusCode! < 300) {
        if (response.data != null) {
          return Map<String, dynamic>.from(response.data);
        }
        return {'success': true};
      } else {
        throw Exception('Failed to add file to comment: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error adding file bytes to comment: $e');
      throw Exception('Failed to add file to comment: $e');
    }
  }
}