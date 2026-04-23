import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'service_report_screen.dart';
import 'work_done_screen.dart';

class TeamOverviewScreen extends StatefulWidget {
  final bool embedded;
  const TeamOverviewScreen({super.key, this.embedded = false});

  @override
  State<TeamOverviewScreen> createState() => _TeamOverviewScreenState();
}

class _TeamOverviewScreenState extends State<TeamOverviewScreen> {
  DateTime _date = DateTime.now();
  bool _loading = true;
  List<StatusRecord> _rows = [];

  // Efficiency range
  DateTime _effFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _effTo = DateTime.now();
  bool _calcRunning = false;
  List<_EmpEff> _eff = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows =
          await ApiService.instance.getStatus(date: fmtDateISO(_date));
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _calcEfficiency() async {
    setState(() => _calcRunning = true);
    try {
      final rows = await ApiService.instance.getStatusRange(
        from: fmtDateISO(_effFrom),
        to: fmtDateISO(_effTo),
      );
      final byEmp = <String, List<StatusRecord>>{};
      for (final r in rows) {
        byEmp.putIfAbsent(r.empName, () => []).add(r);
      }
      final out = <_EmpEff>[];
      byEmp.forEach((name, list) {
        final onSite = list.where((r) => r.status == 'On Site').length;
        final onLeave = list
            .where((r) => r.status == 'On Leave' || r.status == 'Holiday')
            .length;
        final weekendWorked = list.where((r) {
          final d = parseISO(r.date);
          return d != null && (d.weekday == 6 || d.weekday == 7) &&
              (r.status == 'On Site' || r.status == 'In Office');
        }).length;
        final active = list.length - onLeave;
        final eff = active <= 0
            ? 0.0
            : (onSite + weekendWorked) / active * 100;
        out.add(_EmpEff(
          name: name,
          daysWorked: list.length,
          onSite: onSite,
          onLeave: onLeave,
          weekendWorked: weekendWorked,
          efficiency: eff,
        ));
      });
      out.sort((a, b) => b.efficiency.compareTo(a.efficiency));
      if (!mounted) return;
      setState(() {
        _eff = out;
        _calcRunning = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _calcRunning = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  int _count(bool Function(StatusRecord) f) => _rows.where(f).length;

  @override
  Widget build(BuildContext context) {
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) {
                      setState(() => _date = d);
                      _load();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFE6EAF0)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 10),
                      Text(fmtDatePretty(_date)),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.0,
                  children: [
                    statCard(
                        label: 'Total',
                        value: _rows.length.toString(),
                        color: AppColors.primary),
                    statCard(
                        label: 'On Site',
                        value: _count((r) => r.status == 'On Site').toString(),
                        color: AppColors.red),
                    statCard(
                        label: 'Project',
                        value:
                            _count((r) => r.workType == 'Project').toString(),
                        color: AppColors.blue),
                    statCard(
                        label: 'Service',
                        value:
                            _count((r) => r.workType == 'Service').toString(),
                        color: AppColors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                ..._rows.map(_rowTile),
                const SizedBox(height: 18),
                sectionHeader('Team Efficiency'),
                Row(children: [
                  Expanded(child: _dateBox('From', _effFrom, (d) {
                    setState(() => _effFrom = d);
                  })),
                  const SizedBox(width: 8),
                  Expanded(child: _dateBox('To', _effTo, (d) {
                    setState(() => _effTo = d);
                  })),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _calcRunning ? null : _calcEfficiency,
                    icon: const Icon(Icons.analytics_outlined),
                    label: Text(_calcRunning ? 'Calculating…' : 'Calculate'),
                  ),
                ),
                const SizedBox(height: 12),
                ..._eff.map(_effTile),
              ],
            );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Team Overview',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Overview'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: body,
    );
  }

  Widget _rowTile(StatusRecord r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.empName,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            statusBadge(r.status),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              if (r.siteName.isNotEmpty) r.siteName,
              if (r.workType.isNotEmpty) r.workType,
            ].join(' · '),
            style: const TextStyle(color: AppColors.sub, fontSize: 12),
          ),
          if (r.scopeOfWork.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(r.scopeOfWork, style: const TextStyle(fontSize: 13)),
          ],
          if (r.workDone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.check_circle_outline,
                  size: 14, color: AppColors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(r.workDone,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.green)),
              ),
              if (r.completionPct.isNotEmpty)
                Text(' ${r.completionPct}%',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.green,
                        fontWeight: FontWeight.w700)),
            ]),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => WorkDoneScreen(record: r),
                    ),
                  );
                  if (ok == true) _load();
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Update'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  foregroundColor: AppColors.primary,
                  side:
                      const BorderSide(color: Color(0xFFD5DCE3), width: 1),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ServiceReportScreen(record: r),
                  ));
                },
                icon: const Icon(Icons.description_outlined, size: 18),
                label: const Text('Report'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _dateBox(String label, DateTime d, ValueChanged<DateTime> set) {
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
      ),
    );
  }

  Widget _effTile(_EmpEff e) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(e.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Text('${e.efficiency.toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (e.efficiency / 100).clamp(0, 1),
              backgroundColor: const Color(0xFFE6EAF0),
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
              'Days ${e.daysWorked} · OnSite ${e.onSite} · Leave ${e.onLeave} · Wknd ${e.weekendWorked}',
              style: const TextStyle(color: AppColors.sub, fontSize: 12)),
        ],
      ),
    );
  }
}

class _EmpEff {
  final String name;
  final int daysWorked;
  final int onSite;
  final int onLeave;
  final int weekendWorked;
  final double efficiency;
  _EmpEff({
    required this.name,
    required this.daysWorked,
    required this.onSite,
    required this.onLeave,
    required this.weekendWorked,
    required this.efficiency,
  });
}
