import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    if (name.text.trim().isEmpty) return 'Enter the buyer / client name.';
    if (phone.text.trim().isEmpty) return 'Enter a contact phone number.';
    final mn = double.tryParse(minBudget.text.trim());
    final mx = double.tryParse(maxBudget.text.trim());
    if (mn != null && mx != null && mx < mn) return 'Max budget cannot be less than min budget.';
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) { setState(() => error = problem); return; }
    setState(() { saving = true; error = null; });
    try {
      await ref.read(apiClientProvider).post('/buyer-requirements', body: {
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
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead posted'))); context.go('/leads'); }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Post a lead'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Buyer / client name *')),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone *', hintText: '+971 …')),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: buyerType,
              decoration: const InputDecoration(labelText: 'Buyer type'),
              items: const [
                DropdownMenuItem(value: 'end_user', child: Text('End user')),
                DropdownMenuItem(value: 'investor', child: Text('Investor')),
              ],
              onChanged: (v) => setState(() => buyerType = v ?? 'end_user'),
            ),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Lead status', prefixIcon: Icon(Icons.flag_outlined)),
              items: const [
                DropdownMenuItem(value: 'general', child: Text('General')),
                DropdownMenuItem(value: 'potential', child: Text('Potential')),
                DropdownMenuItem(value: 'qualified', child: Text('Qualified')),
              ],
              onChanged: (v) => setState(() => category = v ?? 'general'),
            ),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String>(
              initialValue: purpose,
              decoration: const InputDecoration(labelText: 'Purpose'),
              items: const [
                DropdownMenuItem(value: 'sale', child: Text('Buy / Sale')),
                DropdownMenuItem(value: 'rent', child: Text('Rent')),
              ],
              onChanged: (v) => setState(() => purpose = v ?? 'sale'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: propertyType, decoration: const InputDecoration(labelText: 'Property type', hintText: 'Apartment, Villa, …')),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: TextField(controller: minBudget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min budget (AED)'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: maxBudget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max budget (AED)'))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<int>(
              initialValue: beds,
              decoration: const InputDecoration(labelText: 'Bedrooms'),
              items: const [
                DropdownMenuItem(value: null, child: Text('Any')),
                DropdownMenuItem(value: 0, child: Text('Studio')),
                DropdownMenuItem(value: 1, child: Text('1')),
                DropdownMenuItem(value: 2, child: Text('2')),
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 4, child: Text('4+')),
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
      bottomNavigationBar: StickySaveBar(saving: saving, label: 'Post lead', onPressed: _save),
    );
  }
}
