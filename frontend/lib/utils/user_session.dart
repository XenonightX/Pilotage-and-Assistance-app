import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static int? userId;
  static String? userName;
  static String? userEmail;
  static String? userRole;

  // ✅ Set user data ke memory dan SharedPreferences
  static Future<void> setUser({
    required int id,
    required String name,
    required String email,
    required String role,
  }) async {
    // Set ke memory
    userId = id;
    userName = name;
    userEmail = email;
    userRole = role;

    // Set ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('userId', id);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);
    await prefs.setString('userRole', role);
    await prefs.setBool('isLoggedIn', true);
  }

  // ✅ Load user data dari SharedPreferences ke memory
  static Future<bool> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    
    if (isLoggedIn) {
      userId = prefs.getInt('userId');
      userName = prefs.getString('userName');
      userEmail = prefs.getString('userEmail');
      userRole = prefs.getString('userRole');
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
    return userRole?.toLowerCase() == 'pilot';
  }

  static bool isAdmin() {
    return userRole?.toLowerCase() == 'admin';
  }
  
  static bool isTugboat() {
    return userRole?.toLowerCase() == 'tugboat';
  }
  
  static bool isSuperadmin() {
    return userRole?.toLowerCase() == 'superadmin';
  }
}