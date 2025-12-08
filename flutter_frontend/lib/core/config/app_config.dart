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
  
  /// API endpoints prefix
  static const String apiPrefix = '/api';
  
  /// Full API URL
  static String get apiUrl => '$apiBaseUrl$apiPrefix';
  
  // ============================================================================
  // WHATSAPP API CONFIGURATION (Now merged into main backend)
  // ============================================================================
  
  /// WhatsApp API prefix (part of main backend now)
  static const String whatsappApiPrefix = '/api/whatsapp';
  
  /// Full WhatsApp API URL
  static String get whatsappApiUrl => '$apiBaseUrl$whatsappApiPrefix';
  
  /// WhatsApp session status endpoint
  static String whatsappSessionStatus(String userId) => 
      '$whatsappApiUrl/session/status?userId=$userId';
  
  /// WhatsApp session start endpoint
  static String get whatsappSessionStart => '$whatsappApiUrl/session/start';
  
  /// WhatsApp session stop endpoint
  static String get whatsappSessionStop => '$whatsappApiUrl/session/stop';
  
  /// WhatsApp session QR endpoint
  static String whatsappQrCode(String userId) => 
      '$whatsappApiUrl/session/qr?userId=$userId';
  
  /// WhatsApp groups endpoint
  static String whatsappGroups(String userId) => 
      '$whatsappApiUrl/groups?userId=$userId';
  
  /// WhatsApp monitored groups endpoint
  static String whatsappMonitoredGroups(String userId) => 
      '$whatsappApiUrl/monitored?userId=$userId';
  
  /// WhatsApp monitor toggle endpoint
  static String get whatsappMonitor => '$whatsappApiUrl/monitor';
  
  /// WhatsApp messages endpoint
  static String whatsappMessages(String userId, {String? groupId, int limit = 50}) {
    var url = '$whatsappApiUrl/messages?userId=$userId&limit=$limit';
    if (groupId != null) url += '&groupId=$groupId';
    return url;
  }
  
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
  // EMAIL & CALENDAR API ENDPOINTS
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
