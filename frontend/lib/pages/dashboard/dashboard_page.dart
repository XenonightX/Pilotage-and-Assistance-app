import 'package:flutter/material.dart';
import '../../widgets/navbar/navbar.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key}); // ✅ tambahkan const

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children:  [
          ResponsiveNavBarPage(), // ✅ ini harus const juga kalau konstruktor dia const
          Expanded(
            child: Center(
              child: Text("Dashboard Content Here"),
            ),
          ),
        ],
      ),
    );
  }
}
