import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class CoursesV5Page extends StatefulWidget {
  const CoursesV5Page({super.key});

  @override
  State<CoursesV5Page> createState() => _CoursesV5PageState();
}

class _CoursesV5PageState extends State<CoursesV5Page> {
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
      final value = await _api.getInstructors();
      if (mounted) setState(() => _instructors = value);
    } catch (_) {}
  }

  void _load(CourseFilter value) {
    setState(() {
      _filter = value;
      _future = _api.searchCourses(value);
    });
  }

  void _searchNow() {
    final text = _search.text.trim();
    _load(_filter.copyWith(query: text.isEmpty ? null : text, page: 1));
  }

  void _reset() {
    _search.clear();
    _load(const CourseFilter(pageSize: 12));
  }

  int get _activeFilterCount {
    var count = 0;
    if (_filter.instructorId != null) count++;
    if (_filter.minPrice != null) count++;
    if (_filter.maxPrice != null) count++;
    if (_filter.sort != 'featured') count++;
    return count;
  }

  String? get _instructorLabel {
    final id = _filter.instructorId;
    if (id == null) return null;
    for (final item in _instructors) {
      if (item.id == id) return item.name;
    }
    return 'مدرّس محدد';
  }

  Future<void> _openFilters() async {
    final value = await showModalBottomSheet<CourseFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PremiumFiltersSheet(
        initial: _filter,
        instructors: _instructors,
      ),
    );
    if (value != null) _load(value.copyWith(page: 1));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CatalogHero(compact: compact),
          SizedBox(height: compact ? 16 : 22),
          _SearchBar(
            controller: _search,
            compact: compact,
            activeCount: _activeFilterCount,
            onSearch: _searchNow,
            onFilter: _openFilters,
          ),
          if (_filter.hasActiveFilters) ...[
            const SizedBox(height: 12),
            _ActiveFilters(
              filter: _filter,
              instructorLabel: _instructorLabel,
              onChanged: (value) => _load(value.copyWith(page: 1)),
              onClearAll: _reset,
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
                  _ResultsSummary(catalog: catalog),
                  const SizedBox(height: 14),
                  if (catalog.items.isEmpty)
                    EmptyState(
                      title: 'لا توجد نتائج مطابقة',
                      message: 'غيّر خيارات الفلترة أو اعرض جميع الكورسات.',
                      icon: Icons.manage_search_rounded,
                      action: FilledButton.icon(
                        onPressed: _reset,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('عرض جميع الكورسات'),
                      ),
                    )
                  else
                    _CourseGrid(courses: catalog.items),
                  if (catalog.totalPages > 1) ...[
                    const SizedBox(height: 24),
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

class _CatalogHero extends StatelessWidget {
  const _CatalogHero({required this.compact});
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
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'استكشف وتعلّم',
                style: TextStyle(
                  color: Color(0xFFB9FFF2),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'اختر الكورس المناسب لك',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 24 : 30,
                height: 1.3,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابحث بالاسم، ثم صفِّ النتائج حسب المدرّس والسعر والترتيب.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .76),
                fontSize: compact ? 11 : 13,
                height: 1.7,
              ),
            ),
          ],
        ),
      );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.compact,
    required this.activeCount,
    required this.onSearch,
    required this.onFilter,
  });

  final TextEditingController controller;
  final bool compact;
  final int activeCount;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final searchField = TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: 'ابحث عن كورس...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: 'بحث',
          onPressed: onSearch,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
    );

    final filterButton = OutlinedButton.icon(
      onPressed: onFilter,
      icon: Badge(
        isLabelVisible: activeCount > 0,
        label: Text('$activeCount'),
        child: const Icon(Icons.tune_rounded),
      ),
      label: Text(activeCount > 0 ? 'الفلاتر ($activeCount)' : 'الفلاتر'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(126, 54),
      ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 10),
          filterButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 10),
        filterButton,
      ],
    );
  }
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({
    required this.filter,
    required this.instructorLabel,
    required this.onChanged,
    required this.onClearAll,
  });

  final CourseFilter filter;
  final String? instructorLabel;
  final ValueChanged<CourseFilter> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (filter.instructorId != null) {
      chips.add(_FilterPill(
        icon: Icons.person_outline_rounded,
        label: instructorLabel ?? 'مدرّس',
        onDelete: () => onChanged(filter.copyWith(clearInstructor: true)),
      ));
    }
    if (filter.minPrice != null) {
      chips.add(_FilterPill(
        icon: Icons.payments_outlined,
        label: 'من ${filter.minPrice!.toStringAsFixed(0)} ر.س',
        onDelete: () => onChanged(filter.copyWith(clearMinPrice: true)),
      ));
    }
    if (filter.maxPrice != null) {
      chips.add(_FilterPill(
        icon: Icons.payments_rounded,
        label: filter.maxPrice == 0
            ? 'مجاني فقط'
            : 'حتى ${filter.maxPrice!.toStringAsFixed(0)} ر.س',
        onDelete: () => onChanged(filter.copyWith(clearMaxPrice: true)),
      ));
    }
    if (filter.sort != 'featured') {
      chips.add(_FilterPill(
        icon: Icons.sort_rounded,
        label: _sortLabel(filter.sort),
        onDelete: () => onChanged(filter.copyWith(sort: 'featured')),
      ));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.blue.withValues(alpha: .035),
        border: Border.all(color: AppTheme.blue.withValues(alpha: .12)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton.icon(
            onPressed: onClearAll,
            icon: const Icon(Icons.close_rounded, size: 17),
            label: const Text('مسح الكل'),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.icon,
    required this.label,
    required this.onDelete,
  });

  final IconData icon;
  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsetsDirectional.fromSTEB(10, 7, 7, 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppTheme.blue),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 4),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 16, color: AppTheme.muted),
              ),
            ),
          ],
        ),
      );
}

class _PremiumFiltersSheet extends StatefulWidget {
  const _PremiumFiltersSheet({required this.initial, required this.instructors});

  final CourseFilter initial;
  final List<InstructorOption> instructors;

  @override
  State<_PremiumFiltersSheet> createState() => _PremiumFiltersSheetState();
}

class _PremiumFiltersSheetState extends State<_PremiumFiltersSheet> {
  late CourseFilter _filter = widget.initial;
  late final TextEditingController _min = TextEditingController(
    text: widget.initial.minPrice?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _max = TextEditingController(
    text: widget.initial.maxPrice?.toStringAsFixed(0) ?? '',
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

  void _clearLocal() {
    setState(() {
      _filter = const CourseFilter(pageSize: 12);
      _min.clear();
      _max.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .62,
      maxChildSize: .96,
      builder: (context, scrollController) => Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppTheme.blue.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppTheme.blue),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تصفية النتائج',
                          style: TextStyle(
                            color: AppTheme.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'اختر ما يناسبك ثم طبّق الفلاتر',
                          style: TextStyle(color: AppTheme.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
                children: [
                  _FilterSection(
                    title: 'المدرّس',
                    subtitle: 'اعرض كورسات مدرّس محدد',
                    icon: Icons.school_outlined,
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _filter.instructorId ?? 0,
                      decoration: const InputDecoration(
                        hintText: 'اختر المدرّس',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 0,
                          child: Text('كل المدرّسين'),
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
                  ),
                  const SizedBox(height: 12),
                  _FilterSection(
                    title: 'السعر',
                    subtitle: 'حدد نطاق السعر أو اختر المجاني',
                    icon: Icons.payments_outlined,
                    child: Column(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final stack = constraints.maxWidth < 330;
                            final minField = TextField(
                              controller: _min,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'من',
                                suffixText: 'ر.س',
                              ),
                            );
                            final maxField = TextField(
                              controller: _max,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'إلى',
                                suffixText: 'ر.س',
                              ),
                            );
                            if (stack) {
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilterChip(
                            avatar: const Icon(Icons.redeem_rounded, size: 18),
                            label: const Text('الكورسات المجانية فقط'),
                            selected: _max.text.trim() == '0' || _filter.maxPrice == 0,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _min.clear();
                                  _max.text = '0';
                                } else {
                                  _max.clear();
                                  _filter = _filter.copyWith(clearMaxPrice: true);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FilterSection(
                    title: 'ترتيب النتائج',
                    subtitle: 'اختر الطريقة الأنسب لعرض الكورسات',
                    icon: Icons.swap_vert_rounded,
                    child: Column(
                      children: [
                        _SortOption(
                          label: 'اختيارات مميزة',
                          icon: Icons.auto_awesome_rounded,
                          value: 'featured',
                          selected: _filter.sort,
                          onTap: _setSort,
                        ),
                        _SortOption(
                          label: 'الأحدث أولًا',
                          icon: Icons.new_releases_outlined,
                          value: 'newest',
                          selected: _filter.sort,
                          onTap: _setSort,
                        ),
                        _SortOption(
                          label: 'السعر: الأقل أولًا',
                          icon: Icons.south_rounded,
                          value: 'price-low',
                          selected: _filter.sort,
                          onTap: _setSort,
                        ),
                        _SortOption(
                          label: 'السعر: الأعلى أولًا',
                          icon: Icons.north_rounded,
                          value: 'price-high',
                          selected: _filter.sort,
                          onTap: _setSort,
                        ),
                        _SortOption(
                          label: 'الترتيب الأبجدي',
                          icon: Icons.sort_by_alpha_rounded,
                          value: 'title',
                          selected: _filter.sort,
                          onTap: _setSort,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.border)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearLocal,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: const Text('مسح'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, _value()),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('عرض النتائج'),
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

  void _setSort(String value) {
    setState(() => _filter = _filter.copyWith(sort: value));
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.blue.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: AppTheme.blue),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(color: AppTheme.muted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
}

class _SortOption extends StatelessWidget {
  const _SortOption({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
    required this.onTap,
    this.showDivider = true,
  });

  final String label;
  final IconData icon;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(icon, size: 19, color: selected == value ? AppTheme.blue : AppTheme.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 12,
                        fontWeight: selected == value ? FontWeight.w900 : FontWeight.w600,
                      ),
                    ),
                  ),
                  Radio<String>(
                    value: value,
                    groupValue: selected,
                    onChanged: (v) {
                      if (v != null) onTap(v);
                    },
                  ),
                ],
              ),
            ),
          ),
          if (showDivider) const Divider(height: 1),
        ],
      );
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({required this.catalog});
  final CourseCatalog catalog;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Expanded(
            child: Text(
              'الكورسات المتاحة',
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${catalog.totalCount} كورس',
              style: const TextStyle(
                color: AppTheme.blue,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
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
          final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final course in courses)
                SizedBox(width: width, child: _CourseCard(course: course)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .96),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        course.price == 0 ? 'مجاني' : '${course.price.toStringAsFixed(0)} ر.س',
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
                      course.description.isEmpty ? 'مسار عملي لتطوير مهاراتك.' : course.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.muted, fontSize: 11, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          backgroundColor: AppTheme.blue.withValues(alpha: .1),
                          child: Text(
                            course.instructorName.isEmpty ? 'م' : course.instructorName.substring(0, 1),
                            style: const TextStyle(color: AppTheme.blue, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            course.instructorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                          ),
                        ),
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
          IconButton(
            onPressed: catalog.page > 1 ? () => onPage(catalog.page - 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'صفحة ${catalog.page} من ${catalog.totalPages}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppTheme.muted, fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton(
            onPressed: catalog.page < catalog.totalPages ? () => onPage(catalog.page + 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
        ],
      );
}

String _sortLabel(String value) => switch (value) {
      'newest' => 'الأحدث أولًا',
      'price-low' => 'الأقل سعرًا',
      'price-high' => 'الأعلى سعرًا',
      'title' => 'أبجديًا',
      _ => 'اختيارات مميزة',
    };
