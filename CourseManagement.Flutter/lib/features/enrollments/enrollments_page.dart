import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/ui.dart';

class EnrollmentsPage extends StatefulWidget {
  const EnrollmentsPage({super.key});

  @override
  State<EnrollmentsPage> createState() => _EnrollmentsPageState();
}

class _EnrollmentsPageState extends State<EnrollmentsPage> {
  late Future<List<Enrollment>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiClient>().getMyEnrollments();
  }

  void _refresh() {
    setState(() => _future = context.read<ApiClient>().getMyEnrollments());
  }

  Future<void> _remove(Enrollment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء التسجيل؟'),
        content: Text('هل تريد إزالة تسجيلك من «${item.courseTitle}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إلغاء التسجيل'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await context.read<ApiClient>().unenroll(item.courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء التسجيل بنجاح.')));
      _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'مساري التعليمي',
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
                  'تسجيلاتي',
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: _refresh,
                tooltip: 'تحديث',
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.blue),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'كل الكورسات التي اخترتها محفوظة هنا لتعود إليها في أي وقت.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          FutureBuilder<List<Enrollment>>(
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
              final items = snapshot.data ?? const <Enrollment>[];
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'لم تبدأ مسارك بعد',
                  message: 'استكشف الكورسات واختر أول مسار تعليمي لتظهر تسجيلاتك هنا.',
                  icon: Icons.fact_check_rounded,
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          icon: Icons.auto_stories_rounded,
                          value: '${items.length}',
                          label: 'كورسات مسجلة',
                          color: AppTheme.blue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: _SummaryCard(
                          icon: Icons.bolt_rounded,
                          value: 'نشط',
                          label: 'حالة المسار',
                          color: AppTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EnrollmentCard(
                        item: item,
                        onRemove: () => _remove(item),
                      ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EnrollmentCard extends StatelessWidget {
  const _EnrollmentCard({required this.item, required this.onRemove});

  final Enrollment item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.blue, AppTheme.cyan],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.courseTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'تاريخ التسجيل: ${item.enrolledDate.day}/${item.enrolledDate.month}/${item.enrolledDate.year}',
                    style: const TextStyle(color: AppTheme.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              tooltip: 'إلغاء التسجيل',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFC73A48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
