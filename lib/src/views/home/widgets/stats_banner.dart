import 'package:flutter/material.dart';
import '../home_theme.dart';

class StatsBanner extends StatelessWidget {
  final int totalDevices;
  final String dataPointsCount;
  final int statesCount;
  final int districtsCount;
  final ThemeProvider themeProvider;
  final double screenWidth;
  final VoidCallback onMyDevicesTap;
  final bool isHovered;
  final bool isPressed;
  final ValueChanged<bool> onHoverChanged;
  final ValueChanged<bool> onPressChanged;

  const StatsBanner({
    Key? key,
    required this.totalDevices,
    required this.dataPointsCount,
    required this.statesCount,
    required this.districtsCount,
    required this.themeProvider,
    required this.screenWidth,
    required this.onMyDevicesTap,
    required this.isHovered,
    required this.isPressed,
    required this.onHoverChanged,
    required this.onPressChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = themeProvider.isDarkMode;

    final stats = [
      (
        icon: Icons.router_outlined,
        value: '$totalDevices',
        label: 'Devices',
      ),
      (
        icon: Icons.bar_chart_rounded,
        value: dataPointsCount,
        label: 'Data Points',
      ),
      (
        icon: Icons.public_rounded,
        value: '$statesCount',
        label: 'States Covered',
      ),
      (
        icon: Icons.place_rounded,
        value: '$districtsCount',
        label: 'Districts Covered',
      ),
    ];

    final bool isMobile = screenWidth < 800;

    final Gradient cardBgGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isDark
          ? [
              const Color(0xFF0D1F2D).withOpacity(0.8),
              const Color(0xFF0D1F2D),
            ]
          : [
              const Color(0xFFFFFFFF),
              const Color(0xFFE3F2FD),
            ],
    );
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color labelColor =
        isDark ? Colors.white.withOpacity(0.45) : Colors.black54;
    final Color dividerColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black12;

    Widget buildMyDevicesButton() {
      return Padding(
        padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 20 : 40, vertical: isMobile ? 16 : 0),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHoverChanged(true),
          onExit: (_) => onHoverChanged(false),
          child: GestureDetector(
            onTapDown: (_) => onPressChanged(true),
            onTapUp: (_) => onPressChanged(false),
            onTapCancel: () => onPressChanged(false),
            onTap: onMyDevicesTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              transform: Matrix4.identity()
                ..scale(isPressed ? 0.95 : (isHovered ? 1.04 : 1.0)),
              transformAlignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF8B95C9).withOpacity(0.15)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isHovered
                      ? const Color(0xFF8B95C9)
                      : (isDark
                          ? const Color(0xFF8B95C9).withOpacity(0.3)
                          : Colors.black.withOpacity(0.15)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isHovered
                        ? Colors.black.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: isHovered ? 16 : 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 28,
                vertical: isMobile ? 10 : 12,
              ),
              child: isMobile
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "My Devices",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "MY",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white.withOpacity(0.5)
                                : Colors.black54,
                            letterSpacing: 2.0,
                          ),
                        ),
                        Text(
                          "DEVICES",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: 0.5,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: isDark
                              ? const Color(0xFF8B95C9)
                              : Colors.black87,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      );
    }

    Widget statsRow(
        List<({IconData icon, String value, String label})> items,
        {bool showButton = false}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(items.length, (i) {
            final stat = items[i];
            final isLastItem = i == items.length - 1;
            return IntrinsicWidth(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isMobile ? 190 : null,
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 8 : 24,
                      vertical: isMobile ? 16 : 36,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          alignment: Alignment.center,
                          width: isMobile ? 44 : 86,
                          height: isMobile ? 44 : 86,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius:
                                BorderRadius.circular(isMobile ? 12 : 16),
                          ),
                          child: Icon(
                            stat.icon,
                            color: isDark
                                ? const Color(0xFF8B95C9)
                                : const Color(0xFF0D47A1),
                            size: isMobile ? 26 : 60,
                          ),
                        ),
                        SizedBox(width: isMobile ? 12 : 20),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Builder(
                              builder: (context) {
                                final valStr = stat.value.trim();
                                if (valStr == '--' || valStr.isEmpty) {
                                  return Text(
                                    valStr,
                                    style: TextStyle(
                                      fontSize: isMobile ? 24 : 52,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  );
                                }
                                final match = RegExp(r'^([0-9.]+)(.*)$')
                                    .firstMatch(valStr);
                                double? targetNum;
                                String suffix = '';
                                if (match != null) {
                                  targetNum =
                                      double.tryParse(match.group(1) ?? '');
                                  suffix = match.group(2) ?? '';
                                }
                                if (targetNum == null) {
                                  return Text(
                                    valStr,
                                    style: TextStyle(
                                      fontSize: isMobile ? 24 : 52,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                      letterSpacing: -0.5,
                                      height: 1.0,
                                    ),
                                  );
                                }
                                return TweenAnimationBuilder<double>(
                                  tween:
                                      Tween<double>(begin: 0, end: targetNum),
                                  duration: const Duration(seconds: 2),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, animValue, child) {
                                    String displayStr;
                                    if (targetNum! % 1 == 0 &&
                                        !valStr.contains('.')) {
                                      displayStr = animValue.toInt().toString();
                                    } else {
                                      displayStr = animValue.toStringAsFixed(1);
                                    }
                                    return Text(
                                      '$displayStr$suffix',
                                      style: TextStyle(
                                        fontSize: isMobile ? 24 : 52,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                        letterSpacing: -0.5,
                                        height: 1.0,
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Text(
                              stat.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: isMobile ? 8 : 13,
                                fontWeight: FontWeight.w700,
                                color: labelColor,
                                letterSpacing: 2.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isLastItem || showButton)
                    Container(
                      width: 1,
                      height: isMobile ? 50 : 110,
                      color: dividerColor,
                    ),
                ],
              ),
            );
          }),
          if (showButton) buildMyDevicesButton(),
        ],
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 30),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: IntrinsicWidth(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: cardBgGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.35)
                            : Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.05),
                      width: 1.5,
                    ),
                  ),
                  child: isMobile
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            statsRow(stats.sublist(0, 2), showButton: false),
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: dividerColor,
                            ),
                            statsRow(stats.sublist(2), showButton: false),
                            Container(
                              height: 1,
                              width: double.infinity,
                              color: dividerColor,
                            ),
                            buildMyDevicesButton(),
                          ],
                        )
                      : statsRow(stats, showButton: true),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
