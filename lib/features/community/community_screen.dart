import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shell/app_shell.dart';
import '../deal_board/deal_board_screen.dart';
import '../feed/presentation/feed_screen.dart';

/// Agents' professional Community — the Deal Board and the professional
/// discussion merged into one surface. Private to the professional network: it
/// is for agents to share deals and talk shop, NOT for public sharing (the
/// public social Feed is a separate surface available to everyone).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});
  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this)..addListener(_onTab);

  void _onTab() {
    if (mounted) setState(() {}); // swap the FAB when the tab changes
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onDeals = _tab.index == 0;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Community'),
      drawer: const NuzlDrawer(),
      floatingActionButton: onDeals
          ? FloatingActionButton.extended(
              onPressed: () => openDealComposer(context, ref),
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Post a deal'),
            )
          : FloatingActionButton.extended(
              onPressed: () => openFeedComposer(context, ref, audience: 'company'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New post'),
            ),
      body: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tab,
              tabs: const [
                Tab(icon: Icon(Icons.campaign_outlined), text: 'Deals'),
                Tab(icon: Icon(Icons.forum_outlined), text: 'Discussion'),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: const [
                // Deals: the broadcast/co-broke deal board (cross-agent).
                DealBoardScreen(embedded: true),
                // Discussion: professional posts (company/agents scope).
                FeedScreen(embedded: true, scope: 'company'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
