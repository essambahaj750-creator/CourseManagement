import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late Future<List<UserSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().getUsers();
  }

  void _refresh() =>
      setState(() => _future = context.read<ApiClient>().getUsers());

  Future<void> _changeRole(UserSummary user) async {
    var role = user.role;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير دور المستخدم'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => DropdownButtonFormField<String>(
            initialValue: role,
            decoration: const InputDecoration(labelText: 'الدور'),
            items: const [
              DropdownMenuItem(value: 'Student', child: Text('Student — طالب')),
              DropdownMenuItem(
                value: 'Instructor',
                child: Text('Instructor — مدرّس'),
              ),
              DropdownMenuItem(value: 'Admin', child: Text('Admin — مدير')),
            ],
            onChanged: (value) => setDialogState(() => role = value ?? role),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, role),
            child: const Text('حفظ الدور'),
          ),
        ],
      ),
    );
    if (selected == null || selected == user.role || !mounted) return;

    try {
      await context.read<ApiClient>().changeUserRole(user.id, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تحديث دور المستخدم.')));
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مساحة الإدارة',
          style: TextStyle(
            color: AppTheme.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Expanded(
              child: Text(
                'إدارة المستخدمين',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.blue),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<UserSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(70),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final users = snapshot.data ?? const <UserSummary>[];
            if (users.isEmpty) {
              return const EmptyState(
                title: 'لا يوجد مستخدمون',
                message: 'ستظهر الحسابات هنا بعد التسجيل.',
                icon: Icons.people_alt_rounded,
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var index = 0; index < users.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    _UserRow(
                      user: users[index],
                      onRole: () => _changeRole(users[index]),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.onRole});
  final UserSummary user;
  final VoidCallback onRole;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
    leading: CircleAvatar(
      backgroundColor: AppTheme.blue.withValues(alpha: .12),
      child: Text(
        user.fullName.isEmpty ? 'م' : user.fullName.substring(0, 1),
        style: const TextStyle(
          color: AppTheme.blue,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
    title: Text(
      user.fullName,
      style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '${user.email}\nالدور الحالي: ${user.role}',
      style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.6),
    ),
    trailing: IconButton(
      onPressed: onRole,
      tooltip: 'تغيير الدور',
      icon: const Icon(Icons.manage_accounts_rounded, color: AppTheme.blue),
    ),
  );
}

class AdminEnrollmentsPage extends StatefulWidget {
  const AdminEnrollmentsPage({super.key});

  @override
  State<AdminEnrollmentsPage> createState() => _AdminEnrollmentsPageState();
}

class _AdminEnrollmentsPageState extends State<AdminEnrollmentsPage> {
  late Future<List<Enrollment>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().getAllEnrollments();
  }

  void _refresh() =>
      setState(() => _future = context.read<ApiClient>().getAllEnrollments());

  @override
  Widget build(BuildContext context) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مساحة الإدارة',
          style: TextStyle(
            color: AppTheme.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Expanded(
              child: Text(
                'كل التسجيلات',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.blue),
            ),
          ],
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<Enrollment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(70),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final items = snapshot.data ?? const <Enrollment>[];
            if (items.isEmpty) {
              return const EmptyState(
                title: 'لا توجد تسجيلات',
                message: 'ستظهر تسجيلات الطلاب في هذه المساحة.',
                icon: Icons.fact_check_rounded,
              );
            }
            return Card(
              child: Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 5,
                      ),
                      leading: const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: AppTheme.cyan,
                      ),
                      title: Text(
                        items[index].courseTitle,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        '${items[index].userName} • ${items[index].enrolledDate.day}/${items[index].enrolledDate.month}/${items[index].enrolledDate.year}',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}
