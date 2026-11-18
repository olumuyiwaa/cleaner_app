import 'dart:math' as math;

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
import '../features/jobs/offline_ui.dart';
import '../features/profile/availability_screen.dart';
import '../features/profile/documents_screen.dart';
import '../features/profile/leave_screen.dart';
import '../features/profile/payouts_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/security_screen.dart';
import 'l10n/strings.dart';
import 'theme.dart';

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
            GoRoute(
                path: '/earnings', builder: (_, __) => const EarningsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile', builder: (_, __) => const ProfileScreen()),
          ]),
        ],
      ),
      // Full-screen pages: no bottom bar.
      GoRoute(
        path: '/job/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            JobDetailScreen(jobId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/job/:id/chat',
        parentNavigatorKey: _rootKey,
        builder: (_, state) =>
            JobChatScreen(jobId: state.pathParameters['id']!),
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
        path: '/security',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const SecurityScreen(),
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
      body: QueueWatcher(child: shell),
      // Transparent bottom bar area so our floating pill sits above it.
      extendBody: true,
      bottomNavigationBar: _PillNavBar(shell: shell),
    );
  }
}

/// A floating dark-pill bottom navigation bar matching the UI guide.
class _PillNavBar extends StatelessWidget {
  const _PillNavBar({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.work_outline_rounded, Icons.work_rounded, context.t('nav.jobs')),
      (
        Icons.payments_outlined,
        Icons.payments_rounded,
        context.t('nav.earnings'),
      ),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        context.t('nav.profile'),
      ),
    ];

    return Padding(
      // Sit above the home indicator / gesture bar on phones that have one.
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        math.max(16.0, MediaQuery.of(context).padding.bottom),
      ),
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Brand.pillNav,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (i) {
            final selected = shell.currentIndex == i;
            final item = items[i];
            final label = item.$3;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: label,
                child: ExcludeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: () => shell.goBranch(
                      i,
                      initialLocation: i == shell.currentIndex,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      height: 52,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 10,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selected ? item.$2 : item.$1,
                            size: 21,
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.62),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.62),
                              fontSize: 10,
                              height: 1.1,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
