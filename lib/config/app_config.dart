import 'package:flutter/foundation.dart';

class AppConfig {
  // Backend API configuration
  static const String apiHost = 'albani.smartsoft-me.com';
  static const String apiIpAddress = '64.227.31.17'; // IP address from ping test
  static const bool useHttps = true;
  static const int apiPort = 443;  // HTTPS port
  static const String apiBaseUrl = 'https://$apiHost';
  static const String apiIpUrl = 'https://$apiIpAddress'; // Always use HTTPS
  
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
  static const int apiTimeoutSeconds = 30;     // Timeout for API calls
  
  // Feature flags
  static const bool enableOfflineMode = false;  // Disable offline mode for production
  static const bool debugMode = false;          // Disable debug mode for production
  static const bool acceptUntrustedCertificates = true; // Accept untrusted certificates in release mode
  
  // Debug settings
  static bool get debugApiCalls => kDebugMode; // Only enable in debug mode
  
  // API Headers
  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'Host': apiHost,
    'Origin': 'https://$apiHost',
    'Referer': 'https://$apiHost/',
  };

  // Storage keys
  static const String tokenKey = 'accessToken';
  static const String refreshTokenKey = 'refreshToken';
  static const String tokenExpirationKey = 'tokenExpiration';
  static const String userIdKey = 'userId';
  static const String userNameKey = 'userName';
  
  // Debug flags
  static const bool mockApiCalls = false;
} 