import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';
import '../auth/auth_controller.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<CourseCatalog> _featured;

  @override
  void initState() {
    super.initState();
    _featured = context.read<ApiClient>().searchCourses(
      const CourseFilter(pageSize: 6, sort: 'newest'),
    );
  }

  void _retry() {
    setState(() {
      _featured = context.read<ApiClient>().searchCourses(
        const CourseFilter(pageSize: 6, sort: 'newest'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final fullName = auth.session?.fullName.trim() ?? '';
    final name = fullName.isEmpty ? 'متعلم' : fullName.split(' ').first;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Hero(name: name),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 3 : 1;
              final gap = 12.0;
              final width =
                  (constraints.maxWidth - ((columns - 1) * gap)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _QuickStat(
                      icon: Icons.explore_rounded,
                      eyebrow: 'الكتالوج',
                      title: 'اكتشف كورسك التالي',
                      subtitle: 'مسارات جديدة بانتظارك',
                      color: AppTheme.blue,
                      onTap: () => context.go('/courses'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _QuickStat(
                      icon: Icons.fact_check_rounded,
                      eyebrow: 'مساري',
                      title: 'تابع تسجيلاتك',
                      subtitle: 'ارجع لما بدأت وتقدّم',
                      color: AppTheme.cyan,
                      onTap: () => context.go('/enrollments'),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _QuickStat(
                      icon: Icons.bolt_rounded,
                      eyebrow: 'الزخم',
                      title: 'حافظ على وتيرتك',
                      subtitle: 'تعلّم شيئًا صغيرًا اليوم',
                      color: AppTheme.violet,
                      onTap: () => context.go('/courses'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 34),
          SectionTitle(
            title: 'أضيف حديثًا',
            subtitle: 'محتوى جديد ومختار لتبدأ منه مباشرة',
            action: TextButton.icon(
              onPressed: () => context.go('/courses'),
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<CourseCatalog>(
            future: _featured,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 240,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _retry,
                );
              }
              final courses = snapshot.data?.items ?? const <Course>[];
              if (courses.isEmpty) {
                return const EmptyState(
                  title: 'المكتبة تستعد لك',
                  message:
                      'لا توجد كورسات منشورة بعد. عد قريبًا لاكتشاف المحتوى الجديد.',
                  icon: Icons.auto_stories_rounded,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 980
                      ? 3
                      : constraints.maxWidth >= 600
                      ? 2
                      : 1;
                  final gap = 16.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final course in courses)
                        SizedBox(
                          width: width,
                          child: _FeaturedCourse(course: course),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          const SizedBox(height: 30),
          const _LearningPromise(),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: AppTheme.brandGradient,
        boxShadow: const [
          BoxShadow(
            color: Color(0x28152C55),
            blurRadius: 34,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan.withValues(alpha: .13),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.blue.withValues(alpha: .20),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 700;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: Color(0xFFB9FFF2),
                            size: 15,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'مساحتك الشخصية للتعلّم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'مرحبًا $name،\nماذا ستتعلّم اليوم؟',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 27 : 34,
                        height: 1.35,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'اختر مسارك، تقدّم بخطوات واضحة، وارجع دائمًا إلى مكان واحد يحفظ لك رحلة التعلّم.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          height: 1.85,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => context.go('/courses'),
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('استكشف الكورسات'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/enrollments'),
                          icon: const Icon(Icons.play_circle_outline_rounded),
                          label: const Text('أكمل رحلتك'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: .04),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: .24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (compact) return content;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 6, child: content),
                    const SizedBox(width: 26),
                    const Expanded(flex: 4, child: _HeroMetric()),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: Colors.white.withValues(alpha: .12)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.trending_up_rounded,
                color: Colors.white,
                size: 25,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خطوة واحدة تكفي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'ابدأ الآن بدل انتظار الوقت المثالي',
                    style: TextStyle(
                      color: Color(0xFFCAD9EF),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            Expanded(
              child: _MiniMetric(
                value: '01',
                label: 'اختر',
                icon: Icons.touch_app_rounded,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                value: '02',
                label: 'تعلّم',
                icon: Icons.menu_book_rounded,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _MiniMetric(
                value: '03',
                label: 'طبّق',
                icon: Icons.bolt_rounded,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .09)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFFB9FFF2)),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .66),
            fontSize: 9,
          ),
        ),
      ],
    ),
  );
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B08192F),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: AppTheme.muted,
            ),
          ],
        ),
      ),
    ),
  );
}

class _FeaturedCourse extends StatelessWidget {
  const _FeaturedCourse({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      onTap: () => context.push('/courses/${course.id}'),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C08192F),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourseCover(course: course, height: 160),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.blue.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'كورس',
                          style: TextStyle(
                            color: AppTheme.blue,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF6B84A),
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      const Text(
                        'جديد',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(0xFFF0F4FA),
                        child: Icon(
                          Icons.person_rounded,
                          size: 13,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          course.instructorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.muted,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(height: 1, color: AppTheme.border),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Text(
                        'عرض التفاصيل',
                        style: TextStyle(
                          color: AppTheme.blue,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.blue,
                        size: 17,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LearningPromise extends StatelessWidget {
  const _LearningPromise();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تعلّم بطريقة أبسط وأوضح',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'صُممت المنصة لتقلل التشتيت وتضع المحتوى والتقدم والإدارة أمامك بوضوح.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.7,
              ),
            ),
          ],
        );
        final badges = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            _PromiseBadge(icon: Icons.speed_rounded, label: 'واجهة سريعة'),
            _PromiseBadge(icon: Icons.devices_rounded, label: 'Responsive'),
            _PromiseBadge(icon: Icons.verified_user_rounded, label: 'آمنة'),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 16), badges],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 18),
            badges,
          ],
        );
      },
    ),
  );
}

class _PromiseBadge extends StatelessWidget {
  const _PromiseBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: AppTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.blue),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 9,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
