/// Runtime configuration. Override the API base at build/run time:
///   flutter run --dart-define=API_BASE_URL=https://nuzl.ae/api
/// Defaults to same-origin /api for web, localhost for dev.
class Env {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );
}
