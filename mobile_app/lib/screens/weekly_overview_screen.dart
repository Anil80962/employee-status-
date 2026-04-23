import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class WeeklyOverviewScreen extends StatefulWidget {
  const WeeklyOverviewScreen({super.key});

  @override
  State<WeeklyOverviewScreen> createState() => _WeeklyOverviewScreenState();
}

class _WeeklyOverviewScreenState extends State<WeeklyOverviewScreen> {
  DateTime _weekStart = _mondayOf(DateTime.now());
  bool _loading = true;
  List<Employee> _employees = [];
  Map<String, Map<String, StatusRecord>> _matrix = {};

  static DateTime _mondayOf(DateTime d) {
    final w = d.weekday; // 1 = Monday
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: w - 1));
  }

  List<DateTime> get _days =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final emps = await ApiService.instance.getEmployees();
      final rows = await ApiService.instance.getStatusRange(
        from: fmtDateISO(_days.first),
        to: fmtDateISO(_days.last),
      );
      final m = <String, Map<String, StatusRecord>>{};
      for (final r in rows) {
        final k = r.empName.toLowerCase();
        m.putIfAbsent(k, () => {});
        m[k]![r.date] = r;
      }
      if (!mounted) return;
      setState(() {
        _employees = emps;
        _matrix = m;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Overview'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _weekStart,
                firstDate: DateTime(2024),
                lastDate: DateTime(2100),
              );
              if (d != null) {
                setState(() => _weekStart = _mondayOf(d));
                _load();
              }
            },
          ),
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Week of ${fmtDatePretty(_days.first)} — ${fmtDatePretty(_days.last)}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.sub),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          const DataColumn(label: Text('Employee')),
                          ..._days.map((d) => DataColumn(
                                label: Text(
                                    '${_weekdayName(d)}\n${d.day}/${d.month}',
                                    textAlign: TextAlign.center),
                              )),
                        ],
                        rows: _employees.map((e) {
                          final map = _matrix[e.name.toLowerCase()] ?? {};
                          return DataRow(cells: [
                            DataCell(Text(e.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            ..._days.map((d) {
                              final s = map[fmtDateISO(d)];
                              if (s == null) {
                                return const DataCell(Text('—',
                                    style: TextStyle(color: AppColors.sub)));
                              }
                              return DataCell(_cellLabel(s));
                            }),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _weekdayName(DateTime d) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1];

  Widget _cellLabel(StatusRecord s) {
    final color = AppColors.forStatus(s.status);
    // Prefer the site name when we have one (typically: On Site).
    // Fall back to a short status label for Office / WFH / Leave / Holiday / Weekend.
    final String text;
    if (s.siteName.trim().isNotEmpty) {
      text = s.siteName.trim();
    } else {
      text = _shortStatus(s.status);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  String _shortStatus(String s) {
    switch (s) {
      case 'In Office':
        return 'Office';
      case 'Work From Home':
        return 'WFH';
      case 'On Leave':
        return 'Leave';
      case 'Holiday':
        return 'Holiday';
      case 'Weekend':
        return 'Weekend';
      case 'On Site':
        return 'On Site';
      default:
        return s;
    }
  }
}
