import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/user_avatar.dart';
import '../shell/app_shell.dart';

/// GET /customers/:id returns { customer, properties }.
final customerDetailProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final d = await ref.read(apiClientProvider).get('/customers/$id');
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
});

/// Full customer profile — post-submit lands here for a consistent create → detail
/// workflow, and shows the customer's linked properties.
class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(customerDetailProvider(id));
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Customer')),
      drawer: const NuzlDrawer(),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customerDetailProvider(id)),
        child: AsyncView<Map<String, dynamic>>(
          value: detail,
          onRetry: () => ref.invalidate(customerDetailProvider(id)),
          data: (d) => _body(context, d),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> d) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final c = Map<String, dynamic>.from(d['customer'] as Map? ?? const {});
    final props = (d['properties'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final name = '${c['full_name'] ?? context.tr('Customer')}';
    final type = '${c['customer_type'] ?? ''}'.trim();
    final phone = '${c['phone'] ?? ''}'.trim();
    final email = '${c['email'] ?? ''}'.trim();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x16),
      children: [
        Row(children: [
          UserAvatar(name: name, url: '${c['avatar'] ?? ''}', radius: 28),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: t.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (type.isNotEmpty)
                Text(type[0].toUpperCase() + type.substring(1), style: t.bodyMedium?.copyWith(color: muted)),
            ]),
          ),
        ]),
        const SizedBox(height: AppSpacing.x16),
        if (phone.isNotEmpty) _row(Icons.phone_outlined, phone, t, muted),
        if (email.isNotEmpty) _row(Icons.email_outlined, email, t, muted),
        const SizedBox(height: AppSpacing.x20),
        Text('${context.tr('Properties')} (${props.length})', style: t.labelLarge),
        const SizedBox(height: AppSpacing.x8),
        if (props.isEmpty)
          Text(context.tr('No properties linked yet.'), style: t.bodySmall?.copyWith(color: muted))
        else
          ...props.map((p) => Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.x8),
                child: ListTile(
                  leading: const Icon(Icons.home_work_outlined),
                  title: Text('${p['unit_no'] ?? p['property_type'] ?? context.tr('Property')}'),
                  subtitle: Text([p['relationship'], p['property_type'], p['inventory_status']]
                      .where((e) => e != null && '$e'.isNotEmpty)
                      .join(' · ')),
                  onTap: p['id'] != null ? () => context.push('/property-record/${p['id']}') : null,
                ),
              )),
      ],
    );
  }

  Widget _row(IconData icon, String text, TextTheme t, Color muted) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        child: Row(children: [
          Icon(icon, size: 18, color: muted),
          const SizedBox(width: AppSpacing.x8),
          Expanded(child: Text(text, style: t.bodyMedium)),
        ]),
      );
}
