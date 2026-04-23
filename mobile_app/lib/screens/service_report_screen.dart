import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Mirrors the web portal's CSR form exactly (same sections, same fields).
class ServiceReportScreen extends StatefulWidget {
  final StatusRecord? record;
  const ServiceReportScreen({super.key, this.record});
  @override
  State<ServiceReportScreen> createState() => _ServiceReportScreenState();
}

class _ServiceReportScreenState extends State<ServiceReportScreen> {
  // Header
  final _csrNo = TextEditingController();
  final _callBy = TextEditingController();

  // Customer info
  final _custName = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();

  // Instruction & Engineer
  final _instrFrom = TextEditingController();
  final _inspectedBy = TextEditingController();

  // Work details
  final _nature = TextEditingController();
  final _details = TextEditingController();
  final _location = TextEditingController();
  final _defects = TextEditingController();
  final _remarks = TextEditingController();

  // Timing
  final _eventTime = TextEditingController();
  final _startTime = TextEditingController();
  final _endTime = TextEditingController();

  // Customer feedback
  final _fbRemarks = TextEditingController();
  final _fbName = TextEditingController();
  final _fbDesignation = TextEditingController();
  final _fbPhone = TextEditingController();
  final _fbEmail = TextEditingController();
  final _fbDate = TextEditingController();

  DateTime _date = DateTime.now();
  DateTime _eventDate = DateTime.now();
  String _satisfaction = 'Satisfied';
  String _statusAfter = 'Resolved';
  bool _saving = false;
  bool _printing = false;
  bool _refreshing = false;

  final _custSig =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);
  final _engSig =
      SignatureController(penStrokeWidth: 2, penColor: Colors.black);

  // Signatures already on file (loaded via refresh).
  Uint8List? _savedCustSigBytes;
  Uint8List? _savedEngSigBytes;
  String _savedCustSigDataUrl = '';
  String _savedEngSigDataUrl = '';

  @override
  void initState() {
    super.initState();
    final r = widget.record;
    if (r != null) {
      _prefillFromRecord(r);
      final d = parseISO(r.date);
      if (d != null) {
        _date = d;
        _eventDate = d;
      }
      // Fire a background refresh so the form picks up any work done / customer
      // fields that may have been added after the row was first created.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
    }
  }

  void _prefillFromRecord(StatusRecord r) {
    _nature.text = r.workType;
    _details.text = r.scopeOfWork;
    _remarks.text = r.workRemarks.isNotEmpty ? r.workRemarks : r.workDone;
    _instrFrom.text = r.instructionFrom;
    _inspectedBy.text = r.inspectedBy;
    _custName.text = r.customerName;
    _fbName.text = r.customerName;
    _fbDesignation.text = r.designation;
    _fbPhone.text = r.phone;
    _fbEmail.text = r.email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Service Report'),
        actions: [
          IconButton(
            tooltip: 'Load existing data',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh),
            onPressed: _refreshing ? null : _loadExisting,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // --- Header Info ---
          sectionHeader('Header info'),
          _t(_csrNo, 'CSR No.', placeholder: 'e.g. FGCS-20250105'),
          _dateField('Date', _date, (d) => setState(() => _date = d)),
          const SizedBox(height: 10),
          _t(_callBy, 'Status of Call By', placeholder: 'e.g. Sahana'),

          // --- Customer Info ---
          sectionHeader('Customer info'),
          _t(_custName, 'Site Name',
              placeholder: 'Auto-filled from assigned site'),
          _t(_address, 'Address', placeholder: 'Street address'),
          Row(children: [
            Expanded(child: _t(_city, 'City')),
            const SizedBox(width: 8),
            Expanded(child: _t(_state, 'State')),
            const SizedBox(width: 8),
            Expanded(child: _t(_zip, 'ZIP')),
          ]),

          // --- Instruction & Engineer ---
          sectionHeader('Instruction & Engineer'),
          _t(_instrFrom, 'Instruction From', placeholder: 'e.g. Mr. Madhukiran'),
          _t(_inspectedBy, 'Inspected By', placeholder: 'Engineer name'),

          // --- Work Details ---
          sectionHeader('Work details'),
          _t(_nature, 'Nature of Work',
              maxLines: 2,
              placeholder: 'Describe the nature of work…'),
          _t(_details, 'Work Details',
              maxLines: 3,
              placeholder: 'Detailed description of work done…'),
          Row(children: [
            Expanded(
              child: _t(_location, 'Location of Service',
                  placeholder: 'e.g. Electronics City'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _statusAfter,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Status after Work'),
                items: const [
                  DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                  DropdownMenuItem(value: 'Pending', child: Text('Pending')),
                  DropdownMenuItem(
                      value: 'Requires Follow-up',
                      child: Text('Requires Follow-up')),
                ],
                onChanged: (v) =>
                    setState(() => _statusAfter = v ?? _statusAfter),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          _t(_defects, 'Defects Found on Inspection',
              maxLines: 2,
              placeholder: 'Describe any defects found…'),
          _t(_remarks, "Engineer's Remarks",
              maxLines: 2, placeholder: "Engineer's remarks…"),

          // --- Timing ---
          sectionHeader('Timing'),
          _dateField('Event Date', _eventDate,
              (d) => setState(() => _eventDate = d)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _t(_eventTime, 'Event Time')),
            const SizedBox(width: 8),
            Expanded(child: _t(_startTime, 'Start of Work')),
            const SizedBox(width: 8),
            Expanded(child: _t(_endTime, 'End of Service')),
          ]),

          // --- Customer Satisfaction ---
          sectionHeader('Customer satisfaction'),
          ...const [
            'Extremely Satisfied',
            'Satisfied',
            'Dissatisfied',
            'Annoyed',
          ].map(
            (opt) => RadioListTile<String>(
              value: opt,
              groupValue: _satisfaction,
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(opt),
              onChanged: (v) => setState(() => _satisfaction = v ?? opt),
            ),
          ),

          // --- Customer Feedback ---
          sectionHeader('Customer feedback'),
          _t(_fbRemarks, 'Remarks',
              maxLines: 2, placeholder: 'Customer remarks…'),
          _t(_fbName, 'Customer Name', placeholder: 'Name'),
          _t(_fbDesignation, 'Designation', placeholder: 'Designation'),
          Row(children: [
            Expanded(
              child: _t(_fbPhone, 'Phone / Fax',
                  keyboardType: TextInputType.phone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _t(_fbEmail, 'Email',
                  keyboardType: TextInputType.emailAddress),
            ),
          ]),
          _t(_fbDate, 'Date', placeholder: 'dd-mm-yyyy'),

          // --- Signatures ---
          sectionHeader('Signatures'),
          _sigSlot(
            label: 'Customer Signature',
            controller: _custSig,
            savedBytes: _savedCustSigBytes,
            onRedraw: () => setState(() {
              _savedCustSigBytes = null;
              _savedCustSigDataUrl = '';
              _custSig.clear();
            }),
          ),
          const SizedBox(height: 10),
          _sigSlot(
            label: 'Engineer Signature',
            controller: _engSig,
            savedBytes: _savedEngSigBytes,
            onRedraw: () => setState(() {
              _savedEngSigBytes = null;
              _savedEngSigDataUrl = '';
              _engSig.clear();
            }),
          ),

          // --- Actions ---
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving || _printing ? null : _clearAll,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveOnly,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _printing ? null : _printOnly,
                icon: const Icon(Icons.print_outlined),
                label: Text(_printing ? 'Opening…' : 'Print'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary2),
              ),
            ),
          ]),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ---------- widgets ----------

  Widget _t(TextEditingController c, String label,
      {int maxLines = 1,
      TextInputType? keyboardType,
      String? placeholder}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _dateField(String label, DateTime d, ValueChanged<DateTime> set) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: d,
          firstDate: DateTime(2024),
          lastDate: DateTime(2100),
        );
        if (picked != null) set(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          const Icon(Icons.calendar_today, size: 18, color: AppColors.sub),
          const SizedBox(width: 10),
          Expanded(child: Text('$label:  ${fmtDatePretty(d)}')),
        ]),
      ),
    );
  }

  Widget _sigSlot({
    required String label,
    required SignatureController controller,
    required Uint8List? savedBytes,
    required VoidCallback onRedraw,
  }) {
    final hasSaved = savedBytes != null && savedBytes.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          if (hasSaved)
            const Text('On file',
                style: TextStyle(
                    color: AppColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFDDDDDD)),
            borderRadius: BorderRadius.circular(10),
          ),
          height: 140,
          child: hasSaved
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Image.memory(savedBytes, fit: BoxFit.contain),
                )
              : Signature(
                  controller: controller,
                  backgroundColor: Colors.white,
                ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: Icon(hasSaved ? Icons.edit_outlined : Icons.clear),
            label: Text(hasSaved ? 'Redraw' : 'Clear'),
            onPressed: hasSaved ? onRedraw : controller.clear,
          ),
        ),
      ],
    );
  }

  // ---------- actions ----------

  void _clearAll() {
    for (final c in [
      _csrNo, _callBy,
      _custName, _address, _city, _state, _zip,
      _instrFrom, _inspectedBy,
      _nature, _details, _location, _defects, _remarks,
      _eventTime, _startTime, _endTime,
      _fbRemarks, _fbName, _fbDesignation, _fbPhone, _fbEmail, _fbDate,
    ]) {
      c.clear();
    }
    _custSig.clear();
    _engSig.clear();
    setState(() {
      _date = DateTime.now();
      _eventDate = DateTime.now();
      _satisfaction = 'Satisfied';
      _statusAfter = 'Resolved';
      _savedCustSigBytes = null;
      _savedEngSigBytes = null;
      _savedCustSigDataUrl = '';
      _savedEngSigDataUrl = '';
    });
  }

  Future<String> _sigDataUrl(SignatureController c) async {
    final bytes = await c.toPngBytes();
    if (bytes == null) return '';
    return 'data:image/png;base64,${base64Encode(bytes)}';
  }

  Future<void> _saveOnly() async {
    setState(() => _saving = true);
    try {
      final user = context.read<AuthService>().user!;
      final empId = widget.record?.empId ?? user.username;
      final empName = widget.record?.empName ?? user.displayName;
      final date = fmtDateISO(_date);

      await ApiService.instance.saveServiceReport({
        'empId': empId,
        'empName': empName,
        'date': date,
        'siteName': widget.record?.siteName ?? '',
        'instructionFrom': _instrFrom.text.trim(),
        'inspectedBy': _inspectedBy.text.trim(),
        'customerName': _custName.text.trim(),
        'designation': _fbDesignation.text.trim(),
        'phone': _fbPhone.text.trim(),
        'email': _fbEmail.text.trim(),
        'workDone': _details.text.trim(),
        'completionPct': '100',
        'remarks': _remarks.text.trim(),
      });

      await ApiService.instance.updateWorkDone(
        empId: empId,
        date: date,
        workDone: _details.text.trim(),
        completionPct: '100',
        workRemarks: _remarks.text.trim(),
        instructionFrom: _instrFrom.text.trim(),
        inspectedBy: _inspectedBy.text.trim(),
        customerName: _custName.text.trim(),
        designation: _fbDesignation.text.trim(),
        phone: _fbPhone.text.trim(),
        email: _fbEmail.text.trim(),
      );

      // Prefer freshly drawn signatures; otherwise preserve what's on file.
      final drawnCust = await _sigDataUrl(_custSig);
      final drawnEng = await _sigDataUrl(_engSig);
      final custSig =
          drawnCust.isNotEmpty ? drawnCust : _savedCustSigDataUrl;
      final engSig =
          drawnEng.isNotEmpty ? drawnEng : _savedEngSigDataUrl;

      if (custSig.isNotEmpty || engSig.isNotEmpty) {
        await ApiService.instance.saveReportSignatures(
          empId: empId,
          date: date,
          custSig: custSig,
          engSig: engSig,
        );
      }

      if (!mounted) return;
      showToast(context, 'Saved');
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printOnly() async {
    setState(() => _printing = true);
    try {
      await _printPdf();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Print failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _loadExisting() async {
    if (mounted) setState(() => _refreshing = true);
    try {
      final user = context.read<AuthService>().user!;
      final empId = widget.record?.empId ?? user.username;
      final empName = widget.record?.empName ?? user.displayName;
      final date = fmtDateISO(_date);

      final rows = await ApiService.instance.getStatus(date: date);
      StatusRecord? match;
      for (final r in rows) {
        if (r.empId.isNotEmpty &&
            r.empId.toLowerCase().trim() == empId.toLowerCase().trim()) {
          match = r;
          break;
        }
      }
      match ??= rows.firstWhere(
        (r) =>
            r.empName.toLowerCase().trim() ==
            empName.toLowerCase().trim(),
        orElse: () => StatusRecord(
          empId: '',
          empName: '',
          role: '',
          siteName: '',
          workType: '',
          scopeOfWork: '',
          status: '',
          date: '',
        ),
      );

      if (match.empId.isEmpty && match.empName.isEmpty) {
        if (!mounted) return;
        showToast(context, 'No record for $date', error: true);
        return;
      }

      _prefillFromRecord(match);

      // Auto-fill Customer Info from the Sites sheet if we have a site name
      // and the form is still empty in those slots.
      await _prefillFromSite(match.siteName);

      // Signatures — pull existing PNGs and render them.
      bool hasSigs = false;
      try {
        final sigs = await ApiService.instance
            .getReportSignatures(empId: match.empId, date: date);
        final cust = (sigs['custSig'] ?? '').toString();
        final eng = (sigs['engSig'] ?? '').toString();
        final custBytes = _decodeSig(cust);
        final engBytes = _decodeSig(eng);
        _savedCustSigBytes = custBytes;
        _savedEngSigBytes = engBytes;
        _savedCustSigDataUrl = cust;
        _savedEngSigDataUrl = eng;
        hasSigs = custBytes != null || engBytes != null;
      } catch (_) {/* sigs optional */}

      if (!mounted) return;
      setState(() {});
      showToast(context,
          hasSigs ? 'Record + signatures loaded' : 'Record loaded');
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Uint8List? _decodeSig(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      final payload = s.contains(',') ? s.split(',').last : s;
      final cleaned = payload.replaceAll(RegExp(r'\s'), '');
      if (cleaned.isEmpty) return null;
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  Future<void> _prefillFromSite(String siteName) async {
    if (siteName.trim().isEmpty) return;
    try {
      final sites = await ApiService.instance.getSites();
      final needle = siteName.toLowerCase().trim();
      Site? match;
      for (final s in sites) {
        if (s.name.toLowerCase().trim() == needle) {
          match = s;
          break;
        }
      }
      if (match == null) return;
      // Customer Name always reflects the assigned site's name.
      if (match.name.trim().isNotEmpty) _custName.text = match.name;
      _fillIfEmpty(_address, match.address);
      _fillIfEmpty(_city, match.city);
      _fillIfEmpty(_state, match.state);
      _fillIfEmpty(_zip, match.zipCode);
      _fillIfEmpty(_fbName, match.contactName);
      _fillIfEmpty(_fbPhone, match.contactPhone);
      _fillIfEmpty(_fbEmail, match.contactEmail);
    } catch (_) {/* best-effort */}
  }

  void _fillIfEmpty(TextEditingController c, String value) {
    if (c.text.trim().isEmpty && value.trim().isNotEmpty) c.text = value;
  }

  Future<void> _printPdf() async {
    final doc = pw.Document();
    final drawnCustBytes = await _custSig.toPngBytes();
    final drawnEngBytes = await _engSig.toPngBytes();
    final custBytes = drawnCustBytes ?? _savedCustSigBytes;
    final engBytes = drawnEngBytes ?? _savedEngSigBytes;

    // Logo
    pw.MemoryImage? logo;
    try {
      final b = await rootBundle.load('assets/images/fluxgen-logo.png');
      logo = pw.MemoryImage(b.buffer.asUint8List());
    } catch (_) {/* logo optional */}

    const muted = PdfColor.fromInt(0xFF8D96A3);
    const line = PdfColor.fromInt(0xFFC9D0D8);
    const accent = PdfColor.fromInt(0xFF1A3A5C);

    pw.Widget sectionTitle(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12, bottom: 4),
          child: pw.Text(
            text.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 9,
              color: muted,
              letterSpacing: 0.8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        );

    pw.Widget field(String label, String value,
            {double? width, double minHeight = 18}) =>
        pw.Container(
          width: width,
          padding: const pw.EdgeInsets.only(bottom: 6),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: line, width: 0.5)),
          ),
          constraints: pw.BoxConstraints(minHeight: minHeight + 14),
          margin: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      color: muted,
                      letterSpacing: 0.4,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(value.isEmpty ? ' ' : value,
                  style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        );

    pw.Widget checkbox(String label, bool checked) => pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 10,
              height: 10,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: muted, width: 0.8),
                color: checked ? accent : PdfColors.white,
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: checked ? accent : PdfColors.black,
                    fontWeight: checked
                        ? pw.FontWeight.bold
                        : pw.FontWeight.normal)),
          ],
        );

    pw.Widget signatureCell(
      String label,
      pw.Widget? image, {
      bool seal = false,
    }) =>
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Container(
                height: 70,
                alignment: pw.Alignment.center,
                child: seal
                    ? pw.Container(
                        width: 70,
                        height: 70,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: accent, width: 1.2),
                        ),
                        alignment: pw.Alignment.center,
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('FLUXGEN',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: accent,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text('SUSTAINABLE TECH.',
                                style: pw.TextStyle(
                                    fontSize: 5,
                                    color: accent,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('AUTHORIZED',
                                style: pw.TextStyle(
                                    fontSize: 6,
                                    color: accent,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      )
                    : (image ?? pw.SizedBox()),
              ),
              pw.Container(
                height: 0.5,
                color: line,
                margin: const pw.EdgeInsets.symmetric(horizontal: 20),
              ),
              pw.SizedBox(height: 4),
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: muted)),
            ],
          ),
        );

    String fmt(DateTime d) => DateFormat('dd/MM/y').format(d);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 22, 28, 22),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
            // ── Header
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 44,
                    height: 44,
                    margin: const pw.EdgeInsets.only(right: 10),
                    child: pw.Image(logo),
                  ),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Fluxgen Sustainable Technologies Private Limited',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold)),
                      pw.Text(
                          '1st floor, 1064, 18th Main Rd, BTM 2nd Stage,',
                          style: const pw.TextStyle(
                              fontSize: 9, color: muted)),
                      pw.Text('Bengaluru, Karnataka 560076',
                          style: const pw.TextStyle(
                              fontSize: 9, color: muted)),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CUSTOMER SERVICE REPORT',
                        style: pw.TextStyle(
                            fontSize: 16,
                            color: accent,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Row(children: [
                      pw.Text('CSR NO:',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: muted,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 4),
                      pw.Text(_csrNo.text,
                          style: const pw.TextStyle(fontSize: 9)),
                      pw.SizedBox(width: 10),
                      pw.Text('DATE:',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: muted,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 4),
                      pw.Text(fmt(_date),
                          style: const pw.TextStyle(fontSize: 9)),
                    ]),
                    pw.Row(children: [
                      pw.Text('Status of Call By:',
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: muted,
                              fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(width: 4),
                      pw.Text(_callBy.text,
                          style: const pw.TextStyle(fontSize: 9)),
                    ]),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Container(height: 0.8, color: line),

            // ── Customer details
            sectionTitle('Customer Details'),
            field('Site Name', _custName.text),
            field('Address', _address.text),
            pw.Row(children: [
              pw.Expanded(child: field('City', _city.text)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: field('State', _state.text)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: field('Zip Code', _zip.text)),
            ]),
            pw.Row(children: [
              pw.Expanded(
                  child: field('Instruction From', _instrFrom.text)),
              pw.SizedBox(width: 12),
              pw.Expanded(
                  child: field('Inspected By', _inspectedBy.text)),
            ]),

            // ── Nature of Work
            sectionTitle('Nature of Work'),
            field('', _nature.text, minHeight: 18),

            // ── Work Details
            sectionTitle('Work Details'),
            field('Work Performed', _details.text, minHeight: 26),
            field('Defects Found on Inspection', _defects.text),
            field("Engineer's Remarks", _remarks.text),
            pw.Row(children: [
              pw.Expanded(
                  child: field('Status After Work', _statusAfter)),
              pw.SizedBox(width: 12),
              pw.Expanded(child: pw.SizedBox()),
            ]),

            // ── Service Timings
            sectionTitle('Service Timings'),
            pw.Row(children: [
              pw.Expanded(child: field('Event Date', fmt(_eventDate))),
              pw.SizedBox(width: 10),
              pw.Expanded(child: field('Event Time', _eventTime.text)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: field('Start of Work', _startTime.text)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: field('End of Service', _endTime.text)),
            ]),

            // ── Rating
            sectionTitle('Please rate this service'),
            pw.Row(children: [
              checkbox('Extremely Satisfied',
                  _satisfaction == 'Extremely Satisfied'),
              pw.SizedBox(width: 14),
              checkbox('Satisfied', _satisfaction == 'Satisfied'),
              pw.SizedBox(width: 14),
              checkbox('Dissatisfied', _satisfaction == 'Dissatisfied'),
              pw.SizedBox(width: 14),
              checkbox('Annoyed', _satisfaction == 'Annoyed'),
            ]),
            pw.SizedBox(height: 6),

            // ── Customer Feedback
            sectionTitle('Customer Feedback'),
            field('Remarks', _fbRemarks.text, minHeight: 18),
            pw.Row(children: [
              pw.Expanded(child: field('Name', _fbName.text)),
              pw.SizedBox(width: 10),
              pw.Expanded(
                  child: field('Designation', _fbDesignation.text)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: field('Phone/Fax', _fbPhone.text)),
            ]),
            pw.Row(children: [
              pw.Expanded(child: field('Email', _fbEmail.text)),
              pw.SizedBox(width: 10),
              pw.Expanded(child: field('Date', _fbDate.text)),
            ]),
          ],
        ),
        // Signature row sits outside the main Column so MultiPage can
        // flow it onto the next page if content is tall.
        pw.SizedBox(height: 20),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            signatureCell(
              'Customer Signature',
              custBytes != null ? pw.Image(pw.MemoryImage(custBytes)) : null,
            ),
            pw.SizedBox(width: 10),
            signatureCell(
              'Engineer Signature',
              engBytes != null ? pw.Image(pw.MemoryImage(engBytes)) : null,
            ),
            pw.SizedBox(width: 10),
            signatureCell('Authorized Signatory', null, seal: true),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(height: 0.5, color: line),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            'Fluxgen Sustainable Technologies Private Limited  |  BTM 2nd Stage, Bengaluru 560076  |  www.fluxgen.in',
            style: const pw.TextStyle(fontSize: 8, color: muted),
          ),
        ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }
}
