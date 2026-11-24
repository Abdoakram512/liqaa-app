import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clearSession();
  Future<bool> isLoggedIn();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _userKey = 'cached_auth_user';
  static const String _tokenKey = 'auth_token_secret';

  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  AuthLocalDataSourceImpl(this._prefs, this._secureStorage);

  @override
  Future<void> saveUser(UserModel user) async {
    final jsonStr = jsonEncode(user.toJson());
    await _prefs.setString(_userKey, jsonStr);
  }

  @override
  Future<UserModel?> getUser() async {
    final jsonStr = _prefs.getString(_userKey);
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveToken(String token) async {
    await _secureStorage.write(_tokenKey, token);
  }

  @override
  Future<String?> getToken() async {
    return _secureStorage.read(_tokenKey);
  }

  @override
  Future<void> clearSession() async {
    await _prefs.remove(_userKey);
    await _secureStorage.delete(_tokenKey);
  }

  @override
  Future<bool> isLoggedIn() async {
    final user = await getUser();
    return user != null;
  }
}
