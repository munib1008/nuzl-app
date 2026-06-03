import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/multi_select_field.dart';
import '../../core/widgets/nuzl_logo.dart';

/// 2-step dropdown onboarding: role (+ conditional details) → contact & expertise.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;

  // Step 1 — role + conditional fields
  String? role; // agency | agent | owner | investor | buyer
  String agentType = 'freelancer'; // freelancer | agency_agent
  bool reraRegistered = false;
  final reraBrn = TextEditingController();
  final company = TextEditingController(); // agency / agency name
  final orn = TextEditingController(); // trade licence / ORN

  // Step 2 — contact + expertise
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final areas = <String>{};
  final languages = <String>{};
  final specialties = <String>{};

  static const _roleOptions = [
    ('agency', 'Agency'),
    ('agent', 'Agent'),
    ('owner', 'Owner'),
    ('investor', 'Investor'),
    ('buyer', 'Buyer'),
  ];
  static const _emirates = ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain', 'Al Ain'];
  static const _langs = ['English', 'Arabic', 'Hindi', 'Urdu', 'Tagalog', 'Malayalam', 'Tamil', 'French', 'Russian', 'Chinese'];
  static const _specs = ['Villas', 'Apartments', 'Penthouses', 'Townhouses', 'Commercial', 'Off-Plan', 'Luxury', 'Investment', 'Short Term Rentals', 'Holiday Homes'];

  @override
  void dispose() {
    reraBrn.dispose();
    company.dispose();
    orn.dispose();
    phone.dispose();
    whatsapp.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (role != null) {
      ref.read(personaOverrideProvider.notifier).state = personaFromRole(role);
    }
    final body = <String, dynamic>{
      'role': role,
      'phone': phone.text.trim(),
      'whatsapp': whatsapp.text.trim(),
      'areas': areas.toList(),
      'languages': languages.toList(),
      'specialties': specialties.toList(),
    };
    if (role == 'agency') {
      body['company'] = company.text.trim();
      if (orn.text.trim().isNotEmpty) body['rera_brn'] = orn.text.trim();
    } else if (role == 'agent') {
      if (agentType == 'agency_agent') body['company'] = company.text.trim();
      if (reraRegistered && reraBrn.text.trim().isNotEmpty) body['rera_brn'] = reraBrn.text.trim();
    }
    try {
      await ref.read(apiClientProvider).patch('/users/me', body: body);
    } catch (_) {/* non-blocking: continue to dashboard */}
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x24),
              children: [
                const SizedBox(height: AppSpacing.x16),
                const Center(child: NuzlLogo(size: 44, showWordmark: false)),
                const SizedBox(height: AppSpacing.x12),
                Center(child: Text('Welcome to nuzl', style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700))),
                Center(
                    child: Text("Let's set up your profile to get started",
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                const SizedBox(height: AppSpacing.x20),
                _Stepper(step: step),
                const SizedBox(height: AppSpacing.x24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    child: step == 0 ? _roleStep(t) : _contactStep(t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleStep(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What best describes you?', style: t.titleLarge),
        Text('Choose your role in the UAE real estate market',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.x16),
        DropdownButtonFormField<String>(
          initialValue: role,
          decoration: const InputDecoration(labelText: 'I am a…', prefixIcon: Icon(Icons.badge_outlined)),
          items: _roleOptions
              .map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2)))
              .toList(),
          onChanged: (v) => setState(() => role = v),
        ),
        if (role == 'agent') ...[
          const SizedBox(height: AppSpacing.x12),
          DropdownButtonFormField<String>(
            initialValue: agentType,
            decoration: const InputDecoration(labelText: 'Agent type'),
            items: const [
              DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
              DropdownMenuItem(value: 'agency_agent', child: Text('Agency Agent')),
            ],
            onChanged: (v) => setState(() => agentType = v ?? 'freelancer'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('RERA registered?'),
            value: reraRegistered,
            activeThumbColor: AppColors.primary,
            onChanged: (v) => setState(() => reraRegistered = v),
          ),
          if (reraRegistered)
            TextField(controller: reraBrn, decoration: const InputDecoration(labelText: 'RERA BRN')),
          if (agentType == 'agency_agent') ...[
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: company, decoration: const InputDecoration(labelText: 'Agency name')),
          ],
        ],
        if (role == 'agency') ...[
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name')),
          const SizedBox(height: AppSpacing.x12),
          TextField(controller: orn, decoration: const InputDecoration(labelText: 'Trade licence / ORN')),
        ],
        const SizedBox(height: AppSpacing.x20),
        _nav(onNext: role == null ? null : () => setState(() => step = 1)),
      ],
    );
  }

  Widget _contactStep(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact & expertise', style: t.titleLarge),
        Text('Help others find and connect with you',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.x16),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number *', hintText: '+971 …')),
        const SizedBox(height: AppSpacing.x12),
        TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '+971 …')),
        const SizedBox(height: AppSpacing.x8),
        MultiSelectField(
          label: 'Areas you cover *',
          icon: Icons.map_outlined,
          options: _emirates,
          selected: areas,
          onChanged: (v) => setState(() => areas
            ..clear()
            ..addAll(v)),
        ),
        MultiSelectField(
          label: 'Languages you speak',
          icon: Icons.translate_outlined,
          options: _langs,
          selected: languages,
          onChanged: (v) => setState(() => languages
            ..clear()
            ..addAll(v)),
        ),
        MultiSelectField(
          label: 'Property specialties',
          icon: Icons.star_outline,
          options: _specs,
          selected: specialties,
          onChanged: (v) => setState(() => specialties
            ..clear()
            ..addAll(v)),
        ),
        const SizedBox(height: AppSpacing.x12),
        _nav(
          onBack: () => setState(() => step = 0),
          nextLabel: 'Complete setup',
          onNext: (areas.isEmpty || phone.text.trim().isEmpty) ? null : _finish,
        ),
      ],
    );
  }

  Widget _nav({VoidCallback? onBack, VoidCallback? onNext, String nextLabel = 'Continue'}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        onBack != null ? OutlinedButton(onPressed: onBack, child: const Text('Back')) : const SizedBox.shrink(),
        FilledButton(onPressed: onNext, child: Text(nextLabel)),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (i) {
        final done = i <= step;
        return Row(children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: done ? AppColors.primary : Theme.of(context).dividerColor,
            child: done
                ? (i < step
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)))
                : Text('${i + 1}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
          ),
          if (i < 1)
            Container(width: 40, height: 2, color: i < step ? AppColors.primary : Theme.of(context).dividerColor),
        ]);
      }),
    );
  }
}
