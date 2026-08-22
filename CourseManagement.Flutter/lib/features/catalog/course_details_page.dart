import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CourseDetailsPage extends StatefulWidget {
  const CourseDetailsPage({required this.courseId, super.key});

  final int courseId;

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage> {
  late Future<_CourseDetailsData> _future;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CourseDetailsData> _load() async {
    final api = context.read<ApiClient>();
    final course = await api.getCourse(widget.courseId);
    try {
      final enrollments = await api.getMyEnrollments();
      return _CourseDetailsData(
        course: course,
        enrolled: enrollments.any((item) => item.courseId == widget.courseId),
      );
    } catch (_) {
      return _CourseDetailsData(course: course, enrolled: false);
    }
  }

  Future<void> _toggleEnrollment(_CourseDetailsData data) async {
    setState(() => _actionBusy = true);
    try {
      if (data.enrolled) {
        await context.read<ApiClient>().unenroll(widget.courseId);
      } else {
        await context.read<ApiClient>().enroll(widget.courseId);
      }
      if (!mounted) return;
      setState(() {
        _actionBusy = false;
        _future = Future.value(
          _CourseDetailsData(course: data.course, enrolled: !data.enrolled),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data.enrolled ? 'تم إلغاء التسجيل.' : 'تم تسجيلك في الكورس بنجاح.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _actionBusy = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_CourseDetailsData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return PageContainer(
            child: ErrorState(
              message: snapshot.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }

        final data = snapshot.data!;
        final course = data.course;
        return PageContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  const Text(
                    'تفاصيل الكورس',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth > 760;
                  final cover = ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: CourseCover(
                      course: course,
                      height: wide ? 360 : 230,
                    ),
                  );
                  final information = _CourseInformation(
                    data: data,
                    actionBusy: _actionBusy,
                    onToggle: () => _toggleEnrollment(data),
                    wide: wide,
                  );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: cover),
                        const SizedBox(width: 28),
                        Expanded(flex: 6, child: information),
                      ],
                    );
                  }
                  return Column(
                    children: [cover, const SizedBox(height: 22), information],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CourseInformation extends StatelessWidget {
  const _CourseInformation({
    required this.data,
    required this.actionBusy,
    required this.onToggle,
    required this.wide,
  });

  final _CourseDetailsData data;
  final bool actionBusy;
  final VoidCallback onToggle;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final course = data.course;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.cyan.withValues(alpha: .11),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Text(
            'مسار تعليمي عملي',
            style: TextStyle(
              color: AppTheme.cyan,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          course.title,
          style: const TextStyle(
            color: AppTheme.ink,
            fontSize: 30,
            height: 1.4,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          course.description.isEmpty
              ? 'مسار مصمم لتطوير مهاراتك خطوة بخطوة.'
              : course.description,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.9,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.blue.withValues(alpha: .12),
              child: Text(
                course.instructorName.isEmpty
                    ? 'م'
                    : course.instructorName.substring(0, 1),
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المدرّس',
                  style: TextStyle(color: AppTheme.muted, fontSize: 10),
                ),
                Text(
                  course.instructorName,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'قيمة المسار',
                        style: TextStyle(color: AppTheme.muted, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.price == 0
                            ? 'مجاني'
                            : '${course.price.toStringAsFixed(2)} ر.س',
                        style: const TextStyle(
                          color: AppTheme.blue,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: wide ? 220 : 160,
                  child: ElevatedButton.icon(
                    onPressed: actionBusy ? null : onToggle,
                    icon: actionBusy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            data.enrolled
                                ? Icons.remove_circle_outline_rounded
                                : Icons.add_task_rounded,
                          ),
                    label: Text(data.enrolled ? 'إلغاء التسجيل' : 'سجّل الآن'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseDetailsData {
  const _CourseDetailsData({required this.course, required this.enrolled});

  final Course course;
  final bool enrolled;
}
