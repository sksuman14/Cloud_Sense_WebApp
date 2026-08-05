import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

class ProductCardData {
  final String title;
  final String subtitle;
  final String category;
  final String code;
  final String imagePath;
  final List<Map<String, String>> specs;
  final String route;
  final String highlight;
  final double imageScale;
  final Offset imageOffset;

  ProductCardData({
    required this.title,
    required this.subtitle,
    required this.category,
    required this.code,
    required this.imagePath,
    required this.specs,
    required this.route,
    required this.highlight,
    this.imageScale = 1.25,
    this.imageOffset = Offset.zero,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Dribbble-Style Overlapping 3D Product Showcase Section
// ─────────────────────────────────────────────────────────────────────────────
class ProductSectionV2 extends StatefulWidget {
  const ProductSectionV2({super.key});

  @override
  State<ProductSectionV2> createState() => _ProductSectionV2State();
}

class _ProductSectionV2State extends State<ProductSectionV2> {
  int _currentIndex = 0;
  Timer? _autoScrollTimer;

  final List<ProductCardData> _allProducts = [
    ProductCardData(
      title: "Data Logger",
      subtitle: "Reliable data logging & seamless connectivity",
      category: "CONNECTIVITY",
      code: "REF: CS-LOG-4G",
      imagePath: "assets/images/dataloggerrender.png",
      route: "/datalogger",
      highlight: "4G DUAL SIM · IP65 · SOLAR READY",
      imageScale: 1.35,
      specs: [
        {"label": "Supply voltage", "value": "5–16 V DC"},
        {"label": "Data protocols", "value": "HTTP, HTTPS, MQTT, FTP"},
        {"label": "Interfaces", "value": "ADC, UART, I2C, SPI, RS232, RS485"},
        {"label": "Data backup", "value": "25–30 days storage"},
        {"label": "Connectivity", "value": "4G Dual SIM & GPS"},
      ],
    ),
    ProductCardData(
      title: "Rain Gauge",
      subtitle: "Tipping bucket rain gauge for precise rainfall measurement",
      category: "PRECIPITATION",
      code: "REF: CS-RG-200",
      imagePath: "assets/images/gauge.png",
      route: "/raingauge",
      highlight: "TIPPING BUCKET · REED SWITCH · ABS",
      imageScale: 1.35,
      specs: [
        {"label": "Measurement res.", "value": "0.2 mm / 0.5 mm"},
        {"label": "Collection area", "value": "200 cm² / 314 cm²"},
        {"label": "Sensor type", "value": "Magnetic reed switch"},
        {"label": "Digital output", "value": "Pulse output (Tips × Res)"},
        {"label": "Material", "value": "UV-resistant high-impact ABS"},
      ],
    ),
    ProductCardData(
      title: "Ultrasonic Anemometer",
      subtitle: "Precise wind speed and wind direction monitoring",
      category: "WIND SENSOR",
      code: "REF: CS-WIND-360",
      imagePath: "assets/images/ultrasonic.png",
      route: "/windsensor",
      highlight: "δ ToF WIND SENSING · RS485 / RS232",
      imageScale: 1.90, // Zoomed in large
      imageOffset: const Offset(25.0, 0.0), // Center offset for Ultrasonic
      specs: [
        {"label": "Max wind speed", "value": "65 m/s (234 km/h)"},
        {"label": "Direction coverage", "value": "0°–359°, 1° resolution"},
        {"label": "Measurement method", "value": "Delta Time-of-Flight (δ ToF)"},
        {"label": "Input supply voltage", "value": "2 V – 16 V DC"},
        {"label": "Moving parts", "value": "None — fully solid state"},
      ],
    ),
    ProductCardData(
      title: "Temp, Humidity, Light & Pressure",
      subtitle: "Compact environmental sensing unit for precise measurements",
      category: "MULTISENSOR",
      code: "REF: CS-ENV-LUX",
      imagePath: "assets/images/luxpressure.png",
      route: "/atrh",
      highlight: "MULTI-PARAMETER · IP65 · I2C",
      imageScale: 1.70,
      specs: [
        {"label": "Supply voltage", "value": "3.3 V DC"},
        {"label": "Temperature range", "value": "−40 to +85 °C"},
        {"label": "Humidity range", "value": "0–100% RH"},
        {"label": "Pressure range", "value": "300–1100 hPa"},
        {"label": "Light intensity", "value": "0–140 000 Lux"},
      ],
    ),
    ProductCardData(
      title: "Temperature & Humidity Probe",
      subtitle: "Accurate measurements for temperature and humidity",
      category: "PROBE SENSOR",
      code: "REF: CS-THP-485",
      imagePath: "assets/images/thprobe.png",
      route: "/probe",
      highlight: "PRECISION SENSING · RS485 / ADC",
      specs: [
        {"label": "Supply voltage", "value": "5–12 V DC"},
        {"label": "Temperature range", "value": "−40 to +85 °C"},
        {"label": "Humidity range", "value": "0–100% RH"},
        {"label": "Digital output", "value": "RS485 (Modbus RTU)"},
        {"label": "Temp accuracy", "value": "±0.1 °C"},
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % _allProducts.length;
      });
    });
  }

  void _selectProduct(int index) {
    _startTimer();
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final p in _allProducts) {
      precacheImage(AssetImage(p.imagePath), context);
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final activeProduct = _allProducts[_currentIndex];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: screenWidth < 600 ? 32 : 56,
        horizontal: screenWidth < 600 ? 16 : 32,
      ),
      child: Column(
        children: [
          // ── 1. Section Header (Matching ADVANCED FARM TECHNOLOGY styling) ─
          Text(
            "OUR HARDWARE LINEUP",
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.blueAccent.shade200 : const Color(0xFF1565C0),
              letterSpacing: 2.5,
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 12),

          Text(
            "Precision Hardware for Field Operations",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: screenWidth < 600 ? 26 : 38,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDarkMode ? Colors.white : const Color(0xFF0D1B1E),
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 8),

          Text(
            "Industrial telemetry & sensors engineered to survive India's harshest weather.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: screenWidth < 600 ? 13 : 15,
              color: isDarkMode ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(duration: 500.ms, delay: 200.ms),

          const SizedBox(height: 28),

          // ── 2. Top Product Selector Pills ──────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_allProducts.length, (index) {
                final isSelected = index == _currentIndex;
                final prod = _allProducts[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: InkWell(
                    onTap: () => _selectProduct(index),
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: isDarkMode
                                    ? [const Color(0xFF00B0FF), const Color(0xFF0077C2)]
                                    : [const Color(0xFF0D47A1), const Color(0xFF1976D2)],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04)),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.1)),
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: (isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1))
                                      .withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getCategoryIcon(prod.category),
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : (isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            prod.title,
                            style: TextStyle(
                              fontFamily: 'OpenSans',
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDarkMode ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 36),

          // ── 3. Main Dribbble 3D Overlapping Card ───────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: _DribbbleOverlappingProductCard(
              product: activeProduct,
              allProducts: _allProducts,
              currentIndex: _currentIndex,
              isDark: isDarkMode,
              onSelectProduct: _selectProduct,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case "CONNECTIVITY":
        return Icons.cell_tower_outlined;
      case "PRECIPITATION":
        return Icons.water_drop_outlined;
      case "WIND SENSOR":
        return Icons.air_outlined;
      case "MULTISENSOR":
        return Icons.wb_sunny_outlined;
      case "PROBE SENSOR":
        return Icons.thermostat_outlined;
      default:
        return Icons.hardware_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Dribbble 3D Overlapping Card Component with Max Zoomed Product Image
// ─────────────────────────────────────────────────────────────────────────────
class _DribbbleOverlappingProductCard extends StatefulWidget {
  final ProductCardData product;
  final List<ProductCardData> allProducts;
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onSelectProduct;

  const _DribbbleOverlappingProductCard({
    required this.product,
    required this.allProducts,
    required this.currentIndex,
    required this.isDark,
    required this.onSelectProduct,
  });

  @override
  State<_DribbbleOverlappingProductCard> createState() =>
      _DribbbleOverlappingProductCardState();
}

class _DribbbleOverlappingProductCardState
    extends State<_DribbbleOverlappingProductCard> {
  bool _imageHovered = false;
  bool _buttonHovered = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 920;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
    );
  }

  // ── Desktop 3D Overlapping Layout (Max Zoomed Image) ──────────────────────
  Widget _buildDesktopLayout() {
    return Container(
      key: ValueKey("desktop_${widget.product.code}"),
      height: 520,
      margin: const EdgeInsets.all(12),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Right Overlapping Details Background Card ─────────────────────
          Positioned(
            left: 360,
            right: 0,
            top: 20,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.only(left: 64, right: 36, top: 32, bottom: 32),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF0F1C2E) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: widget.isDark
                      ? const Color(0xFF40C4FF).withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : Colors.black.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: _buildProductDetailsContent(),
            ),
          ),

          // ── Left Floating Elevated Image Card (3D Overlapping Front) ──────
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 400,
            child: MouseRegion(
              onEnter: (_) => setState(() => _imageHovered = true),
              onExit: (_) => setState(() => _imageHovered = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                transform: Matrix4.identity()
                  ..translate(0.0, _imageHovered ? -8.0 : 0.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isDark
                        ? [
                            const Color(0xFF005082),
                            const Color(0xFF002F56),
                            const Color(0xFF07182B),
                          ]
                        : [
                            const Color(0xFFE0F2FE),
                            const Color(0xFFBAE6FD),
                            const Color(0xFF7DD3FC),
                          ],
                  ),
                  border: Border.all(
                    color: widget.isDark
                        ? const Color(0xFF40C4FF).withValues(alpha: 0.4)
                        : const Color(0xFF0284C7).withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0284C7))
                          .withValues(alpha: _imageHovered ? 0.35 : 0.18),
                      blurRadius: _imageHovered ? 32 : 20,
                      spreadRadius: _imageHovered ? 2 : 0,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(
                    children: [
                      // Center Hero Image (PERFECTLY CENTERED & ZOOMED)
                      Positioned.fill(
                        top: 20,
                        bottom: 75,
                        left: 12,
                        right: 12,
                        child: Center(
                          child: AnimatedScale(
                            alignment: Alignment.center,
                            scale: _imageHovered
                                ? widget.product.imageScale * 1.06
                                : widget.product.imageScale,
                            duration: const Duration(milliseconds: 250),
                             child: Transform.translate(
                               offset: widget.product.imageOffset,
                               child: Image.asset(
                                 widget.product.imagePath,
                                 alignment: Alignment.center,
                                 fit: BoxFit.contain,
                                 frameBuilder: (context, child, frame, wasLoaded) {
                                   if (wasLoaded || frame != null) return child;
                                   return const Center(
                                     child: CircularProgressIndicator(strokeWidth: 2),
                                   );
                                 },
                               ),
                             ),
                          ),
                        ),
                      ),

                      // Bottom Glassmorphic Thumbnail Bar
                      Positioned(
                        bottom: 14,
                        left: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: (widget.isDark ? Colors.black : Colors.white)
                                .withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(widget.allProducts.length, (idx) {
                              final p = widget.allProducts[idx];
                              final isSelected = idx == widget.currentIndex;
                              return GestureDetector(
                                onTap: () => widget.onSelectProduct(idx),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 44,
                                  height: 44,
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (widget.isDark
                                            ? const Color(0xFF40C4FF).withValues(alpha: 0.25)
                                            : const Color(0xFF0D47A1).withValues(alpha: 0.15))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? (widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1))
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Image.asset(p.imagePath, fit: BoxFit.contain),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile / Tablet Stacked Layout ─────────────────────────────────────────
  Widget _buildMobileLayout() {
    return Container(
      key: ValueKey("mobile_${widget.product.code}"),
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F1C2E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF40C4FF).withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Image Container (Zoomed In)
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDark
                    ? [const Color(0xFF005082), const Color(0xFF07182B)]
                    : [const Color(0xFFE0F2FE), const Color(0xFF7DD3FC)],
              ),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  top: 16,
                  bottom: 56,
                  left: 12,
                  right: 12,
                  child: Transform.scale(
                    scale: widget.product.imageScale * 0.95,
                    child: Transform.translate(
                      offset: widget.product.imageOffset,
                      child: Image.asset(widget.product.imagePath, fit: BoxFit.contain),
                    ),
                  ),
                ),

                // Thumbnails at bottom
                Positioned(
                  bottom: 8,
                  left: 12,
                  right: 12,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.allProducts.length, (idx) {
                        final p = widget.allProducts[idx];
                        final isSelected = idx == widget.currentIndex;
                        return GestureDetector(
                          onTap: () => widget.onSelectProduct(idx),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? (widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1))
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Image.asset(p.imagePath, fit: BoxFit.contain),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Product Details
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildProductDetailsContent(),
          ),
        ],
      ),
    );
  }

  // ── Product Details Content (Exact data from product_page.dart) ────────────
  Widget _buildProductDetailsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Category & SKU Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF40C4FF).withValues(alpha: 0.15)
                    : const Color(0xFF0D47A1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.product.category,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Product Title
        Text(
          widget.product.title,
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: widget.isDark ? Colors.white : const Color(0xFF0D1B1E),
          ),
        ),

        const SizedBox(height: 4),

        // Subtitle (Exact from product_page.dart)
        Text(
          widget.product.subtitle,
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 13,
            color: widget.isDark ? Colors.white60 : Colors.black54,
          ),
        ),

        const SizedBox(height: 14),

        // Highlight Rating / Status Banner (Exact eyebrow specs)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF40C4FF).withValues(alpha: 0.08)
                : const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF40C4FF).withValues(alpha: 0.2)
                  : const Color(0xFF0284C7).withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            widget.product.highlight,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0284C7),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Specifications & Benefits (Exact data from product_page.dart)
        Text(
          "SPECIFICATIONS & BENEFITS",
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: widget.isDark ? Colors.white38 : Colors.black45,
          ),
        ),

        const SizedBox(height: 8),

        Column(
          children: widget.product.specs.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "${entry['label']}: ",
                    style: TextStyle(
                      fontFamily: 'OpenSans',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry['value']!,
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // CTA Action Button
        MouseRegion(
          onEnter: (_) => setState(() => _buttonHovered = true),
          onExit: (_) => setState(() => _buttonHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.identity()..scale(_buttonHovered ? 1.02 : 1.0),
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () =>
                  NavigationUtils.navigateTo(context, widget.product.route),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text(
                "EXPLORE PRODUCT DETAILS",
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: widget.isDark
                    ? const Color(0xFF0091EA)
                    : const Color(0xFF0D47A1),
                elevation: _buttonHovered ? 8 : 4,
                shadowColor: (widget.isDark ? const Color(0xFF40C4FF) : const Color(0xFF0D47A1))
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
