class AuthSession {
  const AuthSession({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.expiresAtUtc,
  });

  final String token;
  final int userId;
  final String fullName;
  final String email;
  final String role;
  final DateTime expiresAtUtc;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAtUtc);

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String? ?? '',
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'Student',
    expiresAtUtc:
        DateTime.tryParse(json['expiresAtUtc'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'userId': userId,
    'fullName': fullName,
    'email': email,
    'role': role,
    'expiresAtUtc': expiresAtUtc.toIso8601String(),
  };
}

class Course {
  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.instructorId,
    required this.instructorName,
  });

  final int id;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;
  final int instructorId;
  final String instructorName;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? 'كورس بدون عنوان',
    description: json['description'] as String? ?? '',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    imageUrl: (json['imageUrl'] as String?)?.trim().isEmpty == true
        ? null
        : json['imageUrl'] as String?,
    instructorId: (json['instructorId'] as num?)?.toInt() ?? 0,
    instructorName: json['instructorName'] as String? ?? 'لم يُعيّن مدرّس بعد',
  );
}

class CourseCurriculumItem {
  const CourseCurriculumItem({
    required this.id,
    required this.position,
    required this.title,
    required this.type,
  });

  final int id;
  final int position;
  final String title;
  final String type;

  factory CourseCurriculumItem.fromJson(Map<String, dynamic> json) =>
      CourseCurriculumItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        position: (json['position'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? 'درس',
        type: json['type'] as String? ?? 'Video',
      );
}

class InstructorOption {
  const InstructorOption({required this.id, required this.name});

  final int id;
  final String name;

  factory InstructorOption.fromJson(Map<String, dynamic> json) =>
      InstructorOption(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name'] as String? ?? '',
      );
}

class CourseCatalog {
  const CourseCatalog({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<Course> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  factory CourseCatalog.fromJson(Map<String, dynamic> json) => CourseCatalog(
    items: ((json['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Course.fromJson)
        .toList(growable: false),
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 9,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
  );
}

class PagedList<T> {
  const PagedList({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final int totalPages;

  bool get hasPrevious => page > 1;
  bool get hasNext => page < totalPages;

  factory PagedList.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parser,
  ) => PagedList<T>(
    items: ((json['items'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(parser)
        .toList(growable: false),
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 50,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
  );
}

class Enrollment {
  const Enrollment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.courseId,
    required this.courseTitle,
    required this.enrolledDate,
  });

  final int id;
  final int userId;
  final String userName;
  final int courseId;
  final String courseTitle;
  final DateTime enrolledDate;

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    userName: json['userName'] as String? ?? '',
    courseId: (json['courseId'] as num?)?.toInt() ?? 0,
    courseTitle: json['courseTitle'] as String? ?? 'كورس',
    enrolledDate:
        DateTime.tryParse(json['enrolledDate'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

enum CourseAssetType { video, attachment, previewVideo }

class CourseAsset {
  const CourseAsset({
    required this.id,
    required this.courseId,
    required this.originalFileName,
    required this.contentType,
    required this.sizeBytes,
    required this.type,
    required this.createdAtUtc,
    required this.downloadUrl,
  });

  final int id;
  final int courseId;
  final String originalFileName;
  final String contentType;
  final int sizeBytes;
  final CourseAssetType type;
  final DateTime createdAtUtc;
  final String downloadUrl;

  bool get isVideo => type == CourseAssetType.video;
  bool get isPreviewVideo => type == CourseAssetType.previewVideo;
  String get typeLabel => switch (type) {
    CourseAssetType.video => 'درس فيديو',
    CourseAssetType.previewVideo => 'فيديو معاينة',
    CourseAssetType.attachment => 'مرفق',
  };

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).ceil()} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory CourseAsset.fromJson(Map<String, dynamic> json) {
    final typeValue = (json['type'] as num?)?.toInt() ?? 2;
    final type = switch (typeValue) {
      1 => CourseAssetType.video,
      4 => CourseAssetType.previewVideo,
      _ => CourseAssetType.attachment,
    };
    return CourseAsset(
      id: (json['id'] as num?)?.toInt() ?? 0,
      courseId: (json['courseId'] as num?)?.toInt() ?? 0,
      originalFileName: json['originalFileName'] as String? ?? 'ملف',
      contentType: json['contentType'] as String? ?? 'application/octet-stream',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      type: type,
      createdAtUtc:
          DateTime.tryParse(json['createdAtUtc'] as String? ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      downloadUrl: json['downloadUrl'] as String? ?? '',
    );
  }
}

class UserSummary {
  const UserSummary({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  final int id;
  final String fullName;
  final String email;
  final String role;

  factory UserSummary.fromJson(Map<String, dynamic> json) => UserSummary(
    id: (json['id'] as num?)?.toInt() ?? 0,
    fullName: json['fullName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String? ?? 'Student',
  );
}
