import 'package:flutter/material.dart';
import '../pages/dashboard/dashboard_page.dart';
// import '../pages/login/login_page.dart';

class AppRoutes {
  static Map<String, Widget Function(BuildContext)> routes = {
    '/': (context) => DashboardPage(),
    // '/login': (context) => const LoginPage(),
  };
}
