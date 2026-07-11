import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;

class AnimatedLightCard extends StatefulWidget {
  final dynamic luxValue;
  final String name;
  final String unit;
  final Color color;

  const AnimatedLightCard({
    Key? key,
    required this.luxValue,
    required this.name,
    required this.unit,
    required this.color,
  }) : super(key: key);

  @override
  _AnimatedLightCardState createState() => _AnimatedLightCardState();
}

class _AnimatedLightCardState extends State<AnimatedLightCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _starController;
  late List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _stars = List.generate(40, (index) => _Star());
  }

  @override
  void dispose() {
    _starController.dispose();
    super.dispose();
  }

  Gradient _getLightGradient(dynamic luxValue) {
    final double lux = double.tryParse(luxValue.toString()) ?? 0.0;
    if (lux > 100) {
      return const LinearGradient(
          colors: [Color(0xffFDC830), Color(0xffF37335)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight);
    } else {
      return const LinearGradient(
          colors: [Color(0xff0f2027), Color(0xff2c5364)],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double lux = double.tryParse(widget.luxValue.toString()) ?? 0.0;
    final bool isDay = lux > 100;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: _getLightGradient(widget.luxValue),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!isDay)
              Positioned.fill(
                child: CustomPaint(
                  painter: _StarPainter(
                    stars: _stars,
                    animation: _starController,
                  ),
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 700),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: isDay
                          ? Icon(
                              Icons.wb_sunny_rounded,
                              key: const ValueKey('sun'),
                              color: widget.color,
                              size: 18,
                            )
                          : Icon(
                              Icons.nightlight_round,
                              key: const ValueKey('moon'),
                              color: widget.color,
                              size: 18,
                            ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.color.withOpacity(0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.luxValue} ${widget.unit}",
                  style: TextStyle(
                    color: widget.color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final Animation<double> animation;

  _StarPainter({required this.stars, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;

    for (var star in stars) {
      final opacity = star.getOpacity(animation.value);
      if (opacity > 0) {
        paint.color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(star.x * size.width, star.y * size.height),
            star.radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}

class _Star {
  final double x;
  final double y;
  final double radius;
  final double phase;

  _Star()
      : x = Random().nextDouble(),
        y = Random().nextDouble(),
        radius = Random().nextDouble() * 0.8 + 0.2,
        phase = Random().nextDouble();

  double getOpacity(double animationValue) {
    return (0.5 * (sin(2 * pi * (animationValue + phase)) + 1)).clamp(0.0, 1.0);
  }
}
