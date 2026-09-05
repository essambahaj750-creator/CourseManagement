import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../widgets/ui.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = auth.session;
    if (session == null) return const SizedBox.shrink();

    return PageContainer(
      maxWidth: 900,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdaptivePageHeader(
            eyebrow: 'مساحتك الشخصية',
            title: 'حسابي',
            subtitle: 'راجع بيانات حسابك وإدارة حسابك من مكان واحد.',
            icon: Icons.person_rounded,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppTheme.brandGradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: AppTheme.softShadow,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final avatar = Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white.withValues(alpha: .15)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    session.fullName.isEmpty ? 'م' : session.fullName.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 31,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
                final info = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      session.email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white.withValues(alpha: .12)),
                      ),
                      child: Text(
                        'الدور: ${session.role}',
                        style: const TextStyle(
                          color: Color(0xFFB9FFF2),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [avatar, const SizedBox(height: 16), info],
                  );
                }

                return Row(
                  children: [avatar, const SizedBox(width: 18), Expanded(child: info)],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          _InfoCard(
            icon: Icons.badge_outlined,
            title: 'معرّف المستخدم',
            value: '${session.userId}',
            helper: 'رقم حسابك داخل المنصة',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;
                  final copy = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إدارة الحساب',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'يمكنك تسجيل الخروج من الحساب من هنا.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  );
                  final button = OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    onPressed: () async {
                      await auth.logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('تسجيل الخروج'),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [copy, const SizedBox(height: 14), button],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: copy),
                      const SizedBox(width: 18),
                      button,
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.helper,
  });

  final IconData icon;
  final String title;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.blue, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
