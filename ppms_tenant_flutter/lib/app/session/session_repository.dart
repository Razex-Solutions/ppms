import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/session_models.dart';

class SessionRepository {
  static const _tokensKey = 'auth_tokens';
  static const _localeKey = 'app_locale';

  Future<AuthTokens?> loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tokensKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokensKey, jsonEncode(tokens.toJson()));
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokensKey);
  }

  Future<String?> loadLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey);
  }

  Future<void> saveLocaleCode(String localeCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, localeCode);
  }
}
