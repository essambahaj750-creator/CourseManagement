import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final session = auth.session;
    if (session == null) return const SizedBox.shrink();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'مساحتك الشخصية',
                style: TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'حسابي',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: AppTheme.blue.withValues(alpha: .12),
                        child: Text(
                          session.fullName.isEmpty
                              ? 'م'
                              : session.fullName.substring(0, 1),
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        session.fullName,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        session.email,
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cyan.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'الدور: ${session.role}',
                          style: const TextStyle(
                            color: AppTheme.cyan,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.badge_outlined,
                        color: AppTheme.blue,
                      ),
                      title: const Text('معرّف المستخدم'),
                      subtitle: Text('${session.userId}'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.schedule_rounded,
                        color: AppTheme.blue,
                      ),
                      title: const Text('صلاحية الجلسة'),
                      subtitle: Text(
                        'حتى ${session.expiresAtUtc.toLocal().toString().split('.').first}',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) context.go('/login');
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('تسجيل الخروج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
