import 'package:flutter/material.dart';
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
    testWidgets('shared UI states stay responsive at ${size.width.toInt()}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  const LoadingState(label: 'تحميل الكورسات'),
                  const EmptyState(
                    title: 'لا توجد نتائج',
                    message: 'جرّب تغيير البحث أو الفلاتر.',
                  ),
                  ErrorState(
                    message: 'تعذر الاتصال بالخادم',
                    onRetry: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('لحظات ونجهز كل شيء'), findsOneWidget);
      expect(find.text('لا توجد نتائج'), findsOneWidget);
      expect(find.text('حاول مرة أخرى'), findsOneWidget);
    });
  }
}
