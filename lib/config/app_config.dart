import 'package:flutter/foundation.dart';

class AppConfig {
  // Backend API configuration
  static const String apiHost = 'albani.smartsoft-me.com';
  static const bool useHttps = true;
  static const int apiPort = 443;  // HTTPS port
  static const String apiBaseUrl = '${useHttps ? "https" : "http"}://$apiHost';
  
  // Database info (for reference only)
  static const String dbHost = 'localhost';  // From your appsettings.json
  static const int dbPort = 5432;  // Default PostgreSQL port
  static const String dbName = 'project_manager_db';  // From your appsettings.json
  static const String dbUsername = 'postgres';  // From your appsettings.json
  static const String dbPassword = 'postgres';  // Default password, replace with actual password
  static const bool dbUseSSL = false;  // Set to true if SSL is required
  
  // App settings
  static const int connectionTimeout = 30;  // in seconds
  static const int maxRetryAttempts = 3;
  static const int paginationLimit = 10;  // Number of projects per page
  
  // Feature flags
  static const bool enableOfflineMode = false;  // Permanently disable offline mode
  static const bool debugMode = true;          // Enable debug prints for development
  static const int apiTimeoutSeconds = 30;     // Timeout for API calls
  
  // Debug settings
  static bool get debugApiCalls => kDebugMode;  // Only true in debug builds

  // Default values
  static const String defaultUsername = 'SAdmin';  // Default username for testing
  static const String defaultPassword = 'P@ssw0rd';  // Default password for testing

  // Mock data configuration
  static const int mockProjectsCount = 5;       // Number of mock projects to generate
  static const int mockBucketsCount = 5;        // Number of mock buckets per project
  static const int mockFilesCount = 3;          // Number of mock files per bucket
  static const int mockTasksCount = 2;          // Number of mock tasks per bucket

  // Storage keys
  static const String tokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String tokenExpirationKey = 'tokenExpiration';
  static const String userIdKey = 'userId';
  static const String userNameKey = 'userName';
  
  // Debug flags
  static const bool mockApiCalls = false;
} 