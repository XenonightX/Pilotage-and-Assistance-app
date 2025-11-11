import 'package:flutter/material.dart';

class PenundaanPage extends StatelessWidget {
  const PenundaanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          // ✅ Body Content
          Positioned.fill(
            top: 100, // Sama dengan tinggi navbar
            child: Container(
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: Text(
                  "Halaman Penundaan",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(12, 10, 80, 1),
                  ),
                ),
              ),
            ),
          ),

          // ✅ Navbar dengan tinggi 100px (sama dengan navbar.dart)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100, // ✅ Tinggi yang sama dengan navbar utama
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12), // ✅ Shadow yang sama
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      // ✅ Back Button
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color.fromRGBO(12, 10, 80, 1),
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      // ✅ Judul
                      const Text(
                        "Penundaan",
                        style: TextStyle(
                          color: Color.fromRGBO(12, 10, 80, 1),
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}