/// Centralized configuration for the application
/// Change these URLs when deploying to production
class AppConfig {
  // ============================================================================
  // API CONFIGURATION
  // ============================================================================
  
  /// Base URL for the backend API
  /// 
  /// Development: 'http://localhost:3000'
  /// Production: 'https://api.mybox.buildersolve.com'
  static const String apiBaseUrl = 'https://api.mybox.buildersolve.com';
  
  /// API endpoints
  static const String apiPrefix = '/api';
  
  /// Full API URL
  static String get apiUrl => '$apiBaseUrl$apiPrefix';
  
  // ============================================================================
  // OAUTH ENDPOINTS
  // ============================================================================
  
  /// Google OAuth URL
  static String googleAuthUrl(String companyId, String userId) {
    return '$apiBaseUrl/auth/google?companyId=$companyId&userId=$userId';
  }
  
  /// Microsoft OAuth URL
  static String microsoftAuthUrl(String companyId, String userId) {
    return '$apiBaseUrl/auth/microsoft?companyId=$companyId&userId=$userId';
  }
  
  // ============================================================================
  // API ENDPOINTS
  // ============================================================================
  
  /// Emails endpoint
  static String get emailsEndpoint => '$apiUrl/emails';
  
  /// Calendar events endpoint
  static String get calendarEventsEndpoint => '$apiUrl/calendar/events';
  
  /// Mark email as read endpoint
  static String emailReadEndpoint(String id) => '$apiUrl/emails/$id/read';
  
  /// Test connection endpoint
  static String get testConnectionEndpoint => '$apiUrl/test-connection';
  
  /// Health check endpoint
  static String get healthEndpoint => '$apiBaseUrl/health';
}
