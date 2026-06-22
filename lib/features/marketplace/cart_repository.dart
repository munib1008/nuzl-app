import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';

/// The caller's cart: { items: [...], subtotal, count }.
final cartProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/marketplace/cart');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{'items': [], 'subtotal': 0, 'count': 0};
  } catch (_) {
    return <String, dynamic>{'items': [], 'subtotal': 0, 'count': 0};
  }
});

/// Item count for the app-bar cart badge.
final cartCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final c = await ref.watch(cartProvider.future);
  return int.tryParse('${c['count'] ?? 0}') ?? 0;
});

/// One consolidated marketplace menu (app bar): Cart + My orders under a single
/// bucket, with a live cart-count badge on the icon.
class MarketplaceActions extends ConsumerWidget {
  const MarketplaceActions({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider).asData?.value ?? 0;
    return PopupMenuButton<String>(
      tooltip: 'Cart & orders',
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
      onSelected: (v) => context.push(v == 'cart' ? '/cart' : '/orders'),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'cart',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shopping_cart_outlined),
            title: Text(count > 0 ? 'Cart ($count)' : 'Cart'),
          ),
        ),
        const PopupMenuItem<String>(
          value: 'orders',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.receipt_long_outlined),
            title: Text('My orders'),
          ),
        ),
      ],
    );
  }
}

/// Add a product to the cart (with a "View cart" shortcut on success).
Future<void> addToCart(BuildContext context, WidgetRef ref, String itemId, {int quantity = 1}) async {
  try {
    await ref.read(apiClientProvider).post('/marketplace/cart', body: {'item_id': itemId, 'quantity': quantity});
    ref.invalidate(cartProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Added to cart'),
        action: SnackBarAction(label: 'View cart', onPressed: () => context.push('/cart')),
      ));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}
