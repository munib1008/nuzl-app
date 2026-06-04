import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/multi_select_field.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/users/me');
  return (d is Map) ? Map<String, dynamic>.from(d) : {};
});

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loaded = false;
  bool _saving = false;
  String? _role; // agency | agent | owner | investor | buyer
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
  static const _roleOptions = [
    ('agency', 'Agency'),
    ('agent', 'Agent'),
    ('owner', 'Owner'),
    ('investor', 'Investor'),
    ('buyer', 'Customer'),
  ];

  /// Map any stored role string to one of the five selectable options.
  static String? _canonRole(dynamic raw) {
    final r = '${raw ?? ''}'.toLowerCase();
    if (r.isEmpty) return null;
    return switch (personaFromRole(r)) {
      Persona.broker => 'agency',
      Persona.agent || Persona.leadGenerator => 'agent',
      Persona.owner => 'owner',
      Persona.investor || Persona.developer => 'investor',
      Persona.buyer => 'buyer',
      Persona.admin => null,
    };
  }

  @override
  void dispose() { company.dispose(); phone.dispose(); whatsapp.dispose(); bio.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_role != null) {
      ref.read(personaOverrideProvider.notifier).set(personaFromRole(_role));
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/users/me', body: {
        if (_role != null) 'role': _role,
        'company': company.text.trim(),
        'phone': phone.text.trim(),
        'whatsapp': whatsapp.text.trim(),
        'bio': bio.text.trim(),
        'areas': areas.toList(),
        'languages': languages.toList(),
        'specialties': specialties.toList(),
      });
      ref.invalidate(_meProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _prefill(Map<String, dynamic> m) {
    if (_loaded) return;
    _loaded = true;
    _role = _canonRole(m['role']);
    company.text = (m['company'] ?? '').toString();
    phone.text = (m['phone'] ?? '').toString();
    whatsapp.text = (m['whatsapp'] ?? '').toString();
    bio.text = (m['bio'] ?? '').toString();
    void fill(Set<String> set, dynamic v) { if (v is List) set.addAll(v.map((e) => '$e')); }
    fill(areas, m['areas']); fill(languages, m['languages']); fill(specialties, m['specialties']);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;
    ref.watch(_meProvider).whenData(_prefill);

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

          // profile information
          Card(child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Profile information', style: t.titleMedium),
              Text('Update your profile to help others find and trust you',
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.x16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'I am a…', prefixIcon: Icon(Icons.badge_outlined)),
                items: _roleOptions.map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2))).toList(),
                onChanged: (v) => setState(() => _role = v),
              ),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name', hintText: 'Your company or brokerage')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+971 …')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '+971 …')),
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: bio, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell others about yourself…')),
              const SizedBox(height: AppSpacing.x16),
              MultiSelectField(label: 'Areas you cover', icon: Icons.map_outlined, options: _emirates, selected: areas,
                  onChanged: (v) => setState(() => areas..clear()..addAll(v))),
              MultiSelectField(label: 'Languages', icon: Icons.translate_outlined, options: _langs, selected: languages,
                  onChanged: (v) => setState(() => languages..clear()..addAll(v))),
              MultiSelectField(label: 'Property specialties', icon: Icons.star_outline, options: _specs, selected: specialties,
                  onChanged: (v) => setState(() => specialties..clear()..addAll(v))),
              Align(alignment: Alignment.centerRight,
                child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save changes'))),
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
              leading: const Icon(Icons.science_outlined),
              title: const Text('View as role'),
              subtitle: const Text('Preview any role (test mode)'),
              onTap: () => context.go('/view-as')),
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
          const Center(child: Opacity(opacity: 0.5, child: NuzlLogo(size: 24))),
          const SizedBox(height: AppSpacing.x24),
        ],
      ),
    );
  }
}
