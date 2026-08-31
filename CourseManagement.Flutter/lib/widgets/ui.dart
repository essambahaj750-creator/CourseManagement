import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/models.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({required this.child, this.maxWidth = 1240, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width < 600 ? 16.0 : width < 1024 ? 24.0 : 32.0;
    final vertical = width < 600 ? 20.0 : 28.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontal, vertical, horizontal, 48),
          child: child,
        ),
      ),
    );
  }
}

class AdaptivePageHeader extends StatelessWidget {
  const AdaptivePageHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
    this.icon,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.cyan.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppTheme.cyan),
              ),
              const SizedBox(width: 9),
            ],
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppTheme.cyan,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: AppTheme.ink,
            fontSize: compact ? 25 : 30,
            height: 1.25,
            fontWeight: FontWeight.w900,
            letterSpacing: -.35,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.7,
              ),
            ),
          ),
        ],
      ],
    );

    if (action == null) return text;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          text,
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: action!),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: text),
        const SizedBox(width: 20),
        action!,
      ],
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.label = 'جاري تحميل البيانات...', super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 54),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 520;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 5,
          height: 38,
          margin: const EdgeInsets.only(left: 11),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
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
                  letterSpacing: -.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    if (action == null) return heading;
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          heading,
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerRight, child: action!),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        action!,
      ],
    );
  }
}

class CourseCover extends StatelessWidget {
  const CourseCover({required this.course, this.height = 175, super.key});

  final Course course;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
            child: const Center(
              child: Icon(
                Icons.auto_stories_rounded,
                color: Color(0x55FFFFFF),
                size: 52,
              ),
            ),
          ),
          if (course.imageUrl != null)
            Image.network(
              _resolveCoverUrl(course.imageUrl!),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.navy.withValues(alpha: .04),
                  AppTheme.navy.withValues(alpha: .08),
                  AppTheme.navy.withValues(alpha: .82),
                ],
                stops: const [0, .45, 1],
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .93),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1808192F),
                    blurRadius: 14,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, color: AppTheme.cyan, size: 13),
                  SizedBox(width: 5),
                  Text(
                    'متاح الآن',
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 15,
            child: Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Colors.white.withValues(alpha: .18)),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ),
          Positioned(
            bottom: 17,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
              ),
              child: Text(
                course.price == 0 ? 'مجاني' : '${course.price.toStringAsFixed(2)} ر.س',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveCoverUrl(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed?.hasScheme == true) return value;
    final base = ApiClient.defaultBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return '$base${value.startsWith('/') ? value : '/$value'}';
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _StateCard(
    icon: Icons.cloud_off_rounded,
    iconColor: AppTheme.danger,
    title: 'تعذر تحميل البيانات',
    message: message,
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('حاول مرة أخرى'),
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
  Widget build(BuildContext context) => _StateCard(
    icon: icon,
    iconColor: AppTheme.blue,
    title: title,
    message: message,
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: AppTheme.border),
      boxShadow: AppTheme.softShadow,
    ),
    child: Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: .09),
            shape: BoxShape.circle,
            border: Border.all(color: iconColor.withValues(alpha: .12)),
          ),
          child: Icon(icon, color: iconColor, size: 31),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 7),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.75,
              fontSize: 12,
            ),
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 18),
          action!,
        ],
      ],
    ),
  );
}
