import 'package:file_picker/file_picker.dart';

import '../network/api_client.dart';

Future<bool> saveCourseAssetDownload({
  required ApiClient api,
  required int courseId,
  required int assetId,
  required String fileName,
}) async {
  final bytes = await api.downloadCourseAsset(
    courseId: courseId,
    assetId: assetId,
  );

  final savedPath = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ $fileName',
    fileName: fileName,
    bytes: bytes,
  );
  return savedPath != null;
}
