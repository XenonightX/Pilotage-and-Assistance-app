import 'package:flutter/material.dart';

class PemanduanPage extends StatelessWidget {
  const PemanduanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pemanduan"),
      ),
      body: const Center(
        child: Text(
          "Halaman Pemanduan",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
