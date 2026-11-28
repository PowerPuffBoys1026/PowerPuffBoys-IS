/// App-wide configuration.
///
/// `API_BASE_URL` is only the last-resort fallback. On mobile the app first
/// auto-discovers the API on the device's current LAN, and a user can override
/// the address in Server settings without rebuilding.
class AppConfig {
  static const String explicitApiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String localBaseUrl = 'http://localhost:3000/api';

  static final String apiBaseUrl =
      explicitApiBaseUrl.isEmpty ? localBaseUrl : explicitApiBaseUrl;
}
