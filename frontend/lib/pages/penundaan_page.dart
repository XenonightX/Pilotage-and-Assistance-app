import 'package:flutter/material.dart';

class PenundaanPage extends StatelessWidget {
  const PenundaanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Penundaan"),
      ),
      body: const Center(
        child: Text(
          "Halaman Penundaan",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
