import 'package:course_management_flutter/core/network/api_client.dart';
import 'package:course_management_flutter/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CourseFilter', () {
    test('detects active filters and preserves values with copyWith', () {
      const filter = CourseFilter(
        query: 'flutter',
        minPrice: 10,
        sort: 'price-low',
      );
      final next = filter.copyWith(page: 2);

      expect(filter.hasActiveFilters, isTrue);
      expect(next.query, 'flutter');
      expect(next.minPrice, 10);
      expect(next.sort, 'price-low');
      expect(next.page, 2);
    });

    test('can explicitly clear optional filter values', () {
      const filter = CourseFilter(instructorId: 4, minPrice: 10, maxPrice: 80);
      final cleared = filter.copyWith(
        clearInstructor: true,
        clearMinPrice: true,
        clearMaxPrice: true,
      );

      expect(cleared.instructorId, isNull);
      expect(cleared.minPrice, isNull);
      expect(cleared.maxPrice, isNull);
      expect(cleared.hasActiveFilters, isFalse);
    });
  });

  test('CourseCatalog parses paginated API response', () {
    final catalog = CourseCatalog.fromJson({
      'items': [
        {
          'id': 7,
          'title': 'Flutter عملي',
          'description': 'بناء تطبيقات حديثة',
          'price': 49.99,
          'imageUrl': null,
          'instructorId': 2,
          'instructorName': 'أحمد',
        },
      ],
      'totalCount': 10,
      'page': 2,
      'pageSize': 1,
      'totalPages': 10,
    });

    expect(catalog.items.single.title, 'Flutter عملي');
    expect(catalog.items.single.price, 49.99);
    expect(catalog.page, 2);
    expect(catalog.totalPages, 10);
  });

  test('AuthSession detects expired token timestamps', () {
    final session = AuthSession.fromJson({
      'token': 'token',
      'userId': 1,
      'fullName': 'Test User',
      'email': 'test@example.com',
      'role': 'Student',
      'expiresAtUtc': DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

    expect(session.isExpired, isTrue);
  });
}
