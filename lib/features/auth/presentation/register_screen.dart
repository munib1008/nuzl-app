import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import '../../../core/auth/google_sign_in_service.dart';
import '../../../core/widgets/nuzl_logo.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier)
        .register(_email.text.trim(), _password.text, _name.text.trim());
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
                  Text('Create account', style: t.headlineMedium),
                  const SizedBox(height: AppSpacing.x24),
                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(hintText: 'Full name'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: 'Email'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(hintText: 'Password (min 8)'),
                    validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
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
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('or', style: t.bodySmall)),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: AppSpacing.x16),
                  OutlinedButton.icon(
                    onPressed: state.loading ? null : _google,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: AppSpacing.x16),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Already have an account? Sign in'),
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
