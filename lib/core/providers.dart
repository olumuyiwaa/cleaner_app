import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/token_store.dart';
import 'location_service.dart';

/// Overridden in main() with the real instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(tokenStoreProvider)),
);

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());

/// The app language (en / nl), remembered between launches. Defaults to the
/// phone's language when that is Dutch, English otherwise.
class LocaleController extends Notifier<Locale> {
  static const _key = 'language';

  @override
  Locale build() {
    final saved = ref.read(sharedPrefsProvider).getString(_key);
    if (saved == 'nl' || saved == 'en') return Locale(saved!);
    final device = PlatformDispatcher.instance.locale.languageCode;
    return Locale(device == 'nl' ? 'nl' : 'en');
  }

  Future<void> set(String languageCode) async {
    state = Locale(languageCode);
    await ref.read(sharedPrefsProvider).setString(_key, languageCode);
  }
}

final localeProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);
