import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'auth_models.dart';
import 'session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  bool _busy = false;
  bool _showPassword = false;
  bool _needsCode = false;
  String? _error;
  List<Affiliation> _choices = const [];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit({String? businessId}) async {
    if (!(_formKey.currentState?.validate() ?? false) && businessId == null) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authRepositoryProvider).login(
            email: _email.text.trim(),
            password: _password.text,
            twoFactorCode: _needsCode ? _code.text.trim() : null,
            businessId: businessId,
          );
      if (!mounted) return;
      switch (result.kind) {
        case LoginKind.ok:
          await ref.read(sessionProvider.notifier).completeSignIn();
          // The router moves on once the session is set.
        case LoginKind.selectBusiness:
          if (result.choices.length == 1) {
            await _submit(businessId: result.choices.first.businessId);
          } else {
            setState(() => _choices = result.choices);
          }
        case LoginKind.notCleaner:
          setState(() => _error = context.t('login.notCleaner'));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'TWO_FACTOR_REQUIRED') {
        setState(() => _needsCode = true);
      } else if (e.isNetwork) {
        setState(() => _error = context.t('error.network'));
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = context.t('error.generic'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider).languageCode;

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 16,
              24,
              32,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Brand.navy, Brand.navyDark],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Image.asset('assets/images/logo_full.png', height: 40),
                    ),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected) ? Brand.navyDark : Colors.white,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected) ? Colors.white : Colors.transparent,
                        ),
                        side: const WidgetStatePropertyAll(BorderSide(color: Colors.white54)),
                      ),
                      segments: const [
                        ButtonSegment(value: 'en', label: Text('EN')),
                        ButtonSegment(value: 'nl', label: Text('NL')),
                      ],
                      selected: {lang},
                      onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(s.first),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  context.t('login.title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.t('login.subtitle'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: _choices.isNotEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _workplaceChooser(context),
                        )
                      : _form(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _workplaceChooser(BuildContext context) {
    return [
      Text(
        context.t('login.chooseWorkplace'),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      for (final choice in _choices) ...[
        OutlinedButton(
          onPressed: _busy ? null : () => _submit(businessId: choice.businessId),
          child: Text(choice.businessName),
        ),
        const SizedBox(height: 10),
      ],
      if (_error != null) _errorBox(context),
    ];
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: InputDecoration(labelText: context.t('login.email')),
            validator: (v) =>
                (v == null || !v.contains('@')) ? context.t('login.emailInvalid') : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _password,
            obscureText: !_showPassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: _needsCode ? TextInputAction.next : TextInputAction.done,
            onFieldSubmitted: (_) => _needsCode ? null : _submit(),
            decoration: InputDecoration(
              labelText: context.t('login.password'),
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? context.t('login.passwordRequired') : null,
          ),
          if (_needsCode) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _code,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              decoration: InputDecoration(
                labelText: context.t('login.code'),
                helperText: context.t('login.codeHelp'),
              ),
              onFieldSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) _errorBox(context),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : () => _submit(),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : Text(context.t('login.signIn')),
          ),
          TextButton(
            onPressed: _busy ? null : _forgotPassword,
            child: Text(context.t('forgot.link')),
          ),
        ],
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('forgot.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.t('forgot.body')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(labelText: ctx.t('login.email')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.t('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(ctx.t('forgot.send')),
          ),
        ],
      ),
    );
    if (email == null || !email.contains('@') || !mounted) return;
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email);
      if (mounted) showInfo(context, context.t('forgot.sent'));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget _errorBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
      ),
    );
  }
}
