import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/responsive.dart';
import '../shell/app_shell.dart';

final referralProgramProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/referral-program/me');
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  } catch (_) {
    return <String, dynamic>{};
  }
});

/// Refer & Earn — share your code, earn a free month for every friend who joins.
class ReferScreen extends ConsumerWidget {
  const ReferScreen({super.key, this.embedded = false});

  /// When embedded in the Rewards hub's tabs, render just the body (no
  /// Scaffold/app-bar/drawer of its own).
  final bool embedded;

  static String shareLink(String code) {
    // Web uses hash routing; the link opens signup with the code prefilled.
    final origin = Uri.base.origin;
    return origin.isEmpty ? 'https://nuzl.app/#/register?ref=$code' : '$origin/#/register?ref=$code';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(referralProgramProvider);
    final body = ResponsiveCenter(
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(referralProgramProvider.future),
        child: program.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(friendlyError(e)))]),
          data: (m) => _body(context, m),
        ),
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Refer & Earn'),
      drawer: const NuzlDrawer(),
      body: body,
    );
  }

  Widget _body(BuildContext context, Map<String, dynamic> m) {
    final t = Theme.of(context).textTheme;
    final code = '${m['code'] ?? ''}';
    final joined = int.tryParse('${m['joined_count'] ?? 0}') ?? 0;
    final months = int.tryParse('${m['free_months'] ?? 0}') ?? 0;
    final referrals = (m['referrals'] is List) ? m['referrals'] as List : const [];
    final link = code.isEmpty ? '' : shareLink(code);
    return ListView(padding: const EdgeInsets.all(AppSpacing.x16), children: [
      // Reward hero
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
            const Icon(Icons.card_giftcard, color: AppColors.goldAccent, size: 26),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: Text('Give a month, get a month',
                style: t.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text('Earn 1 free month of membership for every friend who joins with your link. Unlimited referrals.',
              style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
        ]),
      ),
      const SizedBox(height: AppSpacing.x16),

      // Stats
      Row(children: [
        Expanded(child: _stat(context, '$joined', joined == 1 ? 'Friend joined' : 'Friends joined', Icons.group_add_outlined, AppColors.primary)),
        const SizedBox(width: AppSpacing.x12),
        Expanded(child: _stat(context, '$months', months == 1 ? 'Free month' : 'Free months', Icons.calendar_month_outlined, AppColors.success)),
      ]),
      const SizedBox(height: AppSpacing.x16),

      // Code + link
      Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your referral code', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.x8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x16, vertical: AppSpacing.x12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppSpacing.rMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(code.isEmpty ? '—' : code,
                      style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 2)),
                ),
                if (code.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _copy(context, code, 'Code copied'),
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
              ]),
            ),
            if (link.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x12),
              Text('Share link', style: t.labelMedium?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(link, style: t.bodySmall?.copyWith(color: AppColors.info), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.x12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _copy(context, link, 'Invite link copied — share it with your network'),
                  icon: const Icon(Icons.ios_share, size: 18),
                  label: const Text('Copy invite link'),
                ),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: AppSpacing.x16),

      Text('Your referrals', style: t.titleMedium),
      const SizedBox(height: AppSpacing.x8),
      if (referrals.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
          child: Text('No referrals yet — share your link to start earning free months.',
              style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
        )
      else
        Column(children: [for (final r in referrals) _ReferralTile(Map<String, dynamic>.from(r))]),
    ]);
  }

  Widget _stat(BuildContext context, String value, String label, IconData icon, Color color) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.x8),
          Text(value, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          Text(label, style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
        ]),
      ),
    );
  }

  void _copy(BuildContext context, String text, String msg) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ReferralTile extends StatelessWidget {
  const _ReferralTile(this.r);
  final Map<String, dynamic> r;
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = '${r['referred_name'] ?? 'New member'}';
    final when = DateTime.tryParse('${r['created_at'] ?? ''}');
    final rewarded = '${r['status']}' == 'rewarded';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.success.withValues(alpha: 0.12),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(when != null ? 'Joined ${DateFormat('d MMM yyyy').format(when.toLocal())}' : 'Joined'),
        trailing: Text(rewarded ? 'Rewarded' : '+1 month',
            style: t.labelMedium?.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
