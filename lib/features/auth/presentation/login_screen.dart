import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import '../../../core/auth/google_sign_in_service.dart';
import '../../../core/widgets/nuzl_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Where to land after sign-in — honor a safe internal `next=` (e.g. the
  /// landing hero search routes through login → /properties), else dashboard.
  String _dest() {
    final next = GoRouterState.of(context).uri.queryParameters['next'];
    if (next != null && next.startsWith('/') && !next.startsWith('//')) return next;
    return '/dashboard';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(authControllerProvider.notifier)
        .login(_email.text.trim(), _password.text);
    if (ok && mounted) context.go(_dest());
  }

  Future<void> _google() async {
    final idToken = await GoogleSignInService().getIdToken();
    if (idToken == null) return;
    final ok = await ref.read(authControllerProvider.notifier).loginWithGoogle(idToken);
    if (ok && mounted) context.go(_dest());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
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
                  const Center(child: NuzlLogo(size: 56)),
                  const SizedBox(height: AppSpacing.x16),
                  Center(child: Text('Sign in to your workspace', style: t.bodyLarge)),
                  const SizedBox(height: AppSpacing.x32),
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
                    decoration: const InputDecoration(hintText: 'Password'),
                    validator: (v) => (v == null || v.length < 8) ? 'Min 8 characters' : null,
                    onFieldSubmitted: (_) => _submit(),
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
                        : const Text('Sign in'),
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
                    onPressed: () => context.go('/forgot'),
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text("Don't have an account? Register"),
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
