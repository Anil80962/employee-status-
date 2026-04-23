import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/common.dart';
import 'login_screen.dart';
import 'team_screen.dart';
import 'update_status_screen.dart';
import 'weekly_overview_screen.dart';
import 'team_overview_screen.dart';
import 'reports_screen.dart';
import 'manage_employees_screen.dart';
import 'manage_users_screen.dart';
import 'inventory_screen.dart';
import 'work_done_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _HomeTab(),
      const UpdateStatusScreen(embedded: true),
      const TeamScreen(embedded: true),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: FluxNavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  bool _loading = true;
  List<StatusRecord> _today = [];
  StatusRecord? _my;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final today = fmtDateISO(DateTime.now());
      final rows = await ApiService.instance.getStatus(date: today);
      final me = context.read<AuthService>().user;
      StatusRecord? mine;
      if (me != null) {
        final matches = rows.where((r) =>
            r.empName.toLowerCase().trim() ==
                me.displayName.toLowerCase().trim() ||
            r.empId.toLowerCase().trim() == me.username.toLowerCase().trim());
        if (matches.isNotEmpty) mine = matches.first;
      }
      if (!mounted) return;
      setState(() {
        _today = rows;
        _my = mine;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed to load: $e', error: true);
    }
  }

  int _count(bool Function(StatusRecord) f) => _today.where(f).length;

  Future<void> _openMyUpdate() async {
    Widget target;
    if (_my != null) {
      // Already have today's entry — jump straight to the work-done editor
      target = WorkDoneScreen(record: _my!);
    } else {
      // No record yet — let them create one
      target = const UpdateStatusScreen();
    }
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => target),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user!;
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          _Topbar(user: user),
          const SizedBox(height: 12),
          _HeroCard(
            greeting: greeting,
            dateLabel: fmtDatePretty(now),
            my: _my,
            loading: _loading,
            onUpdate: _openMyUpdate,
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: _QuickAction(
                icon: Icons.edit_note_rounded,
                label: 'Update Status',
                onTap: _openMyUpdate,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickAction(
                icon: Icons.groups_rounded,
                label: 'View Team',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const TeamScreen(),
                )),
              ),
            ),
          ]),
          const SizedBox(height: 18),
          sectionHeader("Today's team"),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.1,
            children: [
              statCard(
                  label: 'On Site',
                  value: _count((r) => r.status == 'On Site').toString(),
                  color: AppColors.red),
              statCard(
                  label: 'In Office',
                  value: _count((r) => r.status == 'In Office').toString(),
                  color: AppColors.green),
              statCard(
                  label: 'On Leave',
                  value: _count(
                          (r) => r.status == 'On Leave' || r.status == 'Holiday')
                      .toString(),
                  color: AppColors.purple),
              statCard(
                  label: 'Updates',
                  value: _today.length.toString(),
                  color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 18),
          sectionHeader('More'),
          _MoreMenu(),
        ],
      ),
    );
  }
}

class _Topbar extends StatelessWidget {
  final AppUser user;
  const _Topbar({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset('assets/images/fluxgen-logo.png', width: 34, height: 34),
        const SizedBox(width: 10),
        const Expanded(
          child: Text('Ops Team',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        GestureDetector(
          onTap: () => _openProfileSheet(context),
          child: roundedAvatar(user.displayName, size: 38),
        ),
      ],
    );
  }
}

void _openProfileSheet(BuildContext context) {
  final user = context.read<AuthService>().user!;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                roundedAvatar(user.displayName, size: 54),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        '${user.role.toUpperCase()} · @${user.username}',
                        style: const TextStyle(color: AppColors.sub),
                      ),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await context.read<AuthService>().logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _HeroCard extends StatelessWidget {
  final String greeting;
  final String dateLabel;
  final StatusRecord? my;
  final bool loading;
  final VoidCallback onUpdate;
  const _HeroCard({
    required this.greeting,
    required this.dateLabel,
    required this.my,
    required this.loading,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primary2],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(greeting,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (loading)
            const Text('Loading…', style: TextStyle(color: Colors.white70))
          else if (my == null)
            const Text('Status not updated yet',
                style: TextStyle(color: Colors.white70))
          else
            Wrap(spacing: 8, runSpacing: 6, children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(my!.status,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              if (my!.siteName.isNotEmpty)
                Text('@ ${my!.siteName}',
                    style: const TextStyle(color: Colors.white)),
            ]),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Scope of work',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      (my == null || my!.scopeOfWork.trim().isEmpty)
                          ? '—'
                          : my!.scopeOfWork.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: onUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                ),
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE6EAF0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user!;
    final items = <Widget>[];

    void add(String title, IconData icon, Widget Function() builder,
        {bool show = true}) {
      if (!show) return;
      items.add(_MenuTile(
          icon: icon,
          label: title,
          onTap: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => builder()))));
    }

    add('Weekly Overview', Icons.calendar_view_week_rounded,
        () => const WeeklyOverviewScreen());
    add('Team Overview', Icons.dashboard_rounded,
        () => const TeamOverviewScreen(),
        show: user.isAdminOrManager);
    add('Download Reports', Icons.download_rounded, () => const ReportsScreen(),
        show: user.isAdminOrManager);
    add('Manage Employees', Icons.badge_rounded,
        () => const ManageEmployeesScreen(),
        show: user.isAdmin);
    add('Manage Users', Icons.manage_accounts_rounded,
        () => const ManageUsersScreen(),
        show: user.isAdmin);
    add('Inventory', Icons.inventory_2_rounded, () => const InventoryScreen(),
        show: user.isAdmin);

    return Column(
      children: items
          .expand((w) => [w, const SizedBox(height: 8)])
          .toList()
        ..removeLast(),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6EAF0)),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.sub),
          ]),
        ),
      ),
    );
  }
}
