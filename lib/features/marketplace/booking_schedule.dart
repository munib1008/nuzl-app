import 'package:flutter/material.dart';

/// Prompts the customer for a preferred service date & time (date → time) so the
/// provider knows when to perform the job. Returns the combined [DateTime], or
/// null if the customer cancels either step (the booking should then abort).
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
