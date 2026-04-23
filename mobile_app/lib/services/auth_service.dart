import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../models/models.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static const _sessionKey = 'zm_session';

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _user = AppUser.fromJson(
            Map<String, dynamic>.from(jsonDecode(raw) as Map));
        notifyListeners();
      } catch (_) {
        await prefs.remove(_sessionKey);
      }
    }
  }

  Future<String?> login(String username, String password) async {
    username = username.trim();
    password = password.trim();
    if (username.isEmpty || password.isEmpty) {
      return 'Enter username and password.';
    }

    // Built-in admins (case-insensitive on username, exact on password)
    for (final admin in AppConfig.builtInAdmins) {
      if (admin['username']!.toLowerCase() == username.toLowerCase() &&
          admin['password'] == password) {
        await _persist(AppUser(
          username: admin['username']!,
          password: admin['password']!,
          displayName: admin['displayName']!,
          role: admin['role']!,
        ));
        return null;
      }
    }

    try {
      final users = await ApiService.instance.getUsers();
      if (users.isEmpty) {
        return 'No users returned from server. Check the Users sheet.';
      }

      // Case-insensitive, whitespace-trimmed username match.
      final needle = username.toLowerCase();
      AppUser? match;
      for (final entry in users.entries) {
        if (entry.key.toLowerCase().trim() == needle) {
          match = entry.value;
          break;
        }
      }
      if (match == null) {
        return 'User "$username" not found (${users.length} users in sheet).';
      }
      if (match.password.trim() != password) {
        return 'Wrong password.';
      }
      await _persist(match);
      return null;
    } on ApiException catch (e) {
      return 'Server error: ${e.message}';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<void> logout() async {
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
    notifyListeners();
  }

  Future<void> _persist(AppUser u) async {
    _user = u;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(u.toJson()));
    notifyListeners();
  }
}
