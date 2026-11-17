import '../../core/api/api_client.dart';
import '../../core/api/token_store.dart';
import '../../core/json.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  /// POST /auth/login. May answer that a workplace must be chosen first
  /// (the person works for more than one business), or that two-factor is
  /// needed (surfaced as an [ApiException] with code TWO_FACTOR_REQUIRED).
  Future<LoginResult> login({
    required String email,
    required String password,
    String? twoFactorCode,
    String? businessId,
  }) async {
    final data = mapOf(
      await _api.post(
        '/auth/login',
        body: {
          'email': email,
          'password': password,
          if (twoFactorCode != null && twoFactorCode.isNotEmpty)
            'twoFactorCode': twoFactorCode,
          if (businessId != null) 'businessId': businessId,
        },
      ),
    );

    if (data['requiresBusinessSelection'] == true) {
      final cleanerChoices = mapsOf(data['affiliations'])
          .map(Affiliation.fromJson)
          .where((a) => a.role == 'CLEANER')
          .toList();
      if (cleanerChoices.isEmpty) return const LoginResult.notCleaner();
      return LoginResult.selectBusiness(cleanerChoices);
    }

    final accessToken = str(data['accessToken']);
    final refreshToken = str(data['refreshToken']);
    if (accessToken == null || refreshToken == null) {
      throw ApiException('Unexpected response from the server');
    }

    // Signed in as office staff rather than a cleaner: this app is for cleaners only.
    if (data['cleanerProfile'] == null) {
      try {
        await _api.post('/auth/logout', body: {'refreshToken': refreshToken});
      } catch (_) {
        // Best effort: the unused session simply expires.
      }
      return const LoginResult.notCleaner();
    }

    await _tokens.save(access: accessToken, refresh: refreshToken);
    return const LoginResult.ok();
  }

  Future<CleanerProfile> loadProfile() async {
    final data = await _api.get('/cleaners/me');
    return CleanerProfile.fromJson(mapOf(data));
  }

  /// Emails a reset link (the backend always answers OK, so this never
  /// reveals whether an address has an account).
  Future<void> requestPasswordReset(String email) =>
      _api.post('/auth/password-reset/request', body: {'email': email});

  /// Whether two-factor sign-in is switched on for this account.
  Future<bool> twoFactorEnabled() async =>
      boolOf(mapOf(await _api.get('/auth/me'))['twoFactorEnabled']);

  /// Starts 2FA setup: returns the secret to put in an authenticator app.
  Future<({String secret, String otpauthUrl})> generateTwoFactor() async {
    final data = mapOf(await _api.post('/auth/2fa/generate'));
    final secret = str(data['base32']);
    final url = str(data['otpauth_url']);
    if (secret == null || url == null) {
      throw ApiException('Unexpected response from the server');
    }
    return (secret: secret, otpauthUrl: url);
  }

  Future<void> enableTwoFactor(String code) =>
      _api.post('/auth/2fa/verify-enable', body: {'token': code});

  Future<void> disableTwoFactor({required String password, required String code}) =>
      _api.post('/auth/2fa/disable', body: {'password': password, 'code': code});

  /// Changing the password signs every device out, so the caller should
  /// sign out afterwards.
  Future<void> changePassword({required String current, required String next}) => _api.patch(
        '/auth/me/password',
        body: {'currentPassword': current, 'newPassword': next},
      );

  Future<void> logout() async {
    final refresh = _tokens.refresh;
    try {
      if (refresh != null) {
        await _api.post('/auth/logout', body: {'refreshToken': refresh});
      }
    } catch (_) {
      // Signing out locally must always work, even offline.
    }
    await _tokens.clear();
  }
}
