import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import '../auth/session_controller.dart';

final twoFactorEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(authRepositoryProvider).twoFactorEnabled(),
);

/// Change password and two-factor sign-in.
class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final twoFactor = ref.watch(twoFactorEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('profile.security'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(context.t('security.changePassword')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _changePassword(context, ref),
            ),
          ),
          const SizedBox(height: 12),
          twoFactor.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(twoFactorEnabledProvider),
            ),
            data: (enabled) => Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(enabled ? Icons.verified_user : Icons.shield_outlined,
                            color: enabled ? const Color(0xFF3F8A10) : null),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.t('security.twoFactor'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        StatusPill(
                          label: enabled ? context.t('security.on') : context.t('security.off'),
                          color: enabled ? const Color(0xFF3F8A10) : const Color(0xFF6B7585),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.t('security.twoFactorBody'),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    const SizedBox(height: 14),
                    enabled
                        ? OutlinedButton(
                            onPressed: () => _disable(context, ref),
                            child: Text(context.t('security.disable')),
                          )
                        : FilledButton(
                            onPressed: () => _enable(context, ref),
                            child: Text(context.t('security.enable')),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('security.changePassword')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: InputDecoration(labelText: ctx.t('security.currentPassword')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: InputDecoration(
                labelText: ctx.t('security.newPassword'),
                helperText: ctx.t('security.passwordRule'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('common.save')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (next.text.length < 8) {
      showInfo(context, context.t('security.passwordRule'));
      return;
    }
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(current: current.text, next: next.text);
      if (context.mounted) showInfo(context, context.t('security.passwordChanged'));
      // The server ends every session after a password change.
      await ref.read(sessionProvider.notifier).signOut();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _enable(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(authRepositoryProvider);
    try {
      final setup = await repo.generateTwoFactor();
      if (!context.mounted) return;
      final code = TextEditingController();
      final entered = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('security.setupTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.t('security.setupStep1')),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(ctx.t('security.openAuthenticator')),
                  onPressed: () => launchUrl(
                    Uri.parse(setup.otpauthUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const SizedBox(height: 8),
                Text(ctx.t('security.setupManual')),
                const SizedBox(height: 4),
                SelectableText(
                  setup.secret,
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(ctx.t('security.copyKey')),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: setup.secret));
                    showInfo(ctx, ctx.t('common.copied'));
                  },
                ),
                const SizedBox(height: 8),
                Text(ctx.t('security.setupStep2')),
                const SizedBox(height: 8),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: ctx.t('login.code')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: () => Navigator.pop(ctx, code.text.trim()),
              child: Text(ctx.t('security.enable')),
            ),
          ],
        ),
      );
      if (entered == null || entered.isEmpty || !context.mounted) return;
      await repo.enableTwoFactor(entered);
      ref.invalidate(twoFactorEnabledProvider);
      if (context.mounted) showInfo(context, context.t('security.enabled'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _disable(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('security.disable')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: password,
              obscureText: true,
              decoration: InputDecoration(labelText: ctx.t('login.password')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: ctx.t('login.code')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('security.disable')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(authRepositoryProvider)
          .disableTwoFactor(password: password.text, code: code.text.trim());
      ref.invalidate(twoFactorEnabledProvider);
      if (context.mounted) showInfo(context, context.t('security.disabled'));
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
