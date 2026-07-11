import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

/// A data model to hold the results of the device activity fetch.
class DeviceActivitySummary {
  final List<Map<String, dynamic>> allDevices;
  final int totalDevices;
  final int totalActive;
  final int totalInactive;

  DeviceActivitySummary({
    required this.allDevices,
    required this.totalDevices,
    required this.totalActive,
    required this.totalInactive,
  });
}

/// A service class to handle fetching and processing device activity data.
class DeviceService {
  final List<String> _apiUrls = [
    "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity",
    "https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api",
  ];

  /// Fetches device data from both APIs in parallel.
  /// Returns a [DeviceActivitySummary] on success, or null on failure.
  Future<DeviceActivitySummary?> fetchDeviceActivity() async {
    try {
      // Parallel fetch for both APIs
      final responses = await Future.wait(
        _apiUrls.map(
          (url) => http.get(Uri.parse(url),
              headers: {'Content-Type': 'application/json'}).catchError((e) {
            debugPrint("Error fetching device activity $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      List<Map<String, dynamic>> allDevices = [];

      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];

        if (response.statusCode != 200) {
          print("❌ API ${i + 1} failed: HTTP ${response.statusCode}");
          continue;
        }

        final data = json.decode(response.body);
        final List<dynamic>? devicesList = data['devices'];

        if (devicesList == null || devicesList.isEmpty) {
          print("⚠️ API ${i + 1}: No devices found");
          continue;
        }

        for (var deviceData in devicesList) {
          final deviceIdTopic = deviceData['deviceid#topic']?.toString() ?? '';
          if (deviceIdTopic.isEmpty) continue;

          final parts = deviceIdTopic.split('#');
          if (parts.length < 2) continue;

          final deviceId = parts[0];
          final topic = parts.sublist(1).join('#');

          if (topic.startsWith('BF/') || topic.startsWith('CS/')) continue;

          DateTime? lastTime = _parseDate(deviceData['TimeStamp_IST'] ?? 
              deviceData['TimeStamp'] ?? 
              deviceData['Time_Stamp'] ?? 
              deviceData['human_time'] ?? 
              deviceData['timestamp']);
          bool isActive = false;
          if (lastTime != null) {
            final diff = DateTime.now().difference(lastTime);
            isActive = diff.inHours <= 1;
          }

          // Format lastReceivedTime
          String formattedTime = lastTime != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(lastTime)
              : "N/A";

          allDevices.add({
            "DeviceId": deviceId,
            "lastReceivedTime": formattedTime,
            "isActive": isActive,
            "Group": topic.split('/')[0],
            "Topic": topic,
            "API": "API ${i + 1}",
            "LastKnownLongitude": deviceData['Longitude']?.toString() ??
                deviceData['LastKnownLongitude']?.toString() ??
                "0",
            "LastKnownLatitude": deviceData['Latitude']?.toString() ??
                deviceData['LastKnownLatitude']?.toString() ??
                "0",
          });

          // Debug print
          if (kDebugMode) {
            print(
                "API ${i + 1} Device: $deviceIdTopic, Timestamp: ${deviceData['TimeStamp_IST']}");
          }
        }
      }

      // Sort by lastReceivedTime descending
      allDevices.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['lastReceivedTime']) ?? DateTime(1970);
        final bTime =
            DateTime.tryParse(b['lastReceivedTime']) ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      int activeCount = allDevices.where((d) => d['isActive'] as bool).length;
      int inactiveCount = allDevices.length - activeCount;

      return DeviceActivitySummary(
        allDevices: allDevices,
        totalDevices: allDevices.length,
        totalActive: activeCount,
        totalInactive: inactiveCount,
      );
    } catch (e) {
      debugPrint("DeviceService fetch failed: $e");
      return null;
    }
  }

  DateTime? _parseDate(String? dateStr) => DevicePrefixUtils.parseDate(dateStr);
}
