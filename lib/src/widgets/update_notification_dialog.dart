import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:universal_html/html.dart' as html;

class UpdateNotificationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String notice;
  final String updateUrl;
  final bool forceUpdate;

  const UpdateNotificationDialog({
    Key? key,
    this.title = 'New app update available!',
    this.message =
        'We have got some new and interesting features for you. Update your app to use them.',
    this.notice =
        'Update happens in the background. So, you can keep using the app.',
    this.updateUrl = 'https://cloudsense.app',
    this.forceUpdate = false,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    String? title,
    String? message,
    String? notice,
    String? updateUrl,
    bool forceUpdate = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => PopScope(
        canPop: !forceUpdate,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: UpdateNotificationDialog(
            title: title ?? 'New app update available!',
            message: message ??
                'We have got some new and interesting features for you. Update your app to use them.',
            notice: notice ??
                'Update happens in the background. So, you can keep using the app.',
            updateUrl: updateUrl ?? 'https://cloudsense.app',
            forceUpdate: forceUpdate,
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateAction(BuildContext context) async {
    if (kIsWeb) {
      try {
        html.window.location.reload();
      } catch (e) {
        _launchUrl(updateUrl);
      }
    } else {
      _launchUrl(updateUrl);
    }
  }

  Future<void> _launchUrl(String targetUrl) async {
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtleTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final noticeBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF);
    final noticeTextColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF334155);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: dialogBg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Bar with Close Button
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: Align(
                  alignment: Alignment.topRight,
                  child: forceUpdate
                      ? const SizedBox(height: 32)
                      : IconButton(
                          icon: Icon(
                            Icons.close,
                            color: isDark ? Colors.white60 : Colors.black54,
                            size: 22,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Graphic Illustration Badge
                    _buildIllustrationGraphic(isDark),

                    const SizedBox(height: 24),

                    // Title
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Description Message
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subtleTextColor,
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Background Notice Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: noticeBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notice,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: noticeTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Update App Action Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9C27B0), // Vibrant purple
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _handleUpdateAction(context),
                        child: const Text(
                          'Update App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustrationGraphic(bool isDark) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF261633)
            : const Color(0xFFF3E5F5), // Soft lavender circle
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Smartphone Graphic
          Container(
            width: 46,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A), // Dark purple smartphone
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Screen Header Bar
                Positioned(
                  top: 4,
                  left: 14,
                  right: 14,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white38,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // App Logo / Symbol on Screen
                Center(
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFAB47BC),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        'CS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Download Badge (Right Side)
          Positioned(
            right: 14,
            top: 26,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF29B6F6), // Bright cyan/blue badge
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF161B22) : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.lightBlue.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.file_download_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
