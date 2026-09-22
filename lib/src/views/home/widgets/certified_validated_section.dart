import 'dart:convert';
import 'package:flutter/material.dart';
import 'certified_assets.dart';

class CertifiedValidatedSection extends StatelessWidget {
  final bool isDarkMode;

  const CertifiedValidatedSection({
    super.key,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 800;

    final cardBg = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? const Color(0xFF40C4FF).withValues(alpha: 0.2)
        : const Color(0xFFE2E8F0);

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 30,
        vertical: isMobile ? 16 : 28,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.35)
                      : const Color(0x0D000000),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: EdgeInsets.all(isMobile ? 20 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Category Pill Tag matching CloudSense Theme
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDarkMode
                          ? [
                              const Color(0xFF40C4FF).withValues(alpha: 0.16),
                              const Color(0xFF00E676).withValues(alpha: 0.16),
                            ]
                          : [
                              const Color(0xFFE3F2FD),
                              const Color(0xFFE8F5E9),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode
                          ? const Color(0xFF40C4FF).withValues(alpha: 0.35)
                          : const Color(0xFF1565C0).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 13,
                        color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "GOVERNMENT & ACCREDITATION VALIDATED",
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0),
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main Content Row / Column
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTextContent(isMobile),
                          const SizedBox(height: 24),
                          Center(child: _buildBadgeRow(isMobile)),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildTextContent(isMobile),
                          ),
                          const SizedBox(width: 36),
                          _buildBadgeRow(isMobile),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Certified & Validated",
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: isMobile ? 24 : 30,
            fontWeight: FontWeight.w800,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Performance and measurement accuracy validated through IMD certification and NABL-accredited testing, ensuring dependable weather intelligence and field-proven reliability.",
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: isMobile ? 13.5 : 14.5,
            height: 1.6,
            color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeRow(bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildBadgeCard(
          cardBase64: kImdCardBase64,
          logoBase64: kImdLogoBase64,
          label: 'IMD Certified',
          isMobile: isMobile,
        ),
        SizedBox(width: isMobile ? 12 : 16),
        _buildBadgeCard(
          cardBase64: kNablCardBase64,
          logoBase64: kNablLogoBase64,
          label: 'NABL Accredited',
          isMobile: isMobile,
        ),
      ],
    );
  }

  Widget _buildBadgeCard({
    required String cardBase64,
    required String logoBase64,
    required String label,
    required bool isMobile,
  }) {
    final double width = isMobile ? 125 : 145;
    final double height = isMobile ? 140 : 160;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF334155)
              : const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (context) {
          try {
            if (cardBase64.isNotEmpty) {
              return Image.memory(
                base64Decode(cardBase64),
                width: width,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildLogoFallback(logoBase64, label),
              );
            }
          } catch (_) {}
          return _buildLogoFallback(logoBase64, label);
        },
      ),
    );
  }

  Widget _buildLogoFallback(String logoBase64, String label) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                try {
                  if (logoBase64.isNotEmpty) {
                    return Image.memory(
                      base64Decode(logoBase64),
                      fit: BoxFit.contain,
                    );
                  }
                } catch (_) {}
                return const Icon(Icons.verified_user, color: Color(0xFF40C4FF), size: 36);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
