import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

class Footer extends StatelessWidget {
  const Footer({super.key});

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _scrollToTop(BuildContext context) {
    try {
      final ScrollableState? scrollable = Scrollable.maybeOf(context);
      if (scrollable != null) {
        scrollable.position.animateTo(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      } else {
        PrimaryScrollController.maybeOf(context)?.animateTo(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 1050;

    final bgColor = isDarkMode ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
    final borderColor = isDarkMode ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
    final titleColor = isDarkMode ? Colors.white : const Color(0xFF0D47A1);
    final headerColor = isDarkMode ? Colors.white : const Color(0xFF18181B);
    final bodyTextColor = isDarkMode ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);
    final linkTextColor = isDarkMode ? const Color(0xFFD4D4D8) : const Color(0xFF27272A);
    final iconBoxBg = isDarkMode ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);

    return Container(
      width: double.infinity,
      color: bgColor,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: isMobile ? 32 : 48,
              horizontal: isMobile ? 20 : 60,
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBrandSection(isDarkMode, titleColor, bodyTextColor),
                      const SizedBox(height: 32),
                      _buildSitemapSection(context, headerColor, linkTextColor),
                      const SizedBox(height: 28),
                      _buildHardwareSection(context, headerColor, linkTextColor),
                      const SizedBox(height: 32),
                      _buildVisitUsSection(context, headerColor, bodyTextColor, iconBoxBg),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Column 1: Brand & Tagline (Flex 3)
                      Expanded(
                        flex: 3,
                        child: _buildBrandSection(isDarkMode, titleColor, bodyTextColor),
                      ),
                      const SizedBox(width: 32),
                      // Column 2: SITEMAP (Flex 2)
                      Expanded(
                        flex: 2,
                        child: _buildSitemapSection(context, headerColor, linkTextColor),
                      ),
                      const SizedBox(width: 32),
                      // Column 3: HARDWARE PRODUCTS (Flex 3)
                      Expanded(
                        flex: 3,
                        child: _buildHardwareSection(context, headerColor, linkTextColor),
                      ),
                      const SizedBox(width: 32),
                      // Column 4: VISIT US & SOCIAL (Flex 4)
                      Expanded(
                        flex: 4,
                        child: _buildVisitUsSection(context, headerColor, bodyTextColor, iconBoxBg),
                      ),
                    ],
                  ),
          ),
          // ── Divider ──
          Container(
            height: 1,
            color: borderColor,
          ),
          // ── Bottom Bar: IIT ROPAR info & BACK TO TOP ──
          Padding(
            padding: EdgeInsets.symmetric(
              vertical: 18,
              horizontal: isMobile ? 20 : 60,
            ),
            child: Flex(
              direction: isMobile ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'IIT ROPAR – CLOUD SENSE BY ANNAM.AI',
                  style: TextStyle(
                    color: bodyTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                if (isMobile) const SizedBox(height: 16),
                InkWell(
                  onTap: () => _scrollToTop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BACK TO TOP',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_upward_rounded,
                          size: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Column 1: Brand & Tagline ──
  Widget _buildBrandSection(bool isDarkMode, Color titleColor, Color bodyTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF27272A) : const Color(0xFFE4E4E7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud, color: Colors.blueAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontFamily: 'OpenSans', fontSize: 22, color: titleColor),
                  children: [
                    TextSpan(text: "CLOUD ", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: titleColor)),
                    TextSpan(text: "SENSE", style: TextStyle(fontWeight: FontWeight.w300, color: isDarkMode ? Colors.white70 : Colors.blue.shade700, letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Industrial-grade weather telemetry, agricultural intelligence & disaster monitoring platform developed by ANNAM.AI at IIT Ropar. Empowering communities with real-time environmental data, smart sensing, and predictive analytics.',
          style: TextStyle(
            color: bodyTextColor,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ── Column 2: SITEMAP ──
  Widget _buildSitemapSection(BuildContext context, Color headerColor, Color linkTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SITEMAP',
          style: TextStyle(
            color: headerColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        _buildNavLink(context, 'Home', '/', linkTextColor),
        _buildNavLink(context, 'Device List', '/devicelist', linkTextColor),
        _buildNavLink(context, 'KSDMA Weather Portal', '/ksdma', linkTextColor),
      ],
    );
  }

  // ── Column 3: HARDWARE PRODUCTS ──
  Widget _buildHardwareSection(BuildContext context, Color headerColor, Color linkTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HARDWARE PRODUCTS',
          style: TextStyle(
            color: headerColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        _buildNavLink(context, 'Data Logger', '/datalogger', linkTextColor),
        _buildNavLink(context, 'Rain Gauge', '/raingauge', linkTextColor),
        _buildNavLink(context, 'Ultrasonic Anemometer', '/windsensor', linkTextColor),
        _buildNavLink(context, 'Temp, Humidity & Pressure', '/atrh', linkTextColor),
        _buildNavLink(context, 'Temperature & Humidity Probe', '/probe', linkTextColor),
      ],
    );
  }

  // ── Column 4: VISIT US & SOCIAL ──
  Widget _buildVisitUsSection(BuildContext context, Color headerColor, Color bodyTextColor, Color iconBoxBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VISIT US',
          style: TextStyle(
            color: headerColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 14),
        // Address Card
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBoxBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.location_on_outlined, color: Colors.blueAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Address',
                    style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ANNAM.AI, TBI, IIT Ropar, Rupnagar\nPunjab - 140001, India',
                    style: TextStyle(color: bodyTextColor, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _launchURL('https://www.google.com/maps/search/?api=1&query=ANNAM.AI+TBI+IIT+Ropar+Rupnagar+Punjab+140001'),
                    child: const Text(
                      'Open in Maps ↗',
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Email Card
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: iconBoxBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.email_outlined, color: Colors.blueAccent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email',
                    style: TextStyle(color: headerColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    'communications@annam.ai',
                    style: TextStyle(color: bodyTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Social Media Buttons Wrap
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildSocialIconButton(
              icon: Icons.language_rounded,
              tooltip: 'Official Website',
              onTap: () => _launchURL('https://www.annam.ai/'),
              iconBoxBg: iconBoxBg,
            ),
            _buildSocialIconButton(
              icon: Icons.business_center_rounded,
              tooltip: 'LinkedIn',
              onTap: () => _launchURL('https://www.linkedin.com/company/annam-ai/'),
              iconBoxBg: iconBoxBg,
            ),
            _buildSocialIconButton(
              icon: Icons.alternate_email_rounded,
              tooltip: 'X (Twitter)',
              onTap: () => _launchURL('https://x.com/ANNAMAI_IITRPR'),
              iconBoxBg: iconBoxBg,
            ),
            _buildSocialIconButton(
              icon: Icons.facebook_rounded,
              tooltip: 'Facebook',
              onTap: () => _launchURL('https://www.facebook.com/people/Annamai/61583838417273/'),
              iconBoxBg: iconBoxBg,
            ),
            _buildSocialIconButton(
              icon: Icons.camera_alt_rounded,
              tooltip: 'Instagram',
              onTap: () => _launchURL('https://www.instagram.com/annam.ai_iitropar/'),
              iconBoxBg: iconBoxBg,
            ),
          ],
        ),
      ],
    );
  }

  // ── Helpers ──
  Widget _buildNavLink(BuildContext context, String title, String route, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: InkWell(
        onTap: () => NavigationUtils.navigateTo(context, route),
        child: Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required Color iconBoxBg,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconBoxBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: Colors.blueAccent),
        ),
      ),
    );
  }
}
