import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  int _selectedIndex(String path, bool authenticated) {
    if (path.startsWith('/courses')) return 1;
    if (authenticated && path.startsWith('/enrollments')) return 2;
    if (authenticated && path.startsWith('/profile')) return 3;
    return 0;
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).maybePop();
    context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final authenticated = auth.isAuthenticated;
    final path = GoRouterState.of(context).uri.path;
    final selected = _selectedIndex(path, authenticated);
    final width = MediaQuery.sizeOf(context).width;
    final mobile = AppBreakpoints.isMobile(width);
    final desktop = AppBreakpoints.isDesktop(width);
    final drawerNavigation = !desktop;

    final content = Scaffold(
      appBar: AppBar(
        titleSpacing: mobile ? 14 : 22,
        title: _Brand(compact: mobile),
        actions: [
          if (!mobile && authenticated)
            _ProfilePill(
              name: auth.session?.fullName ?? 'حسابي',
              role: auth.session?.role ?? '',
              onTap: () => context.go('/profile'),
            ),
          if (!mobile && !authenticated)
            TextButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('تسجيل الدخول'),
            ),
          if (!mobile) const SizedBox(width: 10),
          if (drawerNavigation)
            Builder(
              builder: (context) => IconButton.filledTonal(
                tooltip: 'القائمة',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          if (drawerNavigation) const SizedBox(width: 10),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      drawer: drawerNavigation
          ? Drawer(child: _SideMenu(auth: auth, path: path, selected: selected))
          : null,
      body: SafeArea(child: child),
      bottomNavigationBar: mobile
          ? NavigationBar(
              selectedIndex: authenticated ? selected : (selected == 1 ? 1 : 0),
              onDestinationSelected: (index) {
                if (authenticated) {
                  _go(context, ['/', '/courses', '/enrollments', '/profile'][index]);
                } else {
                  _go(context, ['/', '/courses', '/login'][index]);
                }
              },
              destinations: authenticated
                  ? const [
                      NavigationDestination(
                        icon: Icon(Icons.space_dashboard_outlined),
                        selectedIcon: Icon(Icons.space_dashboard_rounded),
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
                    ]
                  : const [
                      NavigationDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: 'الرئيسية',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.auto_stories_outlined),
                        selectedIcon: Icon(Icons.auto_stories_rounded),
                        label: 'الكورسات',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.login_rounded),
                        label: 'الدخول',
                      ),
                    ],
            )
          : null,
    );

    if (!desktop) return content;

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 224,
          child: Material(
            color: Colors.white,
            child: _SideMenu(auth: auth, path: path, selected: selected),
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        Expanded(child: content),
      ],
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x262864E9),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 11),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            compact ? 'المعرفة' : 'منصة المعرفة',
            style: const TextStyle(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: -.2,
            ),
          ),
          if (!compact)
            const Text(
              'تعلّم. طبّق. تقدّم.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    ],
  );
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.name, required this.role, required this.onTap});

  final String name;
  final String role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty ? 'م' : name.trim().substring(0, 1);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.blue.withValues(alpha: .11),
              child: Text(
                first,
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 9),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                  if (role.trim().isNotEmpty)
                    Text(
                      role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 9),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideMenu extends StatelessWidget {
  const _SideMenu({required this.auth, required this.path, required this.selected});

  final AuthController auth;
  final String path;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final authenticated = auth.isAuthenticated;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                gradient: AppTheme.brandGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      authenticated ? Icons.auto_awesome_rounded : Icons.explore_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    authenticated ? (auth.session?.fullName ?? 'مساحة التعلم') : 'ابدأ رحلتك التعليمية',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    authenticated
                        ? 'كل أدواتك التعليمية في مكان واحد'
                        : 'استكشف الكورسات وعاين المحتوى قبل التسجيل',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .68),
                      fontSize: 9,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'التنقل',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          _DrawerTile(
            icon: Icons.space_dashboard_rounded,
            label: authenticated ? 'لوحة التحكم' : 'الرئيسية',
            active: selected == 0,
            onTap: () => _navigate(context, '/'),
          ),
          _DrawerTile(
            icon: Icons.auto_stories_rounded,
            label: 'استكشاف الكورسات',
            active: selected == 1,
            onTap: () => _navigate(context, '/courses'),
          ),
          if (authenticated) ...[
            _DrawerTile(
              icon: Icons.fact_check_rounded,
              label: 'تسجيلاتي',
              active: selected == 2,
              onTap: () => _navigate(context, '/enrollments'),
            ),
            _DrawerTile(
              icon: Icons.person_rounded,
              label: 'حسابي',
              active: selected == 3,
              onTap: () => _navigate(context, '/profile'),
            ),
          ] else ...[
            _DrawerTile(
              icon: Icons.login_rounded,
              label: 'تسجيل الدخول',
              active: false,
              onTap: () => _navigate(context, '/login'),
            ),
            _DrawerTile(
              icon: Icons.person_add_alt_1_rounded,
              label: 'إنشاء حساب',
              active: false,
              onTap: () => _navigate(context, '/register'),
            ),
          ],
          if (auth.isInstructor || auth.isAdmin) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'الإدارة',
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (auth.isInstructor)
              _DrawerTile(
                icon: Icons.library_add_check_rounded,
                label: 'إدارة الكورسات',
                active: path.startsWith('/manage'),
                onTap: () => _navigate(context, '/manage/courses'),
              ),
            if (auth.isAdmin) ...[
              _DrawerTile(
                icon: Icons.manage_accounts_rounded,
                label: 'إدارة المستخدمين',
                active: path.startsWith('/admin/users'),
                onTap: () => _navigate(context, '/admin/users'),
              ),
              _DrawerTile(
                icon: Icons.assignment_turned_in_rounded,
                label: 'إدارة التسجيلات',
                active: path.startsWith('/admin/enrollments'),
                onTap: () => _navigate(context, '/admin/enrollments'),
              ),
            ],
          ],
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: authenticated
                  ? OutlinedButton.icon(
                      onPressed: () async {
                        await auth.logout();
                        if (context.mounted) context.go('/');
                      },
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('تسجيل الخروج'),
                    )
                  : FilledButton.icon(
                      onPressed: () => _navigate(context, '/register'),
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: const Text('ابدأ الآن'),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, String destination) {
    Navigator.of(context).maybePop();
    context.go(destination);
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    child: Material(
      color: active ? AppTheme.blue.withValues(alpha: .09) : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.blue.withValues(alpha: .12)
                      : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: active ? AppTheme.blue : AppTheme.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: active ? AppTheme.blue : AppTheme.ink,
                    fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 5,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.blue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
