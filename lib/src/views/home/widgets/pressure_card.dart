import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:ui' as ui;
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
    final double t = ((pressure - 980) / (1040 - 980)).clamp(0.0, 1.0);
    final int lineCount = ui.lerpDouble(4, 9, t)!.toInt();
    final double amplitude =
        ui.lerpDouble(size.height * 0.09, size.height * 0.03, t)!;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 1; i <= lineCount; i++) {
      final path = Path();
      path.moveTo(-5, (size.height / (lineCount + 1)) * i);

      for (double x = 0; x <= size.width + 5; x++) {
        final double wave =
            sin((x * 0.02) + (animation.value * 2 * pi) + (i * 0.5));
        path.lineTo(
            x, ((size.height / (lineCount + 1)) * i) + wave * amplitude);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PressurePainter oldDelegate) =>
      oldDelegate.pressure != pressure;
}
