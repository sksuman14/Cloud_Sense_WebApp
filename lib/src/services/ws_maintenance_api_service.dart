import 'dart:convert';
import 'package:http/http.dart' as http;

class WsMaintenanceApiService {
  static const String baseUrl = 'https://3l3t3rt4n9.execute-api.us-east-1.amazonaws.com';

  /// Fetches all state names available in the S3 state folders.
  static Future<List<String>> fetchStates() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/states'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['states'] is List) {
          return (data['states'] as List).map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching states: $e');
      rethrow;
    }
  }

  /// Fetches district names available under the selected state.
  static Future<List<String>> fetchDistricts(String state) async {
    try {
      final encodedState = Uri.encodeComponent(state);
      final res = await http.get(
        Uri.parse('$baseUrl/$encodedState'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['districts'] is List) {
          return (data['districts'] as List).map((e) => e.toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching districts for $state: $e');
      rethrow;
    }
  }

  /// Fetches sensors for a state, or for a specific district within that state.
  static Future<List<Map<String, dynamic>>> fetchSensors({
    required String state,
    String? district,
  }) async {
    try {
      final encodedState = Uri.encodeComponent(state);
      final String endpoint;
      if (district == null || district.isEmpty || district == 'All' || district == 'All Districts') {
        endpoint = '$baseUrl/$encodedState/sensors.csv';
      } else {
        final encodedDistrict = Uri.encodeComponent(district);
        endpoint = '$baseUrl/$encodedState/$encodedDistrict';
      }

      final res = await http.get(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['sensors'] is List) {
          return (data['sensors'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      } else {
        throw Exception('Failed to load sensors (${res.statusCode}): ${res.body}');
      }
      return [];
    } catch (e) {
      print('Error fetching sensors ($state, district: $district): $e');
      rethrow;
    }
  }

  /// Fetches maintenance history report from /{State}/report.csv, optionally filtered by sensorId.
  static Future<List<Map<String, dynamic>>> fetchReports({
    required String state,
    String? sensorId,
  }) async {
    try {
      final encodedState = Uri.encodeComponent(state);
      String url = '$baseUrl/$encodedState/report.csv';
      if (sensorId != null && sensorId.isNotEmpty) {
        url += '?sensorId=${Uri.encodeComponent(sensorId)}';
      }

      final res = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['reports'] is List) {
          return (data['reports'] as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching reports ($state): $e');
      rethrow;
    }
  }

  /// Records a maintenance action (FIX or VERIFY) via PATCH /{State}/{District}/maintenance.
  static Future<Map<String, dynamic>> recordMaintenance({
    required String state,
    required String district,
    required String sensorId,
    required List<String> parameters,
    required String action, // "FIX" or "VERIFY"
    required String fixedBy,
  }) async {
    try {
      final encodedState = Uri.encodeComponent(state);
      final encodedDistrict = Uri.encodeComponent(district);
      final url = '$baseUrl/$encodedState/$encodedDistrict/maintenance';

      final body = jsonEncode({
        'sensorId': sensorId,
        'parameters': parameters,
        'action': action,
        'fixedBy': fixedBy,
      });

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      final responseBody = res.body;
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        data = {'raw': responseBody};
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      } else {
        final errMsg = data['message'] ?? data['error'] ?? 'HTTP ${res.statusCode}: $responseBody';
        throw Exception(errMsg);
      }
    } catch (e) {
      print('Error recording maintenance: $e');
      rethrow;
    }
  }

  /// Updates the Deployment Date for a sensor via PATCH /{State}/{District}/deployment.
  /// Send deploymentDate as "YYYY-MM-DD" or empty string "" to clear.
  static Future<Map<String, dynamic>> updateDeploymentDate({
    required String state,
    required String district,
    required String sensorId,
    required String deploymentDate,
  }) async {
    try {
      final encodedState = Uri.encodeComponent(state);
      final encodedDistrict = Uri.encodeComponent(district);
      final url = '$baseUrl/$encodedState/$encodedDistrict/deployment';

      final body = jsonEncode({
        'sensorId': sensorId,
        'deploymentDate': deploymentDate,
      });

      final res = await http.patch(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 20));

      final responseBody = res.body;
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        data = {'raw': responseBody};
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      } else {
        final errMsg = data['message'] ?? data['error'] ?? 'HTTP ${res.statusCode}: $responseBody';
        throw Exception(errMsg);
      }
    } catch (e) {
      print('Error updating deployment date ($sensorId): $e');
      rethrow;
    }
  }

  /// Manually triggers sensor and QC synchronization via POST /sync.
  static Future<Map<String, dynamic>> syncSensors() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/sync'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 40));

      final responseBody = res.body;
      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(responseBody) as Map<String, dynamic>;
      } catch (_) {
        data = {'raw': responseBody};
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return data;
      } else {
        final errMsg = data['message'] ?? 'Sync failed with code ${res.statusCode}';
        throw Exception(errMsg);
      }
    } catch (e) {
      print('Error syncing sensors: $e');
      rethrow;
    }
  }
}
