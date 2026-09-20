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

  test('CourseCurriculumItem parses public lesson metadata', () {
    final item = CourseCurriculumItem.fromJson({
      'id': 4,
      'position': 2,
      'title': 'إعداد المشروع',
      'type': 'Video',
    });

    expect(item.id, 4);
    expect(item.position, 2);
    expect(item.title, 'إعداد المشروع');
    expect(item.type, 'Video');
  });

  test('Enrollment parses shared progress summary', () {
    final enrollment = Enrollment.fromJson({
      'id': 8,
      'userId': 3,
      'userName': 'Student',
      'courseId': 11,
      'courseTitle': 'Course',
      'enrolledDate': '2026-09-09T10:00:00Z',
      'lastLessonAssetId': 44,
      'completedLessons': 2,
      'totalLessons': 4,
      'progressPercent': 50,
      'lastAccessedAtUtc': '2026-09-09T11:00:00Z',
    });

    expect(enrollment.lastLessonAssetId, 44);
    expect(enrollment.completedLessons, 2);
    expect(enrollment.totalLessons, 4);
    expect(enrollment.progressPercent, 50);
    expect(enrollment.hasStarted, isTrue);
    expect(enrollment.isComplete, isFalse);
  });

  test('CourseReviewSummary parses public review data', () {
    final summary = CourseReviewSummary.fromJson({
      'courseId': 11,
      'averageRating': 4.5,
      'reviewCount': 1,
      'reviews': [
        {
          'id': 1,
          'userId': 3,
          'userName': 'Student',
          'rating': 5,
          'comment': 'ممتاز',
          'createdAtUtc': '2026-09-09T10:00:00Z',
          'updatedAtUtc': '2026-09-09T10:30:00Z',
        },
      ],
    });

    expect(summary.averageRating, 4.5);
    expect(summary.reviewCount, 1);
    expect(summary.reviews.single.rating, 5);
    expect(summary.reviews.single.comment, 'ممتاز');
  });

  test('InstructorPublicProfile parses instructor metrics', () {
    final profile = InstructorPublicProfile.fromJson({
      'instructorId': 9,
      'fullName': 'مدرّس تجريبي',
      'courseCount': 2,
      'totalStudents': 18,
      'averageRating': 4.7,
      'reviewCount': 11,
      'courses': [
        {
          'id': 7,
          'title': 'Flutter',
          'description': 'Course',
          'price': 0,
          'imageUrl': null,
          'instructorId': 9,
          'instructorName': 'مدرّس تجريبي',
          'averageRating': 4.7,
          'reviewCount': 11,
          'enrolledStudents': 18,
        },
      ],
    });

    expect(profile.instructorId, 9);
    expect(profile.courseCount, 2);
    expect(profile.totalStudents, 18);
    expect(profile.averageRating, 4.7);
    expect(profile.courses.single.title, 'Flutter');
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
