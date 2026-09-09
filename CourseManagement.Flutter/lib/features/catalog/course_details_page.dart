import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
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
  final _contentKey = GlobalKey();
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_CourseDetailsData> _load() async {
    final api = context.read<ApiClient>();
    final auth = context.read<AuthController>();
    final course = await api.getCourse(widget.courseId);
    final curriculum = await api.getCourseCurriculum(widget.courseId);
    final reviews = await api.getCourseReviews(widget.courseId);
    final related = await api.getRelatedCourses(widget.courseId);
    final session = auth.session;
    final isAuthenticated = auth.isAuthenticated;
    final isOwner = session?.role == 'Admin' ||
        (session?.role == 'Instructor' && session?.userId == course.instructorId);

    var enrolled = false;
    if (isAuthenticated && !isOwner) {
      try {
        final enrollments = await api.getMyEnrollments();
        enrolled = enrollments.any((item) => item.courseId == widget.courseId);
      } catch (_) {
        enrolled = false;
      }
    }

    var assets = const <CourseAsset>[];
    CourseProgress? progress;
    var assetsForbidden = !isAuthenticated;
    if (isAuthenticated) {
      try {
        assets = await api.getCourseAssets(widget.courseId);
        assetsForbidden = false;
        if (enrolled && !isOwner) {
          progress = await api.getCourseProgress(widget.courseId);
        }
      } on ApiException catch (error) {
        assetsForbidden = error.statusCode == 403;
      }
    }

    return _CourseDetailsData(
      course: course,
      enrolled: enrolled,
      curriculum: curriculum,
      progress: progress,
      reviews: reviews,
      relatedCourses: related,
      assets: assets,
      assetsForbidden: assetsForbidden,
      isAuthenticated: isAuthenticated,
      isOwner: isOwner,
    );
  }

  Future<void> _toggleEnrollment(_CourseDetailsData data) async {
    if (!data.isAuthenticated) {
      context.go(
        Uri(
          path: '/register',
          queryParameters: {'return': '/courses/${widget.courseId}'},
        ).toString(),
      );
      return;
    }
    if (data.isOwner) return;

    if (!data.enrolled) {
      final session = context.read<AuthController>().session;
      if (session == null) return;
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _EnrollmentConfirmationSheet(
          course: data.course,
          fullName: session.fullName,
          email: session.email,
        ),
      );
      if (confirmed != true || !mounted) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('إلغاء التسجيل؟'),
          content: const Text(
            'سيتم إلغاء تسجيلك من هذا الكورس وإزالة الوصول إلى محتواه المحمي.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إلغاء التسجيل'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

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
        _future = _load();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data.enrolled
                ? 'تم إلغاء التسجيل.'
                : 'تم تسجيلك في الكورس. يمكنك البدء بالتعلّم الآن.',
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

  Future<void> _startLearning() async {
    final target = _contentKey.currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: .06,
    );
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
                    onStartLearning: _startLearning,
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
              const SizedBox(height: 26),
              if (data.assetsForbidden) ...[
                _PublicPreviewPlayer(courseId: course.id),
                const SizedBox(height: 18),
              ],
              _CourseHighlights(data: data),
              const SizedBox(height: 18),
              _CurriculumSection(data: data),
              const SizedBox(height: 18),
              _CourseReviewsSection(data: data),
              if (data.relatedCourses.isNotEmpty) ...[
                const SizedBox(height: 18),
                _RelatedCoursesSection(courses: data.relatedCourses),
              ],
              if (!data.assetsForbidden) ...[
                const SizedBox(height: 18),
                KeyedSubtree(
                  key: _contentKey,
                  child: data.isOwner
                      ? _CourseAssetsSection(data: data)
                      : Column(
                          children: [
                            _LearningWorkspace(data: data),
                            const SizedBox(height: 18),
                            _CourseAssetsSection(
                              data: data,
                              attachmentsOnly: true,
                            ),
                          ],
                        ),
                ),
              ],
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
    required this.onStartLearning,
    required this.wide,
  });

  final _CourseDetailsData data;
  final bool actionBusy;
  final VoidCallback onToggle;
  final VoidCallback onStartLearning;
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
        const SizedBox(height: 14),
        if (data.reviews.reviewCount > 0)
          Row(
            children: [
              const Icon(Icons.star_rounded, color: Color(0xFFE9A51D), size: 20),
              const SizedBox(width: 5),
              Text(
                data.reviews.averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${data.reviews.reviewCount} تقييم)',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'المدرّس',
                    style: TextStyle(color: AppTheme.muted, fontSize: 10),
                  ),
                  Text(
                    course.instructorName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactAction = constraints.maxWidth < 520;
                final price = Column(
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
                );

                final Widget action;
                if (data.isOwner) {
                  action = FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('إدارة الكورس'),
                  );
                } else if (!data.isAuthenticated) {
                  action = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: actionBusy ? null : onToggle,
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: const Text('أنشئ حسابًا للتسجيل'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.go(
                          Uri(
                            path: '/login',
                            queryParameters: {
                              'return': '/courses/${course.id}',
                            },
                          ).toString(),
                        ),
                        child: const Text('لدي حساب بالفعل'),
                      ),
                    ],
                  );
                } else if (data.enrolled) {
                  action = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: onStartLearning,
                        icon: const Icon(Icons.play_circle_fill_rounded),
                        label: const Text('ابدأ التعلّم'),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: actionBusy ? null : onToggle,
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                        ),
                        child: const Text('إلغاء التسجيل'),
                      ),
                    ],
                  );
                } else {
                  action = FilledButton.icon(
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
                        : const Icon(Icons.add_task_rounded),
                    label: const Text('ابدأ التسجيل'),
                  );
                }

                if (compactAction) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      price,
                      const SizedBox(height: 16),
                      action,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: price),
                    const SizedBox(width: 18),
                    SizedBox(width: wide ? 220 : 190, child: action),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseHighlights extends StatelessWidget {
  const _CourseHighlights({required this.data});

  final _CourseDetailsData data;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ماذا يشمل التسجيل؟',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              const _CourseBenefit(
                icon: Icons.ondemand_video_rounded,
                title: 'دروس فيديو منظمة',
                subtitle: 'تظهر الدروس الكاملة بعد التسجيل في الكورس.',
              ),
              const _CourseBenefit(
                icon: Icons.folder_zip_outlined,
                title: 'مرفقات ومواد مساعدة',
                subtitle: 'حمّل الملفات التي يضيفها المدرّس من حسابك.',
              ),
              _CourseBenefit(
                icon: data.enrolled
                    ? Icons.verified_rounded
                    : Icons.lock_outline_rounded,
                title: data.enrolled ? 'وصولك مفعّل' : 'وصول مرتبط بحسابك',
                subtitle: data.enrolled
                    ? 'أنت مسجل ويمكنك الوصول إلى المحتوى المحمي.'
                    : 'سجّل بإيميلك لتبقى الكورسات مرتبطة بحسابك على كل جهاز.',
              ),
            ],
          ),
        ),
      );
}

class _CourseBenefit extends StatelessWidget {
  const _CourseBenefit({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: .08),
                ),
              ),
              child: Icon(icon, color: AppTheme.blue, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _CurriculumSection extends StatelessWidget {
  const _CurriculumSection({required this.data});

  final _CourseDetailsData data;

  @override
  Widget build(BuildContext context) {
    final items = data.curriculum;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'محتوى الكورس',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'يمكنك الاطلاع على عناوين الدروس قبل التسجيل، بينما التشغيل الكامل محمي.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Text(
                    '${items.length} درس',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'المدرّس لم يضف دروسًا إلى المنهج بعد.',
                  style: TextStyle(color: AppTheme.muted),
                ),
              )
            else
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          '${item.position}',
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        data.assetsForbidden
                            ? Icons.lock_outline_rounded
                            : Icons.play_circle_outline_rounded,
                        color: data.assetsForbidden
                            ? AppTheme.subtle
                            : AppTheme.success,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentConfirmationSheet extends StatelessWidget {
  const _EnrollmentConfirmationSheet({
    required this.course,
    required this.fullName,
    required this.email,
  });

  final Course course;
  final String fullName;
  final String email;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'تأكيد التسجيل',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'راجع الحساب والكورس قبل إتمام التسجيل.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 18),
            _ConfirmationRow(
              icon: Icons.person_outline_rounded,
              label: 'الحساب',
              value: fullName.isEmpty ? 'حساب الطالب' : fullName,
            ),
            _ConfirmationRow(
              icon: Icons.alternate_email_rounded,
              label: 'البريد الإلكتروني',
              value: email,
            ),
            _ConfirmationRow(
              icon: Icons.menu_book_rounded,
              label: 'الكورس',
              value: course.title,
            ),
            _ConfirmationRow(
              icon: Icons.payments_outlined,
              label: 'القيمة',
              value: course.price == 0
                  ? 'مجاني'
                  : '${course.price.toStringAsFixed(2)} ر.س',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: .05),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: .09),
                ),
              ),
              child: const Text(
                'بعد التأكيد سيُربط الكورس بهذا الحساب، ويمكنك الوصول إليه من قسم «كورساتي».',
                style: TextStyle(
                  color: AppTheme.text,
                  fontSize: 10,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.verified_rounded),
              label: const Text('تأكيد التسجيل في الكورس'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ليس الآن'),
            ),
          ],
        ),
      );
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.blue, size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 105,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CertificateSheet extends StatelessWidget {
  const _CertificateSheet({required this.certificate});

  final CourseCertificate certificate;

  @override
  Widget build(BuildContext context) {
    final completed = certificate.completedAtUtc.toLocal();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        18,
        8,
        18,
        20 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.blue.withValues(alpha: .06),
              AppTheme.success.withValues(alpha: .05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'شهادة إكمال',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'تم إصدارها بعد إكمال 100% من دروس الكورس.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'تشهد منصة المعرفة بأن',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              certificate.studentName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'قد أتم بنجاح الكورس',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              certificate.courseTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 17,
                height: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 22),
            const Divider(),
            const SizedBox(height: 12),
            _CertificateInfo(
              label: 'المدرّس',
              value: certificate.instructorName.isEmpty
                  ? 'فريق المنصة'
                  : certificate.instructorName,
            ),
            _CertificateInfo(
              label: 'تاريخ الإكمال',
              value:
                  '${completed.day}/${completed.month}/${completed.year}',
            ),
            _CertificateInfo(
              label: 'رقم الشهادة',
              value: certificate.certificateCode,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check_rounded),
              label: const Text('تم'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificateInfo extends StatelessWidget {
  const _CertificateInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
}

class _RelatedCoursesSection extends StatelessWidget {
  const _RelatedCoursesSection({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'قد يناسبك أيضًا',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'كورسات مرتبطة بالمدرّس والسعر مع أولوية للأعلى تقييمًا.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 580
                          ? 2
                          : 1;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;

                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final course in courses)
                        SizedBox(
                          width: width,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () => context.push('/courses/${course.id}'),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                                border: Border.all(color: AppTheme.border),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CourseCover(course: course, height: 118),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppTheme.ink,
                                            fontSize: 12,
                                            height: 1.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            if (course.reviewCount > 0) ...[
                                              const Icon(
                                                Icons.star_rounded,
                                                color: Color(0xFFE9A51D),
                                                size: 15,
                                              ),
                                              const SizedBox(width: 3),
                                              Text(
                                                course.averageRating
                                                    .toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: AppTheme.ink,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            const Icon(
                                              Icons.people_alt_outlined,
                                              color: AppTheme.muted,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                '${course.enrolledStudents} طالب',
                                                style: const TextStyle(
                                                  color: AppTheme.muted,
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              course.price == 0
                                                  ? 'مجاني'
                                                  : '${course.price.toStringAsFixed(0)} ر.س',
                                              style: const TextStyle(
                                                color: AppTheme.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
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
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      );
}

class _CourseReviewsSection extends StatefulWidget {
  const _CourseReviewsSection({required this.data});

  final _CourseDetailsData data;

  @override
  State<_CourseReviewsSection> createState() => _CourseReviewsSectionState();
}

class _CourseReviewsSectionState extends State<_CourseReviewsSection> {
  late CourseReviewSummary _summary;
  final _comment = TextEditingController();
  int _rating = 5;
  bool _busy = false;

  int? get _viewerId => context.read<AuthController>().session?.userId;

  CourseReview? get _ownReview {
    final viewerId = _viewerId;
    if (viewerId == null) return null;
    for (final review in _summary.reviews) {
      if (review.userId == viewerId) return review;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _summary = widget.data.reviews;
    final userId = context.read<AuthController>().session?.userId;
    CourseReview? own;
    if (userId != null) {
      for (final review in _summary.reviews) {
        if (review.userId == userId) {
          own = review;
          break;
        }
      }
    }
    if (own != null) {
      _rating = own.rating;
      _comment.text = own.comment;
    }
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().saveCourseReview(
            courseId: widget.data.course.id,
            rating: _rating,
            comment: _comment.text,
          );
      final summary = await context
          .read<ApiClient>()
          .getCourseReviews(widget.data.course.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تقييمك للكورس.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _delete() async {
    if (_busy || _ownReview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف التقييم؟'),
        content: const Text('سيتم حذف تقييمك ومراجعتك لهذا الكورس.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().deleteCourseReview(widget.data.course.id);
      final summary = await context
          .read<ApiClient>()
          .getCourseReviews(widget.data.course.id);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _rating = 5;
        _comment.clear();
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canReview = widget.data.enrolled && !widget.data.isOwner;
    final ownReview = _ownReview;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final title = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التقييمات والمراجعات',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'آراء طلاب مسجلين فعليًا في الكورس.',
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );

                final score = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFAEC),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: const Color(0xFFF4E4B3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFE9A51D),
                        size: 22,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _summary.reviewCount == 0
                            ? 'لا تقييمات'
                            : '${_summary.averageRating.toStringAsFixed(1)} · ${_summary.reviewCount}',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 12), score],
                  );
                }

                return Row(
                  children: [
                    const Expanded(child: title),
                    const SizedBox(width: 16),
                    score,
                  ],
                );
              },
            ),
            if (canReview) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'شارك تجربتك',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(5, (index) {
                        final value = index + 1;
                        final selected = value <= _rating;
                        return IconButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _rating = value),
                          tooltip: '$value من 5',
                          style: IconButton.styleFrom(
                            backgroundColor: selected
                                ? const Color(0xFFFFF4D1)
                                : Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? const Color(0xFFF0D382)
                                  : AppTheme.border,
                            ),
                          ),
                          icon: Icon(
                            selected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: const Color(0xFFE9A51D),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _comment,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'مراجعتك',
                        hintText: 'ما الذي أعجبك؟ وما الذي يمكن تحسينه؟',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _save,
                            icon: _busy
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.star_rounded),
                            label: Text(
                              ownReview == null
                                  ? 'إرسال التقييم'
                                  : 'تحديث التقييم',
                            ),
                          ),
                        ),
                        if (ownReview != null) ...[
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            onPressed: _busy ? null : _delete,
                            tooltip: 'حذف تقييمي',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppTheme.danger,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (!widget.data.isAuthenticated) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppTheme.blue.withValues(alpha: .045),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppTheme.blue.withValues(alpha: .08),
                  ),
                ),
                child: const Text(
                  'يمكنك قراءة المراجعات الآن. بعد إنشاء حساب والتسجيل في الكورس ستتمكن من إضافة تقييمك.',
                  style: TextStyle(
                    color: AppTheme.text,
                    fontSize: 10,
                    height: 1.7,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (_summary.reviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'لا توجد مراجعات بعد.',
                  style: TextStyle(color: AppTheme.muted),
                ),
              )
            else
              ..._summary.reviews.take(10).map(
                (review) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppTheme.blue.withValues(alpha: .08),
                        child: Text(
                          review.userName.isEmpty
                              ? 'ط'
                              : review.userName.substring(0, 1),
                          style: const TextStyle(
                            color: AppTheme.blue,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    review.userName,
                                    style: const TextStyle(
                                      color: AppTheme.ink,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${review.updatedAtUtc.toLocal().day}/${review.updatedAtUtc.toLocal().month}/${review.updatedAtUtc.toLocal().year}',
                                  style: const TextStyle(
                                    color: AppTheme.subtle,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: List.generate(
                                5,
                                (index) => Icon(
                                  index < review.rating
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: const Color(0xFFE9A51D),
                                  size: 15,
                                ),
                              ),
                            ),
                            if (review.comment.trim().isNotEmpty) ...[
                              const SizedBox(height: 7),
                              Text(
                                review.comment,
                                style: const TextStyle(
                                  color: AppTheme.text,
                                  fontSize: 11,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PublicPreviewPlayer extends StatefulWidget {
  const _PublicPreviewPlayer({required this.courseId});

  final int courseId;

  @override
  State<_PublicPreviewPlayer> createState() => _PublicPreviewPlayerState();
}

class _PublicPreviewPlayerState extends State<_PublicPreviewPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initialize();
  }

  Future<void> _initialize() async {
    final base = ApiClient.defaultBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('$base/api/course/${widget.courseId}/preview'),
    );
    _controller = controller;
    await controller.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.play_circle_outline_rounded, color: AppTheme.cyan),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'معاينة مجانية',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'شاهد المقطع الذي اختاره المدرّس قبل التسجيل. فيديوهات الدروس الكاملة تبقى محمية.',
            style: TextStyle(color: AppTheme.muted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          FutureBuilder<void>(
            future: _initializeFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError || _controller == null) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'لم يضف المدرّس مقطع معاينة لهذا الكورس بعد.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                );
              }
              final controller = _controller!;
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio == 0
                          ? 16 / 9
                          : controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        setState(() {
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        });
                      },
                      icon: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (_, value, _) => Icon(
                          value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _LearningWorkspace extends StatefulWidget {
  const _LearningWorkspace({required this.data});

  final _CourseDetailsData data;

  @override
  State<_LearningWorkspace> createState() => _LearningWorkspaceState();
}

class _LearningWorkspaceState extends State<_LearningWorkspace> {
  late CourseProgress _progress;
  int? _selectedAssetId;
  bool _syncing = false;

  List<CourseAsset> get _videos {
    final videos = widget.data.assets.where((asset) => asset.isVideo).toList();
    final positions = {
      for (final lesson in widget.data.curriculum) lesson.id: lesson.position,
    };
    videos.sort(
      (a, b) => (positions[a.id] ?? 999999).compareTo(
        positions[b.id] ?? 999999,
      ),
    );
    return videos;
  }

  @override
  void initState() {
    super.initState();
    final videos = _videos;
    _progress = widget.data.progress ??
        CourseProgress(
          courseId: widget.data.course.id,
          lastLessonAssetId: null,
          completedLessonAssetIds: const [],
          completedCount: 0,
          totalLessons: videos.length,
          progressPercent: 0,
          lastAccessedAtUtc: null,
        );

    final ids = videos.map((item) => item.id).toSet();
    final last = _progress.lastLessonAssetId;
    if (last != null && ids.contains(last) && !_progress.isCompleted(last)) {
      _selectedAssetId = last;
    } else {
      final lastIndex = last == null
          ? -1
          : videos.indexWhere((item) => item.id == last);
      final ordered = lastIndex >= 0
          ? [...videos.skip(lastIndex + 1), ...videos.take(lastIndex + 1)]
          : videos;
      for (final video in ordered) {
        if (!_progress.isCompleted(video.id)) {
          _selectedAssetId = video.id;
          break;
        }
      }
      _selectedAssetId ??= videos.isEmpty ? null : videos.first.id;
    }
  }

  String _lessonTitle(CourseAsset asset) {
    for (final item in widget.data.curriculum) {
      if (item.id == asset.id) return item.title;
    }
    return asset.originalFileName;
  }

  Future<void> _syncLesson(
    int assetId, {
    required bool completed,
    bool moveNext = false,
  }) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final progress = await context.read<ApiClient>().updateCourseProgress(
            courseId: widget.data.course.id,
            assetId: assetId,
            completed: completed,
          );
      if (!mounted) return;

      int? nextId;
      if (moveNext) {
        final videos = _videos;
        final currentIndex = videos.indexWhere((item) => item.id == assetId);
        if (currentIndex >= 0 && currentIndex + 1 < videos.length) {
          nextId = videos[currentIndex + 1].id;
        }
      }

      setState(() {
        _progress = progress;
        _syncing = false;
        if (nextId != null) _selectedAssetId = nextId;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showCertificate() async {
    try {
      final certificate = await context
          .read<ApiClient>()
          .getCourseCertificate(widget.data.course.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _CertificateSheet(certificate: certificate),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _selectLesson(CourseAsset asset) async {
    if (_selectedAssetId == asset.id) return;
    setState(() => _selectedAssetId = asset.id);
    await _syncLesson(
      asset.id,
      completed: _progress.isCompleted(asset.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _videos;
    if (videos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Text(
            'لم يضف المدرّس دروس فيديو بعد.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }

    final selected = videos.firstWhere(
      (item) => item.id == _selectedAssetId,
      orElse: () => videos.first,
    );
    final selectedIndex = videos.indexWhere((item) => item.id == selected.id);
    final selectedCompleted = _progress.isCompleted(selected.id);

    final player = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تتابع الآن',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _lessonTitle(selected),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCompleted
                    ? AppTheme.success.withValues(alpha: .08)
                    : AppTheme.blue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: selectedCompleted
                      ? AppTheme.success.withValues(alpha: .14)
                      : AppTheme.blue.withValues(alpha: .10),
                ),
              ),
              child: Text(
                selectedCompleted
                    ? 'مكتمل'
                    : 'الدرس ${selectedIndex + 1} من ${videos.length}',
                style: TextStyle(
                  color: selectedCompleted ? AppTheme.success : AppTheme.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _ProtectedVideoPlayer(
          key: ValueKey(selected.id),
          courseId: widget.data.course.id,
          asset: selected,
          onEnded: () => _syncLesson(
            selected.id,
            completed: true,
            moveNext: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _syncing
                    ? null
                    : () => _syncLesson(
                          selected.id,
                          completed: !selectedCompleted,
                        ),
                icon: Icon(
                  selectedCompleted
                      ? Icons.replay_rounded
                      : Icons.check_circle_outline_rounded,
                ),
                label: Text(
                  selectedCompleted ? 'إعادة كغير مكتمل' : 'إكمال الدرس',
                ),
              ),
            ),
            if (selectedIndex + 1 < videos.length) ...[
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncing
                      ? null
                      : () => _selectLesson(videos[selectedIndex + 1]),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('الدرس التالي'),
                ),
              ),
            ],
          ],
        ),
      ],
    );

    final lessonList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'دروس الكورس',
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        ...videos.asMap().entries.map((entry) {
          final index = entry.key;
          final asset = entry.value;
          final active = asset.id == selected.id;
          final done = _progress.isCompleted(asset.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: _syncing ? null : () => _selectLesson(asset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: active
                      ? AppTheme.blue.withValues(alpha: .065)
                      : AppTheme.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: active
                        ? AppTheme.blue.withValues(alpha: .22)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: done
                            ? AppTheme.success.withValues(alpha: .09)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(
                          color: done
                              ? AppTheme.success.withValues(alpha: .15)
                              : AppTheme.border,
                        ),
                      ),
                      child: done
                          ? const Icon(
                              Icons.check_rounded,
                              color: AppTheme.success,
                              size: 18,
                            )
                          : Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppTheme.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _lessonTitle(asset),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? AppTheme.blue : AppTheme.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      active
                          ? Icons.play_circle_fill_rounded
                          : Icons.play_circle_outline_rounded,
                      color: active ? AppTheme.blue : AppTheme.subtle,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مساحة التعلّم',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'تقدّمك محفوظ تلقائيًا ويظهر على كل أجهزتك.',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_progress.progressPercent.toStringAsFixed(_progress.progressPercent % 1 == 0 ? 0 : 1)}%',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: (_progress.progressPercent / 100).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: AppTheme.border,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_progress.completedCount} من ${_progress.totalLessons} دروس مكتملة',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (_progress.totalLessons > 0 &&
                _progress.completedCount >= _progress.totalLessons) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showCertificate,
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('عرض شهادة الإكمال'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.success,
                ),
              ),
            ],
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 860) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 7, child: player),
                      const SizedBox(width: 22),
                      Expanded(flex: 4, child: lessonList),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    player,
                    const SizedBox(height: 22),
                    lessonList,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CourseAssetsSection extends StatefulWidget {
  const _CourseAssetsSection({
    required this.data,
    this.attachmentsOnly = false,
  });

  final _CourseDetailsData data;
  final bool attachmentsOnly;

  @override
  State<_CourseAssetsSection> createState() => _CourseAssetsSectionState();
}

class _CourseAssetsSectionState extends State<_CourseAssetsSection> {
  int? _busyAssetId;

  Future<void> _download(CourseAsset asset) async {
    setState(() => _busyAssetId = asset.id);
    try {
      final bytes = await context.read<ApiClient>().downloadCourseAsset(
        courseId: widget.data.course.id,
        assetId: asset.id,
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ${asset.originalFileName}',
        fileName: asset.originalFileName,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _busyAssetId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            path == null ? 'تم إلغاء الحفظ.' : 'تم حفظ الملف على جهازك.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busyAssetId = null);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (data.assetsForbidden) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: AppTheme.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.isAuthenticated
                      ? 'سجّل في الكورس للوصول إلى الفيديوهات والمرفقات الكاملة.'
                      : 'سجّل الدخول ثم سجّل في الكورس للوصول إلى الدروس والمرفقات.',
                  style: const TextStyle(color: AppTheme.muted, height: 1.6),
                ),
              ),
              const Icon(Icons.arrow_back_rounded, color: AppTheme.cyan),
            ],
          ),
        ),
      );
    }

    final assets = widget.attachmentsOnly
        ? data.assets.where((asset) => !asset.isVideo).toList(growable: false)
        : data.assets;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.folder_special_outlined, color: AppTheme.cyan),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.attachmentsOnly ? 'المرفقات والمواد' : 'محتوى الكورس',
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${assets.length} ملف',
                  style: const TextStyle(color: AppTheme.muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.attachmentsOnly
                  ? 'الملفات والمواد المساندة الخاصة بهذا الكورس.'
                  : 'فيديوهات ومرفقات محمية ولا تظهر إلا للمستخدم المصرح له.',
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            if (assets.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 22),
                child: Text(
                  'لم تتم إضافة دروس أو مرفقات لهذا الكورس بعد.',
                  style: TextStyle(color: AppTheme.muted),
                ),
              )
            else
              ...assets.map(
                (asset) => Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: asset.isVideo
                      ? _ProtectedVideoPlayer(
                          courseId: data.course.id,
                          asset: asset,
                        )
                      : ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.description_outlined,
                            color: AppTheme.blue,
                          ),
                          title: Text(
                            asset.originalFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${asset.typeLabel} • ${asset.sizeLabel}',
                          ),
                          trailing: FilledButton.tonalIcon(
                            onPressed: _busyAssetId == asset.id
                                ? null
                                : () => _download(asset),
                            icon: _busyAssetId == asset.id
                                ? const SizedBox(
                                    width: 15,
                                    height: 15,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download_outlined, size: 17),
                            label: const Text('تنزيل'),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProtectedVideoPlayer extends StatefulWidget {
  const _ProtectedVideoPlayer({
    required this.courseId,
    required this.asset,
    this.onEnded,
    super.key,
  });

  final int courseId;
  final CourseAsset asset;
  final VoidCallback? onEnded;

  @override
  State<_ProtectedVideoPlayer> createState() => _ProtectedVideoPlayerState();
}

class _ProtectedVideoPlayerState extends State<_ProtectedVideoPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initializeFuture;
  bool _reportedEnded = false;

  @override
  void initState() {
    super.initState();
    _initializeFuture = _initialize();
  }

  Future<void> _initialize() async {
    final api = context.read<ApiClient>();
    final session = await api.sessionStore.read();
    if (session == null) {
      throw const ApiException('انتهت الجلسة، يرجى تسجيل الدخول من جديد.');
    }
    final controller = VideoPlayerController.networkUrl(
      api.courseAssetDownloadUri(
        courseId: widget.courseId,
        assetId: widget.asset.id,
      ),
      httpHeaders: {'Authorization': 'Bearer ${session.token}'},
    );
    _controller = controller;
    await controller.initialize();
    controller.addListener(_handlePlayback);
  }

  void _handlePlayback() {
    final controller = _controller;
    if (controller == null || _reportedEnded || !controller.value.isInitialized) {
      return;
    }

    final duration = controller.value.duration;
    if (duration <= Duration.zero) return;

    if (controller.value.position >= duration - const Duration(milliseconds: 500)) {
      _reportedEnded = true;
      widget.onEnded?.call();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handlePlayback);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initializeFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError || _controller == null) {
        return Text(
          'تعذر تشغيل ${widget.asset.originalFileName}. يمكنك تنزيل الملف بدلًا من ذلك.',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        );
      }
      final controller = _controller!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0
                  ? 16 / 9
                  : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    controller.value.isPlaying
                        ? controller.pause()
                        : controller.play();
                  });
                },
                icon: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (_, value, _) => Icon(
                    value.isPlaying
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    color: AppTheme.blue,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${widget.asset.originalFileName} • ${widget.asset.sizeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _CourseDetailsData {
  const _CourseDetailsData({
    required this.course,
    required this.enrolled,
    required this.curriculum,
    required this.progress,
    required this.reviews,
    required this.relatedCourses,
    required this.assets,
    required this.assetsForbidden,
    required this.isAuthenticated,
    required this.isOwner,
  });

  final Course course;
  final bool enrolled;
  final List<CourseCurriculumItem> curriculum;
  final CourseProgress? progress;
  final CourseReviewSummary reviews;
  final List<Course> relatedCourses;
  final List<CourseAsset> assets;
  final bool assetsForbidden;
  final bool isAuthenticated;
  final bool isOwner;
}
