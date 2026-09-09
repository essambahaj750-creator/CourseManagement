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
    var assetsForbidden = !isAuthenticated;
    if (isAuthenticated) {
      try {
        assets = await api.getCourseAssets(widget.courseId);
        assetsForbidden = false;
      } on ApiException catch (error) {
        assetsForbidden = error.statusCode == 403;
      }
    }

    return _CourseDetailsData(
      course: course,
      enrolled: enrolled,
      curriculum: curriculum,
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
              const SizedBox(height: 26),
              if (data.assetsForbidden) ...[
                _PublicPreviewPlayer(courseId: course.id),
                const SizedBox(height: 18),
              ],
              _CourseHighlights(data: data),
              const SizedBox(height: 18),
              _CurriculumSection(data: data),
              if (!data.assetsForbidden) ...[
                const SizedBox(height: 18),
                _CourseAssetsSection(data: data),
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

                final action = data.isOwner
                    ? FilledButton.tonalIcon(
                        onPressed: null,
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('إدارة الكورس'),
                      )
                    : FilledButton.icon(
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
                                !data.isAuthenticated
                                    ? Icons.person_add_alt_1_rounded
                                    : data.enrolled
                                    ? Icons.remove_circle_outline_rounded
                                    : Icons.add_task_rounded,
                              ),
                        label: Text(
                          !data.isAuthenticated
                              ? 'أنشئ حسابًا للتسجيل'
                              : data.enrolled
                              ? 'إلغاء التسجيل'
                              : 'ابدأ التسجيل',
                        ),
                      );

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

class _CourseAssetsSection extends StatefulWidget {
  const _CourseAssetsSection({required this.data});

  final _CourseDetailsData data;

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

    final assets = data.assets;
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
                const Expanded(
                  child: Text(
                    'محتوى الكورس',
                    style: TextStyle(
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
            const Text(
              'فيديوهات ومرفقات محمية ولا تظهر إلا للمستخدم المصرح له.',
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
  const _ProtectedVideoPlayer({required this.courseId, required this.asset});

  final int courseId;
  final CourseAsset asset;

  @override
  State<_ProtectedVideoPlayer> createState() => _ProtectedVideoPlayerState();
}

class _ProtectedVideoPlayerState extends State<_ProtectedVideoPlayer> {
  VideoPlayerController? _controller;
  late final Future<void> _initializeFuture;

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
  }

  @override
  void dispose() {
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
    required this.assets,
    required this.assetsForbidden,
    required this.isAuthenticated,
    required this.isOwner,
  });

  final Course course;
  final bool enrolled;
  final List<CourseCurriculumItem> curriculum;
  final List<CourseAsset> assets;
  final bool assetsForbidden;
  final bool isAuthenticated;
  final bool isOwner;
}
