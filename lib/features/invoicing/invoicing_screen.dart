import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/network/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/status_badge.dart';
import '../crm/crm_scaffold.dart';
import 'invoicing_repository.dart';

String _money(num? v, [String cur = 'AED']) =>
    NumberFormat.currency(symbol: '$cur ', decimalDigits: 2).format(v ?? 0);

String _date(dynamic v) {
  final d = DateTime.tryParse('${v ?? ''}');
  return d != null ? DateFormat('d MMM yyyy').format(d) : '';
}

(BadgeTone, String) _statusMeta(String s) => switch (s) {
      'sent' => (BadgeTone.warning, 'Sent'),
      'accepted' => (BadgeTone.success, 'Accepted'),
      'paid' => (BadgeTone.success, 'Paid'),
      'cancelled' => (BadgeTone.danger, 'Cancelled'),
      _ => (BadgeTone.neutral, 'Draft'),
    };

String _typeLabel(String t) => t == 'invoice' ? 'Invoice' : 'Quotation';

/// Quotation & Invoice generator — create, track and export client documents.
class InvoicingScreen extends ConsumerStatefulWidget {
  const InvoicingScreen({super.key});
  @override
  ConsumerState<InvoicingScreen> createState() => _InvoicingScreenState();
}

class _InvoicingScreenState extends ConsumerState<InvoicingScreen> {
  String _filter = ''; // '' all · 'quote' · 'invoice'

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(invoicingListProvider(_filter));
    return CrmScaffold(
      tab: CrmTab.invoicing,
      title: 'Quotes & Invoices',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.x16, AppSpacing.x12, AppSpacing.x16, 0),
          child: Row(children: [
            for (final f in const [('', 'All'), ('quote', 'Quotations'), ('invoice', 'Invoices')])
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.x8),
                child: ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
              ),
          ]),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(invoicingListProvider(_filter)),
            child: AsyncView<List<Map<String, dynamic>>>(
              value: list,
              onRetry: () => ref.invalidate(invoicingListProvider(_filter)),
              data: (docs) => docs.isEmpty
                  ? ListView(children: const [
                      EmptyState(
                        icon: Icons.request_quote_outlined,
                        title: 'No documents yet',
                        message: 'Create a quotation or invoice for a client — add line items and export a PDF.',
                      ),
                    ])
                  : ListView(
                      padding: const EdgeInsets.all(AppSpacing.x16),
                      children: [for (final d in docs) _DocCard(d)],
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _DocCard extends ConsumerWidget {
  const _DocCard(this.d);
  final Map<String, dynamic> d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final type = '${d['doc_type'] ?? 'quote'}';
    final (tone, label) = _statusMeta('${d['status'] ?? 'draft'}');
    final cur = '${d['currency'] ?? 'AED'}';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: InkWell(
        onTap: () => showDocDetail(context, ref, d),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: type == 'invoice' ? AppColors.primaryTint : AppColors.accentGoldTint,
                  borderRadius: BorderRadius.circular(AppSpacing.rFull),
                ),
                child: Text(_typeLabel(type),
                    style: t.labelSmall?.copyWith(
                        color: type == 'invoice' ? AppColors.primary : AppColors.accentGold,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: AppSpacing.x8),
              Expanded(child: Text('${d['doc_no'] ?? ''}', style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis)),
              StatusBadge(label, tone: tone),
            ]),
            const SizedBox(height: AppSpacing.x8),
            Text('${d['client_name'] ?? '—'}', style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            if ('${d['subject'] ?? ''}'.isNotEmpty)
              Text('${d['subject']}', style: t.bodySmall?.copyWith(color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpacing.x8),
            Row(children: [
              Text(_money(num.tryParse('${d['total']}'), cur), style: t.titleMedium),
              const Spacer(),
              if (_date(d['issue_date']).isNotEmpty)
                Text(_date(d['issue_date']), style: t.bodySmall?.copyWith(color: muted)),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ── Detail sheet ────────────────────────────────────────────────────────────

void showDocDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DocDetailSheet(d),
  );
}

class _DocDetailSheet extends ConsumerStatefulWidget {
  const _DocDetailSheet(this.d);
  final Map<String, dynamic> d;
  @override
  ConsumerState<_DocDetailSheet> createState() => _DocDetailSheetState();
}

class _DocDetailSheetState extends ConsumerState<_DocDetailSheet> {
  late String _status = '${widget.d['status'] ?? 'draft'}'; // optimistic local status
  Map<String, dynamic> get d => widget.d;

  Future<void> _changeStatus(String s) async {
    final prev = _status;
    setState(() => _status = s); // flip the badge instantly
    try {
      await ref.read(invoicingRepoProvider).setStatus('${d['id']}', s);
      ref.invalidate(invoicingListProvider);
    } catch (e) {
      if (mounted) {
        setState(() => _status = prev);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.dTextMuted : AppColors.textMuted;
    final type = '${d['doc_type'] ?? 'quote'}';
    final cur = '${d['currency'] ?? 'AED'}';
    final items = (d['line_items'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final (tone, label) = _statusMeta(_status);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(AppSpacing.x20, 0, AppSpacing.x20, AppSpacing.x24),
        children: [
          Row(children: [
            Expanded(child: Text('${_typeLabel(type)} · ${d['doc_no'] ?? ''}', style: t.titleMedium)),
            StatusBadge(label, tone: tone),
          ]),
          const SizedBox(height: AppSpacing.x4),
          Text('${d['client_name'] ?? ''}', style: t.titleSmall),
          for (final s in [d['client_company'], d['client_email'], d['client_phone']])
            if ('${s ?? ''}'.isNotEmpty) Text('$s', style: t.bodySmall?.copyWith(color: muted)),
          if ('${d['subject'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x8),
            Text('${d['subject']}', style: t.bodyMedium),
          ],
          const Divider(height: AppSpacing.x24),
          // Line items
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${it['description'] ?? ''}', style: t.bodyMedium),
                    Text('${it['qty']} × ${_money(num.tryParse('${it['unit_price']}'), cur)}',
                        style: t.bodySmall?.copyWith(color: muted)),
                  ]),
                ),
                Text(_money(num.tryParse('${it['amount']}'), cur), style: t.bodyMedium),
              ]),
            ),
          const Divider(height: AppSpacing.x24),
          _totalRow(context, 'Subtotal', _money(num.tryParse('${d['subtotal']}'), cur)),
          if ((num.tryParse('${d['discount']}') ?? 0) > 0)
            _totalRow(context, 'Discount', '- ${_money(num.tryParse('${d['discount']}'), cur)}'),
          _totalRow(context, 'VAT (${d['vat_rate']}%)', _money(num.tryParse('${d['vat_amount']}'), cur)),
          _totalRow(context, 'Total', _money(num.tryParse('${d['total']}'), cur), bold: true),
          if ('${d['notes'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x16),
            Text('Notes', style: t.labelLarge),
            Text('${d['notes']}', style: t.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.x20),
          // Actions
          Wrap(spacing: AppSpacing.x8, runSpacing: AppSpacing.x8, children: [
            FilledButton.icon(
              onPressed: () => exportInvoicePdf(context, d),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: const Text('Export PDF'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openForm(context, ref, existing: d);
              },
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            if (type == 'quote')
              OutlinedButton.icon(
                onPressed: () => _convert(context, ref, '${d['id']}'),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Convert to invoice'),
              ),
          ]),
          const SizedBox(height: AppSpacing.x12),
          Text('Set status', style: t.labelLarge),
          const SizedBox(height: AppSpacing.x8),
          Wrap(spacing: AppSpacing.x8, children: [
            for (final s in const ['draft', 'sent', 'accepted', 'paid', 'cancelled'])
              ActionChip(
                label: Text(_statusMeta(s).$2),
                onPressed: _status == s ? null : () => _changeStatus(s),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _totalRow(BuildContext context, String label, String value, {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    final style = bold ? t.titleMedium : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }
}

Future<void> _convert(BuildContext context, WidgetRef ref, String id) async {
  try {
    await ref.read(invoicingRepoProvider).convert(id);
    ref.invalidate(invoicingListProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice created from quotation')));
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
  }
}

// ── Create / edit form ───────────────────────────────────────────────────────

void _openForm(BuildContext context, WidgetRef ref, {Map<String, dynamic>? existing}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => _DocFormPage(existing: existing),
    fullscreenDialog: true,
  ));
}

class _LineCtl {
  _LineCtl({String description = '', String qty = '1', String unitPrice = ''})
      : description = TextEditingController(text: description),
        qty = TextEditingController(text: qty),
        unitPrice = TextEditingController(text: unitPrice);
  final TextEditingController description;
  final TextEditingController qty;
  final TextEditingController unitPrice;
  void dispose() {
    description.dispose();
    qty.dispose();
    unitPrice.dispose();
  }
}

class _DocFormPage extends ConsumerStatefulWidget {
  const _DocFormPage({this.existing});
  final Map<String, dynamic>? existing;
  @override
  ConsumerState<_DocFormPage> createState() => _DocFormPageState();
}

class _DocFormPageState extends ConsumerState<_DocFormPage> {
  late String _type;
  final _client = TextEditingController();
  final _company = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _notes = TextEditingController();
  final _vat = TextEditingController(text: '5');
  final _discount = TextEditingController(text: '0');
  final _currency = TextEditingController(text: 'AED');
  DateTime? _dueDate;
  final List<_LineCtl> _lines = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = '${e?['doc_type'] ?? 'quote'}';
    if (e != null) {
      _client.text = '${e['client_name'] ?? ''}';
      _company.text = '${e['client_company'] ?? ''}';
      _email.text = '${e['client_email'] ?? ''}';
      _phone.text = '${e['client_phone'] ?? ''}';
      _subject.text = '${e['subject'] ?? ''}';
      _notes.text = '${e['notes'] ?? ''}';
      _vat.text = '${e['vat_rate'] ?? 5}';
      _discount.text = '${e['discount'] ?? 0}';
      _currency.text = '${e['currency'] ?? 'AED'}';
      _dueDate = DateTime.tryParse('${e['due_date'] ?? ''}');
      for (final it in (e['line_items'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(it as Map);
        _lines.add(_LineCtl(description: '${m['description'] ?? ''}', qty: '${m['qty'] ?? 1}', unitPrice: '${m['unit_price'] ?? ''}'));
      }
    }
    if (_lines.isEmpty) _lines.add(_LineCtl());
  }

  @override
  void dispose() {
    for (final c in [_client, _company, _email, _phone, _subject, _notes, _vat, _discount, _currency]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _subtotal {
    var s = 0.0;
    for (final l in _lines) {
      s += (double.tryParse(l.qty.text.trim()) ?? 0) * (double.tryParse(l.unitPrice.text.trim()) ?? 0);
    }
    return s;
  }

  double get _vatAmount {
    final disc = (double.tryParse(_discount.text.trim()) ?? 0).clamp(0, _subtotal);
    return (_subtotal - disc) * (double.tryParse(_vat.text.trim()) ?? 0) / 100;
  }

  double get _total {
    final disc = (double.tryParse(_discount.text.trim()) ?? 0).clamp(0, _subtotal);
    return _subtotal - disc + _vatAmount;
  }

  Future<void> _save() async {
    if (_client.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a client name')));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'doc_type': _type,
      'client_name': _client.text.trim(),
      'client_company': _company.text.trim(),
      'client_email': _email.text.trim(),
      'client_phone': _phone.text.trim(),
      'subject': _subject.text.trim(),
      'notes': _notes.text.trim(),
      'currency': _currency.text.trim().isEmpty ? 'AED' : _currency.text.trim(),
      'vat_rate': double.tryParse(_vat.text.trim()) ?? 5,
      'discount': double.tryParse(_discount.text.trim()) ?? 0,
      'due_date': _dueDate?.toIso8601String(),
      'line_items': [
        for (final l in _lines)
          if (l.description.text.trim().isNotEmpty || (double.tryParse(l.unitPrice.text.trim()) ?? 0) != 0)
            {
              'description': l.description.text.trim(),
              'qty': double.tryParse(l.qty.text.trim()) ?? 1,
              'unit_price': double.tryParse(l.unitPrice.text.trim()) ?? 0,
            },
      ],
    };
    try {
      final repo = ref.read(invoicingRepoProvider);
      if (widget.existing != null) {
        await repo.update('${widget.existing!['id']}', body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(invoicingListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cur = _currency.text.trim().isEmpty ? 'AED' : _currency.text.trim();
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing != null ? 'Edit document' : 'New document')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.x16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'quote', label: Text('Quotation'), icon: Icon(Icons.description_outlined)),
              ButtonSegment(value: 'invoice', label: Text('Invoice'), icon: Icon(Icons.receipt_long_outlined)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: AppSpacing.x16),
          Text('Client', style: t.titleSmall),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _client, decoration: const InputDecoration(labelText: 'Client name *')),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _company, decoration: const InputDecoration(labelText: 'Company')),
          const SizedBox(height: AppSpacing.x8),
          Row(children: [
            Expanded(child: TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone'))),
          ]),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject / reference')),
          const SizedBox(height: AppSpacing.x20),
          Row(children: [
            Text('Line items', style: t.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: () => setState(() => _lines.add(_LineCtl())),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add'),
            ),
          ]),
          const SizedBox(height: AppSpacing.x4),
          for (int i = 0; i < _lines.length; i++) _lineEditor(i),
          const SizedBox(height: AppSpacing.x16),
          Row(children: [
            Expanded(child: TextField(controller: _discount, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: 'Discount ($cur)'))),
            const SizedBox(width: AppSpacing.x8),
            Expanded(child: TextField(controller: _vat, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'VAT %'))),
            const SizedBox(width: AppSpacing.x8),
            SizedBox(width: 90, child: TextField(controller: _currency, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Currency'))),
          ]),
          const SizedBox(height: AppSpacing.x12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(_dueDate == null ? 'No due date' : 'Due ${DateFormat.yMMMd().format(_dueDate!)}'),
            trailing: TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dueDate ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
              child: const Text('Pick date'),
            ),
          ),
          const SizedBox(height: AppSpacing.x8),
          TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes / terms')),
          const Divider(height: AppSpacing.x32),
          _totRow('Subtotal', _money(_subtotal, cur)),
          _totRow('VAT (${_vat.text.trim().isEmpty ? '0' : _vat.text.trim()}%)', _money(_vatAmount, cur)),
          _totRow('Total', _money(_total, cur), bold: true),
          const SizedBox(height: AppSpacing.x20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing != null ? 'Save changes' : 'Create ${_typeLabel(_type).toLowerCase()}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineEditor(int i) {
    final l = _lines[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          flex: 5,
          child: TextField(controller: l.description, decoration: const InputDecoration(labelText: 'Description', isDense: true)),
        ),
        const SizedBox(width: AppSpacing.x8),
        Expanded(
          flex: 2,
          child: TextField(controller: l.qty, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Qty', isDense: true)),
        ),
        const SizedBox(width: AppSpacing.x8),
        Expanded(
          flex: 3,
          child: TextField(controller: l.unitPrice, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Unit', isDense: true)),
        ),
        IconButton(
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Remove',
          onPressed: _lines.length == 1
              ? null
              : () => setState(() {
                    _lines.removeAt(i).dispose();
                  }),
        ),
      ]),
    );
  }

  Widget _totRow(String label, String value, {bool bold = false}) {
    final t = Theme.of(context).textTheme;
    final style = bold ? t.titleMedium : t.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: style),
        Text(value, style: style),
      ]),
    );
  }
}

// ── PDF export ────────────────────────────────────────────────────────────────

Future<void> exportInvoicePdf(BuildContext context, Map<String, dynamic> d) async {
  final cur = '${d['currency'] ?? 'AED'}';
  final type = '${d['doc_type'] ?? 'quote'}';
  final items = (d['line_items'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  pw.Widget tot(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );
  final pdf = pw.Document();
  pdf.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    build: (ctx) => [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('NUZL', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold)),
          pw.Text(_typeLabel(type).toUpperCase(), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('${d['doc_no'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          if (_date(d['issue_date']).isNotEmpty) pw.Text('Issued: ${_date(d['issue_date'])}'),
          if (_date(d['due_date']).isNotEmpty) pw.Text('Due: ${_date(d['due_date'])}'),
          pw.Text('Status: ${_statusMeta('${d['status'] ?? 'draft'}').$2}'),
        ]),
      ]),
      pw.SizedBox(height: 20),
      pw.Text('Bill to', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.Text('${d['client_name'] ?? ''}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13)),
      for (final s in [d['client_company'], d['client_email'], d['client_phone']])
        if ('${s ?? ''}'.isNotEmpty) pw.Text('$s'),
      if ('${d['subject'] ?? ''}'.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        pw.Text('Subject: ${d['subject']}'),
      ],
      pw.SizedBox(height: 18),
      pw.TableHelper.fromTextArray(
        headers: const ['Description', 'Qty', 'Unit price', 'Amount'],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
        data: items
            .map((it) => [
                  '${it['description'] ?? ''}',
                  '${it['qty'] ?? ''}',
                  _money(num.tryParse('${it['unit_price']}'), cur),
                  _money(num.tryParse('${it['amount']}'), cur),
                ])
            .toList(),
      ),
      pw.SizedBox(height: 12),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.SizedBox(
          width: 240,
          child: pw.Column(children: [
            tot('Subtotal', _money(num.tryParse('${d['subtotal']}'), cur)),
            if ((num.tryParse('${d['discount']}') ?? 0) > 0)
              tot('Discount', '- ${_money(num.tryParse('${d['discount']}'), cur)}'),
            tot('VAT (${d['vat_rate']}%)', _money(num.tryParse('${d['vat_amount']}'), cur)),
            pw.Divider(),
            tot('Total', _money(num.tryParse('${d['total']}'), cur), bold: true),
          ]),
        ),
      ),
      if ('${d['notes'] ?? ''}'.isNotEmpty) ...[
        pw.SizedBox(height: 18),
        pw.Text('Notes', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text('${d['notes']}'),
      ],
    ],
  ));
  try {
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
  }
}
