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
  static const _pageSize = 25;
  int _page = 1;
  late Future<PagedList<UserSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PagedList<UserSummary>> _load() => context.read<ApiClient>().getUsers(page: _page, pageSize: _pageSize);

  void _refresh() => setState(() => _future = _load());

  void _goToPage(int page) {
    if (page < 1 || page == _page) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  Future<void> _changeRole(UserSummary user) async {
    var role = user.role;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.manage_accounts_rounded, color: AppTheme.blue),
        title: const Text('تغيير دور المستخدم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(user.fullName, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(user.email, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
            const SizedBox(height: 18),
            const Text(
              'الدور الجديد',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 9),
            StatefulBuilder(
              builder: (context, setDialogState) => Column(
                children: [
                  _RoleChoice(
                    value: 'Student',
                    title: 'طالب',
                    subtitle: 'استكشاف الكورسات والتسجيل والتعلّم',
                    icon: Icons.school_outlined,
                    selected: role == 'Student',
                    onTap: () => setDialogState(() => role = 'Student'),
                  ),
                  const SizedBox(height: 8),
                  _RoleChoice(
                    value: 'Instructor',
                    title: 'مدرّس',
                    subtitle: 'إنشاء الكورسات وإدارة المحتوى',
                    icon: Icons.co_present_rounded,
                    selected: role == 'Instructor',
                    onTap: () => setDialogState(() => role = 'Instructor'),
                  ),
                  const SizedBox(height: 8),
                  _RoleChoice(
                    value: 'Admin',
                    title: 'مدير',
                    subtitle: 'صلاحيات الإدارة والتحكم الكامل',
                    icon: Icons.admin_panel_settings_outlined,
                    selected: role == 'Admin',
                    onTap: () => setDialogState(() => role = 'Admin'),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, role),
            icon: const Icon(Icons.save_outlined),
            label: const Text('حفظ الدور'),
          ),
        ],
      ),
    );
    if (selected == null || selected == user.role || !mounted) return;

    try {
      await context.read<ApiClient>().changeUserRole(user.id, selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث دور المستخدم.')));
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptivePageHeader(
          eyebrow: 'مساحة الإدارة',
          title: 'إدارة المستخدمين',
          subtitle: 'راجع الحسابات والأدوار وعدّل صلاحيات المستخدمين من واجهة واضحة ومباشرة.',
          icon: Icons.manage_accounts_rounded,
          action: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تحديث'),
          ),
        ),
        const SizedBox(height: 24),
        FutureBuilder<PagedList<UserSummary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingState(label: 'جاري تحميل المستخدمين...');
            }
            if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), onRetry: _refresh);
            final result = snapshot.data;
            final users = result?.items ?? const <UserSummary>[];
            if (users.isEmpty) {
              return const EmptyState(title: 'لا يوجد مستخدمون', message: 'ستظهر الحسابات هنا بعد التسجيل.', icon: Icons.people_alt_rounded);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminSummary(
                  icon: Icons.people_alt_rounded,
                  value: '${result!.totalCount}',
                  label: 'إجمالي المستخدمين',
                  helper: 'صفحة ${result.page} من ${result.totalPages == 0 ? 1 : result.totalPages}',
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < users.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _UserRow(user: users[index], onRole: () => _changeRole(users[index])),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Pager(
                  page: result.page,
                  totalPages: result.totalPages,
                  totalCount: result.totalCount,
                  hasPrevious: result.hasPrevious,
                  hasNext: result.hasNext,
                  onPrevious: () => _goToPage(result.page - 1),
                  onNext: () => _goToPage(result.page + 1),
                ),
              ],
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final avatar = CircleAvatar(
      backgroundColor: AppTheme.blue.withValues(alpha: .12),
      child: Text(
        user.fullName.isEmpty ? 'م' : user.fullName.substring(0, 1),
        style: const TextStyle(color: AppTheme.blue, fontWeight: FontWeight.w900),
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(user.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: AppTheme.cyan.withValues(alpha: .09), borderRadius: BorderRadius.circular(999)),
          child: Text(user.role, style: const TextStyle(color: AppTheme.cyan, fontSize: 9, fontWeight: FontWeight.w900)),
        ),
      ],
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [avatar, const SizedBox(width: 12), Expanded(child: info)]),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRole, icon: const Icon(Icons.manage_accounts_rounded), label: const Text('تغيير الدور')),
          ],
        ),
      );
    }
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
      leading: avatar,
      title: info,
      trailing: OutlinedButton.icon(onPressed: onRole, icon: const Icon(Icons.manage_accounts_rounded), label: const Text('تغيير الدور')),
    );
  }
}

class _RoleChoice extends StatelessWidget {
  const _RoleChoice({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? AppTheme.blue.withValues(alpha: .07)
            : AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? AppTheme.blue.withValues(alpha: .28)
                    : AppTheme.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.blue.withValues(alpha: .11)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: selected ? AppTheme.blue : AppTheme.muted,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: selected ? AppTheme.blue : AppTheme.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppTheme.subtle,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    key: ValueKey(selected),
                    color: selected ? AppTheme.blue : AppTheme.borderStrong,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class AdminEnrollmentsPage extends StatefulWidget {
  const AdminEnrollmentsPage({super.key});

  @override
  State<AdminEnrollmentsPage> createState() => _AdminEnrollmentsPageState();
}

class _AdminEnrollmentsPageState extends State<AdminEnrollmentsPage> {
  static const _pageSize = 25;
  int _page = 1;
  late Future<PagedList<Enrollment>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PagedList<Enrollment>> _load() => context.read<ApiClient>().getAllEnrollments(page: _page, pageSize: _pageSize);

  void _refresh() => setState(() => _future = _load());

  void _goToPage(int page) {
    if (page < 1 || page == _page) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdaptivePageHeader(
          eyebrow: 'مساحة الإدارة',
          title: 'كل التسجيلات',
          subtitle: 'تابع نشاط التسجيل في الكورسات وتحقق من الطلاب والمسارات المسجّلة.',
          icon: Icons.assignment_turned_in_rounded,
          action: OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded), label: const Text('تحديث')),
        ),
        const SizedBox(height: 24),
        FutureBuilder<PagedList<Enrollment>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const LoadingState(label: 'جاري تحميل التسجيلات...');
            if (snapshot.hasError) return ErrorState(message: snapshot.error.toString(), onRetry: _refresh);
            final result = snapshot.data;
            final items = result?.items ?? const <Enrollment>[];
            if (items.isEmpty) {
              return const EmptyState(title: 'لا توجد تسجيلات', message: 'ستظهر تسجيلات الطلاب في هذه المساحة.', icon: Icons.fact_check_rounded);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AdminSummary(
                  icon: Icons.fact_check_rounded,
                  value: '${result!.totalCount}',
                  label: 'إجمالي التسجيلات',
                  helper: 'صفحة ${result.page} من ${result.totalPages == 0 ? 1 : result.totalPages}',
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var index = 0; index < items.length; index++) ...[
                        if (index > 0) const Divider(height: 1),
                        _EnrollmentAdminRow(item: items[index]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _Pager(
                  page: result.page,
                  totalPages: result.totalPages,
                  totalCount: result.totalCount,
                  hasPrevious: result.hasPrevious,
                  hasNext: result.hasNext,
                  onPrevious: () => _goToPage(result.page - 1),
                  onNext: () => _goToPage(result.page + 1),
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _EnrollmentAdminRow extends StatelessWidget {
  const _EnrollmentAdminRow({required this.item});

  final Enrollment item;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: AppTheme.cyan.withValues(alpha: .10), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.assignment_turned_in_rounded, color: AppTheme.cyan, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.courseTitle, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(item.userName, style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${item.enrolledDate.day}/${item.enrolledDate.month}/${item.enrolledDate.year}', style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSummary extends StatelessWidget {
  const _AdminSummary({required this.icon, required this.value, required this.label, required this.helper});

  final IconData icon;
  final String value;
  final String label;
  final String helper;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppTheme.blue.withValues(alpha: .08), AppTheme.cyan.withValues(alpha: .06)]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: AppTheme.blue),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: AppTheme.ink, fontSize: 11, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(helper, style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.totalCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalPages;
  final int totalCount;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.border)),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        IconButton.outlined(onPressed: hasPrevious ? onPrevious : null, tooltip: 'الصفحة السابقة', icon: const Icon(Icons.chevron_right_rounded)),
        Text(
          'صفحة $page من ${totalPages == 0 ? 1 : totalPages} • $totalCount سجل',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        IconButton.outlined(onPressed: hasNext ? onNext : null, tooltip: 'الصفحة التالية', icon: const Icon(Icons.chevron_left_rounded)),
      ],
    ),
  );
}
