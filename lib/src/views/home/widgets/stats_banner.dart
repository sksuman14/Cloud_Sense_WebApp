import 'package:flutter/material.dart';
import '../home_theme.dart';

class StatsBanner extends StatelessWidget {
  final int totalDevices;
  final int devicesReportedToday;
  final String dataPointsCount;
  final int statesCount;
  final int districtsCount;
  final ThemeProvider themeProvider;
  final double screenWidth;

  const StatsBanner({
    Key? key,
    this.totalDevices = 0,
    this.devicesReportedToday = 0,
    this.dataPointsCount = "--",
    this.statesCount = 0,
    this.districtsCount = 0,
    required this.themeProvider,
    required this.screenWidth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;
    final bool isMobile = screenWidth < 800;

    final stats = [
      (
        icon: Icons.router_outlined,
        value: '$totalDevices',
        label: 'Total Devices',
        accent: const Color(0xFF4FC3F7),
      ),
      (
        icon: Icons.bar_chart_rounded,
        value: dataPointsCount,
        label: 'Data Points',
        accent: const Color(0xFF81C784),
      ),
      (
        icon: Icons.public_rounded,
        value: '$statesCount',
        label: 'States Covered',
        accent: const Color(0xFFFFB74D),
      ),
      (
        icon: Icons.place_rounded,
        value: '$districtsCount',
        label: 'Districts Covered',
        accent: const Color(0xFFBA68C8),
      ),
    ];

    Widget buildStatCell(
        ({IconData icon, String value, String label, Color accent}) stat,
        bool isLast) {
      final valStr = stat.value.trim();
      final match = RegExp(r'^([0-9.]+)(.*)$').firstMatch(valStr);
      final targetNum = match != null ? double.tryParse(match.group(1) ?? '') : null;
      final suffix = match?.group(2) ?? '';

      Widget valueWidget;
      if (targetNum != null) {
        valueWidget = TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: targetNum),
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeOutCubic,
          builder: (context, animValue, _) {
            String displayStr = (targetNum % 1 == 0 && !valStr.contains('.'))
                ? animValue.toInt().toString()
                : animValue.toStringAsFixed(1);
            return Text(
              '$displayStr$suffix',
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: isMobile ? 24 : 42,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0D1B1E),
                letterSpacing: -1,
                height: 1.0,
              ),
            );
          },
        );
      } else {
        valueWidget = Text(
          valStr.isEmpty ? '--' : valStr,
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: isMobile ? 24 : 42,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF0D1B1E),
            letterSpacing: -1,
            height: 1.0,
          ),
        );
      }

      return Expanded(
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 16,
            vertical: isMobile ? 16 : 24,
          ),
          decoration: BoxDecoration(
            border: !isLast
                ? Border(
                    right: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.07)
                          : Colors.black.withOpacity(0.07),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with accent glow
              Container(
                width: isMobile ? 36 : 46,
                height: isMobile ? 36 : 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stat.accent.withOpacity(isDark ? 0.12 : 0.1),
                  boxShadow: [
                    BoxShadow(
                      color: stat.accent.withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  stat.icon,
                  color: stat.accent,
                  size: isMobile ? 18 : 24,
                ),
              ),
              SizedBox(height: isMobile ? 10 : 14),
              // Number
              valueWidget,
              const SizedBox(height: 6),
              // Label
              Text(
                stat.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: isMobile ? 9 : 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.5)
                      : Colors.black.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget rowWidget(
        List<({IconData icon, String value, String label, Color accent})> items) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++)
            buildStatCell(items[i], i == items.length - 1),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF0D1F2D).withOpacity(0.85),
                  const Color(0xFF0A1628).withOpacity(0.95),
                ]
              : [
                  Colors.white.withOpacity(0.95),
                  const Color(0xFFF0F7FF),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  rowWidget(stats.sublist(0, 3)),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.black.withOpacity(0.07),
                  ),
                  rowWidget(stats.sublist(3)),
                ],
              )
            : rowWidget(stats),
      ),
    );
  }
}
