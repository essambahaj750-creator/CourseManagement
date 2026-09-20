import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/models.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _sessionKey = 'course_management_session';
  final FlutterSecureStorage _storage;

  Future<void> save(AuthSession session) async {
    final value = jsonEncode(session.toJson());
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_sessionKey, value);
    } else {
      await _storage.write(key: _sessionKey, value: value);
    }
  }

  Future<String?> _readRaw() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      return preferences.getString(_sessionKey);
    }
    return _storage.read(key: _sessionKey);
  }

  Future<AuthSession?> read() async {
    final raw = await _readRaw();
    if (raw == null || raw.isEmpty) return null;

    try {
      final session = AuthSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (session.token.isEmpty || session.isExpired) {
        await clear();
        return null;
      }
      return session;
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    if (kIsWeb) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_sessionKey);
    } else {
      await _storage.delete(key: _sessionKey);
    }
  }
}
