import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/user_avatar.dart';
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
      appBar: NuzlAppBar(title: context.tr('Customers')),
      drawer: const NuzlDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createDialog(context, ref),
        icon: const Icon(Icons.person_add_alt), label: Text(context.tr('Add customer'))),
      body: ResponsiveCenter(
        child: customers.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))),
          data: (list) => list.isEmpty
              ? const _Empty()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.x8),
                  itemBuilder: (_, i) {
                    final c = Map<String, dynamic>.from(list[i]);
                    return Card(child: ListTile(
                      leading: UserAvatar(name: '${c['full_name'] ?? '?'}', url: '${c['avatar'] ?? ''}'),
                      title: Text(c['full_name'] ?? context.tr('Customer')),
                      subtitle: Text([c['customer_type'], c['phone'], c['email']].where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
                      trailing: Text('${c['properties'] ?? 0} ${context.tr('props')}'),
                      onTap: c['id'] != null ? () => context.push('/customers/${c['id']}') : null,
                    ));
                  }),
        ),
      ),
    );
  }

  Future<void> _createDialog(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController(); final email = TextEditingController(); final phone = TextEditingController();
    String type = 'client';
    final ok = await AppDialog.show<bool>(context,
      title: context.tr('Add customer'),
      children: [
        TextField(controller: name, decoration: InputDecoration(labelText: context.tr('Full name'))),
        TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('Phone'))),
        TextField(controller: email, decoration: InputDecoration(labelText: context.tr('Email'))),
        const SizedBox(height: 8),
        StatefulBuilder(builder: (ctx, setS) => DropdownButtonFormField<String>(
          initialValue: type, decoration: InputDecoration(labelText: context.tr('Type')),
          items: [
            DropdownMenuItem(value: 'client', child: Text(context.tr('Client'))),
            DropdownMenuItem(value: 'investor', child: Text(context.tr('Investor'))),
            DropdownMenuItem(value: 'owner', child: Text(context.tr('Owner'))),
          ], onChanged: (v) => setS(() => type = v ?? 'client'))),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(context.tr('Save'))),
      ],
    );
    if (ok != true) return;
    try {
      final res = await ref.read(apiClientProvider).post('/customers', body: {
        'full_name': name.text.trim(), 'email': email.text.trim(), 'phone': phone.text.trim(), 'customer_type': type,
      });
      ref.invalidate(customersProvider);
      final id = res is Map ? '${res['id'] ?? ''}' : '';
      if (context.mounted) {
        // Consistent post-submit workflow: confirm + land on the new customer.
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Customer added successfully.'))));
        if (id.isNotEmpty) context.push('/customers/$id');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      Text(context.tr('No customers yet')),
      const SizedBox(height: 4),
      Text(context.tr('Add a customer or convert a lead.'), style: TextStyle(color: Theme.of(context).hintColor)),
    ]),
  ));
}
