import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final _searchController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();

  late final ApiClient _api;
  late Future<CourseCatalog> _catalogFuture;

  CourseFilter _filter = const CourseFilter();
  List<InstructorOption> _instructors = const [];
  String? _error;
  bool _loading = true;
  bool _listView = false;

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _catalogFuture = _loadCatalog(_filter);
    _loadInstructors();
  }

  Future<CourseCatalog> _loadCatalog(CourseFilter filter) async {
    setState(() {
      _filter = filter;
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.searchCourses(filter);
      if (mounted) setState(() => _loading = false);
      return result;
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
      rethrow;
    }
  }

  Future<void> _loadInstructors() async {
    try {
      final result = await _api.getInstructors();
      if (mounted) setState(() => _instructors = result);
    } catch (_) {}
  }

  void _refresh([CourseFilter? filter]) {
    setState(() => _catalogFuture = _loadCatalog(filter ?? _filter));
  }

  void _applyFilters() {
    _refresh(
      CourseFilter(
        query: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        instructorId: _filter.instructorId,
        minPrice: double.tryParse(_minController.text.trim()),
        maxPrice: double.tryParse(_maxController.text.trim()),
        sort: _filter.sort,
        page: 1,
        pageSize: _filter.pageSize,
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    _minController.clear();
    _maxController.clear();
    _refresh(CourseFilter(pageSize: _filter.pageSize));
  }

  Future<void> _openMobileFilters() async {
    final result = await showModalBottomSheet<CourseFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterSheet(filter: _filter, instructors: _instructors),
    );
    if (result == null) return;
    _searchController.text = result.query ?? '';
    _minController.text = result.minPrice?.toString() ?? '';
    _maxController.text = result.maxPrice?.toString() ?? '';
    _refresh(result.copyWith(page: 1));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [AppTheme.navy, AppTheme.navySoft, AppTheme.blue],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x2608192F), blurRadius: 24, offset: Offset(0, 12)),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text('مكتبة التعلم', style: TextStyle(color: Color(0xFFB9FFF2), fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 11),
                    const Text('استكشف الكورسات', style: TextStyle(color: Colors.white, fontSize: 28, height: 1.25, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    const Text('ابحث، قارن، واختر المسار الذي يطابق هدفك القادم.', style: TextStyle(color: Color(0xFFD9E6FF), fontSize: 12, height: 1.7)),
                  ],
                );
                final filterButton = FilledButton.icon(
                  onPressed: _openMobileFilters,
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppTheme.blue, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13)),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('تصفية النتائج'),
                );
                if (compact) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 18), filterButton]);
                }
                return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: copy), filterButton]);
              },
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CatalogModeButton(
                icon: Icons.grid_view_rounded,
                label: 'شبكة',
                selected: !_listView,
                onTap: () => setState(() => _listView = false),
              ),
              _CatalogModeButton(
                icon: Icons.view_list_rounded,
                label: 'قائمة',
                selected: _listView,
                onTap: () => setState(() => _listView = true),
              ),
              if (_filter.hasAnyFilter)
                OutlinedButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('مسح الفلاتر'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FutureBuilder<CourseCatalog>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              if (_loading && snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(label: 'جاري البحث في مكتبة الكورسات...');
              }
              if (_error != null || snapshot.hasError) {
                return ErrorState(message: _error ?? snapshot.error.toString(), onRetry: () => _refresh());
              }
              final catalog = snapshot.data;
              final items = catalog?.items ?? const <Course>[];
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'لا توجد نتائج مطابقة',
                  message: 'جرّب تغيير كلمات البحث أو إزالة بعض الفلاتر للوصول إلى كورسات أكثر.',
                  icon: Icons.search_off_rounded,
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: '${catalog!.totalCount} كورس',
                    subtitle: 'اختر الكورس المناسب وافتح التفاصيل لمعرفة المحتوى والمدرّس.',
                    action: Text('${catalog.page} / ${catalog.totalPages == 0 ? 1 : catalog.totalPages}', style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 14),
                  if (_listView)
                    for (final course in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CourseListCard(course: course),
                      )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1024 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
                        const gap = 16.0;
                        final width = (constraints.maxWidth - ((columns - 1) * gap)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [for (final course in items) SizedBox(width: width, child: _CourseGridCard(course: course))],
                        );
                      },
                    ),
                  const SizedBox(height: 18),
                  _CatalogPager(
                    catalog: catalog,
                    onPage: (page) => _refresh(_filter.copyWith(page: page)),
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

class _CatalogModeButton extends StatelessWidget {
  const _CatalogModeButton({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => selected
      ? FilledButton.tonalIcon(onPressed: onTap, icon: Icon(icon), label: Text(label))
      : OutlinedButton.icon(onPressed: onTap, icon: Icon(icon), label: Text(label));
}

class _CourseGridCard extends StatelessWidget {
  const _CourseGridCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => context.go('/courses/${course.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourseCover(course: course),
          Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900, fontSize: 14, height: 1.45)),
                const SizedBox(height: 7),
                Text(course.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.6)),
                const SizedBox(height: 13),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, color: AppTheme.muted, size: 15),
                    const SizedBox(width: 5),
                    Expanded(child: Text(course.instructorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 10))),
                    const Icon(Icons.arrow_back_rounded, color: AppTheme.blue, size: 18),
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

class _CourseListCard extends StatelessWidget {
  const _CourseListCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/courses/${course.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(18), child: CourseCover(course: course, height: 170)),
                    const SizedBox(height: 14),
                    _CourseListInfo(course: course),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 220, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: CourseCover(course: course, height: 145))),
                    const SizedBox(width: 18),
                    Expanded(child: _CourseListInfo(course: course)),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CourseListInfo extends StatelessWidget {
  const _CourseListInfo({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontSize: 16, fontWeight: FontWeight.w900)),
      const SizedBox(height: 7),
      Text(course.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.6)),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _SmallChip(icon: Icons.person_outline_rounded, label: course.instructorName),
          _SmallChip(icon: Icons.payments_outlined, label: course.price == 0 ? 'مجاني' : '${course.price.toStringAsFixed(2)} ر.س'),
        ],
      ),
    ],
  );
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: AppTheme.surfaceMuted, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppTheme.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: AppTheme.blue), const SizedBox(width: 5), Text(label, style: const TextStyle(color: AppTheme.ink, fontSize: 10, fontWeight: FontWeight.w700))]),
  );
}

class _CatalogPager extends StatelessWidget {
  const _CatalogPager({required this.catalog, required this.onPage});
  final CourseCatalog catalog;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.center,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 10,
    runSpacing: 8,
    children: [
      IconButton.outlined(onPressed: catalog.page > 1 ? () => onPage(catalog.page - 1) : null, icon: const Icon(Icons.chevron_right_rounded), tooltip: 'الصفحة السابقة'),
      Text('صفحة ${catalog.page} من ${catalog.totalPages == 0 ? 1 : catalog.totalPages}', style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w800)),
      IconButton.outlined(onPressed: catalog.page < catalog.totalPages ? () => onPage(catalog.page + 1) : null, icon: const Icon(Icons.chevron_left_rounded), tooltip: 'الصفحة التالية'),
    ],
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.instructors});
  final CourseFilter filter;
  final List<InstructorOption> instructors;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _query;
  late final TextEditingController _min;
  late final TextEditingController _max;
  int? _instructorId;
  String? _sort;

  @override
  void initState() {
    super.initState();
    _query = TextEditingController(text: widget.filter.query ?? '');
    _min = TextEditingController(text: widget.filter.minPrice?.toString() ?? '');
    _max = TextEditingController(text: widget.filter.maxPrice?.toString() ?? '');
    _instructorId = widget.filter.instructorId;
    _sort = widget.filter.sort;
  }

  @override
  void dispose() {
    _query.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(999)))),
            const SizedBox(height: 20),
            const Text('تصفية الكورسات', style: TextStyle(color: AppTheme.ink, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            TextField(controller: _query, decoration: const InputDecoration(labelText: 'بحث', prefixIcon: Icon(Icons.search_rounded))),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _instructorId,
              decoration: const InputDecoration(labelText: 'المدرّس'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('كل المدرسين')),
                ...widget.instructors.map((item) => DropdownMenuItem<int?>(value: item.id, child: Text(item.name))),
              ],
              onChanged: (value) => setState(() => _instructorId = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقل سعر'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أعلى سعر'))),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _sort,
              decoration: const InputDecoration(labelText: 'الترتيب'),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('الافتراضي')),
                DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
                DropdownMenuItem(value: 'price_asc', child: Text('السعر: من الأقل')),
                DropdownMenuItem(value: 'price_desc', child: Text('السعر: من الأعلى')),
              ],
              onChanged: (value) => setState(() => _sort = value),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  CourseFilter(
                    query: _query.text.trim().isEmpty ? null : _query.text.trim(),
                    instructorId: _instructorId,
                    minPrice: double.tryParse(_min.text.trim()),
                    maxPrice: double.tryParse(_max.text.trim()),
                    sort: _sort,
                    page: 1,
                    pageSize: widget.filter.pageSize,
                  ),
                );
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('تطبيق الفلاتر'),
            ),
          ],
        ),
      ),
    ),
  );
}
