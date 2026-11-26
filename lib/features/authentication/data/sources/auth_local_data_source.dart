import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/secure_storage_service.dart';
import '../models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveUser(UserModel user);
  Future<UserModel?> getUser();
  Future<UserModel?> findRegisteredAccount(String identity);
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> clearSession();
  Future<bool> isLoggedIn();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  static const String _userKey = 'cached_auth_user';
  static const String _accountsRegistryKey = 'cached_local_accounts_v1';
  static const String _tokenKey = 'auth_token_secret';

  final SharedPreferences _prefs;
  final SecureStorageService _secureStorage;

  AuthLocalDataSourceImpl(this._prefs, this._secureStorage);

  @override
  Future<void> saveUser(UserModel user) async {
    final jsonStr = jsonEncode(user.toJson());
    await _prefs.setString(_userKey, jsonStr);
    await _upsertAccountInRegistry(user);
  }

  Future<void> _upsertAccountInRegistry(UserModel user) async {
    final raw = _prefs.getString(_accountsRegistryKey);
    final List<UserModel> existing = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          existing.add(UserModel.fromJson(item as Map<String, dynamic>));
        }
      } catch (_) {}
    }

    final idx = existing.indexWhere(
      (u) => u.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (idx >= 0) {
      existing[idx] = user;
    } else {
      existing.add(user);
    }

    await _prefs.setString(
      _accountsRegistryKey,
      jsonEncode(existing.map((e) => e.toJson()).toList()),
    );
  }

  @override
  Future<UserModel?> findRegisteredAccount(String identity) async {
    final query = identity.trim().toLowerCase();
    if (query.isEmpty) return null;
    final raw = _prefs.getString(_accountsRegistryKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      for (final item in decoded) {
        final user = UserModel.fromJson(item as Map<String, dynamic>);
        if (user.email.toLowerCase() == query ||
            user.name.trim().toLowerCase() == query) {
          return user;
        }
      }
    } catch (_) {}
    return null;
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
