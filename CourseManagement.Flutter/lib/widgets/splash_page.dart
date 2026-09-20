import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.brandGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PositionedDirectional(
              top: -120,
              end: -90,
              child: _Glow(size: 340, color: AppTheme.blue),
            ),
            PositionedDirectional(
              bottom: -150,
              start: -110,
              child: _Glow(size: 380, color: AppTheme.cyan),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 36,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .085),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .13),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 60,
                          offset: Offset(0, 24),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(0, -4 * _controller.value),
                            child: Transform.scale(
                              scale: 1 + (.025 * _controller.value),
                              child: child,
                            ),
                          ),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(29),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .26),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x4D12B8A0),
                                  blurRadius: 36,
                                  offset: Offset(0, 14),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.school_rounded,
                              size: 46,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'منصة المعرفة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'تعلّم بوضوح، طبّق بثقة، وتقدّم بخطوات محسوبة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .72),
                            fontSize: 12,
                            height: 1.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: SizedBox(
                            width: 180,
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              backgroundColor:
                                  Colors.white.withValues(alpha: .11),
                              color: const Color(0xFFB9FFF2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'نجهّز تجربتك التعليمية...',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .58),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: .22),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      );
}
