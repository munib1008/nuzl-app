import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/rbac/persona.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/image_crop_dialog.dart';
import '../../../core/widgets/multi_select_field.dart';
import '../../../core/widgets/nuzl_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

final _meProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final d = await ref.read(apiClientProvider).get('/users/me');
  return (d is Map) ? Map<String, dynamic>.from(d) : {};
});

/// Avatar is fetched/saved separately so it never blocks profile load/save.
final _avatarProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final d = await ref.read(apiClientProvider).get('/users/me/avatar');
    final u = (d is Map) ? '${d['avatar_url'] ?? ''}' : '';
    return u.isEmpty ? null : u;
  } catch (_) {
    return null;
  }
});

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loaded = false;
  bool _saving = false;
  bool _dirty = false;
  String? _role; // agency | agent | owner | investor | buyer
  final company = TextEditingController();
  final phone = TextEditingController();
  final whatsapp = TextEditingController();
  final bio = TextEditingController();
  final areas = <String>{};
  final languages = <String>{};
  final specialties = <String>{};

  static const _emirates = ['Dubai','Abu Dhabi','Sharjah','Ajman','Ras Al Khaimah','Fujairah','Umm Al Quwain','Al Ain'];
  static const _langs = ['English','Arabic','Hindi','Urdu','Tagalog','Malayalam','Tamil','French'];
  static const _specs = ['Villas','Apartments','Penthouses','Townhouses','Commercial','Off-Plan','Luxury','Investment'];
  static const _roleOptions = [
    ('agency', 'Agency'),
    ('agent', 'Agent'),
    ('owner', 'Owner'),
    ('investor', 'Investor'),
    ('buyer', 'Customer'),
  ];

  /// Map any stored role string to one of the five selectable options.
  static String? _canonRole(dynamic raw) {
    final r = '${raw ?? ''}'.toLowerCase();
    if (r.isEmpty) return null;
    return switch (personaFromRole(r)) {
      Persona.broker => 'agency',
      Persona.agent || Persona.leadGenerator => 'agent',
      Persona.owner => 'owner',
      Persona.investor || Persona.developer => 'investor',
      Persona.buyer => 'buyer',
      Persona.admin => null,
    };
  }

  @override
  void dispose() { company.dispose(); phone.dispose(); whatsapp.dispose(); bio.dispose(); super.dispose(); }

  void _markDirty() { if (!_dirty) setState(() => _dirty = true); }

  /// Prompt to Save / Discard / Keep editing when leaving with unsaved edits.
  Future<void> _onLeave() async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('You have unsaved changes. Save them before leaving?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'cancel'), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Discard')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Save')),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'save') {
      await _save();
    } else if (action == 'discard') {
      _dirty = false;
    } else {
      return; // keep editing
    }
    if (mounted) _leave();
  }

  void _leave() => context.canPop() ? context.pop() : context.go('/dashboard');

  Future<void> _save() async {
    if (_role != null) {
      ref.read(personaOverrideProvider.notifier).set(personaFromRole(_role));
    }
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/users/me', body: {
        if (_role != null) 'role': _role,
        'company': company.text.trim(),
        'phone': phone.text.trim(),
        'whatsapp': whatsapp.text.trim(),
        'bio': bio.text.trim(),
        'areas': areas.toList(),
        'languages': languages.toList(),
        'specialties': specialties.toList(),
      });
      ref.invalidate(_meProvider);
      _dirty = false;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Profile photo ─────────────────────────────────────────────
  void _avatarMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Upload photo'),
              onTap: () { Navigator.pop(ctx); _pickAndUpload(); }),
          ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Paste image URL'),
              onTap: () { Navigator.pop(ctx); _pasteUrlDialog(); }),
          ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove photo'),
              onTap: () { Navigator.pop(ctx); _setAvatar(''); }),
        ]),
      ),
    );
  }

  Future<void> _pickAndUpload() async {
    try {
      // Pick at a modest resolution, then let the user crop/align to a square.
      // Keeping the source small + the square output well under the server body
      // limit avoids the "request entity too large" failures.
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 90);
      if (file == null) return;
      final raw = await file.readAsBytes();
      if (!mounted) return;
      final cropped = await ImageCropDialog.show(context, raw);
      if (cropped == null) return; // cancelled
      final res = await ref.read(apiClientProvider).post('/uploads', body: {
        'filename': 'avatar.png',
        'contentType': 'image/png',
        'dataBase64': base64Encode(cropped),
      });
      final url = (res is Map) ? '${res['url'] ?? ''}' : '';
      if (url.isNotEmpty) await _setAvatar(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload unavailable ($e). Try “Paste image URL”.')));
      }
    }
  }

  Future<void> _pasteUrlDialog() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profile photo URL'),
        content: TextField(controller: c, decoration: const InputDecoration(hintText: 'https://…')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) await _setAvatar(c.text.trim());
  }

  Future<void> _setAvatar(String url) async {
    try {
      await ref.read(apiClientProvider).patch('/users/me/avatar', body: {'avatar_url': url});
      ref.invalidate(_avatarProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(url.isEmpty ? 'Photo removed' : 'Photo updated')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // ── Account deletion (soft delete) ────────────────────────────
  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
            'Your account will be deactivated and you will be signed out. Contact support to restore it.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post('/users/me/deactivate');
      await ref.read(authControllerProvider.notifier).logout();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _prefill(Map<String, dynamic> m) {
    if (_loaded) return;
    _loaded = true;
    _role = _canonRole(m['role']);
    company.text = (m['company'] ?? '').toString();
    phone.text = (m['phone'] ?? '').toString();
    whatsapp.text = (m['whatsapp'] ?? '').toString();
    bio.text = (m['bio'] ?? '').toString();
    void fill(Set<String> set, dynamic v) { if (v is List) set.addAll(v.map((e) => '$e')); }
    fill(areas, m['areas']); fill(languages, m['languages']); fill(specialties, m['specialties']);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;
    final isAdmin = personaFromRole(user?.role) == Persona.admin;
    final avatarUrl = ref.watch(_avatarProvider).asData?.value;
    ref.watch(_meProvider).whenData(_prefill);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !_dirty) return;
        _onLeave();
      },
      child: Scaffold(
        appBar: const NuzlAppBar(title: 'Profile & settings'),
        drawer: const NuzlDrawer(),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            // header
            Center(child: Column(children: [
              Stack(children: [
                if (avatarUrl != null && avatarUrl.isNotEmpty)
                  CircleAvatar(radius: 36, backgroundColor: AppColors.surface2, backgroundImage: NetworkImage(avatarUrl))
                else
                  CircleAvatar(radius: 36, backgroundColor: AppColors.primary,
                    child: Text((user?.fullName.isNotEmpty == true ? user!.fullName[0] : 'N').toUpperCase(),
                        style: t.headlineMedium?.copyWith(color: Colors.white))),
                Positioned(
                  right: 0, bottom: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _avatarMenu,
                      child: const Padding(padding: EdgeInsets.all(6),
                        child: Icon(Icons.camera_alt_outlined, size: 16, color: Colors.white)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: AppSpacing.x12),
              Text(user?.fullName ?? 'Account', style: t.titleLarge),
              Text(user?.email ?? '', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: AppSpacing.x8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(AppSpacing.rFull)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.verified_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text('Unverified', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
              ),
            ])),
            const SizedBox(height: AppSpacing.x24),

            // profile information
            Card(child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Profile information', style: t.titleMedium),
                Text('Update your profile to help others find and trust you',
                    style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                const SizedBox(height: AppSpacing.x16),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'I am a…', prefixIcon: Icon(Icons.badge_outlined)),
                  items: _roleOptions.map((r) => DropdownMenuItem(value: r.$1, child: Text(r.$2))).toList(),
                  onChanged: (v) => setState(() { _role = v; _dirty = true; }),
                ),
                const SizedBox(height: AppSpacing.x12),
                TextField(controller: company, onChanged: (_) => _markDirty(), decoration: const InputDecoration(labelText: 'Company name', hintText: 'Your company or brokerage')),
                const SizedBox(height: AppSpacing.x12),
                TextField(controller: phone, onChanged: (_) => _markDirty(), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number', hintText: '+971 …')),
                const SizedBox(height: AppSpacing.x12),
                TextField(controller: whatsapp, onChanged: (_) => _markDirty(), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '+971 …')),
                const SizedBox(height: AppSpacing.x12),
                TextField(controller: bio, onChanged: (_) => _markDirty(), maxLines: 3, decoration: const InputDecoration(labelText: 'Bio', hintText: 'Tell others about yourself…')),
                const SizedBox(height: AppSpacing.x16),
                MultiSelectField(label: 'Areas you cover', icon: Icons.map_outlined, options: _emirates, selected: areas,
                    onChanged: (v) => setState(() { areas..clear()..addAll(v); _dirty = true; })),
                MultiSelectField(label: 'Languages', icon: Icons.translate_outlined, options: _langs, selected: languages,
                    onChanged: (v) => setState(() { languages..clear()..addAll(v); _dirty = true; })),
                MultiSelectField(label: 'Property specialties', icon: Icons.star_outline, options: _specs, selected: specialties,
                    onChanged: (v) => setState(() { specialties..clear()..addAll(v); _dirty = true; })),
                Align(alignment: Alignment.centerRight,
                  child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving…' : 'Save changes'))),
              ]),
            )),
            const SizedBox(height: AppSpacing.x16),

            // account
            Card(child: Column(children: [
              // "View as role" test mode is restricted to administrators.
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('View as role'),
                  subtitle: const Text('Preview any role (test mode)'),
                  onTap: () => context.go('/view-as')),
              if (isAdmin) const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text('Sign out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () async {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) context.go('/');
                },
              ),
            ])),
            const SizedBox(height: AppSpacing.x16),

            // danger zone — account deletion (kept low-key)
            Card(child: ListTile(
              leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
              title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              subtitle: const Text('Deactivate your account and sign out'),
              onTap: _deleteAccount,
            )),
            const SizedBox(height: AppSpacing.x24),
            const Center(child: Opacity(opacity: 0.5, child: NuzlLogo(size: 24))),
            const SizedBox(height: AppSpacing.x24),
          ],
        ),
      ),
    );
  }
}
