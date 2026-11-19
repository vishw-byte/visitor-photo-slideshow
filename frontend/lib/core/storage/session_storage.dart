import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/visitor_model.dart';

class SessionStorage {
  static const String _keyVisitorToken = 'visitor_session_token';
  static const String _keyVisitorProfile = 'visitor_profile_data';
  static const String _keyAdminToken = 'admin_jwt_token';
  static const String _keyAdminUsername = 'admin_username';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Saves the active visitor session token and profile data.
  Future<void> saveVisitorSession(VisitorModel visitor) async {
    try {
      await _secureStorage.write(key: _keyVisitorToken, value: visitor.sessionToken);
      await _secureStorage.write(
        key: _keyVisitorProfile,
        value: jsonEncode(visitor.toJson()),
      );
    } catch (_) {
      // Fallback for web or desktop environments where keystore may be unavailable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyVisitorToken, visitor.sessionToken);
      await prefs.setString(_keyVisitorProfile, jsonEncode(visitor.toJson()));
    }
  }

  /// Retrieves the saved session token.
  Future<String?> getSessionToken() async {
    try {
      final token = await _secureStorage.read(key: _keyVisitorToken);
      if (token != null) return token;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyVisitorToken);
  }

  /// Retrieves the saved visitor profile.
  Future<VisitorModel?> getVisitorProfile() async {
    try {
      final profileStr = await _secureStorage.read(key: _keyVisitorProfile);
      if (profileStr != null) {
        return VisitorModel.fromJson(jsonDecode(profileStr) as Map<String, dynamic>);
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final profileStr = prefs.getString(_keyVisitorProfile);
    if (profileStr != null) {
      return VisitorModel.fromJson(jsonDecode(profileStr) as Map<String, dynamic>);
    }
    return null;
  }

  /// Clears stored visitor session.
  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _keyVisitorToken);
      await _secureStorage.delete(key: _keyVisitorProfile);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVisitorToken);
    await prefs.remove(_keyVisitorProfile);
  }

  /// Saves the active admin JWT session and username.
  Future<void> saveAdminSession({
    required String token,
    required String username,
  }) async {
    try {
      await _secureStorage.write(key: _keyAdminToken, value: token);
      await _secureStorage.write(key: _keyAdminUsername, value: username);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAdminToken, token);
      await prefs.setString(_keyAdminUsername, username);
    }
  }

  /// Retrieves the saved admin JWT token.
  Future<String?> getAdminToken() async {
    try {
      final token = await _secureStorage.read(key: _keyAdminToken);
      if (token != null) return token;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminToken);
  }

  /// Retrieves the saved admin username.
  Future<String?> getAdminUsername() async {
    try {
      final username = await _secureStorage.read(key: _keyAdminUsername);
      if (username != null) return username;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAdminUsername);
  }

  /// Clears stored admin session.
  Future<void> clearAdminSession() async {
    try {
      await _secureStorage.delete(key: _keyAdminToken);
      await _secureStorage.delete(key: _keyAdminUsername);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAdminToken);
    await prefs.remove(_keyAdminUsername);
  }
}
