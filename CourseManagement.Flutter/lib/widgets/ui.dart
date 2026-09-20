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
    final mobile = AppBreakpoints.isMobile(width);

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          child: Stack(
            children: [
              PositionedDirectional(
                top: -120,
                end: -90,
                child: _AmbientOrb(
                  size: mobile ? 220 : 320,
                  color: AppTheme.blue.withValues(alpha: .055),
                ),
              ),
              PositionedDirectional(
                top: mobile ? 360 : 460,
                start: -130,
                child: _AmbientOrb(
                  size: mobile ? 240 : 360,
                  color: AppTheme.cyan.withValues(alpha: .045),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: AppSpacing.page(width),
              child: RepaintBoundary(child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      );
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
            Container(
              width: compact ? 34 : 38,
              height: compact ? 34 : 38,
              decoration: BoxDecoration(
                gradient: AppTheme.softAccentGradient,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: .10),
                ),
              ),
              child: Icon(
                icon ?? Icons.auto_awesome_rounded,
                size: compact ? 17 : 19,
                color: AppTheme.blue,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: .055),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppTheme.blue.withValues(alpha: .08),
                ),
              ),
              child: Text(
                eyebrow,
                style: const TextStyle(
                  color: AppTheme.blue,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontSize: compact ? 25 : 31,
                letterSpacing: -.35,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
                height: 1.8,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );

    final content = action == null
        ? text
        : compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: action!,
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 22),
                  action!,
                ],
              );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        gradient: AppTheme.surfaceGradient,
        borderRadius: BorderRadius.circular(compact ? 22 : 28),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -54,
            end: -38,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.blue.withValues(alpha: .035),
              ),
            ),
          ),
          PositionedDirectional(
            bottom: -70,
            start: -55,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan.withValues(alpha: .035),
              ),
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  const LoadingState({this.label = 'جاري تحميل البيانات...', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 28,
          vertical: compact ? 34 : 46,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 26),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.blue.withValues(alpha: .07),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.blue.withValues(alpha: .10)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              'لحظات ونجهز كل شيء',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
                height: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          height: subtitle == null ? 30 : 44,
          margin: const EdgeInsetsDirectional.only(end: 12),
          decoration: BoxDecoration(
            gradient: AppTheme.accentGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: AppTheme.blue.withValues(alpha: .16),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 19 : 21,
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
                    fontSize: 11.5,
                    height: 1.65,
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
        const SizedBox(width: 16),
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
    return Semantics(
      image: true,
      label: 'غلاف كورس ${course.title}',
      child: SizedBox(
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
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded) return child;
                  return AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    child: child,
                  );
                },
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      ColoredBox(
                        color: Colors.white.withValues(alpha: .035),
                        child: Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.white.withValues(alpha: .82),
                              value: progress.expectedTotalBytes == null
                                  ? null
                                  : progress.cumulativeBytesLoaded /
                                      progress.expectedTotalBytes!,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
    semanticLabel: 'تعذر تحميل البيانات. $message',
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
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => _StateCard(
    semanticLabel: '$title. $message',
    icon: icon,
    iconColor: AppTheme.blue,
    title: title,
    message: message,
    action: action,
  );
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.semanticLabel,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.action,
  });

  final String semanticLabel;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Semantics(
      container: true,
      liveRegion: true,
      label: semanticLabel,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 32,
          vertical: compact ? 26 : 32,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 22 : 26),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          children: [
            Container(
              width: compact ? 62 : 72,
              height: compact ? 62 : 72,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .09),
                shape: BoxShape.circle,
                border: Border.all(color: iconColor.withValues(alpha: .12)),
              ),
              child: Icon(icon, color: iconColor, size: compact ? 27 : 31),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 17 : 18,
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
      ),
    );
  }
}
