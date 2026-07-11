import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'dart:ui' as ui;

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

class ProductSectionV2 extends StatefulWidget {
  const ProductSectionV2({super.key});

  @override
  State<ProductSectionV2> createState() => _ProductSectionV2State();
}

class _ProductSectionV2State extends State<ProductSectionV2> {
  late PageController _pageController;
  int _currentIndex = 0;

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
  }

  @override
  void dispose() {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldController.dispose();
      });
    }

    return Column(
      children: [
        // --- Header Section ---
        Text(
          "Our Products",
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: screenWidth < 600 ? 32 : 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: isDarkMode ? Colors.white : const Color(0xFF0D1B1E),
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2),

        const SizedBox(height: 48),

        // --- Summary Stats ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatCard("5", "Products", isDarkMode, screenWidth),
              const SizedBox(width: 8),
              _buildStatCard("IP66", "Weatherproof", isDarkMode, screenWidth),
              const SizedBox(width: 8),
              _buildStatCard("4G", "Connectivity", isDarkMode, screenWidth),
            ],
          ),
        ).animate().fadeIn(delay: 400.ms),

        const SizedBox(height: 60),

        // --- Main Carousel ---
        SizedBox(
          height: 520,
          child: PageView.builder(
            controller: _pageController,
            padEnds: false,
            itemCount: _allProducts.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () =>
                      NavigationUtils.navigateTo(context, _allProducts[index].route),
                  borderRadius: BorderRadius.circular(30),
                  child: _buildProductCard(_allProducts[index], isDarkMode),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // --- Navigation Dots & Arrows ---
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
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
                              ? const Color(0xFF1FCB8A)
                              : const Color(0xFF0D47A1))
                          : (isDarkMode
                              ? const Color(0xFF1FCB8A).withOpacity(0.3)
                              : Colors.black.withOpacity(0.15)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  _buildNavButton(Icons.chevron_left, () {
                    _pageController.previousPage(
                        duration: 500.ms, curve: Curves.easeInOut);
                  }, isDarkMode),
                  const SizedBox(width: 12),
                  _buildNavButton(Icons.chevron_right, () {
                    _pageController.nextPage(
                        duration: 500.ms, curve: Curves.easeInOut);
                  }, isDarkMode),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 40),



        Icon(
          Icons.arrow_downward,
          color: isDarkMode
              ? Colors.white24
              : const Color(0xFF0D1B1E).withOpacity(0.2),
          size: 24,
        )
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(
                begin: 0, end: 10, duration: 1.seconds, curve: Curves.easeInOut)
            .fadeIn(),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildStatCard(
      String value, String label, bool isDark, double screenWidth) {
    final bool isSmall = screenWidth < 600;
    return Container(
      width: isSmall ? (screenWidth - 48) / 3 : 160,
      padding: EdgeInsets.symmetric(
          vertical: isSmall ? 12 : 24, horizontal: isSmall ? 6 : 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(isSmall ? 10 : 16),
        border: Border.all(
          color: (isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1))
              .withOpacity(isDark ? 0.3 : 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: isSmall ? 18 : 28,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: isSmall ? 10 : 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ProductCardData product, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  const Color(0xFF0D1F2D).withOpacity(0.8),
                  const Color(0xFF0D1F2D),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF1F5F9),
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.4)
                : Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sensors,
                      color: isDark
                          ? const Color(0xFF1FCB8A)
                          : const Color(0xFF0D47A1),
                      size: 24),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: (isDark
                                ? const Color(0xFF1FCB8A)
                                : const Color(0xFF0D47A1))
                            .withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    product.category,
                    style: TextStyle(
                        fontFamily: 'OpenSans',
                        color: isDark
                            ? const Color(0xFF1FCB8A)
                            : const Color(0xFF0D47A1),
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0D1B1E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.subtitle,
              maxLines: 2,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : Colors.black87,
                height: 1.3, // Slightly increased height for better readability
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 3,
              child: Center(
                child: Image.asset(
                  product.imagePath,
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSpecsGrid(product.specs, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecsGrid(Map<String, String> specs, bool isDark) {
    final List<MapEntry<String, String>> entries = specs.entries.toList();

    return LayoutBuilder(builder: (context, constraints) {
      // Use 2 columns on mobile if screen is narrow, else 3
      final isMobile = constraints.maxWidth < 300;
      final crossAxisCount = isMobile ? 2 : 3;

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: isMobile ? 2.2 : 2.5,
        ),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color:
                      isDark ? Colors.white10 : Colors.white.withOpacity(0.5)),
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
                            ? const Color(0xFF1FCB8A)
                            : const Color(0xFF1565C0),
                        fontSize: 9,
                        fontWeight: FontWeight.w800),
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
                            color:
                                isDark ? Colors.white : const Color(0xFF0D1B1E),
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
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
              ? Colors.white.withOpacity(0.05)
              : Colors.black.withOpacity(0.02),
        ),
        child: Icon(icon,
            color: isDark ? Colors.white70 : const Color(0xFF0D1B1E), size: 24),
      ),
    );
  }
}
