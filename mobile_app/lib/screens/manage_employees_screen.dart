import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ManageEmployeesScreen extends StatefulWidget {
  const ManageEmployeesScreen({super.key});
  @override
  State<ManageEmployeesScreen> createState() =>
      _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  bool _loading = true;
  List<Employee> _employees = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.getEmployees();
      if (!mounted) return;
      setState(() {
        _employees = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _addOrEdit([Employee? existing]) async {
    final res = await showModalBottomSheet<Employee>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _EmployeeForm(existing: existing),
    );
    if (res == null) return;
    try {
      if (existing == null) {
        await ApiService.instance.addEmployee(res);
      } else {
        await ApiService.instance.editEmployee(res);
      }
      if (!mounted) return;
      showToast(context, existing == null ? 'Added' : 'Updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(Employee e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete employee?'),
        content: Text('${e.name} will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.deleteEmployee(e.id);
      if (!mounted) return;
      showToast(context, 'Deleted');
      _load();
    } catch (err) {
      if (!mounted) return;
      showToast(context, 'Failed: $err', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Employees'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _employees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final e = _employees[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
                    ),
                    child: Row(children: [
                      roundedAvatar(e.name, size: 42),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${e.id} · ${e.role}',
                                style: const TextStyle(
                                    color: AppColors.sub, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _addOrEdit(e),
                        icon: const Icon(Icons.edit_outlined,
                            color: AppColors.primary),
                      ),
                      IconButton(
                        onPressed: () => _delete(e),
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.red),
                      ),
                    ]),
                  );
                },
              ),
            ),
    );
  }
}

class _EmployeeForm extends StatefulWidget {
  final Employee? existing;
  const _EmployeeForm({this.existing});
  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  late final _id = TextEditingController(text: widget.existing?.id ?? '');
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _role = TextEditingController(text: widget.existing?.role ?? '');

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isEdit ? 'Edit employee' : 'Add employee',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _id,
            enabled: !isEdit,
            decoration: const InputDecoration(labelText: 'Employee ID'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _role,
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_id.text.trim().isEmpty ||
                    _name.text.trim().isEmpty ||
                    _role.text.trim().isEmpty) {
                  showToast(context, 'All fields required', error: true);
                  return;
                }
                Navigator.of(context).pop(Employee(
                  id: _id.text.trim(),
                  name: _name.text.trim(),
                  role: _role.text.trim(),
                ));
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }
}
