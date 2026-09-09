import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class EnrollmentsPage extends StatefulWidget {
  const EnrollmentsPage({super.key});

  @override
  State<EnrollmentsPage> createState() => _EnrollmentsPageState();
}

class _EnrollmentsPageState extends State<EnrollmentsPage> {
  late Future<List<Enrollment>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().getMyEnrollments();
  }

  void _refresh() {
    setState(() => _future = context.read<ApiClient>().getMyEnrollments());
  }

  Future<void> _remove(Enrollment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.danger),
        title: const Text('إلغاء التسجيل؟'),
        content: Text('ستتم إزالة «${item.courseTitle}» من مسارك التعليمي. يمكنك التسجيل فيه مجددًا لاحقًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('إلغاء التسجيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ApiClient>().unenroll(item.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء التسجيل بنجاح.')),
      );
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdaptivePageHeader(
            eyebrow: 'مساري التعليمي',
            title: 'تسجيلاتي',
            subtitle: 'كل الكورسات التي اخترتها محفوظة هنا لتعود إليها وتكمل تعلّمك في أي وقت.',
            icon: Icons.fact_check_rounded,
            action: OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تحديث'),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<Enrollment>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(label: 'جاري تجهيز مسارك التعليمي...');
              }
              if (snapshot.hasError) {
                return ErrorState(message: snapshot.error.toString(), onRetry: _refresh);
              }
              final items = snapshot.data ?? const <Enrollment>[];
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'لم تبدأ مسارك بعد',
                  message: 'استكشف الكورسات واختر أول مسار تعليمي لتظهر تسجيلاتك هنا.',
                  icon: Icons.fact_check_rounded,
                );
              }

              final averageProgress = items.isEmpty
                  ? 0
                  : items
                          .map((item) => item.progressPercent)
                          .reduce((a, b) => a + b) /
                      items.length;
              final completedCourses =
                  items.where((item) => item.isComplete).length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final cards = [
                        _SummaryCard(
                          icon: Icons.auto_stories_rounded,
                          value: '${items.length}',
                          label: 'كورسات مسجلة',
                          color: AppTheme.blue,
                        ),
                        _SummaryCard(
                          icon: Icons.insights_rounded,
                          value: '${averageProgress.toStringAsFixed(0)}%',
                          label: 'متوسط التقدّم',
                          color: AppTheme.cyan,
                        ),
                        _SummaryCard(
                          icon: Icons.workspace_premium_rounded,
                          value: '$completedCourses',
                          label: 'كورسات مكتملة',
                          color: AppTheme.success,
                        ),
                      ];
                      if (compact) {
                        return Column(
                          children: [
                            cards[0],
                            const SizedBox(height: 10),
                            cards[1],
                            const SizedBox(height: 10),
                            cards[2],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[2]),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  const SectionTitle(
                    title: 'كورساتك الحالية',
                    subtitle: 'تابع ما بدأت، أو ألغِ التسجيل من قائمة الخيارات عند الحاجة.',
                  ),
                  const SizedBox(height: 14),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EnrollmentCard(item: item, onRemove: () => _remove(item)),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.value, required this.label, required this.color});

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                  Text(value, style: const TextStyle(color: AppTheme.ink, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.item, required this.onRemove});

  final Enrollment item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final progressLabel = item.totalLessons == 0
        ? 'المحتوى قيد التجهيز'
        : item.isComplete
            ? 'مكتمل'
            : item.hasStarted
                ? 'تابعت ${item.completedLessons} من ${item.totalLessons} دروس'
                : 'جاهز للبدء';

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.courseTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: item.isComplete
                    ? AppTheme.success.withValues(alpha: .08)
                    : AppTheme.blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: item.isComplete
                      ? AppTheme.success.withValues(alpha: .14)
                      : AppTheme.blue.withValues(alpha: .10),
                ),
              ),
              child: Text(
                item.totalLessons == 0
                    ? '—'
                    : '${item.progressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  color: item.isComplete ? AppTheme.success : AppTheme.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: LinearProgressIndicator(
            value: item.totalLessons == 0
                ? 0
                : (item.progressPercent / 100).clamp(0, 1),
            minHeight: 7,
            backgroundColor: AppTheme.border,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              item.isComplete
                  ? Icons.check_circle_rounded
                  : Icons.play_circle_outline_rounded,
              size: 14,
              color: item.isComplete ? AppTheme.success : AppTheme.muted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                progressLabel,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: AppTheme.subtle,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'سجّلت في ${item.enrolledDate.day}/${item.enrolledDate.month}/${item.enrolledDate.year}',
                style: const TextStyle(
                  color: AppTheme.subtle,
                  fontSize: 9,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const _CourseIcon(),
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => context.go('/courses/${item.courseId}'),
                    icon: Icon(
                      item.hasStarted
                          ? Icons.play_arrow_rounded
                          : Icons.rocket_launch_rounded,
                    ),
                    label: Text(
                      item.hasStarted ? 'متابعة التعلّم' : 'ابدأ التعلّم',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                    ),
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('إلغاء التسجيل'),
                  ),
                ],
              )
            : Row(
                children: [
                  const _CourseIcon(),
                  const SizedBox(width: 14),
                  Expanded(child: details),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () => context.go('/courses/${item.courseId}'),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      item.hasStarted ? 'متابعة' : 'ابدأ',
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    onPressed: onRemove,
                    tooltip: 'إلغاء التسجيل',
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _CourseIcon extends StatelessWidget {
  const _CourseIcon();

  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    decoration: BoxDecoration(
      gradient: AppTheme.accentGradient,
      borderRadius: BorderRadius.circular(17),
      boxShadow: AppTheme.softShadow,
    ),
    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
  );
}
