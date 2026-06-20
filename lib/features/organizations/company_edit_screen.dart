import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../core/network/upload_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../shell/app_shell.dart';
import 'org_ownership_screen.dart';

/// Owner editor for the company's public page (/org/:slug). Edits the tagline,
/// about, cover image, contact links and credentials shown there. Saves via
/// PATCH /organizations/mine (owner-only on the server).
class CompanyEditScreen extends ConsumerStatefulWidget {
  const CompanyEditScreen({super.key});
  @override
  ConsumerState<CompanyEditScreen> createState() => _CompanyEditScreenState();
}

class _CompanyEditScreenState extends ConsumerState<CompanyEditScreen> {
  final _tagline = TextEditingController();
  final _about = TextEditingController();
  final _website = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController();
  final _reraOrn = TextEditingController();
  final _tradeLicense = TextEditingController();
  final _legalEntity = TextEditingController();
  final _yearEstablished = TextEditingController();
  final _countryOfReg = TextEditingController();
  final _vat = TextEditingController();
  final _innovation = TextEditingController();

  String _coverUrl = '';
  bool _loaded = false;
  bool _saving = false;
  bool _uploadingCover = false;

  @override
  void dispose() {
    for (final c in [
      _tagline, _about, _website, _phone, _email, _city, _country, _reraOrn,
      _tradeLicense, _legalEntity, _yearEstablished, _countryOfReg, _vat, _innovation,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(Map<String, dynamic> c) {
    String s(String k) => '${c[k] ?? ''}'.trim();
    _tagline.text = s('tagline');
    _about.text = s('about');
    _website.text = s('website');
    _phone.text = s('phone');
    _email.text = s('email');
    _city.text = s('city');
    _country.text = s('country');
    _reraOrn.text = s('rera_orn');
    _tradeLicense.text = s('trade_license');
    _legalEntity.text = s('legal_entity_type');
    final y = s('year_established');
    _yearEstablished.text = (y.isEmpty || y == '0') ? '' : y;
    _countryOfReg.text = s('country_of_registration');
    _vat.text = s('vat_number');
    _innovation.text = s('innovation_license');
    _coverUrl = s('cover_image_url');
    _loaded = true;
  }

  Future<void> _pickCover() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() => _uploadingCover = true);
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      if (url != null && url.isNotEmpty) {
        setState(() => _coverUrl = url);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cover upload failed — try again.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cover upload failed — ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).patch('/organizations/mine', body: {
        'tagline': _tagline.text.trim(),
        'about': _about.text.trim(),
        'cover_image_url': _coverUrl.trim(),
        'website': _website.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'city': _city.text.trim(),
        'country': _country.text.trim(),
        'rera_orn': _reraOrn.text.trim(),
        'trade_license': _tradeLicense.text.trim(),
        'legal_entity_type': _legalEntity.text.trim(),
        'year_established': _yearEstablished.text.trim(),
        'country_of_registration': _countryOfReg.text.trim(),
        'vat_number': _vat.text.trim(),
        'innovation_license': _innovation.text.trim(),
      });
      ref.invalidate(myCompanyProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Public page updated.')));
        if (context.canPop()) context.pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = ref.watch(myCompanyProvider);
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Edit public page'),
      drawer: const NuzlDrawer(),
      body: AsyncView<Map<String, dynamic>?>(
        value: company,
        onRetry: () => ref.invalidate(myCompanyProvider),
        data: (c) {
          if (c == null) {
            return const Center(
              child: Padding(padding: EdgeInsets.all(24), child: Text('Create or join a company first.')),
            );
          }
          if (!_loaded) _prefill(c);
          final slug = '${c['slug'] ?? ''}'.trim();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.x16),
                children: [
                  _cover(context, slug),
                  const SizedBox(height: AppSpacing.x20),
                  _section(context, 'Basics'),
                  _field(_tagline, 'Tagline', hint: 'e.g. Dubai’s off-plan specialists'),
                  _field(_about, 'About the company', maxLines: 5, hint: 'What you do, who you serve, what sets you apart.'),
                  const SizedBox(height: AppSpacing.x20),
                  _section(context, 'Contact & links'),
                  _field(_website, 'Website', keyboard: TextInputType.url),
                  _field(_phone, 'Phone', keyboard: TextInputType.phone),
                  _field(_email, 'Email', keyboard: TextInputType.emailAddress),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _field(_city, 'City')),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(child: _field(_country, 'Country')),
                  ]),
                  const SizedBox(height: AppSpacing.x20),
                  _section(context, 'Credentials & registration'),
                  _field(_reraOrn, 'RERA ORN'),
                  _field(_tradeLicense, 'Trade licence'),
                  _field(_legalEntity, 'Legal entity type', hint: 'e.g. LLC, Free Zone, Sole Establishment'),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: _field(_yearEstablished, 'Year established', keyboard: TextInputType.number,
                        formatters: [FilteringTextInputFormatter.digitsOnly])),
                    const SizedBox(width: AppSpacing.x12),
                    Expanded(child: _field(_countryOfReg, 'Country of registration')),
                  ]),
                  _field(_vat, 'TRN / VAT number'),
                  _field(_innovation, 'Innovation licence'),
                  const SizedBox(height: AppSpacing.x24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_saving ? 'Saving…' : 'Save changes'),
                  ),
                  if (slug.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.x8),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/org/$slug'),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Preview public page'),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.x32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _section(BuildContext context, String label) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        child: Text(label, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _field(TextEditingController c, String label,
      {String? hint, int maxLines = 1, TextInputType? keyboard, List<TextInputFormatter>? formatters}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x12),
      child: TextField(
        controller: c,
        minLines: maxLines > 1 ? maxLines : 1,
        maxLines: maxLines,
        keyboardType: keyboard,
        inputFormatters: formatters,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }

  Widget _cover(BuildContext context, String slug) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _section(context, 'Cover image'),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        child: AspectRatio(
          aspectRatio: 3.4,
          child: _coverUrl.isNotEmpty
              ? Image.network(_coverUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(t))
              : _coverPlaceholder(t),
        ),
      ),
      const SizedBox(height: AppSpacing.x8),
      Row(children: [
        OutlinedButton.icon(
          onPressed: _uploadingCover ? null : _pickCover,
          icon: _uploadingCover
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(_uploadingCover ? 'Uploading…' : (_coverUrl.isEmpty ? 'Upload cover' : 'Replace cover')),
        ),
        if (_coverUrl.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.x8),
          TextButton(onPressed: _uploadingCover ? null : () => setState(() => _coverUrl = ''), child: const Text('Remove')),
        ],
      ]),
    ]);
  }

  Widget _coverPlaceholder(TextTheme t) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary]),
        ),
        child: Center(
          child: Text('No cover yet', style: t.bodySmall?.copyWith(color: Colors.white70)),
        ),
      );
}
