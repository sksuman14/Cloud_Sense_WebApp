import 'package:flutter/material.dart';
import 'package:cloud_sense_webapp/src/models/derived_weather_keys.dart';

class DerivedPluckCard extends StatefulWidget {
  final DerivedPluckKeyItem item;
  final bool isDarkMode;
  final VoidCallback? onPluck;

  const DerivedPluckCard({
    Key? key,
    required this.item,
    required this.isDarkMode,
    this.onPluck,
  }) : super(key: key);

  @override
  State<DerivedPluckCard> createState() => _DerivedPluckCardState();
}

class _DerivedPluckCardState extends State<DerivedPluckCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  void _showInspectionDialog(BuildContext context) {
    if (widget.onPluck != null) {
      widget.onPluck!();
    }

    final isDark = widget.isDarkMode;
    final item = widget.item;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 720,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F1E2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
            border: Border.all(
              color: item.accentColor.withOpacity(0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Sheet Grab Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header with Title & Close
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.accentColor.withOpacity(isDark ? 0.20 : 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.accentColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Icon(item.icon, color: item.accentColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.category.icon == Icons.eco
                                      ? Colors.green.withOpacity(0.2)
                                      : item.accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.category.label.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                    color: item.accentColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0D1B1E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Measurement Hero Box
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF132A3E),
                                    const Color(0xFF0F1E2E),
                                  ]
                                : [
                                    item.accentColor.withOpacity(0.08),
                                    Colors.white,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: item.accentColor.withOpacity(0.25),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "CURRENT MEASUREMENT",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      item.value,
                                      style: TextStyle(
                                        fontFamily: 'OpenSans',
                                        fontSize: 32,
                                        fontWeight: FontWeight.w900,
                                        color: item.accentColor,
                                      ),
                                    ),
                                    if (item.unit.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        item.unit,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: item.statusColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: item.statusColor.withOpacity(0.6),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                item.statusBadge,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: item.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Metric Description
                      Text(
                        "METEOROLOGICAL SIGNIFICANCE",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.scientificMeaning,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF2D3748),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Mathematical Formula Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0A141F) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.functions_rounded,
                                    size: 16, color: item.accentColor),
                                const SizedBox(width: 6),
                                Text(
                                  "DERIVATION FORMULA",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.9,
                                    color: item.accentColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              item.formula,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.amberAccent : const Color(0xFF92400E),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Optimal Standard: ${item.optimalRange}",
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Operational Advisories
                      Text(
                        "OPERATIONAL ADVISORIES",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...item.operationalAdvisories.map((advisory) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16,
                                  color: item.accentColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  advisory,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.45,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.8)
                                        : const Color(0xFF334155),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final item = widget.item;

    final cardBorder = isDark
        ? (_isHovered
            ? item.accentColor.withOpacity(0.85)
            : item.accentColor.withOpacity(0.35))
        : (_isHovered
            ? item.accentColor.withOpacity(0.85)
            : item.accentColor.withOpacity(0.40));

    final cardBg = isDark
        ? [
            const Color(0xFF0D1E2E).withOpacity(0.85),
            const Color(0xFF091622).withOpacity(0.92),
          ]
        : [
            Colors.white.withOpacity(0.95),
            const Color(0xFFF1F5F9).withOpacity(0.90),
          ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => _showInspectionDialog(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: _isHovered ? 2.0 : 1.4),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: cardBg,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? item.accentColor.withOpacity(0.30)
                    : Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, _isHovered ? 6 : 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Subtle accent corner flare
                Positioned(
                  top: -20,
                  right: -20,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.accentColor.withOpacity(_isHovered ? 0.18 : 0.08),
                    ),
                  ),
                ),

                // Card Main Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Top Row: Category icon & Pluck pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: item.accentColor.withOpacity(isDark ? 0.18 : 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, size: 18, color: item.accentColor),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "PLUCK",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.6,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.open_in_new_rounded,
                                  size: 10,
                                  color: isDark ? Colors.white60 : Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Label / Title
                      Text(
                        item.shortLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 4),

                      // Large Value + Unit
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              item.value,
                              style: TextStyle(
                                fontFamily: 'OpenSans',
                                fontSize: item.value.length > 5 ? 18 : 22,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.unit.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              item.unit,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Status Badge Tag
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.statusColor.withOpacity(isDark ? 0.16 : 0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.statusColor.withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          item.statusBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: item.statusColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
