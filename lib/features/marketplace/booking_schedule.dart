import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/app_spacing.dart';

/// Result of the booking sheet: the chosen slot + optional notes + property.
class BookingResult {
  BookingResult(this.when, this.note, {this.propertyId});
  final DateTime when;
  final String? note;
  final String? propertyId;
}

/// Simple date→time picker (no availability constraint). Used by the provider's
/// reschedule action, where the supplier may set any time by agreement.
Future<DateTime?> pickServiceSchedule(BuildContext context) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: now.add(const Duration(days: 365)),
    helpText: context.tr('Preferred service date'),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
    helpText: context.tr('Preferred start time'),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Customer booking sheet constrained to the provider's working days & hours
/// (from the service [item]: work_days "1,2,..", work_start/work_end "HH:mm",
/// slot_minutes). Returns the picked slot + notes, or null if cancelled.
Future<BookingResult?> pickServiceBooking(
  BuildContext context,
  Map<String, dynamic> item, {
  List<Map<String, dynamic>> properties = const [],
}) {
  return showModalBottomSheet<BookingResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookingSheet(item: item, properties: properties),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.item, this.properties = const []});
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> properties;
  @override
  State<_BookingSheet> createState() => _BookingSheetState();
}

class _BookingSheetState extends State<_BookingSheet> {
  late final Set<int> _days; // 1=Mon..7=Sun
  late final int _startMin;
  late final int _endMin;
  late final int _slot;
  final _note = TextEditingController();
  DateTime? _date;
  int? _slotMin;
  String? _propertyId;

  @override
  void initState() {
    super.initState();
    final parsed = '${widget.item['work_days'] ?? ''}'
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 7)
        .toSet();
    _days = parsed.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : parsed;
    _startMin = _parseMin('${widget.item['work_start'] ?? ''}') ?? 8 * 60;
    final end = _parseMin('${widget.item['work_end'] ?? ''}') ?? 20 * 60;
    _endMin = end > _startMin ? end : _startMin + 60;
    final s = int.tryParse('${widget.item['slot_minutes'] ?? ''}') ?? 60;
    _slot = s >= 15 ? s : 60;
    _date = _firstSelectable();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int? _parseMin(String hhmm) {
    final p = hhmm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  DateTime _firstSelectable() {
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);
    for (var i = 0; i < 14; i++) {
      if (_days.contains(d.weekday)) return d;
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  List<int> _slots() {
    final out = <int>[];
    for (var m = _startMin; m + _slot <= _endMin; m += _slot) {
      out.add(m);
    }
    return out;
  }

  bool _isPast(int m) {
    final d = _date;
    if (d == null) return false;
    return DateTime(d.year, d.month, d.day, m ~/ 60, m % 60).isBefore(DateTime.now());
  }

  String _fmtSlot(int m) {
    final t = TimeOfDay(hour: m ~/ 60, minute: m % 60);
    return t.format(context);
  }

  String _propLabel(Map<String, dynamic> p) {
    final label = '${p['label'] ?? ''}'.trim();
    if (label.isNotEmpty) return label;
    final community = '${p['community'] ?? ''}'.trim();
    final type = '${p['property_type'] ?? ''}'.trim();
    final joined = [type, community].where((s) => s.isNotEmpty).join(' · ');
    return joined.isEmpty ? context.tr('Property') : joined;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _firstSelectable(),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (d) => _days.contains(d.weekday),
      helpText: context.tr('Service date'),
    );
    if (picked != null) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
        _slotMin = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final muted = Theme.of(context).hintColor;
    final slots = _slots();
    final d = _date;
    final dateLabel = d == null
        ? context.tr('Pick a date')
        : '${context.tr(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1])} '
            '${d.day}/${d.month}/${d.year}';
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.x16,
        right: AppSpacing.x16,
        top: AppSpacing.x16,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.x16,
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('Book service'), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(dateLabel),
          ),
          const SizedBox(height: AppSpacing.x12),
          Text(context.tr('Available times'), style: t.bodySmall?.copyWith(color: muted)),
          const SizedBox(height: AppSpacing.x8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in slots)
                ChoiceChip(
                  label: Text(_fmtSlot(m)),
                  selected: _slotMin == m,
                  onSelected: _isPast(m) ? null : (_) => setState(() => _slotMin = m),
                ),
            ],
          ),
          if (slots.where((m) => !_isPast(m)).isEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text(context.tr('No slots left on this day — pick another date.'),
                style: t.bodySmall?.copyWith(color: muted)),
          ],
          if (widget.properties.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x12),
            DropdownButtonFormField<String?>(
              initialValue: _propertyId,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('For property (optional)')),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(context.tr('No specific property'))),
                for (final p in widget.properties)
                  DropdownMenuItem<String?>(
                    value: '${p['id']}',
                    child: Text(_propLabel(p), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _propertyId = v),
            ),
          ],
          const SizedBox(height: AppSpacing.x12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(labelText: context.tr('Notes for the provider (optional)')),
          ),
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_date != null && _slotMin != null)
                  ? () {
                      final dd = _date!;
                      final when = DateTime(dd.year, dd.month, dd.day, _slotMin! ~/ 60, _slotMin! % 60);
                      Navigator.pop(
                          context,
                          BookingResult(when, _note.text.trim().isEmpty ? null : _note.text.trim(),
                              propertyId: _propertyId));
                    }
                  : null,
              child: Text(context.tr('Confirm booking')),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
        ]),
      ),
    );
  }
}
