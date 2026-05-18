class Constants {
  // Base URL of the Django backend's NinjaAPI mount. Override via
  // --dart-define=API_BASE_URL=https://api.excess.example.com/api/v1.
  // For Android emulator pointing at host Django: use http://10.0.2.2:8000/api/v1.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
}
