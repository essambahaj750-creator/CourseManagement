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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFEEF4FF), Color(0xFFF8FBFF), Color(0xFFF2FBF9)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 24,
                vertical: mobile ? 18 : 30,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final content = _FormContent(
                      title: title,
                      subtitle: subtitle,
                      form: form,
                      showBrand: !wide,
                    );

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(mobile ? 22 : 30),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.elevatedShadow,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: wide
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(flex: 10, child: _VisualPanel()),
                                  Expanded(
                                    flex: 9,
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(38, 42, 38, 42),
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 390),
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
                                mobile ? 20 : 30,
                                mobile ? 22 : 32,
                                mobile ? 20 : 30,
                                mobile ? 26 : 34,
                              ),
                              child: content,
                            ),
                    );
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
        const SizedBox(height: 28),
      ],
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 7),
      Text(
        subtitle,
        style: const TextStyle(color: AppTheme.muted, height: 1.75, fontSize: 13),
      ),
      const SizedBox(height: 28),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.school_rounded, color: Colors.white, size: 23),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'منصة المعرفة',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w900, fontSize: 15),
            ),
            Text(
              'تعلّم. طبّق. تقدّم.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.muted, fontWeight: FontWeight.w700, fontSize: 9),
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
      padding: const EdgeInsets.all(38),
      constraints: const BoxConstraints(minHeight: 600),
      decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
      child: Stack(
        children: [
          Positioned(
            top: -90,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -100,
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyan.withValues(alpha: .14),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: .12)),
                    ),
                    child: const Icon(Icons.school_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'منصة المعرفة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 112),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withValues(alpha: .10)),
                ),
                child: const Text(
                  'تجربة تعلم عربية حديثة',
                  style: TextStyle(color: Color(0xFFDCE8FF), fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'خطوتك القادمة\nتبدأ من هنا.',
                style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.3),
              ),
              const SizedBox(height: 16),
              Text(
                'تعلم عملي، مسارات واضحة، ومحتوى يساعدك على بناء مهارات قابلة للتطبيق.',
                style: TextStyle(color: Colors.white.withValues(alpha: .74), height: 1.8, fontSize: 13),
              ),
              const SizedBox(height: 26),
              for (final text in [
                'محتوى منظم وواضح',
                'تقدمك محفوظ في مكان واحد',
                'إدارة سهلة للطلاب والمدربين',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.check_circle_rounded, color: Color(0xFF62E1C8), size: 18),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          text,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .84),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
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
