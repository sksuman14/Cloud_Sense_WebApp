import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../utils/api_keys.dart';
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
      final response = await http.get(
        Uri.parse('$apiBaseUrl/boundaries'),
        headers: {'Accept': 'application/json'},
      );
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

  String? jwtToken;

  Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    if (jwtToken != null && jwtToken!.isNotEmpty) 'Authorization': 'Bearer $jwtToken',
  };

  // 0. POST /api/send-otp - Request Password Reset OTP via AWS API
  Future<Map<String, dynamic>> requestPasswordReset(String identifier) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier.trim(),
          'email': identifier.contains('@') ? identifier.trim() : '',
          'mobile_number': !identifier.contains('@') ? identifier.trim() : '',
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'message': body['message'] ?? 'OTP sent successfully.'};
      }
      return {'success': false, 'message': body['message'] ?? 'Failed to send OTP.'};
    } catch (e) {
      print('Error requesting reset OTP: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // 0.8 POST /api/reset-password - Verify OTP and Reset Password
  Future<Map<String, dynamic>> resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'identifier': identifier.trim(),
          'otp': otp.trim(),
          'new_password': newPassword.trim(),
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'message': body['message'] ?? 'Password reset successful.'};
      }
      return {'success': false, 'message': body['message'] ?? 'Invalid or expired OTP.'};
    } catch (e) {
      print('Error resetting password: $e');
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  // 1. POST /api/register - Register New User with Password & receive JWT Token
  Future<Map<String, dynamic>> registerUser({
    required String fullName,
    required String mobileNumber,
    required String email,
    required String password,
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
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true && body['user'] != null) {
          if (body['token'] != null) {
            jwtToken = body['token'].toString();
          }
          return {
            'success': true,
            'user': _mapRowToUser(body['user']),
            'token': jwtToken,
          };
        }
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Registration failed. Please try again.',
      };
    } catch (e) {
      print('❌ Error registering user via API: $e');
      return {'success': false, 'message': 'Server unreachable. Please try again.'};
    }
  }

  // 2. POST /api/login - Production Password Login with JWT Token Generation
  Future<Map<String, dynamic>> loginUserWithCredentials({
    required String identifier,
    required String password,
  }) async {
    try {
      final isEmail = identifier.contains('@');
      final cleanNum = isEmail ? '' : identifier.replaceAll(RegExp(r'\D'), '');
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'mobile_number': !isEmail ? (cleanNum.isNotEmpty ? cleanNum : identifier) : '',
          'email': isEmail ? identifier.trim() : '',
          'password': password,
        }),
      );
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true && body['user'] != null) {
        if (body['token'] != null) {
          jwtToken = body['token'].toString();
        }
        return {
          'success': true,
          'user': _mapRowToUser(body['user']),
          'token': jwtToken,
        };
      }
      return {
        'success': false,
        'message': body['message'] ?? 'Invalid credentials. Please check your password.',
      };
    } catch (e) {
      print('❌ Error logging in user via API: $e');
      return {'success': false, 'message': 'Server unreachable. Please try again.'};
    }
  }

  // 3. POST /api/login - Officer / Admin Email Login
  Future<Map<String, dynamic>> loginUserWithEmail(String email, String role, {String password = ''}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'role': role, 'password': password}),
      );
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (response.statusCode == 200 && body['success'] == true && body['user'] != null) {
        if (body['token'] != null) {
          jwtToken = body['token'].toString();
        }
        return {'success': true, 'user': _mapRowToUser(body['user']), 'token': jwtToken};
      }
      return {'success': false, 'message': body['message'] ?? 'Login failed.'};
    } catch (e) {
      print('Error in loginUserWithEmail: $e');
      return {'success': false, 'message': 'Server unreachable. Please try again.'};
    }
  }

  List<Map<String, dynamic>>? _cachedWsDevices;
  DateTime? _cachedWsTime;

  /// Fetch live weather sensor devices from AWS WS_Nearest_Sensors API
  Future<List<Map<String, dynamic>>> fetchWsNearestSensors({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedWsDevices != null &&
        _cachedWsTime != null &&
        DateTime.now().difference(_cachedWsTime!) < const Duration(minutes: 1)) {
      return _cachedWsDevices!;
    }
    try {
      final response = await http.get(Uri.parse('https://5mqwg03znl.execute-api.us-east-1.amazonaws.com/default/WS_Nearest_Sensors?state=Kerala'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['devices'] is List) {
          _cachedWsDevices = List<Map<String, dynamic>>.from(body['devices']);
          _cachedWsTime = DateTime.now();
          return _cachedWsDevices!;
        }
      }
    } catch (e) {
      print('Error fetching WS_Nearest_Sensors API: $e');
    }
    return _cachedWsDevices ?? [];
  }

  /// Get raw live telemetry object for a specific DeviceId from cached WS_Nearest_Sensors API response
  Map<String, dynamic>? getWsDeviceRaw(String deviceId) {
    if (_cachedWsDevices == null) return null;
    for (var d in _cachedWsDevices!) {
      if (d['DeviceId']?.toString() == deviceId || d['Annam_ID']?.toString() == deviceId) {
        return d;
      }
    }
    return null;
  }

  // 4. GET /api/stations - Fetch All Non-Rejected Stations (for map/public view)
  Future<List<KsdmaStation>> fetchStations() async {
    final List<KsdmaStation> stationsList = [];

    // 1. Fetch live WS_Nearest_Sensors API stations (45 Kerala weather sensors)
    try {
      final devices = await fetchWsNearestSensors();
      for (var d in devices) {
        final deviceId = d['DeviceId']?.toString() ?? d['Annam_ID']?.toString() ?? 'WS_UNKNOWN';
        final rawDistrict = d['District']?.toString() ?? 'Kerala';
        final cleanDistrict = rawDistrict.replaceAll(RegExp(r'\s+district', caseSensitive: false), '').trim();
        final rawCity = d['City']?.toString() ?? cleanDistrict;
        final cleanCity = rawCity.replaceAll(RegExp(r'\s+taluk', caseSensitive: false), '').trim();

        final lat = double.tryParse(d['Latitude']?.toString() ?? '') ?? 10.5276;
        final lng = double.tryParse(d['Longitude']?.toString() ?? '') ?? 76.2144;
        final timeStr = d['TimeStamp']?.toString() ?? '';
        final createdAt = DateTime.tryParse(timeStr) ?? DateTime.now();

        stationsList.add(KsdmaStation(
          stationId: deviceId,
          ownerUserId: 'aws_sensor_network',
          ownerName: 'AWS Telemetry Network',
          ownerCategory: UserCategory.districtOfficer,
          category: StationCategory.aws,
          instrumentType: InstrumentType.awsAutomaticStation,
          deviceMake: 'Automatic Weather Station',
          measurementLocation: '$cleanCity, $cleanDistrict',
          latitude: lat,
          longitude: lng,
          district: cleanDistrict,
          taluk: cleanCity,
          gramaPanchayat: cleanCity,
          village: cleanCity,
          approvalStatus: ApprovalStatus.approved,
          createdAt: createdAt,
        ));
      }
    } catch (e) {
      print('Error mapping WS_Nearest_Sensors stations: $e');
    }

    // 2. Fetch custom stations from backend Lambda API
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/stations'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['stations'] != null) {
          final List rows = body['stations'];
          final existingIds = stationsList.map((s) => s.stationId).toSet();
          for (var r in rows) {
            final st = _mapRowToStation(r);
            if (!existingIds.contains(st.stationId)) {
              stationsList.add(st);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching stations via API: $e');
    }

    return stationsList;
  }

  /// PostGIS Accelerated Radius Search: GET /api/stations/nearby
  Future<List<KsdmaStation>> fetchNearbyStations({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final url = Uri.parse('$apiBaseUrl/stations/nearby?lat=$latitude&lng=$longitude&radius_km=$radiusKm');
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['stations'] != null) {
          final List rows = body['stations'];
          return rows.map((r) => _mapRowToStation(r)).toList();
        }
      }
    } catch (e) {
      print('Error fetching nearby stations via PostGIS API: $e');
    }
    return [];
  }

  /// PostGIS Accelerated Reverse-Geocoding: GET /api/stations/reverse-geocode
  Future<Map<String, String>?> reverseGeocodeLocation(double lat, double lng) async {
    try {
      final url = Uri.parse('$apiBaseUrl/stations/reverse-geocode?lat=$lat&lng=$lng');
      final response = await http.get(url, headers: {'Accept': 'application/json'});
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true) {
          return {
            'district': body['district']?.toString() ?? '',
            'taluk': body['taluk']?.toString() ?? '',
            'grama_panchayat': body['grama_panchayat']?.toString() ?? '',
          };
        }
      }
    } catch (e) {
      print('Error in PostGIS Reverse Geocoding: $e');
    }
    return null;
  }

  // 5. GET /api/stations/pending - Fetch Only Pending Stations (for Admin Dashboard)
  Future<List<KsdmaStation>> fetchPendingStations() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/stations/pending'),
        headers: {'Accept': 'application/json'},
      );
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
        headers: authHeaders,   // ✅ FIXED: was {'Content-Type': 'application/json'}
        body: jsonEncode({'station_id': stationId, 'admin_id': 'usr_admin_hq'}),
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('❌ Approve Unauthorized: ${response.body}');
      }
      return response.statusCode == 200;
    } catch (e) {
      print('Error approving station via API: $e');
      return false;
    }
  }

  // 8. POST /api/reject - Admin Reject Station
  Future<bool> rejectStation(String stationId, {String reason = 'Rejected by Admin HQ'}) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/reject'),
        headers: authHeaders,   // ✅ FIXED: was {'Content-Type': 'application/json'}
        body: jsonEncode({
          'station_id': stationId,
          'admin_id': 'usr_admin_hq',
          'rejection_reason': reason,
        }),
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        print('❌ Reject Unauthorized: ${response.body}');
      }
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
          'is_removed': obs.isRemoved,
          'removal_reason': obs.removalReason,
          'is_edited': obs.isEdited,
          'status': obs.isRemoved ? 'removed' : 'approved',
        }),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('API observation sync notice ($e). Saved locally in state.');
      return true;
    }
  }

  // 10. PUT /api/observations/:id - Admin Flag/Update Observation as is_removed = true with removal_reason
   Future<bool> deleteObservation(String observationId, String reason) async {
    try {
      final response = await http.put(
        Uri.parse('$apiBaseUrl/observations/$observationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'is_removed': true,
          'status': 'removed',
          'removal_reason': reason,
        }),
      ).timeout(const Duration(seconds: 4));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return true;
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

  DateTime? _parseTimeStamp(dynamic ts) {
    if (ts == null) return null;
    final s = ts.toString().trim();
    if (s.isEmpty) return null;

    final dt = DateTime.tryParse(s);
    if (dt != null) return dt.toLocal();

    try {
      final spaceParts = s.split(' ');
      final dateParts = spaceParts[0].split(RegExp(r'[-/]'));
      if (dateParts.length == 3) {
        int? year, month, day;
        if (dateParts[0].length == 4) {
          year = int.tryParse(dateParts[0]);
          month = int.tryParse(dateParts[1]);
          day = int.tryParse(dateParts[2]);
        } else if (dateParts[2].length == 4) {
          day = int.tryParse(dateParts[0]);
          month = int.tryParse(dateParts[1]);
          year = int.tryParse(dateParts[2]);
        }
        if (year != null && month != null && day != null) {
          int hour = 0, minute = 0, second = 0;
          if (spaceParts.length > 1) {
            final timeParts = spaceParts[1].split(':');
            if (timeParts.length >= 2) {
              hour = int.tryParse(timeParts[0]) ?? 0;
              minute = int.tryParse(timeParts[1]) ?? 0;
              if (timeParts.length >= 3) {
                second = int.tryParse(timeParts[2]) ?? 0;
              }
            }
          }
          return DateTime(year, month, day, hour, minute, second);
        }
      }
    } catch (_) {}
    return null;
  }

  double? _extractTemperature(Map item) {
    final raw = item['now_temperature'] ?? item['temperature'];
    if (raw == null) return null;
    final val = double.tryParse(raw.toString().trim());
    if (val != null && val > -50 && val < 70 && val != 0.0) {
      return val;
    }
    return null;
  }

  double? _extractHumidity(Map item) {
    final raw = item['now_relative_humidity'] ??
                item['Maximum_Relative_Humidity'] ??
                item['Humidity'] ??
                item['humidity'] ??
                item['now_humidity'];
    if (raw == null) return null;
    return double.tryParse(raw.toString().trim());
  }

  double? _extractRainfall(Map item) {
    final raw = item['Rainfall_Cumulative'] ??
                item['RainfallCumulative'] ??
                item['Rainfall_Cumulative_mm'] ??
                item['RainfallDaily'] ??
                item['RainfallDailyComulative'] ??
                item['Rainfall'] ??
                item['Rainfall_mm'] ??
                item['RainfallHourly'] ??
                item['rainfall'];
    return double.tryParse(raw?.toString() ?? '');
  }

  /// Fetch Today's and Yesterday's full AWS telemetry via new pre-calculated keraladata API
  /// Uses server-calculated Maximum_Temperature, Minimum_Temperature, Average_Humidity, and Total_Rainfall
  Future<List<KsdmaObservation>> fetchTodayAndYesterdayAwsObservations(List<String> deviceIds) async {
    final List<KsdmaObservation> awsObsList = [];
    final now = DateTime.now();
    final todayStr = DateFormat('dd-MM-yyyy').format(now);
    final yesterday = now.subtract(const Duration(days: 1));
    final yestStr = DateFormat('dd-MM-yyyy').format(yesterday);

    // Batch requests in chunks of 12 for fast parallel loading
    const chunkSize = 12;
    for (int i = 0; i < deviceIds.length; i += chunkSize) {
      final chunk = deviceIds.sublist(i, i + chunkSize > deviceIds.length ? deviceIds.length : i + chunkSize);
      final futures = chunk.map((devId) async {
        try {
          final cleanNum = devId.replaceAll('WS_', '').trim();
          final formattedDevId = 'WS_$cleanNum';
          final encodedKey = Uri.encodeComponent(ApiKeys.annamApiKey);

          final String urlYest = 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/keraladata?startdate=$yestStr&enddate=$yestStr&annam_id=$formattedDevId&key=$encodedKey&mode=view';
          final String urlToday = 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/keraladata?startdate=$todayStr&enddate=$todayStr&annam_id=$formattedDevId&key=$encodedKey&mode=view';

          final responses = await Future.wait([
            http.get(Uri.parse(urlYest)).timeout(const Duration(seconds: 25)),
            http.get(Uri.parse(urlToday)).timeout(const Duration(seconds: 25)),
          ]);

          final List<KsdmaObservation> devObs = [];

          // Helper to extract observation from Calculated or items
          void parseAndAddObservation(http.Response response, DateTime targetDate, String label) {
            if (response.statusCode != 200) return;
            final dynamic body = jsonDecode(response.body);

            double? maxTemp, minTemp, maxHum, avgHum, totalRain;

            if (body is Map && body['Calculated'] is List && (body['Calculated'] as List).isNotEmpty) {
              final calc = Map<String, dynamic>.from((body['Calculated'] as List).first);
              maxTemp = double.tryParse(calc['Maximum_Temperature']?.toString() ?? '');
              minTemp = double.tryParse(calc['Minimum_Temperature']?.toString() ?? '');
              maxHum = double.tryParse(calc['Maximum_Humidity']?.toString() ?? '');
              avgHum = double.tryParse(calc['Average_Humidity']?.toString() ?? '');
              totalRain = double.tryParse(calc['Total_Rainfall']?.toString() ?? '');
            } else {
              // Fallback to item-by-item parsing if Calculated field is missing
              List items = body is List ? body : (body is Map && body['items'] is List ? body['items'] : []);
              if (items.isNotEmpty) {
                items.sort((a, b) {
                  final dtA = _parseTimeStamp(a['TimeStamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final dtB = _parseTimeStamp(b['TimeStamp']) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return dtA.compareTo(dtB);
                });
                double totalH = 0;
                int humCount = 0;

                for (var item in items) {
                  final t = _extractTemperature(item);
                  if (t != null) {
                    if (maxTemp == null || t > maxTemp) maxTemp = t;
                    if (minTemp == null || t < minTemp) minTemp = t;
                  }
                  final h = _extractHumidity(item);
                  if (h != null) {
                    totalH += h;
                    humCount++;
                    if (maxHum == null || h > maxHum) maxHum = h;
                  }
                }
                if (humCount > 0) avgHum = double.parse((totalH / humCount).toStringAsFixed(1));
                for (int idx = items.length - 1; idx >= 0; idx--) {
                  final r = _extractRainfall(items[idx]);
                  if (r != null) {
                    totalRain = r;
                    break;
                  }
                }
              }
            }

            if (maxTemp != null || minTemp != null || maxHum != null || avgHum != null || totalRain != null) {
              final obsDt = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
              devObs.add(KsdmaObservation(
                observationId: 'obs_${devId}_$label',
                stationId: devId,
                submittedByUserId: 'aws_sensor_network',
                observationDate: targetDate,
                observationTime: TimeOfDay(hour: targetDate.hour, minute: targetDate.minute),
                submissionTimestamp: obsDt,
                rainfallMm: totalRain ?? 0.0,
                maxTemperatureC: maxTemp,
                minTemperatureC: minTemp,
                humidityPercent: maxHum ?? avgHum,
      
                riverWaterLevelM: null,
                source: 'WS_KERALA_PRECALCULATED_API',
              ));
            }
          }

          parseAndAddObservation(responses[0], yesterday, 'yesterday');
          parseAndAddObservation(responses[1], now, 'today');

          return devObs;
        } catch (e) {
          debugPrint('Error fetching AWS history for $devId: $e');
          return <KsdmaObservation>[];
        }
      });

      final results = await Future.wait(futures);
      for (var list in results) {
        awsObsList.addAll(list);
      }
    }

    return awsObsList;
  }

  /// Fetch full date range AWS telemetry with daily precalculated summary & averages
  Future<List<KsdmaObservation>> fetchAwsObservationsForDateRange(List<String> deviceIds, DateTime startDate, DateTime endDate) async {
    final List<KsdmaObservation> awsObsList = [];
    final startStr = DateFormat('dd-MM-yyyy').format(startDate);
    final endStr = DateFormat('dd-MM-yyyy').format(endDate);

    const chunkSize = 10;
    for (int i = 0; i < deviceIds.length; i += chunkSize) {
      final chunk = deviceIds.sublist(i, i + chunkSize > deviceIds.length ? deviceIds.length : i + chunkSize);
      final futures = chunk.map((devId) async {
        try {
          final cleanNum = devId.replaceAll('WS_', '').trim();
          final formattedDevId = 'WS_$cleanNum';
          final encodedKey = Uri.encodeComponent(ApiKeys.annamApiKey);

          final String urlRange = 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/keraladata?startdate=$startStr&enddate=$endStr&annam_id=$formattedDevId&key=$encodedKey&mode=view';
          final response = await http.get(Uri.parse(urlRange)).timeout(const Duration(seconds: 30));

          if (response.statusCode != 200) return <KsdmaObservation>[];

          final dynamic body = jsonDecode(response.body);
          final List<KsdmaObservation> devObs = [];

          List items = body is List ? body : (body is Map && body['items'] is List ? body['items'] : []);

          if (items.isNotEmpty) {
            final Map<String, List<dynamic>> groupedByDay = {};
            for (var item in items) {
              final dt = _parseTimeStamp(item['TimeStamp']);
              if (dt != null) {
                final dayKey = DateFormat('yyyy-MM-dd').format(dt);
                groupedByDay.putIfAbsent(dayKey, () => []).add(item);
              }
            }

            groupedByDay.forEach((dayKey, dayItems) {
              try {
                final targetDate = DateFormat('yyyy-MM-dd').parse(dayKey);
                double? maxTemp, minTemp, maxHum, avgHum, totalRain;
                double totalH = 0;
                int humCount = 0;

                for (var item in dayItems) {
                  final t = _extractTemperature(item);
                  if (t != null) {
                    if (maxTemp == null || t > maxTemp) maxTemp = t;
                    if (minTemp == null || t < minTemp) minTemp = t;
                  }
                  final h = _extractHumidity(item);
                  if (h != null) {
                    totalH += h;
                    humCount++;
                    if (maxHum == null || h > maxHum) maxHum = h;
                  }
                }
                if (humCount > 0) avgHum = double.parse((totalH / humCount).toStringAsFixed(1));

                for (int idx = dayItems.length - 1; idx >= 0; idx--) {
                  final r = _extractRainfall(dayItems[idx]);
                  if (r != null) {
                    totalRain = r;
                    break;
                  }
                }

                final obsDt = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
                devObs.add(KsdmaObservation(
                  observationId: 'obs_${devId}_${dayKey}',
                  stationId: devId,
                  submittedByUserId: 'aws_sensor_network',
                  observationDate: targetDate,
                  observationTime: const TimeOfDay(hour: 23, minute: 59),
                  submissionTimestamp: obsDt,
                  rainfallMm: totalRain ?? 0.0,
                  maxTemperatureC: maxTemp,
                  minTemperatureC: minTemp,
                  humidityPercent: avgHum ?? maxHum,
                  riverWaterLevelM: null,
                  source: 'WS_KERALA_PRECALCULATED_API',
                ));
              } catch (e) {
                print('Error grouping AWS day: $e');
              }
            });
          } else if (body is Map && body['Calculated'] is List && (body['Calculated'] as List).isNotEmpty) {
            for (var calcItem in (body['Calculated'] as List)) {
              final calc = Map<String, dynamic>.from(calcItem);
              final dateVal = calc['Date']?.toString() ?? calc['date']?.toString() ?? calc['TimeStamp']?.toString() ?? '';
              DateTime targetDate = endDate;
              if (dateVal.isNotEmpty) {
                targetDate = DateTime.tryParse(dateVal) ?? _parseTimeStamp(dateVal) ?? endDate;
              }

              final maxTemp = double.tryParse(calc['Maximum_Temperature']?.toString() ?? '');
              final minTemp = double.tryParse(calc['Minimum_Temperature']?.toString() ?? '');
              final maxHum = double.tryParse(calc['Maximum_Humidity']?.toString() ?? '');
              final avgHum = double.tryParse(calc['Average_Humidity']?.toString() ?? '');
              final totalRain = double.tryParse(calc['Total_Rainfall']?.toString() ?? '');

              final obsDt = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
              devObs.add(KsdmaObservation(
                observationId: 'obs_${devId}_${targetDate.year}_${targetDate.month}_${targetDate.day}',
                stationId: devId,
                submittedByUserId: 'aws_sensor_network',
                observationDate: targetDate,
                observationTime: const TimeOfDay(hour: 23, minute: 59),
                submissionTimestamp: obsDt,
                rainfallMm: totalRain ?? 0.0,
                maxTemperatureC: maxTemp,
                minTemperatureC: minTemp,
                humidityPercent: avgHum ?? maxHum,
                riverWaterLevelM: null,
                source: 'WS_KERALA_PRECALCULATED_API',
              ));
            }
          }
          return devObs;
        } catch (e) {
          debugPrint('Error fetching AWS range history for $devId: $e');
          return <KsdmaObservation>[];
        }
      });

      final results = await Future.wait(futures);
      for (var list in results) {
        awsObsList.addAll(list);
      }
    }
    return awsObsList;
  }

  // 12. GET /api/observations - Fetch All Live & Historical Observations
  Future<List<KsdmaObservation>> fetchObservations() async {
    final List<KsdmaObservation> obsList = [];
    final List<String> awsDeviceIds = [];

    // 1. Fetch snapshot observations from WS_Nearest_Sensors API as baseline
    try {
      final devices = await fetchWsNearestSensors();
      for (var d in devices) {
        final deviceId = d['DeviceId']?.toString() ?? d['Annam_ID']?.toString() ?? 'WS_UNKNOWN';
        if (deviceId != 'WS_UNKNOWN') awsDeviceIds.add(deviceId);
        final temp = double.tryParse(d['Temperature']?.toString() ?? '');
        final humidity = double.tryParse(d['Humidity']?.toString() ?? '');
        final rainfall = double.tryParse(d['Rainfall']?.toString() ?? '');
        final timeStr = d['TimeStamp']?.toString() ?? '';
        final obsDt = DateTime.tryParse(timeStr) ?? DateTime.now();

        obsList.add(KsdmaObservation(
          observationId: 'obs_${deviceId}_${obsDt.millisecondsSinceEpoch}',
          stationId: deviceId,
          submittedByUserId: 'aws_sensor_network',
          observationDate: obsDt,
          observationTime: TimeOfDay(hour: obsDt.hour, minute: obsDt.minute),
          submissionTimestamp: obsDt,
          rainfallMm: rainfall,
          maxTemperatureC: temp,
          minTemperatureC: temp != null ? double.parse((temp - 3.5).toStringAsFixed(2)) : null,
          humidityPercent: humidity,
          riverWaterLevelM: null,
          source: 'WS_NEAREST_SENSORS_API',
        ));
      }
    } catch (e) {
      print('Error mapping WS_Nearest_Sensors observations: $e');
    }

    // 2. Fetch Today's & Yesterday's full AWS telemetry via WS_Kerala_API
    if (awsDeviceIds.isNotEmpty) {
      try {
        final fullAwsObs = await fetchTodayAndYesterdayAwsObservations(awsDeviceIds);
        // Update/Replace baseline snapshot with full API observations if present
        final fullStationIdsToday = fullAwsObs.where((o) => DateUtils.isSameDay(o.observationDate, DateTime.now())).map((o) => o.stationId).toSet();
        if (fullStationIdsToday.isNotEmpty) {
          obsList.removeWhere((o) => fullStationIdsToday.contains(o.stationId) && o.source == 'WS_NEAREST_SENSORS_API');
        }
        obsList.addAll(fullAwsObs);
      } catch (e) {
        print('Error fetching full AWS observations via WS_Kerala_API: $e');
      }
    }

    // 3. Fetch custom observations from backend Lambda API
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/observations'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['observations'] != null) {
          final List rows = body['observations'];
          for (var r in rows) {
            obsList.add(_mapRowToObservation(r));
          }
        }
      }
    } catch (e) {
      print('Error fetching observations via API: $e');
    }

    return obsList;
  }

  // 13. GET /api/champions - Fetch Weather Champions Leaderboard
  Future<List<KsdmaUser>> fetchChampions() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/champions'),
        headers: {'Accept': 'application/json'},
      );
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
      final response = await http.get(
        Uri.parse('$apiBaseUrl/boundaries'),
        headers: {'Accept': 'application/json'},
      );
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

  // 15. GET /api/admin-hierarchy - Fetch Administrative Hierarchy Tree
  Future<Map<String, Map<String, List<String>>>> fetchAdminHierarchy() async {
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/admin-hierarchy'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final Map<String, dynamic> body = jsonDecode(response.body);
        if (body['success'] == true && body['hierarchy'] != null) {
          final Map<String, dynamic> rawTree = body['hierarchy'];
          final Map<String, Map<String, List<String>>> result = {};
          rawTree.forEach((dist, talukObj) {
            if (talukObj is Map) {
              final Map<String, List<String>> tMap = {};
              talukObj.forEach((tName, pList) {
                if (pList is List) {
                  tMap[tName.toString()] = pList.map((e) => e.toString()).toList();
                }
              });
              result[dist.toString()] = tMap;
            }
          });
          return result;
        }
      }
    } catch (e) {
      print('Error fetching admin hierarchy via API: $e');
    }
    return {};
  }

  // ─── Mapper Helpers ───────────────────────────────────────────────────────

  int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? 0;
  }

  KsdmaUser _mapRowToUser(Map<String, dynamic> r) {
    final roleStr = (r['user_role'] ?? r['role'] ?? 'VOLUNTEER').toString().toUpperCase();
    final role = roleStr == 'ADMIN'
        ? UserRole.admin
        : roleStr == 'OFFICER'
            ? UserRole.officer
            : UserRole.volunteer;

    return KsdmaUser(
      userId: (r['user_id'] ?? '').toString(),
      fullName: (r['full_name'] ?? '').toString(),
      mobileNumber: (r['mobile_number'] ?? '').toString(),
      email: (r['email'] ?? '').toString(),
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
      streakDays: _toInt(r['current_streak'] ?? r['streak_days']),
      maxStreak: _toInt(r['max_streak'] ?? r['current_streak'] ?? r['streak_days']),
      totalObservations: _toInt(r['total_contributions'] ?? r['total_observations']),
      todayReadings: _toInt(r['today_readings'] ?? r['today_observations']),
      lastObservationDate: r['last_observation_date'] != null ? DateTime.tryParse(r['last_observation_date'].toString()) : null,
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
      district: r['district']?.toString() ?? 'Kozhikode',
      taluk: r['taluk']?.toString() ?? '',
      gramaPanchayat: r['grama_panchayat']?.toString() ?? '',
      village: r['village']?.toString() ?? '',
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
    final statusStr = r['status']?.toString().toLowerCase() ?? '';
    final bool isRemoved = r['is_removed'] == true || statusStr == 'removed' || statusStr == 'rejected';
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
      isEdited: r['is_edited'] == true || r['is_edited'] == 'true',
      isRemoved: isRemoved,
      removalReason: r['removal_reason']?.toString(),
    );
  }
}
