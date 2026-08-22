import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../models/models.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._api);

  final ApiClient _api;
  AuthSession? session;
  String? errorMessage;
  bool isRestoring = true;
  bool isBusy = false;

  bool get isAuthenticated => session != null && !session!.isExpired;
  bool get isAdmin => session?.role.toLowerCase() == 'admin';
  bool get isInstructor =>
      session?.role.toLowerCase() == 'instructor' || isAdmin;

  Future<void> restore() async {
    try {
      session = await _api.sessionStore.read().timeout(
        const Duration(seconds: 3),
        onTimeout: () => null,
      );
    } catch (_) {
      session = null;
    } finally {
      isRestoring = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    return _run(() async {
      session = await _api.login(email.trim(), password);
    });
  }

  Future<bool> register(String fullName, String email, String password) async {
    return _run(() async {
      session = await _api.register(fullName.trim(), email.trim(), password);
    });
  }

  Future<void> logout() async {
    await _api.sessionStore.clear();
    session = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
