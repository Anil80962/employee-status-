import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class TeamScreen extends StatefulWidget {
  final bool embedded;
  const TeamScreen({super.key, this.embedded = false});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _loading = true;
  List<Employee> _employees = [];
  List<StatusRecord> _statuses = [];
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.instance.getEmployees(),
        ApiService.instance.getStatus(date: fmtDateISO(_date)),
      ]);
      if (!mounted) return;
      setState(() {
        _employees = results[0] as List<Employee>;
        _statuses = results[1] as List<StatusRecord>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Map<String, List<_TeamItem>> _group() {
    final byEmp = <String, StatusRecord>{};
    for (final s in _statuses) {
      byEmp[s.empName.toLowerCase()] = s;
    }
    final groups = <String, List<_TeamItem>>{
      'Assigned': [],
      'In Office': [],
      'Work From Home': [],
      'On Leave': [],
      'Available': [],
    };
    for (final e in _employees) {
      final s = byEmp[e.name.toLowerCase()];
      if (s == null) {
        groups['Available']!.add(_TeamItem(e, null));
      } else if (s.status == 'On Site') {
        groups['Assigned']!.add(_TeamItem(e, s));
      } else if (s.status == 'In Office') {
        groups['In Office']!.add(_TeamItem(e, s));
      } else if (s.status == 'Work From Home') {
        groups['Work From Home']!.add(_TeamItem(e, s));
      } else if (s.status == 'On Leave' ||
          s.status == 'Holiday' ||
          s.status == 'Weekend') {
        groups['On Leave']!.add(_TeamItem(e, s));
      } else {
        groups['Available']!.add(_TeamItem(e, s));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final groups = _group();
    Widget body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
              children: [
                _header(),
                ...groups.entries.where((e) => e.value.isNotEmpty).expand(
                      (e) => [
                        _groupHeader(e.key, e.value.length),
                        ...e.value.map((t) => _tile(t)),
                        const SizedBox(height: 10),
                      ],
                    ),
              ],
            ),
          );

    if (widget.embedded) {
      return body;
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ],
      ),
      body: body,
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Team Today',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
                Text(fmtDatePretty(_date),
                    style: const TextStyle(color: AppColors.sub)),
              ],
            ),
          ),
          IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, color: AppColors.primary)),
          IconButton(
            onPressed: () async {
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
            icon: const Icon(Icons.calendar_month_rounded,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String title, int count) {
    final color = AppColors.forStatus(title == 'Assigned' ? 'On Site' : title);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
            color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(width: 6),
        Text('· $count',
            style: const TextStyle(color: AppColors.sub, fontSize: 13)),
      ]),
    );
  }

  Widget _tile(_TeamItem t) {
    final subtitle = t.status == null
        ? 'Not updated'
        : [
            t.status!.status,
            if (t.status!.siteName.isNotEmpty) '· ${t.status!.siteName}',
          ].join(' ');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(children: [
        roundedAvatar(t.employee.name, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.employee.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      color: AppColors.sub, fontSize: 12)),
            ],
          ),
        ),
        if (t.status != null) statusBadge(t.status!.status),
      ]),
    );
  }
}

class _TeamItem {
  final Employee employee;
  final StatusRecord? status;
  _TeamItem(this.employee, this.status);
}
