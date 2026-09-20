import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CoursesV3Page extends StatefulWidget {
  const CoursesV3Page({super.key});

  @override
  State<CoursesV3Page> createState() => _CoursesV3PageState();
}

class _CoursesV3PageState extends State<CoursesV3Page> {
  final _search = TextEditingController();
  late ApiClient _api;
  CourseFilter _filter = const CourseFilter(pageSize: 12);
  late Future<CourseCatalog> _future;
  List<InstructorOption> _instructors = const [];

  @override
  void initState() {
    super.initState();
    _api = context.read<ApiClient>();
    _future = _api.searchCourses(_filter);
    _loadInstructors();
  }

  Future<void> _loadInstructors() async {
    try {
      final value = await _api.getInstructors();
      if (mounted) setState(() => _instructors = value);
    } catch (_) {}
  }

  void _load(CourseFilter next) {
    setState(() {
      _filter = next;
      _future = _api.searchCourses(next);
    });
  }

  void _submitSearch() => _load(_filter.copyWith(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: 1,
      ));

  void _clearAll() {
    _search.clear();
    _load(const CourseFilter(pageSize: 12));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<CourseFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _MobileFilters(
        initial: _filter,
        instructors: _instructors,
      ),
    );
    if (result != null) {
      _search.text = result.query ?? _search.text;
      _load(result.copyWith(page: 1));
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = AppBreakpoints.isMobile(width);

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogHeader(mobile: mobile),
          SizedBox(height: mobile ? 14 : 20),
          _SearchBar(
            controller: _search,
            hasFilters: _filter.hasActiveFilters,
            onSearch: _submitSearch,
            onFilters: _openFilters,
            onClear: _clearAll,
          ),
          if (!mobile) ...[
            const SizedBox(height: 12),
            _DesktopFilterRow(
              filter: _filter,
              instructors: _instructors,
              onChanged: (value) => _load(value.copyWith(page: 1)),
            ),
          ],
          const SizedBox(height: 20),
          FutureBuilder<CourseCatalog>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingState(label: 'جاري تحميل الكورسات...');
              }
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: () => _load(_filter),
                );
              }
              final catalog = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResultsSummary(catalog: catalog, filter: _filter),
                  const SizedBox(height: 14),
                  if (catalog.items.isEmpty)
                    EmptyState(
                      title: 'لا توجد نتائج مطابقة',
                      message: 'غيّر البحث أو امسح الفلاتر ثم حاول مرة أخرى.',
                      icon: Icons.search_off_rounded,
                      action: FilledButton.icon(
                        onPressed: _clearAll,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('إظهار كل الكورسات'),
                      ),
                    )
                  else
                    _CourseGrid(courses: catalog.items),
                  if (catalog.totalPages > 1) ...[
                    const SizedBox(height: 20),
                    _Pagination(
                      catalog: catalog,
                      onPage: (page) => _load(_filter.copyWith(page: page)),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatalogHeader extends StatelessWidget {
  const _CatalogHeader({required this.mobile});
  final bool mobile;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(mobile ? 20 : 28),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(mobile ? 24 : 30),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'استكشف الكورسات',
              style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.3),
            ),
            const SizedBox(height: 8),
            Text(
              'ابحث عن المهارة التي تريدها، شاهد تفاصيل الكورس والمعاينة، ثم ابدأ التعلم.',
              style: TextStyle(color: Colors.white.withValues(alpha: .74), fontSize: 12, height: 1.7),
            ),
          ],
        ),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.hasFilters,
    required this.onSearch,
    required this.onFilters,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasFilters;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final searchField = TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: InputDecoration(
              hintText: 'ابحث باسم الكورس أو الوصف...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded)),
            ),
          );
          final filterButton = FilledButton.icon(
            onPressed: onFilters,
            icon: const Icon(Icons.tune_rounded),
            label: Text(hasFilters ? 'الفلاتر مفعّلة' : 'الفلاتر'),
          );
          if (compact) {
            return Column(
              children: [
                searchField,
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: const Text('بحث'))),
                    const SizedBox(width: 10),
                    Expanded(child: filterButton),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 10),
              FilledButton.icon(onPressed: onSearch, icon: const Icon(Icons.search_rounded), label: const Text('بحث')),
              const SizedBox(width: 8),
              filterButton,
            ],
          );
        },
      );
}

class _DesktopFilterRow extends StatelessWidget {
  const _DesktopFilterRow({required this.filter, required this.instructors, required this.onChanged});
  final CourseFilter filter;
  final List<InstructorOption> instructors;
  final ValueChanged<CourseFilter> onChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int>(
                  initialValue: filter.instructorId ?? 0,
                  decoration: const InputDecoration(labelText: 'المدرّس', isDense: true),
                  items: [
                    const DropdownMenuItem(value: 0, child: Text('كل المدرّسين')),
                    ...instructors.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (value) => onChanged(filter.copyWith(instructorId: value == 0 ? null : value, clearInstructor: value == 0)),
                ),
              ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String>(
                  initialValue: filter.sort,
                  decoration: const InputDecoration(labelText: 'الترتيب', isDense: true),
                  items: const [
                    DropdownMenuItem(value: 'featured', child: Text('مميز')),
                    DropdownMenuItem(value: 'newest', child: Text('الأحدث')),
                    DropdownMenuItem(value: 'price-low', child: Text('الأقل سعرًا')),
                    DropdownMenuItem(value: 'price-high', child: Text('الأعلى سعرًا')),
                    DropdownMenuItem(value: 'title', child: Text('أبجديًا')),
                  ],
                  onChanged: (value) => onChanged(filter.copyWith(sort: value ?? 'featured')),
                ),
              ),
              FilterChip(
                label: const Text('مجاني فقط'),
                selected: filter.maxPrice == 0,
                onSelected: (selected) => onChanged(filter.copyWith(maxPrice: selected ? 0 : null, clearMaxPrice: !selected)),
              ),
            ],
          ),
        ),
      );
}

class _MobileFilters extends StatefulWidget {
  const _MobileFilters({required this.initial, required this.instructors});
  final CourseFilter initial;
  final List<InstructorOption> instructors;

  @override
  State<_MobileFilters> createState() => _MobileFiltersState();
}

class _MobileFiltersState extends State<_MobileFilters> {
  late CourseFilter _filter = widget.initial;
  late final _min = TextEditingController(text: widget.initial.minPrice?.toString() ?? '');
  late final _max = TextEditingController(text: widget.initial.maxPrice?.toString() ?? '');

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .55,
        maxChildSize: .94,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 44, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(99))),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Expanded(child: Text('تصفية الكورسات', style: TextStyle(color: AppTheme.ink, fontSize: 19, fontWeight: FontWeight.w900))),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 20),
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: _filter.instructorId ?? 0,
                      decoration: const InputDecoration(labelText: 'المدرّس', prefixIcon: Icon(Icons.person_outline_rounded)),
                      items: [
                        const DropdownMenuItem(value: 0, child: Text('كل المدرّسين')),
                        ...widget.instructors.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (value) => setState(() => _filter = _filter.copyWith(instructorId: value == 0 ? null : value, clearInstructor: value == 0)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أقل سعر'))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: _max, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'أعلى سعر'))),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _filter.sort,
                      decoration: const InputDecoration(labelText: 'ترتيب النتائج', prefixIcon: Icon(Icons.sort_rounded)),
                      items: const [
                        DropdownMenuItem(value: 'featured', child: Text('اختيارات مميزة')),
                        DropdownMenuItem(value: 'newest', child: Text('الأحدث أولًا')),
                        DropdownMenuItem(value: 'price-low', child: Text('السعر: الأقل أولًا')),
                        DropdownMenuItem(value: 'price-high', child: Text('السعر: الأعلى أولًا')),
                        DropdownMenuItem(value: 'title', child: Text('الترتيب الأبجدي')),
                      ],
                      onChanged: (value) => setState(() => _filter = _filter.copyWith(sort: value ?? 'featured')),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        _filter.copyWith(
                          minPrice: double.tryParse(_min.text.trim()),
                          maxPrice: double.tryParse(_max.text.trim()),
                          clearMinPrice: _min.text.trim().isEmpty,
                          clearMaxPrice: _max.text.trim().isEmpty,
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('تطبيق الفلاتر'),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, const CourseFilter(pageSize: 12)),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('مسح كل الفلاتر'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.catalog, required this.filter});
  final CourseCatalog catalog;
  final CourseFilter filter;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('النتائج', style: TextStyle(color: AppTheme.ink, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text('${catalog.totalCount} كورس متاح', style: const TextStyle(color: AppTheme.muted, fontSize: 11)),
              ],
            ),
          ),
          if (filter.hasActiveFilters)
            const Chip(avatar: Icon(Icons.tune_rounded, size: 15), label: Text('نتائج مفلترة')),
        ],
      );
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses});
  final List<Course> courses;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1120 ? 3 : constraints.maxWidth >= 680 ? 2 : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final course in courses) SizedBox(width: width, child: _CourseCard(course: course))],
          );
        },
      );
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/courses/${course.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CourseCover(course: course, height: 180),
                  PositionedDirectional(
                    top: 10,
                    end: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .94), borderRadius: BorderRadius.circular(999)),
                      child: Text(course.price == 0 ? 'مجاني' : '${course.price.toStringAsFixed(0)} ر.س', style: const TextStyle(color: AppTheme.ink, fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.ink, fontSize: 15, fontWeight: FontWeight.w900, height: 1.45)),
                    const SizedBox(height: 7),
                    Text(course.description.isEmpty ? 'مسار عملي لتطوير مهاراتك.' : course.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.6)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(radius: 13, backgroundColor: AppTheme.blue.withValues(alpha: .1), child: Text(course.instructorName.isEmpty ? 'م' : course.instructorName.substring(0, 1), style: const TextStyle(color: AppTheme.blue, fontSize: 10, fontWeight: FontWeight.w900))),
                        const SizedBox(width: 7),
                        Expanded(child: Text(course.instructorName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.muted, fontSize: 11))),
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

class _Pagination extends StatelessWidget {
  const _Pagination({required this.catalog, required this.onPage});
  final CourseCatalog catalog;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(onPressed: catalog.page > 1 ? () => onPage(catalog.page - 1) : null, icon: const Icon(Icons.chevron_right_rounded)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('صفحة ${catalog.page} من ${catalog.totalPages}', style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          IconButton(onPressed: catalog.page < catalog.totalPages ? () => onPage(catalog.page + 1) : null, icon: const Icon(Icons.chevron_left_rounded)),
        ],
      );
}
