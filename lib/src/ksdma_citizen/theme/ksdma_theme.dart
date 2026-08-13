import 'package:flutter/material.dart';

/// Design tokens and styling for KSDMA Citizen Weather Observation Network
class KsdmaColors {
  static const Color ink = Color(0xFF0B2B2A);
  static const Color inkSoft = Color(0xFF3E5551);
  
  static const Color primary = Color(0xFF146356);
  static const Color primaryDark = Color(0xFF0A322C);
  static const Color primaryTint = Color(0xFFE4EEE9);
  
  static const Color gold = Color(0xFFE0992E);
  static const Color goldDark = Color(0xFFB87519);
  static const Color goldTint = Color(0xFFFCF0DA);
  
  static const Color rain = Color(0xFF3E7CB1);
  static const Color rainDark = Color(0xFF2C5E88);
  static const Color rainTint = Color(0xFFE7F0F7);
  
  static const Color leaf = Color(0xFF5B8C5A);
  static const Color leafTint = Color(0xFFEAF3E7);
  
  static const Color danger = Color(0xFFC1443C);
  static const Color dangerTint = Color(0xFFFBEAE8);
  
  static const Color bg = Color(0xFFF3F5EF);
  static const Color surface = Colors.white;
  static const Color line = Color(0xFFDFE4DA);
  static const Color lineSoft = Color(0xFFEBEEE6);
  
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color.fromRGBO(11, 43, 42, 0.05),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    BoxShadow(
      color: Color.fromRGBO(11, 43, 42, 0.12),
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -12,
    ),
  ];
}

/// Custom Vertical Gauge Indicator matching the HTML signature gauge element
class KsdmaGaugeIndicator extends StatelessWidget {
  final double level; // 0.0 to 1.0
  final Color fill;
  final double width;
  final double height;

  const KsdmaGaugeIndicator({
    super.key,
    required this.level,
    this.fill = KsdmaColors.rain,
    this.width = 14.0,
    this.height = 34.0,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(width / 2),
        border: Border.all(color: const Color.fromRGBO(11, 43, 42, 0.18), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular((width / 2) - 1),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Internal tick mark grid overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _GaugeTickPainter(),
              ),
            ),
            // Dynamic liquid level fill
            FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: clampedLevel,
              child: Container(
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugeTickPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromRGBO(11, 43, 42, 0.12)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(0, size.height * 0.25), Offset(size.width, size.height * 0.25), paint);
    canvas.drawLine(Offset(0, size.height * 0.50), Offset(size.width, size.height * 0.50), paint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Panel container card matching .panel
class KsdmaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const KsdmaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidget = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: KsdmaColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KsdmaColors.line),
        boxShadow: KsdmaColors.cardShadow,
      ),
      child: child,
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: cardWidget,
      );
    }
    return cardWidget;
  }
}

/// Stat Metric Card matching .stat-card
class KsdmaStatCard extends StatelessWidget {
  final String num;
  final String label;
  final String? subtext;
  final IconData? icon;
  final Color gaugeFill;

  const KsdmaStatCard({
    super.key,
    required this.num,
    required this.label,
    this.subtext,
    this.icon,
    this.gaugeFill = KsdmaColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return KsdmaCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: gaugeFill.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon ?? Icons.analytics,
              color: gaugeFill,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  num,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtext!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge tag matching .tag .tag-good, .tag-warn, .tag-bad
enum KsdmaTagType { good, warn, bad, neutral }

class KsdmaBadgeTag extends StatelessWidget {
  final String text;
  final KsdmaTagType type;
  final IconData? icon;

  const KsdmaBadgeTag({
    super.key,
    required this.text,
    this.type = KsdmaTagType.neutral,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (type) {
      case KsdmaTagType.good:
        bg = KsdmaColors.leafTint;
        fg = KsdmaColors.leaf;
        break;
      case KsdmaTagType.warn:
        bg = KsdmaColors.goldTint;
        fg = KsdmaColors.goldDark;
        break;
      case KsdmaTagType.bad:
        bg = KsdmaColors.dangerTint;
        fg = KsdmaColors.danger;
        break;
      case KsdmaTagType.neutral:
        bg = KsdmaColors.primaryTint;
        fg = KsdmaColors.primaryDark;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eyebrow Text Component matching .eyebrow
class KsdmaEyebrow extends StatelessWidget {
  final String text;
  final Color? color;

  const KsdmaEyebrow(this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        letterSpacing: 1.0,
        fontWeight: FontWeight.bold,
        color: color ?? KsdmaColors.rain,
      ),
    );
  }
}

/// Input Field Decoration Helper
InputDecoration ksdmaInputDecoration(String hint, {Widget? prefixIcon, Widget? suffixIcon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CB0A9), fontSize: 13),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: KsdmaColors.line, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: KsdmaColors.line, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: KsdmaColors.rain, width: 2.0),
    ),
  );
}
