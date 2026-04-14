import 'package:flutter/material.dart';
import '../../widgets/navbar/navbar.dart';
import 'package:pilotage_and_assistance_app/widgets/common/gradient_background.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key}); // ✅ tambahkan const

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const Positioned.fill(child: GradientBackground()),
          Column(
            children: [
              const ResponsiveNavBarPage(),
              const Expanded(
                child: Center(
                  child: Text("Dashboard Content Here"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
