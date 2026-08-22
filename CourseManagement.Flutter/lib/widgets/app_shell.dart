import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _selectedIndex(String path) {
    if (path.startsWith('/courses')) return 1;
    if (path.startsWith('/enrollments')) return 2;
    if (path.startsWith('/profile')) return 3;
    return 0;
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).maybePop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final path = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(path);
    final compact = MediaQuery.sizeOf(context).width < 780;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.blue, AppTheme.cyan],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.school_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'منصة المعرفة',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        actions: [
          if (!compact)
            IconButton(
              tooltip: 'حسابي',
              onPressed: () => context.go('/profile'),
              icon: CircleAvatar(
                radius: 17,
                backgroundColor: AppTheme.blue.withValues(alpha: .12),
                child: Text(
                  auth.session?.fullName.substring(0, 1) ?? 'م',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (compact)
            Builder(
              builder: (context) => IconButton(
                tooltip: 'القائمة',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.blue.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'مساحة التعلم\n${auth.session?.fullName ?? ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _DrawerTile(
                icon: Icons.dashboard_rounded,
                label: 'لوحة التحكم',
                active: selected == 0,
                onTap: () => _go(context, '/'),
              ),
              _DrawerTile(
                icon: Icons.auto_stories_rounded,
                label: 'استكشاف الكورسات',
                active: selected == 1,
                onTap: () => _go(context, '/courses'),
              ),
              _DrawerTile(
                icon: Icons.fact_check_rounded,
                label: 'تسجيلاتي',
                active: selected == 2,
                onTap: () => _go(context, '/enrollments'),
              ),
              _DrawerTile(
                icon: Icons.person_rounded,
                label: 'حسابي',
                active: selected == 3,
                onTap: () => _go(context, '/profile'),
              ),
              if (auth.isInstructor) ...[
                const Divider(indent: 20, endIndent: 20),
                _DrawerTile(
                  icon: Icons.library_add_check_rounded,
                  label: 'إدارة الكورسات',
                  active: path.startsWith('/manage'),
                  onTap: () => _go(context, '/manage/courses'),
                ),
              ],
              if (auth.isAdmin) ...[
                _DrawerTile(
                  icon: Icons.manage_accounts_rounded,
                  label: 'إدارة المستخدمين',
                  active: path.startsWith('/admin/users'),
                  onTap: () => _go(context, '/admin/users'),
                ),
                _DrawerTile(
                  icon: Icons.fact_check_rounded,
                  label: 'إدارة التسجيلات',
                  active: path.startsWith('/admin/enrollments'),
                  onTap: () => _go(context, '/admin/enrollments'),
                ),
              ],
              const Spacer(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('تسجيل الخروج'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) =>
            _go(context, ['/', '/courses', '/enrollments', '/profile'][index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'الكورسات',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'تسجيلاتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: active,
      selectedTileColor: AppTheme.blue.withValues(alpha: .09),
      selectedColor: AppTheme.blue,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(icon),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}
