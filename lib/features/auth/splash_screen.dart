import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import 'session_controller.dart';

/// Shown while the stored login is checked at start-up. If that check fails
/// (typically no connection) it offers a retry instead of signing the person out.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: session.hasError
            ? ErrorView(
                error: session.error!,
                onRetry: () => ref.invalidate(sessionProvider),
              )
            : Center(
                child: Image.asset('assets/images/logo_full.png', width: 220),
              ),
      ),
    );
  }
}
