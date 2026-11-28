/// App-wide configuration.
///
/// `API_BASE_URL` is the build default. The app does not silently auto-discover
/// at startup: use Server settings to run Auto-detect and save an address you
/// have reviewed. That override survives rebuilds.
class AppConfig {
  static const String explicitApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String localBaseUrl = 'http://localhost:3000/api';

  static final String apiBaseUrl =
      explicitApiBaseUrl.isEmpty ? localBaseUrl : explicitApiBaseUrl;
}
