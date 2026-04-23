import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});
  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool _loading = true;
  Map<String, AppUser> _users = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await ApiService.instance.getUsers();
      if (!mounted) return;
      setState(() {
        _users = u;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _addUser() async {
    final res = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _UserForm(),
    );
    if (res == null) return;
    try {
      await ApiService.instance.addUser(
        username: res.username,
        password: res.password,
        role: res.role,
        displayName: res.displayName,
      );
      if (!mounted) return;
      showToast(context, 'User created');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _delete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Remove ${u.username}?'),
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
      await ApiService.instance.deleteUser(u.username);
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
    final list = _users.values.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
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
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final u = list[i];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE6EAF0)),
                    ),
                    child: Row(children: [
                      roundedAvatar(u.displayName, size: 42),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${u.username} · ${u.role}',
                                style: const TextStyle(
                                    color: AppColors.sub, fontSize: 12)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _delete(u),
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

class _UserForm extends StatefulWidget {
  const _UserForm();
  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _display = TextEditingController();
  String _role = 'user';

  @override
  Widget build(BuildContext context) {
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
          const Text('Create user',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: 10),
          TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 10),
          TextField(
              controller: _display,
              decoration: const InputDecoration(labelText: 'Display Name')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _role,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Role'),
            items: const [
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
              DropdownMenuItem(value: 'user', child: Text('User')),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                if (_user.text.trim().isEmpty ||
                    _pass.text.isEmpty ||
                    _display.text.trim().isEmpty) {
                  showToast(context, 'All fields required', error: true);
                  return;
                }
                Navigator.of(context).pop(AppUser(
                  username: _user.text.trim(),
                  password: _pass.text,
                  displayName: _display.text.trim(),
                  role: _role,
                ));
              },
              child: const Text('Create'),
            ),
          ),
        ],
      ),
    );
  }
}
