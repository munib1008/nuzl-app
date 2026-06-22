import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import '../../../core/auth/google_sign_in_service.dart';
import '../../../core/widgets/nuzl_logo.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.referralCode});
  final String? referralCode;
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late final _referral = TextEditingController(text: widget.referralCode ?? '');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose(); _referral.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier).register(
          _email.text.trim(), _password.text, _name.text.trim(),
          referralCode: _referral.text.trim().isEmpty ? null : _referral.text.trim(),
        );
    if (ok && mounted) context.go('/onboarding');
  }

  Future<void> _google() async {
    final idToken = await GoogleSignInService().getIdToken();
    if (idToken == null) return;
    final ok = await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
    if (ok && mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: NuzlLogo(size: 48)),
                  const SizedBox(height: AppSpacing.x24),
                  Text(context.tr('Create account'), style: t.headlineMedium),
                  const SizedBox(height: AppSpacing.x24),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(hintText: context.tr('Full name')),
                    validator: (v) => (v == null || v.isEmpty) ? context.tr('Required') : null,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(hintText: context.tr('Email')),
                    validator: (v) => (v == null || !v.contains('@')) ? context.tr('Enter a valid email') : null,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(hintText: context.tr('Password (min 8)')),
                    validator: (v) => (v == null || v.length < 8) ? context.tr('Min 8 characters') : null,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextFormField(
                    controller: _referral,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: context.tr('Referral code (optional)'),
                      prefixIcon: const Icon(Icons.card_giftcard, size: 18),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: AppSpacing.x16),
                    Text(state.error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: AppSpacing.x24),
                  FilledButton(
                    onPressed: state.loading ? null : _submit,
                    child: state.loading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(context.tr('Create account')),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(context.tr('or'), style: t.bodySmall)),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: AppSpacing.x16),
                  OutlinedButton.icon(
                    onPressed: state.loading ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: Text(context.tr('Continue with Google')),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(context.tr('Already have an account? Sign in')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
