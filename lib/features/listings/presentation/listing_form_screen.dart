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
import '../../profile/presentation/profile_completion_banner.dart';
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
  final building = TextEditingController();
  final location = TextEditingController(); // a Google Maps link or "lat, lng"
  final originalPrice = TextEditingController();
  final developer = TextEditingController();
  final view = TextEditingController();
  final parking = TextEditingController();
  final serviceCharge = TextEditingController();
  DateTime? handover;
  final Set<int> selectedAmenities = {};

  final List<String> imageUrls = []; // uploaded photo URLs (first = cover)
  bool uploading = false;
  bool saving = false;
  bool aiBusy = false;
  bool isExclusive = false;
  bool isHotDeal = false;
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
      building.text = '${m['building_name'] ?? ''}';
      isExclusive = m['is_exclusive'] == true;
      isHotDeal = m['is_hot_deal'] == true;
      if (m['original_price'] != null) originalPrice.text = '${m['original_price']}';
      developer.text = '${m['developer'] ?? ''}';
      view.text = '${m['view'] ?? ''}';
      parking.text = m['parking'] != null ? '${m['parking']}' : '';
      serviceCharge.text = m['service_charge'] != null ? '${m['service_charge']}' : '';
      handover = DateTime.tryParse('${m['handover_date'] ?? ''}');
      final lat = m['latitude'], lng = m['longitude'];
      if (lat != null && lng != null) location.text = '$lat, $lng';
      final imgs = m['images'];
      if (imgs is List) {
        for (final e in imgs) {
          final s = '$e';
          if (s.isNotEmpty && !imageUrls.contains(s)) imageUrls.add(s);
        }
      }
      final cov = '${m['cover_image'] ?? ''}';
      if (cov.isNotEmpty && !imageUrls.contains(cov)) imageUrls.insert(0, cov);
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
    ownerName.dispose(); ownerPhone.dispose(); description.dispose(); permit.dispose();
    building.dispose(); location.dispose(); originalPrice.dispose();
    developer.dispose(); view.dispose(); parking.dispose(); serviceCharge.dispose();
    super.dispose();
  }

  /// Pick + upload one photo, appended to the gallery. Compressed (1280px/q60)
  /// so the base64 body stays well under Vercel's ~4.5MB request cap.
  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1280, imageQuality: 60);
    if (picked == null) return;
    setState(() => uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final url = await ref.read(uploadServiceProvider).upload(bytes, picked.name, 'image/jpeg');
      if (url == null) throw Exception('the server returned no URL');
      setState(() => imageUrls.add(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Photo not uploaded: $e')));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  /// Parse "lat, lng" or a Google Maps link (which contains @lat,lng) → coords.
  (double, double)? _coords() {
    final m = RegExp(r'(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)').firstMatch(location.text);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!), lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat, lng);
  }

  Widget _addPhotoTile(TextTheme t) => GestureDetector(
        onTap: uploading ? null : _addPhoto,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: uploading
              ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
              : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text('Add', style: t.bodySmall?.copyWith(color: AppColors.textMuted)),
                ]),
        ),
      );

  Widget _photoThumb(int index, String url) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
          child: Image.network(url,
              width: 96, height: 96, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  width: 96, height: 96, color: AppColors.surface2,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textSubtle))),
        ),
        Positioned(
          right: 2, top: 2,
          child: GestureDetector(
            onTap: () => setState(() => imageUrls.removeAt(index)),
            child: const CircleAvatar(
                radius: 11, backgroundColor: Colors.black54,
                child: Icon(Icons.close, size: 14, color: Colors.white)),
          ),
        ),
        if (index == 0)
          Positioned(
            left: 4, bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.rFull),
              ),
              child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
          ),
      ]);

  /// AI Deal Assistant — paste a WhatsApp-style blurb and pre-fill the form.
  Future<void> _aiFill() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-fill from a message'),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paste a WhatsApp-style property message — we’ll extract the details.',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: AppSpacing.x12),
            TextField(
              controller: ctrl, autofocus: true, maxLines: 5,
              decoration: const InputDecoration(
                  hintText: 'e.g. Burj Crown 2BR 1066 sqft Canal View AED 3.1M',
                  border: OutlineInputBorder()),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Extract')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || !mounted) return;
    setState(() => aiBusy = true);
    try {
      final res = await ref.read(apiClientProvider).post('/deal-assistant/parse', body: {'text': ctrl.text.trim()});
      final d = (res is Map && res['draft'] is Map) ? Map<String, dynamic>.from(res['draft']) : <String, dynamic>{};
      final src = res is Map ? '${res['source'] ?? ''}' : '';
      setState(() {
        if (d['building_name'] != null) building.text = '${d['building_name']}';
        if (d['unit_no'] != null) unitNo.text = '${d['unit_no']}';
        if (d['price'] is num) price.text = (d['price'] as num).toStringAsFixed(0);
        if (d['bedrooms'] != null) beds.text = '${d['bedrooms']}';
        if (d['bathrooms'] != null) baths.text = '${d['bathrooms']}';
        if (d['size_sqft'] is num) size.text = (d['size_sqft'] as num).toStringAsFixed(0);
        const types = ['apartment', 'villa', 'townhouse', 'office', 'retail', 'warehouse', 'land'];
        if (types.contains('${d['property_type']}')) propertyType = '${d['property_type']}';
        if (d['purpose'] == 'rent' || d['purpose'] == 'sale') purpose = '${d['purpose']}';
        // Fold view / community / status into the description if it's still empty.
        final extra = [
          if (d['view'] != null) '${d['view']}',
          if (d['community'] != null) '${d['community']}',
          if (d['status'] != null) 'Status: ${d['status']}',
        ].where((s) => s.isNotEmpty).join(' · ');
        if (extra.isNotEmpty && description.text.trim().isEmpty) description.text = extra;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(src == 'heuristic'
                ? 'Filled what we could — please review the fields.'
                : 'Filled from your message — review and adjust.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not parse: $e')));
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }

  Future<void> _save() async {
    final editing = widget.editId != null;
    final messenger = ScaffoldMessenger.of(context); // captured before any await
    // Profile-completion gate (#15): a complete profile is required to post a new listing.
    if (!editing) {
      final pc = await ref.read(profileCompletionProvider.future).catchError((_) => <String, dynamic>{'complete': true});
      if (pc['complete'] != true) {
        final missing = (pc['missing'] is List) ? (pc['missing'] as List).join(', ') : 'some fields';
        if (!mounted) return;
        setState(() => error = 'Complete your profile ($missing) before posting — see Profile.');
        return;
      }
    }
    // Validate all mandatory fields together and show a single, specific summary
    // (don't clear the form — entered data is preserved).
    final priceVal = double.tryParse(price.text.trim());
    final missing = <String>[
      if (building.text.trim().isEmpty) 'Building name',
      if (!editing && unitNo.text.trim().isEmpty) 'Unit number',
      if (priceVal == null || priceVal <= 0) 'A valid price',
    ];
    if (missing.isNotEmpty) {
      final msg = missing.length == 1
          ? '${missing.first} is required.'
          : 'Please complete: ${missing.join(', ')}.';
      setState(() => error = msg);
      // Surface it above the pinned save bar too, so it's seen wherever the user
      // is scrolled — without clearing any entered data.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    setState(() { saving = true; error = null; });
    final coords = _coords();
    final body = <String, dynamic>{
      'property_type': propertyType,
      'purpose': purpose,
      'furnishing': furnishing,
      'price': priceVal,
      'bedrooms': int.tryParse(beds.text),
      'bathrooms': int.tryParse(baths.text),
      'size_sqft': double.tryParse(size.text),
      'description': description.text.trim(),
      'building_name': building.text.trim(),
      'is_exclusive': isExclusive,
      'is_hot_deal': isHotDeal,
      if (originalPrice.text.trim().isNotEmpty) 'original_price': double.tryParse(originalPrice.text.trim()),
      if (developer.text.trim().isNotEmpty) 'developer': developer.text.trim(),
      if (view.text.trim().isNotEmpty) 'view': view.text.trim(),
      if (parking.text.trim().isNotEmpty) 'parking': int.tryParse(parking.text.trim()),
      if (serviceCharge.text.trim().isNotEmpty) 'service_charge': double.tryParse(serviceCharge.text.trim()),
      if (handover != null)
        'handover_date': '${handover!.year}-${handover!.month.toString().padLeft(2, '0')}-${handover!.day.toString().padLeft(2, '0')}',
      'amenities': selectedAmenities.toList(),
      if (permit.text.trim().isNotEmpty) 'permit_number': permit.text.trim(),
      if (coords != null) 'latitude': coords.$1,
      if (coords != null) 'longitude': coords.$2,
      if (imageUrls.isNotEmpty) 'cover_image': imageUrls.first,
      'images': imageUrls,
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
            // AI Deal Assistant — paste a message to auto-fill (create only).
            if (widget.editId == null) ...[
              Card(
                color: AppColors.primaryTint,
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome, color: AppColors.primary),
                  title: const Text('Auto-fill from a message'),
                  subtitle: const Text('Paste a WhatsApp deal — we extract the details'),
                  trailing: aiBusy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right),
                  onTap: aiBusy ? null : _aiFill,
                ),
              ),
              const SizedBox(height: AppSpacing.x16),
            ],
            // Photos — at least 3 to publish a live listing. First photo is the cover.
            Text('Photos', style: t.titleSmall),
            const SizedBox(height: 2),
            Text(
              '${imageUrls.length} added · at least 3 to publish',
              style: t.bodySmall?.copyWith(
                  color: imageUrls.length >= 3 ? AppColors.success : AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.x8),
            Wrap(
              spacing: AppSpacing.x8,
              runSpacing: AppSpacing.x8,
              children: [
                for (var i = 0; i < imageUrls.length; i++) _photoThumb(i, imageUrls[i]),
                _addPhotoTile(t),
              ],
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
            const SizedBox(height: AppSpacing.x12),
            TextField(
              controller: building,
              decoration: const InputDecoration(labelText: 'Building name *', hintText: 'e.g. Marina Heights, Tower B'),
            ),
            const SizedBox(height: AppSpacing.x12),
            TextField(
              controller: location,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Location pin',
                hintText: 'Paste a Google Maps link, or "25.0772, 55.1335"',
                prefixIcon: const Icon(Icons.place_outlined),
                helperText: _coords() != null
                    ? 'Pinned at ${_coords()!.$1.toStringAsFixed(5)}, ${_coords()!.$2.toStringAsFixed(5)}'
                    : 'Used for the map view',
                helperStyle: _coords() != null ? const TextStyle(color: AppColors.success) : null,
              ),
            ),
            if (widget.editId == null) ...[
              const SizedBox(height: AppSpacing.x12),
              TextField(controller: unitNo, decoration: const InputDecoration(labelText: 'Unit number *')),
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
            Text('Property details', style: t.titleSmall),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Expanded(child: TextField(controller: developer, decoration: const InputDecoration(labelText: 'Developer', hintText: 'e.g. Emaar'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: view, decoration: const InputDecoration(labelText: 'View', hintText: 'e.g. Marina'))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            Row(children: [
              Expanded(child: TextField(controller: parking, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Parking spaces'))),
              const SizedBox(width: AppSpacing.x12),
              Expanded(child: TextField(controller: serviceCharge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Service charge (AED/sqft/yr)'))),
            ]),
            const SizedBox(height: AppSpacing.x12),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final d = await showDatePicker(
                  context: context,
                  initialDate: handover ?? now,
                  firstDate: DateTime(now.year - 10),
                  lastDate: DateTime(now.year + 15),
                  helpText: 'Handover date',
                );
                if (d != null) setState(() => handover = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Handover date', suffixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(
                  handover == null
                      ? 'Select date (off-plan / ready)'
                      : '${handover!.year}-${handover!.month.toString().padLeft(2, '0')}-${handover!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(color: handover == null ? Theme.of(context).hintColor : null),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x16),
            Text('Highlights', style: t.titleSmall),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclusive listing'),
              value: isExclusive,
              onChanged: (v) => setState(() => isExclusive = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hot deal'),
              value: isHotDeal,
              onChanged: (v) => setState(() => isHotDeal = v),
            ),
            TextField(
              controller: originalPrice,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Original price (AED) — optional',
                helperText: 'If above the current price, shows a "Price reduced" ribbon',
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
