import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Embedded location map (OpenStreetMap tiles — no API key) with a marker and an
/// "Open in Maps" link. Shows a compact "no location" panel when coordinates are
/// missing. Shared by the public + authenticated property detail pages.
class LocationMap extends StatelessWidget {
  const LocationMap({super.key, required this.lat, required this.lng, this.height = 220});
  final double? lat;
  final double? lng;
  final double height;

  Future<void> _openInMaps() async {
    if (lat == null || lng == null) return;
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    await launchUrl(uri, webOnlyWindowName: '_blank', mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (lat == null || lng == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppSpacing.rMd),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: const Center(
          child: Text('No location pinned', style: TextStyle(color: AppColors.textSubtle)),
        ),
      );
    }
    final point = LatLng(lat!, lng!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.rCard),
        child: SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: point,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag | InteractiveFlag.doubleTapZoom),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ae.nuzl.app',
              ),
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
      const SizedBox(height: AppSpacing.x8),
      OutlinedButton.icon(
        onPressed: _openInMaps,
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Open in Maps'),
      ),
    ]);
  }
}
