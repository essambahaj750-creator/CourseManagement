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
      extendBody: mobile,
      appBar: AppBar(
        toolbarHeight: mobile ? 66 : 76,
        titleSpacing: mobile ? 12 : 22,
        title: _Brand(compact: mobile),
        actions: [
          if (!mobile)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: OutlinedButton.icon(
                onPressed: () => context.go('/courses'),
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('استكشف'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
          if (!mobile && auth.isAuthenticated)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: _AccountChip(auth: auth),
            ),
          if (!mobile && !auth.isAuthenticated)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text('تسجيل الدخول'),
              ),
            ),
          if (!desktop)
            Builder(
              builder: (context) => Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: _TopActionButton(
                  tooltip: 'القائمة',
                  icon: Icons.menu_rounded,
                  onTap: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.border),
        ),
      ),
      drawer: desktop
          ? null
          : Drawer(
              width: 314,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.horizontal(
                  end: Radius.circular(28),
                ),
              ),
              child: _NavigationPanel(auth: auth, path: path, items: items),
            ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9FBFF),
              AppTheme.background,
              Color(0xFFF4F8FB),
            ],
          ),
        ),
        child: SafeArea(child: child),
      ),
      bottomNavigationBar: mobile
          ? _FloatingBottomNavigation(
              items: primaryItems,
              selectedIndex: selectedPrimary,
              onSelected: (index) => context.go(primaryItems[index].path),
            )
          : null,
    );

    if (!desktop) return scaffold;

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        SizedBox(
          width: 276,
          child: Material(
            color: const Color(0xFFFBFCFF),
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
      const _NavItem(
        '/',
        'الرئيسية',
        Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        shortLabel: 'الرئيسية',
      ),
      const _NavItem(
        '/courses',
        'استكشاف الكورسات',
        Icons.auto_stories_outlined,
        selectedIcon: Icons.auto_stories_rounded,
        shortLabel: 'الكورسات',
      ),
    ];

    if (!auth.isAuthenticated) {
      items.add(
        const _NavItem(
          '/login',
          'تسجيل الدخول',
          Icons.login_rounded,
          shortLabel: 'الدخول',
        ),
      );
      return items;
    }

    if (!auth.isAdmin) {
      items.add(
        const _NavItem(
          '/enrollments',
          'كورساتي',
          Icons.play_circle_outline_rounded,
          selectedIcon: Icons.play_circle_rounded,
          shortLabel: 'كورساتي',
        ),
      );
    }

    if (auth.isInstructor && !auth.isAdmin) {
      items.add(
        const _NavItem(
          '/manage/courses',
          'إدارة الكورسات',
          Icons.dashboard_customize_outlined,
          selectedIcon: Icons.dashboard_customize_rounded,
          shortLabel: 'الإدارة',
        ),
      );
    }

    if (auth.isAdmin) {
      items.addAll(const [
        _NavItem(
          '/admin/users',
          'إدارة المستخدمين',
          Icons.group_outlined,
          selectedIcon: Icons.group_rounded,
          shortLabel: 'المستخدمون',
        ),
        _NavItem(
          '/admin/enrollments',
          'إدارة التسجيلات',
          Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check_rounded,
          shortLabel: 'التسجيلات',
        ),
      ]);
    }

    items.add(
      const _NavItem(
        '/profile',
        'حسابي',
        Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        shortLabel: 'حسابي',
      ),
    );
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
    return [
      for (final path in preferredPaths)
        items.firstWhere((item) => item.path == path),
    ];
  }

  int _selectedIndex(List<_NavItem> items, String path) {
    for (var index = 0; index < items.length; index++) {
      final candidate = items[index].path;
      if (candidate == '/' ? path == '/' : path.startsWith(candidate)) {
        return index;
      }
    }
    return 0;
  }
}

class _NavigationPanel extends StatelessWidget {
  const _NavigationPanel({
    required this.auth,
    required this.path,
    required this.items,
  });

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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 15,
                    color: AppTheme.blue,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'التنقل الرئيسي',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (final item in items)
                  _NavigationTile(
                    item: item,
                    active: item.path == '/'
                        ? path == '/'
                        : path.startsWith(item.path),
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
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: AppTheme.danger,
                  backgroundColor: AppTheme.danger.withValues(alpha: .035),
                  side: BorderSide(
                    color: AppTheme.danger.withValues(alpha: .15),
                  ),
                ),
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
    final displayName = auth.isAuthenticated
        ? (name?.isNotEmpty == true ? name! : 'حسابي')
        : 'منصة المعرفة';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -28,
            end: -20,
            child: Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan.withValues(alpha: .13),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -40,
            start: -28,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.blue.withValues(alpha: .16),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .10),
                      ),
                    ),
                    child: Icon(
                      auth.isAuthenticated
                          ? Icons.person_rounded
                          : Icons.school_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          auth.isAuthenticated
                              ? _roleLabel(role)
                              : 'تعلّم. طبّق. تقدّم.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      auth.isAuthenticated
                          ? Icons.verified_user_rounded
                          : Icons.auto_awesome_rounded,
                      color: const Color(0xFFB9FFF2),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      auth.isAuthenticated
                          ? 'جلسة آمنة'
                          : 'تجربة تعلّم حديثة',
                      style: const TextStyle(
                        color: Color(0xFFDAFFF8),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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
  const _NavigationTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.blue.withValues(alpha: .075)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active
                  ? AppTheme.blue.withValues(alpha: .10)
                  : Colors.transparent,
            ),
          ),
          child: ListTile(
            onTap: onTap,
            selected: active,
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: active
                    ? AppTheme.blue.withValues(alpha: .11)
                    : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                active ? (item.selectedIcon ?? item.icon) : item.icon,
                size: 19,
              ),
            ),
            title: Text(
              item.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            trailing: active
                ? Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.blue,
                      shape: BoxShape.circle,
                    ),
                  )
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            selectedColor: AppTheme.blue,
            iconColor: AppTheme.muted,
            textColor: AppTheme.text,
            minTileHeight: 54,
          ),
        ),
      );
}

class _FloatingBottomNavigation extends StatelessWidget {
  const _FloatingBottomNavigation({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 70,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFCFFFFFF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A07182F),
              blurRadius: 34,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _BottomNavItem(
                  item: items[index],
                  selected: index == selectedIndex,
                  onTap: () => onSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? (item.selectedIcon ?? item.icon) : item.icon;
    return Semantics(
      selected: selected,
      button: true,
      label: item.shortLabel ?? item.label,
      child: Tooltip(
        message: item.label,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 190),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.blue.withValues(alpha: .09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 190),
                  width: selected ? 34 : 30,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.blue.withValues(alpha: .10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: selected ? 21 : 20,
                    color: selected ? AppTheme.blue : AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.shortLabel ?? item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppTheme.blue : AppTheme.muted,
                    fontSize: 9,
                    fontWeight:
                        selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: onTap,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppTheme.ink, size: 22),
            ),
          ),
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
            width: compact ? 39 : 43,
            height: compact ? 39 : 43,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x222463EB),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                PositionedDirectional(
                  top: 6,
                  end: 7,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: Color(0xFFB9FFF2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compact ? 'المعرفة' : 'منصة المعرفة',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
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

class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final name = auth.session?.fullName.trim() ?? 'حسابي';
    final initial = name.isEmpty ? 'م' : name.substring(0, 1);
    return ActionChip(
      avatar: CircleAvatar(
        backgroundColor: AppTheme.blue.withValues(alpha: .12),
        child: Text(
          initial,
          style: const TextStyle(
            color: AppTheme.blue,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 150),
        child: Text(
          name.isEmpty ? 'حسابي' : name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      side: const BorderSide(color: AppTheme.border),
      backgroundColor: Colors.white,
      onPressed: () => context.go('/profile'),
    );
  }
}

class _NavItem {
  const _NavItem(
    this.path,
    this.label,
    this.icon, {
    this.selectedIcon,
    this.shortLabel,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData? selectedIcon;
  final String? shortLabel;
}
