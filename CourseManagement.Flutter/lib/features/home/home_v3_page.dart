import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';
import '../auth/auth_controller.dart';

class HomeV3Page extends StatefulWidget {
  const HomeV3Page({super.key});

  @override
  State<HomeV3Page> createState() => _HomeV3PageState();
}

class _HomeV3PageState extends State<HomeV3Page> {
  late Future<CourseCatalog> _courses;

  @override
  void initState() {
    super.initState();
    _courses = _load();
  }

  Future<CourseCatalog> _load() => context.read<ApiClient>().searchCourses(
        const CourseFilter(pageSize: 6, sort: 'newest'),
      );

  void _retry() => setState(() => _courses = _load());

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final width = MediaQuery.sizeOf(context).width;
    final mobile = AppBreakpoints.isMobile(width);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(auth: auth, mobile: mobile),
          SizedBox(height: mobile ? 16 : 24),
          _QuickActions(auth: auth),
          SizedBox(height: mobile ? 26 : 36),
          SectionTitle(
            title: 'أحدث الكورسات',
            subtitle: 'ابدأ من المحتوى المضاف حديثًا',
            action: TextButton(
              onPressed: () => context.go('/courses'),
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<CourseCatalog>(
            future: _courses,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(label: 'جاري تجهيز الكورسات...');
              }
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString(), onRetry: _retry);
              }
              final items = snapshot.data?.items ?? const <Course>[];
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'لا توجد كورسات منشورة بعد',
                  message: 'ستظهر الكورسات هنا بمجرد نشر أول محتوى.',
                  icon: Icons.auto_stories_rounded,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 620
                          ? 2
                          : 1;
                  const gap = 14.0;
                  final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final course in items)
                        SizedBox(
                          width: itemWidth,
                          child: _CourseCard(course: course),
                        ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.auth, required this.mobile});

  final AuthController auth;
  final bool mobile;

  @override
  Widget build(BuildContext context) {
    final firstName = (auth.session?.fullName.trim().split(' ').firstOrNull ?? '').trim();
    final headline = auth.isAdmin
        ? 'أدر المنصة من مكان واحد'
        : auth.isInstructor
            ? 'ابنِ تجربة تعليمية يستفيد منها طلابك'
            : auth.isAuthenticated
                ? 'أكمل رحلتك التعليمية${firstName.isEmpty ? '' : '، $firstName'}'
                : 'تعلّم مهارة جديدة بطريقة أبسط';
    final subtitle = auth.isAdmin
        ? 'تابع المستخدمين والتسجيلات والكورسات بصلاحيات واضحة.'
        : auth.isInstructor
            ? 'أنشئ كورساتك، ارفع الدروس، وراجع المحتوى قبل نشره.'
            : 'استكشف الكورسات، شاهد المعاينة، ثم سجّل وابدأ التعلّم.';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(mobile ? 20 : 30),
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient,
        borderRadius: BorderRadius.circular(mobile ? 24 : 32),
        boxShadow: AppTheme.elevatedShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              auth.isAdmin ? 'لوحة الإدارة' : auth.isInstructor ? 'مساحة المدرّس' : 'منصة المعرفة',
              style: const TextStyle(color: Color(0xFFB9FFF2), fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            headline,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 25 : 34,
              height: 1.35,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Text(
              subtitle,
              style: TextStyle(color: Colors.white.withValues(alpha: .74), fontSize: mobile ? 12 : 14, height: 1.8),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => context.go(auth.isAdmin ? '/admin/users' : auth.isInstructor ? '/manage/courses' : '/courses'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.blue),
                icon: Icon(auth.isAdmin ? Icons.admin_panel_settings_rounded : auth.isInstructor ? Icons.dashboard_customize_rounded : Icons.explore_rounded),
                label: Text(auth.isAdmin ? 'إدارة المستخدمين' : auth.isInstructor ? 'إدارة كورساتي' : 'استكشف الكورسات'),
              ),
              if (!auth.isAuthenticated)
                OutlinedButton.icon(
                  onPressed: () => context.go('/register'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: .35))),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('إنشاء حساب'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final actions = auth.isAdmin
        ? const [
            _ActionData('المستخدمون', 'إدارة الحسابات والصلاحيات', Icons.group_rounded, '/admin/users'),
            _ActionData('التسجيلات', 'متابعة تسجيل الطلاب', Icons.fact_check_rounded, '/admin/enrollments'),
            _ActionData('الكتالوج', 'مراجعة واجهة الكورسات', Icons.auto_stories_rounded, '/courses'),
          ]
        : auth.isInstructor
            ? const [
                _ActionData('كورساتي', 'إنشاء وتعديل المحتوى', Icons.dashboard_customize_rounded, '/manage/courses'),
                _ActionData('الكتالوج', 'شاهد تجربة الطالب', Icons.visibility_rounded, '/courses'),
                _ActionData('حسابي', 'بيانات الحساب', Icons.person_rounded, '/profile'),
              ]
            : auth.isAuthenticated
                ? const [
                    _ActionData('كورساتي', 'تابع ما سجلت فيه', Icons.play_circle_rounded, '/enrollments'),
                    _ActionData('استكشف', 'اعثر على كورس جديد', Icons.explore_rounded, '/courses'),
                    _ActionData('حسابي', 'إدارة بياناتك', Icons.person_rounded, '/profile'),
                  ]
                : const [
                    _ActionData('استكشف', 'تصفح جميع الكورسات', Icons.explore_rounded, '/courses'),
                    _ActionData('دخول', 'تابع تعلمك من أي جهاز', Icons.login_rounded, '/login'),
                    _ActionData('حساب جديد', 'ابدأ خلال دقيقة', Icons.person_add_alt_1_rounded, '/register'),
                  ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 1;
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final action in actions) SizedBox(width: width, child: _ActionCard(data: action))],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.data});
  final _ActionData data;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => context.go(data.path),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppTheme.blue.withValues(alpha: .09), borderRadius: BorderRadius.circular(15)),
                  child: Icon(data.icon, color: AppTheme.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data.title, style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 10)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.muted, size: 14),
              ],
            ),
          ),
        ),
      );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/courses/${course.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CourseCover(course: course, height: 170),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontSize: 15, height: 1.45, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 7),
                    Text(course.instructorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.play_circle_outline_rounded, color: AppTheme.blue, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(child: Text('تفاصيل ومعاينة', style: TextStyle(color: AppTheme.blue, fontSize: 11, fontWeight: FontWeight.w800))),
                        Text(course.price == 0 ? 'مجاني' : '${course.price.toStringAsFixed(0)} ر.س', style: const TextStyle(color: AppTheme.ink, fontSize: 13, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ActionData {
  const _ActionData(this.title, this.subtitle, this.icon, this.path);
  final String title;
  final String subtitle;
  final IconData icon;
  final String path;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
