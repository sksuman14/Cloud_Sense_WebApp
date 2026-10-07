import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class MaintenanceService {
  /// Global notifier tracking if the app is currently in maintenance mode
  static final ValueNotifier<bool> isUnderMaintenance = ValueNotifier<bool>(false);

  static const String targetApiUrl =
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity';

  /// Triggers maintenance mode across the entire app
  static void triggerMaintenance() {
    if (!isUnderMaintenance.value) {
      debugPrint("🚨 MaintenanceService: Activating Maintenance Mode");
      isUnderMaintenance.value = true;
    }
  }

  /// Clears maintenance mode
  static void clearMaintenance() {
    if (isUnderMaintenance.value) {
      debugPrint("✅ MaintenanceService: Deactivating Maintenance Mode");
      isUnderMaintenance.value = false;
    }
  }

  /// Checks if a failed URL is related to the critical API and triggers maintenance
  static void handleApiError(String url, [Object? error]) {
    if (url.contains('WS_Device_Activity')) {
      debugPrint("⚠️ Critical API Error ($url): $error -> Activating maintenance mode");
      triggerMaintenance();
    }
  }

  /// Checks the health of the critical API endpoint directly (used by retry button)
  static Future<bool> checkApiStatus() async {
    try {
      final response = await http
          .get(Uri.parse(targetApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        clearMaintenance();
        return true;
      } else {
        triggerMaintenance();
        return false;
      }
    } catch (e) {
      debugPrint("API Health Check Failed: $e");
      triggerMaintenance();
      return false;
    }
  }
}
