import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../data/auth_repository.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _S();
}

class _S extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _sending = false;
  bool _sent = false;

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _sent = true); // never reveal whether the email exists
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: NuzlLogo(size: 48)),
              const SizedBox(height: AppSpacing.x24),
              if (_sent) ...[
                Icon(Icons.mark_email_read_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: AppSpacing.x12),
                Text('Check your email', style: t.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.x8),
                Text('If an account exists for that address, we sent a link to reset your password. It expires in 1 hour.',
                    style: t.bodyMedium?.copyWith(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.x24),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
              ] else ...[
                Text('Reset your password', style: t.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.x8),
                Text('Enter your email and we’ll send you a reset link.',
                    style: t.bodyMedium?.copyWith(color: Theme.of(context).hintColor), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.x24),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSpacing.x16),
                FilledButton(
                  onPressed: _sending ? null : _submit,
                  child: _sending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Send reset link'),
                ),
                const SizedBox(height: AppSpacing.x8),
                TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
