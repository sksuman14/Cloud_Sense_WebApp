import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ksdma_models.dart';

/// KSDMA AWS Lambda REST API Service
/// All data is stored in AWS RDS PostgreSQL via Lambda Function URL.
class KsdmaApiService {
  // AWS Serverless Lambda API Endpoint
  static String get apiBaseUrl {
    return 'https://4tzbwvog4jqj3bz5vtyseqxvkm0ramhd.lambda-url.us-east-1.on.aws/api';
  }

  bool isConnected = false;

  // Test API Connection
  Future<bool> initializeConnection() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/boundaries'));
      if (response.statusCode == 200) {
        isConnected = true;
        print('✅ Connected to KSDMA AWS Lambda API & RDS PostgreSQL Database!');
        return true;
      }
    } catch (e) {
      print('⚠️ API Connection Notice: $e');
    }
    return false;
  }

  // 0. POST /api/send-otp - Request OTP via Backend AWS API
  Future<String?> requestOtp({required String identifier, String email = '', String mobileNumber = ''}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier,
          'email': email.isNotEmpty ? email : (identifier.contains('@') ? identifier : ''),
          'mobile_number': mobileNumber.isNotEmpty ? mobileNumber : (!identifier.contains('@') ? identifier : ''),
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['otp'] != null) {
          return body['otp'].toString();
        }
      }
    } catch (e) {
      print('Error requesting OTP via API: $e');
    }
    return null;
  }

  // 1. POST /api/register - Register New User
  Future<KsdmaUser?> registerUser({
    required String fullName,
    required String mobileNumber,
    required String email,
    String password = '',
    UserRole role = UserRole.volunteer,
    required UserCategory category,
  }) async {
    try {
      final cleanNum = mobileNumber.replaceAll(RegExp(r'\D'), '');
      final userId = 'usr_${cleanNum.isNotEmpty ? cleanNum : DateTime.now().millisecondsSinceEpoch.toString()}';
      final response = await http.post(
        Uri.parse('$apiBaseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'full_name': fullName,
          'mobile_number': mobileNumber,
          'email': email,
          'password': password,
          'user_role': role.name.toUpperCase(),
          'role_category': category.name,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['user'] != null) {
          return _mapRowToUser(body['user']);
        }
      } else {
        print('⚠️ Register API Error status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error registering user via API: $e');
    }
    return null;
  }

  // 2. POST /api/login - Login via Mobile Number
  Future<KsdmaUser?> loginUserWithPhone(String identifier) async {
    try {
      final isEmail = identifier.contains('@');
      final cleanNum = isEmail ? '' : identifier.replaceAll(RegExp(r'\D'), '');
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile_number': !isEmail ? (cleanNum.isNotEmpty ? cleanNum : identifier) : '',
          'email': isEmail ? identifier.trim() : '',
        }),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['user'] != null) {
          return _mapRowToUser(body['user']);
        }
      } else {
        print('⚠️ Login API Error status: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('❌ Error logging in user via API: $e');
    }
    return null;
  }

  // 3. POST /api/login - Officer / Admin Email Login
  Future<Map<String, dynamic>> loginUserWithEmail(String email, String role) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'role': role}),
      );
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true && body['user'] != null) {
        return {'success': true, 'user': _mapRowToUser(body['user'])};
      }
      return {'success': false, 'message': body['message'] ?? 'Login failed.'};
    } catch (e) {
      print('Error in loginUserWithEmail: $e');
      return {'success': false, 'message': 'Server unreachable. Please try again.'};
    }
  }

  // 4. GET /api/stations - Fetch All Non-Rejected Stations (for map/public view)
  Future<List<KsdmaStation>> fetchStations() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/stations'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['stations'] != null) {
          final List rows = body['stations'];
          return rows.map((r) => _mapRowToStation(r)).toList();
        }
      }
    } catch (e) {
      print('Error fetching stations via API: $e');
    }
    return [];
  }

  // 5. GET /api/stations/pending - Fetch Only Pending Stations (for Admin Dashboard)
  Future<List<KsdmaStation>> fetchPendingStations() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/stations/pending'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['stations'] != null) {
          final List rows = body['stations'];
          return rows.map((r) => _mapRowToStation(r)).toList();
        }
      }
    } catch (e) {
      print('Error fetching pending stations via API: $e');
    }
    return [];
  }

  // 6. POST /api/stations - Register New Instrument
  Future<bool> registerStation(KsdmaStation station) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/stations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'station_id': station.stationId,
          'owner_user_id': station.ownerUserId,
          'owner_name': station.ownerName,
          'owner_category': station.ownerCategory.name,
          'category': station.category.name,
          'instrument_type': station.instrumentType.name,
          'device_make': station.deviceMake,
          'measurement_location': station.measurementLocation,
          'device_photo_url': station.devicePhotoUrl,
          'latitude': station.latitude,
          'longitude': station.longitude,
          'district': station.district,
          'taluk': station.taluk,
          'grama_panchayat': station.gramaPanchayat,
          'village': station.village,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error registering station via API: $e');
      return false;
    }
  }

  // 7. POST /api/approve - Admin Approve Station
  Future<bool> approveStation(String stationId) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/approve'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'station_id': stationId, 'admin_id': 'usr_admin_hq'}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error approving station via API: $e');
      return false;
    }
  }

  // 8. POST /api/reject - Admin Reject Station (saves rejection_reason in stations table)
  Future<bool> rejectStation(String stationId, {String reason = 'Rejected by Admin HQ'}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/reject'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'station_id': stationId,
          'admin_id': 'usr_admin_hq',
          'rejection_reason': reason,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error rejecting station via API: $e');
      return false;
    }
  }

  // 9. POST /api/observations - Save Daily Weather Reading
  Future<bool> submitObservation(KsdmaObservation obs) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/observations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'observation_id': obs.observationId,
          'station_id': obs.stationId,
          'submitted_by_user_id': obs.submittedByUserId,
          'observation_date': obs.observationDate.toIso8601String().split('T')[0],
          'observation_time': '${obs.observationTime.hour.toString().padLeft(2, '0')}:${obs.observationTime.minute.toString().padLeft(2, '0')}:00',
          'rainfall_mm': obs.rainfallMm,
          'max_temperature_c': obs.maxTemperatureC,
          'min_temperature_c': obs.minTemperatureC,
          'river_water_level_m': obs.riverWaterLevelM,
          'humidity_percent': obs.humidityPercent,
          'source': obs.source,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error submitting observation via API: $e');
      return false;
    }
  }

  // 10. DELETE /api/observations/:id - Admin Remove Observation with moderation_reason
  Future<bool> deleteObservation(String observationId, String reason) async {
    try {
      final response = await http.delete(
        Uri.parse('$apiBaseUrl/observations/$observationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'reason': reason}),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error removing observation via API: $e');
      return false;
    }
  }

  // 11. POST /api/observations/bulk - Admin Bulk Import
  Future<int> bulkUploadObservations(List<Map<String, dynamic>> records) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/observations/bulk'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'records': records}),
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        return body['count'] ?? records.length;
      }
    } catch (e) {
      print('Error performing bulk upload via API: $e');
    }
    return 0;
  }

  // 12. GET /api/observations - Fetch All Live Observations
  Future<List<KsdmaObservation>> fetchObservations() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/observations'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['observations'] != null) {
          final List rows = body['observations'];
          return rows.map((r) => _mapRowToObservation(r)).toList();
        }
      }
    } catch (e) {
      print('Error fetching observations via API: $e');
    }
    return [];
  }

  // 13. GET /api/champions - Fetch Weather Champions Leaderboard
  Future<List<KsdmaUser>> fetchChampions() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/champions'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['champions'] != null) {
          final List rows = body['champions'];
          return rows.map((r) => _mapRowToUser(r)).toList();
        }
      }
    } catch (e) {
      print('Error fetching champions via API: $e');
    }
    return [];
  }

  // 14. GET /api/boundaries - Fetch Administrative Boundaries
  Future<List<Map<String, dynamic>>> fetchBoundaries() async {
    try {
      final response = await http.get(Uri.parse('$apiBaseUrl/boundaries'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['boundaries'] != null) {
          final List rows = body['boundaries'];
          return List<Map<String, dynamic>>.from(rows);
        }
      }
    } catch (e) {
      print('Error fetching boundaries via API: $e');
    }
    return [];
  }

  // ─── Mapper Helpers ───────────────────────────────────────────────────────

  KsdmaUser _mapRowToUser(Map<String, dynamic> r) {
    final roleStr = (r['user_role'] ?? r['role'] ?? 'VOLUNTEER').toString().toUpperCase();
    final role = roleStr == 'ADMIN'
        ? UserRole.admin
        : roleStr == 'OFFICER'
            ? UserRole.officer
            : UserRole.volunteer;

    return KsdmaUser(
      userId: r['user_id'] ?? '',
      fullName: r['full_name'] ?? '',
      mobileNumber: r['mobile_number'] ?? '',
      email: r['email'] ?? '',
      role: role,
      category: UserCategory.values.firstWhere(
        (e) => e.name == r['role_category'],
        orElse: () => role == UserRole.admin
            ? UserCategory.adminHq
            : role == UserRole.officer
                ? UserCategory.districtOfficer
                : UserCategory.generalPublic,
      ),
      district: '',
      taluk: '',
      gramaPanchayat: '',
      village: '',
      streakDays: (r['current_streak'] ?? r['streak_days'] ?? 0) as int,
      totalObservations: (r['total_contributions'] ?? r['total_observations'] ?? 0) as int,
      badgeTier: (r['badge'] ?? r['badge_tier'] ?? 'BRONZE').toString(),
      avatarUrl: '',
    );
  }

  KsdmaStation _mapRowToStation(Map<String, dynamic> r) {
    return KsdmaStation(
      stationId: r['station_id'],
      ownerUserId: r['owner_user_id'] ?? 'usr_admin_hq',
      ownerName: r['owner_name'] ?? 'State HQ Administrator',
      ownerCategory: UserCategory.values.firstWhere((e) => e.name == r['owner_category'], orElse: () => UserCategory.generalPublic),
      category: r['category'] == 'aws' ? StationCategory.aws : StationCategory.manual,
      instrumentType: InstrumentType.values.firstWhere((e) => e.name == r['instrument_type'], orElse: () => InstrumentType.rainGauge),
      deviceMake: r['device_make'] ?? 'Standard Instrument',
      measurementLocation: r['measurement_location'] ?? 'Site',
      devicePhotoUrl: r['device_photo_url'] ?? 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
      latitude: (r['latitude'] as num).toDouble(),
      longitude: (r['longitude'] as num).toDouble(),
      district: r['district'],
      taluk: r['taluk'],
      gramaPanchayat: r['grama_panchayat'],
      village: r['village'],
      approvalStatus: r['approval_status'] == 'approved'
          ? ApprovalStatus.approved
          : r['approval_status'] == 'rejected'
              ? ApprovalStatus.rejected
              : ApprovalStatus.pending,
      rejectionReason: r['rejection_reason'] ?? '',
      createdAt: DateTime.parse(r['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  KsdmaObservation _mapRowToObservation(Map<String, dynamic> r) {
    return KsdmaObservation(
      observationId: r['observation_id'],
      stationId: r['station_id'],
      submittedByUserId: r['submitted_by_user_id'],
      observationDate: DateTime.parse(r['observation_date']),
      observationTime: const TimeOfDay(hour: 8, minute: 0),
      submissionTimestamp: DateTime.parse(r['submission_timestamp'] ?? DateTime.now().toIso8601String()),
      source: r['source'] ?? 'WEB_PORTAL',
      rainfallMm: r['rainfall_mm'] != null ? (r['rainfall_mm'] as num).toDouble() : null,
      maxTemperatureC: r['max_temperature_c'] != null ? (r['max_temperature_c'] as num).toDouble() : null,
      minTemperatureC: r['min_temperature_c'] != null ? (r['min_temperature_c'] as num).toDouble() : null,
      riverWaterLevelM: r['river_water_level_m'] != null ? (r['river_water_level_m'] as num).toDouble() : null,
      humidityPercent: r['humidity_percent'] != null ? (r['humidity_percent'] as num).toDouble() : null,
      isRemoved: r['is_removed'] == true,
    );
  }
}
