import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/upload_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/sticky_save_bar.dart';
import '../../auth/application/auth_controller.dart';
import '../../shell/app_shell.dart';
import '../data/listings_repository.dart' show listingsProvider, amenitiesProvider;
import 'listings_screen.dart' show listingsRawProvider;

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key, this.editId, this.initial});

  /// When set, the form edits this listing (PATCH) instead of creating one.
  final String? editId;
  final Map<String, dynamic>? initial;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  String propertyType = 'apartment';
  String purpose = 'sale';
  String furnishing = 'unfurnished';
  final price = TextEditingController();
  final beds = TextEditingController(text: '1');
  final baths = TextEditingController(text: '1');
  final size = TextEditingController();
  final unitNo = TextEditingController();
  final ownerName = TextEditingController();
  final ownerPhone = TextEditingController();
  final description = TextEditingController();
  final permit = TextEditingController();
  final Set<int> selectedAmenities = {};

  Uint8List? imageBytes;
  String? imageName;
  String? coverUrl;
  bool uploading = false;
  bool saving = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    if (m != null) {
      const types = ['apartment', 'villa', 'townhouse', 'office', 'retail', 'warehouse', 'land'];
      const furns = ['unfurnished', 'partly_furnished', 'furnished'];
      propertyType = types.contains('${m['property_type']}') ? '${m['property_type']}' : 'apartment';
      purpose = (m['purpose'] == 'rent') ? 'rent' : 'sale';
      furnishing = furns.contains('${m['furnishing']}') ? '${m['furnishing']}' : 'unfurnished';
      price.text = m['price'] != null ? '${m['price']}' : '';
      beds.text = m['bedrooms'] != null ? '${m['bedrooms']}' : '';
      baths.text = m['bathrooms'] != null ? '${m['bathrooms']}' : '';
      size.text = m['size_sqft'] != null ? '${m['size_sqft']}' : '';
      unitNo.text = '${m['unit_no'] ?? ''}';
      description.text = '${m['description'] ?? ''}';
      permit.text = '${m['permit_number'] ?? ''}';
      final cov = '${m['cover_image'] ?? ''}';
      if (cov.isNotEmpty) coverUrl = cov;
      final am = m['amenities'];
      if (am is List) {
        for (final e in am) {
          final id = e is Map ? e['id'] : null;
          final n = id is int ? id : int.tryParse('$id');
          if (n != null) selectedAmenities.add(n);
        }
      }
    }
  }

  @override
  void dispose() {
    price.dispose(); beds.dispose(); baths.dispose(); size.dispose(); unitNo.dispose();
    ownerName.dispose(); ownerPhone.dispose(); description.dispose(); permit.dispose(); super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { imageBytes = bytes; imageName = picked.name; uploading = true; });
    try {
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      setState(() { coverUrl = url; uploading = false; });
      if (url == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server returned no image URL — listing will save without a photo.')));
      }
    } catch (e) {
      // Keep the local preview, but the listing will save without a stored photo.
      // Surface the real reason (e.g. uploads not configured / image too large).
      setState(() { coverUrl = null; uploading = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo not uploaded: $e\nThe listing will save without a photo.')));
      }
    }
  }

  Future<void> _save() async {
    setState(() { saving = true; error = null; });
    final editing = widget.editId != null;
    final body = <String, dynamic>{
      'property_type': propertyType,
      'purpose': purpose,
      'furnishing': furnishing,
      'price': double.tryParse(price.text) ?? 0,
      'bedrooms': int.tryParse(beds.text),
      'bathrooms': int.tryParse(baths.text),
      'size_sqft': double.tryParse(size.text),
      'description': description.text.trim(),
      'amenities': selectedAmenities.toList(),
      if (permit.text.trim().isNotEmpty) 'permit_number': permit.text.trim(),
      if (coverUrl != null) 'cover_image': coverUrl,
      if (coverUrl != null) 'images': [coverUrl],
    };
    try {
      Map<String, dynamic>? created;
      if (editing) {
        await ref.read(apiClientProvider).patch('/listings/${widget.editId}', body: body);
      } else {
        // For an owner listing their own property, the owner IS them — don't ask;
        // default the owner name from their profile. Agents enter the real owner.
        final u = ref.read(authControllerProvider).user;
        final isOwner = u?.activeRole == 'owner';
        body['unit_no'] = unitNo.text.trim();
        body['owner_name'] = isOwner ? u!.fullName : ownerName.text.trim();
        body['owner_phone'] = isOwner ? '' : ownerPhone.text.trim();
        final res = await ref.read(apiClientProvider).post('/listings', body: body);
        created = res is Map ? Map<String, dynamic>.from(res) : null;
      }
      ref.invalidate(listingsProvider);
      ref.invalidate(listingsRawProvider);
      if (!mounted) return;
      // An owner's new listing is a draft until a title deed is submitted + published;
      // take them straight to the listing so they can do that (it won't show in the
      // public browse yet, only under "My listings").
      if (!editing && created?['is_visible'] == false && created?['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saved as a draft — submit a title deed, then publish it to go live.')));
        context.go('/listings/${created!['id']}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(editing ? 'Listing updated' : 'Listing added')));
        context.go('/properties');
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = ref.watch(authControllerProvider).user;
    final isOwner = user?.activeRole == 'owner';
    final ownerFullName = user?.fullName ?? '';
    return Scaffold(
      appBar: NuzlAppBar(title: widget.editId != null ? 'Edit listing' : 'Add listing'),
      drawer: const NuzlDrawer(),
      body: ResponsiveCenter(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.x16),
          children: [
            // image picker
            GestureDetector(
              onTap: uploading ? null : _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppSpacing.rLg),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  image: imageBytes != null ? DecorationImage(image: MemoryImage(imageBytes!), fit: BoxFit.cover) : null,
                ),
                child: uploading
                    ? const Center(child: CircularProgressIndicator())
                    : imageBytes == null
                        ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.x8),
                            Text('Add photo', style: t.bodyMedium?.copyWith(color: AppColors.textMuted)),
                          ])
                        : Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: const CircleAvatar(backgroundColor: Colors.black54, child: Icon(Icons.edit, color: Colors.white, size: 18)),
                              onPressed: _pickImage,
                            )),
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
            DropdownButtonFormField<String>(
              initialValue: propertyType, decoration: const InputDecoration(labelText: 'Property type'),
              items: const ['apartment','villa','townhouse','office','retail','warehouse','land']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v[0].toUpperCase() + v.substring(1)))).toList(),
              onChanged: (v) => setState(() => propertyType = v ?? 'apartment'),
            ),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: purpose, decoration: const InputDecoration(labelText: 'Purpose'),
                items: const [DropdownMenuItem(value: 'sale', child: Text('Sale')), DropdownMenuItem(value: 'rent', child: Text('Rent'))],
                onChanged: (v) => setState(() => purpose = v ?? 'sale'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: furnishing, decoration: const InputDecoration(labelText: 'Furnishing'),
                items: const [
                  DropdownMenuItem(value: 'unfurnished', child: Text('Unfurnished')),
                  DropdownMenuItem(value: 'partly_furnished', child: Text('Partly furnished')),
                  DropdownMenuItem(value: 'furnished', child: Text('Furnished')),
                ],
                onChanged: (v) => setState(() => furnishing = v ?? 'unfurnished'))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price (AED)')),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: TextField(controller: beds, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bedrooms'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: baths, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bathrooms'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: size, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Size (sqft)'))),
            ]),
            if (widget.editId == null) ...[
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: unitNo, decoration: const InputDecoration(labelText: 'Unit number')),
              const SizedBox(height: AppSpacing.x12),
              if (isOwner)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppSpacing.rMd),
                  ),
                  child: Row(children: [
                    const Icon(Icons.person_outline, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.x8),
                    Expanded(
                      child: Text(
                        'Listed as owner: ${ownerFullName.isEmpty ? 'you' : ownerFullName}',
                        style: t.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ),
                  ]),
                )
              else
                Row(children: [
                  Expanded(child: TextField(controller: ownerName, decoration: const InputDecoration(labelText: 'Owner name'))),
                  const SizedBox(width: AppSpacing.x12),
                  Expanded(child: TextField(controller: ownerPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Owner phone'))),
                ]),
            ],
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: AppSpacing.x12),
            TextField(
              controller: permit,
              decoration: const InputDecoration(
                labelText: 'Permit number (Trakheesi / RERA)',
                helperText: 'Required to publish a live listing',
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
            Text('Amenities', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            ref.watch(amenitiesProvider).maybeWhen(
              data: (list) => list.isEmpty
                  ? Text('No amenities available', style: t.bodySmall?.copyWith(color: AppColors.textMuted))
                  : Wrap(
                      spacing: AppSpacing.x8,
                      runSpacing: AppSpacing.x8,
                      children: list.map((e) {
                        final m = Map<String, dynamic>.from(e);
                        final id = m['id'] is int ? m['id'] as int : int.tryParse('${m['id']}') ?? -1;
                        final label = '${m['label'] ?? m['code'] ?? ''}';
                        return FilterChip(
                          label: Text(label),
                          selected: selectedAmenities.contains(id),
                          onSelected: (v) => setState(() {
                            if (v) {
                              selectedAmenities.add(id);
                            } else {
                              selectedAmenities.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x12),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: AppSpacing.x16),
          ],
        ),
      ),
      // Pinned save bar — stays visible above the mobile bottom nav so the
      // primary action is never hidden behind it (and clears the home indicator).
      bottomNavigationBar: StickySaveBar(
        saving: saving,
        label: widget.editId != null ? 'Save changes' : 'Add listing',
        onPressed: _save,
      ),
    );
  }
}
