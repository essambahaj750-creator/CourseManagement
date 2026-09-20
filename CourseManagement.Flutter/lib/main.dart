import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/session_store.dart';
import 'features/auth/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SessionStore();
  final api = ApiClient(sessionStore: store);
  final auth = AuthController(api);
  runApp(CourseManagementApp(api: api, auth: auth));
  auth.restore();
}
