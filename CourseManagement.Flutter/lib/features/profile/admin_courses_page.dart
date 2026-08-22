import 'package:flutter/material.dart';
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
        await api.createCourse(
          title: draft.title,
          description: draft.description,
          price: draft.price,
          imageUrl: draft.imageUrl,
        );
      } else {
        await api.updateCourse(
          id: course.id,
          title: draft.title,
          description: draft.description,
          price: draft.price,
          imageUrl: draft.imageUrl,
        );
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
  });

  final Course course;
  final double width;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                        onPressed: onEdit,
                        icon: const Icon(Icons.edit_rounded, size: 17),
                        label: const Text('تعديل'),
                      ),
                    ),
                    const SizedBox(width: 8),
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

class _CourseDraft {
  const _CourseDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  final String title;
  final String description;
  final double price;
  final String? imageUrl;
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
  late final TextEditingController _imageUrl;

  @override
  void initState() {
    super.initState();
    final course = widget.course;
    _title = TextEditingController(text: course?.title ?? '');
    _description = TextEditingController(text: course?.description ?? '');
    _price = TextEditingController(
      text: course == null ? '0' : course.price.toStringAsFixed(2),
    );
    _imageUrl = TextEditingController(text: course?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      _CourseDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        price: double.parse(_price.text.trim()),
        imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
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
              TextFormField(
                controller: _imageUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'رابط صورة اختياري',
                  hintText: 'https://example.com/course.jpg',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final uri = Uri.tryParse(value.trim());
                  return uri != null &&
                          (uri.scheme == 'http' || uri.scheme == 'https')
                      ? null
                      : 'يجب أن يبدأ الرابط بـ http:// أو https://';
                },
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
