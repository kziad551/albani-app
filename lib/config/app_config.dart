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
  static const int paginationLimit = 7;  // Number of projects per page
  
  // Feature flags
  static const bool enableOfflineMode = true;  // Enable fallback to mock data if API fails
  
  // Debug settings
  static const bool debugApiCalls = true;  // Print API call details for debugging
} 