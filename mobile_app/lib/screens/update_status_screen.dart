import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/search_picker.dart';

class UpdateStatusScreen extends StatefulWidget {
  final bool embedded;
  const UpdateStatusScreen({super.key, this.embedded = false});

  @override
  State<UpdateStatusScreen> createState() => _UpdateStatusScreenState();
}

class _UpdateStatusScreenState extends State<UpdateStatusScreen> {
  DateTime _date = DateTime.now();
  String _status = 'On Site';
  String _workType = 'Project';
  final _siteCtrl = TextEditingController();
  final _scopeCtrl = TextEditingController();

  List<Employee> _employees = [];
  List<Site> _sites = [];
  Employee? _targetEmp;
  bool _loading = true;
  bool _submitting = false;

  bool get _isLeaveLike =>
      _status == 'On Leave' || _status == 'Holiday' || _status == 'Weekend';

  bool get _hideSite => _status == 'In Office' || _isLeaveLike ||
      _status == 'Work From Home';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.instance.getEmployees(),
        ApiService.instance.getSites(),
      ]);
      final user = context.read<AuthService>().user!;
      final emps = results[0] as List<Employee>;
      Employee? me;
      for (final e in emps) {
        if (e.name.toLowerCase().trim() ==
                user.displayName.toLowerCase().trim() ||
            e.id.toLowerCase().trim() == user.username.toLowerCase().trim()) {
          me = e;
          break;
        }
      }
      // Fallback to a virtual employee using session data
      me ??= Employee(
          id: user.username, name: user.displayName, role: user.role);
      if (!mounted) return;
      setState(() {
        _employees = emps;
        _sites = results[1] as List<Site>;
        _targetEmp = me;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed to load: $e', error: true);
    }
  }

  Future<void> _submit() async {
    final emp = _targetEmp;
    if (emp == null) {
      showToast(context, 'Pick an employee', error: true);
      return;
    }
    if (!_hideSite && _siteCtrl.text.trim().isEmpty) {
      showToast(context, 'Site name required', error: true);
      return;
    }
    if (!_isLeaveLike && _scopeCtrl.text.trim().isEmpty) {
      showToast(context, 'Scope of work required', error: true);
      return;
    }

    setState(() => _submitting = true);
    try {
      await ApiService.instance.submitStatus(
        empId: emp.id,
        empName: emp.name,
        role: emp.role,
        siteName: _hideSite ? '' : _siteCtrl.text.trim(),
        workType: _isLeaveLike ? '' : _workType,
        scopeOfWork: _isLeaveLike ? '' : _scopeCtrl.text.trim(),
        status: _status,
        date: fmtDateISO(_date),
      );
      if (!mounted) return;
      showToast(context, 'Status updated');
      _siteCtrl.clear();
      _scopeCtrl.clear();
      if (!widget.embedded) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user!;
    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              children: [
                if (user.isAdminOrManager) _empSelector(),
                _dateRow(),
                const SizedBox(height: 12),
                _statusGrid(),
                const SizedBox(height: 14),
                if (!_hideSite) _siteField(),
                if (!_isLeaveLike) ...[
                  const SizedBox(height: 10),
                  _workTypeField(),
                  const SizedBox(height: 10),
                  _scopeField(),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Submit Status'),
                  ),
                ),
              ],
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: const [
                Text('Update Status',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Update Status')),
      body: body,
    );
  }

  Widget _empSelector() {
    final labels = _employees.map((e) => '${e.name} · ${e.role}').toList();
    final current = _targetEmp == null
        ? null
        : '${_targetEmp!.name} · ${_targetEmp!.role}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SearchPickerField(
        label: 'Employee',
        icon: Icons.person_outline,
        items: labels,
        value: current,
        onSelected: (v) {
          final idx = labels.indexOf(v);
          if (idx >= 0) setState(() => _targetEmp = _employees[idx]);
        },
      ),
    );
  }

  Widget _dateRow() {
    return InkWell(
      onTap: _pickDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.sub),
            const SizedBox(width: 10),
            Expanded(child: Text(fmtDatePretty(_date))),
            const Icon(Icons.chevron_right, color: AppColors.sub),
          ],
        ),
      ),
    );
  }

  Widget _statusGrid() {
    final icons = {
      'On Site': '🏗️',
      'In Office': '🏢',
      'Work From Home': '🏠',
      'On Leave': '🌴',
      'Holiday': '🎉',
      'Weekend': '⛺',
    };
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.95,
      children: AppConfig.statusOptions.map((s) {
        final selected = s == _status;
        final c = AppColors.forStatus(s);
        return InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _status = s),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected ? c.withOpacity(0.12) : Colors.white,
              border: Border.all(
                  color: selected ? c : const Color(0xFFE6EAF0),
                  width: selected ? 2 : 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icons[s] ?? '•', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 6),
                Text(s,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        color: selected ? c : AppColors.text,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _siteField() {
    final names = _sites.map((s) => s.name).toList();
    return SearchPickerField(
      label: 'Site name',
      icon: Icons.location_on_outlined,
      items: names,
      value: _siteCtrl.text.isEmpty ? null : _siteCtrl.text,
      onSelected: (v) => setState(() => _siteCtrl.text = v),
    );
  }

  Widget _workTypeField() {
    return DropdownButtonFormField<String>(
      value: _workType,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Type of work'),
      items: AppConfig.workTypes
          .map((w) => DropdownMenuItem(value: w, child: Text(w)))
          .toList(),
      onChanged: (v) => setState(() => _workType = v ?? _workType),
    );
  }

  Widget _scopeField() {
    return TextField(
      controller: _scopeCtrl,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Scope of work',
        alignLabelWithHint: true,
      ),
    );
  }
}
