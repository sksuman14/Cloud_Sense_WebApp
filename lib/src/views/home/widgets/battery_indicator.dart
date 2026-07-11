import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import '../home_theme.dart';

class BatteryIndicator extends StatelessWidget {
  final double percentage;

  const BatteryIndicator({Key? key, required this.percentage})
      : super(key: key);

  (IconData, Color) _getBatteryStyle(double p) {
    return (
      DevicePrefixUtils.getBatteryIcon(p.toInt()),
      DevicePrefixUtils.getBatteryColor(p.toInt())
    );
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _getBatteryStyle(percentage);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final textColor =
        themeProvider.isDarkMode ? Colors.white70 : Colors.black87;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 2),
        Text(
          '${percentage.toStringAsFixed(2)}%',
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
