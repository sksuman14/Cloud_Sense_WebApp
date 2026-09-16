import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/views/devices/manually_add_device.dart';
import 'package:cloud_sense_webapp/src/views/devices/qr_scan_add_device.dart';
import 'package:cloud_sense_webapp/src/widgets/appbar.dart';
import 'package:cloud_sense_webapp/src/widgets/drawer.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/widgets/device_action_button.dart';

// ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──

String _toAnnamDisplayName(String internalSensorName) =>
    DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

// ── Internal Helpers for prefixing ──
// (Unused helpers removed. Logic now handled via RegExp in _toAnnamDisplayName)

class DataDisplayPage extends StatefulWidget {
  @override
  _DataDisplayPageState createState() => _DataDisplayPageState();
}

class _DataDisplayPageState extends State<DataDisplayPage> {
  bool _isLoading = true;
  bool _isLoadingBattery = false;
  Map<String, List<String>> _deviceCategories = {};
  String? _email;
  late ScrollController _scrollController;
  String filter = "All";
  String searchQuery = "";
  Map<String, DateTime> _timestampMap = {};
  Map<String, List<String>> _parameterNamesMap = {};
  Map<String, bool> _hoverStates = {};
  Map<String, String> _locationMap = {};
  Map<String, String> _healthTopicLookupMap = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedDeviceIds = {};
  bool _isBatchDeleting = false;

  Future<void> _fetchHealthTopicLookup() async {
    try {
      final response = await http.get(Uri.parse(
          'https://4p8k77fw8b.execute-api.us-east-1.amazonaws.com/default/IoT_Health_API?limit=500'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> devices = data['devices'] ?? [];
        Map<String, String> lookup = {};
        for (var dev in devices) {
          final topicStr = (dev['deviceId_topic'] ?? dev['deviceid#topic'])?.toString() ?? '';
          final devId = dev['deviceId']?.toString() ?? '';
          if (topicStr.isNotEmpty) {
            final sensorName = DevicePrefixUtils.getSensorNameFromTopic(topicStr) ?? devId;
            final displaySensorName = _toAnnamDisplayName(sensorName);
            lookup[sensorName] = topicStr;
            lookup[displaySensorName] = topicStr;
            lookup[devId] = topicStr;
            if (sensorName.contains('_')) {
              lookup[sensorName.split('_').last] = topicStr;
            }
          }
        }
        if (mounted) {
          setState(() {
            _healthTopicLookupMap = lookup;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching health topic lookup: $e");
    }
  }

  Future<void> _deleteSelectedDevices() async {
    if (_selectedDeviceIds.isEmpty || _email == null) return;

    // Build a Map<prefix, List<deviceId>> filtered to only selected devices
    // so we can reuse the shared DeleteDeviceUtils.deleteDevices() dialog & logic.
    final Map<String, List<String>> selectedCategories = {};
    for (final entry in _deviceCategories.entries) {
      final selected =
          entry.value.where((id) => _selectedDeviceIds.contains(id)).toList();
      if (selected.isNotEmpty) {
        selectedCategories[entry.key] = selected;
      }
    }

    if (selectedCategories.isEmpty) return;

    // Show in-page loading banner while API calls are in progress
    setState(() => _isBatchDeleting = true);

    await DeleteDeviceUtils.deleteDevices(
      context,
      _email!,
      selectedCategories,
      (updatedCategories) {
        // Merge the deletions back into the full _deviceCategories map
        if (mounted) {
          setState(() {
            for (final entry in updatedCategories.entries) {
              _deviceCategories[entry.key] = entry.value;
            }
            _deviceCategories.removeWhere((_, v) => v.isEmpty);
            _isSelectionMode = false;
            _selectedDeviceIds.clear();
            _isBatchDeleting = false; // hide loading banner
          });
          _fetchData(); // full refresh after batch delete
        }
      },
    );

    // Also reset if user cancelled the dialog (confirmed == false)
    if (mounted && _isBatchDeleting) {
      setState(() => _isBatchDeleting = false);
    }
  }

  String? _getLocationForSensor(String sensorName) {
    final hardcoded = _hardcodedLocationMap[sensorName] ?? _hardcodedLocationMap[DevicePrefixUtils.getSensorNameFromTopic(sensorName) ?? ''];
    if (hardcoded != null) return hardcoded;

    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    final apiLocation = _locationMap[topic];
    if (apiLocation != null && apiLocation.isNotEmpty) return apiLocation;

    // Fallback for TS (Testing) sensors: Rupnagar, Punjab
    if (DevicePrefixUtils.isAnnamTestingSensor(sensorName)) {
      return 'Rupnagar, Punjab';
    }
    return null;
  }

  static const Map<String, String> _hardcodedLocationMap = {
    'WJ214': 'Dinanagar, Punjab',
    'ANNAM0126_214': 'Dinanagar, Punjab',
    'WJ240': 'Ghanauli, Rupnagar, Punjab',
    'WJ247': 'Kala Afgana, Gurdaspur, Punjab',
    'WJ276': 'Qadian, Gurdaspur, Punjab',
    'WA013': 'Gajansu Madh, Jammu and Kashmir',
    'WA027': 'Nandpur, Sambha, Jammu and Kashmir',
    'WJ224': 'Tarn Taran, Punjab',
    'WJ466': 'Dasuya, Hoshairpur, Punjab',
    'WJ080': 'Jaito, Faridkot, Punjab',
    'WJ231': 'Adampur, Jalandhar, Punjab',
    'WJ398': 'District Administration Complex, Sector 76, Mohali, Punjab',
    'IT100': 'IIT Bombay, Maharashtra',
    'SM003': 'Cachar, Assam',
    'SW003': 'Bhubaneswar (M.Corp.) P.S., Khordha district, Odisha',
    'GPS': 'Rupnagar, Punjab',
    'gps': 'Rupnagar, Punjab',
    'WJ221': 'Zira tehsil, Firozpur district, Punjab',
    'NA013': 'Hyderabad, Musheerabad mandal, Telangana',
    'WJ267': 'Sardulgarh tehsil, Mansa district, Punjab',
    'WA016': 'Hiranagar, Kathua, Jammu and Kashmir',
  };

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

  double getResponsiveFontSize(
      BuildContext context, double minSize, double maxSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    return screenWidth < 600 ? minSize : maxSize;
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadEmail();
    _loadTimestampMapFromApi();

    _searchController.addListener(() {
      setState(() {
        searchQuery = _searchController.text.trim();
      });
    });

    _deviceCategories.forEach((category, sensorList) {
      for (var sensor in sensorList) {
        _hoverStates[sensor] = false;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedEmail = prefs.getString('email');

    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      if (currentUser.username.trim().toLowerCase() ==
          "05agriculture.05@gmail.com") {
        NavigationUtils.navigateTo(context, '/deviceinfo', isReplacement: true);
        return;
      }
      setState(() {
        _email = savedEmail ?? currentUser.username;
      });
      _fetchData();
    } catch (e) {
      if (savedEmail != null && savedEmail.isNotEmpty) {
        if (savedEmail.trim().toLowerCase() == "05agriculture.05@gmail.com") {
          NavigationUtils.navigateTo(context, '/deviceinfo',
              isReplacement: true);
          return;
        }
        setState(() {
          _email = savedEmail;
        });
        _fetchData();
      } else {
        await Amplify.Auth.signOut();
        await prefs.clear();
        NavigationUtils.navigateTo(
          context,
          '/login',
          removeUntil: true,
        );
      }
    }
  }

  Future<void> _fetchData() async {
    if (_email == null) return;
    _fetchHealthTopicLookup();

    final url =
        'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$_email';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        Map<String, List<String>> groupedDevices = {};

        if (result is Map<String, dynamic>) {
          result.forEach((key, value) {
            if (key != 'device_id' && key != 'email_id' && value != null) {
              String category = _mapCategory(key);
              if (key == 'LU' || key == 'TE' || key == 'AC') {
                category = 'CPS Lab Sensors';
              }
              groupedDevices.putIfAbsent(category, () => []);

              if (value is List) {
                for (var v in value) {
                  final devStr = v.toString().trim();
                  if (devStr.isNotEmpty && !groupedDevices[category]!.contains(devStr)) {
                    groupedDevices[category]!.add(devStr);
                  }
                }
              } else if (value is String && value.isNotEmpty) {
                if (!groupedDevices[category]!.contains(value)) {
                  groupedDevices[category]!.add(value);
                }
              }
            }
          });
        } else if (result is List) {
          for (var item in result) {
            if (item is Map) {
              item.forEach((key, value) {
                if (key != 'device_id' && key != 'email_id' && value != null) {
                  String category = _mapCategory(key.toString());
                  groupedDevices.putIfAbsent(category, () => []);
                  if (value is List) {
                    for (var v in value) {
                      final devStr = v.toString().trim();
                      if (devStr.isNotEmpty && !groupedDevices[category]!.contains(devStr)) {
                        groupedDevices[category]!.add(devStr);
                      }
                    }
                  } else if (value is String && value.isNotEmpty) {
                    if (!groupedDevices[category]!.contains(value)) {
                      groupedDevices[category]!.add(value);
                    }
                  }
                }
              });
            }
          }
        }

        setState(() {
          _deviceCategories = groupedDevices;
        });
      }
    } catch (error) {
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _mapCategory(String key) {
    return DevicePrefixUtils.getCategoryDisplayName(key);
  }



  Future<void> _loadTimestampMapFromApi() async {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];

    final excludedParams = {
      'Longitude',
      'Latitude',
      'IMEINumber',
      'SignalStrength',
      'ExpiresAt',
      'Topic'
    };

    setState(() => _isLoadingBattery = true);

    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching timestamps $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      Map<String, DateTime> tempMap = {};
      Map<String, List<String>> paramNamesMap = {};

      for (var response in responses) {
        if (response.statusCode != 200) continue;

        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> devices = jsonResponse['devices'] ?? [];

        for (var item in devices) {
          final rawTopic =
              (item['deviceid#topic'] ?? item['deviceId#topic'] ?? '')
                  .toString();
          if (rawTopic.isEmpty) continue;

          String ts = (item['TimeStamp_IST'] ?? '').toString();
          if (rawTopic.toLowerCase().contains('jio_logger') ||
              rawTopic.toLowerCase().contains('/jw')) {
            final mqttTime = item['MQTT_TopicTime'] ?? item['mqtt_topic_time'];
            if (mqttTime != null && mqttTime.toString().isNotEmpty) {
              ts = mqttTime.toString();
            }
          }
          if (ts.isEmpty) continue;

          final timestamp = parseTimestamp(ts);
          if (timestamp != null) {
            final key = rawTopic.toLowerCase();

            if (tempMap.containsKey(key)) {
              if (timestamp.isAfter(tempMap[key]!)) {
                tempMap[key] = timestamp;
                paramNamesMap[key] = [];
                final city = (item['City'] ?? '').toString().trim();
                final district = (item['District'] ?? '').toString().trim();
                final state = (item['State'] ?? '').toString().trim();
                final parts = {
                  if (city.isNotEmpty) city,
                  if (district.isNotEmpty) district,
                  if (state.isNotEmpty) state
                }.toList();
                if (parts.isNotEmpty) _locationMap[key] = parts.join(', ');
                item.forEach((k, v) {
                  if (v != null &&
                      k != 'deviceid#topic' &&
                      k != 'TimeStamp_IST' &&
                      !excludedParams.contains(k)) {
                    paramNamesMap[key]!.add(k);
                  }
                });
              }
            } else {
              tempMap[key] = timestamp;
              paramNamesMap[key] = [];
              final city = (item['City'] ?? '').toString().trim();
              final district = (item['District'] ?? '').toString().trim();
              final state = (item['State'] ?? '').toString().trim();
              final parts = {
                if (city.isNotEmpty) city,
                if (district.isNotEmpty) district,
                if (state.isNotEmpty) state
              }.toList();
              if (parts.isNotEmpty) _locationMap[key] = parts.join(', ');
              item.forEach((k, v) {
                if (v != null &&
                    k != 'deviceid#topic' &&
                    k != 'TimeStamp_IST' &&
                    !excludedParams.contains(k)) {
                  paramNamesMap[key]!.add(k);
                }
              });
            }
          }
        }
      }

      setState(() {
        _timestampMap = tempMap;
        _parameterNamesMap = paramNamesMap;
        _isLoadingBattery = false;
      });
    } catch (e) {
      print('Error loading timestamps: $e');
      setState(() => _isLoadingBattery = false);
    }
  }

  DateTime? parseTimestamp(String ts) {
    ts = ts.trim();
    try {
      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(ts)) {
        final year = int.parse(ts.substring(0, 4));
        final month = int.parse(ts.substring(4, 6));
        final day = int.parse(ts.substring(6, 8));
        final hour = int.parse(ts.substring(9, 11));
        final minute = int.parse(ts.substring(11, 13));
        final second = int.parse(ts.substring(13, 15));
        return DateTime(year, month, day, hour, minute, second);
      } else if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(ts)) {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(ts, true).toLocal();
      } else if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(ts)) {
        return DateFormat('dd-MM-yyyy HH:mm:ss').parse(ts, true).toLocal();
      }
    } catch (e) {
      print('Timestamp parse error for $ts: $e');
    }
    return null;
  }

  String buildTopicFromSensorName(String sensorName) =>
      DevicePrefixUtils.buildTopicFromSensorName(sensorName);

  Color getDotColorForSensor(String sensorName) {
    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    final timestamp = _timestampMap[topic];
    if (timestamp == null) return Colors.red;
    final now = DateTime.now();
    final diff = now.difference(timestamp.toLocal());
    return diff.inMinutes <= 11 ? Colors.green : Colors.red;
  }

  List<String> getParamNamesForSensor(String sensorName) {
    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    return _parameterNamesMap[topic] ?? [];
  }

  List<Map<String, dynamic>> _getAllDevicesList() {
    List<Map<String, dynamic>> devices = [];

    _deviceCategories.forEach((category, sensorList) {
      for (var sensor in sensorList) {
        final topic = buildTopicFromSensorName(sensor);
        final timestamp = _timestampMap[topic.toLowerCase()];
        bool isActive = timestamp != null &&
            DateTime.now().difference(timestamp.toLocal()).inMinutes <= 11;

        devices.add({
          'DeviceId': sensor,
          'Topic': topic,
          'isActive': isActive,
          'lastReceivedTime': timestamp != null
              ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toLocal())
              : 'N/A',
          'Category': category,
        });
      }
    });
    return devices;
  }

  List<Map<String, dynamic>> get filteredDevices {
    List<Map<String, dynamic>> devices = _getAllDevicesList();

    if (filter == "Active") {
      devices = devices.where((d) => d['isActive'] == true).toList();
    } else if (filter == "Inactive") {
      devices = devices.where((d) => d['isActive'] == false).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      devices = devices.where((d) {
        final deviceId = (d['DeviceId'] as String?)?.toLowerCase() ?? '';
        final category = (d['Category'] as String?)?.toLowerCase() ?? '';
        final displayId =
            _toAnnamDisplayName(d['DeviceId'] ?? '').toLowerCase();
        final location =
            _getLocationForSensor(d['DeviceId'] ?? '')?.toLowerCase() ?? '';
        return deviceId.contains(query) ||
            category.contains(query) ||
            displayId.contains(query) ||
            location.contains(query);
      }).toList();
    }

    int naturalCompare(String a, String b) {
      final regExp = RegExp(r'(\d+|\D+)');
      final matchesA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
      final matchesB = regExp.allMatches(b).map((m) => m.group(0)!).toList();

      final len = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
      for (int i = 0; i < len; i++) {
        final partA = matchesA[i];
        final partB = matchesB[i];
        final numA = int.tryParse(partA);
        final numB = int.tryParse(partB);

        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = partA.compareTo(partB);
          if (cmp != 0) return cmp;
        }
      }
      return matchesA.length.compareTo(matchesB.length);
    }

    int getSortRank(Map<String, dynamic> d) {
      final deviceId = (d['DeviceId'] ?? "").toString();
      final topic = (d['Topic'] ?? "").toString();
      final sn = DevicePrefixUtils.resolveSensorName(deviceId, topic);
      final dn = _toAnnamDisplayName(sn).toUpperCase();
      final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);
      final isActive = d['isActive'] == true;

      final isKerala = mapped.prefix == 'KR' ||
          sn.startsWith('KR') ||
          topic.toLowerCase().contains('kerala');
      final isPunjab = mapped.prefix == 'PJ' ||
          sn.startsWith('PJ') ||
          topic.toLowerCase().contains('punjab');
      final isAnnam = DevicePrefixUtils.isAnnamCoreSensor(sn) || dn.startsWith('ANNAM');

      // === ACTIVE SENSORS FIRST ===
      // 1. Kerala ANNAM sensors (Active)
      if (isAnnam && isKerala && isActive) return 0;

      // 2. Punjab ANNAM sensors (Active)
      if (isAnnam && isPunjab && isActive) return 1;

      // 3. Other ANNAM sensors (Active)
      if (isAnnam && isActive) return 2;

      // 4. Non-ANNAM sensors (Active)
      if (!isAnnam && isActive) return 3;

      // === INACTIVE SENSORS LAST ===
      // 5. Kerala ANNAM sensors (Inactive)
      if (isAnnam && isKerala && !isActive) return 4;

      // 6. Punjab ANNAM sensors (Inactive)
      if (isAnnam && isPunjab && !isActive) return 5;

      // 7. Other ANNAM sensors (Inactive)
      if (isAnnam && !isActive) return 6;

      // 8. Non-ANNAM sensors (Inactive)
      return 7;
    }

    devices.sort((a, b) {
      final rankA = getSortRank(a);
      final rankB = getSortRank(b);
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      final deviceIdA = (a['DeviceId'] ?? "").toString();
      final topicA = (a['Topic'] ?? "").toString();
      final snA = DevicePrefixUtils.resolveSensorName(deviceIdA, topicA);
      final dnA = _toAnnamDisplayName(snA);

      final deviceIdB = (b['DeviceId'] ?? "").toString();
      final topicB = (b['Topic'] ?? "").toString();
      final snB = DevicePrefixUtils.resolveSensorName(deviceIdB, topicB);
      final dnB = _toAnnamDisplayName(snB);

      final nameCmp = naturalCompare(dnA, dnB);
      if (nameCmp != 0) return nameCmp;

      return topicA.compareTo(topicB);
    });

    return devices;
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 800;

    final allDevs = _getAllDevicesList();
    final activeCount = allDevs.where((d) => d['isActive'] == true).length;
    final inactiveCount = allDevs.where((d) => d['isActive'] == false).length;
    final totalCount = allDevs.length;

    final bg = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final card = isDarkMode
        ? const Color(0xFF1E293B)
        : Colors.white;
    final strong = isDarkMode
        ? const Color(0xFFF8FAFC)
        : const Color(0xFF0F172A);
    final subtle = isDarkMode
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final accent = const Color(0xFF0EA5E9);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBarWidget(),
      endDrawer: !isWideScreen ? const EndDrawerWidget() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.all(screenWidth < 600 ? 10.0 : 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _isSelectionMode
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  "${_selectedDeviceIds.length} Selected",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    final currentIds = filteredDevices
                                        .map((d) => d['DeviceId'] as String)
                                        .toSet();
                                    if (_selectedDeviceIds
                                        .containsAll(currentIds)) {
                                      _selectedDeviceIds.removeAll(currentIds);
                                    } else {
                                      _selectedDeviceIds.addAll(currentIds);
                                    }
                                  });
                                },
                                child: Text(
                                  _selectedDeviceIds.containsAll(
                                              filteredDevices.map((d) =>
                                                  d['DeviceId'] as String)) &&
                                          filteredDevices.isNotEmpty
                                      ? "Deselect All"
                                      : "Select All",
                                  style: TextStyle(
                                    color: subtle,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _selectedDeviceIds.isNotEmpty &&
                                        !_isBatchDeleting
                                    ? _deleteSelectedDevices
                                    : null,
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: Text(
                                    "Delete (${_selectedDeviceIds.length})"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      Colors.redAccent.withOpacity(0.3),
                                  disabledForegroundColor: Colors.white70,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _isSelectionMode = false;
                                    _selectedDeviceIds.clear();
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : Colors.black26),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text("Cancel",
                                    style: TextStyle(color: strong)),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Your Devices",
                            style: TextStyle(
                              color: strong,
                              fontSize: getResponsiveFontSize(context, 18, 22),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              if (allDevs.isNotEmpty) ...[
                                OutlinedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isSelectionMode = true;
                                      _selectedDeviceIds.clear();
                                    });
                                  },
                                  icon: Icon(Icons.checklist_rounded,
                                      size: 18, color: subtle),
                                  label: Text(
                                    "Manage",
                                    style: TextStyle(
                                      color: strong,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                        color: isDarkMode
                                            ? Colors.white24
                                            : Colors.black26),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              ElevatedButton(
                                onPressed: () =>
                                    _showAddDeviceDialog(context, strong),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                ),
                                child: const Text("Add Device"),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              if (_isBatchDeleting) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.redAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.redAccent),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Deleting selected devices...",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Top Metric Summary Cards (Total, Active, Inactive)
              _buildMetricSummaryCards(
                total: totalCount,
                active: activeCount,
                inactive: inactiveCount,
                isDarkMode: isDarkMode,
                strong: strong,
                subtle: subtle,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: strong),
                  decoration: InputDecoration(
                    hintText: "Search Device ID, Category, Location...",
                    hintStyle: TextStyle(color: subtle),
                    prefixIcon: Icon(Icons.search, color: subtle),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: subtle),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: card,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color:
                              isDarkMode ? Colors.white10 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white12
                              : Colors.black.withOpacity(0.05)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: accent, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _isLoading || _isLoadingBattery
                  ? const Center(child: CircularProgressIndicator())
                  : Container(
                      decoration: BoxDecoration(
                        color: card.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: card.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(isDarkMode ? 0.3 : 0.05),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (filteredDevices.isNotEmpty || searchQuery.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Text(
                                  "${filteredDevices.length} device${filteredDevices.length == 1 ? '' : 's'} found",
                                  style: TextStyle(
                                    color: subtle,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            if (filteredDevices.isEmpty && searchQuery.isEmpty)
                              _buildNoDevicesCard()
                            else
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final gridCols = constraints.maxWidth > 900
                                      ? 3
                                      : (constraints.maxWidth > 600 ? 2 : 1);

                                  if (gridCols > 1) {
                                    return GridView.builder(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridCols,
                                        mainAxisExtent: 92,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                      itemCount: filteredDevices.length,
                                      itemBuilder: (context, i) {
                                        return _buildGridDeviceCard(
                                          context: context,
                                          index: i,
                                          d: filteredDevices[i],
                                          isDarkMode: isDarkMode,
                                          strong: strong,
                                          subtle: subtle,
                                          card: card,
                                          accent: accent,
                                          screenWidth: screenWidth,
                                        );
                                      },
                                    );
                                  }

                                  return Column(
                                    children: filteredDevices.asMap().entries.map((entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _buildGridDeviceCard(
                                        context: context,
                                        index: entry.key,
                                        d: entry.value,
                                        isDarkMode: isDarkMode,
                                        strong: strong,
                                        subtle: subtle,
                                        card: card,
                                        accent: accent,
                                        screenWidth: screenWidth,
                                      ),
                                    )).toList(),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
              const SizedBox(height: 16),
              // Account & Security Section
              _buildAccountSecuritySection(
                isDarkMode: isDarkMode,
                card: card,
                strong: strong,
                subtle: subtle,
                screenWidth: screenWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSummaryCards({
    required int total,
    required int active,
    required int inactive,
    required bool isDarkMode,
    required Color strong,
    required Color subtle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Row(
          children: [
            // 1. Total Devices Box
            Expanded(
              child: InkWell(
                onTap: () => setState(() => filter = "All"),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: filter == "All"
                        ? (isDarkMode ? const Color(0xFF0288D1).withOpacity(0.25) : const Color(0xFFE0F2FE))
                        : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: filter == "All" ? const Color(0xFF0288D1) : (isDarkMode ? Colors.white12 : Colors.black12),
                      width: filter == "All" ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.devices, size: isMobile ? 16 : 20, color: const Color(0xFF0288D1)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Total Devices",
                              style: TextStyle(
                                color: subtle,
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$total",
                        style: TextStyle(
                          color: strong,
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 2. Active Devices Box
            Expanded(
              child: InkWell(
                onTap: () => setState(() => filter = "Active"),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: filter == "Active"
                        ? (isDarkMode ? const Color(0xFF10B981).withOpacity(0.25) : const Color(0xFFD1FAE5))
                        : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: filter == "Active" ? const Color(0xFF10B981) : (isDarkMode ? Colors.white12 : Colors.black12),
                      width: filter == "Active" ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: isMobile ? 16 : 20, color: const Color(0xFF10B981)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Active",
                              style: TextStyle(
                                color: subtle,
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$active",
                        style: TextStyle(
                          color: const Color(0xFF10B981),
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 3. Inactive Devices Box
            Expanded(
              child: InkWell(
                onTap: () => setState(() => filter = "Inactive"),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                  decoration: BoxDecoration(
                    color: filter == "Inactive"
                        ? (isDarkMode ? const Color(0xFFEF4444).withOpacity(0.25) : const Color(0xFFFEE2E2))
                        : (isDarkMode ? const Color(0xFF1E293B) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: filter == "Inactive" ? const Color(0xFFEF4444) : (isDarkMode ? Colors.white12 : Colors.black12),
                      width: filter == "Inactive" ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: isMobile ? 16 : 20, color: const Color(0xFFEF4444)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              "Inactive",
                              style: TextStyle(
                                color: subtle,
                                fontSize: isMobile ? 11 : 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$inactive",
                        style: TextStyle(
                          color: const Color(0xFFEF4444),
                          fontSize: isMobile ? 18 : 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGridDeviceCard({
    required BuildContext context,
    required int index,
    required Map<String, dynamic> d,
    required bool isDarkMode,
    required Color strong,
    required Color subtle,
    required Color card,
    required Color accent,
    required double screenWidth,
  }) {
    final sensorName = d['DeviceId'] as String;
    final displaySensorName = _toAnnamDisplayName(sensorName);
    final isActive = d['isActive'] == true;
    final location = _getLocationForSensor(sensorName) ?? '';
    final topic = (d['Topic'] ?? '').toString();
    final isSelected = _selectedDeviceIds.contains(sensorName);

    String sequentialName = '';
    String category = d['Category'] ?? '';

    if (category == 'CPS Lab Sensors') {
      if (sensorName.contains('LU')) {
        sequentialName = 'Lux Sensor';
      } else if (sensorName.contains('TE')) {
        sequentialName = 'Temperature Sensor';
      } else if (sensorName.contains('AC')) {
        sequentialName = 'Accelerometer Sensor';
      }
    } else if (category == 'ANNAM Sensors') {
      sequentialName = 'ANNAM Sensor';
    } else if (category.contains('IIT Bombay')) {
      sequentialName = 'IIT Bombay Sensor';
    } else if (category.contains('IIT Ropar')) {
      sequentialName = 'IIT Ropar Sensor';
    } else if (category.contains('Forest')) {
      sequentialName = 'Forest Sensor';
    } else if (category.contains('Soil')) {
      sequentialName = 'Soil Sensor';
    } else if (category.contains('Jan Weather')) {
      sequentialName = 'Jan Weather Sensor';
    } else if (category.contains('SSMET Weather')) {
      final sw = sensorName.trim().toUpperCase();
      if (sw == 'SW013') {
        sequentialName = 'Agri Bazar Sensor';
      } else if (sw == 'SW007') {
        sequentialName = 'IMD Chandigarh Sensor';
      } else {
        sequentialName = 'SSMET Weather Sensor';
      }
    } else {
      sequentialName = '${category.split(" ").first} Sensor';
    }

    final statusColor = isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverStates[sensorName] = true),
      onExit: (_) => setState(() => _hoverStates[sensorName] = false),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode
                  ? Colors.redAccent.withOpacity(0.14)
                  : const Color(0xFFFEE2E2).withOpacity(0.7))
              : card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.redAccent
                : (_hoverStates[sensorName] == true
                    ? accent.withOpacity(0.5)
                    : (isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.08))),
            width: isSelected ? 1.5 : 1.2,
          ),
          boxShadow: [
            if (_hoverStates[sensorName] == true || isSelected)
              BoxShadow(
                color: (isSelected ? Colors.redAccent : accent).withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 2,
              ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vertical status indicator bar on left edge
              Container(
                width: 4.0,
                color: statusColor,
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (isSelected) {
                          _selectedDeviceIds.remove(sensorName);
                        } else {
                          _selectedDeviceIds.add(sensorName);
                        }
                      });
                      return;
                    }

                    if (sensorName.startsWith('BF')) {
                      String numericNodeId = sensorName.replaceAll(RegExp(r'\D'), '');
                      NavigationUtils.navigateTo(
                        context,
                        '/buffalodata',
                        arguments: {
                          'startDateTime': DateTime.now(),
                          'endDateTime': DateTime.now().add(const Duration(days: 1)),
                          'nodeId': numericNodeId,
                        },
                      );
                    } else if (sensorName.startsWith('CS')) {
                      String numericNodeId = sensorName.replaceAll(RegExp(r'\D'), '');
                      NavigationUtils.navigateTo(
                        context,
                        '/cowdata',
                        arguments: {
                          'startDateTime': DateTime.now(),
                          'endDateTime': DateTime.now().add(const Duration(days: 1)),
                          'nodeId': numericNodeId,
                        },
                      );
                    } else {
                      NavigationUtils.navigateTo(
                        context,
                        '/devicegraph',
                        arguments: {
                          'deviceName': sensorName,
                          'sequentialName': sequentialName,
                          'backgroundImagePath': 'assets/backgroundd.jpg',
                        },
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "${index + 1}. $displaySensorName",
                                style: TextStyle(
                                  color: strong,
                                  fontWeight: FontWeight.w700,
                                  fontSize: screenWidth < 600 ? 12 : 13.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (topic.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: (isDarkMode ? Colors.white : Colors.black)
                                        .withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Topic: $topic",
                                    style: TextStyle(
                                      color: subtle,
                                      fontFamily: 'monospace',
                                      fontSize: screenWidth < 600 ? 9.5 : 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                              if (location.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: screenWidth < 600 ? 11 : 12,
                                        color: subtle),
                                    const SizedBox(width: 3),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: TextStyle(
                                          color: subtle,
                                          fontSize: screenWidth < 600 ? 10 : 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (_isSelectionMode)
                          Checkbox(
                            value: isSelected,
                            activeColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4)),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedDeviceIds.add(sensorName);
                                } else {
                                  _selectedDeviceIds.remove(sensorName);
                                }
                              });
                            },
                          )
                        else
                          DeviceActionButton(
                            deviceId: sensorName,
                            topic: topic,
                            sensorName: sensorName,
                            displaySensorName: displaySensorName,
                            sequentialName: sequentialName,
                            displayParamNames: getParamNamesForSensor(sensorName),
                            parameterDisplayNames: parameterDisplayNames,
                            userEmail: _email,
                            isAdmin: false,
                            isDark: isDarkMode,
                            healthTopicLookupMap: _healthTopicLookupMap,
                            onDeleteSuccess: () => _fetchData(),
                            iconSize: getResponsiveFontSize(context, 18, 20),
                            iconColor: subtle,
                          ),
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

  void _showAddDeviceDialog(BuildContext context, Color strong) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Center(
            child: Text(
              "Add New Device",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: strong,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        QRScannerPopup(devices: _deviceCategories),
                  );
                },
                child: const Text("Scan QR Code"),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) =>
                        ManualEntryPopup(devices: _deviceCategories),
                  );
                },
                child: const Text("Add Manually"),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountSecuritySection({
    required bool isDarkMode,
    required Color card,
    required Color strong,
    required Color subtle,
    required double screenWidth,
  }) {
    final email = _email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'U';
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined,
                  color: Color(0xFF0EA5E9), size: 20),
              const SizedBox(width: 8),
              Text(
                "Account & Security",
                style: TextStyle(
                  color: strong,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          const Color(0xFF0EA5E9).withOpacity(0.15),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email.isNotEmpty ? email : "CloudSense User",
                            style: TextStyle(
                              color: strong,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "CloudSense IoT Member",
                            style: TextStyle(
                              color: subtle,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_email != null && _email!.isNotEmpty) {
                        DeleteDeviceUtils.deleteAccount(
                            context, _email!, _email);
                      }
                    },
                    icon: const Icon(Icons.delete_forever_outlined,
                        size: 18, color: Colors.redAccent),
                    label: const Text(
                      "Delete Account",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      const Color(0xFF0EA5E9).withOpacity(0.15),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.isNotEmpty ? email : "CloudSense User",
                        style: TextStyle(
                          color: strong,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "CloudSense IoT Member",
                        style: TextStyle(
                          color: subtle,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    if (_email != null && _email!.isNotEmpty) {
                      DeleteDeviceUtils.deleteAccount(
                          context, _email!, _email);
                    }
                  },
                  icon: const Icon(Icons.delete_forever_outlined,
                      size: 18, color: Colors.redAccent),
                  label: const Text(
                    "Delete Account",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildNoDevicesCard() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final strong = isDarkMode ? Colors.white : Colors.black;

    return Center(
      child: Container(
        width: 300,
        height: 300,
        margin: const EdgeInsets.all(10),
        child: Card(
          color: isDarkMode ? const Color(0xFF161A22) : Colors.grey[200],
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No Device Found',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color.fromARGB(255, 235, 28, 28),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Add New Device',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: strong,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 10),
                    backgroundColor: Colors.black),
                onPressed: () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) =>
                        QRScannerPopup(devices: _deviceCategories),
                  );
                },
                child: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
                  backgroundColor: Colors.black,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        ManualEntryPopup(devices: _deviceCategories),
                  );
                },
                child: const Text(
                  'Add Manually',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
