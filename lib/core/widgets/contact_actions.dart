import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_spacing.dart';

/// One-tap reach-out actions for a contact phone — Call, WhatsApp, Copy.
///
/// Adopted from the Lovable build's `mailto:`/`tel:` lead quick-actions, but
/// adapted for the GCC: leads here carry a phone (no email), and WhatsApp is
/// the primary channel for real-estate outreach, so it sits beside the dialer.
class ContactActions extends StatelessWidget {
  const ContactActions({super.key, required this.phone, this.compact = false});

  final String phone;

  /// Compact = two small icon buttons (for dense lists). Full = labelled
  /// outlined buttons (for a detail header).
  final bool compact;

  String get _digits => phone.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _open(BuildContext context, Uri uri) async {
    // Don't gate on canLaunchUrl — on Flutter web it gives false negatives for
    // tel:/wa.me. Just launch and surface a friendly message if it throws.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't open that app")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (phone.trim().isEmpty) return const SizedBox.shrink();

    if (compact) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Call',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.call_outlined, size: 20),
          onPressed: () => _open(context, Uri.parse('tel:$phone')),
        ),
        IconButton(
          tooltip: 'WhatsApp',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chat_outlined, size: 20),
          onPressed: () => _open(context, Uri.parse('https://wa.me/$_digits')),
        ),
      ]);
    }

    return Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
      OutlinedButton.icon(
        onPressed: () => _open(context, Uri.parse('tel:$phone')),
        icon: const Icon(Icons.call_outlined, size: 18),
        label: const Text('Call'),
      ),
      OutlinedButton.icon(
        onPressed: () => _open(context, Uri.parse('https://wa.me/$_digits')),
        icon: const Icon(Icons.chat_outlined, size: 18),
        label: const Text('WhatsApp'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: phone));
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text('Phone number copied')));
          }
        },
        icon: const Icon(Icons.copy_outlined, size: 18),
        label: const Text('Copy'),
      ),
    ]);
  }
}
