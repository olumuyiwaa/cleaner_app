import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'me_data.dart';

/// Stripe Connect status and onboarding for receiving payouts.
class PayoutsScreen extends ConsumerStatefulWidget {
  const PayoutsScreen({super.key});

  @override
  ConsumerState<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends ConsumerState<PayoutsScreen> with WidgetsBindingObserver {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back from the browser: re-check the status.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(stripeStatusProvider);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final url = await ref.read(meRepositoryProvider).stripeOnboardingUrl();
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) showInfo(context, context.t('job.cannotOpen'));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(stripeStatusProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile.payouts'))),
      body: status.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(stripeStatusProvider)),
        data: (s) {
          final ready = s.connected && s.payoutsEnabled;
          final IconData icon;
          final Color color;
          final String key;
          if (ready) {
            icon = Icons.check_circle;
            color = const Color(0xFF3F8A10);
            key = 'payouts.ready';
          } else if (s.connected && s.detailsSubmitted) {
            icon = Icons.hourglass_top;
            color = const Color(0xFFD98200);
            key = 'payouts.review';
          } else if (s.connected) {
            icon = Icons.error_outline;
            color = const Color(0xFFD98200);
            key = 'payouts.incomplete';
          } else {
            icon = Icons.account_balance_outlined;
            color = Theme.of(context).hintColor;
            key = 'payouts.notConnected';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(icon, size: 44, color: color),
                      const SizedBox(height: 12),
                      Text(
                        context.t('$key.title'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.t('$key.body'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!ready)
                FilledButton(
                  onPressed: _busy ? null : _start,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(s.connected
                          ? context.t('payouts.continue')
                          : context.t('payouts.connect')),
                )
              else
                OutlinedButton(
                  onPressed: _busy ? null : _start,
                  child: Text(context.t('payouts.manage')),
                ),
            ],
          );
        },
      ),
    );
  }
}
