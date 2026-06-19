import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_dialog.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/responsive.dart';
import '../../core/widgets/verification_badge.dart';
import '../shell/app_shell.dart';

/// Pending ownership claims the user can act on (orgs they own) + their own submitted claims.
final orgClaimsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/claims');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

/// The caller's own company (with verification status), or null if none.
final myCompanyProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/current');
    return d is Map ? Map<String, dynamic>.from(d) : null;
  } catch (_) {
    return null;
  }
});

/// Pending company-join requests the user can act on (companies they own) + their own.
final joinRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/organizations/mine/join-requests');
    return d is List ? d.map((e) => Map<String, dynamic>.from(e as Map)).toList() : <Map<String, dynamic>>[];
  } catch (_) {
    return <Map<String, dynamic>>[];
  }
});

class OrgOwnershipScreen extends ConsumerWidget {
  const OrgOwnershipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final claims = ref.watch(orgClaimsProvider);
    final joinReqs = ref.watch(joinRequestsProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Organization ownership'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(orgClaimsProvider);
            ref.invalidate(joinRequestsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.x16),
            children: [
              const _CompanyVerificationCard(),
              const SizedBox(height: AppSpacing.x16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Claim ownership', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.x4),
                    Text('Request to become the owner of your organization. The current owner approves or declines.',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                    const SizedBox(height: AppSpacing.x12),
                    FilledButton.icon(
                      onPressed: () => _claim(context, ref),
                      icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                      label: const Text('Claim ownership'),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
              Text('Pending claims', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              AsyncView<List<Map<String, dynamic>>>(
                value: claims,
                onRetry: () => ref.invalidate(orgClaimsProvider),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                        child: Text('No pending claims.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      )
                    : Column(children: [for (final c in list) _ClaimTile(c)]),
              ),
              const SizedBox(height: AppSpacing.x16),
              Text('Company join requests', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              AsyncView<List<Map<String, dynamic>>>(
                value: joinReqs,
                onRetry: () => ref.invalidate(joinRequestsProvider),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x16),
                        child: Text('No join requests.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                      )
                    : Column(children: [for (final j in list) _JoinTile(j)]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _claim(BuildContext context, WidgetRef ref) async {
    final reason = TextEditingController();
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Claim ownership',
      children: [
        TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (optional)', hintText: 'Why should you own this org?'),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit claim')),
      ],
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/organizations/mine/claim', body: {'reason': reason.text.trim()});
      ref.invalidate(orgClaimsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim submitted')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

/// A pending company-join request: owners approve/decline; requesters see status.
class _JoinTile extends ConsumerWidget {
  const _JoinTile(this.j);
  final Map<String, dynamic> j;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/organizations/join-requests/${j['id']}/decide', body: {'approve': approve});
      ref.invalidate(joinRequestsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final iAmOwner = j['i_am_owner'] == true;
    final orgName = '${j['org_name'] ?? 'the company'}';
    final requester = '${j['requester_name'] ?? 'A user'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(iAmOwner ? '$requester wants to join $orgName' : 'Your request to join $orgName',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (iAmOwner && '${j['requester_email'] ?? ''}'.trim().isNotEmpty)
                Text('${j['requester_email']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              if (!iAmOwner)
                Text('Awaiting the company owner’s decision.',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          if (iAmOwner) ...[
            const SizedBox(width: AppSpacing.x8),
            TextButton(onPressed: () => _decide(context, ref, false), child: const Text('Decline')),
            FilledButton(onPressed: () => _decide(context, ref, true), child: const Text('Approve')),
          ],
        ]),
      ),
    );
  }
}

/// Company verification status + self-serve submission (owner-only).
class _CompanyVerificationCard extends ConsumerWidget {
  const _CompanyVerificationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final company = ref.watch(myCompanyProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x16),
        child: company.when(
          loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
          error: (_, __) => Text('Company unavailable.', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
          data: (c) {
            if (c == null) return _noCompany(context, ref, t);
            final status = '${c['verification_status'] ?? 'pending'}';
            final owner = c['i_am_owner'] == true;
            final submitted = '${c['submitted_at'] ?? ''}'.isNotEmpty;
            final note = '${c['verification_note'] ?? ''}'.trim();
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('Company verification', style: t.titleMedium)),
                VerificationBadge(status),
              ]),
              const SizedBox(height: AppSpacing.x4),
              Text('${c['name'] ?? 'Your company'}',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.x8),
              Text(_blurb(status, submitted),
                  style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              if (status == 'rejected' && note.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.x8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  ),
                  child: Text('Reviewer note: $note',
                      style: t.bodySmall?.copyWith(color: AppColors.danger)),
                ),
              ],
              if (owner && status != 'verified') ...[
                const SizedBox(height: AppSpacing.x12),
                FilledButton.icon(
                  onPressed: () => _submit(context, ref, c),
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(status == 'rejected' || submitted ? 'Resubmit for verification' : 'Submit for verification'),
                ),
              ],
              if (!owner && status != 'verified')
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x8),
                  child: Text('Only the company owner can submit for verification.',
                      style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ),
            ]);
          },
        ),
      ),
    );
  }

  String _blurb(String status, bool submitted) {
    switch (status) {
      case 'verified':
        return 'Your company is verified — you can publish listings and appear in the marketplace.';
      case 'rejected':
        return 'Verification was declined. Fix the issue below and resubmit.';
      default:
        return submitted
            ? 'Submitted for review. We’ll notify you once it’s approved. You can save drafts meanwhile, but listings stay private until verified.'
            : 'Submit your trade license to get verified. Until then you can save drafts, but listings won’t be published publicly.';
    }
  }

  Widget _noCompany(BuildContext context, WidgetRef ref, TextTheme t) {
    final name = TextEditingController();
    String type = 'agency';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Company verification', style: t.titleMedium),
      const SizedBox(height: AppSpacing.x4),
      Text('You’re not part of a company yet. Create one to list services, products or inventory.',
          style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.x12),
      FilledButton.icon(
        onPressed: () async {
          final ok = await AppDialog.show<bool>(
            context,
            title: 'Create company',
            children: [
              StatefulBuilder(
                builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Company name *')),
                  const SizedBox(height: AppSpacing.x8),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Business type'),
                    items: const [
                      DropdownMenuItem(value: 'agency', child: Text('Real estate agency')),
                      DropdownMenuItem(value: 'developer', child: Text('Developer')),
                      DropdownMenuItem(value: 'maintenance', child: Text('Service provider')),
                      DropdownMenuItem(value: 'supplier', child: Text('Product supplier')),
                    ],
                    onChanged: (v) => setS(() => type = v ?? 'agency'),
                  ),
                ]),
              ),
            ],
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
            ],
          );
          if (ok != true || name.text.trim().isEmpty) return;
          try {
            await ref.read(apiClientProvider).post('/organizations/mine', body: {'name': name.text.trim(), 'org_type': type});
            ref.invalidate(myCompanyProvider);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company created')));
            }
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
          }
        },
        icon: const Icon(Icons.add_business_outlined, size: 18),
        label: const Text('Create company'),
      ),
    ]);
  }

  Future<void> _submit(BuildContext context, WidgetRef ref, Map<String, dynamic> c) async {
    final license = TextEditingController(text: '${c['trade_license'] ?? ''}');
    final phone = TextEditingController(text: '${c['phone'] ?? ''}');
    final email = TextEditingController(text: '${c['email'] ?? ''}');
    final about = TextEditingController(text: '${c['about'] ?? ''}');
    String? docUrl = '${c['trade_license_doc'] ?? ''}'.isEmpty ? null : '${c['trade_license_doc']}';
    var uploading = false;
    final ok = await AppDialog.show<bool>(
      context,
      title: 'Submit for verification',
      maxWidth: 460,
      children: [
        StatefulBuilder(
          builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: license, decoration: const InputDecoration(labelText: 'Trade license number *')),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(
                child: Text(
                  docUrl == null ? 'Attach trade-license document' : 'Document attached ✓',
                  style: TextStyle(color: docUrl == null ? AppColors.textMuted : AppColors.success),
                ),
              ),
              TextButton.icon(
                onPressed: uploading
                    ? null
                    : () async {
                        final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2200, imageQuality: 85);
                        if (picked == null) return;
                        final bytes = await picked.readAsBytes();
                        setS(() => uploading = true);
                        try {
                          final up = await ref.read(apiClientProvider).post('/uploads', body: {
                            'filename': picked.name,
                            'contentType': 'image/jpeg',
                            'dataBase64': base64Encode(bytes),
                          });
                          final url = (up is Map) ? up['url'] : null;
                          if (url != null) setS(() => docUrl = '$url');
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                        } finally {
                          setS(() => uploading = false);
                        }
                      },
                icon: uploading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload'),
              ),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Contact phone'))),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: TextField(controller: email, decoration: const InputDecoration(labelText: 'Contact email'))),
            ]),
            const SizedBox(height: AppSpacing.x8),
            TextField(controller: about, maxLines: 2, decoration: const InputDecoration(labelText: 'Company description')),
          ]),
        ),
      ],
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
      ],
    );
    if (ok != true) return;
    if (license.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A trade license number is required.')));
      }
      return;
    }
    try {
      await ref.read(apiClientProvider).post('/organizations/mine/submit-verification', body: {
        'trade_license': license.text.trim(),
        'trade_license_doc': docUrl,
        'phone': phone.text.trim().isEmpty ? null : phone.text.trim(),
        'email': email.text.trim().isEmpty ? null : email.text.trim(),
        'about': about.text.trim().isEmpty ? null : about.text.trim(),
      });
      ref.invalidate(myCompanyProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for verification')));
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
}

class _ClaimTile extends ConsumerWidget {
  const _ClaimTile(this.c);
  final Map<String, dynamic> c;

  Future<void> _decide(BuildContext context, WidgetRef ref, bool approve) async {
    try {
      await ref.read(apiClientProvider).post('/organizations/claims/${c['id']}/decide', body: {'approve': approve});
      ref.invalidate(orgClaimsProvider);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final iAmOwner = c['i_am_owner'] == true;
    final orgName = '${c['org_name'] ?? 'Organization'}';
    final claimant = '${c['claimant_name'] ?? 'A member'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(iAmOwner ? '$claimant wants to own $orgName' : 'Your claim on $orgName',
                  style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if ('${c['reason'] ?? ''}'.trim().isNotEmpty)
                Text('${c['reason']}', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              if (!iAmOwner)
                Text('Awaiting the current owner’s decision.',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
            ]),
          ),
          if (iAmOwner) ...[
            const SizedBox(width: AppSpacing.x8),
            TextButton(onPressed: () => _decide(context, ref, false), child: const Text('Decline')),
            FilledButton(onPressed: () => _decide(context, ref, true), child: const Text('Approve')),
          ],
        ]),
      ),
    );
  }
}
