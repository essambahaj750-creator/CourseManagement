import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:course_management_flutter/app.dart';
import 'package:course_management_flutter/core/network/api_client.dart';
import 'package:course_management_flutter/core/storage/session_store.dart';
import 'package:course_management_flutter/features/auth/auth_controller.dart';
import 'package:course_management_flutter/features/auth/login_page.dart';
import 'package:course_management_flutter/models/models.dart';

void main() {
  group('ApiClient authentication', () {
    test('adds bearer token to authenticated requests', () async {
      final store = _FakeSessionStore(_validSession());
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        expect(request.url.path, '/api/course/7/assets');
        return http.Response('[]', 200);
      });
      final api = ApiClient(sessionStore: store, client: client);

      final assets = await api.getCourseAssets(7);

      expect(assets, isEmpty);
      expect(store.clearCount, 0);
    });

    test('401 clears stored session and notifies AuthController', () async {
      final store = _FakeSessionStore(_validSession());
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'detail': 'expired'}),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
      final api = ApiClient(sessionStore: store, client: client);
      final auth = AuthController(api);
      await auth.restore();
      expect(auth.isAuthenticated, isTrue);

      await expectLater(
        api.getCourseAssets(3),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 401)
              .having(
                (error) => error.message,
                'message',
                contains('انتهت الجلسة'),
              ),
        ),
      );

      expect(store.clearCount, 1);
      expect(store.current, isNull);
      expect(auth.session, isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.errorMessage, contains('انتهت الجلسة'));
    });

    test('login stores the returned session through SessionStore', () async {
      final store = _FakeSessionStore(null);
      final expires = DateTime.now().toUtc().add(const Duration(hours: 1));
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/auth/login');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
        expect(body['password'], 'secret');
        return http.Response(
          jsonEncode({
            'token': 'new-token',
            'userId': 12,
            'fullName': 'Test User',
            'email': 'user@example.com',
            'role': 'Student',
            'expiresAtUtc': expires.toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final api = ApiClient(sessionStore: store, client: client);
      final auth = AuthController(api);

      final success = await auth.login(' user@example.com ', 'secret');

      expect(success, isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.session?.token, 'new-token');
      expect(store.current?.token, 'new-token');
      expect(store.saveCount, 1);
    });
  });

  testWidgets('router sends unauthenticated users to login after restore', (
    tester,
  ) async {
    final store = _FakeSessionStore(null);
    final api = ApiClient(
      sessionStore: store,
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final auth = AuthController(api);

    await tester.pumpWidget(CourseManagementApp(api: api, auth: auth));
    await auth.restore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LoginPage), findsOneWidget);
    expect(auth.isAuthenticated, isFalse);
  });
}

AuthSession _validSession() => AuthSession(
  token: 'test-token',
  userId: 42,
  fullName: 'Test User',
  email: 'test@example.com',
  role: 'Instructor',
  expiresAtUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
);

class _FakeSessionStore extends SessionStore {
  _FakeSessionStore(this.current);

  AuthSession? current;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<AuthSession?> read() async => current;

  @override
  Future<void> save(AuthSession session) async {
    saveCount += 1;
    current = session;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    current = null;
  }
}
