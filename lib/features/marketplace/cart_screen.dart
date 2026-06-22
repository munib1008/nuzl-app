import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';
import 'cart_repository.dart';

/// Future-ready payment methods (§2). Recorded on the order; live card capture
/// (Stripe) is wired separately — for now the order is placed with the choice.
const _paymentMethods = <(String, String)>[
  ('cod', 'Cash on delivery'),
  ('card', 'Credit / debit card'),
  ('apple_pay', 'Apple Pay'),
  ('google_pay', 'Google Pay'),
  ('bank_transfer', 'Bank transfer'),
  ('wallet', 'Marketplace wallet'),
];

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(cartProvider);
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    return Scaffold(
      appBar: NuzlAppBar(title: context.tr('Cart')),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(cartProvider),
          child: async.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
            error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
            data: (cart) {
              final items = (cart['items'] as List?) ?? const [];
              if (items.isEmpty) {
                return ListView(children: [
                  EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: context.tr('Your cart is empty'),
                    message: context.tr('Add products from the marketplace to check out in one go.'),
                    actionLabel: context.tr('Browse marketplace'),
                    onAction: () => context.go('/marketplace'),
                  ),
                ]);
              }
              final subtotal = num.tryParse('${cart['subtotal'] ?? 0}') ?? 0;
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  for (final raw in items) _CartTile(Map<String, dynamic>.from(raw as Map)),
                  const SizedBox(height: AppSpacing.x16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(context.tr('Subtotal'), style: Theme.of(context).textTheme.titleMedium),
                    Text(aed.format(subtotal),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: AppSpacing.x12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _checkout(context, ref),
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: Text(context.tr('Checkout')),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref) async {
    final delivery = TextEditingController();
    final billing = TextEditingController();
    final phone = TextEditingController();
    final notes = TextEditingController();
    var method = 'cod';
    final ok = await AppDialog.show<bool>(
      context,
      title: context.tr('Checkout'),
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: delivery, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Delivery address *'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: context.tr('Contact number *'))),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: billing, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Billing address (optional)'))),
            const SizedBox(height: AppSpacing.x8),
            DropdownButtonFormField<String>(
              initialValue: method,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('Payment method')),
              items: [for (final m in _paymentMethods) DropdownMenuItem(value: m.$1, child: Text(context.tr(m.$2)))],
              onChanged: (v) => setS(() => method = v ?? 'cod'),
            ),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: notes, maxLines: 2, decoration: InputDecoration(labelText: context.tr('Delivery notes (optional)'))),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.tr('Cancel'))),
        FilledButton(
          onPressed: () {
            if (delivery.text.trim().isEmpty || phone.text.trim().isEmpty) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(context.tr('Add a delivery address and contact number.'))));
              return;
            }
            Navigator.pop(context, true);
          },
          child: Text(context.tr('Place order')),
        ),
      ],
    );
    if (ok != true) return;
    try {
      final origin = Uri.base.origin;
      final ret = origin.isEmpty ? 'https://nuzl.app' : origin;
      final res = await ref.read(apiClientProvider).post('/marketplace/cart/checkout', body: {
        'delivery_address': delivery.text.trim(),
        'billing_address': billing.text.trim(),
        'contact_phone': phone.text.trim(),
        'payment_method': method,
        'delivery_notes': notes.text.trim(),
        'success_url': '$ret/#/orders',
        'cancel_url': '$ret/#/cart',
      });
      ref.invalidate(cartProvider);
      // Card payment (Stripe configured) → redirect to the hosted checkout.
      final url = (res is Map) ? res['url'] : null;
      if (url != null && '$url'.isNotEmpty) {
        await launchUrl(Uri.parse('$url'), webOnlyWindowName: '_self');
        return;
      }
      final count = (res is Map) ? (int.tryParse('${res['count'] ?? 0}') ?? 0) : 0;
      if (context.mounted) {
        final placed = '${context.tr('Order placed')} — $count ${context.tr(count == 1 ? 'item' : 'items')}. ${context.tr('Track it in Orders.')}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(placed),
          action: SnackBarAction(label: context.tr('View'), onPressed: () => context.go('/orders')),
        ));
        context.go('/orders');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _CartTile extends ConsumerWidget {
  const _CartTile(this.line);
  final Map<String, dynamic> line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final aed = NumberFormat.currency(symbol: 'AED ', decimalDigits: 0);
    final title = '${line['title'] ?? 'Product'}';
    final price = num.tryParse('${line['price'] ?? 0}') ?? 0;
    final qty = int.tryParse('${line['quantity'] ?? 1}') ?? 1;
    final image = '${line['image_url'] ?? ''}';
    final id = '${line['id'] ?? ''}';
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
            child: image.isNotEmpty
                ? Image.network(image, width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _thumb())
                : _thumb(),
          ),
          const SizedBox(width: AppSpacing.x12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(aed.format(price), style: t.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ]),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            onPressed: () => _setQty(ref, id, qty - 1),
          ),
          Text('$qty', style: t.titleSmall),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            onPressed: () => _setQty(ref, id, qty + 1),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.tr('Remove'),
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: () => _remove(ref, id),
          ),
        ]),
      ),
    );
  }

  Widget _thumb() => Container(
        width: 56, height: 56, color: AppColors.surface2,
        child: const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
      );

  Future<void> _setQty(WidgetRef ref, String id, int qty) async {
    try {
      await ref.read(apiClientProvider).patch('/marketplace/cart/$id', body: {'quantity': qty});
      ref.invalidate(cartProvider);
    } catch (_) {/* keep current view */}
  }

  Future<void> _remove(WidgetRef ref, String id) async {
    try {
      await ref.read(apiClientProvider).delete('/marketplace/cart/$id');
      ref.invalidate(cartProvider);
    } catch (_) {/* keep current view */}
  }
}
