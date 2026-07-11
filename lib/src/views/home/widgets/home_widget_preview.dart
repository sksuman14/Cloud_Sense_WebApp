import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../home_theme.dart';

/// A premium, responsive widget that previews a 2x4 (medium rectangle) home screen widget.
///
/// It supports both Light and Dark themes (either detected automatically or overridden),
/// and automatically scales all text, icons, and padding proportionally based on the
/// available width constraints to ensure it never overflows.
class HomeScreenWidgetPreview extends StatelessWidget {
  /// The unique identifier of the device.
  final String deviceId;

  /// The current temperature reading from the device.
  final double temperature;

  /// Whether the device is online or offline.
  final bool isOnline;

  /// The formatted timestamp when the data was last updated.
  final String updatedTime;

  /// Optional theme override. If null, the widget detects the current theme dynamically
  /// using the [ThemeProvider] or [Theme.of].
  final bool? isDark;

  const HomeScreenWidgetPreview({
    Key? key,
    this.deviceId = 'ANNAM001',
    this.temperature = 30.49,
    this.isOnline = true,
    this.updatedTime = '12:26 PM',
    this.isDark,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Determine whether to use Dark mode.
    // First check explicit override, then fallback to ThemeProvider, then fallback to Theme.of
    bool isDarkModeResolved = false;
    try {
      if (isDark != null) {
        isDarkModeResolved = isDark!;
      } else {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        isDarkModeResolved = themeProvider.isDarkMode;
      }
    } catch (_) {
      // If Provider is not available (e.g. in test environment without Provider setup)
      isDarkModeResolved = isDark ?? (Theme.of(context).brightness == Brightness.dark);
    }

    // Color definitions based on the resolved theme.
    final List<Color> backgroundColors = isDarkModeResolved
        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] // Deep slate gradient
        : [const Color(0xFFE0F2FE), const Color(0xFFF0F9FF)]; // Soft sky blue gradient

    final Color borderColor = isDarkModeResolved
        ? const Color(0xFF334155) // Dark slate border
        : const Color(0xFFBAE6FD); // Muted light blue border

    final Color titleColor = isDarkModeResolved
        ? const Color(0xFFF8FAFC) // Slate-50
        : const Color(0xFF0F172A); // Slate-900

    final Color textColor = isDarkModeResolved
        ? const Color(0xFFCBD5E1) // Slate-300
        : const Color(0xFF334155); // Slate-700

    final Color labelColor = isDarkModeResolved
        ? const Color(0xFF94A3B8) // Slate-400
        : const Color(0xFF64748B); // Slate-500

    final Color statusTextColor = isDarkModeResolved
        ? (isOnline ? const Color(0xFF4ADE80) : const Color(0xFFF87171)) // Light green / Light red
        : (isOnline ? const Color(0xFF16A34A) : const Color(0xFFDC2626)); // Mid green / Mid red

    final Color cloudIconColor = isDarkModeResolved
        ? const Color(0xFF38BDF8) // Light blue
        : const Color(0xFF0284C7); // Mid blue

    final Color tempIconColor = isDarkModeResolved
        ? const Color(0xFFFB923C) // Warm orange
        : const Color(0xFFEA580C); // Dark orange

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // Base proportions off a reference width of 320px
        final double scale = width / 320.0;

        // Prevent layout from scaling to absurdly small or large sizes
        final double finalScale = scale.clamp(0.5, 2.5);

        // Scaled padding and font sizes
        final double padding = 16.0 * finalScale;
        final double titleSize = 16.0 * finalScale;
        final double bodySize = 14.0 * finalScale;
        final double tempSize = 28.0 * finalScale;
        final double subtitleSize = 11.0 * finalScale;
        final double iconSize = 18.0 * finalScale;
        final double statusDotSize = 8.0 * finalScale;

        return AspectRatio(
          aspectRatio: 2.0, // 2x4 medium widget is roughly 2:1 aspect ratio
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: backgroundColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: borderColor,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkModeResolved
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0xFF0D47A1).withValues(alpha: 0.08),
                  blurRadius: 10.0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- TOP ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cloud Sense Branding
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud,
                                color: cloudIconColor,
                                size: iconSize,
                              ),
                              SizedBox(width: 6.0 * finalScale),
                              Text(
                                'Cloud Sense',
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.bold,
                                  fontSize: titleSize,
                                  color: titleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.0 * finalScale),
                      // Online / Offline Status
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.0 * finalScale,
                            vertical: 4.0 * finalScale,
                          ),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? (isDarkModeResolved
                                    ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                                    : const Color(0xFF22C55E).withValues(alpha: 0.12))
                                : (isDarkModeResolved
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.1)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.12)),
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: statusDotSize,
                                height: statusDotSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline
                                      ? const Color(0xFF22C55E)
                                      : const Color(0xFFEF4444),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isOnline
                                          ? const Color(0xFF22C55E).withValues(alpha: 0.6)
                                          : const Color(0xFFEF4444).withValues(alpha: 0.6),
                                      blurRadius: 4.0,
                                      spreadRadius: 1.0,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 6.0 * finalScale),
                              Text(
                                isOnline ? 'Online' : 'Offline',
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.w600,
                                  fontSize: subtitleSize,
                                  color: statusTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // --- SECOND ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Device ID Info
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Device: ',
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.normal,
                                  fontSize: bodySize,
                                  color: labelColor,
                                ),
                              ),
                              Text(
                                deviceId,
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.w600, // Medium weight
                                  fontSize: bodySize,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 8.0 * finalScale),
                      // Temperature Focus
                      Flexible(
                        child: FittedBox(
                          alignment: Alignment.centerRight,
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.thermostat,
                                color: tempIconColor,
                                size: tempSize * 0.75,
                              ),
                              SizedBox(width: 2.0 * finalScale),
                              Text(
                                '${temperature.toStringAsFixed(2)}°C',
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontWeight: FontWeight.bold, // Bold primary focus
                                  fontSize: tempSize,
                                  color: titleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // --- THIRD ROW ---
                  FittedBox(
                    alignment: Alignment.centerLeft,
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Updated: $updatedTime',
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontWeight: FontWeight.normal,
                        fontSize: subtitleSize,
                        color: labelColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
