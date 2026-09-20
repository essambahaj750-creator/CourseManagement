import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AuthShell extends StatelessWidget {
  const AuthShell({
    required this.title,
    required this.subtitle,
    required this.form,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = AppBreakpoints.isMobile(width);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFF0F5FF),
              Color(0xFFF7F9FC),
              Color(0xFFF0FAF8),
            ],
            stops: [0, .52, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 0 : 24,
                vertical: mobile ? 0 : 28,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 860;
                    final content = _FormContent(
                      title: title,
                      subtitle: subtitle,
                      form: form,
                      showBrand: !wide,
                    );

                    final frame = Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          mobile ? 0 : AppRadius.xl,
                        ),
                        border: mobile
                            ? null
                            : Border.all(color: AppTheme.border),
                        boxShadow: mobile ? null : AppTheme.elevatedShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: wide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(
                                    flex: 11,
                                    child: _VisualPanel(),
                                  ),
                                  Expanded(
                                    flex: 9,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 44,
                                        vertical: 52,
                                      ),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 410,
                                          ),
                                          child: content,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.fromLTRB(
                                mobile ? 20 : 34,
                                mobile ? 30 : 38,
                                mobile ? 20 : 34,
                                mobile ? 36 : 42,
                              ),
                              child: content,
                            ),
                    );

                    if (mobile) {
                      return ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.sizeOf(context).height -
                              MediaQuery.paddingOf(context).vertical,
                        ),
                        child: frame,
                      );
                    }

                    return frame;
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.showBrand,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final bool showBrand;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBrand) ...[
            const _CompactBrand(),
            const SizedBox(height: 34),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.blue.withValues(alpha: .07),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: AppTheme.blue.withValues(alpha: .09),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 14,
                  color: AppTheme.blue,
                ),
                SizedBox(width: 6),
                Text(
                  'دخول آمن',
                  style: TextStyle(
                    color: AppTheme.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.8,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 30),
          form,
        ],
      );
}

class _CompactBrand extends StatelessWidget {
  const _CompactBrand();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: AppTheme.softShadow,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'منصة المعرفة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'تعلّم بوضوح، وتقدّم بثقة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _VisualPanel extends StatelessWidget {
  const _VisualPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(46),
      constraints: const BoxConstraints(minHeight: 660),
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Stack(
        children: [
          Positioned(
            top: -130,
            left: -100,
            child: _Orb(
              size: 330,
              color: Colors.white.withValues(alpha: .055),
              borderColor: Colors.white.withValues(alpha: .09),
            ),
          ),
          Positioned(
            bottom: -160,
            right: -120,
            child: _Orb(
              size: 390,
              color: AppTheme.cyan.withValues(alpha: .12),
              borderColor: Colors.white.withValues(alpha: .06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .12),
                      ),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 13),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منصة المعرفة',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'مساحتك للتعلم والتقدم',
                          style: TextStyle(
                            color: Color(0xFFB9C9DE),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .075),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .10),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: Color(0xFF75E7D0),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'تجربة تعلم عربية حديثة',
                      style: TextStyle(
                        color: Color(0xFFDCE8FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'خطوتك القادمة\nتبدأ من هنا.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'مسارات واضحة، محتوى عملي، وتجربة تحفظ تقدمك وتبقي ما تحتاجه قريبًا منك.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .76),
                  height: 1.9,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              const _FeaturePoint(
                icon: Icons.route_rounded,
                text: 'مسار تعلّم واضح بدون تشتيت',
              ),
              const _FeaturePoint(
                icon: Icons.bookmark_added_rounded,
                text: 'تقدمك محفوظ في مكان واحد',
              ),
              const _FeaturePoint(
                icon: Icons.devices_rounded,
                text: 'تجربة متناسقة على الموبايل والويب',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .065),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Color(0xFF75E7D0),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'بياناتك محمية وصلاحياتك واضحة داخل المنصة.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .78),
                          fontSize: 10,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeaturePoint extends StatelessWidget {
  const _FeaturePoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF75E7D0).withValues(alpha: .10),
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(
                  color: const Color(0xFF75E7D0).withValues(alpha: .10),
                ),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF75E7D0),
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .86),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.size,
    required this.color,
    required this.borderColor,
  });

  final double size;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(color: borderColor),
        ),
      );
}
