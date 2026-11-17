import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../../core/push_service.dart';
import '../jobs/live_location.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),
  ),
);

/// Who is signed in. `null` data means signed out; an error means the
/// session could not be checked (usually offline) and the splash screen
/// offers a retry rather than silently logging the person out.
class SessionController extends AsyncNotifier<CleanerProfile?> {
  @override
  Future<CleanerProfile?> build() async {
    ref.read(apiClientProvider).onSessionExpired = _expired;

    final tokens = ref.read(tokenStoreProvider);
    await tokens.load();
    if (tokens.refresh == null) return null;

    try {
      final profile = await ref.read(authRepositoryProvider).loadProfile();
      ref.read(pushServiceProvider).start();
      return profile;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await tokens.clear();
        return null;
      }
      rethrow;
    }
  }

  /// Called after a successful login: loads the profile and enters the app.
  Future<void> completeSignIn() async {
    final profile = await ref.read(authRepositoryProvider).loadProfile();
    state = AsyncData(profile);
    ref.read(pushServiceProvider).start();
  }

  void updateProfile(CleanerProfile profile) {
    if (state.valueOrNull != null) state = AsyncData(profile);
  }

  Future<void> signOut() async {
    await ref.read(liveLocationProvider.notifier).stop();
    await ref.read(pushServiceProvider).stop();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  void _expired() {
    state = const AsyncData(null);
  }
}

final sessionProvider =
    AsyncNotifierProvider<SessionController, CleanerProfile?>(
  SessionController.new,
);
