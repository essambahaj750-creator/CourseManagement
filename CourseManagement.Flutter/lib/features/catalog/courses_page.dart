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
    } catch (_) {
      // Instructor filter is optional; the catalog remains usable.
    }
  }

  void _refresh([CourseFilter? filter]) {
    setState(() => _catalogFuture = _loadCatalog(filter ?? _filter));
  }

  void _applyFilters() {
    _refresh(
      CourseFilter(
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
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
      builder: (context) =>
          _FilterSheet(filter: _filter, instructors: _instructors),
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
                BoxShadow(
                  color: Color(0x2608192F),
                  blurRadius: 24,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cyan.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'مكتبة التعلم',
                        style: TextStyle(
                          color: Color(0xFFB9FFF2),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text(
                      'استكشف الكورسات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ابحث، قارن، واختر المسار الذي يطابق هدفك القادم.',
                      style: TextStyle(
                        color: Color(0xFFD9E6FF),
                        fontSize: 12,
                        height: 1.7,
                      ),
                    ),
                  ],
                );
                final filterButton = FilledButton.icon(
                  onPressed: _openMobileFilters,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('تصفية النتائج'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 18), filterButton],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: copy),
                    filterButton,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _CatalogHighlight(
                icon: Icons.search_rounded,
                title: 'ابحث بسهولة',
                subtitle: 'استخدم العنوان أو الوصف أو المدرّس',
              ),
              _CatalogHighlight(
                icon: Icons.tune_rounded,
                title: 'فلاتر دقيقة',
                subtitle: 'السعر والترتيب والمجال في مكان واحد',
              ),
              _CatalogHighlight(
                icon: Icons.auto_awesome_rounded,
                title: 'مسارات عملية',
                subtitle: 'اختر ما يناسب هدفك الحالي',
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final results = _ResultsPane(
                future: _catalogFuture,
                loading: _loading,
                error: _error,
                listView: _listView,
                onRetry: _refresh,
                onToggleView: () => setState(() => _listView = !_listView),
                onPage: (page) => _refresh(_filter.copyWith(page: page)),
              );
              if (constraints.maxWidth < 900) return results;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FilterPanel(
                    filter: _filter,
                    instructors: _instructors,
                    search: _searchController,
                    minPrice: _minController,
                    maxPrice: _maxController,
                    onApply: _applyFilters,
                    onReset: _resetFilters,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: results),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatalogHighlight extends StatelessWidget {
  const _CatalogHighlight({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    width: 250,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE3E9F4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080B1220),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.blue.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppTheme.blue, size: 20),
        ),
        const SizedBox(width: 10),
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.filter,
    required this.instructors,
    required this.search,
    required this.minPrice,
    required this.maxPrice,
    required this.onApply,
    required this.onReset,
    required this.onChanged,
  });

  final CourseFilter filter;
  final List<InstructorOption> instructors;
  final TextEditingController search;
  final TextEditingController minPrice;
  final TextEditingController maxPrice;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final ValueChanged<CourseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 292,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'تصفية النتائج',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: AppTheme.blue,
                      size: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'استخدم أكثر من فلتر للوصول إلى النتيجة الأنسب.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              _FilterFields(
                filter: filter,
                instructors: instructors,
                search: search,
                minPrice: minPrice,
                maxPrice: maxPrice,
                onChanged: onChanged,
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('تطبيق الفلاتر'),
              ),
              TextButton.icon(
                onPressed: filter.hasActiveFilters ? onReset : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('إعادة الضبط'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter, required this.instructors});

  final CourseFilter filter;
  final List<InstructorOption> instructors;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _search = TextEditingController(
    text: widget.filter.query ?? '',
  );
  late final TextEditingController _min = TextEditingController(
    text: widget.filter.minPrice?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.filter.maxPrice?.toString() ?? '',
  );
  late CourseFilter _filter = widget.filter;

  @override
  void dispose() {
    _search.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'الفلاتر',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _FilterFields(
                filter: _filter,
                instructors: widget.instructors,
                search: _search,
                minPrice: _min,
                maxPrice: _max,
                onChanged: (value) => setState(() => _filter = value),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  _filter.copyWith(
                    query: _search.text.trim().isEmpty
                        ? null
                        : _search.text.trim(),
                    minPrice: double.tryParse(_min.text.trim()),
                    maxPrice: double.tryParse(_max.text.trim()),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('عرض النتائج'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterFields extends StatelessWidget {
  const _FilterFields({
    required this.filter,
    required this.instructors,
    required this.search,
    required this.minPrice,
    required this.maxPrice,
    required this.onChanged,
  });

  final CourseFilter filter;
  final List<InstructorOption> instructors;
  final TextEditingController search;
  final TextEditingController minPrice;
  final TextEditingController maxPrice;
  final ValueChanged<CourseFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: search,
          decoration: const InputDecoration(
            labelText: 'كلمة البحث',
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'عنوان، وصف، مدرس...',
          ),
          onSubmitted: (_) =>
              onChanged(filter.copyWith(query: search.text.trim())),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          initialValue: filter.instructorId ?? 0,
          decoration: const InputDecoration(
            labelText: 'المدرّس',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          items: [
            const DropdownMenuItem(value: 0, child: Text('كل المدرّسين')),
            ...instructors.map(
              (item) =>
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
            ),
          ],
          onChanged: (value) => onChanged(
            filter.copyWith(
              instructorId: value == 0 ? null : value,
              clearInstructor: value == 0,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: minPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'من',
                  suffixText: 'ر.س',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: maxPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'إلى',
                  suffixText: 'ر.س',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: filter.sort,
          decoration: const InputDecoration(
            labelText: 'الترتيب',
            prefixIcon: Icon(Icons.sort_rounded),
          ),
          items: const [
            DropdownMenuItem(value: 'featured', child: Text('اختيارات مميزة')),
            DropdownMenuItem(value: 'newest', child: Text('الأحدث أولًا')),
            DropdownMenuItem(
              value: 'price-low',
              child: Text('السعر: الأقل أولًا'),
            ),
            DropdownMenuItem(
              value: 'price-high',
              child: Text('السعر: الأعلى أولًا'),
            ),
            DropdownMenuItem(value: 'title', child: Text('الترتيب الأبجدي')),
          ],
          onChanged: (value) =>
              onChanged(filter.copyWith(sort: value ?? 'featured')),
        ),
      ],
    );
  }
}

class _ResultsPane extends StatelessWidget {
  const _ResultsPane({
    required this.future,
    required this.loading,
    required this.error,
    required this.listView,
    required this.onRetry,
    required this.onToggleView,
    required this.onPage,
  });

  final Future<CourseCatalog> future;
  final bool loading;
  final String? error;
  final bool listView;
  final VoidCallback onRetry;
  final VoidCallback onToggleView;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    if (loading && error == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(70),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (error != null) return ErrorState(message: error!, onRetry: onRetry);
    return FutureBuilder<CourseCatalog>(
      future: future,
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
            onRetry: onRetry,
          );
        }
        final catalog = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultsHeader(
              catalog: catalog,
              listView: listView,
              onToggleView: onToggleView,
            ),
            const SizedBox(height: 14),
            if (catalog.items.isEmpty)
              const EmptyState(
                title: 'لم نجد نتائج مطابقة',
                message: 'وسّع نطاق البحث أو أزل أحد الفلاتر للوصول إلى كامل المكتبة.',
                icon: Icons.search_off_rounded,
              )
            else
              _CourseGrid(catalog: catalog, listView: listView),
            if (catalog.totalPages > 1) ...[
              const SizedBox(height: 20),
              _Pagination(catalog: catalog, onPage: onPage),
            ],
          ],
        );
      },
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.catalog,
    required this.listView,
    required this.onToggleView,
  });

  final CourseCatalog catalog;
  final bool listView;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'النتائج المتاحة',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${catalog.totalCount} كورسات ضمن مكتبة منصة المعرفة',
              style: const TextStyle(color: AppTheme.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      IconButton(
        tooltip: listView ? 'عرض الشبكة' : 'عرض القائمة',
        onPressed: onToggleView,
        icon: Icon(
          listView ? Icons.grid_view_rounded : Icons.view_list_rounded,
          color: AppTheme.blue,
        ),
      ),
    ],
  );
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.catalog, required this.listView});

  final CourseCatalog catalog;
  final bool listView;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = listView ? 1 : (constraints.maxWidth > 760 ? 2 : 1);
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: [
            for (final course in catalog.items)
              SizedBox(
                width: width,
                child: _CourseTile(course: course, listView: listView),
              ),
          ],
        );
      },
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile({required this.course, required this.listView});

  final Course course;
  final bool listView;

  @override
  Widget build(BuildContext context) {
    final information = _CourseInfo(course: course);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        child: listView
            ? Row(
                children: [
                  SizedBox(
                    width: 150,
                    child: CourseCover(course: course, height: 150),
                  ),
                  Expanded(child: information),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CourseCover(course: course),
                  information,
                ],
              ),
      ),
    );
  }
}

class _CourseInfo extends StatelessWidget {
  const _CourseInfo({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final description = course.description.isEmpty
        ? 'مسار عملي لتطوير مهاراتك.'
        : course.description;
    final initial = course.instructorName.isEmpty
        ? 'م'
        : course.instructorName.substring(0, 1);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.ink,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppTheme.blue.withValues(alpha: .12),
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  course.instructorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ),
              Text(
                course.price == 0
                    ? 'مجاني'
                    : '${course.price.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.catalog, required this.onPage});

  final CourseCatalog catalog;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final end = catalog.totalPages < 5 ? catalog.totalPages : 5;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: catalog.page > 1 ? () => onPage(catalog.page - 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        for (var page = 1; page <= end; page++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: page == catalog.page
                ? CircleAvatar(
                    radius: 17,
                    backgroundColor: AppTheme.blue,
                    child: Text(
                      '$page',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: () => onPage(page),
                    child: Text('$page'),
                  ),
          ),
        IconButton(
          onPressed: catalog.page < catalog.totalPages
              ? () => onPage(catalog.page + 1)
              : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
      ],
    );
  }
}
