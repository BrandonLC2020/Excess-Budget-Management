class Constants {
  // Base URL of the Django backend's NinjaAPI mount. Override via
  // --dart-define=API_BASE_URL=https://api.excess.example.com/api/v1.
  // For Android emulator pointing at host Django: use http://10.0.2.2:8000/api/v1.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  // Auth0 configurations
  static const String auth0Domain = String.fromEnvironment(
    'AUTH0_DOMAIN',
    defaultValue: 'b1codes.us.auth0.com',
  );

  static const String auth0ClientId = String.fromEnvironment(
    'AUTH0_CLIENT_ID',
    defaultValue: 'vHX8TZc34HJfNRyA8aVZquT6509YnWUp',
  );

  static const String auth0Audience = String.fromEnvironment(
    'AUTH0_AUDIENCE',
    defaultValue: 'https://api.excessbudget.com/',
  );
}
