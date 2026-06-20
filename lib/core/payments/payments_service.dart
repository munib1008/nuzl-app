import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../network/api_client.dart';

/// True when Stripe is configured on the API (drives whether a "Pay" affordance
/// is shown — hidden until STRIPE_SECRET_KEY is set so there are no dead buttons).
final paymentsConfigProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/payments/config');
    return d is Map && d['configured'] == true;
  } catch (_) {
    return false;
  }
});

/// Creates a Stripe Checkout session and opens the Stripe-hosted card page.
/// On web it redirects in the same tab so the success URL returns to the app.
Future<void> startCheckout(
  BuildContext context,
  WidgetRef ref, {
  required String purpose,
  String? refId,
}) async {
  final origin = Uri.base.origin;
  final ret = origin.isEmpty ? 'https://nuzl.app' : origin;
  try {
    final res = await ref.read(apiClientProvider).post('/payments/checkout', body: {
      'purpose': purpose,
      'ref_id': refId,
      'success_url': '$ret/#/dashboard',
      'cancel_url': '$ret/#/dashboard',
    });
    final url = (res is Map) ? res['url'] : null;
    if (url == null) throw Exception('No checkout URL returned.');
    final ok = await launchUrl(Uri.parse('$url'), webOnlyWindowName: '_self');
    if (!ok) throw Exception('Could not open the payment page.');
  } catch (e) {
    if (!context.mounted) return;
    final s = '$e';
    final msg = (s.contains('not enabled') || s.contains('501'))
        ? 'Payments aren’t enabled yet — coming at launch.'
        : s;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}
