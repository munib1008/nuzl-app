import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_view.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: AsyncView(
        value: profile,
        onRetry: () => ref.refresh(profileProvider),
        data: (user) => ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                (user.fullName.isNotEmpty ? user.fullName[0] : '?').toUpperCase(),
                style: t.headlineMedium?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
            Center(child: Text(user.fullName, style: t.titleLarge)),
            Center(child: Text(user.email, style: t.bodySmall)),
            if (user.role != null)
              Center(child: Text(user.role!, style: t.bodySmall)),
            const SizedBox(height: AppSpacing.x32),
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('Mortgages'),
              subtitle: const Text('Track payments and balances'),
              onTap: () => context.push('/mortgages'),
            ),
            ListTile(
              leading: const Icon(Icons.calculate_outlined),
              title: const Text('Mortgage calculator'),
              subtitle: const Text('Estimate a monthly payment'),
              onTap: () => context.push('/calculator'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Appearance'),
              subtitle: const Text('Light / Dark / System'),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
