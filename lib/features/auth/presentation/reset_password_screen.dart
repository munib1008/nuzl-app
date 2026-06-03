import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../data/auth_repository.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<ResetPasswordScreen> createState() => _S();
}

class _S extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_password.text.length < 8) { setState(() => _error = 'Use at least 8 characters'); return; }
    if (_password.text != _confirm.text) { setState(() => _error = 'Passwords do not match'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(authRepositoryProvider).resetPassword(widget.token, _password.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated — please sign in')));
        context.go('/login');
      }
    } catch (e) {
      setState(() => _error = '$e'.replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final invalid = widget.token.isEmpty;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Center(child: NuzlLogo(size: 48)),
              const SizedBox(height: AppSpacing.x24),
              Text('Set a new password', style: t.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.x24),
              if (invalid)
                Text('This reset link is missing its token. Please use the link from your email.',
                    style: t.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error), textAlign: TextAlign.center)
              else ...[
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'New password')),
                const SizedBox(height: AppSpacing.x12),
                TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm password'),
                    onSubmitted: (_) => _submit()),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.x12),
                  Text(_error!, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: AppSpacing.x16),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update password'),
                ),
              ],
              const SizedBox(height: AppSpacing.x8),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
            ]),
          ),
        ),
      ),
    );
  }
}
