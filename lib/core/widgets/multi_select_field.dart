import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// A clean dropdown-style multi-select (replaces chip walls). Tapping opens a
/// bottom sheet of checkboxes; the field shows a compact summary of the picks.
class MultiSelectField extends StatelessWidget {
  const MultiSelectField({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icon,
    this.hint = 'Select…',
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final IconData? icon;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final summary = selected.isEmpty
        ? hint
        : (selected.length <= 2 ? selected.join(', ') : '${selected.length} selected');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.rSm),
        onTap: () async {
          final result = await showModalBottomSheet<Set<String>>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _MultiSelectSheet(label: label, options: options, initial: selected),
          );
          if (result != null) onChanged(result);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon) : null,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(summary,
              style: TextStyle(color: selected.isEmpty ? Theme.of(context).hintColor : null)),
        ),
      ),
    );
  }
}

class _MultiSelectSheet extends StatefulWidget {
  const _MultiSelectSheet({required this.label, required this.options, required this.initial});
  final String label;
  final List<String> options;
  final Set<String> initial;

  @override
  State<_MultiSelectSheet> createState() => _MultiSelectSheetState();
}

class _MultiSelectSheetState extends State<_MultiSelectSheet> {
  late final Set<String> _picked = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x16),
              child: Row(
                children: [
                  Expanded(child: Text(widget.label, style: Theme.of(context).textTheme.titleMedium)),
                  TextButton(
                    onPressed: () => Navigator.pop(context, _picked),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scroll,
                children: widget.options.map((o) {
                  final sel = _picked.contains(o);
                  return CheckboxListTile(
                    value: sel,
                    activeColor: AppColors.primary,
                    title: Text(o),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => v == true ? _picked.add(o) : _picked.remove(o)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
