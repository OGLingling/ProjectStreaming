import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static Map<String, dynamic>? _activeUser;

  static const List<String> _sessionKeys = [
    'is_logged_in',
    'user_id',
    'firebase_uid',
    'user_email',
    'user_name',
    'user_profilePic',
  ];

  static bool get hasActiveSession => _activeUser != null;

  static Map<String, dynamic>? get activeUser => _activeUser;

  static Future<void> startSession(Map<String, dynamic> userData) async {
    _activeUser = Map<String, dynamic>.from(userData);

    final prefs = await SharedPreferences.getInstance();
    final id = userData['id']?.toString();
    final email = userData['email']?.toString();
    final name = userData['name']?.toString();
    final profilePic = userData['profilePic']?.toString();

    await prefs.setBool('is_logged_in', true);
    if (id != null && id.isNotEmpty) await prefs.setString('user_id', id);
    if (email != null && email.isNotEmpty) {
      await prefs.setString('user_email', email);
    }
    if (name != null && name.isNotEmpty) {
      await prefs.setString('user_name', name);
    }
    if (profilePic != null && profilePic.isNotEmpty) {
      await prefs.setString('user_profilePic', profilePic);
    }
  }

  static Future<void> clearStoredSession({bool signOutFirebase = false}) async {
    _activeUser = null;

    final prefs = await SharedPreferences.getInstance();
    for (final key in _sessionKeys) {
      await prefs.remove(key);
    }

    if (signOutFirebase) {
      try {
        await firebase_auth.FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error signing out Firebase session: $e');
      }
    }
  }

  static Future<void> endSession() async {
    await clearStoredSession(signOutFirebase: true);
  }
}
