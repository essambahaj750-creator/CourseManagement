import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/models.dart';
import '../storage/session_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class CourseFilter {
  const CourseFilter({
    this.query,
    this.instructorId,
    this.minPrice,
    this.maxPrice,
    this.sort = 'featured',
    this.page = 1,
    this.pageSize = 9,
  });

  final String? query;
  final int? instructorId;
  final double? minPrice;
  final double? maxPrice;
  final String sort;
  final int page;
  final int pageSize;

  CourseFilter copyWith({
    String? query,
    int? instructorId,
    double? minPrice,
    double? maxPrice,
    String? sort,
    int? page,
    int? pageSize,
    bool clearInstructor = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) => CourseFilter(
    query: query ?? this.query,
    instructorId: clearInstructor ? null : instructorId ?? this.instructorId,
    minPrice: clearMinPrice ? null : minPrice ?? this.minPrice,
    maxPrice: clearMaxPrice ? null : maxPrice ?? this.maxPrice,
    sort: sort ?? this.sort,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );

  bool get hasActiveFilters =>
      (query?.trim().isNotEmpty ?? false) ||
      instructorId != null ||
      minPrice != null ||
      maxPrice != null ||
      sort != 'featured';
}

class ApiClient {
  ApiClient({required this.sessionStore, http.Client? client})
    : _client = client ?? http.Client();

  static const defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7026',
  );

  final SessionStore sessionStore;
  final http.Client _client;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = defaultBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';

    if (authenticated) {
      final session = await sessionStore.read();
      if (session == null) {
        throw const ApiException('انتهت الجلسة، يرجى تسجيل الدخول من جديد.');
      }
      headers['Authorization'] = 'Bearer ${session.token}';
    }

    late http.Response response;
    try {
      final uri = _uri(path, query);
      final encodedBody = body == null ? null : jsonEncode(body);
      if (method == 'GET') {
        response = await _client
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 20));
      } else if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 20));
      } else if (method == 'DELETE') {
        response = await _client
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 20));
      } else if (method == 'PUT') {
        response = await _client
            .put(uri, headers: headers, body: encodedBody)
            .timeout(const Duration(seconds: 20));
      } else {
        throw UnsupportedError('Unsupported HTTP method: $method');
      }
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'تعذر الاتصال بالخادم. تحقق من تشغيل API واتصال الشبكة.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractError(response),
        statusCode: response.statusCode,
      );
    }

    if (response.body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('استجابة غير صالحة من الخادم.');
    }
  }

  Future<List<dynamic>> _jsonListRequest(
    String method,
    String path, {
    Map<String, String>? query,
    bool authenticated = false,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (authenticated) {
      final session = await sessionStore.read();
      if (session == null) {
        throw const ApiException('انتهت الجلسة، يرجى تسجيل الدخول من جديد.');
      }
      headers['Authorization'] = 'Bearer ${session.token}';
    }

    try {
      final response = method == 'GET'
          ? await _client
                .get(_uri(path, query), headers: headers)
                .timeout(const Duration(seconds: 20))
          : await _client
                .delete(_uri(path, query), headers: headers)
                .timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          _extractError(response),
          statusCode: response.statusCode,
        );
      }
      if (response.body.trim().isEmpty) return const <dynamic>[];
      return (jsonDecode(response.body) as List<dynamic>);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiException(
        'تعذر الاتصال بالخادم. تحقق من تشغيل API واتصال الشبكة.',
      );
    }
  }

  String _extractError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return (json['detail'] ??
              json['message'] ??
              json['title'] ??
              'حدث خطأ غير متوقع.')
          as String;
    } catch (_) {
      return 'حدث خطأ غير متوقع (${response.statusCode}).';
    }
  }

  Future<AuthSession> login(String email, String password) async {
    final json = await _jsonRequest(
      'POST',
      '/api/auth/login',
      body: {'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(json);
    await sessionStore.save(session);
    return session;
  }

  Future<AuthSession> register(
    String fullName,
    String email,
    String password,
  ) async {
    final json = await _jsonRequest(
      'POST',
      '/api/auth/register',
      body: {'fullName': fullName, 'email': email, 'password': password},
    );
    final session = AuthSession.fromJson(json);
    await sessionStore.save(session);
    return session;
  }

  Future<CourseCatalog> searchCourses(CourseFilter filter) async {
    final json = await _jsonRequest(
      'GET',
      '/api/course/search',
      query: {
        if (filter.query?.trim().isNotEmpty == true) 'q': filter.query!.trim(),
        if (filter.instructorId != null)
          'instructorId': '${filter.instructorId}',
        if (filter.minPrice != null) 'minPrice': '${filter.minPrice}',
        if (filter.maxPrice != null) 'maxPrice': '${filter.maxPrice}',
        'sort': filter.sort,
        'page': '${filter.page}',
        'pageSize': '${filter.pageSize}',
      },
    );
    return CourseCatalog.fromJson(json);
  }

  Future<List<InstructorOption>> getInstructors() async {
    final list = await _jsonListRequest('GET', '/api/course/instructors');
    return list
        .whereType<Map<String, dynamic>>()
        .map(InstructorOption.fromJson)
        .toList(growable: false);
  }

  Future<Course> getCourse(int id) async {
    final json = await _jsonRequest('GET', '/api/course/$id');
    return Course.fromJson(json);
  }

  Future<Course> createCourse({
    required String title,
    required String description,
    required double price,
    String? imageUrl,
  }) async {
    final json = await _jsonRequest(
      'POST',
      '/api/course',
      authenticated: true,
      body: {
        'title': title.trim(),
        'description': description.trim(),
        'price': price,
        'imageUrl': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      },
    );
    return Course.fromJson(json);
  }

  Future<Course> updateCourse({
    required int id,
    required String title,
    required String description,
    required double price,
    String? imageUrl,
  }) async {
    final json = await _jsonRequest(
      'PUT',
      '/api/course/$id',
      authenticated: true,
      body: {
        'title': title.trim(),
        'description': description.trim(),
        'price': price,
        'imageUrl': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      },
    );
    return Course.fromJson(json);
  }

  Future<void> deleteCourse(int id) async {
    await _jsonRequest('DELETE', '/api/course/$id', authenticated: true);
  }

  Future<List<Enrollment>> getMyEnrollments() async {
    final list = await _jsonListRequest(
      'GET',
      '/api/enrollment/my',
      authenticated: true,
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(Enrollment.fromJson)
        .toList(growable: false);
  }

  Future<Enrollment> enroll(int courseId) async {
    final json = await _jsonRequest(
      'POST',
      '/api/enrollment',
      body: {'courseId': courseId},
      authenticated: true,
    );
    return Enrollment.fromJson(json);
  }

  Future<void> unenroll(int courseId) async {
    await _jsonListRequest(
      'DELETE',
      '/api/enrollment/course/$courseId',
      authenticated: true,
    );
  }

  Future<List<Enrollment>> getAllEnrollments() async {
    final list = await _jsonListRequest(
      'GET',
      '/api/enrollment',
      authenticated: true,
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(Enrollment.fromJson)
        .toList(growable: false);
  }

  Future<List<UserSummary>> getUsers() async {
    final list = await _jsonListRequest(
      'GET',
      '/api/users',
      authenticated: true,
    );
    return list
        .whereType<Map<String, dynamic>>()
        .map(UserSummary.fromJson)
        .toList(growable: false);
  }

  Future<void> changeUserRole(int userId, String role) async {
    await _jsonRequest(
      'PUT',
      '/api/users/$userId/role',
      body: {'role': role},
      authenticated: true,
    );
  }
}
