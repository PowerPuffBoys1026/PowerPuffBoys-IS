/// App-wide configuration.
///
/// Override the API base URL at build/run time, e.g.:
///   flutter run -d edge --dart-define=API_BASE_URL=http://localhost:3000/api
class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
}
