import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final roles = <String>{};
  final company = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final bio = TextEditingController();
  final areas = <String>{};
  final languages = <String>{};
  final specialties = <String>{};

  static const _emirates = ['Dubai','Abu Dhabi','Sharjah','Ajman','Ras Al Khaimah','Fujairah','Umm Al Quwain','Al Ain'];
  static const _langs = ['English','Arabic','Hindi','Urdu','Tagalog','Malayalam','Tamil','French'];
  static const _specs = ['Villas','Apartments','Penthouses','Townhouses','Commercial','Off-Plan','Luxury','Investment'];

  @override
  void dispose() { company.dispose(); phone.dispose(); whatsapp.dispose(); bio.dispose(); super.dispose(); }

  void _save() {
    // Map the first selected role to the session persona so navigation adapts.
    if (roles.contains('Broker')) ref.read(personaOverrideProvider.notifier).state = Persona.broker;
    else if (roles.contains('Agent')) ref.read(personaOverrideProvider.notifier).state = Persona.agent;
    else if (roles.contains('Lead Generator')) ref.read(personaOverrideProvider.notifier).state = Persona.leadGenerator;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;

    Widget chips(String label, List<String> options, Set<String> selected, {bool wrapTrue = true}) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.titleSmall),
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
            final sel = selected.contains(o);
            return FilterChip(
              label: Text(o), selected: sel,
              onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
              selectedColor: AppColors.primaryTint, checkmarkColor: AppColors.primary,
            );
          }).toList()),
          const SizedBox(height: AppSpacing.x16),
        ]);

    return Scaffold(
      appBar: const NuzlAppBar(title: 'Profile & settings'),
      drawer: const NuzlDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
          // header
          Center(child: Column(children: [
            CircleAvatar(radius: 36, backgroundColor: AppColors.primary,
              child: Text((user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'N').toUpperCase(),
                  style: t.headlineMedium?.copyWith(color: Colors.white))),
            const SizedBox(height: AppSpacing.x12),
            Text(user?.fullName ?? 'Account', style: t.titleLarge),
            Text(user?.email ?? '', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.verified_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text('Unverified', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              ]),
            ),
          ])),
          const SizedBox(height: AppSpacing.x24),

          // performance stats
          Card(child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Performance', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x12),
              _stat('Deals closed', '0', t),
              _stat('Total earnings', 'AED 0', t),
              _stat('Total reviews', '0', t),
            ]),
          )),
          const SizedBox(height: AppSpacing.x16),

          // profile information
          Card(child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Profile information', style: t.titleMedium),
              Text('Update your profile to help others find and trust you',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.x16),
              chips('I am a… (select all that apply)', const ['Broker','Agent','Lead Generator'], roles),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name', hintText: 'Your company or brokerage')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+971 …')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '+971 …')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell others about yourself…')),
              const SizedBox(height: AppSpacing.x16),
              chips('Areas you cover', _emirates, areas),
              chips('Languages', _langs, languages),
              chips('Property specialties', _specs, specialties),
              Align(alignment: Alignment.centerRight,
                child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('Save changes'))),
            ]),
          )),
          const SizedBox(height: AppSpacing.x16),

          // tools + account
          Card(child: Column(children: [
            ListTile(leading: const Icon(Icons.account_balance_outlined), title: const Text('Mortgages'),
                onTap: () => context.go('/mortgages')),
            const Divider(height: 1),
            ListTile(leading: const Icon(Icons.calculate_outlined), title: const Text('Mortgage calculator'),
                onTap: () => context.go('/calculator')),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () async {
                await ref.read(authControllerProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ])),
          const SizedBox(height: AppSpacing.x24),
          Center(child: Opacity(opacity: 0.5, child: NuzlLogo(size: 24))),
          const SizedBox(height: AppSpacing.x24),
        ],
      ),
    );
  }

  Widget _stat(String k, String v, TextTheme t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: t.bodyMedium), Text(v, style: t.titleMedium),
    ]));
}
