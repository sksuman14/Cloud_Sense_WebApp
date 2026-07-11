import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wave/wave.dart';
import 'package:wave/config.dart';
import 'dart:ui' as ui;
import '../home_theme.dart';

class AnimatedWaveHumidityCard extends StatefulWidget {
  final double humidity;
  final String formattedValue;

  const AnimatedWaveHumidityCard({
    Key? key,
    required this.humidity,
    required this.formattedValue,
  }) : super(key: key);

  @override
  _AnimatedWaveHumidityCardState createState() =>
      _AnimatedWaveHumidityCardState();
}

class _AnimatedWaveHumidityCardState extends State<AnimatedWaveHumidityCard> {
  List<Color> _getWaveColors(double humidity) {
    final t = (humidity / 100.0).clamp(0.0, 1.0);
    const Color lowHumidityColor = Color.fromARGB(255, 61, 142, 180);
    const Color highHumidityColor = Color.fromARGB(255, 4, 116, 168);

    final Color primaryColor =
        Color.lerp(lowHumidityColor, highHumidityColor, t)!;

    return [
      primaryColor.withOpacity(0.5),
      primaryColor,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final waveColors = _getWaveColors(widget.humidity);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.water_drop_outlined,
                color: themeProvider.isDarkMode ? Colors.white : Colors.black,
                size: 18),
            const SizedBox(width: 4),
            Text(
              "Humidity",
              style: TextStyle(
                color:
                    themeProvider.isDarkMode ? Colors.white70 : Colors.black87,
                fontSize: 11,
                shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          "${widget.formattedValue} %",
          style: TextStyle(
            color: themeProvider.isDarkMode ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: const [
              Shadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 1))
            ],
          ),
        ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: widget.humidity),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeInOutCubic,
        builder: (context, animatedHumidity, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                color: themeProvider.isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
              ),
              WaveWidget(
                config: CustomConfig(
                  colors: waveColors,
                  heightPercentages: [
                    (100 - animatedHumidity) / 100,
                    (102 - animatedHumidity) / 100,
                  ],
                  durations: [8000, 6000],
                ),
                waveAmplitude: 2.0,
                size: const Size(double.infinity, double.infinity),
                backgroundColor: Colors.transparent,
              ),
              child!,
            ],
          );
        },
        child: content,
      ),
    );
  }
}
