import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';

Future<bool> saveCourseAssetDownload({
  required ApiClient api,
  required int courseId,
  required int assetId,
  required String fileName,
}) async {
  final destination = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ $fileName',
    fileName: fileName,
  );
  if (destination == null) return false;

  final session = await api.sessionStore.read();
  if (session == null) {
    throw const ApiException('انتهت الجلسة، يرجى تسجيل الدخول من جديد.');
  }

  final client = http.Client();
  final target = File(destination);
  final temporary = File('$destination.part');

  try {
    if (await temporary.exists()) await temporary.delete();

    final request = http.Request(
      'GET',
      api.courseAssetDownloadUri(courseId: courseId, assetId: assetId),
    )
      ..headers['Accept'] = '*/*'
      ..headers['Authorization'] = 'Bearer ${session.token}';

    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      await api.sessionStore.clear();
      api.onUnauthorized?.call();
      throw const ApiException(
        'انتهت الجلسة، يرجى تسجيل الدخول من جديد.',
        statusCode: 401,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final buffered = await http.Response.fromStream(response);
      throw ApiException(
        _extractError(buffered),
        statusCode: buffered.statusCode,
      );
    }

    final sink = temporary.openWrite(mode: FileMode.writeOnly);
    try {
      await sink.addStream(
        response.stream.timeout(const Duration(minutes: 10)),
      );
      await sink.flush();
    } finally {
      await sink.close();
    }

    if (await target.exists()) await target.delete();
    await temporary.rename(destination);
    return true;
  } on ApiException {
    rethrow;
  } catch (_) {
    throw const ApiException('تعذر تنزيل الملف من الخادم.');
  } finally {
    client.close();
    if (await temporary.exists()) {
      try {
        await temporary.delete();
      } catch (_) {
        // Best-effort cleanup of an interrupted partial download.
      }
    }
  }
}

String _extractError(http.Response response) {
  try {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['detail'] ??
            body['message'] ??
            body['title'] ??
            'حدث خطأ غير متوقع.')
        as String;
  } catch (_) {
    return 'حدث خطأ غير متوقع (${response.statusCode}).';
  }
}
