import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/models.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({required this.child, this.maxWidth = 1240, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 34),
        child: child,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      if (action != null) SizedBox(child: action),
    ],
  );
}

class CourseCover extends StatelessWidget {
  const CourseCover({required this.course, this.height = 175, super.key});

  final Course course;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.navy, AppTheme.blue, AppTheme.cyan],
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (course.imageUrl != null)
            Image.network(
              course.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: .08),
                  AppTheme.navy.withValues(alpha: .72),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'متاح الآن',
                style: TextStyle(
                  color: AppTheme.blue,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 18,
            right: 18,
            child: Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          Positioned(
            bottom: 18,
            left: 18,
            child: Text(
              course.price == 0
                  ? 'مجاني'
                  : '${course.price.toStringAsFixed(2)} ر.س',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EAF3)),
    ),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_rounded, size: 46, color: AppTheme.blue),
        const SizedBox(height: 14),
        const Text(
          'تعذر تحميل البيانات',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.7,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('حاول مرة أخرى'),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(34),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5EAF3)),
    ),
    child: Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppTheme.blue.withValues(alpha: .10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.blue, size: 30),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.muted,
            height: 1.7,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
