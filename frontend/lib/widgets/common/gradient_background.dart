import 'package:flutter/material.dart';

class GradientBackground extends StatelessWidget {
  const GradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(0, 40, 120, 1),
            Color.fromRGBO(6, 72, 140, 1),
            Color.fromRGBO(10, 120, 140, 1),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowCircle(
              size: 220,
              color: Colors.white12,
            ),
          ),
          Positioned(
            top: 180,
            left: -90,
            child: _GlowCircle(
              size: 240,
              color: Color.fromRGBO(255, 255, 255, 0.08),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -40,
            child: _GlowCircle(
              size: 260,
              color: Color.fromRGBO(255, 255, 255, 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
