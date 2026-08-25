import 'package:flutter/material.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/auth_controller.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CourseManagementPage extends StatefulWidget {
  const CourseManagementPage({super.key});

  @override
  State<CourseManagementPage> createState() => _CourseManagementPageState();
}

class _CourseManagementPageState extends State<CourseManagementPage> {
  late Future<CourseCatalog> _future;
  late final int? _instructorId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthController>();
    _instructorId = auth.isAdmin ? null : auth.session?.userId;
    _future = _load();
  }

  Future<CourseCatalog> _load() => context.read<ApiClient>().searchCourses(
    CourseFilter(instructorId: _instructorId, page: 1, pageSize: 100),
  );

  void _refresh() => setState(() => _future = _load());

  Future<void> _openForm([Course? course]) async {
    final draft = await showDialog<_CourseDraft>(
      context: context,
      builder: (context) => _CourseFormDialog(course: course),
    );
    if (draft == null || !mounted) return;

    try {
      final api = context.read<ApiClient>();
      if (course == null) {
        final created = await api.createCourse(
          title: draft.title,
          description: draft.description,
          price: draft.price,
        );
        if (draft.coverBytes != null && draft.coverFileName != null) {
          await api.uploadCourseCover(
            courseId: created.id,
            fileName: draft.coverFileName!,
            bytes: draft.coverBytes!,
          );
        }
      } else {
        await api.updateCourse(
          id: course.id,
          title: draft.title,
          description: draft.description,
          price: draft.price,
        );
        if (draft.coverBytes != null && draft.coverFileName != null) {
          await api.uploadCourseCover(
            courseId: course.id,
            fileName: draft.coverFileName!,
            bytes: draft.coverBytes!,
          );
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            course == null
                ? 'تم إنشاء الكورس بنجاح.'
                : 'تم تحديث الكورس بنجاح.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _manageAssets(Course course) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CourseAssetsDialog(course: course),
    );
  }

  Future<void> _delete(Course course) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الكورس؟'),
        content: Text(
          'سيتم حذف «${course.title}» نهائيًا. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ApiClient>().deleteCourse(course.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تم حذف الكورس.')));
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PageContainer(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'مساحة الإدارة',
          style: TextStyle(
            color: AppTheme.cyan,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            const Expanded(
              child: Text(
                'إدارة الكورسات',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              tooltip: 'تحديث',
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.blue),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('كورس جديد'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _instructorId == null
              ? 'أنشئ وعدّل وتابع جميع الكورسات من مكان واحد.'
              : 'هذه المساحة تعرض الكورسات التي أنشأتها ويمكنك إدارتها.',
          style: const TextStyle(color: AppTheme.muted, height: 1.7),
        ),
        const SizedBox(height: 22),
        FutureBuilder<CourseCatalog>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(70),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final courses = snapshot.data?.items ?? const <Course>[];
            if (courses.isEmpty) {
              return EmptyState(
                title: 'لا توجد كورسات بعد',
                message: 'ابدأ بإضافة أول كورس ليظهر في الكتالوج مباشرة.',
                icon: Icons.auto_stories_rounded,
              );
            }
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 980
                    ? 3
                    : constraints.maxWidth >= 620
                    ? 2
                    : 1;
                final gap = 16.0;
                final cardWidth =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final course in courses)
                      _AdminCourseCard(
                        course: course,
                        width: cardWidth,
                        onEdit: () => _openForm(course),
                        onDelete: () => _delete(course),
                        onManageAssets: () => _manageAssets(course),
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

class _AdminCourseCard extends StatelessWidget {
  const _AdminCourseCard({
    required this.course,
    required this.width,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAssets,
  });

  final Course course;
  final double width;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageAssets;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourseCover(course: course, height: 145),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  course.instructorName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  course.description.isEmpty
                      ? 'لا يوجد وصف مضاف لهذا الكورس.'
                      : course.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onManageAssets,
                        icon: const Icon(Icons.folder_copy_outlined, size: 17),
                        label: const Text('الملفات'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onEdit,
                      tooltip: 'تعديل الكورس',
                      color: AppTheme.blue,
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      onPressed: onDelete,
                      tooltip: 'حذف الكورس',
                      color: AppTheme.danger,
                      icon: const Icon(Icons.delete_outline_rounded),
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

class CourseAssetsDialog extends StatefulWidget {
  const CourseAssetsDialog({required this.course, super.key});

  final Course course;

  @override
  State<CourseAssetsDialog> createState() => _CourseAssetsDialogState();
}

class _CourseAssetsDialogState extends State<CourseAssetsDialog> {
  late Future<List<CourseAsset>> _future;
  CourseAssetType _type = CourseAssetType.video;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CourseAsset>> _load() =>
      context.read<ApiClient>().getCourseAssets(widget.course.id);

  void _refresh() => setState(() => _future = _load());

  Future<void> _pickAndUpload() async {
    if (_busy) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: [
        'mp4',
        'webm',
        'mov',
        'm4v',
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'xls',
        'xlsx',
        'zip',
        'txt',
      ],
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      _showMessage('تعذر قراءة الملف من الجهاز. حاول اختيار الملف مرة أخرى.');
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().uploadCourseAsset(
        courseId: widget.course.id,
        fileName: picked.name,
        bytes: bytes,
        type: _type,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _future = _load();
      });
      _showMessage('تم رفع الملف وربطه بالكورس بنجاح.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _download(CourseAsset asset) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await context.read<ApiClient>().downloadCourseAsset(
        courseId: widget.course.id,
        assetId: asset.id,
      );
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'حفظ ${asset.originalFileName}',
        fileName: asset.originalFileName,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(
        savedPath == null ? 'تم إلغاء الحفظ.' : 'تم حفظ الملف على جهازك.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(error.toString());
    }
  }

  Future<void> _delete(CourseAsset asset) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الملف؟'),
        content: Text('سيتم حذف «${asset.originalFileName}» نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<ApiClient>().deleteCourseAsset(
        courseId: widget.course.id,
        assetId: asset.id,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _future = _load();
      });
      _showMessage('تم حذف الملف.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    return Dialog(
      child: SizedBox(
        width: screen.width > 760 ? 700 : screen.width - 32,
        height: screen.height > 760 ? 640 : screen.height - 80,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ملفات «${widget.course.title}»',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'ارفع فيديوهات ومرفقات حقيقية من جهازك. الخادم يتحقق من النوع والحجم ويحفظها خارج SQLite.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<CourseAssetType>(
                      initialValue: _type,
                      decoration: const InputDecoration(
                        labelText: 'نوع الملف',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: CourseAssetType.video,
                          child: Text('فيديو تعليمي'),
                        ),
                        DropdownMenuItem(
                          value: CourseAssetType.attachment,
                          child: Text('ملف مرفق'),
                        ),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              if (value != null) setState(() => _type = value);
                            },
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickAndUpload,
                    icon: _busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.upload_file_rounded),
                    label: const Text('اختيار ورفع'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(),
              const SizedBox(height: 6),
              const Text(
                'الملفات المرتبطة',
                style: TextStyle(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<CourseAsset>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return ErrorState(
                        message: snapshot.error.toString(),
                        onRetry: _refresh,
                      );
                    }
                    final assets = snapshot.data ?? const <CourseAsset>[];
                    if (assets.isEmpty) {
                      return const EmptyState(
                        title: 'لا توجد ملفات بعد',
                        message:
                            'اختر ملفًا من جهازك ليظهر هنا بعد نجاح الرفع.',
                        icon: Icons.folder_open_rounded,
                      );
                    }
                    return ListView.separated(
                      itemCount: assets.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final asset = assets[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            asset.isVideo
                                ? Icons.play_circle_outline_rounded
                                : Icons.description_outlined,
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
                          trailing: Wrap(
                            spacing: 0,
                            children: [
                              IconButton(
                                onPressed: _busy
                                    ? null
                                    : () => _download(asset),
                                tooltip: 'تنزيل',
                                icon: const Icon(Icons.download_outlined),
                              ),
                              IconButton(
                                onPressed: _busy ? null : () => _delete(asset),
                                tooltip: 'حذف',
                                color: AppTheme.danger,
                                icon: const Icon(Icons.delete_outline_rounded),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseDraft {
  const _CourseDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.coverFileName,
    required this.coverBytes,
  });

  final String title;
  final String description;
  final double price;
  final String? coverFileName;
  final Uint8List? coverBytes;
}

class _CourseFormDialog extends StatefulWidget {
  const _CourseFormDialog({this.course});

  final Course? course;

  @override
  State<_CourseFormDialog> createState() => _CourseFormDialogState();
}

class _CourseFormDialogState extends State<_CourseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  String? _coverFileName;
  Uint8List? _coverBytes;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _title = TextEditingController(text: course?.title ?? '');
    _description = TextEditingController(text: course?.description ?? '');
    _price = TextEditingController(
      text: course == null ? '0' : course.price.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    if (bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة صورة الغلاف من الجهاز.')),
      );
      return;
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حجم صورة الغلاف يجب ألا يتجاوز 5MB.')),
      );
      return;
    }

    setState(() {
      _coverFileName = picked.name;
      _coverBytes = bytes;
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _CourseDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: double.parse(_price.text.trim()),
        coverFileName: _coverFileName,
        coverBytes: _coverBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.course == null
                    ? 'إضافة كورس جديد'
                    : 'تعديل بيانات الكورس',
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'أدخل البيانات الأساسية، ثم احفظ لتظهر النتيجة في الكتالوج.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'عنوان الكورس *',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'اكتب عنوانًا من 3 أحرف على الأقل.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 6,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'الوصف',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                validator: (value) => value != null && value.length > 2000
                    ? 'الوصف طويل جدًا.'
                    : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'السعر',
                  suffixText: 'ر.س',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                validator: (value) {
                  final price = double.tryParse(value?.trim() ?? '');
                  if (price == null || price < 0) {
                    return 'أدخل سعرًا صحيحًا يساوي صفرًا أو أكثر.';
                  }
                  if (price > 1000000) return 'السعر يتجاوز الحد المسموح.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickCover,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _coverFileName ??
                      (widget.course?.imageUrl != null
                          ? 'اختيار صورة جديدة (يوجد غلاف حالي)'
                          : 'اختيار صورة الغلاف من الجهاز'),
                ),
              ),
              if (_coverFileName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'الصورة المختارة: $_coverFileName',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              const Text(
                'JPG أو PNG أو WebP — الحد الأقصى 5MB. اتركه فارغًا للحفاظ على الغلاف الحالي.',
                style: TextStyle(color: AppTheme.muted, fontSize: 11),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('حفظ الكورس'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
