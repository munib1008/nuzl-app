import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final customersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/customers');
    return d is List ? d : [];
  } catch (_) { return []; }
});

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Customers'),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.person_add_alt), label: const Text('Add customer')),
      body: ResponsiveCenter(
        child: customers.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('$e'))),
          data: (list) => list.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final c = Map<String, dynamic>.from(list[i]);
                    return Card(child: ListTile(
                      leading: CircleAvatar(child: Text((c['full_name'] ?? '?').toString().characters.first.toUpperCase())),
                      title: Text(c['full_name'] ?? 'Customer'),
                      subtitle: Text([c['customer_type'], c['phone'], c['email']].where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
                      trailing: Text('${c['properties'] ?? 0} props'),
                    ));
                  }),
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(); final email = TextEditingController(); final phone = TextEditingController();
    String type = 'client';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add customer'),
      content: StatefulBuilder(builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
        TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type'),
          items: const [
            DropdownMenuItem(value: 'client', child: Text('Client')),
            DropdownMenuItem(value: 'investor', child: Text('Investor')),
            DropdownMenuItem(value: 'owner', child: Text('Owner')),
          ], onChanged: (v) => setS(() => type = v ?? 'client')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ));
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/customers', body: {
        'full_name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'customer_type': type,
      });
      ref.invalidate(customersProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.contacts_outlined, size: 44, color: Theme.of(context).hintColor),
      const SizedBox(height: 12),
      const Text('No customers yet'),
      const SizedBox(height: 4),
      Text('Add a customer or convert a lead.', style: TextStyle(color: Theme.of(context).hintColor)),
    ]),
  ));
}
