class SupabaseConfig {
  static const String _urlValue = String.fromEnvironment('SUPABASE_URL');
  static const String _projectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
  );
  static const String _anonKeyValue = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
  static const String _defaultProjectRef = 'nlikgeqoocimbbqyaegq';
  static const String _defaultAnonKey =
      'sb_publishable_7GsRwLNjTPaUpulq5GrLfg_4HbEkq3Z';

  static String get url {
    if (_urlValue.isNotEmpty) return _urlValue;
    if (_projectRef.isNotEmpty) return 'https://$_projectRef.supabase.co';
    return 'https://$_defaultProjectRef.supabase.co';
  }

  static String get anonKey {
    if (_anonKeyValue.isNotEmpty) return _anonKeyValue;
    return _defaultAnonKey;
  }

  static bool get isConfigured => true;
}
