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
    var enrolled = false;
    if (auth.isAuthenticated) {
      try {
        final enrollments = await api.getMyEnrollments();
        enrolled = enrollments.any((item) => item.courseId == widget.courseId);
      } catch (_) {
        enrolled = false;
      }
    }

    var assets = const <CourseAsset>[];
    var assetsForbidden = false;
    if (auth.isAuthenticated) {
      try {
        assets = await api.getCourseAssets(widget.courseId);
      } on ApiException catch (error) {
        assetsForbidden = error.statusCode == 403;
      }
    }

    return _CourseDetailsData(
      course: course,
      enrolled: enrolled,
      assets: assets,
      assetsForbidden: assetsForbidden,
    );
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
        _future = _load();
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
              const SizedBox(height: 26),
              _CourseAssetsSection(data: data),
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
              const Expanded(
                child: Text(
                  'الفيديوهات والمرفقات تظهر بعد التسجيل في الكورس.',
                  style: TextStyle(color: AppTheme.muted, height: 1.6),
                ),
              ),
              if (!data.enrolled)
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
              'فيديوهات ومرفقات محفوظة محليًا على الخادم ولا تظهر إلا للمستخدم المصرح له.',
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
                  'لم تتم إضافة ملفات لهذا الكورس بعد.',
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
          'تعذر تشغيل ${widget.asset.originalFileName}. استخدم زر التنزيل من إدارة الملفات.',
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
    required this.assets,
    required this.assetsForbidden,
  });

  final Course course;
  final bool enrolled;
  final List<CourseAsset> assets;
  final bool assetsForbidden;
}
