import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class DatabaseService {
  // Singleton pattern
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  final String _baseUrl = AppConfig.apiBaseUrl;
  bool _isConnected = false;
  
  // Initialize connection - now just checks API connectivity
  Future<void> init() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      _isConnected = response.statusCode == 200;
      debugPrint('API connection established: $_isConnected');
    } catch (e) {
      _isConnected = false;
      debugPrint('Failed to connect to API: $e');
      rethrow;
    }
  }
  
  // Check connection status
  bool get isConnected => _isConnected;
  
  // Close connection - no longer needed with HTTP
  Future<void> close() async {
    _isConnected = false;
    debugPrint('API connection reset');
  }
  
  // Execute a query that returns results - now uses API
  Future<List<Map<String, dynamic>>> query(String endpoint, [Map<String, dynamic>? parameters]) async {
    if (!_isConnected) {
      await init();
    }
    
    try {
      final Uri uri;
      if (parameters != null && parameters.isNotEmpty) {
        // Convert parameters to query string
        final queryParams = parameters.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}').join('&');
        uri = Uri.parse('$_baseUrl/$endpoint?$queryParams');
      } else {
        uri = Uri.parse('$_baseUrl/$endpoint');
      }
      
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data['data'] != null && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        return [];
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Query error: $e');
      rethrow;
    }
  }
  
  // Execute a mutation that doesn't return results
  Future<int> execute(String endpoint, [Map<String, dynamic>? body]) async {
    if (!_isConnected) {
      await init();
    }
    
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body != null ? jsonEncode(body) : null,
      ).timeout(Duration(seconds: AppConfig.connectionTimeout));
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return 1; // Simulating rows affected
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Execute error: $e');
      rethrow;
    }
  }
  
  // Get users
  Future<List<Map<String, dynamic>>> getUsers() async {
    return await query('Users');
  }
  
  // Get projects
  Future<List<Map<String, dynamic>>> getProjects() async {
    return await query('Projects');
  }
  
  // Get project by ID
  Future<Map<String, dynamic>?> getProjectById(int id) async {
    final results = await query('Projects/$id');
    return results.isNotEmpty ? results.first : null;
  }
  
  // Create a new project
  Future<int> createProject(Map<String, dynamic> project) async {
    return await execute('Projects', project);
  }
  
  // Update a project
  Future<int> updateProject(int id, Map<String, dynamic> project) async {
    project['id'] = id;
    return await execute('Projects/$id', project);
  }
  
  // Delete a project
  Future<int> deleteProject(int id) async {
    return await execute('Projects/$id');
  }
} 