import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../auth/application/auth_controller.dart';
import '../referral/refer_screen.dart';
import '../shell/app_shell.dart';

final leaderboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/promotions/leaderboard');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Rewards & offers — launch promotions + the platform top-contributor leaderboard.
class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key, this.embedded = false});

  /// When embedded in the Rewards hub's tabs, render just the body.
  final bool embedded;

  static const _offers = [
    (Icons.celebration_outlined, 'First month free', 'Every new member gets a full month free — no card required to start.', AppColors.success, null),
    (Icons.emoji_events_outlined, 'Top 10 contributors win', 'The 10 members who add the most properties each cycle earn a free year of membership.', AppColors.accentGold, null),
    (Icons.card_giftcard, 'Refer & Earn', 'Get 1 free month for every friend who joins with your link. Unlimited referrals.', AppColors.primaryBright, '/refer'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final board = ref.watch(leaderboardProvider);
    final myId = ref.watch(authControllerProvider).user?.id;
    final body = ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async => ref.refresh(leaderboardProvider.future),
          child: ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
            // Launch offers
            Container(
              padding: const EdgeInsets.all(AppSpacing.x20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.rCard),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_offer_outlined, color: AppColors.goldAccent, size: 24),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(child: Text('Launch offers',
                      style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text('Early adopters get rewarded. Make the most of the launch.',
                    style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
            const SizedBox(height: AppSpacing.x12),
            for (final o in _offers) ...[
              _OfferCard(icon: o.$1, title: o.$2, body: o.$3, color: o.$4, route: o.$5),
              const SizedBox(height: AppSpacing.x8),
            ],

            const SizedBox(height: AppSpacing.x16),
            Row(children: [
              Icon(Icons.leaderboard_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.x8),
              Text('Top contributors', style: t.titleMedium),
            ]),
            const SizedBox(height: AppSpacing.x4),
            Text('Members who added the most properties.',
                style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
            const SizedBox(height: AppSpacing.x12),
            board.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
              error: (e, _) => Text(friendlyError(e)),
              data: (m) {
                final top = (m['top'] is List) ? m['top'] as List : const [];
                final myCount = int.tryParse('${m['my_count'] ?? 0}') ?? 0;
                if (top.isEmpty) {
                  return Text('No rankings yet — add properties to climb the board.',
                      style: t.bodyMedium?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted));
                }
                return Column(children: [
                  for (var i = 0; i < top.length; i++)
                    _RankTile(rank: i + 1, row: Map<String, dynamic>.from(top[i]), me: myId),
                  const SizedBox(height: AppSpacing.x12),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppSpacing.rMd),
                    ),
                    child: Row(children: [
                      const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.x8),
                      Expanded(child: Text('You’ve added $myCount ${myCount == 1 ? 'property' : 'properties'}',
                          style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ]);
              },
            ),
            const SizedBox(height: AppSpacing.x24),
          ]),
        ),
      );
    if (embedded) return body;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Rewards & offers'),
      drawer: const NuzlDrawer(),
      body: body,
    );
  }
}

/// Combined "Rewards & referrals" hub — tabs for the rewards/leaderboard view
/// and the Refer & Earn program, so they live under one menu entry.
class RewardsHubScreen extends StatelessWidget {
  const RewardsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: NuzlAppBar(title: 'Rewards & referrals'),
        drawer: NuzlDrawer(),
        body: Column(children: [
          TabBar(tabs: [Tab(text: 'Rewards & offers'), Tab(text: 'Refer & Earn')]),
          Expanded(
            child: TabBarView(children: [
              RewardsScreen(embedded: true),
              ReferScreen(embedded: true),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.icon, required this.title, required this.body, required this.color, this.route});
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String? route;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        onTap: route == null ? null : () => context.push(route!),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppSpacing.rMd)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSpacing.x12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted)),
              ]),
            ),
            if (route != null) Icon(Icons.chevron_right, color: dark ? AppColors.dTextSubtle : AppColors.textSubtle),
          ]),
        ),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.rank, required this.row, required this.me});
  final int rank;
  final Map<String, dynamic> row;
  final String? me;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isMe = me != null && '${row['id']}' == me;
    final count = int.tryParse('${row['property_count'] ?? 0}') ?? 0;
    final medal = rank == 1 ? AppColors.accentGold : rank == 2 ? (dark ? AppColors.dTextMuted : AppColors.textMuted) : rank == 3 ? AppColors.warning : null;
    return Card(
      color: isMe ? AppColors.primary.withValues(alpha: 0.06) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x12, vertical: AppSpacing.x8),
        child: Row(children: [
          SizedBox(
            width: 28,
            child: medal != null
                ? Icon(Icons.emoji_events, size: 20, color: medal)
                : Text('$rank', textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: AppSpacing.x8),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primaryTint,
            backgroundImage: '${row['avatar_url'] ?? ''}'.isNotEmpty ? NetworkImage('${row['avatar_url']}') : null,
            child: '${row['avatar_url'] ?? ''}'.isEmpty
                ? Text('${row['full_name'] ?? '?'}'.isNotEmpty ? '${row['full_name']}'[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13))
                : null,
          ),
          const SizedBox(width: AppSpacing.x8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['full_name'] ?? 'Member'}${isMe ? ' (you)' : ''}',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if ('${row['org_name'] ?? ''}'.isNotEmpty)
                Text('${row['org_name']}', style: t.bodySmall?.copyWith(color: dark ? AppColors.dTextMuted : AppColors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          Text('$count', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
        ]),
      ),
    );
  }
}
