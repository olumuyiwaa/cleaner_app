/// Build-time configuration. Override with:
///   flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
class AppConfig {
  AppConfig._();

  /// Backend base URL including the /api/v1 prefix.
  /// 10.0.2.2 is the Android emulator's alias for the host machine's localhost
  /// (the backend listens on :8000 locally). iOS simulator users should pass
  /// http://localhost:8000/api/v1 instead.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  /// How often the live position is sent to dispatch while a job is in progress.
  static const Duration locationPingInterval = Duration(seconds: 60);

  /// How often an open chat polls for new messages.
  static const Duration chatPollInterval = Duration(seconds: 8);

  /// Where Stripe sends the cleaner back to after onboarding. Stripe needs an
  /// https page; the web cleaner portal works for that.
  static const String stripeReturnUrl = String.fromEnvironment(
    'STRIPE_RETURN_URL',
    defaultValue: 'https://todcleaningservice.vercel.app/cleaner/profile',
  );
}
