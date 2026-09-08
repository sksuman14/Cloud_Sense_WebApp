import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/update_notification_dialog.dart';

class AppUpdateService {
  static const String currentAppVersion = "1.1.0";
  static const int currentBuildNumber = 106;

  // Remote version API endpoint
  static const String versionCheckApiUrl =
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api?type=app_version';

  /// Check if a new version of the CloudSense App is available
  static Future<void> checkAppUpdate(BuildContext context,
      {bool forceShow = false}) async {
    // Only check for updates on mobile/native apps, not on website
    if (kIsWeb) return;

    try {
      if (!forceShow) {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getString('last_update_check_date');
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        if (lastCheck == todayStr) {
          // Checked today already
          return;
        }
      }

      bool hasUpdate = false;
      String title = "New app update available!";
      String message =
          "We have got some new and interesting features for you. Update your app to use them.";
      String notice =
          "Update happens in the background. So, you can keep using the app.";
      String updateUrl = "https://cloudsense.app";
      bool forceUpdate = false;

      try {
        final response = await http
            .get(Uri.parse(versionCheckApiUrl))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final latestVer = (data['latest_version'] ??
                    data['version'] ??
                    currentAppVersion)
                .toString();
            final buildNum = int.tryParse(
                    (data['build_number'] ?? data['build'] ?? currentBuildNumber)
                        .toString()) ??
                currentBuildNumber;

            if (buildNum > currentBuildNumber ||
                _isVersionGreater(latestVer, currentAppVersion)) {
              hasUpdate = true;
              if (data['title'] != null) title = data['title'].toString();
              if (data['message'] != null) message = data['message'].toString();
              if (data['notice'] != null) notice = data['notice'].toString();
              if (data['update_url'] != null) {
                updateUrl = data['update_url'].toString();
              }
              if (data['force_update'] != null) {
                forceUpdate = data['force_update'] == true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Remote version check failed, checking fallback: $e");
      }

      // Record check date
      if (!forceShow) {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        await prefs.setString('last_update_check_date', todayStr);
      }

      if (hasUpdate || forceShow) {
        if (context.mounted) {
          UpdateNotificationDialog.show(
            context,
            title: title,
            message: message,
            notice: notice,
            updateUrl: updateUrl,
            forceUpdate: forceUpdate,
          );
        }
      }
    } catch (e) {
      debugPrint("Error checking app update: $e");
    }
  }

  /// Helper to compare semver strings like "1.2.0" > "1.1.0"
  static bool _isVersionGreater(String newVer, String oldVer) {
    try {
      final newParts =
          newVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final oldParts =
          oldVer.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final n = i < newParts.length ? newParts[i] : 0;
        final o = i < oldParts.length ? oldParts[i] : 0;
        if (n > o) return true;
        if (n < o) return false;
      }
    } catch (e) {
      return false;
    }
    return false;
  }
}
