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

/// App-bar cart icon with a live item-count badge → opens the cart.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartCountProvider).asData?.value ?? 0;
    return IconButton(
      tooltip: 'Cart',
      onPressed: () => context.push('/cart'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_cart_outlined),
      ),
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
