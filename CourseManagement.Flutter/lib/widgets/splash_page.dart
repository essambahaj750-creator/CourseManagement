import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppTheme.navy, AppTheme.navySoft, AppTheme.cyan],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .24),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'منصة المعرفة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'تعلم أذكى. تقدّم أسرع.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: .72),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white.withValues(alpha: .85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
