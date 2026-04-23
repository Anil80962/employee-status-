import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/search_picker.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Reports'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          unselectedLabelColor: AppColors.sub,
          tabs: const [
            Tab(text: 'Employee'),
            Tab(text: 'Site'),
            Tab(text: 'Work Type'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _EmployeeReport(),
          _SiteReport(),
          _WorkTypeReport(),
        ],
      ),
    );
  }
}

class _ReportRunner extends StatefulWidget {
  final String title;
  final String filterLabel;
  final List<String> Function(List<Employee>, List<Site>) buildOptions;
  final String Function() getSelected;
  final void Function(String) setSelected;
  final bool Function(StatusRecord) matches;
  final String filename;
  const _ReportRunner({
    required this.title,
    required this.filterLabel,
    required this.buildOptions,
    required this.getSelected,
    required this.setSelected,
    required this.matches,
    required this.filename,
  });

  @override
  State<_ReportRunner> createState() => _ReportRunnerState();
}

class _ReportRunnerState extends State<_ReportRunner> {
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  bool _loading = false;
  List<StatusRecord> _rows = [];
  List<Employee> _emps = [];
  List<Site> _sites = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final r = await Future.wait([
        ApiService.instance.getEmployees(),
        ApiService.instance.getSites(),
      ]);
      if (!mounted) return;
      setState(() {
        _emps = r[0] as List<Employee>;
        _sites = r[1] as List<Site>;
      });
    } catch (_) {}
  }

  Future<void> _preview() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.getStatusRange(
        from: fmtDateISO(_from),
        to: fmtDateISO(_to),
      );
      if (!mounted) return;
      setState(() {
        _rows = data.where(widget.matches).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _exportCsv() async {
    if (_rows.isEmpty) {
      showToast(context, 'Preview first', error: true);
      return;
    }
    final rows = <List<String>>[
      [
        '#', 'Employee', 'Role', 'Site', 'Work Type', 'Scope', 'Status',
        'Date', 'Work Done', 'Completion %', 'Remarks'
      ],
      for (var i = 0; i < _rows.length; i++)
        [
          '${i + 1}',
          _rows[i].empName,
          _rows[i].role,
          _rows[i].siteName,
          _rows[i].workType,
          _rows[i].scopeOfWork,
          _rows[i].status,
          _rows[i].date,
          _rows[i].workDone,
          _rows[i].completionPct,
          _rows[i].workRemarks,
        ],
    ];
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/${widget.filename}_${fmtDateISO(_from)}_${fmtDateISO(_to)}.csv');
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], subject: widget.title);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SearchPickerField(
          label: widget.filterLabel,
          icon: Icons.filter_alt_outlined,
          items: widget.buildOptions(_emps, _sites),
          value: widget.getSelected(),
          onSelected: (v) => setState(() => widget.setSelected(v)),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _from,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _from = d);
              },
              child: _dateBox('From', _from),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _to,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _to = d);
              },
              child: _dateBox('To', _to),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _preview,
              icon: const Icon(Icons.visibility_outlined),
              label: Text(_loading ? 'Loading…' : 'Preview'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _rows.isEmpty ? null : _exportCsv,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export CSV'),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Text('${_rows.length} row(s)',
            style: const TextStyle(color: AppColors.sub)),
        const SizedBox(height: 6),
        ..._rows.map((r) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE6EAF0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(r.empName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700))),
                    statusBadge(r.status),
                  ]),
                  Text(
                    '${r.date} · ${r.siteName} · ${r.workType}',
                    style: const TextStyle(
                        color: AppColors.sub, fontSize: 12),
                  ),
                  if (r.scopeOfWork.isNotEmpty)
                    Text(r.scopeOfWork,
                        style: const TextStyle(fontSize: 13)),
                ],
              ),
            )),
      ],
    );
  }

  Widget _dateBox(String label, DateTime d) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDDDDDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.sub)),
          const SizedBox(height: 2),
          Text(fmtDatePretty(d)),
        ],
      ),
    );
  }
}

class _EmployeeReport extends StatefulWidget {
  const _EmployeeReport();
  @override
  State<_EmployeeReport> createState() => _EmployeeReportState();
}

class _EmployeeReportState extends State<_EmployeeReport> {
  String _selected = 'All employees';
  @override
  Widget build(BuildContext context) {
    return _ReportRunner(
      title: 'Employee Report',
      filterLabel: 'Employee',
      filename: 'employee-report',
      buildOptions: (emps, _) => ['All employees', ...emps.map((e) => e.name)],
      getSelected: () => _selected,
      setSelected: (v) => _selected = v,
      matches: (r) =>
          _selected == 'All employees' || r.empName == _selected,
    );
  }
}

class _SiteReport extends StatefulWidget {
  const _SiteReport();
  @override
  State<_SiteReport> createState() => _SiteReportState();
}

class _SiteReportState extends State<_SiteReport> {
  String _selected = 'All sites';
  @override
  Widget build(BuildContext context) {
    return _ReportRunner(
      title: 'Site Report',
      filterLabel: 'Site',
      filename: 'site-report',
      buildOptions: (_, sites) => ['All sites', ...sites.map((s) => s.name)],
      getSelected: () => _selected,
      setSelected: (v) => _selected = v,
      matches: (r) => _selected == 'All sites' || r.siteName == _selected,
    );
  }
}

class _WorkTypeReport extends StatefulWidget {
  const _WorkTypeReport();
  @override
  State<_WorkTypeReport> createState() => _WorkTypeReportState();
}

class _WorkTypeReportState extends State<_WorkTypeReport> {
  String _selected = 'All work types';
  final _types = const [
    'All work types',
    'Project',
    'Service',
    'Office Work',
    'BMS Integration',
    'Site Survey',
  ];
  @override
  Widget build(BuildContext context) {
    return _ReportRunner(
      title: 'Work Type Report',
      filterLabel: 'Work type',
      filename: 'worktype-report',
      buildOptions: (_, __) => _types,
      getSelected: () => _selected,
      setSelected: (v) => _selected = v,
      matches: (r) =>
          _selected == 'All work types' || r.workType == _selected,
    );
  }
}
