import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../features/auth/application/auth_controller.dart';

/// Follow / unfollow an agent (user) or organization, with a live follower count.
class FollowButton extends ConsumerStatefulWidget {
  const FollowButton({super.key, required this.targetId, this.isOrg = false});
  final String targetId;
  final bool isOrg;

  @override
  ConsumerState<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<FollowButton> {
  bool _loading = true;
  bool _busy = false;
  bool _following = false;
  int _followers = 0;

  String get _path => widget.isOrg ? '/follows/org/${widget.targetId}' : '/follows/user/${widget.targetId}';

  static int _n(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).get(_path);
      if (!mounted) return;
      setState(() {
        _following = r is Map && r['is_following'] == true;
        _followers = r is Map ? _n(r['followers']) : 0;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle() async {
    setState(() => _busy = true);
    try {
      final api = ref.read(apiClientProvider);
      final r = _following ? await api.delete(_path) : await api.post(_path);
      if (!mounted) return;
      setState(() {
        _following = r is Map && r['is_following'] == true;
        _followers = r is Map ? _n(r['followers']) : _followers;
        _busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show a follow button on your own profile.
    final myId = ref.watch(authControllerProvider).user?.id;
    if (!widget.isOrg && myId != null && myId == widget.targetId) return const SizedBox.shrink();
    if (_loading) {
      return const SizedBox(height: 36, width: 90,
          child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    final btn = _following
        ? OutlinedButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Following'))
        : FilledButton.icon(
            onPressed: _busy ? null : _toggle,
            icon: const Icon(Icons.person_add_alt, size: 18),
            label: const Text('Follow'));
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn,
      const SizedBox(width: AppSpacing.x8),
      Text('$_followers follower${_followers == 1 ? '' : 's'}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
    ]);
  }
}
