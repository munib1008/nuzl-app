import 'package:flutter/material.dart';
import '../../core/theme/app_spacing.dart';

/// Result of the booking sheet: the chosen slot + optional notes.
class BookingResult {
  BookingResult(this.when, this.note);
  final DateTime when;
  final String? note;
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
    helpText: 'Preferred service date',
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 9, minute: 0),
    helpText: 'Preferred start time',
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Customer booking sheet constrained to the provider's working days & hours
/// (from the service [item]: work_days "1,2,..", work_start/work_end "HH:mm",
/// slot_minutes). Returns the picked slot + notes, or null if cancelled.
Future<BookingResult?> pickServiceBooking(BuildContext context, Map<String, dynamic> item) {
  return showModalBottomSheet<BookingResult>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _BookingSheet(item: item),
  );
}

class _BookingSheet extends StatefulWidget {
  const _BookingSheet({required this.item});
  final Map<String, dynamic> item;
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? _firstSelectable(),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (d) => _days.contains(d.weekday),
      helpText: 'Service date',
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
        ? 'Pick a date'
        : '${const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]} '
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
          Text('Book service', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.x12),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(dateLabel),
          ),
          const SizedBox(height: AppSpacing.x12),
          Text('Available times', style: t.bodySmall?.copyWith(color: muted)),
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
            Text('No slots left on this day — pick another date.',
                style: t.bodySmall?.copyWith(color: muted)),
          ],
          const SizedBox(height: AppSpacing.x12),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes for the provider (optional)'),
          ),
          const SizedBox(height: AppSpacing.x16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_date != null && _slotMin != null)
                  ? () {
                      final dd = _date!;
                      final when = DateTime(dd.year, dd.month, dd.day, _slotMin! ~/ 60, _slotMin! % 60);
                      Navigator.pop(context, BookingResult(when, _note.text.trim().isEmpty ? null : _note.text.trim()));
                    }
                  : null,
              child: const Text('Confirm booking'),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
        ]),
      ),
    );
  }
}
