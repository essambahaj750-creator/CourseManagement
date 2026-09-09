import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final path = GoRouterState.of(context).uri.path;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = AppBreakpoints.isMobile(width);
    final desktop = AppBreakpoints.isDesktop(width);
    final items = _navigationItems(auth);
    final primaryItems = _primaryItems(items, auth);
    final selectedPrimary = _selectedIndex(primaryItems, path);

    final scaffold = Scaffold(
      appBar: AppBar(
        toolbarHeight: mobile ? 64 : 72,
        titleSpacing: mobile ? 12 : 20,
        title: _Brand(compact: mobile),
        actions: [
          if (!mobile && auth.isAuthenticated)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _AccountChip(auth: auth),
            ),
          if (!mobile && !auth.isAuthenticated)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('تسجيل الدخول'),
              ),
            ),
          if (!desktop)
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: IconButton.filledTonal(
                  tooltip: 'القائمة',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      drawer: desktop
          ? null
          : Drawer(
              width: 310,
              child: _NavigationPanel(auth: auth, path: path, items: items),
            ),
      body: SafeArea(child: child),
      bottomNavigationBar: mobile
          ? NavigationBar(
              selectedIndex: selectedPrimary,
              onDestinationSelected: (index) => context.go(primaryItems[index].path),
              destinations: [
                for (final item in primaryItems)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon ?? item.icon),
                    label: item.shortLabel ?? item.label,
                  ),
              ],
            )
          : null,
    );

    if (!desktop) return scaffold;

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 264,
          child: Material(
            color: const Color(0xFFFCFDFE),
            child: _NavigationPanel(auth: auth, path: path, items: items),
          ),
        ),
        Container(width: 1, color: AppTheme.border),
        Expanded(child: scaffold),
      ],
    );
  }

  List<_NavItem> _navigationItems(AuthController auth) {
    final items = <_NavItem>[
      const _NavItem('/', 'الرئيسية', Icons.home_outlined, selectedIcon: Icons.home_rounded, shortLabel: 'الرئيسية'),
      const _NavItem('/courses', 'استكشاف الكورسات', Icons.auto_stories_outlined, selectedIcon: Icons.auto_stories_rounded, shortLabel: 'الكورسات'),
    ];

    if (!auth.isAuthenticated) {
      items.add(const _NavItem('/login', 'تسجيل الدخول', Icons.login_rounded, shortLabel: 'الدخول'));
      return items;
    }

    if (!auth.isAdmin) {
      items.add(const _NavItem('/enrollments', 'كورساتي', Icons.play_circle_outline_rounded, selectedIcon: Icons.play_circle_rounded, shortLabel: 'كورساتي'));
    }

    if (auth.isInstructor && !auth.isAdmin) {
      items.add(const _NavItem('/manage/courses', 'إدارة الكورسات', Icons.dashboard_customize_outlined, selectedIcon: Icons.dashboard_customize_rounded, shortLabel: 'الإدارة'));
    }

    if (auth.isAdmin) {
      items.addAll(const [
        _NavItem('/admin/users', 'إدارة المستخدمين', Icons.group_outlined, selectedIcon: Icons.group_rounded, shortLabel: 'المستخدمون'),
        _NavItem('/admin/enrollments', 'إدارة التسجيلات', Icons.fact_check_outlined, selectedIcon: Icons.fact_check_rounded, shortLabel: 'التسجيلات'),
      ]);
    }

    items.add(const _NavItem('/profile', 'حسابي', Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, shortLabel: 'حسابي'));
    return items;
  }

  List<_NavItem> _primaryItems(List<_NavItem> items, AuthController auth) {
    final preferredPaths = !auth.isAuthenticated
        ? const ['/', '/courses', '/login']
        : auth.isAdmin
            ? const ['/', '/courses', '/admin/users', '/profile']
            : auth.isInstructor
                ? const ['/', '/courses', '/manage/courses', '/profile']
                : const ['/', '/courses', '/enrollments', '/profile'];
    return [for (final path in preferredPaths) items.firstWhere((item) => item.path == path)];
  }

  int _selectedIndex(List<_NavItem> items, String path) {
    for (var index = 0; index < items.length; index++) {
      final candidate = items[index].path;
      if (candidate == '/' ? path == '/' : path.startsWith(candidate)) return index;
    }
    return 0;
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({required this.auth, required this.path, required this.items});

  final AuthController auth;
  final String path;
  final List<_NavItem> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: _IdentityCard(auth: auth),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text('التنقل', style: TextStyle(color: AppTheme.muted, fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in items)
                  _NavigationTile(
                    item: item,
                    active: item.path == '/' ? path == '/' : path.startsWith(item.path),
                    onTap: () {
                      Navigator.of(context).maybePop();
                      context.go(item.path);
                    },
                  ),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), foregroundColor: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final name = auth.session?.fullName.trim();
    final role = auth.session?.role ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: Colors.white.withValues(alpha: .08)),
                ),
                child: Icon(auth.isAuthenticated ? Icons.person_rounded : Icons.explore_rounded, color: Colors.white),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.isAuthenticated ? (name?.isNotEmpty == true ? name! : 'حسابي') : 'منصة المعرفة', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                    const SizedBox(height: 3),
                    Text(auth.isAuthenticated ? _roleLabel(role) : 'تعلم من أي جهاز وفي أي وقت', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role.toLowerCase()) {
    'admin' => 'مدير النظام',
    'instructor' => 'مدرّس',
    _ => 'طالب',
  };
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({required this.item, required this.active, required this.onTap});

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: ListTile(
      onTap: onTap,
      selected: active,
      leading: Icon(active ? (item.selectedIcon ?? item.icon) : item.icon),
      title: Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      trailing: active ? const Icon(Icons.arrow_back_ios_new_rounded, size: 13) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      selectedColor: AppTheme.blue,
      selectedTileColor: AppTheme.blue.withValues(alpha: .075),
      iconColor: AppTheme.muted,
      textColor: AppTheme.text,
      minTileHeight: 52,
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 38 : 42,
        height: compact ? 38 : 42,
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 22),
      ),
      const SizedBox(width: 9),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(compact ? 'المعرفة' : 'منصة المعرفة', style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900, fontSize: 16)),
          if (!compact) const Text('تعلّم. طبّق. تقدّم.', style: TextStyle(color: AppTheme.muted, fontSize: 9, fontWeight: FontWeight.w700)),
        ],
      ),
    ],
  );
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final name = auth.session?.fullName.trim() ?? 'حسابي';
    return ActionChip(
      avatar: CircleAvatar(backgroundColor: AppTheme.blue.withValues(alpha: .12), child: Text(name.isEmpty ? 'م' : name.substring(0, 1), style: const TextStyle(color: AppTheme.blue, fontSize: 11, fontWeight: FontWeight.w900))),
      label: Text(name.isEmpty ? 'حسابي' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () => context.go('/profile'),
    );
  }
}

class _NavItem {
  const _NavItem(this.path, this.label, this.icon, {this.selectedIcon, this.shortLabel});
  final String path;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? shortLabel;
}
