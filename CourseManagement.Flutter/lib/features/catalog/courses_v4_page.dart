import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CoursesV4Page extends StatefulWidget {
  const CoursesV4Page({super.key});

  @override
  State<CoursesV4Page> createState() => _CoursesV4PageState();
}

class _CoursesV4PageState extends State<CoursesV4Page> {
  final _search = TextEditingController();
  late final ApiClient _api;
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
      final instructors = await _api.getInstructors();
      if (mounted) setState(() => _instructors = instructors);
    } catch (_) {
      // The catalog remains usable even when instructor filtering is unavailable.
    }
  }

  void _load(CourseFilter filter) {
    setState(() {
      _filter = filter;
      _future = _api.searchCourses(filter);
    });
  }

  void _searchNow() {
    _load(
      _filter.copyWith(
        query: _search.text.trim().isEmpty ? null : _search.text.trim(),
        page: 1,
      ),
    );
  }

  void _reset() {
    _search.clear();
    _load(const CourseFilter(pageSize: 12));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<CourseFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FiltersSheet(
        initial: _filter,
        instructors: _instructors,
      ),
    );
    if (result != null) _load(result.copyWith(page: 1));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = screenWidth < 600;
    final showInlineFilters = screenWidth >= 900;

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(compact: compact),
          SizedBox(height: compact ? 14 : 20),
          _SearchControls(
            controller: _search,
            compact: compact,
            hasActiveFilters: _filter.hasActiveFilters,
            onSearch: _searchNow,
            onFilters: _openFilters,
            onReset: _reset,
          ),
          if (showInlineFilters) ...[
            const SizedBox(height: 12),
            _InlineFilters(
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
                  _ResultHeader(catalog: catalog, filtered: _filter.hasActiveFilters),
                  const SizedBox(height: 14),
                  if (catalog.items.isEmpty)
                    EmptyState(
                      title: 'لا توجد نتائج مطابقة',
                      message: 'جرّب كلمة بحث مختلفة أو امسح الفلاتر.',
                      icon: Icons.search_off_rounded,
                      action: FilledButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('عرض كل الكورسات'),
                      ),
                    )
                  else
                    _CourseGrid(courses: catalog.items),
                  if (catalog.totalPages > 1) ...[
                    const SizedBox(height: 22),
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

class _Header extends StatelessWidget {
  const _Header({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 20 : 28),
        decoration: BoxDecoration(
          gradient: AppTheme.brandGradient,
          borderRadius: BorderRadius.circular(compact ? 24 : 30),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'مكتبة التعلم',
                style: TextStyle(
                  color: Color(0xFFB9FFF2),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'استكشف الكورسات',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 25 : 30,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابحث، شاهد تفاصيل الكورس والمعاينة، ثم سجّل وابدأ التعلّم.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .74),
                fontSize: compact ? 11 : 13,
                height: 1.8,
              ),
            ),
          ],
        ),
      );
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.controller,
    required this.compact,
    required this.hasActiveFilters,
    required this.onSearch,
    required this.onFilters,
    required this.onReset,
  });

  final TextEditingController controller;
  final bool compact;
  final bool hasActiveFilters;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: 'اسم الكورس أو الوصف...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasActiveFilters
            ? IconButton(
                tooltip: 'مسح البحث والفلاتر',
                onPressed: onReset,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
      ),
    );

    final filter = FilledButton.icon(
      onPressed: onFilters,
      icon: const Icon(Icons.tune_rounded),
      label: Text(hasActiveFilters ? 'فلاتر مفعّلة' : 'الفلاتر'),
    );

    if (compact) {
      return Column(
        children: [
          field,
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search_rounded),
                  label: const Text('بحث'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: filter),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.search_rounded),
          label: const Text('بحث'),
        ),
        const SizedBox(width: 8),
        filter,
      ],
    );
  }
}

class _InlineFilters extends StatelessWidget {
  const _InlineFilters({
    required this.filter,
    required this.instructors,
    required this.onChanged,
  });

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
                width: 240,
                child: DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: filter.instructorId ?? 0,
                  decoration: const InputDecoration(
                    labelText: 'المدرّس',
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('كل المدرّسين', overflow: TextOverflow.ellipsis),
                    ),
                    ...instructors.map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: (value) => onChanged(
                    filter.copyWith(
                      instructorId: value == 0 ? null : value,
                      clearInstructor: value == 0,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: filter.sort,
                  decoration: const InputDecoration(
                    labelText: 'الترتيب',
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'featured', child: Text('اختيارات مميزة')),
                    DropdownMenuItem(value: 'newest', child: Text('الأحدث أولًا')),
                    DropdownMenuItem(value: 'price-low', child: Text('الأقل سعرًا')),
                    DropdownMenuItem(value: 'price-high', child: Text('الأعلى سعرًا')),
                    DropdownMenuItem(value: 'title', child: Text('أبجديًا')),
                  ],
                  onChanged: (value) => onChanged(
                    filter.copyWith(sort: value ?? 'featured'),
                  ),
                ),
              ),
              FilterChip(
                label: const Text('مجاني فقط'),
                selected: filter.maxPrice == 0,
                onSelected: (selected) => onChanged(
                  filter.copyWith(
                    maxPrice: selected ? 0 : null,
                    clearMaxPrice: !selected,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({required this.initial, required this.instructors});

  final CourseFilter initial;
  final List<InstructorOption> instructors;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late CourseFilter _filter = widget.initial;
  late final TextEditingController _min = TextEditingController(
    text: widget.initial.minPrice?.toString() ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.initial.maxPrice?.toString() ?? '',
  );

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  CourseFilter _value() => _filter.copyWith(
        minPrice: double.tryParse(_min.text.trim()),
        maxPrice: double.tryParse(_max.text.trim()),
        clearMinPrice: _min.text.trim().isEmpty,
        clearMaxPrice: _max.text.trim().isEmpty,
      );

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .55,
        maxChildSize: .94,
        builder: (context, scrollController) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'تصفية الكورسات',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 19,
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
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _filter.instructorId ?? 0,
                      decoration: const InputDecoration(
                        labelText: 'المدرّس',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('كل المدرّسين', overflow: TextOverflow.ellipsis),
                        ),
                        ...widget.instructors.map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _filter = _filter.copyWith(
                          instructorId: value == 0 ? null : value,
                          clearInstructor: value == 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 330;
                        final minField = TextField(
                          controller: _min,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'أقل سعر'),
                        );
                        final maxField = TextField(
                          controller: _max,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'أعلى سعر'),
                        );
                        if (narrow) {
                          return Column(
                            children: [minField, const SizedBox(height: 10), maxField],
                          );
                        }
                        return Row(
                          children: [
                            Expanded(child: minField),
                            const SizedBox(width: 10),
                            Expanded(child: maxField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _filter.sort,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب النتائج',
                        prefixIcon: Icon(Icons.sort_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'featured', child: Text('اختيارات مميزة')),
                        DropdownMenuItem(value: 'newest', child: Text('الأحدث أولًا')),
                        DropdownMenuItem(value: 'price-low', child: Text('السعر: الأقل أولًا')),
                        DropdownMenuItem(value: 'price-high', child: Text('السعر: الأعلى أولًا')),
                        DropdownMenuItem(value: 'title', child: Text('الترتيب الأبجدي')),
                      ],
                      onChanged: (value) => setState(
                        () => _filter = _filter.copyWith(sort: value ?? 'featured'),
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(context, _value()),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('تطبيق الفلاتر'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        const CourseFilter(pageSize: 12),
                      ),
                      icon: const Icon(Icons.restart_alt_rounded),
                      label: const Text('مسح كل الفلاتر'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
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

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({required this.catalog, required this.filtered});

  final CourseCatalog catalog;
  final bool filtered;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'النتائج',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${catalog.totalCount} كورس متاح',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          if (filtered)
            const Chip(
              avatar: Icon(Icons.tune_rounded, size: 15),
              label: Text('مفلترة'),
            ),
        ],
      );
}

class _CourseGrid extends StatelessWidget {
  const _CourseGrid({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1120
              ? 3
              : constraints.maxWidth >= 680
                  ? 2
                  : 1;
          const gap = 14.0;
          final cardWidth =
              (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final course in courses)
                SizedBox(
                  width: cardWidth,
                  child: _CourseCard(course: course),
                ),
            ],
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        course.price == 0
                            ? 'مجاني'
                            : '${course.price.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(15),
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
                        height: 1.45,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      course.description.isEmpty
                          ? 'مسار عملي لتطوير مهاراتك.'
                          : course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: AppTheme.blue.withValues(alpha: .1),
                          child: Text(
                            course.instructorName.isEmpty
                                ? 'م'
                                : course.instructorName.substring(0, 1),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.muted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.blue,
                          size: 18,
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

class _Pagination extends StatelessWidget {
  const _Pagination({required this.catalog, required this.onPage});

  final CourseCatalog catalog;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: catalog.page > 1
                ? () => onPage(catalog.page - 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'صفحة ${catalog.page} من ${catalog.totalPages}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
