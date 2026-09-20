import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:course_management_flutter/widgets/ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[
    const Size(320, 640),
    const Size(600, 800),
    const Size(900, 800),
    const Size(1200, 800),
  ]) {
    testWidgets('shared page UI stays responsive at ${size.width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(size: size, textScaler: const TextScaler.linear(1.2)),
              child: PageContainer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AdaptivePageHeader(
                      eyebrow: 'مساحة الإدارة',
                      title: 'إدارة المستخدمين',
                      subtitle: 'راجع الحسابات والأدوار من واجهة واضحة ومتجاوبة.',
                      icon: Icons.manage_accounts_rounded,
                      action: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تحديث'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const LoadingState(),
                    const SizedBox(height: 20),
                    const SectionTitle(
                      title: 'قسم تجريبي',
                      subtitle: 'عنوان فرعي لاختبار التفاف النص على المقاسات الصغيرة.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('إدارة المستخدمين'), findsOneWidget);
      expect(find.text('تحديث'), findsOneWidget);
      expect(find.text('جاري تحميل البيانات...'), findsOneWidget);
    });
  }
}
