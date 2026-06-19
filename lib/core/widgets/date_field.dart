import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_spacing.dart';

/// A tappable field that opens a calendar date picker and writes `yyyy-MM-dd`
/// into [controller] — replaces manual "YYYY-MM-DD" typing across the platform.
class DateField extends StatefulWidget {
  const DateField({
    super.key,
    required this.controller,
    required this.label,
    this.firstDate,
    this.lastDate,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final VoidCallback? onChanged;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  Future<void> _pick() async {
    final now = DateTime.now();
    final initial = DateTime.tryParse(widget.controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: widget.firstDate ?? DateTime(now.year - 5),
      lastDate: widget.lastDate ?? DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() => widget.controller.text = DateFormat('yyyy-MM-dd').format(picked));
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    return InkWell(
      onTap: _pick,
      borderRadius: BorderRadius.circular(AppSpacing.rMd),
      child: InputDecorator(
        isEmpty: text.isEmpty,
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(text),
      ),
    );
  }
}
