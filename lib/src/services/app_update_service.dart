import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../widgets/update_notification_dialog.dart';

class AppUpdateService {
  // Remote version API endpoint
  static const String versionCheckApiUrl =
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api?type=app_version';

  // Default Google Play Store URL for CloudSenseVis
  static const String defaultPlayStoreUrl =
      'https://play.google.com/store/apps/details?id=com.CloudSenseVis';

  /// Check if a new version of the CloudSense App is available
  static Future<void> checkAppUpdate(BuildContext context,
      {bool forceShow = false}) async {
    // Only check for updates on mobile/native apps, not on website
    if (kIsWeb) return;

    try {
      // 1. Dynamically read real package info from installed Android app
      String installedVersion = "1.1.0";
      int installedBuildNumber = 109;

      try {
        final packageInfo = await PackageInfo.fromPlatform();
        installedVersion = packageInfo.version;
        installedBuildNumber = int.tryParse(packageInfo.buildNumber) ?? installedBuildNumber;
        debugPrint("📱 Installed App Info -> Version: $installedVersion, Build: $installedBuildNumber");
      } catch (e) {
        debugPrint("Could not read PackageInfo: $e");
      }

      // 2. Check 24-hour cache unless forced by user action
      if (!forceShow) {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getString('last_update_check_date');
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        if (lastCheck == todayStr) {
          debugPrint("Already checked for updates today ($todayStr).");
          return;
        }
      }

      bool hasUpdate = false;
      String title = "New app update available!";
      String message =
          "We have got some new features and performance improvements. Update your app to use them.";
      String notice =
          "Update happens via Google Play Store. Tap below to update.";
      String updateUrl = defaultPlayStoreUrl;
      bool forceUpdate = false;

      // 3. Fetch remote version info from API
      try {
        final response = await http
            .get(Uri.parse(versionCheckApiUrl))
            .timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map<String, dynamic>) {
            final latestVer = (data['latest_version'] ??
                    data['version'] ??
                    data['version_name'] ??
                    data['app_version'] ??
                    installedVersion)
                .toString();

            final buildNum = int.tryParse((data['build_number'] ??
                        data['build_code'] ??
                        data['build'] ??
                        data['version_code'] ??
                        installedBuildNumber)
                    .toString()) ??
                installedBuildNumber;

            debugPrint("☁️ Remote Version Info -> Latest: $latestVer, Build: $buildNum");

            if (buildNum > installedBuildNumber ||
                _isVersionGreater(latestVer, installedVersion)) {
              hasUpdate = true;
              if (data['title'] != null) title = data['title'].toString();
              if (data['message'] != null) message = data['message'].toString();
              if (data['notice'] != null) notice = data['notice'].toString();
              if (data['update_url'] != null && data['update_url'].toString().isNotEmpty) {
                updateUrl = data['update_url'].toString();
              }
              if (data['force_update'] != null) {
                forceUpdate = data['force_update'] == true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Remote version check failed: $e");
      }

      // Record check date
      if (!forceShow) {
        final prefs = await SharedPreferences.getInstance();
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        await prefs.setString('last_update_check_date', todayStr);
      }

      // 4. Show Update Dialog if update available
      if (hasUpdate) {
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
      } else if (forceShow) {
        // User manually clicked "Check for Updates" from Drawer
        if (context.mounted) {
          Fluttertoast.showToast(
            msg: "You are already using the latest version (v$installedVersion+$installedBuildNumber).",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.green.shade800,
            textColor: Colors.white,
            fontSize: 14.0,
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
