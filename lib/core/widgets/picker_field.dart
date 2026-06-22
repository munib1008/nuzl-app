import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// A form-field-styled, tappable field that opens a searchable list to pick a
/// value. With [allowCustom] (default), the user can also enter a value not in
/// the list — so a curated option list never locks anyone out.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icon,
    this.enabled = true,
    this.allowCustom = true,
    this.hint,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;
  final IconData? icon;
  final bool enabled;
  final bool allowCustom;
  final String? hint;

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet(
        label: label,
        options: options,
        allowCustom: allowCustom,
        current: value,
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      borderRadius: BorderRadius.circular(AppSpacing.rMd),
      child: InputDecorator(
        isEmpty: value.isEmpty,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value.isEmpty ? (hint ?? '') : value,
          style: t.bodyMedium?.copyWith(
            color: value.isEmpty ? Theme.of(context).hintColor : null,
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({
    required this.label,
    required this.options,
    required this.allowCustom,
    required this.current,
  });
  final String label;
  final List<String> options;
  final bool allowCustom;
  final String current;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final media = MediaQuery.of(context);
    final q = _q.trim().toLowerCase();
    final filtered =
        q.isEmpty ? widget.options : widget.options.where((o) => o.toLowerCase().contains(q)).toList();
    final exact = widget.options.any((o) => o.toLowerCase() == q);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.x16, 0, AppSpacing.x16, AppSpacing.x8),
            child: Column(children: [
              Text('Select ${widget.label.toLowerCase()}', style: t.titleMedium),
              const SizedBox(height: AppSpacing.x8),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search…'),
                onChanged: (v) => setState(() => _q = v),
              ),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              if (widget.allowCustom && q.isNotEmpty && !exact)
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text('Use "${_q.trim()}"'),
                  onTap: () => Navigator.pop(context, _q.trim()),
                ),
              for (final o in filtered)
                ListTile(
                  title: Text(o),
                  trailing: o == widget.current
                      ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () => Navigator.pop(context, o),
                ),
              if (filtered.isEmpty && !(widget.allowCustom && q.isNotEmpty))
                const Padding(padding: EdgeInsets.all(AppSpacing.x24), child: Center(child: Text('No matches'))),
            ]),
          ),
        ]),
      ),
    );
  }
}
