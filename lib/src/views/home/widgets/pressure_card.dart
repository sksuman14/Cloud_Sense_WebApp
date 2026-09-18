import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../home_theme.dart';

class AnimatedPressureCard extends StatefulWidget {
  final double pressure;
  final String formattedValue;

  const AnimatedPressureCard({
    Key? key,
    required this.pressure,
    required this.formattedValue,
  }) : super(key: key);

  @override
  State<AnimatedPressureCard> createState() => _AnimatedPressureCardState();
}

class _AnimatedPressureCardState extends State<AnimatedPressureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Gradient _getPressureGradient(double pressure) {
    final t = ((pressure - 980) / (1040 - 980)).clamp(0.0, 1.0);
    const lowPressureColor1 = Color(0xFF78909C);
    const lowPressureColor2 = Color(0xFF546E7A);
    const highPressureColor1 = Color(0xFF03A9F4);
    const highPressureColor2 = Color(0xFF0277BD);

    return LinearGradient(
      colors: [
        Color.lerp(lowPressureColor1, highPressureColor1, t)!,
        Color.lerp(lowPressureColor2, highPressureColor2, t)!,
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: _getPressureGradient(widget.pressure),
            ),
            child: CustomPaint(
              painter: _PressurePainter(
                animation: _controller,
                pressure: widget.pressure,
              ),
              size: Size.infinite,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.speed,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "Atm Pressure",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.formattedValue} hPa",
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PressurePainter extends CustomPainter {
  final Animation<double> animation;
  final double pressure;

  _PressurePainter({required this.animation, required this.pressure})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final progress = animation.value;
    final center = Offset(size.width * 0.85, size.height * 0.25);
    final maxRadius = size.width * 0.85;

    // 1. Isobaric Radar Ring Expansion
    for (int i = 0; i < 4; i++) {
      final ringProgress = (progress + i * 0.25) % 1.0;
      final radius = maxRadius * ringProgress;
      final opacity = (1.0 - ringProgress) * 0.25;

      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));

      canvas.drawCircle(center, radius, ringPaint);
    }

    // 2. Barometric Micro Floating Particles
    final particlePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final px = size.width * ((0.12 * i + progress * 0.1) % 1.0);
      final py = size.height * (0.15 + 0.7 * ((i * 0.31 + progress * 0.2) % 1.0));
      final particleOpacity = 0.35 * sin(((progress + i * 0.12) % 1.0) * pi);
      particlePaint.color = Colors.white.withOpacity(particleOpacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), 1.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PressurePainter oldDelegate) =>
      oldDelegate.pressure != pressure;
}
