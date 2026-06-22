import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/sticky_save_bar.dart';
import '../../shell/app_shell.dart';
import '../data/leads_repository.dart' show leadsProvider;

class PostLeadScreen extends ConsumerStatefulWidget {
  const PostLeadScreen({super.key});
  @override
  ConsumerState<PostLeadScreen> createState() => _PostLeadScreenState();
}

class _PostLeadScreenState extends ConsumerState<PostLeadScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final minBudget = TextEditingController();
  final maxBudget = TextEditingController();
  final propertyType = TextEditingController(text: 'Apartment');
  String buyerType = 'end_user';
  String purpose = 'sale';
  // Lead lifecycle classification. A lead is captured as General and is promoted
  // to Potential / Qualified as it is worked; it becomes a Customer automatically
  // once the person signs up on Nuzl (handled server-side on registration).
  String category = 'general';
  int? beds;
  bool saving = false;
  String? error;

  @override
  void dispose() { name.dispose(); phone.dispose(); minBudget.dispose(); maxBudget.dispose(); propertyType.dispose(); super.dispose(); }

  String? _validate() {
    if (name.text.trim().isEmpty) return context.tr('Enter the buyer / client name.');
    if (phone.text.trim().isEmpty) return context.tr('Enter a contact phone number.');
    final mn = double.tryParse(minBudget.text.trim());
    final mx = double.tryParse(maxBudget.text.trim());
    if (mn != null && mx != null && mx < mn) return context.tr('Max budget cannot be less than min budget.');
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) { setState(() => error = problem); return; }
    setState(() { saving = true; error = null; });
    try {
      final res = await ref.read(apiClientProvider).post('/buyer-requirements', body: {
        'buyer_name': name.text.trim(),
        'buyer_phone': phone.text.trim(),
        'buyer_type': buyerType,
        'purpose': purpose,
        'min_budget': double.tryParse(minBudget.text),
        'max_budget': double.tryParse(maxBudget.text),
        'bedrooms_min': beds,
        'bedrooms_max': beds,
        'property_type': propertyType.text.trim(),
        'lead_category': category,
      });
      ref.invalidate(leadsProvider);
      final id = res is Map ? '${res['id'] ?? ''}' : '';
      if (mounted) {
        // Consistent post-submit workflow: confirm + land on the new lead's detail.
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('Your lead has been created successfully.'))));
        context.go(id.isNotEmpty ? '/leads/$id' : '/leads');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Post a lead')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: context.tr('Buyer / client name *'))),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('Phone *'), hintText: '+971 …')),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: buyerType,
              decoration: InputDecoration(labelText: context.tr('Buyer type')),
              items: [
                DropdownMenuItem(value: 'end_user', child: Text(context.tr('End user'))),
                DropdownMenuItem(value: 'investor', child: Text(context.tr('Investor'))),
              ],
              onChanged: (v) => setState(() => buyerType = v ?? 'end_user'),
            ),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(labelText: context.tr('Lead status'), prefixIcon: const Icon(Icons.flag_outlined)),
              items: [
                DropdownMenuItem(value: 'general', child: Text(context.tr('General'))),
                DropdownMenuItem(value: 'potential', child: Text(context.tr('Potential'))),
                DropdownMenuItem(value: 'qualified', child: Text(context.tr('Qualified'))),
              ],
              onChanged: (v) => setState(() => category = v ?? 'general'),
            ),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: purpose,
              decoration: InputDecoration(labelText: context.tr('Purpose')),
              items: [
                DropdownMenuItem(value: 'sale', child: Text(context.tr('Buy / Sale'))),
                DropdownMenuItem(value: 'rent', child: Text(context.tr('Rent'))),
              ],
              onChanged: (v) => setState(() => purpose = v ?? 'sale'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: propertyType, decoration: InputDecoration(labelText: context.tr('Property type'), hintText: context.tr('Apartment, Villa, …'))),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: TextField(controller: minBudget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('Min budget (AED)')))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: maxBudget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: context.tr('Max budget (AED)')))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<int>(
              initialValue: beds,
              decoration: InputDecoration(labelText: context.tr('Bedrooms')),
              items: [
                DropdownMenuItem(value: null, child: Text(context.tr('Any'))),
                DropdownMenuItem(value: 0, child: Text(context.tr('Studio'))),
                const DropdownMenuItem(value: 1, child: Text('1')),
                const DropdownMenuItem(value: 2, child: Text('2')),
                const DropdownMenuItem(value: 3, child: Text('3')),
                const DropdownMenuItem(value: 4, child: Text('4+')),
              ],
              onChanged: (v) => setState(() => beds = v),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x12),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: AppSpacing.x16),
          ],
        ),
      ),
      bottomNavigationBar: StickySaveBar(saving: saving, label: context.tr('Post lead'), onPressed: _save),
    );
  }
}
