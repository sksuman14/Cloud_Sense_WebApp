import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../home_theme.dart';

class AnimatedWindCard extends StatefulWidget {
  final double windSpeed;
  final String formattedValue;

  const AnimatedWindCard({
    Key? key,
    required this.windSpeed,
    required this.formattedValue,
  }) : super(key: key);

  @override
  State<AnimatedWindCard> createState() => _AnimatedWindCardState();
}

class _AnimatedWindCardState extends State<AnimatedWindCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.windSpeed > 0) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedWindCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.windSpeed > 0 && !_controller.isAnimating) {
      _controller.repeat();
    } else if (widget.windSpeed <= 0 && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.lightBlue.shade700.withOpacity(0.8),
                  Colors.blue.shade900.withOpacity(0.9)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: widget.windSpeed > 0
                ? CustomPaint(
                    painter: _WindPainter(
                      animation: _controller,
                      windSpeed: widget.windSpeed,
                    ),
                    size: ui.Size.infinite,
                  )
                : const SizedBox.shrink(),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wind_power,
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.black,
                      size: 18),
                  const SizedBox(width: 4),
                  Text("Wind Speed",
                      style: TextStyle(
                          color: themeProvider.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
                          fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "${widget.formattedValue} m/s",
                style: TextStyle(
                    color:
                        themeProvider.isDarkMode ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindParticle {
  double x;
  double y;
  final double size;
  final double offset;

  _WindParticle()
      : x = Random().nextDouble(),
        y = Random().nextDouble(),
        size = Random().nextDouble() * 2 + 1,
        offset = Random().nextDouble();
}

class _WindPainter extends CustomPainter {
  final Animation<double> animation;
  final double windSpeed;
  late final List<_WindParticle> particles;

  _WindPainter({required this.animation, required this.windSpeed})
      : super(repaint: animation) {
    final int particleCount = (windSpeed * 10).clamp(10, 80).toInt();
    particles = List.generate(particleCount, (_) => _WindParticle());
  }

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..color = Colors.white.withOpacity(0.5);

    for (var particle in particles) {
      final progress = (animation.value + particle.offset) % 1.0;
      final currentX =
          ui.lerpDouble(-size.width * 0.2, size.width * 1.2, progress)!;
      final currentY = particle.y * size.height +
          (sin(progress * 2 * pi) * particle.size * 2);

      double opacity = 1.0;
      if (progress < 0.1) {
        opacity = progress / 0.1;
      } else if (progress > 0.9) {
        opacity = (1.0 - progress) / 0.1;
      }
      paint.color = Colors.white.withOpacity(opacity * 0.5);

      canvas.drawCircle(ui.Offset(currentX, currentY), particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
