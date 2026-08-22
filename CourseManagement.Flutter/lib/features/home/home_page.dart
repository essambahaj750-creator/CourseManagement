import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

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
          Row(
            children: [
              Expanded(
                child: _QuickStat(
                  icon: Icons.auto_stories_rounded,
                  title: 'الكتالوج',
                  value: 'استكشف الآن',
                  color: AppTheme.blue,
                  onTap: () => context.go('/courses'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickStat(
                  icon: Icons.fact_check_rounded,
                  title: 'مساري',
                  value: 'تسجيلاتي',
                  color: AppTheme.cyan,
                  onTap: () => context.go('/enrollments'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickStat(
                  icon: Icons.bolt_rounded,
                  title: 'وتيرتك',
                  value: 'مستمر',
                  color: const Color(0xFF8B63E8),
                  onTap: () => context.go('/courses'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SectionTitle(
            title: 'اختيارات حديثة',
            subtitle: 'أحدث المحتوى الذي أضيف إلى المكتبة',
            action: TextButton(
              onPressed: () => context.go('/courses'),
              child: const Text('عرض الكل'),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<CourseCatalog>(
            future: _featured,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 220,
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
                  message: 'لا توجد كورسات منشورة بعد. عد قريبًا لاكتشاف المحتوى الجديد.',
                  icon: Icons.auto_stories_rounded,
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 3
                      : constraints.maxWidth >= 560
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * 14) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
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
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.navy, AppTheme.navySoft, AppTheme.cyan],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x32152C55),
            blurRadius: 30,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'مساحة تعلمك الشخصية  ✦',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'مرحبًا $name،\nخطوتك التالية تبدأ من هنا.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.4,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'اكتشف مسارات عملية، احفظ تقدمك، وابنِ مهارة جديدة كل يوم.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .74),
                  height: 1.8,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 20),
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
                    icon: const Icon(Icons.fact_check_rounded),
                    label: const Text('تابع تسجيلاتي'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .35),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
          if (compact) return content;
          return Row(
            children: [
              Expanded(child: content),
              const SizedBox(width: 24),
              const Expanded(child: _HeroMetric()),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'جاهز للتقدم؟',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'خطوة صغيرة اليوم\nتصنع فرقًا كبيرًا غدًا.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .76),
              height: 1.7,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  const _QuickStat({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
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
}

class _FeaturedCourse extends StatelessWidget {
  const _FeaturedCourse({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CourseCover(course: course, height: 145),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    course.instructorName,
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        color: AppTheme.blue,
                        size: 18,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'التفاصيل',
                        style: TextStyle(
                          color: AppTheme.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
}
