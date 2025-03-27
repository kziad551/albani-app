import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'auth_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ApiService {
  final AuthService _authService = AuthService();
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  final String _baseUrl = AppConfig.apiBaseUrl;
  final storage = const FlutterSecureStorage();
  
  // Flag for mock mode - use same value as AppConfig
  bool get _mockMode => AppConfig.enableOfflineMode;
  
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
    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
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
      
      // Try to validate with the Employees endpoint
      try {
        final response = await get('api/Employees/validate');
        debugPrint('Token validation response: $response');
        return true; // If we got a response without exception, token is valid
      } catch (e) {
        debugPrint('First token validation endpoint failed: $e');
      }
      
      // Try with auth endpoint as fallback
      try {
        final response = await get('api/auth/validate');
        debugPrint('Token validation response: $response');
        return true;
      } catch (e) {
        debugPrint('Token validation error: $e');
        return false;
      }
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
      // Token expired or invalid - handle token refresh or clear storage
      debugPrint('Received 401 Unauthorized response');
      
      // First try to validate the token
      final isValid = await _authService.hasValidToken();
      if (!isValid) {
        // If token is invalid, handle expiration
        await _handleTokenExpiration();
        throw Exception('Unauthorized: Please log in again');
      }
      
      // If token is valid but request failed, throw error
      throw Exception('Unauthorized: Please try again');
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
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      // Validate token before making request
      final isValid = await _authService.hasValidToken();
      if (!isValid) {
        throw Exception('Unauthorized: Please log in again');
      }
      
      debugPrint('Fetching projects from server');
      
      // Use the exact same endpoint that the website uses
      final response = await get('api/Projects/GetUserProjects');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response['result'] != null && response['result'] is List) {
          return List<Map<String, dynamic>>.from(response['result']);
        } else if (response['items'] != null && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        }
      }
      
      // If no valid response format, return empty list
      debugPrint('No projects found in any response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      throw Exception('Failed to load projects: $e');
    }
  }
  
  Future<Map<String, dynamic>> getProjectById(dynamic id) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      final response = await get('api/Projects/$id');
      
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map && response['data'] != null) {
        return response['data'];
      }
      
      throw Exception('Invalid project response format');
    } catch (e) {
      debugPrint('Error fetching project details: $e');
      throw Exception('Failed to load project details: $e');
    }
  }
  
  Future<List<Map<String, dynamic>>> getBuckets({dynamic projectId = 0}) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Fetching buckets for projectId=$projectId (${projectId.runtimeType})');
      
      // Use the project ID to fetch buckets from the API - same endpoint as website
      final endpoint = (projectId != null && projectId != 0)
        ? 'api/Buckets/GetProjectBuckets/${projectId.toString()}'
        : 'api/Buckets/GetDefaults';
      
      debugPrint('Using endpoint: $endpoint');
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
        } else if (response['buckets'] != null && response['buckets'] is List) {
          return List<Map<String, dynamic>>.from(response['buckets']);
        }
      }
      
      // If no valid response, return empty list
      debugPrint('No buckets found in any response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching buckets: $e');
      throw Exception('Failed to load buckets: $e');
    }
  }
  
  // Get bucket files from the API
  Future<List<Map<String, dynamic>>> getBucketFiles(String bucketId) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Fetching files for bucketId=$bucketId');
      
      // Use the same endpoint as the website
      final response = await get('api/Files/GetByBucketId/$bucketId');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response['result'] != null && response['result'] is List) {
          return List<Map<String, dynamic>>.from(response['result']);
        } else if (response['items'] != null && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        } else if (response['files'] != null && response['files'] is List) {
          return List<Map<String, dynamic>>.from(response['files']);
        }
      }
      
      // If no valid response, return empty list
      debugPrint('No files found in any response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching bucket files: $e');
      throw Exception('Failed to load bucket files: $e');
    }
  }
  
  // Get bucket tasks from the API
  Future<List<Map<String, dynamic>>> getBucketTasks(String bucketId) async {
    try {
      // First check internet connection
      final hasInternet = await hasInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }
      
      debugPrint('Fetching tasks for bucketId=$bucketId');
      
      // Use the same endpoint as the website
      final response = await get('api/Tasks/GetByBucketId/$bucketId');
      
      if (response is List) {
        return List<Map<String, dynamic>>.from(response);
      } else if (response is Map) {
        if (response['data'] != null && response['data'] is List) {
          return List<Map<String, dynamic>>.from(response['data']);
        } else if (response['result'] != null && response['result'] is List) {
          return List<Map<String, dynamic>>.from(response['result']);
        } else if (response['items'] != null && response['items'] is List) {
          return List<Map<String, dynamic>>.from(response['items']);
        } else if (response['tasks'] != null && response['tasks'] is List) {
          return List<Map<String, dynamic>>.from(response['tasks']);
        }
      }
      
      // If no valid response, return empty list
      debugPrint('No tasks found in any response format, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching bucket tasks: $e');
      throw Exception('Failed to load bucket tasks: $e');
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
}
