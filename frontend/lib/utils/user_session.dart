import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static int? userId;
  static String? userName;
  static String? userEmail;
  static String? userRole;

  static String _normalizedRole() {
    return (userRole ?? '').trim().toLowerCase();
  }

  // ✅ Set user data ke memory dan SharedPreferences
  static Future<void> setUser({
    required int id,
    required String name,
    required String email,
    required String role,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();
    final normalizedRole = role.trim();

    // Set ke memory
    userId = id;
    userName = normalizedName;
    userEmail = normalizedEmail;
    userRole = normalizedRole;

    // Set ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', id);
    await prefs.setString('userName', normalizedName);
    await prefs.setString('userEmail', normalizedEmail);
    await prefs.setString('userRole', normalizedRole);
    await prefs.setBool('isLoggedIn', true);
  }

  // ✅ Load user data dari SharedPreferences ke memory
  static Future<bool> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (isLoggedIn) {
      userId = prefs.getInt('userId');
      userName = prefs.getString('userName')?.trim();
      userEmail = prefs.getString('userEmail')?.trim();
      userRole = prefs.getString('userRole')?.trim();
      return true;
    }
    
    return false;
  }

  // ✅ Clear semua data (logout)
  static Future<void> clear() async {
    // Clear memory
    userId = null;
    userName = null;
    userEmail = null;
    userRole = null;

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static bool isLoggedIn() {
    return userId != null;
  }

  static bool isPilot() {
    return _normalizedRole() == 'pilot';
  }

  static bool isAdmin() {
    return _normalizedRole() == 'admin';
  }
  
  static bool isTugboat() {
    return _normalizedRole() == 'tugboat';
  }
  
  static bool isSuperadmin() {
    return _normalizedRole() == 'superadmin';
  }
}
