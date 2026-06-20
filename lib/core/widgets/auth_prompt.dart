import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Product-led gate: shown when a logged-out visitor taps an action that needs
/// an account (save, contact, request a viewing, buy, message). The point is to
/// educate and convert — not to bounce the visitor to a cold login screen.
Future<void> showAuthPrompt(BuildContext context, {String? action}) {
  const benefits = [
    (Icons.bookmark_outline, 'Save properties'),
    (Icons.account_balance_outlined, 'Track mortgages'),
    (Icons.verified_user_outlined, 'Manage ownership'),
    (Icons.groups_outlined, 'Connect with tenants'),
    (Icons.storefront_outlined, 'Access the marketplace'),
  ];
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.rCard)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Create your free NUZL account to continue',
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              if (action != null && action.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Sign in to $action.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
              ],
              const SizedBox(height: AppSpacing.x16),
              for (final b in benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x8),
                  child: Row(children: [
                    Icon(b.$1, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.x12),
                    Text(b.$2, style: t.bodyMedium),
                  ]),
                ),
              const SizedBox(height: AppSpacing.x16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/register');
                  },
                  child: const Text('Create free account'),
                ),
              ),
              const SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.go('/login');
                  },
                  child: const Text('Sign in'),
                ),
              ),
            ]),
          ),
        ),
      );
    },
  );
}
