import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'session_controller.dart';

/// Shown while the stored login is checked at start-up. If that check fails
/// (typically no connection) it offers a retry instead of signing the person out.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final failed = session.hasError;
    return Scaffold(
      backgroundColor: failed ? null : Brand.navy,
      body: SafeArea(
        child: failed
            ? ErrorView(
                error: session.error!,
                onRetry: () => ref.invalidate(sessionProvider),
              )
            : Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Image.asset('assets/images/logo_full.png', width: 200),
                ),
              ),
      ),
    );
  }
}
