import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import 'dart:ui' as ui;
import '../home_theme.dart';

class AnimatedRainfallCard extends StatefulWidget {
  final double rainfall;
  final String formattedValue;
  final String label;
  final double intensityMultiplier;
  final bool enableAnimation;

  const AnimatedRainfallCard({
    Key? key,
    required this.rainfall,
    required this.formattedValue,
    required this.label,
    this.intensityMultiplier = 5.0,
    this.enableAnimation = true,
  }) : super(key: key);

  @override
  State<AnimatedRainfallCard> createState() => _AnimatedRainfallCardState();
}

class _AnimatedRainfallCardState extends State<AnimatedRainfallCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<_RainDrop> _drops = [];
  int _completedCycles = 0;
  double _lastAnimationValue = 0.0;

  List<_RainDrop> _generateDrops(double rainfall) {
    final int dropCount =
        (rainfall * widget.intensityMultiplier).clamp(15, 100).toInt();
    return List.generate(dropCount, (_) => _RainDrop());
  }

  @override
  void initState() {
    super.initState();
    _drops = _generateDrops(widget.rainfall);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() {
        if (_controller.value < _lastAnimationValue) {
          setState(() {
            _completedCycles++;
          });
        }
        _lastAnimationValue = _controller.value;
      });

    if (widget.rainfall > 0 && widget.enableAnimation) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedRainfallCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.rainfall != oldWidget.rainfall) {
      setState(() {
        _drops = _generateDrops(widget.rainfall);
      });
    }

    if (widget.rainfall > 0 &&
        widget.enableAnimation &&
        !_controller.isAnimating) {
      _controller.repeat();
    } else if ((widget.rainfall <= 0 || !widget.enableAnimation) &&
        _controller.isAnimating) {
      _controller.stop();
      setState(() {
        _completedCycles = 0;
        _lastAnimationValue = 0.0;
      });
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
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grain,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                size: 18),
            const SizedBox(width: 4),
            Text(widget.label,
                style: TextStyle(
                    color: themeProvider.isDarkMode
                        ? Colors.white70
                        : Colors.black87,
                    fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text("${widget.formattedValue} mm",
            style: TextStyle(
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 16),
            textAlign: TextAlign.center),
      ],
    );

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
          ),
          if (widget.rainfall > 0 && widget.enableAnimation)
            CustomPaint(
              painter: _RainPainter(
                animation: _controller,
                drops: _drops,
                completedCycles: _completedCycles,
              ),
              size: Size.infinite,
            ),
          content,
        ],
      ),
    );
  }
}

class _RainDrop {
  final double x = Random().nextDouble();
  final double size = Random().nextDouble() * 4 + 2;
  final double offset = Random().nextDouble();
  final double speedFactor = Random().nextDouble() * 0.5 + 0.8;
}

class _RainPainter extends CustomPainter {
  final Animation<double> animation;
  final List<_RainDrop> drops;
  final int completedCycles;

  _RainPainter({
    required this.animation,
    required this.drops,
    required this.completedCycles,
  }) : super(repaint: animation);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final paint = ui.Paint()..color = Colors.white.withOpacity(0.7);
    final double continuousValue = animation.value + completedCycles;

    for (var drop in drops) {
      final progress = (continuousValue * drop.speedFactor + drop.offset) % 1.0;

      final start = ui.Offset(drop.x * size.width, -drop.size * 2);
      final end = ui.Offset(drop.x * size.width, size.height + drop.size * 2);
      final currentPos = ui.Offset.lerp(start, end, progress)!;

      final path = ui.Path();
      path.moveTo(currentPos.dx, currentPos.dy - drop.size);
      path.quadraticBezierTo(
        currentPos.dx - drop.size,
        currentPos.dy + drop.size,
        currentPos.dx,
        currentPos.dy + drop.size,
      );
      path.quadraticBezierTo(
        currentPos.dx + drop.size,
        currentPos.dy + drop.size,
        currentPos.dx,
        currentPos.dy - drop.size,
      );
      path.close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) {
    return oldDelegate.drops != drops ||
        oldDelegate.completedCycles != completedCycles;
  }
}
