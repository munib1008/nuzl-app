import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/network/api_client.dart';
import '../../core/rbac/persona.dart';
import '../auth/application/auth_controller.dart';
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

  // Company step (org roles) — join an existing company or create a new one.
  String _companyChoice = ''; // '' | join | create
  final _companySearch = TextEditingController();
  List<Map<String, dynamic>> _companyResults = [];
  bool _searching = false;
  String? _joinedOrgName;
  bool _companyCreated = false;
  String _bizType = 'agency';
  final _coCity = TextEditingController();
  final _coCountry = TextEditingController(text: 'United Arab Emirates');
  final _coPhone = TextEditingController();
  final _coEmail = TextEditingController();
  final _coWebsite = TextEditingController();
  final _coDesc = TextEditingController();

  // Step 3 — contact + expertise
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final areas = <String>{};
  final languages = <String>{};
  final specialties = <String>{};

  // One PRIMARY role (UAT #3). The last three are company-based: picking one
  // takes you straight to "Create company" with the matching business type, and
  // the company sets up the role + workspace for you.
  static const _roleOptions = [
    ('owner', 'Owner'),
    ('tenant', 'Tenant'),
    ('agent', 'Agent'),
    ('salesperson', 'Salesperson'),
    ('lead', 'Customer'),
    ('developer', 'Developer'),
    ('agency', 'Real estate agency'),
    ('provider', 'Service provider'),
    ('supplier', 'Supplier'),
  ];

  /// Company-based roles → the business type their "Create company" step starts on.
  static const _companyRoleBiz = {
    'agency': 'agency',
    'provider': 'maintenance',
    'supplier': 'supplier',
  };

  /// Icon + one-line description per goal (role value), for the goal cards.
  static const _goalMeta = <String, (IconData, String)>{
    'owner': (Icons.home_work_outlined, 'Track ownership, leases & maintenance'),
    'tenant': (Icons.vpn_key_outlined, 'My tenancy, rent & maintenance'),
    'agent': (Icons.handshake_outlined, 'List & sell, CRM, leads & deals'),
    'salesperson': (Icons.badge_outlined, 'Pipeline, leads & quotations'),
    'lead': (Icons.search, 'Buy, rent or just browse'),
    'developer': (Icons.domain_outlined, 'Projects, inventory & handover'),
    'agency': (Icons.business_outlined, 'Run a brokerage company'),
    'provider': (Icons.build_outlined, 'Maintenance, cleaning, fit-out'),
    'supplier': (Icons.inventory_2_outlined, 'Furniture, materials, hardware'),
  };
  static const _emirates = ['Dubai', 'Abu Dhabi', 'Sharjah', 'Ajman', 'Ras Al Khaimah', 'Fujairah', 'Umm Al Quwain', 'Al Ain'];
  static const _langs = ['English', 'Arabic', 'Hindi', 'Urdu', 'Tagalog', 'Malayalam', 'Tamil', 'French', 'Russian', 'Chinese'];
  static const _specs = ['Villas', 'Apartments', 'Penthouses', 'Townhouses', 'Commercial', 'Off-Plan', 'Luxury', 'Investment', 'Short Term Rentals', 'Holiday Homes'];

  @override
  void dispose() {
    reraBrn.dispose();
    company.dispose();
    orn.dispose();
    _companySearch.dispose();
    _coCity.dispose();
    _coCountry.dispose();
    _coPhone.dispose();
    _coEmail.dispose();
    _coWebsite.dispose();
    _coDesc.dispose();
    phone.dispose();
    whatsapp.dispose();
    super.dispose();
  }

  /// Agent / Salesperson / Developer can name the organization they work with.
  bool get _isOrg => const ['salesperson', 'developer'].contains(role);

  /// Company-based roles created via the company step (agency / service / supplier).
  bool get _isCompanyRole => _companyRoleBiz.containsKey(role);

  /// Org-affiliated roles get the company-association step (join or create).
  bool get _needsCompany => _isOrg || _isCompanyRole;

  /// The visible steps — the company step only appears for org-affiliated roles.
  List<Widget Function(TextTheme)> get _stepBuilders =>
      [_roleStep, if (_needsCompany) _companyStep, _contactStep];

  /// Professionals get the "areas / specialties" fields; consumers
  /// (owner/tenant/customer) complete without them.
  bool get _isPro => const ['agent', 'salesperson', 'developer'].contains(role);

  Future<void> _finish() async {
    if (role != null) {
      ref.read(personaOverrideProvider.notifier).set(personaFromRole(role));
    }
    final body = <String, dynamic>{
      'role': role,
      'phone': phone.text.trim(),
      'whatsapp': whatsapp.text.trim(),
      'areas': areas.toList(),
      'languages': languages.toList(),
      'specialties': specialties.toList(),
    };
    if (_isOrg) {
      body['company'] = company.text.trim();
      if (orn.text.trim().isNotEmpty) body['rera_brn'] = orn.text.trim();
    } else if (role == 'agent') {
      if (agentType == 'agency_agent') body['company'] = company.text.trim();
      if (reraRegistered && reraBrn.text.trim().isNotEmpty) body['rera_brn'] = reraBrn.text.trim();
    }
    try {
      await ref.read(apiClientProvider).patch('/users/me', body: body);
      // Persist the primary role server-side (UAT #3) so it survives devices.
      // Company-based roles are granted by creating the company (don't double-set).
      if (role != null && !_isCompanyRole) {
        await ref.read(authControllerProvider.notifier).setPrimaryRole(role!);
      }
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
                Center(child: Text('Welcome to nuzl', style: GoogleFonts.manrope(fontSize: 22, fontWeight: FontWeight.w700))),
                Center(
                    child: Text("Let's set up your profile to get started",
                        style: t.bodyMedium?.copyWith(color: AppColors.textMuted))),
                const SizedBox(height: AppSpacing.x20),
                _Stepper(step: step, count: _stepBuilders.length),
                const SizedBox(height: AppSpacing.x24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.x20),
                    child: _stepBuilders[step.clamp(0, _stepBuilders.length - 1)](t),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A tappable goal card (icon + label + description). Selecting it sets the
  /// role and, for company-based goals, pre-arms the company step.
  Widget _goalCard(TextTheme t, String value, String label) {
    final selected = role == value;
    final meta = _goalMeta[value];
    final accent = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: 158,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rLg),
        onTap: () => setState(() {
          role = value;
          final biz = _companyRoleBiz[value];
          if (biz != null) {
            _companyChoice = 'create';
            _bizType = biz;
          }
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.x12),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.10) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppSpacing.rLg),
            border: Border.all(
                color: selected ? accent : Theme.of(context).dividerColor, width: selected ? 1.5 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Icon(meta?.$1 ?? Icons.badge_outlined, size: 22, color: selected ? accent : AppColors.textMuted),
            const SizedBox(height: AppSpacing.x8),
            Text(label,
                style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: selected ? accent : null)),
            const SizedBox(height: 2),
            Text(meta?.$2 ?? '',
                style: t.bodySmall?.copyWith(color: AppColors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Widget _roleStep(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What brings you to NUZL?', style: t.titleLarge),
        Text('Pick your main goal — you stay a Customer and can add more roles later.',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.x16),
        Wrap(
          spacing: AppSpacing.x12,
          runSpacing: AppSpacing.x12,
          children: [for (final r in _roleOptions) _goalCard(t, r.$1, r.$2)],
        ),
        if (_isCompanyRole) ...[
          const SizedBox(height: AppSpacing.x12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.x12),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(AppSpacing.rMd),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.x8),
              Expanded(
                child: Text("Next, set up your company — that's all it takes to start as a ${_roleOptions.firstWhere((r) => r.$1 == role).$2.toLowerCase()}.",
                    style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
              ),
            ]),
          ),
        ],
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
        const SizedBox(height: AppSpacing.x20),
        _nav(onNext: role == null ? null : () => setState(() => step = 1)),
      ],
    );
  }

  // ── Company association step (join an existing company or create a new one) ──
  Widget _companyStep(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your company', style: t.titleLarge),
      Text('Do you belong to a company?', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x12),
      Row(children: [
        Expanded(child: _choiceTile('join', Icons.search, 'Join existing')),
        const SizedBox(width: AppSpacing.x8),
        Expanded(child: _choiceTile('create', Icons.add_business_outlined, 'Create new')),
      ]),
      if (_companyChoice == 'join') ...[const SizedBox(height: AppSpacing.x16), _joinUi(t)],
      if (_companyChoice == 'create') ...[const SizedBox(height: AppSpacing.x16), _createUi(t)],
      const SizedBox(height: AppSpacing.x20),
      _nav(
        onBack: () => setState(() => step = 0),
        nextLabel: _companyChoice == '' ? 'Skip for now' : 'Continue',
        onNext: _companyNext,
      ),
    ]);
  }

  Widget _choiceTile(String value, IconData icon, String label) {
    final selected = _companyChoice == value;
    return InkWell(
      borderRadius: BorderRadius.circular(AppSpacing.rMd),
      onTap: () => setState(() => _companyChoice = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
          border: Border.all(color: selected ? AppColors.primary : Theme.of(context).dividerColor, width: selected ? 1.5 : 1),
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? AppColors.primary : AppColors.textMuted),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.primary : null)),
        ]),
      ),
    );
  }

  Widget _joinUi(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: TextField(
            controller: _companySearch,
            decoration: const InputDecoration(labelText: 'Company name or trade license'),
            onSubmitted: (_) => _searchCompanies(),
          ),
        ),
        const SizedBox(width: AppSpacing.x8),
        FilledButton(
          onPressed: _searching ? null : _searchCompanies,
          child: _searching
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Search'),
        ),
      ]),
      if (_joinedOrgName != null)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x8),
          child: Text('Request sent to $_joinedOrgName — pending the owner’s approval. You can continue.',
              style: const TextStyle(color: AppColors.success)),
        ),
      for (final o in _companyResults)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${o['name']}'),
          subtitle: Text([
            if ('${o['org_type'] ?? ''}'.isNotEmpty) _cap('${o['org_type']}'),
            if (o['verification_status'] == 'verified') 'Verified',
          ].join(' · ')),
          trailing: TextButton(onPressed: () => _requestJoin(o), child: const Text('Request')),
        ),
    ]);
  }

  Widget _createUi(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: company, decoration: const InputDecoration(labelText: 'Company name *')),
      const SizedBox(height: AppSpacing.x8),
      DropdownButtonFormField<String>(
        initialValue: _bizType,
        decoration: const InputDecoration(labelText: 'Business type *'),
        items: const [
          DropdownMenuItem(value: 'agency', child: Text('Real estate agency')),
          DropdownMenuItem(value: 'developer', child: Text('Developer')),
          DropdownMenuItem(value: 'maintenance', child: Text('Service provider')),
          DropdownMenuItem(value: 'supplier', child: Text('Product supplier')),
        ],
        onChanged: (v) => setState(() => _bizType = v ?? 'agency'),
      ),
      const SizedBox(height: AppSpacing.x8),
      TextField(controller: orn, decoration: const InputDecoration(labelText: 'Trade license')),
      const SizedBox(height: AppSpacing.x8),
      Row(children: [
        Expanded(child: TextField(controller: _coCity, decoration: const InputDecoration(labelText: 'City'))),
        const SizedBox(width: AppSpacing.x8),
        Expanded(child: TextField(controller: _coCountry, decoration: const InputDecoration(labelText: 'Country'))),
      ]),
      const SizedBox(height: AppSpacing.x8),
      Row(children: [
        Expanded(child: TextField(controller: _coPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact phone'))),
        const SizedBox(width: AppSpacing.x8),
        Expanded(child: TextField(controller: _coEmail, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Contact email'))),
      ]),
      const SizedBox(height: AppSpacing.x8),
      TextField(controller: _coWebsite, decoration: const InputDecoration(labelText: 'Website')),
      const SizedBox(height: AppSpacing.x8),
      TextField(controller: _coDesc, maxLines: 2, decoration: const InputDecoration(labelText: 'Company description')),
      const SizedBox(height: AppSpacing.x12),
      if (_companyCreated)
        const Text('Company created ✓ Submit it for verification later to publish publicly.',
            style: TextStyle(color: AppColors.success))
      else
        FilledButton.icon(
          onPressed: _createCompany,
          icon: const Icon(Icons.add_business_outlined, size: 18),
          label: const Text('Create company'),
        ),
    ]);
  }

  Future<void> _searchCompanies() async {
    final q = _companySearch.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    try {
      final d = await ref.read(apiClientProvider).get('/organizations/search', query: {'q': q});
      if (mounted) {
        setState(() => _companyResults =
            d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : []);
      }
    } catch (_) {
      /* non-blocking */
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _requestJoin(Map<String, dynamic> o) async {
    try {
      await ref.read(apiClientProvider).post('/organizations/${o['id']}/join-request', body: {});
      if (mounted) setState(() => _joinedOrgName = '${o['name']}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _createCompany() async {
    if (company.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company name is required.')));
      return;
    }
    try {
      await ref.read(apiClientProvider).post('/organizations/mine', body: {
        'name': company.text.trim(),
        'org_type': _bizType,
        'trade_license': orn.text.trim().isEmpty ? null : orn.text.trim(),
        'phone': _coPhone.text.trim().isEmpty ? null : _coPhone.text.trim(),
        'email': _coEmail.text.trim().isEmpty ? null : _coEmail.text.trim(),
        'website': _coWebsite.text.trim().isEmpty ? null : _coWebsite.text.trim(),
        'city': _coCity.text.trim().isEmpty ? null : _coCity.text.trim(),
        'country': _coCountry.text.trim().isEmpty ? null : _coCountry.text.trim(),
        'about': _coDesc.text.trim().isEmpty ? null : _coDesc.text.trim(),
      });
      // Creating a company grants the matching role server-side — refresh the
      // session so the new role + workspace is active immediately.
      await ref.read(authControllerProvider.notifier).bootstrap();
      if (mounted) setState(() => _companyCreated = true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  /// Auto-create the company on Continue if the user filled the form but didn't
  /// press Create, then advance to the contact step.
  Future<void> _companyNext() async {
    if (_companyChoice == 'create' && !_companyCreated && company.text.trim().isNotEmpty) {
      await _createCompany();
    }
    if (mounted) setState(() => step = _stepBuilders.length - 1);
  }

  Widget _contactStep(TextTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contact & expertise', style: t.titleLarge),
        Text('Help others find and connect with you',
            style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.x16),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+971 …')),
        const SizedBox(height: AppSpacing.x12),
        TextField(controller: whatsapp, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '+971 …')),
        const SizedBox(height: AppSpacing.x8),
        MultiSelectField(
          label: 'Languages you speak',
          icon: Icons.translate_outlined,
          options: _langs,
          selected: languages,
          onChanged: (v) => setState(() => languages
            ..clear()
            ..addAll(v)),
        ),
        if (_isPro) ...[
          MultiSelectField(
            label: 'Areas you cover',
            icon: Icons.map_outlined,
            options: _emirates,
            selected: areas,
            onChanged: (v) => setState(() => areas
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
        ],
        const SizedBox(height: AppSpacing.x12),
        _nav(
          onBack: () => setState(() => step -= 1),
          nextLabel: 'Complete setup',
          onNext: _finish,
        ),
      ],
    );
  }

  String _cap(String s) {
    final x = s.replaceAll('_', ' ').trim();
    return x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}';
  }

  Widget _nav({VoidCallback? onBack, VoidCallback? onNext, String nextLabel = 'Continue'}) {
    final next = FilledButton(
      onPressed: onNext,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      child: Text(nextLabel),
    );
    // Full-width primary action so "Continue" / "Complete setup" is unmissable.
    if (onBack == null) return SizedBox(width: double.infinity, child: next);
    return Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onBack,
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          child: const Text('Back'),
        ),
      ),
      const SizedBox(width: AppSpacing.x12),
      Expanded(child: next),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.step, this.count = 2});
  final int step;
  final int count;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
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
          if (i < count - 1)
            Container(width: 40, height: 2, color: i < step ? AppColors.primary : Theme.of(context).dividerColor),
        ]);
      }),
    );
  }
}
