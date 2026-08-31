import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:course_management_flutter/features/auth/auth_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final size in <Size>[
    const Size(320, 640),
    const Size(600, 800),
    const Size(1024, 768),
  ]) {
    testWidgets('AuthShell has no layout overflow at ${size.width.toInt()}px', (
      tester,
    ) async {
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
          home: MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: const TextScaler.linear(1.25),
            ),
            child: AuthShell(
              title: 'تسجيل الدخول',
              subtitle: 'ادخل إلى حسابك لمتابعة التعلم وإدارة محتواك.',
              form: Column(
                children: [
                  const TextField(
                    decoration: InputDecoration(labelText: 'البريد الإلكتروني'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text('تسجيل الدخول'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.byType(FilledButton), findsOneWidget);
    });
  }
}
