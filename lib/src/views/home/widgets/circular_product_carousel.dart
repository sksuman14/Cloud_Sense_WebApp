import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

class ProductCardData {
  final String title;
  final String subtitle;
  final String category;
  final String imagePath;
  final Map<String, String> specs;
  final String route;

  ProductCardData({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.imagePath,
    required this.specs,
    required this.route,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Main section widget
// ─────────────────────────────────────────────────────────────────────────────
class ProductSectionV2 extends StatefulWidget {
  const ProductSectionV2({super.key});

  @override
  State<ProductSectionV2> createState() => _ProductSectionV2State();
}

class _ProductSectionV2State extends State<ProductSectionV2>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  // Shimmer animation
  AnimationController? _shimmerController;
  Animation<double>? _shimmerAnim;

  final List<ProductCardData> _allProducts = [
    ProductCardData(
      title: "Data Logger",
      subtitle: "Multi-channel wireless logger with 4G and cloud dashboard.",
      category: "Connectivity",
      imagePath: "assets/images/dataloggerrender.png",
      route: "/datalogger",
      specs: {
        "Supply": "5-16 V DC",
        "Backup": "25-30 Days",
        "Connectivity": "4G/LTE/GPS",
        "Protocol": "HTTP/MQTT/FTP",
        "IP Rating": "IP65",
      },
    ),
    ProductCardData(
      title: "Rain Gauge",
      subtitle: "Tipping Bucket mechanism for rainfall recording.",
      category: "Sensor",
      imagePath: "assets/images/gauge.png",
      route: "/raingauge",
      specs: {
        "Resolution": "0.2 / 0.5 mm",
        "Diameter": "159.5 / 200 mm",
        "Mechanism": "Tipping Bucket",
        "Material": "Rugged ABS",
        "Output": "Digital Pulse",
      },
    ),
    ProductCardData(
      title: "Ultrasonic Anemometer",
      subtitle: "Precise wind speed and direction monitoring.",
      category: "Sensor",
      imagePath: "assets/images/ultrasonic.png",
      route: "/windsensor",
      specs: {
        "Wind Speed": "0-65 m/s",
        "Direction": "0-359°",
        "Resolution": "1°",
        "Voltage": "2-16 V DC",
        "Heating": "-40 to +70℃",
      },
    ),
    ProductCardData(
      title: "Integrated Environmental Sensor",
      subtitle: "Temp, humidity, light & pressure in one compact unit.",
      category: "Sensor",
      imagePath: "assets/images/luxpressure.png",
      route: "/atrh",
      specs: {
        "Temp Range": "-40 to +85 °C",
        "Humidity Range": "0-100% RH",
        "Pressure Range": "300-1100 hPa",
        "Light Intensity Range": "0-140000 Lux",
        "Supply": "3.3 V DC",
      },
    ),
    ProductCardData(
      title: "Temperature and Humidity Probe",
      subtitle: "Accurate measurements for temperature and humidity.",
      category: "Sensor",
      imagePath: "assets/images/thprobe.png",
      route: "/probe",
      specs: {
        "Temp Range": "-40 to +85 °C",
        "Humidity Range": "0-100% RH",
        "Accuracy": "±0.1°C / ±3%",
        "Voltage": "5-12 V DC",
        "Protocol": "RS485 & 0-1 V",
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);

    // Shimmer loop
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController!, curve: Curves.easeInOut),
    );

    // Auto-scroll every 3.5s
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _allProducts.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload ALL product images immediately so they never blank on first view
    for (final p in _allProducts) {
      precacheImage(AssetImage(p.imagePath), context);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _shimmerController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    double viewportFraction = 0.9;
    if (screenWidth > 1000) {
      viewportFraction = 0.33;
    } else if (screenWidth > 700) {
      viewportFraction = 0.5;
    }

    if (_pageController.viewportFraction != viewportFraction) {
      final oldController = _pageController;
      _pageController = PageController(
        viewportFraction: viewportFraction,
        initialPage: _currentIndex,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => oldController.dispose());
    }

    return Column(
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        // Category label — same style as "ADVANCED FARM TECHNOLOGY"
        Text(
          'OUR PRODUCTS',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDarkMode
                ? Colors.blueAccent.shade200
                : const Color(0xFF1565C0),
            letterSpacing: 2.5,
          ),
        )
            .animate()
            .fadeIn(duration: 500.ms)
            .slideY(begin: -0.3, end: 0, curve: Curves.easeOut),

        const SizedBox(height: 14),

        Text(
          "Hardware Built for the Field",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: screenWidth < 600 ? 28 : 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDarkMode ? Colors.white : const Color(0xFF0D1B1E),
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 100.ms)
            .slideY(begin: 0.2, end: 0),

        const SizedBox(height: 8),

        Text(
          "Precision sensors & connectivity designed for India's harshest conditions",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: screenWidth < 600 ? 13 : 15,
            color: isDarkMode ? Colors.white54 : Colors.black54,
            fontWeight: FontWeight.w400,
          ),
        )
            .animate()
            .fadeIn(duration: 600.ms, delay: 200.ms),

        const SizedBox(height: 28),

        // ── Summary Stats ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatCardItem(
                value: "5",
                label: "Products",
                icon: Icons.inventory_2_outlined,
                isDark: isDarkMode,
                screenWidth: screenWidth,
              ),
              SizedBox(width: screenWidth < 600 ? 8 : 16),
              _StatCardItem(
                value: "IP66",
                label: "Weatherproof",
                icon: Icons.shield_outlined,
                isDark: isDarkMode,
                screenWidth: screenWidth,
              ),
              SizedBox(width: screenWidth < 600 ? 8 : 16),
              _StatCardItem(
                value: "4G",
                label: "Connectivity",
                icon: Icons.cell_tower_outlined,
                isDark: isDarkMode,
                screenWidth: screenWidth,
              ),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 48),

        // ── Carousel ─────────────────────────────────────────────────────────
        SizedBox(
          height: 520,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: _allProducts.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return _HoverProductCard(
                product: _allProducts[index],
                isDark: isDarkMode,
                shimmerAnim: _shimmerAnim,
                onTap: () => NavigationUtils.navigateTo(
                    context, _allProducts[index].route),
              )
                  .animate()
                  .fadeIn(
                      duration: 500.ms,
                      delay: Duration(milliseconds: 80 * index))
                  .slideY(
                      begin: 0.12,
                      end: 0,
                      duration: 500.ms,
                      delay: Duration(milliseconds: 80 * index),
                      curve: Curves.easeOut);
            },
          ),
        ),

        const SizedBox(height: 24),

        // ── Dots + Arrows ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(
                  screenWidth > 1000 ? 3 : _allProducts.length,
                  (index) => AnimatedContainer(
                    duration: 300.ms,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _currentIndex == index ? 24 : 8,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? (isDarkMode
                              ? const Color(0xFF40C4FF)
                              : const Color(0xFF0D47A1))
                          : (isDarkMode
                              ? const Color(0xFF40C4FF).withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.15)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildNavButton(Icons.chevron_left, () {
                    _autoScrollTimer?.cancel(); // stop auto on manual swipe
                    _pageController.previousPage(
                        duration: 500.ms, curve: Curves.easeInOut);
                  }, isDarkMode),
                  const SizedBox(width: 12),
                  _buildNavButton(Icons.chevron_right, () {
                    _autoScrollTimer?.cancel();
                    _pageController.nextPage(
                        duration: 500.ms, curve: Curves.easeInOut);
                  }, isDarkMode),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.02),
        ),
        child: Icon(icon,
            color: isDark ? Colors.white70 : const Color(0xFF0D1B1E), size: 24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card item with hover animation & icons
// ─────────────────────────────────────────────────────────────────────────────
class _StatCardItem extends StatefulWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isDark;
  final double screenWidth;

  const _StatCardItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.screenWidth,
  });

  @override
  State<_StatCardItem> createState() => _StatCardItemState();
}

class _StatCardItemState extends State<_StatCardItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isSmall = widget.screenWidth < 600;
    final accent = widget.isDark
        ? const Color(0xFF40C4FF)
        : const Color(0xFF0D47A1);

    final double cardWidth = isSmall
        ? (widget.screenWidth - 48) / 3
        : 180;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: cardWidth,
        transform: Matrix4.identity()..translate(0.0, _hovered ? -4.0 : 0.0),
        padding: EdgeInsets.symmetric(
          vertical: isSmall ? 12 : 20,
          horizontal: isSmall ? 8 : 16,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isSmall ? 12 : 18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: widget.isDark
                ? [
                    const Color(0xFF0D1F2D).withValues(alpha: _hovered ? 0.95 : 0.75),
                    const Color(0xFF0A1628).withValues(alpha: _hovered ? 0.95 : 0.75),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF4F8FD),
                  ],
          ),
          border: Border.all(
            color: accent.withValues(alpha: _hovered ? 0.6 : (widget.isDark ? 0.25 : 0.35)),
            width: _hovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: _hovered ? 0.25 : 0.05),
              blurRadius: _hovered ? 16 : 8,
              spreadRadius: _hovered ? 1 : 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: widget.isDark ? 0.4 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top icon with glowing background container
            Container(
              padding: EdgeInsets.all(isSmall ? 6 : 9),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: _hovered ? 0.18 : 0.08),
                border: Border.all(
                  color: accent.withValues(alpha: _hovered ? 0.4 : 0.15),
                  width: 1,
                ),
              ),
              child: Icon(
                widget.icon,
                size: isSmall ? 16 : 22,
                color: accent,
              ),
            ),
            SizedBox(height: isSmall ? 6 : 10),
            Text(
              widget.value,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: isSmall ? 18 : 26,
                fontWeight: FontWeight.w800,
                color: widget.isDark ? Colors.white : const Color(0xFF0D1B1E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: isSmall ? 10 : 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? accent : const Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Hover-animated product card
// ─────────────────────────────────────────────────────────────────────────────
class _HoverProductCard extends StatefulWidget {
  final ProductCardData product;
  final bool isDark;
  final Animation<double>? shimmerAnim;
  final VoidCallback onTap;

  const _HoverProductCard({
    required this.product,
    required this.isDark,
    required this.shimmerAnim,
    required this.onTap,
  });

  @override
  State<_HoverProductCard> createState() => _HoverProductCardState();
}

class _HoverProductCardState extends State<_HoverProductCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late AnimationController _borderController;
  late Animation<double> _borderAnim;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _borderAnim = CurvedAnimation(
        parent: _borderController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDark
        ? const Color(0xFF40C4FF)
        : const Color(0xFF0D47A1);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _borderAnim,
          builder: (context, child) {
            final glowOpacity = _hovered
                ? 0.5 + _borderAnim.value * 0.4
                : 0.15 + _borderAnim.value * 0.15;
            final borderWidth = _hovered
                ? 1.5 + _borderAnim.value * 0.8
                : 1.0 + _borderAnim.value * 0.5;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              transform: Matrix4.identity()
                ..translate(0.0, _hovered ? -6.0 : 0.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? [
                          const Color(0xFF0A1628),
                          const Color(0xFF0D1F2D),
                          const Color(0xFF0A1628),
                        ]
                      : [
                          Colors.white,
                          const Color(0xFFF4F8FD),
                          Colors.white,
                        ],
                ),
                border: Border.all(
                  color: accent.withValues(alpha: glowOpacity),
                  width: borderWidth,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(
                        alpha: _hovered ? 0.22 : 0.06 + _borderAnim.value * 0.06),
                    blurRadius: _hovered ? 28 : 14,
                    spreadRadius: _hovered ? 2 : 0,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(
                        alpha: widget.isDark ? 0.5 : 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: icon + category badge ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon badge with inner glow
                    AnimatedContainer(
                      duration: 300.ms,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF40C4FF).withValues(alpha: _hovered ? 0.18 : 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF40C4FF)
                              .withValues(alpha: _hovered ? 0.5 : 0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(Icons.sensors,
                          color: widget.isDark
                              ? const Color(0xFF40C4FF)
                              : const Color(0xFF0D47A1),
                          size: 22),
                    ),

                    // Glowing category badge
                    AnimatedContainer(
                      duration: 300.ms,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF40C4FF)
                              .withValues(alpha: _hovered ? 0.7 : 0.4),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: const Color(0xFF40C4FF)
                            .withValues(alpha: _hovered ? 0.12 : 0.05),
                      ),
                      child: Text(
                        widget.product.category,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          color: widget.isDark
                              ? const Color(0xFF40C4FF)
                              : const Color(0xFF0D47A1),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Title ──
                Text(
                  widget.product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: widget.isDark ? Colors.white : const Color(0xFF0D1B1E),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),

                // ── Subtitle ──
                Text(
                  widget.product.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 13.5,
                    color: widget.isDark ? Colors.white70 : Colors.black87,
                    height: 1.35,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Product Image with shimmer bg ──
                Expanded(
                  flex: 3,
                  child: widget.shimmerAnim != null
                      ? AnimatedBuilder(
                          animation: widget.shimmerAnim!,
                          builder: (context, child) {
                            final v = widget.shimmerAnim!.value;
                            return Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: widget.isDark
                                      ? [
                                          const Color(0xFF0D2137),
                                          const Color(0xFF112840),
                                          const Color(0xFF0D2137),
                                        ]
                                      : [
                                          const Color(0xFFEEF4FF),
                                          const Color(0xFFE8F0FE),
                                          const Color(0xFFEEF4FF),
                                        ],
                                  stops: [
                                    (v - 0.5).clamp(0.0, 1.0),
                                    v.clamp(0.0, 1.0),
                                    (v + 0.5).clamp(0.0, 1.0),
                                  ],
                                ),
                              ),
                              child: child,
                            );
                          },
                          child: Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              transform: Matrix4.identity()
                                ..scale(_hovered ? 1.06 : 1.0),
                              child: Image.asset(
                                widget.product.imagePath,
                                height: 160,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Image.asset(
                            widget.product.imagePath,
                            height: 160,
                            fit: BoxFit.contain,
                          ),
                        ),
                ),

                const SizedBox(height: 12),

                // ── Specs Grid ──
                _buildSpecsGrid(widget.product.specs, widget.isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecsGrid(Map<String, String> specs, bool isDark) {
    final entries = specs.entries.toList();
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 300;
      final crossAxisCount = isMobile ? 2 : 3;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: isMobile ? 2.2 : 2.5,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF40C4FF).withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF40C4FF).withValues(alpha: 0.18)
                    : Colors.black.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontFamily: 'OpenSans',
                      color: isDark
                          ? const Color(0xFF40C4FF)
                          : const Color(0xFF1565C0),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0D1B1E),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(delay: Duration(milliseconds: 60 * index))
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1));
        },
      );
    });
  }
}
