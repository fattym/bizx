class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bd2-production.up.railway.app',
  );

  static String aiChatUrl() => '$baseUrl/api/ai/chat';
}
