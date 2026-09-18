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
      duration: const Duration(seconds: 10),
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

class _WindPainter extends CustomPainter {
  final Animation<double> animation;
  final double windSpeed;

  _WindPainter({required this.animation, required this.windSpeed})
      : super(repaint: animation);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final progress = animation.value;
    const darkTeal = Color(0xFF14B8A6);

    final List<Map<String, double>> airflowCurves = [
      {'yRatio': 0.22, 'lenRatio': 0.50, 'speed': 1.0, 'phase': 0.0, 'waveAmp': 4.0},
      {'yRatio': 0.40, 'lenRatio': 0.38, 'speed': 1.4, 'phase': 0.3, 'waveAmp': 3.0},
      {'yRatio': 0.58, 'lenRatio': 0.55, 'speed': 0.9, 'phase': 0.65, 'waveAmp': 5.0},
      {'yRatio': 0.75, 'lenRatio': 0.42, 'speed': 1.2, 'phase': 0.18, 'waveAmp': 3.5},
      {'yRatio': 0.88, 'lenRatio': 0.32, 'speed': 1.5, 'phase': 0.8, 'waveAmp': 2.5},
    ];

    for (var stream in airflowCurves) {
      final yBase = size.height * stream['yRatio']!;
      final streamLen = size.width * stream['lenRatio']!;
      final speedMult = stream['speed']!;
      final phaseOffset = stream['phase']!;
      final waveAmp = stream['waveAmp']!;

      final localProgress = (progress * speedMult + phaseOffset) % 1.0;
      final startX = size.width * 1.4 * localProgress - size.width * 0.4;
      final endX = startX + streamLen;

      final path = ui.Path();
      path.moveTo(startX, yBase);

      for (double x = startX; x <= endX; x += 4) {
        final normX = ((x - startX) / streamLen).clamp(0.0, 1.0);
        final yWave = yBase + sin((x / size.width * 2.5 * pi) + (progress * 3 * pi)) * waveAmp * sin(normX * pi);
        path.lineTo(x, yWave);
      }

      final alpha = sin(localProgress * pi).clamp(0.0, 1.0);
      final streamPaint = ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = ui.StrokeCap.round
        ..color = darkTeal.withOpacity((0.75 * alpha).clamp(0.0, 1.0));

      canvas.drawPath(path, streamPaint);

      if (endX > 0 && endX < size.width) {
        final headY = yBase + sin((endX / size.width * 2.5 * pi) + (progress * 3 * pi)) * waveAmp * 0.2;
        final headPaint = ui.Paint()
          ..style = ui.PaintingStyle.fill
          ..color = darkTeal.withOpacity((0.9 * alpha).clamp(0.0, 1.0));

        canvas.drawCircle(ui.Offset(endX, headY), 2.0, headPaint);
      }
    }

    final particlePaint = ui.Paint()..style = ui.PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final pProgress = (progress + i * 0.12) % 1.0;
      final px = size.width * (pProgress * 1.3 - 0.15);
      final py = size.height * (0.15 + (i * 0.11 + sin(pProgress * 2 * pi) * 0.05) % 0.75);
      final pAlpha = sin(pProgress * pi).clamp(0.0, 1.0) * 0.6;

      particlePaint.color = darkTeal.withOpacity(pAlpha.clamp(0.0, 1.0));
      canvas.drawCircle(ui.Offset(px, py), 1.5, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
