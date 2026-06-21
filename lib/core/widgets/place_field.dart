import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A single place suggestion (label + optional coordinate).
class PlaceSuggestion {
  const PlaceSuggestion(this.label, this.lat, this.lng);
  final String label;
  final double? lat;
  final double? lng;
}

/// Type-ahead location field: as you type it queries a places service and shows
/// a dropdown of matches; picking one fills the text AND reports the lat/lng pin
/// via [onSelected]. Geocoding is isolated in [_search] so the source can be
/// swapped (e.g. to Google Places) without touching the UI. Today it uses the
/// keyless OpenStreetMap (Nominatim) geocoder, biased to the GCC.
class PlaceField extends StatefulWidget {
  const PlaceField({
    super.key,
    required this.controller,
    this.label = 'Location',
    this.hint = 'Search a building, community or address…',
    this.onSelected,
    this.onCleared,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final void Function(PlaceSuggestion place)? onSelected;
  final VoidCallback? onCleared;

  @override
  State<PlaceField> createState() => _PlaceFieldState();
}

class _PlaceFieldState extends State<PlaceField> {
  final _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)));
  Timer? _debounce;
  List<PlaceSuggestion> _results = const [];
  bool _loading = false;
  bool _picked = false; // suppress the dropdown right after a selection

  @override
  void dispose() {
    _debounce?.cancel();
    _dio.close(force: true);
    super.dispose();
  }

  void _onChanged(String v) {
    if (_picked) {
      _picked = false;
      return;
    }
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 3) {
      setState(() {
        _results = const [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(q));
  }

  Future<void> _search(String q) async {
    try {
      // Nominatim (OpenStreetMap) — keyless. Biased to the GCC; tweak/replace
      // here to switch geocoders (e.g. Google Places) without UI changes.
      final res = await _dio.get<dynamic>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': q,
          'format': 'jsonv2',
          'addressdetails': 0,
          'limit': 6,
          'countrycodes': 'ae,sa,qa,kw,bh,om',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = res.data;
      final list = <PlaceSuggestion>[];
      if (data is List) {
        for (final e in data) {
          if (e is Map) {
            final name = '${e['display_name'] ?? ''}'.trim();
            final lat = double.tryParse('${e['lat'] ?? ''}');
            final lng = double.tryParse('${e['lon'] ?? ''}');
            if (name.isNotEmpty) list.add(PlaceSuggestion(name, lat, lng));
          }
        }
      }
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = const [];
          _loading = false;
        });
      }
    }
  }

  void _pick(PlaceSuggestion p) {
    _picked = true;
    // Show a concise label in the field (first 1–2 segments), keep full as pin.
    final short = p.label.split(',').take(2).join(',').trim();
    widget.controller.text = short.isEmpty ? p.label : short;
    widget.onSelected?.call(p);
    setState(() {
      _results = const [];
      _loading = false;
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        controller: widget.controller,
        onChanged: _onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: const Icon(Icons.place_outlined, size: 20),
          suffixIcon: _loading
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
              : (widget.controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Clear',
                      onPressed: () {
                        widget.controller.clear();
                        widget.onCleared?.call();
                        setState(() => _results = const []);
                      },
                    )
                  : null),
        ),
      ),
      if (_results.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.rMd),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              for (final p in _results)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.location_on_outlined, size: 18, color: dark ? AppColors.dTextMuted : AppColors.textMuted),
                  title: Text(p.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                  onTap: () => _pick(p),
                ),
            ],
          ),
        ),
    ]);
  }
}
