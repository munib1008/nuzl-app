import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/empty_state.dart';
import '../../shell/app_shell.dart';

/// Deals screen. Phase 1 API creates deals on offer-accept; a dedicated
/// GET /deals endpoint is a small backend addition (offers.service has the data).
/// Until then this shows guidance rather than failing.
class DealsScreen extends ConsumerWidget {
  const DealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Deals'),
      drawer: const NuzlDrawer(),
      body: const EmptyState(
        icon: Icons.handshake_outlined,
        title: 'No deals to show yet',
        message: 'Deals are created automatically when an offer is accepted. Accept an offer to see it here.',
      ),
    );
  }
}
