/// Build-time configuration. Override with:
///   flutter run --dart-define=API_BASE_URL=https://your-api.example.com/api/v1
class AppConfig {
  AppConfig._();

  /// Backend base URL including the /api/v1 prefix.
  /// The deployed backend is available at https://todcleaning.onrender.com/api/v1.
  /// Local development can still override this with --dart-define=API_BASE_URL.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://todcleaning.onrender.com/api/v1',
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
