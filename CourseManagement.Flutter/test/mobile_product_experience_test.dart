import 'dart:convert';

import 'package:course_management_flutter/core/network/api_client.dart';
import 'package:course_management_flutter/core/storage/session_store.dart';
import 'package:course_management_flutter/core/theme/app_theme.dart';
import 'package:course_management_flutter/features/auth/auth_controller.dart';
import 'package:course_management_flutter/features/catalog/courses_v4_page.dart';
import 'package:course_management_flutter/features/home/home_v3_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  final catalogJson = jsonEncode({
    'items': [
      {
        'id': 1,
        'title': 'Flutter من الصفر',
        'description': 'تطبيق عملي متكامل',
        'price': 0,
        'imageUrl': null,
        'instructorId': 2,
        'instructorName': 'أحمد محمد',
      },
    ],
    'totalCount': 1,
    'page': 1,
    'pageSize': 12,
    'totalPages': 1,
  });

  ApiClient api() => ApiClient(
        sessionStore: SessionStore(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/instructors')) {
            return http.Response(
              jsonEncode([{'id': 2, 'name': 'أحمد محمد'}]),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            catalogJson,
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

  Future<void> pumpAt(WidgetTester tester, Widget child, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Directionality(textDirection: TextDirection.rtl, child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final width in [320.0, 360.0, 390.0, 600.0, 760.0, 900.0]) {
    testWidgets('course catalog stays usable at ${width.toInt()}px', (tester) async {
      final client = api();
      await pumpAt(
        tester,
        Provider<ApiClient>.value(value: client, child: const CoursesV4Page()),
        width,
      );
      expect(find.text('استكشف الكورسات'), findsOneWidget);
      expect(find.text('Flutter من الصفر'), findsOneWidget);
    });
  }

  for (final width in [320.0, 360.0, 390.0, 600.0]) {
    testWidgets('role-aware home stays usable at ${width.toInt()}px', (tester) async {
      final client = api();
      final auth = AuthController(client)..isRestoring = false;
      await pumpAt(
        tester,
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: client),
            ChangeNotifierProvider<AuthController>.value(value: auth),
          ],
          child: const HomeV3Page(),
        ),
        width,
      );
      expect(find.text('تعلّم مهارة جديدة بطريقة أبسط'), findsOneWidget);
      expect(find.text('Flutter من الصفر'), findsOneWidget);
    });
  }
}
