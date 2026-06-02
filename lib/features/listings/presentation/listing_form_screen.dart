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
import '../../shell/app_shell.dart';
import '../data/listings_repository.dart' show listingsProvider;

class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({super.key});
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

  Uint8List? imageBytes;
  String? imageName;
  String? coverUrl;
  bool uploading = false;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    price.dispose(); beds.dispose(); baths.dispose(); size.dispose(); unitNo.dispose();
    ownerName.dispose(); ownerPhone.dispose(); description.dispose(); super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() { imageBytes = bytes; imageName = picked.name; uploading = true; });
    final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
    setState(() { coverUrl = url; uploading = false; });
    if (url == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image upload not configured on the server — listing will save without a photo.')));
    }
  }

  Future<void> _save() async {
    setState(() { saving = true; error = null; });
    try {
      await ref.read(apiClientProvider).post('/listings', body: {
        'property_type': propertyType,
        'purpose': purpose,
        'furnishing': furnishing,
        'price': double.tryParse(price.text) ?? 0,
        'bedrooms': int.tryParse(beds.text),
        'bathrooms': int.tryParse(baths.text),
        'size_sqft': double.tryParse(size.text),
        'unit_no': unitNo.text.trim(),
        'owner_name': ownerName.text.trim(),
        'owner_phone': ownerPhone.text.trim(),
        'description': description.text.trim(),
        if (coverUrl != null) 'cover_image': coverUrl,
        if (coverUrl != null) 'images': [coverUrl],
      });
      ref.invalidate(listingsProvider);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing added'))); context.go('/properties'); }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const NuzlAppBar(title: 'Add listing'),
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
              value: propertyType, decoration: const InputDecoration(labelText: 'Property type'),
              items: const ['apartment','villa','townhouse','office','retail','warehouse','land']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v[0].toUpperCase() + v.substring(1)))).toList(),
              onChanged: (v) => setState(() => propertyType = v ?? 'apartment'),
            ),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: purpose, decoration: const InputDecoration(labelText: 'Purpose'),
                items: const [DropdownMenuItem(value: 'sale', child: Text('Sale')), DropdownMenuItem(value: 'rent', child: Text('Rent'))],
                onChanged: (v) => setState(() => purpose = v ?? 'sale'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: DropdownButtonFormField<String>(
                value: furnishing, decoration: const InputDecoration(labelText: 'Furnishing'),
                items: const [
                  DropdownMenuItem(value: 'unfurnished', child: Text('Unfurnished')),
                  DropdownMenuItem(value: 'semi_furnished', child: Text('Semi')),
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
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: unitNo, decoration: const InputDecoration(labelText: 'Unit number')),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: TextField(controller: ownerName, decoration: const InputDecoration(labelText: 'Owner name'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: ownerPhone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Owner phone'))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description')),
            if (error != null) Padding(
              padding: const EdgeInsets.only(top: AppSpacing.x12),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: AppSpacing.x20),
            FilledButton(
              onPressed: saving ? null : _save,
              child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add listing'),
            ),
            const SizedBox(height: AppSpacing.x24),
          ],
        ),
      ),
    );
  }
}
