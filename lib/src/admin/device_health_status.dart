import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:intl/intl.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/views/home/home_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/device_graph.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/src/admin/quality_diagnostics_page.dart';
import 'package:cloud_sense_webapp/src/admin/admin_page.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

class DeviceHealthData {
  final String deviceId;
  final String deviceIdTopic;
  final String imeiNumber;
  final String? city;
  final String? district;
  final String? state;
  final String? firmwareVersion;
  final int healthScore;
  final String healthStatus;
  final int lastActiveMinsAgo;
  final String lastSeenIst;
  final int signalDbm;
  final String signalStatus;
  final double batteryVoltage;
  final String batteryStatus;
  final String sdCardStatus;
  final bool sdCardMounted;
  final double avgCompleteness7d;
  final int totalMissing7d;
  final int totalDuplicates7d;
  final int daysInSummary;
  final double? batteryDrainage7d;
  final double? batteryDrainPerHour;
  final List<Map<String, dynamic>> dailyCompleteness;
  final List<String> missingParameters;
  final bool isDetailed;
  final double? latitude;
  final double? longitude;

  DeviceHealthData({
    required this.deviceId,
    required this.deviceIdTopic,
    required this.imeiNumber,
    this.city,
    this.district,
    this.state,
    this.firmwareVersion,
    required this.healthScore,
    required this.healthStatus,
    required this.lastActiveMinsAgo,
    required this.lastSeenIst,
    required this.signalDbm,
    required this.signalStatus,
    required this.batteryVoltage,
    required this.batteryStatus,
    required this.sdCardStatus,
    required this.sdCardMounted,
    required this.avgCompleteness7d,
    required this.totalMissing7d,
    required this.totalDuplicates7d,
    required this.daysInSummary,
    this.batteryDrainage7d,
    this.batteryDrainPerHour,
    required this.dailyCompleteness,
    required this.missingParameters,
    this.isDetailed = false,
    this.latitude,
    this.longitude,
  });

  factory DeviceHealthData.fromJson(Map<String, dynamic> json) {
    return DeviceHealthData(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceIdTopic: json['deviceId_topic']?.toString() ?? '',
      imeiNumber: json['IMEINumber']?.toString() ?? '',
      city: json['City'],
      district: json['District'],
      state: json['State'],
      firmwareVersion: json['FirmwareVersion']?.toString(),
      healthScore: (json['health_score'] as num?)?.toInt() ?? 0,
      healthStatus:
          (json['health_status'] ?? 'offline').toString().toLowerCase(),
      lastActiveMinsAgo: (json['last_active_mins_ago'] as num?)?.toInt() ?? 0,
      lastSeenIst: json['last_seen_ist']?.toString() ?? '',
      signalDbm: (json['signal_dbm'] as num?)?.toInt() ??
          (json['SignalStrength'] as num?)?.toInt() ??
          (json['Signal_Strength'] as num?)?.toInt() ??
          0,
      signalStatus: json['signal_status']?.toString() ?? 'unknown',
      batteryVoltage: (json['battery_voltage'] ??
              json['BatteryVoltage'] ??
              json['Battery_Voltage'] ??
              0.0)
          .toDouble(),
      batteryStatus: json['battery_status']?.toString() ?? 'unknown',
      sdCardStatus: json['sd_card_status']?.toString() ?? 'unknown',
      sdCardMounted: json['sd_card_mounted'] ?? false,
      avgCompleteness7d: (json['avg_completeness_7d'] ?? 0.0).toDouble(),
      totalMissing7d: (json['total_missing_7d'] as num?)?.toInt() ?? 0,
      totalDuplicates7d: (json['total_duplicates_7d'] as num?)?.toInt() ??
          (json['daily_completeness'] as List?)?.fold<int>(
              0,
              (sum, day) =>
                  sum +
                  (((day as Map<String, dynamic>)['duplicate_count'] as num?)
                          ?.toInt() ??
                      0)) ??
          0,
      daysInSummary: (json['days_in_summary'] as num?)?.toInt() ?? 0,
      batteryDrainage7d: json['battery_drainage_7d'] != null
          ? (json['battery_drainage_7d'] as num).toDouble()
          : null,
      batteryDrainPerHour: json['battery_drain_per_hour'] != null
          ? (json['battery_drain_per_hour'] as num).toDouble()
          : null,
      dailyCompleteness:
          List<Map<String, dynamic>>.from(json['daily_completeness'] ?? []),
      missingParameters:
          List<String>.from(json['sensor_data']?['missing_parameters'] ?? []),
      isDetailed: json['daily_completeness'] != null,
      latitude: _safeDouble(json['Latitude']) ?? _safeDouble(json['latitude']),
      longitude:
          _safeDouble(json['Longitude']) ?? _safeDouble(json['longitude']),
    );
  }

  DeviceHealthData copyWith({
    double? latitude,
    double? longitude,
    bool? isDetailed,
    List<Map<String, dynamic>>? dailyCompleteness,
    List<String>? missingParameters,
    String? imeiNumber,
    String? lastSeenIst,
    String? signalStatus,
    String? batteryStatus,
    String? sdCardStatus,
    double? batteryVoltage,
    int? signalDbm,
    int? healthScore,
    String? healthStatus,
    int? lastActiveMinsAgo,
    double? avgCompleteness7d,
    int? totalMissing7d,
    int? totalDuplicates7d,
    int? daysInSummary,
    double? batteryDrainage7d,
    double? batteryDrainPerHour,
    String? city,
    String? district,
    String? state,
  }) {
    return DeviceHealthData(
      deviceId: deviceId,
      deviceIdTopic: deviceIdTopic,
      imeiNumber: imeiNumber ?? this.imeiNumber,
      city: city ?? this.city,
      district: district ?? this.district,
      state: state ?? this.state,
      firmwareVersion: firmwareVersion,
      healthScore: healthScore ?? this.healthScore,
      healthStatus: healthStatus ?? this.healthStatus,
      lastActiveMinsAgo: lastActiveMinsAgo ?? this.lastActiveMinsAgo,
      lastSeenIst: lastSeenIst ?? this.lastSeenIst,
      signalDbm: signalDbm ?? this.signalDbm,
      signalStatus: signalStatus ?? this.signalStatus,
      batteryVoltage: batteryVoltage ?? this.batteryVoltage,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      sdCardStatus: sdCardStatus ?? this.sdCardStatus,
      sdCardMounted: sdCardMounted,
      avgCompleteness7d: avgCompleteness7d ?? this.avgCompleteness7d,
      totalMissing7d: totalMissing7d ?? this.totalMissing7d,
      totalDuplicates7d: totalDuplicates7d ?? this.totalDuplicates7d,
      daysInSummary: daysInSummary ?? this.daysInSummary,
      batteryDrainage7d: batteryDrainage7d ?? this.batteryDrainage7d,
      batteryDrainPerHour: batteryDrainPerHour ?? this.batteryDrainPerHour,
      dailyCompleteness: dailyCompleteness ?? this.dailyCompleteness,
      missingParameters: missingParameters ?? this.missingParameters,
      isDetailed: isDetailed ?? this.isDetailed,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  String get location {
    List<String> parts = [];
    if (city != null && city!.isNotEmpty && city != "null") parts.add(city!);
    if (district != null && district!.isNotEmpty && district != "null")
      parts.add(district!);
    if (state != null && state!.isNotEmpty && state != "null")
      parts.add(state!);
    return parts.isEmpty ? 'Unknown' : parts.join(', ');
  }

  String get displayName {
    String? sensorName =
        DevicePrefixUtils.getSensorNameFromTopic(deviceIdTopic);
    if (sensorName != null) {
      return DevicePrefixUtils.toAnnamDisplayName(sensorName);
    }
    // Fallback for cases where deviceIdTopic might be a partial path or missing the '#' separator
    if (deviceIdTopic.contains('WS/SSMet_0126')) {
      final paddedId = deviceId.padLeft(3, '0');
      return DevicePrefixUtils.toAnnamDisplayName('WJ$paddedId');
    }
    return deviceId;
  }
}

double? _safeDouble(dynamic val) {
  if (val == null || val == 'N/A' || val == 'n/a' || val == '') return null;
  if (val is num) return val.toDouble();
  return double.tryParse(val.toString());
}

class DeviceHealthStatusPage extends StatefulWidget {
  const DeviceHealthStatusPage({Key? key}) : super(key: key);

  @override
  State<DeviceHealthStatusPage> createState() => _DeviceHealthStatusPageState();
}

double getResponsiveFontSize(
    BuildContext context, double mobileSize, double desktopSize) {
  final width = MediaQuery.of(context).size.width;
  return width <= 600 ? mobileSize : desktopSize;
}

class _DeviceHealthStatusPageState extends State<DeviceHealthStatusPage> {
  List<DeviceHealthData> _allDevices = [];
  List<DeviceHealthData> _filteredDevices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isMapView = false;
  final MapController _mapController = MapController();

  String _selectedFilter = 'All';
  String _overallFilter = 'All';
  String _batteryFilter = 'All';
  String _sdCardFilter = 'All';
  String _signalFilter = 'All';
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _mainHorizontalController = ScrollController();
  final ScrollController _diagHorizontalController = ScrollController();

  int _visibleCount = 20;
  int? _apiTotalCount;
  bool _isBackgroundLoading = false;
  String? _nextToken;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  final Set<String> _expandedDevices = {};

  final String _apiUrl =
      'https://4p8k77fw8b.execute-api.us-east-1.amazonaws.com/default/IoT_Health_API';

  @override
  void initState() {
    super.initState();
    _loadFilters().then((_) => _fetchHealthData());
    // Auto-refresh every 5 minutes
    _refreshTimer =
        Timer.periodic(const Duration(minutes: 5), (_) => _fetchHealthData());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _mainHorizontalController.dispose();
    _diagHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('health_selectedFilter', _selectedFilter);
    await prefs.setString('health_overallFilter', _overallFilter);
    await prefs.setString('health_batteryFilter', _batteryFilter);
    await prefs.setString('health_sdCardFilter', _sdCardFilter);
    await prefs.setString('health_signalFilter', _signalFilter);
    await prefs.setString('health_searchQuery', _searchQuery);
  }

  Future<void> _loadFilters() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedFilter = prefs.getString('health_selectedFilter') ?? 'All';
      _overallFilter = prefs.getString('health_overallFilter') ?? 'All';
      _batteryFilter = prefs.getString('health_batteryFilter') ?? 'All';
      _sdCardFilter = prefs.getString('health_sdCardFilter') ?? 'All';
      _signalFilter = prefs.getString('health_signalFilter') ?? 'All';
      _searchQuery = prefs.getString('health_searchQuery') ?? '';
      _searchController.text = _searchQuery;
    });
  }

  Future<void> _fetchHealthData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _visibleCount = 20;
      _nextToken = null;
      _hasMore = false;
      // Removed filter resets to preserve state on refresh
    });

    try {
      // Fetching all devices (no limit) to get global counts initially
      // as requested by the user.
      final List<Future<http.Response>> requests = [
        http
            .get(Uri.parse(_apiUrl).replace(queryParameters: {'limit': '1000'}))
            .catchError((e) {
          debugPrint("Error fetching health api: $e");
          return http.Response('{"devices":[]}', 500);
        }),
        http
            .get(Uri.parse(
                'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api'))
            .catchError((e) {
          debugPrint("Error fetching latest api: $e");
          return http.Response('{"devices":[]}', 500);
        }),
        http
            .get(Uri.parse(
                'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity'))
            .catchError((e) {
          debugPrint("Error fetching device activity api: $e");
          return http.Response('{"devices":[]}', 500);
        }),
      ];

      final results = await Future.wait(requests);

      if (results[0].statusCode == 200) {
        final healthResponse = json.decode(results[0].body);
        final List<dynamic> devicesJson = healthResponse['devices'] ?? [];
        List<DeviceHealthData> allDevices =
            devicesJson.map((j) => DeviceHealthData.fromJson(j)).toList();

        // Handle pagination tokens and total count (DynamoDB/API common formats)
        _apiTotalCount =
            int.tryParse(healthResponse['totalCount']?.toString() ?? '');

        _hasMore = healthResponse['has_more'] == true;
        _nextToken = healthResponse['nextToken']?.toString() ??
            healthResponse['LastEvaluatedKey']?.toString() ??
            healthResponse['lastEvaluatedKey']?.toString();

        // Safety: if has_more is missing, fallback to nextToken check
        if (healthResponse['has_more'] == null) {
          _hasMore = _nextToken != null;
        }

        // Build a unified coordinate lookup from both telemetry APIs
        final Map<String, dynamic> coordLookup = {};
        void mergeCoords(http.Response res) {
          if (res.statusCode == 200) {
            try {
              final data = json.decode(res.body);
              final List<dynamic> coordList = data['devices'] ?? [];
              for (var d in coordList) {
                final topic = d['deviceid#topic']?.toString() ??
                    d['DeviceId']?.toString() ??
                    '';
                if (topic.isNotEmpty) {
                  coordLookup[topic] = d;
                }
              }
            } catch (_) {}
          }
        }

        if (results.length > 1) mergeCoords(results[1]);
        if (results.length > 2) mergeCoords(results[2]);

        // Fallback (Ropar/Punjab)
        const double fallbackLat = 30.9756;
        const double fallbackLon = 76.5273;

        // Apply coordinates
        allDevices = allDevices.map((device) {
          double? lat = device.latitude;
          double? lon = device.longitude;

          if (lat == null || lon == null || (lat == 0 && lon == 0)) {
            final topicInfo = coordLookup[device.deviceIdTopic] ??
                coordLookup[device.deviceId];
            if (topicInfo != null) {
              lat = _safeDouble(topicInfo['Latitude']) ??
                  _safeDouble(topicInfo['latitude']);
              lon = _safeDouble(topicInfo['Longitude']) ??
                  _safeDouble(topicInfo['longitude']);
            }
          }

          if (lat == null || lon == null || (lat == 0 && lon == 0)) {
            final jitterLat = fallbackLat +
                (DateTime.now().microsecondsSinceEpoch % 1000 - 500) / 100000.0;
            final jitterLon = fallbackLon +
                (DateTime.now().microsecondsSinceEpoch % 1000 - 500) / 100000.0;
            return device.copyWith(latitude: jitterLat, longitude: jitterLon);
          }

          return device.copyWith(latitude: lat, longitude: lon);
        }).toList();

        if (mounted) {
          setState(() {
            _allDevices = allDevices;
            _lastUpdated = DateTime.now();
            _applyFilters();
            _isLoading = false;
          });

          // If there's more data on the server, start background fetch
          if (_hasMore && _nextToken != null) {
            _fetchAllRemainingPages();
          }

          // Start fetching detailed info for all devices in the background
          _fetchDetailedDataForAll();
        }
      } else {
        throw Exception('Failed to load health data');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  bool _isFetchingDetails = false;

  Future<void> _fetchDetailedDataForAll() async {
    if (_isFetchingDetails) return;
    _isFetchingDetails = true;

    // Fetch details in batches to prevent API rate limiting
    const int batchSize = 5;

    while (mounted && _isFetchingDetails) {
      // Find devices that have missing info (isDetailed == false)
      final pendingDevices =
          _allDevices.where((d) => !d.isDetailed).take(batchSize).toList();

      if (pendingDevices.isEmpty) {
        // If background loading is still adding new devices, wait and check again
        if (_isBackgroundLoading) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        } else {
          break; // All done
        }
      }

      try {
        final futures = pendingDevices
            .map((device) => _fetchDetailedDeviceData(device.deviceIdTopic));
        final results = await Future.wait(futures);

        if (!mounted) break;

        setState(() {
          for (int i = 0; i < pendingDevices.length; i++) {
            final detailed = results[i];
            final targetTopic = pendingDevices[i].deviceIdTopic;
            final index =
                _allDevices.indexWhere((d) => d.deviceIdTopic == targetTopic);

            if (index != -1) {
              if (detailed != null) {
                _allDevices[index] = detailed.copyWith(
                  city: pendingDevices[i].city,
                  district: pendingDevices[i].district,
                  state: pendingDevices[i].state,
                );
              } else {
                // Mark as detailed to prevent infinite retry loops on failure
                _allDevices[index] =
                    _allDevices[index].copyWith(isDetailed: true);
              }
            }
          }
        });
      } catch (e) {
        debugPrint('Batch detail fetch error: $e');
        // On error, mark them as detailed to prevent infinite loop
        setState(() {
          for (var device in pendingDevices) {
            final index = _allDevices
                .indexWhere((d) => d.deviceIdTopic == device.deviceIdTopic);
            if (index != -1) {
              _allDevices[index] =
                  _allDevices[index].copyWith(isDetailed: true);
            }
          }
        });
      }

      // Small delay between batches to be nice to the server
      await Future.delayed(const Duration(milliseconds: 500));
    }

    _isFetchingDetails = false;
  }

  Future<void> _fetchAllRemainingPages() async {
    if (_isBackgroundLoading) return;
    _isBackgroundLoading = true;

    while (_hasMore && _nextToken != null && mounted) {
      try {
        final uri = Uri.parse(_apiUrl).replace(queryParameters: {
          'limit': '1000',
          'nextToken': _nextToken!,
        });
        final response = await http.get(uri);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List<dynamic> newDevicesJson = data['devices'] ?? [];
          final newDevices =
              newDevicesJson.map((j) => DeviceHealthData.fromJson(j)).toList();

          _hasMore = data['has_more'] == true;
          _nextToken = data['nextToken']?.toString() ??
              data['LastEvaluatedKey']?.toString() ??
              data['lastEvaluatedKey']?.toString();

          if (data['has_more'] == null) {
            _hasMore = _nextToken != null;
          }

          if (mounted) {
            setState(() {
              _allDevices.addAll(newDevices);
              _applyFilters();
            });
          }
          // Small delay to prevent hitting API too hard
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          _hasMore = false; // Stop on error
        }
      } catch (e) {
        debugPrint('Background Pagination Error: $e');
        _hasMore = false;
        break;
      }
    }
    _isBackgroundLoading = false;
  }

  Future<void> _loadMoreDevices() async {
    if (_isLoadingMore) return;

    // 1. If we have more in memory than is visible, just increment visible count (Local Pagination)
    if (_visibleCount < _filteredDevices.length) {
      setState(() {
        _visibleCount += 20;
      });
      return;
    }

    // 2. If we need more from the API (Server-Side Pagination)
    if (!_hasMore || _nextToken == null) return;

    // Safety: if background loader is already busy, just wait for it to add items to memory
    if (_isBackgroundLoading) return;

    setState(() => _isLoadingMore = true);

    try {
      final uri = Uri.parse(_apiUrl).replace(queryParameters: {
        'limit': '1000',
        'nextToken': _nextToken!,
      });
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> newDevicesJson = data['devices'] ?? [];
        final newDevices =
            newDevicesJson.map((j) => DeviceHealthData.fromJson(j)).toList();

        // Update pagination token
        _hasMore = data['has_more'] == true;
        _nextToken = data['nextToken']?.toString() ??
            data['LastEvaluatedKey']?.toString() ??
            data['lastEvaluatedKey']?.toString();

        if (data['has_more'] == null) {
          _hasMore = _nextToken != null;
        }

        if (mounted) {
          setState(() {
            _allDevices.addAll(newDevices);
            _visibleCount += newDevices.length;
            _applyFilters();
            _isLoadingMore = false;
          });
        }
      } else {
        throw Exception('Failed to fetch more devices');
      }
    } catch (e) {
      debugPrint('Pagination Error: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading more: ${e.toString()}')),
        );
      }
    }
  }

  Future<DeviceHealthData?> _fetchDetailedDeviceData(
      String deviceIdTopic) async {
    try {
      final response = await http.get(Uri.parse(_apiUrl)
          .replace(queryParameters: {'deviceId_topic': deviceIdTopic}));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DeviceHealthData.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching detailed data: $e');
    }
    return null;
  }

  void _handleCardTap(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'All') {
        _overallFilter = 'All';
        _batteryFilter = 'All';
        _sdCardFilter = 'All';
        _signalFilter = 'All';
        _searchQuery = '';
        _searchController.clear();
      }
    });
    _saveFilters();
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredDevices = _allDevices.where((device) {
        bool matchesSearch = device.displayName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            device.imeiNumber
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            device.location
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            device.missingParameters.any(
                (p) => p.toLowerCase().contains(_searchQuery.toLowerCase())) ||
            (_searchQuery.toLowerCase().trim() == 'missing' &&
                device.missingParameters.isNotEmpty);

        bool matchesStatus = true;
        if (_selectedFilter != 'All') {
          if (_selectedFilter == 'Critical') {
            matchesStatus = device.healthStatus == 'critical';
          } else if (_selectedFilter == 'Offline') {
            matchesStatus = device.healthStatus == 'offline';
          } else {
            matchesStatus =
                device.healthStatus == _selectedFilter.toLowerCase();
          }
        }

        // Column-specific status filters
        bool matchesOverallFilter = _overallFilter == 'All' ||
            device.healthStatus == _overallFilter.toLowerCase();
        bool matchesBatteryFilter = _batteryFilter == 'All' ||
            device.batteryStatus.toLowerCase().trim() ==
                _batteryFilter.toLowerCase();
        bool matchesSDFilter = true;
        if (_sdCardFilter != 'All') {
          if (_sdCardFilter == 'Mounted') {
            matchesSDFilter = device.sdCardMounted;
          } else if (_sdCardFilter == 'Not Mounted') {
            matchesSDFilter = !device.sdCardMounted;
          } else {
            matchesSDFilter = device.sdCardStatus.toLowerCase().trim() ==
                _sdCardFilter.toLowerCase();
          }
        }

        bool matchesSignalFilter = _signalFilter == 'All' ||
            device.signalStatus.toLowerCase().trim() ==
                _signalFilter.toLowerCase();

        return matchesSearch &&
            matchesStatus &&
            matchesOverallFilter &&
            matchesBatteryFilter &&
            matchesSDFilter &&
            matchesSignalFilter;
      }).toList();

      // Sort by status priority: Offline > Critical > Warning > OK
      const Map<String, int> priority = {
        'offline': 1,
        'critical': 2,
        'warning': 3,
        'ok': 4,
      };

      _filteredDevices.sort((a, b) {
        int pA = priority[a.healthStatus] ?? 5;
        int pB = priority[b.healthStatus] ?? 5;
        if (pA != pB) return pA.compareTo(pB);
        // For warning devices: battery critical/low first
        const Map<String, int> battPriority = {
          'critical': 1,
          'warning': 2,
          'ok': 3,
        };
        int bpA = battPriority[a.batteryStatus.toLowerCase().trim()] ?? 4;
        int bpB = battPriority[b.batteryStatus.toLowerCase().trim()] ?? 4;
        if (bpA != bpB) return bpA.compareTo(bpB);

        // Secondary sort by name if priority is same
        return a.displayName.compareTo(b.displayName);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // We try to get ThemeProvider but fallback if not found
    ThemeProvider? themeProvider;
    try {
      themeProvider = Provider.of<ThemeProvider>(context);
    } catch (_) {}

    final isDark = themeProvider?.isDarkMode ??
        Theme.of(context).brightness == Brightness.dark;

    // Premium Theme-aware Palette
    final bgColor = isDark ? const Color(0xFF0B141D) : const Color(0xFFF5F7FA);
    final appBarColor =
        isDark ? const Color(0xFF14212B) : const Color(0xFF1976D2);
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final strong = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final primaryBlue = const Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            _isMapView
                ? 'Sensor Health Map (${_filteredDevices.length})'
                : 'Device Health Status (${_filteredDevices.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.5,
            )),
        actions: [
          // IconButton(
          //   icon: Icon(_isMapView ? Icons.view_list_rounded : Icons.map_rounded,
          //       color: Colors.white),
          //   onPressed: () => setState(() => _isMapView = !_isMapView),
          //   tooltip: _isMapView ? 'Switch to List' : 'Switch to Map',
          // ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchHealthData,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                            color: strong, strokeWidth: 2))
                    : _isMapView
                        ? _buildMapView(isDark)
                        : RefreshIndicator(
                            onRefresh: _fetchHealthData,
                            color: Colors.blueAccent,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryCards(isDark),
                                  const SizedBox(height: 32),
                                  _buildFilterBar(isDark),
                                  const SizedBox(height: 24),
                                  _buildDeviceTable(isDark),
                                  const SizedBox(height: 60),
                                ],
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapView(bool isDark) {
    final devicesWithCoords = _filteredDevices
        .where((d) => d.latitude != null && d.longitude != null);

    if (devicesWithCoords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off_rounded,
                size: 64, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 16),
            Text(
              'No location data available for filtered devices',
              style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 16),
            ),
          ],
        ),
      );
    }

    // Determine center of the map
    LatLng center = const LatLng(30.97, 76.47); // Default to Ropar
    if (devicesWithCoords.isNotEmpty) {
      double avgLat =
          devicesWithCoords.map((d) => d.latitude!).reduce((a, b) => a + b) /
              devicesWithCoords.length;
      double avgLon =
          devicesWithCoords.map((d) => d.longitude!).reduce((a, b) => a + b) /
              devicesWithCoords.length;
      center = LatLng(avgLat, avgLon);
    }

    return FlutterMap(
      key: const ValueKey('health_status_map'),
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(21.7679, 78.8718),
        initialZoom: 4.8,
        minZoom: 2.0,
        maxZoom: 19.0,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-85.05112878, -180),
            const LatLng(85.05112878, 180),
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.CloudSenseVis',
          tileProvider: NetworkTileProvider(),
        ),
        Opacity(
          opacity: 0.8,
          child: TileLayer(
            urlTemplate:
                'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.CloudSenseVis',
            tileProvider: NetworkTileProvider(),
          ),
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            alignment: Alignment.center,
            markers: devicesWithCoords
                .map((device) {
                  Color statusColor;
                  switch (device.healthStatus) {
                    case 'ok':
                      statusColor = Colors.greenAccent;
                      break;
                    case 'warning':
                      statusColor = Colors.orangeAccent;
                      break;
                    case 'critical':
                    case 'offline':
                      statusColor = Colors.redAccent;
                      break;
                    default:
                      statusColor = Colors.grey;
                  }

                  return Marker(
                    point: LatLng(device.latitude!, device.longitude!),
                    width: 60,
                    height: 60,
                    child: GestureDetector(
                      onTap: () => _onDeviceTap(device, isDark),
                      child: Column(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: statusColor.withOpacity(0.5),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              device.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                })
                .cast<Marker>()
                .toList(),
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.blueAccent.withOpacity(0.8),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(bool isDark) {
    int onlineCount = _allDevices.where((d) => d.healthStatus == 'ok').length;
    int warningCount =
        _allDevices.where((d) => d.healthStatus == 'warning').length;
    int criticalCount =
        _allDevices.where((d) => d.healthStatus == 'critical').length;
    int offlineCount =
        _allDevices.where((d) => d.healthStatus == 'offline').length;

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final crossAxisCount =
          isMobile ? 2 : (constraints.maxWidth / 200).floor().clamp(1, 5);
      final spacing = isMobile ? 10.0 : 16.0;
      final childAspectRatio =
          isMobile ? 1.7 : (constraints.maxWidth < 1100 ? 2.5 : 3.2);

      final cards = [
        _StatCard(
            title: 'NEED HELP NOW (Critical)',
            value: criticalCount.toDouble(),
            color: const Color(0xFFF43F5E),
            icon: Icons.gpp_maybe_rounded,
            isSelected: _selectedFilter == 'Critical',
            onTap: () => _handleCardTap('Critical'),
            subtitle: 'Score < 75'),
        _StatCard(
            title: 'KEEP AN EYE ON (Warning)',
            value: warningCount.toDouble(),
            color: const Color(0xFFF59E0B),
            icon: Icons.warning_amber_rounded,
            isSelected: _selectedFilter == 'Warning',
            onTap: () => _handleCardTap('Warning'),
            subtitle: 'Score 75-90'),
        _StatCard(
            title: 'NOT RESPONDING (Offline)',
            value: offlineCount.toDouble(),
            color: const Color(0xFF94A3B8),
            icon: Icons.cloud_off_rounded,
            isSelected: _selectedFilter == 'Offline',
            onTap: () => _handleCardTap('Offline'),
            subtitle: 'last active > 60 min'),
        _StatCard(
            title: 'ALL GOOD (OK)',
            value: onlineCount.toDouble(),
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
            isSelected: _selectedFilter == 'OK',
            onTap: () => _handleCardTap('OK'),
            subtitle: 'Score > 90'),
        _StatCard(
            title: 'TOTAL STATIONS',
            value: (_apiTotalCount ?? _allDevices.length).toDouble(),
            color: const Color(0xFF6366F1),
            icon: Icons.devices_other_rounded,
            isSelected: _selectedFilter == 'All',
            onTap: () => _handleCardTap('All'),
            subtitle: 'All Stations'),
      ];

      return GridView.count(
        crossAxisCount: crossAxisCount,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
        children: cards,
      );
    });
  }

  Widget _buildFilterBar(bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? Colors.black.withOpacity(0.2) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() => _searchQuery = val);
              _saveFilters();
              _applyFilters();
            },
            style: TextStyle(color: strong),
            decoration: InputDecoration(
              hintText: 'Search by station name or village...',
              hintStyle: TextStyle(color: strong.withOpacity(0.4)),
              prefixIcon: Icon(Icons.search, color: strong.withOpacity(0.6)),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
        const SizedBox(height: 15),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              {'value': 'All', 'label': 'All'},
              {'value': 'Critical', 'label': 'Need help now (Critical)'},
              {'value': 'Warning', 'label': 'Keep an eye on (Warning)'},
              {'value': 'Offline', 'label': 'Not responding (Offline)'},
              {'value': 'OK', 'label': 'All good (OK)'},
            ].map((filterMap) {
              final filter = filterMap['value']!;
              final label = filterMap['label']!;
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedFilter = filter;
                        if (filter == 'All') {
                          _overallFilter = 'All';
                          _batteryFilter = 'All';
                          _sdCardFilter = 'All';
                          _signalFilter = 'All';
                          _searchQuery = '';
                          _searchController.clear();
                        }
                      });
                      _saveFilters();
                      _applyFilters();
                    }
                  },
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.03),
                  selectedColor: const Color(0xFF1976D2),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : strong.withOpacity(0.7),
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected ? Colors.transparent : borderColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceTable(bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? Colors.black.withOpacity(0.15) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.1);

    if (_filteredDevices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: strong.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: TextStyle(color: strong.withOpacity(0.4), fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adjusted minWidth after removing Location column
          return Scrollbar(
            controller: _mainHorizontalController,
            thumbVisibility: true,
            thickness: 4,
            child: SingleChildScrollView(
              controller: _mainHorizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width:
                    constraints.maxWidth > 1320 ? constraints.maxWidth : 1320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableHeader(true, isDark),
                    ..._filteredDevices.asMap().entries.take(_visibleCount).map(
                        (entry) => _buildTableRow(
                            entry.value, entry.key, true, isDark)),
                    if (_visibleCount < _filteredDevices.length || _hasMore)
                      _buildLoadMoreButton(isDark),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? CircularProgressIndicator(color: strong, strokeWidth: 2)
            : ElevatedButton.icon(
                onPressed: _loadMoreDevices,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Load More Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
      ),
    );
  }

  Future<void> _onDeviceTap(DeviceHealthData device, bool isDark) async {
    if (device.isDetailed) {
      _showHealthDetailsDialog(device, isDark);
      return;
    }

    // Show loading overlay or dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    final detailedDevice = await _fetchDetailedDeviceData(device.deviceIdTopic);

    // Close loading indicator
    if (mounted) Navigator.pop(context);

    if (detailedDevice != null && mounted) {
      // Update the device in _allDevices if it exists
      setState(() {
        final index = _allDevices
            .indexWhere((d) => d.deviceIdTopic == device.deviceIdTopic);
        if (index != -1) {
          _allDevices[index] = detailedDevice.copyWith(
            city: device.city,
            district: device.district,
            state: device.state,
          );
          _applyFilters();
        }
      });
      _showHealthDetailsDialog(detailedDevice, isDark);
    } else if (mounted) {
      // Fallback: show what we have but maybe warn?
      _showHealthDetailsDialog(device, isDark);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load detailed diagnostics.')),
      );
    }
  }

  void _onQualityCheckTap(DeviceHealthData device, bool isDark) {
    NavigationUtils.navigateTo(
      context,
      '/admin/health/quality-diagnostics',
      arguments: {
        'deviceId': device.deviceId,
        'deviceIdTopic': device.deviceIdTopic,
        'displayName': device.displayName,
        'isDark': isDark,
      },
    );
  }

  Widget _buildTableHeader(bool isExpanded, bool isDark) {
    final cardHeaderBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.02);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: cardHeaderBg,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Ensure dividers reach top/bottom
          children: [
            _HeaderCell(
                label: '#',
                width: 60,
                flex: 0,
                isExpanded: false,
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'DEVICE ID & LOCATION',
                width: 280,
                flex: 4,
                isExpanded: false, // Fixed width
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'OVERALL',
                width: 140,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _overallFilter,
                filterOptions: const [
                  'All',
                  'OK',
                  'Warning',
                  'Critical',
                  'Offline'
                ],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _overallFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'BATTERY',
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _batteryFilter,
                filterOptions: const ['All', 'OK', 'Warning', 'Critical'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _batteryFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'SD CARD',
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _sdCardFilter,
                filterOptions: const ['All', 'Mounted', 'Not Mounted'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _sdCardFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'SIGNAL',
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _signalFilter,
                filterOptions: const ['All', 'OK', 'Warning', 'Critical'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _signalFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'AVG COMPLETENESS',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'LAST ACTIVE',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: false),

            // No border for last cell
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(
      DeviceHealthData device, int index, bool isExpanded, bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final hint =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    final alternateColor =
        isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC);

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: index % 2 == 1 ? alternateColor : Colors.transparent,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: InkWell(
          onTap: () => _onDeviceTap(device, isDark),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DataCell(
                width: 60,
                flex: 0,
                isExpanded: false,
                showBorder: true,
                isDark: isDark,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                        color: subtle,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _DataCell(
                width: 280,
                flex: 4,
                isExpanded: false, // Fixed width
                showBorder: true,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Centered
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.displayName,
                      textAlign: TextAlign.center, // Centered
                      style: TextStyle(
                          color: strong,
                          fontWeight: FontWeight.bold,
                          fontSize: isExpanded ? 13 : 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.location,
                      textAlign: TextAlign.center, // Centered
                      style:
                          TextStyle(color: hint, fontSize: isExpanded ? 11 : 9),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 140,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _onDeviceTap(device, isDark),
                      borderRadius: BorderRadius.circular(6),
                      child: _buildStatusBadge(device.healthStatus,
                          isSmall: !isExpanded),
                    ),
                    if (device.healthStatus == 'ok' ||
                        device.healthStatus == 'warning') ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _onQualityCheckTap(device, isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.8), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'Quality Check',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _DataCell(
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            DevicePrefixUtils.getBatteryIcon(
                                _voltageToPercentage(device.batteryVoltage)
                                    .toInt()),
                            color: _getBatteryColor(device.batteryVoltage),
                            size: isExpanded ? 16 : 14),
                        const SizedBox(width: 6),
                        Text(
                            '${device.batteryVoltage.toStringAsFixed(2)} V (${_voltageToPercentage(device.batteryVoltage).toStringAsFixed(2)}%)',
                            style: TextStyle(
                                color: subtle, fontSize: isExpanded ? 12 : 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getBatteryLabel(device.batteryStatus),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getStatusColor(device.batteryStatus),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      device.sdCardMounted ? 'Mounted' : 'Not Mounted',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: device.sdCardMounted
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: isExpanded ? 12 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSdLabel(device.sdCardStatus),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getStatusColor(device.sdCardStatus),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 110,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getSignalIcon(device.signalDbm),
                            color: _getSignalColor(device.signalDbm),
                            size: isExpanded ? 16 : 14),
                        const SizedBox(width: 6),
                        Text('${device.signalDbm} dBm',
                            style: TextStyle(
                                color: subtle, fontSize: isExpanded ? 12 : 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSignalLabel(device.signalStatus),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getStatusColor(device.signalStatus),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Text(
                  '${device.avgCompleteness7d.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: subtle,
                      fontSize: isExpanded ? 12 : 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: false, // No border for last cell
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatLastActive(device.lastActiveMinsAgo),
                      textAlign: TextAlign.center, // Centered
                      style: TextStyle(
                          color: subtle, fontSize: isExpanded ? 12 : 10),
                    ),
                    if (device.missingParameters.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Tooltip(
                        message: device.missingParameters.join(", "),
                        child: Text(
                          'Missing: ${device.missingParameters.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase().trim();
    if (status == 'ok' || status == 'online' || status == 'mounted') {
      return const Color(0xFF10B981); // Emerald / Online
    }
    if (status == 'warning') {
      return const Color(0xFFF59E0B); // Amber / Warning
    }
    if (status == 'critical' || status == 'fail' || status == 'low') {
      return const Color(0xFFF43F5E); // Rose / Critical
    }
    if (status == 'offline') {
      return const Color(0xFF94A3B8); // Slate / Offline
    }
    return Colors.grey;
  }

  String _getBatteryLabel(String status) {
    String prefix = status.toUpperCase();
    switch (status.toLowerCase().trim()) {
      case 'critical':
        return '$prefix\nCharge immediately';
      case 'warning':
        return '$prefix\nPlan to charge soon';
      case 'ok':
        return '$prefix\nBattery healthy';
      default:
        return '$prefix\nStatus unknown';
    }
  }

  String _getSignalLabel(String status) {
    String prefix = status.toUpperCase();
    switch (status.toLowerCase().trim()) {
      case 'critical':
        return '$prefix\nCheck antenna';
      case 'warning':
        return '$prefix\nData might delay';
      case 'ok':
        return '$prefix\nGood connection';
      default:
        return '$prefix\nCheck network';
    }
  }

  String _getSdLabel(String status) {
    return status.toUpperCase();
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase().trim()) {
      case 'offline':
        return 'Not responding (Offline)';
      case 'critical':
        return 'Need help now (Critical)';
      case 'warning':
        return 'Keep an eye on (Warning)';
      case 'ok':
        return 'All good (OK)';
      default:
        return status.toUpperCase();
    }
  }

  Widget _buildStatusBadge(String status, {bool isSmall = false}) {
    Color color = _getStatusColor(status);
    String label = _getStatusLabel(status);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmall ? 4 : 6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: color,
            fontSize: isSmall ? 8 : 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  double _voltageToPercentage(double voltage) {
    if (voltage <= 0) return 0.0;
    // Li-ion mapping: 2.8V (0%) to 4.2V (100%)
    return ((voltage - 2.8) / (4.2 - 2.8) * 100).clamp(0.0, 100.0).toDouble();
  }

  Color _getBatteryColor(double voltage) {
    if (voltage >= 3.8) return Colors.greenAccent;
    if (voltage >= 3.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  IconData _getSignalIcon(int dbm) {
    if (dbm > -60) return Icons.network_cell;
    if (dbm > -75) return Icons.signal_cellular_alt;
    if (dbm > -90) return Icons.signal_cellular_alt;
    return Icons.signal_cellular_0_bar;
  }

  Color _getSignalColor(int dbm) {
    if (dbm > -70) return Colors.greenAccent;
    if (dbm > -90) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _formatLastActive(int mins) {
    if (mins < 60) {
      return '${mins}m ago';
    } else if (mins < 1440) {
      final hours = mins / 60.0;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h ago';
    } else {
      final days = mins / 1440.0;
      return '${days.toStringAsFixed(days >= 10 ? 0 : 1)}d ago';
    }
  }

  void _showHealthDetailsDialog(DeviceHealthData device, bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          width: MediaQuery.of(context).size.width.clamp(400.0, 1100.0),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161A22) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: strong.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: TextStyle(
                              color: strong,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5),
                        ),
                        if (device.location != 'Unknown') ...[
                          const SizedBox(height: 2),
                          Text(
                            device.location,
                            style: TextStyle(
                              color: subtle,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            // Determine the internal sensor name (e.g., WJ201) for data fetching
                            String? sensorName =
                                DevicePrefixUtils.getSensorNameFromTopic(
                                    device.deviceIdTopic);
                            if (sensorName == null &&
                                device.deviceIdTopic
                                    .contains('WS/SSMet_0126')) {
                              sensorName =
                                  'WJ${device.deviceId.padLeft(3, '0')}';
                            }

                            // Determine the category/sequential name for the graph page
                            final mapping =
                                DevicePrefixUtils.mapCategoryAndPrefix(device
                                        .deviceIdTopic
                                        .contains('WS/SSMet_0126')
                                    ? device.deviceIdTopic
                                    : '0#${device.deviceIdTopic}'); // Fallback for mapping

                            NavigationUtils.navigateTo(
                              context,
                              '/admin/devicegraph',
                              arguments: {
                                'deviceName': sensorName ?? device.deviceId,
                                'sequentialName': mapping.category,
                                'backgroundImagePath': 'assets/backgroundd.jpg',
                              },
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.show_chart,
                                  color: Colors.blueAccent, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "View Graph",
                                style: TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded, color: subtle)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Divider(color: Colors.black12, height: 1),
              ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Metric Cards Grid
                      LayoutBuilder(builder: (context, constraints) {
                        final isMobile = constraints.maxWidth <= 600;
                        final spacing = isMobile ? 8.0 : 10.0;
                        final crossAxisCount =
                            isMobile ? 2 : (constraints.maxWidth > 800 ? 4 : 2);
                        final childAspectRatio = isMobile
                            ? 1.5
                            : (constraints.maxWidth > 800 ? 2.0 : 1.8);

                        final dialogCards = [
                          _buildDialogStatCard(
                            title: 'HEALTH SCORE',
                            value: '${device.healthScore} / 100',
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFF6366F1),
                            subtitle: _buildStatusBadge(device.healthStatus,
                                isSmall: true),
                            isDark: isDark,
                            width: 0,
                          ),
                          _buildDialogStatCard(
                            title: 'BATTERY',
                            value:
                                '${device.batteryVoltage.toStringAsFixed(2)} V (${_voltageToPercentage(device.batteryVoltage).toStringAsFixed(2)}%)',
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFF10B981),
                            subtitle: Text(
                              device.batteryStatus.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(device.batteryStatus),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            isDark: isDark,
                            width: 0,
                            isHighlighted: true,
                          ),
                          _buildDialogStatCard(
                            title: 'SIGNAL STRENGTH',
                            value: '${device.signalDbm} dBm',
                            icon: Icons.sensors_rounded,
                            color: const Color(0xFFF59E0B),
                            subtitle: Text(
                              device.signalStatus.toUpperCase(),
                              style: TextStyle(
                                color: _getStatusColor(device.signalStatus),
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            isDark: isDark,
                            width: 0,
                          ),
                          _buildDialogStatCard(
                            title: 'LAST SEEN',
                            value: _formatLastActive(device.lastActiveMinsAgo),
                            icon: Icons.history_toggle_off_rounded,
                            color: const Color(0xFF94A3B8),
                            subtitle: Text(
                              'SD: ${device.sdCardMounted ? "mounted" : "failed"}',
                              style: TextStyle(
                                color: device.sdCardMounted
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            isDark: isDark,
                            width: 0,
                          ),
                          _buildDialogStatCard(
                            title: 'AVG COMPLETENESS (7D)',
                            value:
                                '${device.avgCompleteness7d.toStringAsFixed(1)}%',
                            icon: Icons.analytics_rounded,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                            width: 0,
                          ),
                          _buildDialogStatCard(
                            title: 'MISSING (7D)',
                            value: device.totalMissing7d.toString(),
                            icon: Icons.assignment_late_rounded,
                            color: const Color(0xFFF43F5E),
                            isDark: isDark,
                            width: 0,
                          ),
                          _buildDialogStatCard(
                            title: 'DUPLICATES (7D)',
                            value: device.totalDuplicates7d.toString(),
                            icon: Icons.copy_rounded,
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                            width: 0,
                          ),
                          // _buildDialogStatCard(
                          //   title: 'BATTERY DRAINED (7 D)',
                          //   value:
                          //       '${device.batteryDrainage7d?.toString() ?? "0"}V',
                          //   icon: Icons.speed_rounded,
                          //   color: const Color(0xFF06B6D4),
                          //   isDark: isDark,
                          //   width: 0,
                          // ),
                        ];

                        return GridView.count(
                          crossAxisCount: crossAxisCount,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: childAspectRatio,
                          children: dialogCards,
                        );
                      }),

                      const SizedBox(height: 24),

                      // Missing Parameters
                      if (device.missingParameters.isNotEmpty) ...[
                        _buildDialogSectionTitle('MISSING PARAMETERS',
                            Icons.error_outline_rounded, isDark),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: device.missingParameters
                              .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                          color: Colors.redAccent
                                              .withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      p,
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Charts Section
                      LayoutBuilder(builder: (context, constraints) {
                        bool isNarrow = constraints.maxWidth < 700;

                        final completenessChart = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('7-day completeness %',
                                style: TextStyle(
                                    color: strong.withOpacity(0.8),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Container(
                                height: 200,
                                child: SfCartesianChart(
                                  margin: EdgeInsets.zero,
                                  plotAreaBorderWidth: 0,
                                  tooltipBehavior: TooltipBehavior(
                                    enable: true,
                                    builder: (dynamic data,
                                        dynamic point,
                                        dynamic series,
                                        int pointIndex,
                                        int seriesIndex) {
                                      final Map<String, dynamic> d =
                                          data as Map<String, dynamic>;
                                      final double pct =
                                          (d['pct'] as num).toDouble();

                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFF1E293B)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: strong.withOpacity(0.1)),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                            )
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Completeness: ${pct.toStringAsFixed(2)}%',
                                              style: TextStyle(
                                                color: strong,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  primaryXAxis: CategoryAxis(
                                    majorGridLines:
                                        const MajorGridLines(width: 0),
                                    axisLine: const AxisLine(
                                        width: 0.5, color: Colors.white24),
                                    labelStyle: const TextStyle(
                                        fontSize: 8, color: Colors.white54),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    minimum: 0,
                                    maximum: 100,
                                    interval: 20,
                                    majorGridLines: const MajorGridLines(
                                        width: 0.5, color: Colors.white10),
                                    axisLine: const AxisLine(width: 0),
                                    labelStyle: const TextStyle(
                                        fontSize: 8, color: Colors.white54),
                                  ),
                                  series: <CartesianSeries>[
                                    ColumnSeries<Map<String, dynamic>, String>(
                                      enableTooltip: true,
                                      dataSource: device.dailyCompleteness,
                                      xValueMapper:
                                          (Map<String, dynamic> data, _) =>
                                              DateFormat('MM/dd').format(
                                                  DateTime.parse(data['date'])),
                                      yValueMapper:
                                          (Map<String, dynamic> data, _) =>
                                              (data['pct'] as num).toDouble(),
                                      pointColorMapper:
                                          (Map<String, dynamic> data, _) {
                                        double pct =
                                            (data['pct'] as num).toDouble();
                                        if (pct > 80)
                                          return Colors.greenAccent
                                              .withOpacity(0.7);
                                        if (pct > 50)
                                          return Colors.orangeAccent
                                              .withOpacity(0.7);
                                        return Colors.redAccent
                                            .withOpacity(0.7);
                                      },
                                      borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(4)),
                                    )
                                  ],
                                )),
                          ],
                        );

                        return completenessChart;
                      }),

                      const SizedBox(height: 32),
                      _buildDialogSectionTitle(
                          'DATA LOGS (7D)', Icons.list_alt_rounded, isDark),
                      const SizedBox(height: 12),
                      _buildDailyBreakdownTable(
                          device.dailyCompleteness, isDark),
                    ],
                  ),
                ),
              ),

              // Footer - Fixed
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                    child: const Text('Close Diagnostics',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    required double width,
    Widget? subtitle,
    required bool isDark,
    bool isHighlighted = false,
  }) {
    final strong = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor =
        isDark ? color.withOpacity(0.25) : Colors.black.withOpacity(0.06);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 180;
      final valFontSize = isMobile ? 14.0 : 18.0;
      final titleFontSize = isMobile ? 8.0 : 9.0;
      final iconSize = isMobile ? 10.0 : 12.0;

      return Container(
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withOpacity(isDark ? 0.15 : 0.1)
              : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? color : borderColor,
            width: isHighlighted ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? color.withOpacity(isDark ? 0.4 : 0.2)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: isHighlighted ? 15 : 10,
              offset: Offset(0, isHighlighted ? 6 : 4),
              spreadRadius: isHighlighted ? 1 : 0,
            ),
          ],
        ),
        child: Container(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.center, // Center content vertically
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      softWrap: true,
                      style: TextStyle(
                        color: strong.withOpacity(0.5),
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: isMobile ? 0.5 : 1.0,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                ],
              ),
              const SizedBox(height: 4), // Reduced from 8
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    color: strong,
                    fontSize: valFontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4), // Reduced from 6
                subtitle,
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDailyBreakdownTable(
      List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) return Container();
    final strong = isDark ? Colors.white : Colors.black;

    return LayoutBuilder(builder: (context, constraints) {
      // Calculate minimum width needed for columns (increased for extra columns and long labels)
      double minTableWidth = 1600;
      // Use parent width OR minTableWidth, whichever is larger
      double availableWidth =
          MediaQuery.of(context).size.width.clamp(400.0, 800.0) -
              48; // -48 for dialog padding (24*2)
      double tableWidth =
          availableWidth > minTableWidth ? availableWidth : minTableWidth;

      return Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withOpacity(0.2)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: strong.withOpacity(0.05)),
        ),
        child: Scrollbar(
          controller: _diagHorizontalController,
          thumbVisibility: true,
          thickness: 3,
          radius: const Radius.circular(3),
          child: SingleChildScrollView(
            controller: _diagHorizontalController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  IntrinsicHeight(
                    child: Container(
                      decoration: BoxDecoration(
                        color: strong.withOpacity(0.05),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompactCell(
                              label: 'DATE',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactCell(
                              label: 'MISSING',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactCell(
                              label: 'RECEIVED',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactCell(
                              label: 'UNIQUE',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactCell(
                              label: 'EXPECTED',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactCell(
                              label: 'DUPLICATE',
                              flex: 2,
                              isDark: isDark,
                              showBorder: false),
                        ],
                      ),
                    ),
                  ),
                  // Rows
                  ...data.asMap().entries.map((entry) {
                    final index = entry.key;
                    final d = entry.value;
                    final rowColor = index % 2 == 1
                        ? (isDark
                            ? Colors.white.withOpacity(0.02)
                            : const Color(0xFFF8FAFC))
                        : Colors.transparent;

                    return IntrinsicHeight(
                      child: Container(
                        decoration: BoxDecoration(
                          color: rowColor,
                          border: Border(
                              top: BorderSide(color: strong.withOpacity(0.05))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CompactValueCell(
                                value: d['date']?.toString() ?? '-',
                                flex: 2,
                                isDark: isDark,
                                showBorder: true),
                            _CompactValueCell(
                                value: d['missing_count']?.toString() ?? '0',
                                flex: 2,
                                isDark: isDark,
                                showBorder: true,
                                color: (d['missing_count'] as num? ?? 0) > 0
                                    ? Colors.redAccent
                                    : null),
                            _CompactValueCell(
                                value: d['total_received']?.toString() ?? '0',
                                flex: 2,
                                isDark: isDark,
                                showBorder: true),
                            _CompactValueCell(
                                value: d['unique_received']?.toString() ?? '0',
                                flex: 2,
                                isDark: isDark,
                                showBorder: true),
                            _CompactValueCell(
                                value: d['expected_count']?.toString() ?? '0',
                                flex: 2,
                                isDark: isDark,
                                showBorder: true),
                            _CompactValueCell(
                                value: d['duplicate_count']?.toString() ?? '0',
                                flex: 2,
                                isDark: isDark,
                                showBorder: false),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildDialogSectionTitle(String title, IconData icon, bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                color: strong,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildDialogMetric(String label, String value, bool isDark,
      {bool isCritical = false}) {
    final strong = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: subtle, fontSize: 10)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: isCritical ? Colors.redAccent : strong,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) return Container();
    final strong = isDark ? Colors.white : Colors.black;

    return Container(
      height: 60,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map((d) {
          double pct = (d['pct'] as num).toDouble();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${d['date']}: $pct%',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: TextStyle(
                          color: strong.withOpacity(0.5),
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: (pct / 100 * 40).clamp(4, 40),
                      decoration: BoxDecoration(
                        color: (pct > 90
                                ? Colors.greenAccent
                                : (pct > 50
                                    ? Colors.orangeAccent
                                    : Colors.redAccent))
                            .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Public entry-point callable from any page (e.g. Admin Dashboard) ─────────
/// Fetches device health data for [deviceIdTopic] and shows the
/// same diagnostics dialog that the Health Status page shows.
Future<void> showDeviceHealthDetailDialog(
  BuildContext context,
  String deviceIdTopic,
  bool isDark,
) async {
  const _kApiUrl =
      'https://4p8k77fw8b.execute-api.us-east-1.amazonaws.com/default/IoT_Health_API';

  // Show loading spinner
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent)),
  );

  try {
    final response = await http.get(
      Uri.parse(_kApiUrl)
          .replace(queryParameters: {'deviceId_topic': deviceIdTopic}),
    );

    if (context.mounted) Navigator.pop(context); // close spinner

    if (response.statusCode == 200 && context.mounted) {
      final device = DeviceHealthData.fromJson(json.decode(response.body));
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.65),
        builder: (_) =>
            _HealthDetailDialogWidget(device: device, isDark: isDark),
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load device diagnostics.')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

// ── Standalone dialog widget ──────────────────────────────────────────────────
class _HealthDetailDialogWidget extends StatefulWidget {
  final DeviceHealthData device;
  final bool isDark;

  const _HealthDetailDialogWidget({required this.device, required this.isDark});

  @override
  State<_HealthDetailDialogWidget> createState() =>
      _HealthDetailDialogWidgetState();
}

class _HealthDetailDialogWidgetState extends State<_HealthDetailDialogWidget> {
  final ScrollController _diagHorizontalController = ScrollController();

  @override
  void dispose() {
    _diagHorizontalController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _getStatusColor(String status) {
    status = status.toLowerCase().trim();
    if (status == 'ok' || status == 'online' || status == 'mounted') {
      return const Color(0xFF10B981);
    }
    if (status == 'warning') return const Color(0xFFF59E0B);
    if (status == 'critical' || status == 'fail' || status == 'low') {
      return const Color(0xFFF43F5E);
    }
    if (status == 'offline') return const Color(0xFF94A3B8);
    return Colors.grey;
  }

  Widget _buildStatusBadge(String status, {bool isSmall = false}) {
    final color = _getStatusColor(status);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 6 : 8, vertical: isSmall ? 2 : 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmall ? 4 : 6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            color: color,
            fontSize: isSmall ? 8 : 10,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  double _voltageToPercentage(double voltage) {
    if (voltage <= 0) return 0.0;
    return ((voltage - 2.8) / (4.2 - 2.8) * 100).clamp(0.0, 100.0);
  }

  String _formatLastActive(int mins) {
    if (mins < 60) return '${mins}m ago';
    if (mins < 1440) {
      final h = mins / 60.0;
      return '${h.toStringAsFixed(h >= 10 ? 0 : 1)}h ago';
    }
    final d = mins / 1440.0;
    return '${d.toStringAsFixed(d >= 10 ? 0 : 1)}d ago';
  }

  Widget _buildDialogSectionTitle(String title, IconData icon, bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    return Row(children: [
      Icon(icon, size: 16, color: Colors.blueAccent),
      const SizedBox(width: 8),
      Text(title,
          style: TextStyle(
              color: strong,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5)),
    ]);
  }

  Widget _buildDialogStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
    Widget? subtitle,
    required bool isDark,
    bool isHighlighted = false,
  }) {
    final strong = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final borderColor =
        isDark ? color.withOpacity(0.25) : Colors.black.withOpacity(0.06);

    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 180;
      final valFontSize = isMobile ? 14.0 : 18.0;
      final titleFontSize = isMobile ? 8.0 : 9.0;
      final iconSize = isMobile ? 10.0 : 12.0;

      return Container(
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withOpacity(isDark ? 0.15 : 0.1)
              : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted ? color : borderColor,
            width: isHighlighted ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? color.withOpacity(isDark ? 0.4 : 0.2)
                  : Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: isHighlighted ? 15 : 10,
              offset: Offset(0, isHighlighted ? 6 : 4),
              spreadRadius: isHighlighted ? 1 : 0,
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                        softWrap: true,
                        style: TextStyle(
                            color: strong.withOpacity(0.5),
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w800,
                            letterSpacing: isMobile ? 0.5 : 1.0)),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: TextStyle(
                        color: strong,
                        fontSize: valFontSize,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                subtitle,
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDailyBreakdownTable(
      List<Map<String, dynamic>> data, bool isDark) {
    if (data.isEmpty) return const SizedBox.shrink();
    final strong = isDark ? Colors.white : Colors.black;
    const double minTableWidth = 1600;
    final double availableWidth =
        MediaQuery.of(context).size.width.clamp(400.0, 800.0) - 48;
    final double tableWidth =
        availableWidth > minTableWidth ? availableWidth : minTableWidth;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: strong.withOpacity(0.05)),
      ),
      child: Scrollbar(
        controller: _diagHorizontalController,
        thumbVisibility: true,
        thickness: 3,
        radius: const Radius.circular(3),
        child: SingleChildScrollView(
          controller: _diagHorizontalController,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Container(
                    decoration: BoxDecoration(
                      color: strong.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CompactCell(
                            label: 'DATE',
                            flex: 2,
                            isDark: isDark,
                            showBorder: true),
                        _CompactCell(
                            label: 'MISSING',
                            flex: 2,
                            isDark: isDark,
                            showBorder: true),
                        _CompactCell(
                            label: 'RECEIVED',
                            flex: 2,
                            isDark: isDark,
                            showBorder: true),
                        _CompactCell(
                            label: 'UNIQUE',
                            flex: 2,
                            isDark: isDark,
                            showBorder: true),
                        _CompactCell(
                            label: 'EXPECTED',
                            flex: 2,
                            isDark: isDark,
                            showBorder: true),
                        _CompactCell(
                            label: 'DUPLICATE',
                            flex: 2,
                            isDark: isDark,
                            showBorder: false),
                      ],
                    ),
                  ),
                ),
                ...data.asMap().entries.map((entry) {
                  final index = entry.key;
                  final d = entry.value;
                  final rowColor = index % 2 == 1
                      ? (isDark
                          ? Colors.white.withOpacity(0.02)
                          : const Color(0xFFF8FAFC))
                      : Colors.transparent;
                  return IntrinsicHeight(
                    child: Container(
                      decoration: BoxDecoration(
                        color: rowColor,
                        border: Border(
                            top: BorderSide(color: strong.withOpacity(0.05))),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CompactValueCell(
                              value: d['date']?.toString() ?? '-',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactValueCell(
                              value: d['missing_count']?.toString() ?? '0',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true,
                              color: (d['missing_count'] as num? ?? 0) > 0
                                  ? Colors.redAccent
                                  : null),
                          _CompactValueCell(
                              value: d['total_received']?.toString() ?? '0',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactValueCell(
                              value: d['unique_records']?.toString() ?? '0',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactValueCell(
                              value: d['expected_records']?.toString() ?? '0',
                              flex: 2,
                              isDark: isDark,
                              showBorder: true),
                          _CompactValueCell(
                              value: d['duplicate_count']?.toString() ?? '0',
                              flex: 2,
                              isDark: isDark,
                              showBorder: false,
                              color: (d['duplicate_count'] as num? ?? 0) > 0
                                  ? Colors.orangeAccent
                                  : null),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final isDark = widget.isDark;
    final strong = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        width: MediaQuery.of(context).size.width.clamp(400.0, 1100.0),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161A22) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: strong.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.displayName,
                          style: TextStyle(
                              color: strong,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5)),
                      if (device.location != 'Unknown') ...[
                        const SizedBox(height: 2),
                        Text(device.location,
                            style: TextStyle(
                                color: subtle,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          String? sensorName =
                              DevicePrefixUtils.getSensorNameFromTopic(
                                  device.deviceIdTopic);
                          if (sensorName == null &&
                              device.deviceIdTopic.contains('WS/SSMet_0126')) {
                            sensorName = 'WJ${device.deviceId.padLeft(3, '0')}';
                          }
                          final mapping =
                              DevicePrefixUtils.mapCategoryAndPrefix(
                                  device.deviceIdTopic.contains('WS/SSMet_0126')
                                      ? device.deviceIdTopic
                                      : '0#${device.deviceIdTopic}');
                          NavigationUtils.navigateTo(
                            context,
                            '/admin/devicegraph',
                            arguments: {
                              'deviceName': sensorName ?? device.deviceId,
                              'sequentialName': mapping.category,
                              'backgroundImagePath': 'assets/backgroundd.jpg',
                            },
                          );
                        },
                        child: Row(children: [
                          const Icon(Icons.show_chart,
                              color: Colors.blueAccent, size: 14),
                          const SizedBox(width: 4),
                          Text('View Graph',
                              style: const TextStyle(
                                  color: Colors.blueAccent,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline)),
                        ]),
                      ),
                    ],
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: subtle)),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Divider(color: Colors.black12, height: 1),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Metric cards
                    LayoutBuilder(builder: (context, constraints) {
                      final isMobile = constraints.maxWidth <= 600;
                      final spacing = isMobile ? 8.0 : 10.0;
                      final crossAxisCount =
                          isMobile ? 2 : (constraints.maxWidth > 800 ? 4 : 2);
                      final childAspectRatio = isMobile
                          ? 1.5
                          : (constraints.maxWidth > 800 ? 2.0 : 1.8);

                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: spacing,
                        crossAxisSpacing: spacing,
                        childAspectRatio: childAspectRatio,
                        children: [
                          _buildDialogStatCard(
                            title: 'HEALTH SCORE',
                            value: '${device.healthScore} / 100',
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFF6366F1),
                            subtitle: _buildStatusBadge(device.healthStatus,
                                isSmall: true),
                            isDark: isDark,
                          ),
                          _buildDialogStatCard(
                            title: 'BATTERY',
                            value:
                                '${device.batteryVoltage.toStringAsFixed(2)} V (${_voltageToPercentage(device.batteryVoltage).toStringAsFixed(2)}%)',
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFF10B981),
                            subtitle: Text(
                              device.batteryStatus.toUpperCase(),
                              style: TextStyle(
                                  color: _getStatusColor(device.batteryStatus),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                            isDark: isDark,
                            isHighlighted: true,
                          ),
                          _buildDialogStatCard(
                            title: 'SIGNAL STRENGTH',
                            value: '${device.signalDbm} dBm',
                            icon: Icons.sensors_rounded,
                            color: const Color(0xFFF59E0B),
                            subtitle: Text(
                              device.signalStatus.toUpperCase(),
                              style: TextStyle(
                                  color: _getStatusColor(device.signalStatus),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                            isDark: isDark,
                          ),
                          _buildDialogStatCard(
                            title: 'LAST SEEN',
                            value: _formatLastActive(device.lastActiveMinsAgo),
                            icon: Icons.history_toggle_off_rounded,
                            color: const Color(0xFF94A3B8),
                            subtitle: Text(
                              'SD: ${device.sdCardMounted ? "mounted" : "failed"}',
                              style: TextStyle(
                                  color: device.sdCardMounted
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                            isDark: isDark,
                          ),
                          _buildDialogStatCard(
                            title: 'AVG COMPLETENESS (7D)',
                            value:
                                '${device.avgCompleteness7d.toStringAsFixed(1)}%',
                            icon: Icons.analytics_rounded,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                          _buildDialogStatCard(
                            title: 'MISSING (7D)',
                            value: device.totalMissing7d.toString(),
                            icon: Icons.assignment_late_rounded,
                            color: const Color(0xFFF43F5E),
                            isDark: isDark,
                          ),
                          _buildDialogStatCard(
                            title: 'DUPLICATES (7D)',
                            value: device.totalDuplicates7d.toString(),
                            icon: Icons.copy_rounded,
                            color: const Color(0xFFF59E0B),
                            isDark: isDark,
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 24),
                    if (device.missingParameters.isNotEmpty) ...[
                      _buildDialogSectionTitle('MISSING PARAMETERS',
                          Icons.error_outline_rounded, isDark),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: device.missingParameters
                            .map((p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                        color:
                                            Colors.redAccent.withOpacity(0.2)),
                                  ),
                                  child: Text(p,
                                      style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (device.dailyCompleteness.isNotEmpty) ...[
                      // 7-day completeness chart
                      _buildDialogSectionTitle('7-DAY COMPLETENESS',
                          Icons.bar_chart_rounded, isDark),
                      const SizedBox(height: 12),
                      LayoutBuilder(builder: (ctx, constraints) {
                        final strong = isDark ? Colors.white : Colors.black;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '7-day completeness %',
                              style: TextStyle(
                                  color: strong.withOpacity(0.8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 200,
                              child: SfCartesianChart(
                                margin: EdgeInsets.zero,
                                plotAreaBorderWidth: 0,
                                tooltipBehavior: TooltipBehavior(
                                  enable: true,
                                  builder: (dynamic data,
                                      dynamic point,
                                      dynamic series,
                                      int pointIndex,
                                      int seriesIndex) {
                                    final Map<String, dynamic> d =
                                        data as Map<String, dynamic>;
                                    final double pct =
                                        (d['pct'] as num).toDouble();
                                    return Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF1E293B)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: strong.withOpacity(0.1)),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.2),
                                            blurRadius: 4,
                                          )
                                        ],
                                      ),
                                      child: Text(
                                        'Completeness: ${pct.toStringAsFixed(2)}%',
                                        style: TextStyle(
                                            color: strong,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12),
                                      ),
                                    );
                                  },
                                ),
                                primaryXAxis: CategoryAxis(
                                  majorGridLines:
                                      const MajorGridLines(width: 0),
                                  axisLine: const AxisLine(
                                      width: 0.5, color: Colors.white24),
                                  labelStyle: const TextStyle(
                                      fontSize: 8, color: Colors.white54),
                                ),
                                primaryYAxis: NumericAxis(
                                  minimum: 0,
                                  maximum: 100,
                                  interval: 20,
                                  majorGridLines: const MajorGridLines(
                                      width: 0.5, color: Colors.white10),
                                  axisLine: const AxisLine(width: 0),
                                  labelStyle: const TextStyle(
                                      fontSize: 8, color: Colors.white54),
                                ),
                                series: <CartesianSeries>[
                                  ColumnSeries<Map<String, dynamic>, String>(
                                    enableTooltip: true,
                                    dataSource: device.dailyCompleteness,
                                    xValueMapper:
                                        (Map<String, dynamic> data, _) =>
                                            DateFormat('MM/dd').format(
                                                DateTime.parse(data['date'])),
                                    yValueMapper:
                                        (Map<String, dynamic> data, _) =>
                                            (data['pct'] as num).toDouble(),
                                    pointColorMapper:
                                        (Map<String, dynamic> data, _) {
                                      final pct =
                                          (data['pct'] as num).toDouble();
                                      if (pct > 80)
                                        return Colors.greenAccent
                                            .withOpacity(0.7);
                                      if (pct > 50)
                                        return Colors.orangeAccent
                                            .withOpacity(0.7);
                                      return Colors.redAccent.withOpacity(0.7);
                                    },
                                    borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        topRight: Radius.circular(4)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 32),
                      // Data logs table
                      _buildDialogSectionTitle(
                          'DATA LOGS (7D)', Icons.list_alt_rounded, isDark),
                      const SizedBox(height: 12),
                      _buildDailyBreakdownTable(
                          device.dailyCompleteness, isDark),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      device.isDetailed
                          ? ''
                          : 'Note: Tap "View Graph" for detailed telemetry.',
                      style: TextStyle(
                          color: subtle,
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: const Text('Close Diagnostics',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final double value;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final String? subtitle;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isSelected,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = color.withOpacity(0.3);
    final cardBg = isSelected ? color.withOpacity(0.15) : Colors.transparent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.6) : borderColor,
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(height: 3, width: double.infinity, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withOpacity(0.2)
                              : color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black54,
                                fontWeight: FontWeight.w900,
                                fontSize: 9,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                if (subtitle != null) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      subtitle!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected
                                            ? (isDark
                                                ? Colors.white70
                                                : Colors.black54)
                                            : (isDark
                                                ? Colors.white30
                                                : Colors.black26),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final double width;
  final int flex;
  final bool isExpanded;
  final bool isDark;
  final bool showBorder;
  final String? filterValue;
  final List<String>? filterOptions;
  final Function(String?)? onFilterChanged;

  const _HeaderCell({
    required this.label,
    required this.width,
    this.flex = 1,
    this.isExpanded = false,
    this.isDark = true,
    this.showBorder = true,
    this.filterValue,
    this.filterOptions,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final strong = isDark ? Colors.white : Colors.black87;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
      decoration: BoxDecoration(
        border:
            showBorder ? Border(right: BorderSide(color: borderColor)) : null,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? strong.withOpacity(0.5)
                    : const Color(0xFF1976D2).withOpacity(0.8),
                fontSize: isExpanded ? 11 : 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            if (filterOptions != null) ...[
              const SizedBox(height: 4),
              Theme(
                data: Theme.of(context).copyWith(
                  canvasColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.black12,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: filterValue,
                      isDense: true,
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 16,
                        color: strong.withOpacity(0.6),
                      ),
                      style: TextStyle(
                        color: strong.withOpacity(0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      items: filterOptions!.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: onFilterChanged,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    if (isExpanded) {
      return Expanded(flex: flex, child: content);
    } else {
      return SizedBox(width: width, child: content);
    }
  }
}

class _DataCell extends StatelessWidget {
  final Widget child;
  final double width;
  final int flex;
  final bool isExpanded;
  final bool showBorder;
  final bool isDark;

  const _DataCell({
    required this.child,
    required this.width,
    this.flex = 1,
    this.isExpanded = false,
    this.showBorder = true,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.06);

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
      decoration: BoxDecoration(
        border:
            showBorder ? Border(right: BorderSide(color: borderColor)) : null,
      ),
      child: Center(child: child),
    );

    if (isExpanded) {
      return Expanded(flex: flex, child: content);
    } else {
      return SizedBox(width: width, child: content);
    }
  }
}

class _CompactCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool isDark;
  final bool showBorder;

  const _CompactCell({
    required this.label,
    this.flex = 1,
    this.isDark = true,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          border:
              showBorder ? Border(right: BorderSide(color: borderColor)) : null,
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2, // Reduced letter spacing to save space
            ),
            overflow: TextOverflow.visible,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

class _CompactValueCell extends StatelessWidget {
  final String value;
  final int flex;
  final bool isDark;
  final bool showBorder;
  final Color? color;
  final double fontSize;

  const _CompactValueCell({
    required this.value,
    this.flex = 1,
    required this.isDark,
    this.showBorder = true,
    this.color,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.06);

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: BoxDecoration(
          border:
              showBorder ? Border(right: BorderSide(color: borderColor)) : null,
        ),
        child: Center(
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color ?? (isDark ? Colors.white70 : Colors.black87),
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _QualityCheckDialog extends StatefulWidget {
  final String deviceId;
  final String deviceIdTopic;
  final String displayName;
  final bool isDark;

  const _QualityCheckDialog({
    required this.deviceId,
    required this.deviceIdTopic,
    required this.displayName,
    required this.isDark,
  });

  @override
  State<_QualityCheckDialog> createState() => _QualityCheckDialogState();
}

class _QualityCheckDialogState extends State<_QualityCheckDialog> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  final Set<String> _expandedDevices = {};
  List<DeviceQualityHistoryRecord> _records = [];
  String? _error;
  bool _showQualityIndex = true;
  String? _selectedGraphParam;
  String? _nextToken;
  bool _hasMore = false;

  static const Map<String, String> parameterDisplayNames = {
    "MaximumTemperature": "Maximum Temperature",
    "HumidityHourlyComulative": "Humidity Hourly Comulative",
    "AtmPressure": "Pressure",
    "AverageTemperature": "Average Temperature",
    "MaximumHumidity": "Maximum Humidity",
    "MinimumTemperature": "Minimum Temperature",
    "PressureHourlyComulative": "Pressure Hourly Comulative",
    "LightIntensity": "Light Intensity",
    "RainfallMinutly": "Rainfall Minutly",
    "CurrentTemperature": "Temperature",
    "WindDirection": "Wind Direction",
    "WindSpeed": "Wind Speed",
    "RainfallWeekly": "Rainfall Weekly",
    "RainfallDaily": "Rainfall Daily",
    "AverageHumidity": "Average Humidity",
    "BatteryVoltage": "Battery Voltage",
    "MinimumHumidity": "Minimum Humidity",
    "CurrentHumidity": "Humidity",
    "RainfallHourly": "Rainfall Hourly",
    "LuxHourlyComulative": "Lux Hourly Comulative",
    "TemperatureHourlyComulative": "Temperature Hourly Comulative",
    "SunshineHours": "Sunshine Hours",
    "PAR": "PAR",
    "UVRadiation": "UV Radiation",
    "SolarRadiation": "Solar Radiation",
  };

  static String _getDisplayName(String key) {
    if (parameterDisplayNames.containsKey(key)) {
      return parameterDisplayNames[key]!;
    }
    final lowerKey = key.toLowerCase();
    for (var entry in parameterDisplayNames.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return key;
  }

  @override
  void initState() {
    super.initState();
    _fetchQualityStatus();
  }

  Future<void> _fetchQualityStatus() async {
    try {
      final topic = widget.deviceIdTopic.split('#').last;
      final uri = Uri.https(
        'xj0wfbsjyi.execute-api.us-east-1.amazonaws.com',
        '/default/IoT_QC_Api_Func',
        {
          'device_id': widget.deviceId,
          'topic': topic,
          'history': 'true',
          'limit': '150',
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recordsJson = data['records'] ?? [];
        if (mounted) {
          setState(() {
            _records = recordsJson
                .map((r) => DeviceQualityHistoryRecord.fromJson(r))
                .toList();
            _nextToken = data['nextToken']?.toString();
            _hasMore = data['has_more'] == true;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
            'Failed to load quality history (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreHistory() async {
    if (_isLoadingMore || !_hasMore || _nextToken == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final topic = widget.deviceIdTopic.split('#').last;
      final uri = Uri.https(
        'xj0wfbsjyi.execute-api.us-east-1.amazonaws.com',
        '/default/IoT_QC_Api_Func',
        {
          'device_id': widget.deviceId,
          'topic': topic,
          'history': 'true',
          'limit': '150',
          'nextToken': _nextToken!,
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recordsJson = data['records'] ?? [];
        final newRecords = recordsJson
            .map((r) => DeviceQualityHistoryRecord.fromJson(r))
            .toList();

        if (mounted) {
          setState(() {
            _records.addAll(newRecords);
            _nextToken = data['nextToken']?.toString();
            _hasMore = data['has_more'] == true;
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strong = widget.isDark ? Colors.white : Colors.black87;
    final bgColor = widget.isDark ? const Color(0xFF14212B) : Colors.white;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 900), // Wider for graph
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quality Diagnostics',
                      style: TextStyle(
                        color: strong,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.displayName} (${widget.deviceId})',
                      style: TextStyle(
                        color: strong.withOpacity(0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close, color: strong.withOpacity(0.5)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 32),
            if (_isLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Color(0xFF1976D2)),
              ))
            else if (_error != null)
              Center(
                  child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent)),
              ))
            else if (_records.isNotEmpty)
              Flexible(
                  child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildQualityGraph(strong),
                    if (_hasMore) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: _isLoadingMore
                            ? const CircularProgressIndicator(strokeWidth: 2)
                            : ElevatedButton.icon(
                                onPressed: _fetchMoreHistory,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Load More Records'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Colors.blueAccent.withOpacity(0.1),
                                  foregroundColor: Colors.blueAccent,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ))
            else
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Text("No quality history found."),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityGraph(Color strong) {
    final allParams = <String>{};
    for (var r in _records) {
      allParams.addAll(r.rawSnapshot.keys);
    }
    // Filter out system parameters
    allParams.removeWhere((p) {
      final lp = p.toLowerCase();
      return lp.contains('battery') || lp.contains('signalstrength');
    });
    final paramsList = allParams.toList()..sort();

    if (_selectedGraphParam == null && paramsList.isNotEmpty) {
      _selectedGraphParam = paramsList.firstWhere(
        (p) =>
            p.toLowerCase().contains('temp') || p.toLowerCase().contains('hum'),
        orElse: () => paramsList.first,
      );
    }

    final chartData = _records
        .map((r) {
          DateTime time;
          try {
            time = DateFormat("yyyy-MM-dd HH:mm:ss").parse(r.timestamp);
          } catch (e) {
            time = DateTime.now();
          }

          double? value;
          Color pointColor;
          String pointStatus;

          if (_showQualityIndex) {
            final flag = r.overallFlag.toUpperCase();
            if (flag == 'GOOD')
              value = 3;
            else if (flag == 'SUSPECT')
              value = 2;
            else if (flag == 'ERRONEOUS')
              value = 1;
            else
              value = 0;
            pointColor = _getFlagColor(r.overallFlag);
            pointStatus = r.overallFlag;
          } else {
            final rawVal = r.rawSnapshot[_selectedGraphParam];
            value = double.tryParse(rawVal?.toString() ?? '');

            // Check individual field status
            final fieldStatus =
                r.flaggedFields[_selectedGraphParam]?.toString().toUpperCase();
            if (fieldStatus != null) {
              pointStatus = fieldStatus;
              pointColor = _getFlagColor(fieldStatus);
            } else {
              pointStatus = 'GOOD';
              pointColor = Colors.greenAccent;
            }
          }

          return _ChartData(
            time,
            value ?? 0,
            pointColor,
            pointStatus,
            r.flaggedFields,
          );
        })
        .toList()
        .reversed
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUALITY DIAGNOSTICS TREND',
                    style: TextStyle(
                      color: strong.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _showQualityIndex
                        ? 'Quality Level Trend'
                        : 'Parameter Trend',
                    style: TextStyle(
                      color: strong,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () =>
                  setState(() => _showQualityIndex = !_showQualityIndex),
              tooltip: _showQualityIndex
                  ? 'Show Parameter Graph'
                  : 'Show Quality Index',
              icon: Icon(
                _showQualityIndex
                    ? Icons.analytics_outlined
                    : Icons.verified_user_outlined,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
        if (!_showQualityIndex && paramsList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: strong.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<String>(
                isDense: true,
                value: _selectedGraphParam,
                underline: const SizedBox(),
                iconSize: 18,
                dropdownColor:
                    widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                style: TextStyle(
                    color: strong, fontSize: 10, fontWeight: FontWeight.w600),
                items: paramsList
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(_getDisplayName(p)),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedGraphParam = val),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 250,
          child: SfCartesianChart(
            margin: EdgeInsets.zero,
            plotAreaBorderWidth: 0,
            primaryXAxis: DateTimeAxis(
              majorGridLines: const MajorGridLines(width: 0),
              labelStyle:
                  TextStyle(color: strong.withOpacity(0.5), fontSize: 9),
              axisLine: AxisLine(color: strong.withOpacity(0.1)),
            ),
            primaryYAxis: NumericAxis(
              isVisible: true,
              labelStyle: _showQualityIndex
                  ? const TextStyle(color: Colors.transparent, fontSize: 0)
                  : TextStyle(color: strong.withOpacity(0.5), fontSize: 9),
              majorTickLines: _showQualityIndex
                  ? const MajorTickLines(size: 0)
                  : const MajorTickLines(),
              majorGridLines: MajorGridLines(
                  color: strong.withOpacity(0.05), dashArray: const [5, 5]),
              axisLine: const AxisLine(width: 0),
              minimum: _showQualityIndex ? -0.5 : null,
              maximum: _showQualityIndex ? 3.5 : null,
              interval: _showQualityIndex ? 1 : null,
            ),
            zoomPanBehavior: ZoomPanBehavior(
              enablePanning: true,
              enablePinching: true,
              enableMouseWheelZooming: true,
              zoomMode: ZoomMode.x,
            ),
            trackballBehavior: TrackballBehavior(
              enable: true,
              activationMode: ActivationMode.singleTap,
              tooltipSettings: const InteractiveTooltip(enable: false),
              lineType: TrackballLineType.vertical,
              lineColor: strong.withOpacity(0.3),
              lineWidth: 1,
            ),
            tooltipBehavior: TooltipBehavior(
              enable: true,
              header: '',
              canShowMarker: true,
              activationMode: ActivationMode.singleTap,
              builder: (dynamic data, dynamic point, dynamic series,
                  int pointIndex, int seriesIndex) {
                final _ChartData d = data;
                final statusColor = d.color;
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5)),
                    boxShadow: [
                      const BoxShadow(color: Colors.black26, blurRadius: 4)
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('dd MMM, HH:mm:ss').format(d.x),
                        style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: statusColor, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            d.flag.toUpperCase(),
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 12),
                          ),
                        ],
                      ),
                      if (_showQualityIndex && d.flaggedParams.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text('FLAGGED FIELDS:',
                            style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1)),
                        const SizedBox(height: 4),
                        ...d.flaggedParams.keys.take(5).map((k) => Text(
                              '• ${_getDisplayName(k)}',
                              style: TextStyle(
                                  color: statusColor.withOpacity(0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600),
                            )),
                        if (d.flaggedParams.length > 5)
                          Text('...and ${d.flaggedParams.length - 5} more',
                              style: const TextStyle(
                                  fontSize: 9, color: Colors.grey)),
                      ] else if (!_showQualityIndex) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Value: ${d.y.toStringAsFixed(2)}',
                          style: TextStyle(
                              color: strong,
                              fontWeight: FontWeight.w900,
                              fontSize: 13),
                        ),
                      ]
                    ],
                  ),
                );
              },
            ),
            series: <CartesianSeries<_ChartData, DateTime>>[
              LineSeries<_ChartData, DateTime>(
                dataSource: chartData,
                xValueMapper: (_ChartData data, _) => data.x,
                yValueMapper: (_ChartData data, _) => data.y,
                color: Colors.blueAccent.withOpacity(0.3),
                width: 2,
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 6,
                  width: 6,
                  shape: DataMarkerType.circle,
                  borderColor: Colors.transparent,
                ),
              ),
              ScatterSeries<_ChartData, DateTime>(
                dataSource: chartData,
                xValueMapper: (_ChartData data, _) => data.x,
                yValueMapper: (_ChartData data, _) => data.y,
                pointColorMapper: (_ChartData data, _) => data.color,
                markerSettings: const MarkerSettings(
                  isVisible: true,
                  height: 8,
                  width: 8,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildLegendItem('Good', Colors.greenAccent),
              _buildLegendItem('Suspect', Colors.orangeAccent),
              _buildLegendItem('Erroneous', Colors.redAccent),
              _buildLegendItem(
                  'Inconsistent', const Color.fromARGB(255, 209, 233, 114)),
              _buildLegendItem(
                  'Missing', const Color.fromARGB(255, 111, 223, 238)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 9, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getFlagColor(String flag) {
    flag = flag.toUpperCase();
    if (flag == 'GOOD') return Colors.greenAccent;
    if (flag == 'SUSPECT') return Colors.orangeAccent;
    if (flag == 'ERRONEOUS') return Colors.redAccent;
    if (flag == 'INCONSISTENT') return const Color.fromARGB(255, 209, 233, 114);
    if (flag == 'MISSING') return const Color.fromARGB(255, 111, 223, 238);
    return Colors.grey;
  }
}

class _ChartData {
  _ChartData(this.x, this.y, this.color, this.flag, this.flaggedParams);
  final DateTime x;
  final double y;
  final Color color;
  final String flag;
  final Map<String, dynamic> flaggedParams;
}

class DeviceQualityHistoryRecord {
  final String timestamp;
  final String overallFlag;
  final Map<String, dynamic> flaggedFields;
  final int intervalMin;
  final Map<String, dynamic> rawSnapshot;

  DeviceQualityHistoryRecord({
    required this.timestamp,
    required this.overallFlag,
    required this.flaggedFields,
    required this.intervalMin,
    required this.rawSnapshot,
  });

  factory DeviceQualityHistoryRecord.fromJson(Map<String, dynamic> json) {
    return DeviceQualityHistoryRecord(
      timestamp: json['timestamp']?.toString() ?? '',
      overallFlag: json['overall_flag']?.toString() ?? 'UNKNOWN',
      flaggedFields: Map<String, dynamic>.from(json['flagged_fields'] ?? {}),
      intervalMin: (json['interval_min'] as num?)?.toInt() ?? 0,
      rawSnapshot: Map<String, dynamic>.from(json['raw_snapshot'] ?? {}),
    );
  }
}
