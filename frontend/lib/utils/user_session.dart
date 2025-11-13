class UserSession {
  static int? userId;
  static String? userName;
  static String? userEmail;
  static String? userRole;

  static void setUser({
    required int id,
    required String name,
    required String email,
    required String role,
  }) {
    userId = id;
    userName = name;
    userEmail = email;
    userRole = role;
  }

  static void clear() {
    userId = null;
    userName = null;
    userEmail = null;
    userRole = null;
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