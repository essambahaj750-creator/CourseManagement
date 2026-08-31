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
          return const PageContainer(
            child: LoadingState(label: 'جاري تحميل تفاصيل الكورس...'),
          );
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
                  IconButton.outlined(
                    onPressed: () => context.pop(),
                    tooltip: 'رجوع',
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  const SizedBox(width: 8),
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
              const SizedBox(height: 14),
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
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FactChip(
              icon: Icons.payments_outlined,
              label: course.price == 0
                  ? 'مجاني'
                  : '${course.price.toStringAsFixed(2)} ر.س',
            ),
            const _FactChip(
              icon: Icons.verified_user_outlined,
              label: 'وصول آمن',
            ),
            if (data.enrolled)
              const _FactChip(
                icon: Icons.check_circle_outline_rounded,
                label: 'مسجّل',
                highlight: true,
              ),
          ],
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: wide ? 250 : double.infinity,
          child: FilledButton.icon(
            onPressed: actionBusy ? null : onToggle,
            icon: actionBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    data.enrolled
                        ? Icons.remove_circle_outline_rounded
                        : Icons.add_circle_outline_rounded,
                  ),
            label: Text(data.enrolled ? 'إلغاء التسجيل' : 'التسجيل في الكورس'),
          ),
        ),
      ],
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: highlight
          ? AppTheme.cyan.withValues(alpha: .10)
          : AppTheme.surfaceMuted,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: highlight ? AppTheme.cyan.withValues(alpha: .18) : AppTheme.border,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: highlight ? AppTheme.cyan : AppTheme.blue),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: highlight ? AppTheme.cyan : AppTheme.ink,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
        widget.data.course.id,
        asset.id,
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ ${asset.originalFileName}',
        fileName: asset.originalFileName,
        bytes: bytes,
      );
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حفظ الملف بنجاح.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busyAssetId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final auth = context.watch<AuthController>();
    if (!auth.isAuthenticated) {
      return const _AssetNotice(
        icon: Icons.lock_outline_rounded,
        title: 'سجّل الدخول للوصول إلى محتوى الكورس',
        message: 'الفيديوهات والمرفقات التعليمية متاحة للمستخدمين المسجلين.',
      );
    }
    if (data.assetsForbidden) {
      return const _AssetNotice(
        icon: Icons.workspace_premium_outlined,
        title: 'سجّل في الكورس أولًا',
        message: 'بعد التسجيل ستظهر لك الفيديوهات والمرفقات الخاصة بهذا الكورس.',
      );
    }
    if (data.assets.isEmpty) {
      return const _AssetNotice(
        icon: Icons.video_library_outlined,
        title: 'لا يوجد محتوى مرفوع بعد',
        message: 'سيظهر محتوى الكورس هنا عندما يضيف المدرّس الفيديوهات أو المرفقات.',
      );
    }

    final videos = data.assets.where((item) => item.type == 1).toList();
    final attachments = data.assets.where((item) => item.type != 1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: 'محتوى الكورس',
          subtitle: 'شاهد الفيديوهات ونزّل الملفات التعليمية المتاحة لك.',
        ),
        const SizedBox(height: 16),
        if (videos.isNotEmpty) ...[
          _AssetGroup(
            title: 'الفيديوهات',
            icon: Icons.play_circle_fill_rounded,
            children: [
              for (final asset in videos)
                _VideoAssetCard(courseId: data.course.id, asset: asset),
            ],
          ),
          const SizedBox(height: 14),
        ],
        if (attachments.isNotEmpty)
          _AssetGroup(
            title: 'المرفقات',
            icon: Icons.attach_file_rounded,
            children: [
              for (final asset in attachments)
                _AttachmentTile(
                  asset: asset,
                  busy: _busyAssetId == asset.id,
                  onDownload: () => _download(asset),
                ),
            ],
          ),
      ],
    );
  }
}

class _AssetGroup extends StatelessWidget {
  const _AssetGroup({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.blue),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.asset,
    required this.busy,
    required this.onDownload,
  });

  final CourseAsset asset;
  final bool busy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, color: AppTheme.cyan),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              asset.originalFileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onDownload,
            tooltip: 'تنزيل',
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, color: AppTheme.blue),
          ),
        ],
      ),
    ),
  );
}

class _AssetNotice extends StatelessWidget {
  const _AssetNotice({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.blue.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: AppTheme.blue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(
                  color: AppTheme.muted,
                  height: 1.6,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _VideoAssetCard extends StatefulWidget {
  const _VideoAssetCard({required this.courseId, required this.asset});

  final int courseId;
  final CourseAsset asset;

  @override
  State<_VideoAssetCard> createState() => _VideoAssetCardState();
}

class _VideoAssetCardState extends State<_VideoAssetCard> {
  VideoPlayerController? _controller;
  bool _loading = false;
  String? _error;

  Future<void> _play() async {
    if (_controller != null) {
      setState(() {
        _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = context.read<ApiClient>().courseAssetDownloadUri(
        widget.courseId,
        widget.asset.id,
      );
      final token = await context.read<ApiClient>().readAccessToken();
      final controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: token == null ? const {} : {'Authorization': 'Bearer $token'},
      );
      await controller.initialize();
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller != null && controller.value.isInitialized)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _loading ? null : _play,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            controller?.value.isPlaying == true
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.asset.originalFileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                        if (_error != null)
                          Text(
                            _error!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.danger, fontSize: 9),
                          ),
                      ],
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
