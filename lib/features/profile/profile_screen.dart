import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../auth/auth_models.dart';
import '../auth/session_controller.dart';
import 'me_data.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploading = false;

  Future<void> _changeAvatar() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 82,
      );
      if (picked == null) return;
      setState(() => _uploading = true);
      final bytes = await picked.readAsBytes();
      final name = picked.name.toLowerCase();
      final type = name.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final profile =
          await ref.read(meRepositoryProvider).uploadAvatar(bytes, type);
      ref.read(sessionProvider.notifier).updateProfile(profile);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _editPhone(CleanerProfile profile) async {
    final controller = TextEditingController(text: profile.phone ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('profile.phone')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(labelText: ctx.t('profile.phone')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.t('common.save')),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    try {
      final updated = await ref.read(meRepositoryProvider).updatePhone(value);
      ref.read(sessionProvider.notifier).updateProfile(updated);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _signOut() async {
    final ok = await confirm(
      context,
      title: context.t('profile.signOut'),
      message: context.t('profile.signOutConfirm'),
      confirmLabel: context.t('profile.signOut'),
      destructive: true,
    );
    if (ok) await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider).valueOrNull;
    final lang = ref.watch(localeProvider).languageCode;
    if (profile == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(title: Text(context.t('nav.profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          // Dark hero identity card matching mockup style
          Container(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Brand.pillNav,
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _changeAvatar,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(profile.initials,
                                style: const TextStyle(fontSize: 26))
                            : null,
                      ),
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Brand.blue,
                        child: _uploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.edit,
                                size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  profile.businessName,
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: Text(profile.email),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(profile.phone ?? context.t('profile.addPhone')),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => _editPhone(profile),
                ),
              ],
            ),
          ),
          SectionTitle(context.t('profile.work')),
          Card(
            child: Column(
              children: [
                _nav(context, Icons.schedule, 'profile.availability',
                    '/availability'),
                _nav(context, Icons.beach_access_outlined, 'profile.leave',
                    '/leave'),
                _nav(context, Icons.folder_outlined, 'profile.documents',
                    '/documents'),
                _nav(context, Icons.account_balance_outlined, 'profile.payouts',
                    '/payouts'),
                _nav(context, Icons.security_outlined, 'profile.security',
                    '/security'),
              ],
            ),
          ),
          SectionTitle(context.t('profile.language')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'en', label: Text('English')),
                  ButtonSegment(value: 'nl', label: Text('Nederlands')),
                ],
                selected: {lang},
                onSelectionChanged: (s) =>
                    ref.read(localeProvider.notifier).set(s.first),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            label: Text(context.t('profile.signOut')),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _nav(BuildContext context, IconData icon, String key, String route) =>
      ListTile(
        leading: Icon(icon),
        title: Text(context.t(key)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route),
      );
}
