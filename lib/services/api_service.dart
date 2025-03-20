import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'auth_service.dart';

class ApiService {
  final AuthService _authService = AuthService();
  
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  
  final String _baseUrl = AppConfig.apiBaseUrl;
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
  
  // Helper method for handling API responses
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return {'success': true};
    } else if (response.statusCode == 401) {
      // Token expired or invalid
      throw Exception('Unauthorized: Please log in again');
    } else {
      throw Exception('API Error: ${response.statusCode} - ${response.body}');
    }
  }
  
  // GET request
  Future<dynamic> get(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$_baseUrl/$endpoint');
      debugPrint('GET Request to: $uri');
      
      final response = await http.get(
        uri,
        headers: headers,
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      debugPrint('GET Response (${response.statusCode}): ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}...');
      return _handleResponse(response);
    } catch (e) {
      debugPrint('GET request error: $e');
      rethrow;
    }
  }
  
  // POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('POST request error: $e');
      rethrow;
    }
  }
  
  // PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: headers,
        body: jsonEncode(data),
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('PUT request error: $e');
      rethrow;
    }
  }
  
  // DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: headers,
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      return _handleResponse(response);
    } catch (e) {
      debugPrint('DELETE request error: $e');
      rethrow;
    }
  }
  
  // API methods for projects
  
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      debugPrint('Fetching projects from server');
      
      // Use the exact same endpoint that the website uses
      try {
        final response = await get('api/Projects/GetUserProjects');
        debugPrint('GetUserProjects response: ${response.toString().substring(0, response.toString().length > 100 ? 100 : response.toString().length)}...');
        
        if (response is List) {
          debugPrint('GetUserProjects returned ${response.length} projects');
          return List<Map<String, dynamic>>.from(response);
        } else if (response is Map) {
          if (response['data'] != null && response['data'] is List) {
            debugPrint('GetUserProjects data field contains ${response['data'].length} projects');
            return List<Map<String, dynamic>>.from(response['data']);
          } else if (response['result'] != null && response['result'] is List) {
            debugPrint('GetUserProjects result field contains ${response['result'].length} projects');
            return List<Map<String, dynamic>>.from(response['result']);
          } else if (response['items'] != null && response['items'] is List) {
            debugPrint('GetUserProjects items field contains ${response['items'].length} projects');
            return List<Map<String, dynamic>>.from(response['items']);
          }
        }
        debugPrint('GetUserProjects response did not match expected formats: $response');
      } catch (e) {
        debugPrint('GetUserProjects failed: $e');
      }
      
      // Try the byGuid all projects endpoint as fallback
      try {
        final response = await get('api/Projects/byGuid?Includes=Buckets,Employee');
        debugPrint('byGuid response type: ${response.runtimeType}');
        
        if (response is List) {
          return List<Map<String, dynamic>>.from(response);
        } else if (response is Map) {
          if (response['data'] != null && response['data'] is List) {
            return List<Map<String, dynamic>>.from(response['data']);
          }
        }
      } catch (e) {
        debugPrint('byGuid endpoint failed: $e');
      }
      
      // Last resort - standard projects endpoint
      final response = await get('api/Projects');
      
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
      
      debugPrint('No projects found in any endpoint, returning empty list');
      return [];
    } catch (e) {
      debugPrint('Error fetching projects: $e');
      if (AppConfig.enableOfflineMode) {
        debugPrint('Using minimal mock data in offline mode');
        return _getMinimalMockProjects();
      }
      rethrow;
    }
  }
  
  // Minimal mock data for offline development only
  List<Map<String, dynamic>> _getMinimalMockProjects() {
    // Just return a very small set of mock data for development
    return [
      {
        'id': 1,
        'name': 'Sample Project 1',
        'status': 'In Progress',
        'location': 'Sample Location',
        'managedBy': 'Development Mode'
      },
      {
        'id': 2,
        'name': 'Sample Project 2',
        'status': 'Completed',
        'location': 'Test Location',
        'managedBy': 'Development Mode'
      }
    ];
  }
  
  Future<Map<String, dynamic>> getProjectById(int id) async {
    try {
      final response = await get('api/Projects/$id');
      
      if (response is Map<String, dynamic>) {
        return response;
      } else if (response is Map && response['data'] != null) {
        return response['data'];
      }
      
      return {};
    } catch (e) {
      debugPrint('Error fetching project details: $e');
      // Return a mock project if offline mode is enabled
      if (AppConfig.enableOfflineMode) {
        final mockProjects = _getMinimalMockProjects();
        final mockProject = mockProjects.firstWhere(
          (p) => p['id'] == id,
          orElse: () => mockProjects.first,
        );
        return mockProject;
      }
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> createProject(Map<String, dynamic> project) async {
    try {
      debugPrint('Creating project with data: $project');
      
      // Use the same multipart/form-data approach the website uses
      try {
        debugPrint('Trying multipart/form-data approach for project creation');
        final uri = Uri.parse('$_baseUrl/api/Projects/AddProject');
        final headers = await _getHeaders();
        headers.remove('Content-Type'); // Let multipart set the content type
        
        // Create multipart request
        final request = http.MultipartRequest('POST', uri);
        request.headers.addAll(headers);
        
        // Add project data as fields - using the exact same field names as the website
        request.fields['command.Title'] = project['title'] ?? '';
        request.fields['command.Description'] = project['description'] ?? '';
        request.fields['command.Location'] = project['location'] ?? '';
        request.fields['command.Status'] = project['status'] ?? 'In Progress';
        
        // If there's a guid in the project data, include it
        if (project['guid'] != null) {
          request.fields['command.Guid'] = project['guid'];
        }
        
        debugPrint('Sending multipart request to: $uri');
        debugPrint('Multipart fields: ${request.fields}');
        
        // Send request
        final streamedResponse = await request.send()
            .timeout(Duration(seconds: AppConfig.connectionTimeout));
        
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint('Multipart response status: ${response.statusCode}');
        debugPrint('Multipart response body: ${response.body}');
        
        final responseData = _handleResponse(response);
        
        Map<String, dynamic> projectData;
        if (responseData is Map && responseData['data'] != null) {
          projectData = Map<String, dynamic>.from(responseData['data']);
        } else if (responseData is Map<String, dynamic>) {
          projectData = responseData;
        } else {
          throw Exception('Invalid response format from AddProject endpoint');
        }
        
        // Force refresh the project list from server to ensure synchronization
        await getProjects();
        
        return projectData;
      } catch (e) {
        debugPrint('Multipart approach failed: $e');
        // Continue to fallback approach
      }
      
      // Fallback to standard JSON endpoint
      debugPrint('Trying JSON approach for project creation');
      final response = await post('api/Projects', {'command': project});
      
      if (response is Map && response['data'] != null) {
        final projectData = Map<String, dynamic>.from(response['data']);
        
        // Force refresh the project list from server
        await getProjects();
        
        return projectData;
      } else if (response is Map<String, dynamic>) {
        // Force refresh the project list from server
        await getProjects();
        
        return response;
      }
      
      throw Exception('Failed to create project: Invalid response format from both endpoints');
    } catch (e) {
      debugPrint('Error creating project: $e');
      if (AppConfig.enableOfflineMode) {
        // Create a mock project with a new ID
        final mockProject = {
          ...project,
          'id': DateTime.now().microsecondsSinceEpoch,
          'guid': DateTime.now().millisecondsSinceEpoch.toString(),
        };
        return mockProject;
      }
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> updateProject(int id, Map<String, dynamic> project) async {
    try {
      final response = await put('api/Projects/$id', {'command': project});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      } else if (response is Map<String, dynamic>) {
        return response;
      }
      
      throw Exception('Failed to update project: Invalid response format');
    } catch (e) {
      debugPrint('Error updating project: $e');
      if (AppConfig.enableOfflineMode) {
        return {...project, 'id': id};
      }
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> deleteProject(int id) async {
    try {
      final response = await delete('api/Projects/$id');
      return response is Map<String, dynamic> ? response : {'success': true};
    } catch (e) {
      debugPrint('Error deleting project: $e');
      if (AppConfig.enableOfflineMode) {
        return {'success': true};
      }
      rethrow;
    }
  }
  
  // API methods for users
  
  Future<dynamic> getUsers({int? page, int? pageSize}) async {
    try {
      print('[API] Getting users, page: $page, pageSize: $pageSize');
      
      final response = await _get('/api/Employees');
      print('[API] Users response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('[API] Successfully fetched ${data.length} users');
        
        // Return as List<Map<String, dynamic>>
        List<Map<String, dynamic>> users = [];
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            users.add(item);
          }
        }
        
        return users;
      } else {
        print('[API] Failed to get users: ${response.statusCode} - ${response.body}');
        // Fall back to mock data if the API fails
        print('[API] Falling back to mock users');
        return getMockUsers();
      }
    } catch (e) {
      print('[API] Error getting users: $e');
      // Return mock data in case of an error
      print('[API] Falling back to mock users after error');
      return getMockUsers();
    }
  }
  
  List<Map<String, dynamic>> getMockUsers() {
    return [
      {
        'id': 1,
        'userName': 'SAdmin',
        'firstName': 'System',
        'lastName': 'Administrator',
        'email': 'admin@example.com',
        'phoneNumber': '+1234567890',
        'role': 'Administrator',
        'isActive': true,
      },
      {
        'id': 2,
        'userName': 'Manager1',
        'firstName': 'Project',
        'lastName': 'Manager',
        'email': 'manager@example.com',
        'phoneNumber': '+0987654321',
        'role': 'Project Manager',
        'isActive': true,
      },
      {
        'id': 3,
        'userName': 'Developer1',
        'firstName': 'John',
        'lastName': 'Developer',
        'email': 'dev1@example.com',
        'phoneNumber': '+1122334455',
        'role': 'Developer',
        'isActive': true,
      },
      {
        'id': 4,
        'userName': 'Designer1',
        'firstName': 'Sarah',
        'lastName': 'Designer',
        'email': 'design1@example.com',
        'phoneNumber': '+5566778899',
        'role': 'Designer',
        'isActive': true,
      },
      {
        'id': 5,
        'userName': 'QA1',
        'firstName': 'Michael',
        'lastName': 'Tester',
        'email': 'qa1@example.com',
        'phoneNumber': '+9988776655',
        'role': 'QA Engineer',
        'isActive': true,
      }
    ];
  }
  
  // API methods for logs
  
  Future<List<Map<String, dynamic>>> getLogs({
    String? userName,
    String? entityName,
    String? action,
    DateTime? fromDate,
    DateTime? toDate,
    int? page,
    int? pageSize = 1000, // Increased to fetch many more logs at once
  }) async {
    try {
      debugPrint('[API] Getting logs with filters');
      
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
      
      // Always include pagination parameters with much higher pageSize
      queryParams['page'] = (page ?? 1).toString();
      queryParams['pageSize'] = (pageSize ?? 1000).toString();
      
      // Use the exact same endpoint as the website with no fallbacks
      String url = 'api/AuditLog';
      if (queryParams.isNotEmpty) {
        url += '?' + queryParams.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
      }
      
      debugPrint('[API] Using website log endpoint: $url');
      
      final response = await get(url);
      debugPrint('[API] AuditLog response type: ${response.runtimeType}');
      
      List<Map<String, dynamic>> logs = [];
      
      // Process response based on its structure
      if (response is List) {
        debugPrint('[API] Response is a List with ${response.length} items');
        logs = List<Map<String, dynamic>>.from(response);
      } else if (response is Map<String, dynamic>) {
        if (response.containsKey('items') && response['items'] is List) {
          debugPrint('[API] Found items in response with ${response['items'].length} logs');
          logs = List<Map<String, dynamic>>.from(response['items']);
        } else if (response.containsKey('data') && response['data'] is List) {
          debugPrint('[API] Found data in response with ${response['data'].length} logs');
          logs = List<Map<String, dynamic>>.from(response['data']);
        } else if (response.containsKey('result') && response['result'] is List) {
          debugPrint('[API] Found result in response with ${response['result'].length} logs');
          logs = List<Map<String, dynamic>>.from(response['result']);
        } else if (response.containsKey('logs') && response['logs'] is List) {
          debugPrint('[API] Found logs in response with ${response['logs'].length} logs');
          logs = List<Map<String, dynamic>>.from(response['logs']);
        } else {
          // Try to find any List in the response
          for (var key in response.keys) {
            if (response[key] is List && (response[key] as List).isNotEmpty) {
              debugPrint('[API] Found list in key $key with ${response[key].length} items');
              logs = List<Map<String, dynamic>>.from(response[key]);
              break;
            }
          }
        }
      }
      
      debugPrint('[API] Successfully processed ${logs.length} logs');
      
      // If no logs found, try the direct response if it has log-like structure
      if (logs.isEmpty && response is Map<String, dynamic>) {
        if (response.containsKey('userName') && response.containsKey('action')) {
          logs.add(response);
        }
      }
      
      // Only use mock data if completely empty
      if (logs.isEmpty) {
        debugPrint('[API] No logs found from API, using mock data');
        logs = getMockLogs();
      }
      
      return logs;
    } catch (e) {
      debugPrint('[API] Error getting logs: $e');
      // Return mock data in case of an error
      return getMockLogs();
    }
  }
  
  List<Map<String, dynamic>> getMockLogs() {
    // Return sample logs for testing
    return [
      {
        'id': 1,
        'userName': 'SAdmin',
        'entityName': 'Project',
        'action': 'Create',
        'details': 'Created project "Website Redesign"',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      },
      {
        'id': 2,
        'userName': 'Manager1',
        'entityName': 'User',
        'action': 'Update',
        'details': 'Updated user profile for "John Smith"',
        'timestamp': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'id': 3,
        'userName': 'SAdmin',
        'entityName': 'Bucket',
        'action': 'Delete',
        'details': 'Deleted bucket "Frontend Development"',
        'timestamp': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      },
      {
        'id': 4,
        'userName': 'Developer1',
        'entityName': 'Project',
        'action': 'Update',
        'details': 'Updated project status to "Completed"',
        'timestamp': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      },
      {
        'id': 5,
        'userName': 'SAdmin',
        'entityName': 'Project',
        'action': 'Create',
        'details': 'Created project "Mobile App Development"',
        'timestamp': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      },
    ];
  }
  
  // API methods for buckets
  
  Future<List<Map<String, dynamic>>> getBuckets({int projectId = 0}) async {
    try {
      debugPrint('Fetching buckets for projectId=$projectId');
      
      // Use the project GUID to fetch buckets from the API
      final endpoint = projectId > 0 
        ? 'api/Buckets/GetProjectBuckets?ProjectGuid=$projectId'
        : 'api/Buckets/GetDefaults';
      
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
      
      // If no valid response, use minimal mock data
      if (AppConfig.enableOfflineMode) {
        debugPrint('Using minimal mock buckets in offline mode');
        return _getMinimalMockBuckets(projectId);
      }
      
      return [];
    } catch (e) {
      debugPrint('Error fetching buckets: $e');
      
      if (AppConfig.enableOfflineMode) {
        return _getMinimalMockBuckets(projectId);
      }
      
      rethrow; // Rethrow to allow proper error handling in the UI
    }
  }
  
  // Create or update a bucket
  Future<Map<String, dynamic>> createBucket(Map<String, dynamic> bucketData) async {
    try {
      final response = await post('api/Buckets', {'command': bucketData});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      
      throw Exception('Failed to create bucket: Invalid response format');
    } catch (e) {
      debugPrint('Error creating bucket: $e');
      
      if (AppConfig.enableOfflineMode) {
        // Create a mock bucket with a new ID and GUID
        final mockBucket = {
          ...bucketData,
          'id': DateTime.now().microsecondsSinceEpoch,
          'guid': DateTime.now().millisecondsSinceEpoch.toString(),
        };
        return mockBucket;
      }
      
      rethrow;
    }
  }
  
  // Update a bucket
  Future<Map<String, dynamic>> updateBucket(Map<String, dynamic> bucketData) async {
    try {
      final id = bucketData['id'];
      final response = await put('api/Buckets/$id', {'command': bucketData});
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      
      throw Exception('Failed to update bucket: Invalid response format');
    } catch (e) {
      debugPrint('Error updating bucket: $e');
      
      if (AppConfig.enableOfflineMode) {
        // Return the data with a mock update timestamp
        return {
          ...bucketData,
          'lastModified': DateTime.now().toIso8601String(),
        };
      }
      
      rethrow;
    }
  }
  
  // Add a bucket to a project
  Future<Map<String, dynamic>> addBucketToProject(Map<String, dynamic> bucketData, String projectGuid) async {
    try {
      bucketData['parentGuid'] = projectGuid;
      final response = await post('api/Buckets/AddBucketToProject', bucketData);
      
      if (response is Map && response['data'] != null) {
        return Map<String, dynamic>.from(response['data']);
      }
      
      throw Exception('Failed to add bucket to project: Invalid response format');
    } catch (e) {
      debugPrint('Error adding bucket to project: $e');
      
      if (AppConfig.enableOfflineMode) {
        // Create a mock bucket with a new ID and GUID
        final mockBucket = {
          ...bucketData,
          'id': DateTime.now().microsecondsSinceEpoch,
          'guid': DateTime.now().millisecondsSinceEpoch.toString(),
          'projectGuid': projectGuid,
        };
        return mockBucket;
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
      
      if (AppConfig.enableOfflineMode) {
        return [];
      }
      
      rethrow;
    }
  }
  
  // Minimal mock buckets data for development
  List<Map<String, dynamic>> _getMinimalMockBuckets(int projectId) {
    return [
      {
        'id': 1,
        'name': 'Development Bucket',
        'description': 'Sample bucket for development',
        'projectId': projectId,
        'guid': '123e4567-e89b-12d3-a456-426614174000',
        'line': 1,
        'employees': []
      },
      {
        'id': 2,
        'name': 'Testing Bucket',
        'description': 'Sample bucket for testing',
        'projectId': projectId,
        'guid': '993e4567-e89b-12d3-a456-426614174001',
        'line': 2,
        'employees': []
      }
    ];
  }
  
  // Private HTTP methods for API communication
  Future<http.Response> _get(String endpoint) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}$endpoint');
    
    print('[API] GET request to: $url');
    
    String? authToken;
    try {
      authToken = await _authService.storage.read(key: 'accessToken');
    } catch (e) {
      print('[API] Error getting auth token: $e');
    }
    
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    
    try {
      final response = await http.get(url, headers: headers);
      return response;
    } catch (e) {
      print('[API] Error in GET request: $e');
      throw Exception('Network error: $e');
    }
  }
}
