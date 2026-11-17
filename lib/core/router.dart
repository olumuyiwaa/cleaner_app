import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/splash_screen.dart';
import '../features/earnings/earnings_screen.dart';
import '../features/jobs/job_chat_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/jobs_screen.dart';
import '../features/profile/availability_screen.dart';
import '../features/profile/documents_screen.dart';
import '../features/profile/leave_screen.dart';
import '../features/profile/payouts_screen.dart';
import '../features/profile/profile_screen.dart';
import 'l10n/strings.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  // Re-evaluate redirects whenever the session changes.
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final at = state.matchedLocation;

      // Still checking the stored login, or could not check it (offline).
      if ((session.isLoading && !session.hasValue) || session.hasError) {
        return at == '/splash' ? null : '/splash';
      }
      final signedIn = session.valueOrNull != null;
      if (!signedIn) return at == '/login' ? null : '/login';
      if (at == '/login' || at == '/splash') return '/jobs';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/jobs', builder: (_, __) => const JobsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/earnings', builder: (_, __) => const EarningsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      // Full-screen pages: no bottom bar.
      GoRoute(
        path: '/job/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/job/:id/chat',
        parentNavigatorKey: _rootKey,
        builder: (_, state) => JobChatScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/availability',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/leave',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const LeaveScreen(),
      ),
      GoRoute(
        path: '/documents',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/payouts',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const PayoutsScreen(),
      ),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.work_outline),
            selectedIcon: const Icon(Icons.work),
            label: context.t('nav.jobs'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: context.t('nav.earnings'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: context.t('nav.profile'),
          ),
        ],
      ),
    );
  }
}
