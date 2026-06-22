import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Approximate centres for popular GCC communities/cities, so a listing without
/// an exact pin still shows a useful map (no API key needed). Keys are lower-case
/// and matched as substrings of the address, longest first.
const Map<String, LatLng> _communityCentroids = {
  'jumeirah village circle': LatLng(25.0568, 55.2090),
  'jumeirah beach residence': LatLng(25.0795, 55.1340),
  'jumeirah lake towers': LatLng(25.0693, 55.1440),
  'dubai hills estate': LatLng(25.1030, 55.2480),
  'dubai creek harbour': LatLng(25.2030, 55.3530),
  'dubai silicon oasis': LatLng(25.1210, 55.3780),
  'downtown dubai': LatLng(25.1972, 55.2744),
  'business bay': LatLng(25.1850, 55.2650),
  'palm jumeirah': LatLng(25.1124, 55.1390),
  'arabian ranches': LatLng(25.0520, 55.2680),
  'international city': LatLng(25.1640, 55.4090),
  'al reem island': LatLng(24.4980, 54.4060),
  'saadiyat island': LatLng(24.5430, 54.4340),
  'dubai marina': LatLng(25.0805, 55.1403),
  'damac hills': LatLng(25.0190, 55.2540),
  'town square': LatLng(24.9880, 55.2960),
  'the springs': LatLng(25.0660, 55.2010),
  'city walk': LatLng(25.2090, 55.2630),
  'yas island': LatLng(24.4980, 54.6050),
  'al barsha': LatLng(25.1130, 55.2000),
  'bur dubai': LatLng(25.2630, 55.2970),
  'mirdif': LatLng(25.2170, 55.4180),
  'deira': LatLng(25.2700, 55.3200),
  'jvc': LatLng(25.0568, 55.2090),
  'jbr': LatLng(25.0795, 55.1340),
  'jlt': LatLng(25.0693, 55.1440),
  'abu dhabi': LatLng(24.4539, 54.3773),
  'sharjah': LatLng(25.3463, 55.4209),
  'ajman': LatLng(25.4052, 55.5136),
  'dubai': LatLng(25.2048, 55.2708),
};

LatLng? _centroidFor(String? query) {
  final q = (query ?? '').toLowerCase();
  if (q.trim().isEmpty) return null;
  // Longest key first so "dubai marina" wins over "dubai".
  final keys = _communityCentroids.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final k in keys) {
    if (q.contains(k)) return _communityCentroids[k];
  }
  return null;
}

/// Embedded location map (OpenStreetMap tiles — no API key) with a marker and an
/// "Open in Google Maps" link. When no exact [lat]/[lng] is pinned, it centres on
/// the community parsed from [query] (shown as an approximate area) and still
/// offers a Google Maps search by address. Shared by the property detail pages.
class LocationMap extends StatelessWidget {
  const LocationMap({super.key, required this.lat, required this.lng, this.query, this.height = 220});
  final double? lat;
  final double? lng;

  /// Human address (building · community · city) used for the Google Maps search
  /// and to centre the map when there's no exact pin.
  final String? query;
  final double height;

  bool get _exact => lat != null && lng != null;

  Future<void> _openInMaps() async {
    final Uri uri;
    if (query != null && query!.trim().isNotEmpty) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query!.trim())}');
    } else if (_exact) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    } else {
      return;
    }
    await launchUrl(uri, webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final point = _exact ? LatLng(lat!, lng!) : _centroidFor(query);
    if (point == null) {
      // Nothing to centre on — but still let the user search the address if any.
      final hasQuery = query != null && query!.trim().isNotEmpty;
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Center(
          child: hasQuery
              ? OutlinedButton.icon(
                  onPressed: _openInMaps,
                  icon: const Icon(Icons.map_outlined, size: 16),
                  label: const Text('Open in Google Maps'),
                )
              : const Text('No location pinned', style: TextStyle(color: AppColors.textSubtle)),
        ),
      );
    }
    final approximate = !_exact;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        child: SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: approximate ? 12.5 : 14,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ae.nuzl.app',
              ),
              if (approximate)
                CircleLayer(circles: [
                  CircleMarker(
                    point: point,
                    radius: 600,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: .14),
                    borderColor: AppColors.primary.withValues(alpha: .5),
                    borderStrokeWidth: 1.5,
                  ),
                ])
              else
                MarkerLayer(markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_pin, size: 40, color: AppColors.primary),
                  ),
                ]),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
        ),
      ),
      if (approximate)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.x4),
          child: Text('Approximate — community area',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSubtle)),
        ),
      const SizedBox(height: AppSpacing.x8),
      OutlinedButton.icon(
        onPressed: _openInMaps,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open in Google Maps'),
      ),
    ]);
  }
}
