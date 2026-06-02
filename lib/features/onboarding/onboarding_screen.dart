import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/nuzl_logo.dart';

/// 3-step onboarding: role → business details → contact & expertise.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int step = 0;
  Persona? role;
  final businessName = TextEditingController();
  final bio = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final areas = <String>{};
  final languages = <String>{};
  final specialties = <String>{};

  static const _emirates = ['Dubai','Abu Dhabi','Sharjah','Ajman','Ras Al Khaimah','Fujairah','Umm Al Quwain','Al Ain'];
  static const _langs = ['English','Arabic','Hindi','Urdu','Tagalog','Malayalam','Tamil','French','Russian','Chinese'];
  static const _specs = ['Villas','Apartments','Penthouses','Townhouses','Commercial','Off-Plan','Luxury','Investment','Short Term Rentals','Holiday Homes'];

  @override
  void dispose() {
    businessName.dispose(); bio.dispose(); phone.dispose(); whatsapp.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (role != null) {
      ref.read(personaOverrideProvider.notifier).state = role;
    }
    try {
      await ref.read(apiClientProvider).patch('/users/me', body: {
        'company': businessName.text.trim(),
        'bio': bio.text.trim(),
        'phone': phone.text.trim(),
        'whatsapp': whatsapp.text.trim(),
        'areas': areas.toList(),
        'languages': languages.toList(),
        'specialties': specialties.toList(),
      });
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
                Center(child: NuzlLogo(size: 44, showWordmark: false)),
                const SizedBox(height: AppSpacing.x12),
                Center(child: Text('Welcome to nuzl',
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700))),
                Center(child: Text("Let's set up your profile to get started",
                    style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                const SizedBox(height: AppSpacing.x20),
                _Stepper(step: step),
                const SizedBox(height: AppSpacing.x24),
                Card(child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x20),
                  child: switch (step) {
                    0 => _roleStep(t),
                    1 => _businessStep(t),
                    _ => _contactStep(t),
                  },
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleStep(TextTheme t) {
    Widget tile(Persona p, IconData icon, String title, String badge, String desc) {
      final sel = role == p;
      return InkWell(
        onTap: () => setState(() => role = p),
        borderRadius: BorderRadius.circular(AppSpacing.rMd),
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.x12),
          padding: const EdgeInsets.all(AppSpacing.x16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
            border: Border.all(color: sel ? AppColors.primary : Theme.of(context).dividerColor, width: sel ? 2 : 1),
            color: sel ? AppColors.primaryTint : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: Text(title, style: t.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.accentGoldTint, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Text(badge, style: t.bodySmall?.copyWith(color: AppColors.secondary)),
              ),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Text(desc, style: t.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.4)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('What best describes you?', style: t.titleLarge),
      Text('Choose your role in the UAE real estate market', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x16),
      tile(Persona.broker, Icons.business_outlined, 'Broker', 'RERA required',
          'I run a real estate agency or brokerage with a RERA license and manage agents.'),
      tile(Persona.agent, Icons.person_outline, 'Agent', 'RERA optional',
          'I work as a real estate agent representing buyers and sellers.'),
      tile(Persona.leadGenerator, Icons.people_outline, 'Lead Generator', 'No RERA',
          'I connect buyers and sellers with agents and earn commissions on verified leads.'),
      const SizedBox(height: AppSpacing.x8),
      _nav(onNext: role == null ? null : () => setState(() => step = 1)),
    ]);
  }

  Widget _businessStep(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your business details', style: t.titleLarge),
      Text('Tell us about your business', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x16),
      TextField(controller: businessName, decoration: const InputDecoration(labelText: 'Business name', hintText: 'e.g. Dubai Property Leads')),
      const SizedBox(height: AppSpacing.x12),
      TextField(controller: bio, maxLines: 4, decoration: const InputDecoration(labelText: 'Brief bio', hintText: 'Tell potential partners about yourself…')),
      const SizedBox(height: AppSpacing.x16),
      _nav(onBack: () => setState(() => step = 0), onNext: () => setState(() => step = 2)),
    ]);
  }

  Widget _contactStep(TextTheme t) {
    Widget chips(String label, List<String> options, Set<String> selected) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: t.titleSmall),
        const SizedBox(height: AppSpacing.x8),
        Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
          final sel = selected.contains(o);
          return FilterChip(
            label: Text(o), selected: sel,
            onSelected: (v) => setState(() => v ? selected.add(o) : selected.remove(o)),
            selectedColor: AppColors.primaryTint,
            checkmarkColor: AppColors.primary,
          );
        }).toList()),
        const SizedBox(height: AppSpacing.x16),
      ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Contact & expertise', style: t.titleLarge),
      Text('Help others find and connect with you', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x16),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number *', hintText: '+971 …')),
      const SizedBox(height: AppSpacing.x12),
      TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '+971 …')),
      const SizedBox(height: AppSpacing.x16),
      chips('Areas you cover in UAE *', _emirates, areas),
      chips('Languages you speak', _langs, languages),
      chips('Property specialties', _specs, specialties),
      _nav(onBack: () => setState(() => step = 1), nextLabel: 'Complete setup',
          onNext: (areas.isEmpty || phone.text.trim().isEmpty) ? null : _finish),
    ]);
  }

  Widget _nav({VoidCallback? onBack, VoidCallback? onNext, String nextLabel = 'Continue'}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      onBack != null
          ? OutlinedButton(onPressed: onBack, child: const Text('Back'))
          : const SizedBox.shrink(),
      FilledButton(onPressed: onNext, child: Text(nextLabel)),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) {
      final done = i <= step;
      return Row(children: [
        CircleAvatar(radius: 14, backgroundColor: done ? AppColors.primary : Theme.of(context).dividerColor,
          child: done
              ? (i < step ? const Icon(Icons.check, size: 16, color: Colors.white)
                          : Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)))
              : Text('${i + 1}', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12))),
        if (i < 2) Container(width: 40, height: 2, color: i < step ? AppColors.primary : Theme.of(context).dividerColor),
      ]);
    }));
  }
}
