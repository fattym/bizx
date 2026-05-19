class GoogleMapsConfig {
  static const String apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;
}

