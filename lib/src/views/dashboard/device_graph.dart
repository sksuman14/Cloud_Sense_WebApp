import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;
import 'package:cloud_sense_webapp/src/data/downloadcsv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/device_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';

// ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──

String _toAnnamDisplayName(String internalSensorName) =>
    DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

// DeviceStatus class to hold device data
class DeviceStatus {
  final String deviceId;
  final String lastReceivedTime;
  final double? latitude;
  final double? longitude;
  final String activityType; // e.g., chloritrone, WS, weather, water, Awadh_Jio
  final String? hardwareDeviceId;

  DeviceStatus({
    required this.deviceId,
    required this.lastReceivedTime,
    this.latitude,
    this.longitude,
    required this.activityType,
    this.hardwareDeviceId,
  });
}

class DeviceGraphPage extends StatefulWidget {
  final String deviceName;
  final String? sequentialName;
  final String? selectedDate;
  final String? period;
  final String? anomalyName;

  DeviceGraphPage({
    required this.deviceName,
    required this.sequentialName,
    this.selectedDate,
    this.period,
    this.anomalyName,
    required String backgroundImagePath,
  });

  @override
  _DeviceGraphPageState createState() => _DeviceGraphPageState();
}

class _DeviceGraphPageState extends State<DeviceGraphPage>
    with SingleTickerProviderStateMixin {
  bool _isAdmin = false;

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');
    if (mounted) {
      setState(() {
        _isAdmin = (email?.toLowerCase().trim() == 'sksuman14@gmail.com');
      });
    }
  }

  Map<String, String> _locationMap = {};
  static const Map<String, String> _hardcodedLocationMap = {
    'WJ262': 'Amritsar, Punjab',
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
  };

  String buildTopicFromSensorName(String sensorName) =>
      DevicePrefixUtils.buildTopicFromSensorName(sensorName);

  String? _getLocationForSensor(String sensorName) {
    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    final apiLocation = _locationMap[topic];
    if (apiLocation != null && apiLocation.isNotEmpty) return apiLocation;
    final hardcoded = _hardcodedLocationMap[sensorName];
    if (hardcoded != null) return hardcoded;

    // Fallback for TS (Testing) sensors: Rupnagar, Punjab
    if (DevicePrefixUtils.isAnnamTestingSensor(sensorName)) {
      return 'Rupnagar, Punjab';
    }
    return null;
  }

  Future<void> _loadLocationMap() async {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];
    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching location $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );
      Map<String, String> tempLocationMap = {};
      for (var response in responses) {
        if (response.statusCode != 200) continue;
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> devices = jsonResponse['devices'] ?? [];
        for (var item in devices) {
          final rawTopic =
              (item['deviceid#topic'] ?? item['deviceId#topic'] ?? '')
                  .toString();
          if (rawTopic.isEmpty) continue;
          final key = rawTopic.toLowerCase();
          final city = (item['City'] ?? '').toString().trim();
          final district = (item['District'] ?? '').toString().trim();
          final state = (item['State'] ?? '').toString().trim();
          final parts = {
            if (city.isNotEmpty) city,
            if (district.isNotEmpty) district,
            if (state.isNotEmpty) state
          }.toList();
          if (parts.isNotEmpty) {
            tempLocationMap[key] = parts.join(', ');
          }
        }
      }
      if (mounted) {
        setState(() {
          _locationMap = tempLocationMap;
        });
      }
    } catch (e) {
      debugPrint("Error loading location map: $e");
    }
  }

  bool _isKmPerHour = false;
  List<ChartData> _convertWindSpeed(List<ChartData> data) {
    if (!_isKmPerHour) return data;
    return data
        .map((d) => ChartData(
              timestamp: d.timestamp,
              value: d.value * 3.6,
            ))
        .toList();
  }

  bool _isShiftPressed = false;
  late DateTime _selectedDay = DateTime.now();
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  // Centralized data containers
  Map<String, List<ChartData>> _parametersData = {};
  DeviceTypeConfig? _config;
  Set<String> _visibleParameters = {};
  int _graphsPerRow = 1;

  // Consolidated device status variables
  Map<String, double> _lastBatteries = {};
  Map<String, double> _lastSignalStrengths = {};
  Map<String, double> _lastTiltStatuses = {};
  Map<String, String> _lastSDCardStatuses = {};
  Map<String, String> _lastMaxGustTimes = {};
  Map<String, double> _lastSquallSpeeds = {};
  Map<String, double> _lastSquallDirections = {};
  Map<String, String> _lastSquallTimes = {};
  Map<String, double> _lastDailyMaxTemps = {};
  Map<String, double> _lastDailyMinTemps = {};
  Map<String, double> _lastPanelVoltages = {};

  bool _isLoading = false;
  late final String activityType;
  String? _firmwareVersion;
  // Add this method to convert degrees to direction (e.g., ENE)

  void _extractFirmwareVersion(List<dynamic> items,
      {String key = 'FirmwareVersion'}) {
    for (var item in items.reversed) {
      final val = item[key];
      if (val != null &&
          val.toString().toLowerCase() != 'null' &&
          val.toString().trim().isNotEmpty) {
        _firmwareVersion = val.toString().trim();
        return;
      }
    }
  }

  double _convertVoltageToPercentage(double voltage) {
    const double maxVoltage = 4.2; // 100%
    const double minVoltage = 2.8; // 0%

    // Clamp the voltage to the valid range to avoid percentages outside 0-100
    if (voltage >= maxVoltage) return 100.0;
    if (voltage <= minVoltage) return 0.0;

    // Linear interpolation: percentage = ((voltage - min) / (max - min)) * 100
    return ((voltage - minVoltage) / (maxVoltage - minVoltage)) * 100.0;
  }

// Helper function to calculate total rainfall
  double _calculateTotalRainfall(List<ChartData> rainData,
      {bool isIncremental = false}) {
    if (rainData.isEmpty) return 0.0;

    if (isIncremental) {
      return rainData.fold(0.0, (sum, data) => sum + data.value);
    }

    final Map<DateTime, double> hourlyTotals = {};

    for (var data in rainData) {
      DateTime hourEnd = DateTime(
        data.timestamp.year,
        data.timestamp.month,
        data.timestamp.day,
        data.timestamp.hour,
        0,
      );
      if (data.timestamp.minute > 0) {
        hourEnd = DateTime(
          data.timestamp.year,
          data.timestamp.month,
          data.timestamp.day,
          data.timestamp.hour + 1,
          0,
        );
      }

      if (data.timestamp.isAtSameMomentAs(hourEnd) ||
          data.timestamp.isBefore(hourEnd)) {
        hourlyTotals[hourEnd] = data.value;
      }
    }

    return hourlyTotals.values.fold(0.0, (sum, total) => sum + total);
  }

// Helper function to merge raw sensor data with available corrected fields without dropping uncorrected timestamps
  List<ChartData> _mergeCorrectedData(
      List<ChartData> rawData, List<ChartData>? correctedData) {
    if (correctedData == null || correctedData.isEmpty) return rawData;

    final Map<DateTime, ChartData> mergedMap = {
      for (var d in rawData) d.timestamp: d
    };

    for (var c in correctedData) {
      if (mergedMap.containsKey(c.timestamp)) {
        final existing = mergedMap[c.timestamp]!;
        mergedMap[c.timestamp] = ChartData(
          timestamp: c.timestamp,
          value: c.value,
          gustTime: existing.gustTime,
          filledFlag: existing.filledFlag,
        );
      } else {
        mergedMap[c.timestamp] = c;
      }
    }

    final result = mergedMap.values.toList();
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

// Helper function to transform cumulative rainfall to incremental rainfall

  final DateFormat formatter = DateFormat('dd-MM-yyyy HH:mm:ss');
  Timer? _reloadTimer;
  // AnimationController for rotating refresh icon
  late AnimationController _rotationController;
  // Add a map to store hover states for each parameter
  final Map<String, bool> _isParamHovering = {};
  String? _selectedParam;

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

// Threshold for ammonia alerts

  bool isShiftPressed = false;
  late final FocusNode _focusNode;

  List<Map<String, dynamic>> rainHourlyItems = [];

// Variable to hold the selected device ID
  List<DeviceStatus> _deviceStatuses = [];

  String _lastSelectedRange = 'single'; // Default to single

  bool isWindDirectionValid(String? windDirection) {
    return windDirection != null && windDirection != "-";
  }

  bool iswinddirectionValid(String? direction) {
    if (direction == null || direction.isEmpty) {
      return false;
    }
    try {
      double value = double.parse(direction);
      bool isValid = value >= 0 && value <= 360;

      return isValid;
    } catch (e) {
      return false;
    }
  }

  // ScrollController for scrolling to charts
  final ScrollController _scrollController = ScrollController();
  // Map to associate parameter labels with their chart keys
  final Map<String, GlobalKey> _chartKeys = {};
  final Map<String, GlobalKey<SfCartesianChartState>> _sfChartKeys = {};
  // New variables to store rain forecasting data for WD 211
  String _totalRainLast24Hours = '0.00 mm';
  String _mostRecentHourRain = '0.00 mm';

  bool hasNonZeroValues(List<dynamic> data,
      {bool includePrecipitation = true}) {
    if (includePrecipitation) {
      return data.isNotEmpty &&
          data.any((entry) => entry.value != null && entry.value != 0);
    } else {
      return data.isNotEmpty &&
          data.any((entry) =>
              entry.value != null &&
              entry.value != 0 &&
              entry.type != 'precipitationProbability');
    }
  }

  Map<String, List<ChartData>> _parseDeviceData(dynamic data) {
    if (_config == null) return {};

    Map<String, List<ChartData>> parsed;

    // SM sensors use a slightly different top-level structure (sometimes just a list)
    if (widget.deviceName.startsWith('SM')) {
      parsed = _parseSMParametersData(data);
    } else {
      // Most others use { "items": [...] }
      parsed = _parseMultiSensorData(
        data is Map<String, dynamic> ? data : {'items': data},
        itemsKey: data is Map<String, dynamic> &&
                data.containsKey('sensor_data_items')
            ? 'sensor_data_items'
            : 'items',
        timestampKey: data is Map<String, dynamic> &&
                data.containsKey('sensor_data_items')
            ? 'HumanTime'
            : (widget.deviceName.startsWith('WT') ||
                    widget.deviceName.startsWith('WF') ||
                    widget.deviceName.startsWith('WA') ||
                    widget.deviceName.startsWith('JW')
                ? 'Time_Stamp'
                : (widget.deviceName.startsWith('IT')
                    ? 'human_time'
                    : (widget.deviceName.startsWith('FS')
                        ? 'timestamp'
                        : (widget.deviceName.startsWith('WN')
                            ? 'TimeStamp'
                            : 'TimeStamp')))),
        batteryKey: (widget.deviceName.startsWith('JW') ||
                widget.deviceName.startsWith('KR') ||
                widget.deviceName.startsWith('SH'))
            ? 'Battery_Voltage'
            : 'BatteryVoltage',
        signalStrengthKey: (widget.deviceName.startsWith('JW') ||
                widget.deviceName.startsWith('KR') ||
                widget.deviceName.startsWith('SH'))
            ? 'Signal_Strength'
            : 'SignalStrength',
        maxGustTimeKey: widget.deviceName.startsWith('JW')
            ? 'Max_wind_gust_time'
            : (widget.deviceName.startsWith('KR') ||
                    widget.deviceName.startsWith('AM'))
                ? 'max_wind_gust_time'
                : 'MaxWindGustTime',
        onBatteryUpdate: (v) => _lastBatteries[widget.deviceName] = v,
        onSignalStrengthUpdate: (v) =>
            _lastSignalStrengths[widget.deviceName] = v,
        onSDcardStatusUpdate: (v) => _lastSDCardStatuses[widget.deviceName] = v,
        onMaxWindGustTimeUpdate: (v) =>
            _lastMaxGustTimes[widget.deviceName] = v,
        onSquallSpeedUpdate: (v) => _lastSquallSpeeds[widget.deviceName] = v,
        onSquallDirectionUpdate: (v) =>
            _lastSquallDirections[widget.deviceName] = v,
        onSquallTimeUpdate: (v) => _lastSquallTimes[widget.deviceName] = v,
        onDailyMaxTempUpdate: (v) => _lastDailyMaxTemps[widget.deviceName] = v,
        onDailyMinTempUpdate: (v) => _lastDailyMinTemps[widget.deviceName] = v,
        onPanelVoltageUpdate: (v) => _lastPanelVoltages[widget.deviceName] = v,
        onTiltUpdate: (v) => _lastTiltStatuses[widget.deviceName] = v,
      );
    }

    // Apply special scaling/adjustments based on device
    if ((widget.deviceName.startsWith('SW003') ||
        widget.deviceName.startsWith('SW025'))) {
      parsed.forEach((key, valueList) {
        if (key.toLowerCase().contains('rain')) {
          parsed[key] = valueList
              .map((d) =>
                  ChartData(timestamp: d.timestamp, value: d.value * 0.4))
              .toList();
        }
      });
    }

    return parsed;
  }

  void _updateCSVRows(Map<String, List<ChartData>> data) {
    if (data.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      return;
    }

    List<String> headers = ['Timestamp'];
    headers.addAll(data.keys);

    List<List<dynamic>> dataRows = [];
    int maxLength =
        data.values.map((list) => list.length).fold(0, (a, b) => a > b ? a : b);

    for (int i = 0; i < maxLength; i++) {
      List<dynamic> row = [
        data.values.first.length > i
            ? formatter.format(data.values.first[i].timestamp)
            : ''
      ];
      for (var key in data.keys) {
        var value = data[key]!.length > i ? data[key]![i].value : null;
        row.add(value ?? '');
      }
      dataRows.add(row);
    }

    _csvRows = [headers, ...dataRows];
  }

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _config = DeviceConfig.getConfig(widget.deviceName);
    _loadLocationMap();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    if (widget.selectedDate != null) {
      try {
        final parts = widget.selectedDate!.split('-');
        if (parts.length == 3) {
          // dd-MM-yyyy
          _selectedDay = DateTime(
            int.parse(parts[2]), // year
            int.parse(parts[1]), // month
            int.parse(parts[0]), // day
          );
        } else {
          _selectedDay = DateTime.now();
        }
      } catch (e) {
        _selectedDay = DateTime.now();
      }
    } else {
      _selectedDay = DateTime.now();
    }
    requestPermissions();

    _focusNode = FocusNode();
    _initializeNotifications();

    // Initialize AnimationController
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 500), // Slower for visibility
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reloadData(range: 'single');
      }
    });
    // --- END OF NEW PART ---

    // Set up the periodic timer to reload data every 180 seconds
    _reloadTimer = Timer.periodic(const Duration(seconds: 180), (timer) {
      if (!_isLoading) {
        // We check _isLoading to prevent a new reload if one is already in progress
        _reloadData(range: _lastSelectedRange);
      } else {
        print("Skipping periodic reload, a fetch is already in progress.");
      }
    });
    // Initialize chart keys for each parameter
    _initializeChartKeys();
  }

  // Update _initializeChartKeys to ensure consistent parameter names
  void _initializeChartKeys() {
    // Initialize hover states and chart keys
    _chartKeys.clear();
    _sfChartKeys.clear();
    _isParamHovering.clear();
    _selectedParam = null; // Reset selected parameter
    _visibleParameters.clear();

    if (_config != null) {
      for (var param in _config!.parameters) {
        if (param.key == 'WindSpeed' ||
            param.key == 'Wind_Speed' ||
            param.key == 'now_wind_speed' ||
            param.key == 'NowWindSpeed' ||
            param.key == 'WindDirection' ||
            param.key == 'WindDir' ||
            param.key == 'now_wind_direction' ||
            param.key == 'NowWindDirection') {
          continue;
        }

        _chartKeys[param.displayName] = GlobalKey();
        _sfChartKeys[param.displayName] = GlobalKey<SfCartesianChartState>();
        _isParamHovering[param.displayName] = false;
        if (!param.isMetadata) {
          _visibleParameters.add(param.displayName);
        }
      }

      if (_config!.hasWind) {
        _chartKeys['Wind'] = GlobalKey();
        _sfChartKeys['Wind'] = GlobalKey<SfCartesianChartState>();
        _isParamHovering['Wind'] = false;
        _visibleParameters.add('Wind');
      }
    } else {
      // Fallback for unknown devices or legacy chlorine handling
      const params = [
        'Chlorine',
        'Temperature',
        'Humidity',
        'Light Intensity',
        'Wind',
        'Solar Irradiance',
      ];
      for (var param in params) {
        _chartKeys[param] = GlobalKey();
        _sfChartKeys[param] = GlobalKey<SfCartesianChartState>();
        _isParamHovering[param] = false;
        _visibleParameters.add(param);
      }
    }
  }

  Future<void> _exportChart(String title, String format) async {
    try {
      final key = _sfChartKeys[title];
      if (key == null || key.currentState == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Chart state not found for $title")),
        );
        return;
      }

      // Convert chart to image bytes
      final ui.Image? data = await key.currentState!.toImage(pixelRatio: 3.0);
      if (data == null) return;

      final ByteData? bytes = await data.toByteData(
          format: format.toLowerCase() == 'png'
              ? ui.ImageByteFormat.png
              : ui.ImageByteFormat
                  .rawRgba); // JPG handled via conversion if needed, but PNG is simpler here

      if (bytes == null) return;

      final Uint8List pngBytes = bytes.buffer.asUint8List();

      if (kIsWeb) {
        final blob = html.Blob([pngBytes], 'image/png');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute("download",
              "Chart_${title.replaceAll(' ', '_')}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png")
          ..click();
        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Downloading $title chart as PNG")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text("Image download is only supported on Web currently")),
        );
      }
    } catch (e) {
      debugPrint("Export error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error exporting chart: $e")),
      );
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    // Cancel the timer to prevent memory leaks
    _reloadTimer?.cancel();
    _focusNode.dispose();
    _rotationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (_isShiftPressed != isShift) {
      setState(() => _isShiftPressed = isShift);
    }
    return false;
  }

  Future<void> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

// Add this method to initialize notifications
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  // Add this method to show notification

  Future<void> _fetchDeviceDetails() async {
    // REMOVED: setState(() { _isLoading = true; ... });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final urls = [
        'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity?t=$timestamp',
        'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api?t=$timestamp',
      ];

      final responses = await Future.wait(
        urls.map(
          (url) => http.get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          ).catchError((e) {
            debugPrint("Error fetching details $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      List<DeviceStatus> allDevices = [];

      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response.statusCode != 200) {
          continue;
        }

        final data = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic>? devices = data['devices'];
        if (devices == null || devices.isEmpty) {
          continue;
        }

        for (var device in devices) {
          final deviceIdTopic =
              (device['deviceid#topic'] ?? device['deviceId#topic'] ?? '')
                  .toString();
          if (deviceIdTopic.isEmpty) continue;

          final parts = deviceIdTopic.split('#');
          if (parts.isEmpty) continue;

          final deviceId = parts[0];
          final topic = parts.length > 1 ? parts.sublist(1).join('#') : '';

          if (topic.startsWith('BF/') || topic.startsWith('CS/')) continue;

          double? lat = double.tryParse(
              (device['LastKnownLatitude'] ?? device['Latitude'] ?? 0)
                  .toString());
          double? lon = double.tryParse(
              (device['LastKnownLongitude'] ?? device['Longitude'] ?? 0)
                  .toString());

          final activityType =
              _mapActivityToPrefix(_getActivityTypeFromTopic(topic), topic);

          String lastReceivedTime = parseTime(device['TimeStamp_IST'] ??
              device['TimeStamp'] ??
              device['Time_Stamp'] ??
              device['human_time'] ??
              device['timestamp']);

          final hardwareDeviceId = (device['ANNAM_ID'] ??
                  device['DeviceId'] ??
                  device['deviceid'] ??
                  device['Device_ID'] ??
                  device['DeviceID'])
              ?.toString();

          allDevices.add(DeviceStatus(
            deviceId: deviceId,
            lastReceivedTime: lastReceivedTime,
            latitude: (lat != null && lat != 0) ? lat : null,
            longitude: (lon != null && lon != 0) ? lon : null,
            activityType: activityType,
            hardwareDeviceId: hardwareDeviceId,
          ));
        }
      }

      final deviceList = allDevices;

      deviceList.sort((a, b) {
        final aTime = DateTime.tryParse(a.lastReceivedTime) ?? DateTime(1970);
        final bTime = DateTime.tryParse(b.lastReceivedTime) ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });

      // Just update the statuses. _isLoading is handled by _reloadData.
      if (mounted) {
        setState(() {
          _deviceStatuses = deviceList;
// Clear any previous error
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _getActivityTypeFromTopic(String topic) {
    if (topic.startsWith('WS/Weather/')) return 'weather';
    if (topic.startsWith('WS/Water/')) return 'water';

    if (topic.startsWith('WS/JioData/'))
      return 'Awadh_Jio'; // Map JioData to Awadh_Jio

    if (topic.startsWith('WS/SVPU/')) return 'SV'; // Map SVPU to WS
    if (topic.startsWith('chloritrone/')) return 'chloritrone';
    if (topic.startsWith('Awadh_Jio/')) return 'Awadh_Jio';
    if (topic == 'WS/Campus/2') return 'CF';
    if (topic.startsWith('WS/Campus/')) return 'CP';
    if (topic.startsWith('Weather/sensor/')) return 'WT';
    if (topic.contains('SSMet/Forest')) return 'FS';
    if (topic.contains('SSMet/Soil')) return 'SS';
    if (topic.contains('Polytechnic')) return 'PC';
    if (topic.contains('GPC')) return 'GP';
    if (topic.startsWith('Awadh/IIT_B')) return 'IT';
    if (topic.startsWith('Demo/Device')) return 'DM';
    if (topic.contains('IIT/WS/SSMet/1')) return 'SM'; // Special case for SM001
    if (topic.contains('SSMet/Railway')) return 'SM';
    if (topic.contains('SSMET_1225')) return 'SW';
    if (topic.contains('SSMet_0126')) return 'WJ';
    if (topic.contains('SSMet_0226')) return 'WF';
    if (topic.contains('Annam_0426')) return 'WA';
    if (topic.contains('Annam_0526')) return 'WM';
    if (topic.contains('SSMet/custom/1225/C0')) return 'SI';
    if (topic.contains('NARL')) return 'NA';
    if (topic.contains('KJSCE')) return 'KJ';
    if (topic.contains('KARGIL/')) return 'KD';
    if (topic.contains('WS/Vanix/02')) return 'VD';

    if (topic.contains('Shobha')) return 'SH';
    if (topic.contains('Jio_Logger')) return 'JW';
    if (topic.contains('Winds_WN') ||
        topic.contains('WINDS/') ||
        topic.contains('Winds/Sensor/')) return 'WN';
    if (topic.contains('Mysuru')) return 'MY';
    if (topic.contains('Kerala')) return 'KR';
    if (topic.contains('AWS')) return 'AW';
    if (topic.startsWith('WS/ANNAM_CP') || topic.contains('ANNAM_CP'))
      return 'AM';

    if (topic.contains('Testing/')) return 'AT'; // Map Testing/nRF52840 to AT
    return 'unknown';
  }

  String parseTime(String? time) {
    if (time == null || time.isEmpty || time == "N/A") return 'Unknown';
    try {
      // Remove extra spaces
      time = time.trim().replaceAll(RegExp(r'\s+'), ' ');

      // Handle yyyyMMddTHHmmss (compact format)
      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(time)) {
        final year = int.parse(time.substring(0, 4));
        final month = int.parse(time.substring(4, 6));
        final day = int.parse(time.substring(6, 8));
        final hour = int.parse(time.substring(9, 11));
        final minute = int.parse(time.substring(11, 13));
        final second = int.parse(time.substring(13, 15));
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(year, month, day, hour, minute, second),
        );
      }

      // Handle yyyy-MM-dd HH:mm:ss
      final standardRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
      if (standardRegex.hasMatch(time)) {
        final parsed = DateTime.parse(time);
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(parsed);
      }

      // Handle dd-MM-yyyy HH:mm:ss
      final dmyRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (dmyRegex.hasMatch(time)) {
        final parts = time.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final day = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final year = int.parse(dateParts[2]);
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final second = int.parse(timeParts[2]);
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(year, month, day, hour, minute, second),
        );
      }

      // Handle yyyy/MM/dd,HH:mm:ss (Winds_WS format)
      final windsRegex = RegExp(r'^\d{4}/\d{2}/\d{2},\d{2}:\d{2}:\d{2}$');
      if (windsRegex.hasMatch(time)) {
        final parts = time.split(',');
        final dateParts = parts[0].split('/');
        final timeParts = parts[1].split(':');
        final y = int.parse(dateParts[0]);
        final m = int.parse(dateParts[1]);
        final d = int.parse(dateParts[2]);
        final H = int.parse(timeParts[0]);
        final M = int.parse(timeParts[1]);
        final S = int.parse(timeParts[2]);
        return DateFormat('dd-MM-yyyy HH:mm:ss')
            .format(DateTime(y, m, d, H, M, S));
      }

      // Handle yyyy-MM-dd HH:mm AM/PM
      final amPmRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{1,2}:\d{2} (AM|PM)$');
      if (amPmRegex.hasMatch(time)) {
        final isPm = time.endsWith('PM');
        final base = time.replaceAll(RegExp(r' (AM|PM)$'), '');
        final dateTimeParts = base.split(' ');
        final date = dateTimeParts[0];
        final timeStr = dateTimeParts[1];
        final dateParts = date.split('-');
        final timeParts = timeStr.split(':');
        int hour = int.parse(timeParts[0]);
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        return DateFormat('dd-MM-yyyy HH:mm:ss').format(
          DateTime(
            int.parse(dateParts[0]),
            int.parse(dateParts[1]),
            int.parse(dateParts[2]),
            hour,
            int.parse(timeParts[1]),
          ),
        );
      }

      // Fallback to DateTime.tryParse
      final parsed = DateTime.tryParse(time.replaceAll('  ', ' '));
      return parsed != null
          ? DateFormat('dd-MM-yyyy HH:mm:ss').format(parsed)
          : 'Unknown';
    } catch (e) {
      if (kDebugMode) {
        print("Failed to parse time: $time, error: $e");
      }
      return 'Unknown';
    }
  }

  String _mapActivityToPrefix(String activityType, String? topic) {
    if (activityType == 'chloritrone') return 'CL';
    if (activityType == 'water') return 'WQ';
    if (activityType == 'weather') return 'weather';

    if (activityType == 'WS') {
      if (topic == null) return 'CX';
      if (topic.contains('SSMET')) return 'SM';
      if (topic.contains('SSMET_1225')) return 'SW';
      if (topic.contains('SSMET_0126')) return 'WJ';
      if (topic.contains('SSMET_0226')) return 'WF';
      if (topic.contains('Annam_0426')) return 'WA';
      if (topic.contains('Annam_0526')) return 'WM';
      if (topic.contains('SSMet/custom/1225/C0')) return 'SI';
      if (topic.contains('NARL')) return 'NA';
      if (topic.contains('Polytechnic')) return 'PC';
      if (topic.contains('GPC')) return 'GP';
      if (topic == 'WS/Campus/2') return 'CF';
      if (topic.contains('WS/Campus')) return 'CP';
      if (topic.contains('SSMet/Forest')) return 'FS';
      if (topic.contains('SSMet/Soil')) return 'SS';
      if (topic.contains('Awadh/IIT_B')) return 'IT';
      if (topic.contains('Demo/Device')) return 'DM';
      if (topic.contains('KJSCE')) return 'KJ';
      if (topic.contains('SVPU')) return 'SV';
      if (topic.contains('Mysuru')) return 'MY';
      if (topic.contains('Winds_WN')) return 'WN';
      if (topic.contains('WS_WINDS/Jio_Logger')) return 'JW';
      if (topic.contains('Shobha')) return 'SH';
      return 'CX';
    }
    return activityType;
  }

  String _getPrefix(String deviceName) {
    if (deviceName.startsWith('Awadh_Jio')) return 'Awadh_Jio';
    if (deviceName.startsWith('weather')) return 'weather';
    return deviceName.substring(0, 2);
  }

  List<List<dynamic>> _csvRows = [];

  String _generateApiUrl(String range, String startdate, String enddate,
      {String? year, String? month}) {
    if (_config == null) return '';

    String template = '';
    if (range == '30days' && _config!.monthHistoryApiTemplate != null) {
      template = _config!.monthHistoryApiTemplate!;
    } else if (range == '3months' && _config!.threeMonthHistoryApiTemplate != null) {
      template = _config!.threeMonthHistoryApiTemplate!;
    } else if (range == '7days' && _config!.historyApiTemplate != null) {
      template = _config!.historyApiTemplate!;
    } else {
      template = (_config!.apiTemplate ?? '');
    }

    // Handle special CP sensor routing
    if (widget.deviceName.startsWith('CP') &&
        widget.deviceName != 'CP001' &&
        widget.deviceName != 'CP002' &&
        widget.deviceName != 'CP003') {
      template =
          'https://d3dj66m23j48gu.cloudfront.net/campusdata?deviceid={deviceId}&startdate={startdate}&enddate={enddate}';
    }

    if (template.isEmpty) return '';

    String deviceIdStr = widget.deviceName;
    // Strip the prefix
    if (widget.deviceName.startsWith('AWS_')) {
      deviceIdStr = widget.deviceName.substring(4);
    } else if (RegExp(r'^[A-Za-z]{2}').hasMatch(widget.deviceName)) {
      deviceIdStr = widget.deviceName.substring(2);
    }
    // If the remaining ID is purely numeric, parse as int to strip leading zeros (legacy behavior)
    if (RegExp(r'^\d+$').hasMatch(deviceIdStr)) {
      deviceIdStr = int.parse(deviceIdStr).toString();
    }

    // For places that still need the purely numeric value as a fallback
    int deviceIdNumeric =
        int.tryParse(deviceIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (widget.deviceName.startsWith('KR')) {
      deviceIdStr = deviceIdNumeric.toString();
    }

    if (widget.deviceName.startsWith('JW')) {
      try {
        final jwDevice = _deviceStatuses.firstWhere(
          (d) =>
              d.activityType == 'JW' &&
              (int.tryParse(d.deviceId) == deviceIdNumeric),
        );
        if (jwDevice.hardwareDeviceId != null &&
            jwDevice.hardwareDeviceId!.isNotEmpty) {
          deviceIdStr = jwDevice.hardwareDeviceId!;
        }
      } catch (e) {
        // ignore if not found
      }
    }

    // Special for SI
    String strDeviceId = widget.deviceName.toUpperCase();
    RegExp regExp = RegExp(r'([A-Z]\d)$');
    Match? match = regExp.firstMatch(strDeviceId);
    String subDeviceId = match != null ? match.group(1)! : '';

    // Special for CP
    String cpDeviceId = widget.deviceName == 'CP001' ? '1' : '3';

    String monthAbbr = '';
    if (month != null && month.isNotEmpty) {
      try {
        int m = int.parse(month);
        monthAbbr = DateFormat('MMM').format(DateTime(2026, m)).toLowerCase();
      } catch (e) {
        debugPrint("Error parsing month for abbreviation: $e");
      }
    }

    String deviceIdPadded = deviceIdNumeric.toString().padLeft(3, '0');
    String deviceIdPadded2 = deviceIdNumeric.toString().padLeft(2, '0');

    String startdateYMD = '';
    String enddateYMD = '';
    String windowAbbr = '';
    try {
      final startDt = DateFormat('dd-MM-yyyy').parse(startdate);
      startdateYMD = DateFormat('yyyy-MM-dd').format(startDt);
      final endDt = DateFormat('dd-MM-yyyy').parse(enddate);
      enddateYMD = DateFormat('yyyy-MM-dd').format(endDt);
      if (range == '3months') {
        windowAbbr = '${DateFormat('MMM').format(startDt).toLowerCase()}_${DateFormat('MMM').format(endDt).toLowerCase()}';
      }
    } catch (e) {
      startdateYMD = startdate;
      enddateYMD = enddate;
    }

    return template
        .replaceAll('{deviceId}', deviceIdStr)
        .replaceAll('{deviceIdPadded}', deviceIdPadded)
        .replaceAll('{deviceIdPadded2}', deviceIdPadded2)
        .replaceAll('{monthAbbr}', monthAbbr)
        .replaceAll('{deviceName}', widget.deviceName)
        .replaceAll('{strDeviceId}', subDeviceId)
        .replaceAll('{cpDeviceId}', cpDeviceId)
        .replaceAll('{startdate}', startdate)
        .replaceAll('{enddate}', enddate)
        .replaceAll('{startdate_yyyy_mm_dd}', startdateYMD)
        .replaceAll('{enddate_yyyy_mm_dd}', enddateYMD)
        .replaceAll('{year}', year ?? '')
        .replaceAll('{month}', month ?? '')
        .replaceAll('{windowAbbr}', windowAbbr);
  }

  Future<void> _fetchDataForRange(String range,
      [DateTime? selectedDate]) async {
    setState(() {
      _isLoading = true;
// Clear previous errors
      _parametersData.clear();
      _csvRows.clear();

      // Reset consolidated status variables
      _lastBatteries.clear();
      _lastSignalStrengths.clear();
      _lastSDCardStatuses.clear();
    });

    try {
      DateTime startDate;
      DateTime endDate = DateTime.now();

      if (widget.selectedDate != null) {
        try {
          final anomalyDate =
              DateFormat('dd-MM-yyyy').parse(widget.selectedDate!);
          startDate = anomalyDate;
          endDate = anomalyDate;
        } catch (e) {
          startDate = endDate; // fallback to today
        }
      } else {
        switch (range) {
          case '7days':
            startDate = endDate.subtract(const Duration(days: 7));
            break;
          case '30days':
            startDate = endDate.subtract(const Duration(days: 30));
            break;
          case '3months':
            DateTime currentMonthStart =
                DateTime(endDate.year, endDate.month, 1);
            DateTime threeMonthsAgoStart = DateTime(
                currentMonthStart.year, currentMonthStart.month - 3, 1);
            startDate = threeMonthsAgoStart;
            endDate = currentMonthStart.subtract(const Duration(days: 1));
            break;
          case '1year':
            startDate = endDate.subtract(const Duration(days: 365));
            break;
          case 'single':
            startDate = _selectedDay;
            endDate = startDate;
            break;
          default:
            startDate = endDate;
        }
      }

      _lastSelectedRange = range;
      final dateFormatter = DateFormat('dd-MM-yyyy');
      final startStr = dateFormatter.format(startDate);
      final endStr = dateFormatter.format(endDate);

      // Unique device logic (WD rain forecasting)
      if (widget.deviceName == 'WD211') await _fetchRainForecastingData();
      if (widget.deviceName == 'WD511') await _fetchRainForecastData();

      String year = range == '30days'
          ? _selectedYear.toString()
          : endDate.year.toString();
      String month = range == '30days'
          ? _selectedMonth.toString()
          : endDate.month.toString();

      if (_deviceStatuses.isEmpty) {
        await _fetchDeviceDetails();
      }

      String apiUrl =
          _generateApiUrl(range, startStr, endStr, year: year, month: month);
      if (apiUrl.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _parametersData = _parseDeviceData(data);
          _updateCSVRows(_parametersData);
        });
        await _fetchDeviceDetails();
      } else {}
    } catch (e) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void downloadCSV(BuildContext context, {DateTimeRange? range}) async {
    List<List<dynamic>> csvRows;

    // Handling WD211/WD511 specially if they rely on separate forecasting data
    // Note: rfdData and rfsData should ideally be integrated into _parametersData.
    // For now, if _csvRows is empty, we fall back to generic checks or show error.

    if (_csvRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available for download.")),
      );
      return;
    }

    csvRows = _csvRows;

    String csvData = const ListToCsvConverter().convert(csvRows);
    String fileName = _generateFileName();

    if (kIsWeb) {
      final blob = html.Blob([csvData], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Downloading"),
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      try {
        await saveCSVFile(csvData, fileName);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error downloading: $e")),
        );
      }
    }
  }

  String _generateFileName() {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SensorData_$timestamp.csv';
  }

  Future<void> saveCSVFile(String csvData, String fileName) async {
    try {
      // Get the Downloads directory.
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      if (downloadsDirectory.existsSync()) {
        final filePath = '${downloadsDirectory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsString(csvData);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("File downloaded to $filePath"),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Unable to find Downloads directory")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving file: $e")),
      );
    }
  }

  Future<void> _fetchRainForecastingData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=211'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _fetchRainForecastData() async {
    try {
      final response = await http.get(Uri.parse(
          'https://w6dzlucugb.execute-api.us-east-1.amazonaws.com/default/CloudSense_rain_data_api?DeviceId=511'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _totalRainLast24Hours =
              data['TotalRainLast24Hours']?.toString() ?? '0.00 mm';
          _mostRecentHourRain =
              data['MostRecentHourRain']?.toString() ?? '0.00 mm';
        });
      } else {
        throw Exception('Failed to load rain forecasting data');
      }
    } catch (e) {
      print('Error fetching rain forecasting data: $e');
    }
  }

  Future<void> _showDownloadOptionsDialog(BuildContext context) async {
    String? hardwareDeviceId;
    if (widget.deviceName.startsWith('JW')) {
      String deviceIdOnly = widget.deviceName.replaceAll(RegExp(r'[^0-9]'), '');
      int deviceIdNumeric = int.tryParse(deviceIdOnly) ?? 0;
      try {
        final jwDevice = _deviceStatuses.firstWhere(
          (d) =>
              d.activityType == 'JW' &&
              (int.tryParse(d.deviceId) == deviceIdNumeric),
        );
        hardwareDeviceId = jwDevice.hardwareDeviceId;
      } catch (e) {
        // ignore
      }
    }
    showCsvDownloadDialog(context,
        deviceName: widget.deviceName,
        hardwareDeviceId: hardwareDeviceId,
        visibleParameters: _visibleParameters,
        isAdmin: _isAdmin);
  }

  // ───────────────────────────────────────────────────────────────────────────────
//                           SINGLE DATE PARSER
// ───────────────────────────────────────────────────────────────────────────────
  DateTime parseSensorDate(
    String? dateStr, {
    String? forcedFormat,
  }) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return DateTime.now();
    }

    final trimmed = dateStr.trim();

    try {
      // Special compressed format: 20250614T162130
      if (RegExp(r'^\d{8}T\d{6}$').hasMatch(trimmed)) {
        return DateTime.parse(trimmed.replaceFirst('T', ''));
      }

      // Forced format (if provided)
      if (forcedFormat != null) {
        return DateFormat(forcedFormat).parseStrict(trimmed);
      }

      // Most common formats in order of likelihood
      final formats = [
        'yyyy-MM-dd HH:mm:ss', // most common
        'dd-MM-yyyy HH:mm:ss', // CB, Ammonia, Rain, TH
        'yyyy-MM-dd hh:mm a', // BD, Wind
        'yyyyMMdd HHmmss', // after T replacement
        'yyyy-MM-dd HH:mm', // rare cases
        'yyyy/MM/dd,HH:mm:ss', // Winds WN Sensors
      ];

      for (final fmt in formats) {
        try {
          return DateFormat(fmt).parseStrict(trimmed);
        } catch (_) {
          continue;
        }
      }

      // Last resort: raw parse
      return DateTime.parse(trimmed);
    } catch (e) {
      print('Date parsing failed for: "$trimmed" → $e');
      return DateTime.now();
    }
  }

// ───────────────────────────────────────────────────────────────────────────────
//                    GENERIC MULTI-PARAMETER PARSER
// ───────────────────────────────────────────────────────────────────────────────
  Map<String, List<ChartData>> _parseMultiSensorData(
    Map<String, dynamic> apiData, {
    required String itemsKey, // 'items', 'sensor_data_items', etc.
    required String timestampKey, // 'TimeStamp', 'human_time', etc.
    List<String> excludedKeys = const [
      'TimeStamp',
      'Topic',
      'IMEINumber',
      'DeviceId',
      'Latitude',
      'Longitude',
      'EpochTime',
      'human_time',
      'device_id',
    ],
    String batteryKey = 'BatteryVoltage',
    String signalStrengthKey = 'SignalStrength',
    String firmwareKey = 'FirmwareVersion',
    String sdCardKey = 'SDcardStatus',
    String maxGustTimeKey = 'MaxWindGustTime',
    Function(double)? onBatteryUpdate,
    Function(double)? onSignalStrengthUpdate,
    Function(String)? onSDcardStatusUpdate,
    Function(String)? onMaxWindGustTimeUpdate,
    Function(double)? onSquallSpeedUpdate,
    Function(double)? onSquallDirectionUpdate,
    Function(String)? onSquallTimeUpdate,
    Function(double)? onDailyMaxTempUpdate,
    Function(double)? onDailyMinTempUpdate,
    Function(double)? onPanelVoltageUpdate,
    Function(double)? onTiltUpdate,
  }) {
    final List<dynamic> items = apiData[itemsKey] ?? [];
    Map<String, List<ChartData>> parametersData = {};
// ✅ Extract firmware version
    _extractFirmwareVersion(items, key: firmwareKey);
    if (items.isEmpty) return parametersData;

    // Collect all possible numeric parameter keys (union across all items)
    final Set<String> allKeys = {};
    for (var item in items) {
      if (item is Map<String, dynamic>) {
        for (var key in item.keys) {
          if (!excludedKeys.contains(key)) {
            allKeys.add(key);
            // Add CamelCase aliases for AM sensors so graphs render properly
            if (key == 'now_temperature') allKeys.add('NowTemperature');
            if (key == 'now_relative_humidity')
              allKeys.add('NowRelativeHumidity');
            if (key == 'now_wind_speed') allKeys.add('NowWindSpeed');
            if (key == 'now_wind_direction') allKeys.add('NowWindDirection');
            if (key == 'rainfall') allKeys.add('Rainfall');
          }
        }
      }
    }

    final parameterKeys = allKeys.toList();

    // Initialize lists
    for (var key in parameterKeys) {
      parametersData[key] = [];
    }

    // Parse data
    for (var item in items) {
      if (item == null) continue;

      // Try primary key, then fallbacks if not found
      final timestamp = parseSensorDate(
        item[timestampKey]?.toString() ??
            item['TimeStamp_IST']?.toString() ??
            item['TimeStamp']?.toString() ??
            item['Time_Stamp']?.toString() ??
            item['human_time']?.toString() ??
            item['HumanTime']?.toString() ??
            item['timestamp']?.toString() ??
            item['EpochTime']?.toString(),
      );

      for (var key in parameterKeys) {
        final rawValue = item[key] ??
            (key == 'NowTemperature' ? item['now_temperature'] : null) ??
            (key == 'NowRelativeHumidity'
                ? item['now_relative_humidity']
                : null) ??
            (key == 'NowWindSpeed' ? item['now_wind_speed'] : null) ??
            (key == 'NowWindDirection' ? item['now_wind_direction'] : null) ??
            (key == 'Rainfall' ? item['rainfall'] : null);

        if (rawValue != null) {
          double value = double.tryParse(rawValue.toString()) ?? 0.0;

          if ((key.toLowerCase() == 'batteryvoltage' ||
                  key.toLowerCase() == 'battery_voltage') &&
              value == 0.0) {
            if (parametersData[key] != null &&
                parametersData[key]!.isNotEmpty) {
              value = parametersData[key]!.last.value;
            }
          }

          String? gustTime;
          if (key == 'MaximumWindGustSpeed' ||
              key == 'Maximum_wind_gust_speed' ||
              key == 'max_wind_gust') {
            gustTime = (item[maxGustTimeKey] ?? item['max_wind_time_gust'])
                ?.toString();
            if (gustTime == null || gustTime.isEmpty) {
              gustTime = (item['Time_Stamp'] ?? item['TimeStamp'])?.toString();
            }
          }
          int filledFlag = int.tryParse(item['filled_flag']?.toString() ?? '0') ?? 0;
          parametersData[key]!.add(ChartData(
              timestamp: timestamp,
              value: value,
              gustTime: gustTime,
              filledFlag: filledFlag));
              
          // Extract corrected_fields
          if (item['corrected_fields'] != null && item['corrected_fields'] is Map) {
            final correctedFields = item['corrected_fields'] as Map;
            final lowerKey = key.toLowerCase();
            if (correctedFields.containsKey(lowerKey) && correctedFields[lowerKey]['corrected_value'] != null) {
              final correctedRaw = correctedFields[lowerKey]['corrected_value'];
              final correctedValue = double.tryParse(correctedRaw.toString());
              if (correctedValue != null) {
                final correctedKey = 'CorrectedField_$key';
                if (parametersData[correctedKey] == null) {
                  parametersData[correctedKey] = [];
                }
                parametersData[correctedKey]!.add(ChartData(
                  timestamp: timestamp,
                  value: correctedValue,
                  gustTime: gustTime,
                  filledFlag: filledFlag,
                ));
              }
            }
          }
        }
      }
    }

    // Update latest battery if requested
    if (onBatteryUpdate != null) {
      for (var item in items.reversed) {
        if (item != null) {
          final batVal = item[batteryKey] ??
              item['BatteryVoltage'] ??
              item['Battery_Voltage'] ??
              item['battery_voltage'];
          if (batVal != null) {
            final bat = double.tryParse(batVal.toString()) ?? 0.0;
            if (bat != 0.0) {
              onBatteryUpdate(bat);
              break;
            }
          }
        }
      }
    }

    // Update latest signal strength if requested
    if (onSignalStrengthUpdate != null) {
      for (var item in items.reversed) {
        if (item != null) {
          final sigVal = item[signalStrengthKey] ??
              item['SignalStrength'] ??
              item['Signal_Strength'] ??
              item['signal_strength'];
          if (sigVal != null) {
            final rssi = double.tryParse(sigVal.toString()) ?? 0.0;
            if (rssi != 0) {
              onSignalStrengthUpdate(rssi);
              break;
            }
          }
        }
      }
    }

    // Update latest SD card status if requested
    if (onSDcardStatusUpdate != null) {
      for (var item in items.reversed) {
        if (item != null && item[sdCardKey] != null) {
          onSDcardStatusUpdate(item[sdCardKey].toString());
          break;
        }
      }
    }

    // Update latest Max Wind Gust Time range if requested
    if (onMaxWindGustTimeUpdate != null) {
      for (var item in items.reversed) {
        if (item != null) {
          final rawTime = item[maxGustTimeKey] ??
              item['max_wind_time_gust'] ??
              item['Time_Stamp'] ??
              item['TimeStamp'];
          if (rawTime != null) {
            final timeRange = rawTime.toString().trim();
            if (timeRange.isNotEmpty && timeRange.toLowerCase() != 'null') {
              onMaxWindGustTimeUpdate(timeRange);
              break;
            }
          }
        }
      }
    }

    // ✅ Update Squall and Daily Temp values from MOST RECENT item
    bool foundSquallSpeed = onSquallSpeedUpdate == null;
    bool foundSquallDir = onSquallDirectionUpdate == null;
    bool foundSquallTime = onSquallTimeUpdate == null;
    bool foundDailyMax = onDailyMaxTempUpdate == null;
    bool foundDailyMin = onDailyMinTempUpdate == null;
    bool foundPanelVolt = onPanelVoltageUpdate == null;
    bool foundTilt = onTiltUpdate == null;

    for (var item in items.reversed) {
      if (item == null) continue;

      if (!foundSquallSpeed &&
          (item['SquallWindSpeed'] != null ||
              item['Squall_wind_speed'] != null)) {
        onSquallSpeedUpdate!(double.tryParse(
                (item['SquallWindSpeed'] ?? item['Squall_wind_speed'])
                    .toString()) ??
            0.0);
        foundSquallSpeed = true;
      }
      if (!foundSquallDir &&
          (item['SquallWindDirection'] != null ||
              item['Squall_wind_direction'] != null)) {
        onSquallDirectionUpdate!(double.tryParse(
                (item['SquallWindDirection'] ?? item['Squall_wind_direction'])
                    .toString()) ??
            0.0);
        foundSquallDir = true;
      }
      if (!foundSquallTime && item['SquallWindTime'] != null) {
        onSquallTimeUpdate!(item['SquallWindTime'].toString());
        foundSquallTime = true;
      }
      if (!foundDailyMax &&
          (item['DailyMaximumTemperature'] != null ||
              item['daily_maximum_temperature'] != null)) {
        onDailyMaxTempUpdate!(double.tryParse(
                (item['DailyMaximumTemperature'] ??
                        item['daily_maximum_temperature'])
                    .toString()) ??
            0.0);
        foundDailyMax = true;
      }
      if (!foundDailyMin &&
          (item['DailyMinimumTemperature'] != null ||
              item['daily_minimum_temperature'] != null)) {
        onDailyMinTempUpdate!(double.tryParse(
                (item['DailyMinimumTemperature'] ??
                        item['daily_minimum_temperature'])
                    .toString()) ??
            0.0);
        foundDailyMin = true;
      }
      if (!foundPanelVolt &&
          (item['PanelVoltage'] != null || item['Panel_Voltage'] != null)) {
        onPanelVoltageUpdate!(double.tryParse(
                (item['PanelVoltage'] ?? item['Panel_Voltage']).toString()) ??
            0.0);
        foundPanelVolt = true;
      }
      if (!foundTilt && (item['Tilt'] != null || item['Tilt_sensor'] != null)) {
        onTiltUpdate!(
            double.tryParse((item['Tilt'] ?? item['Tilt_sensor']).toString()) ??
                0.0);
        foundTilt = true;
      }

      if (foundSquallSpeed &&
          foundSquallDir &&
          foundSquallTime &&
          foundDailyMax &&
          foundDailyMin &&
          foundPanelVolt &&
          foundTilt) {
        break;
      }
    }

    // Clean up empty lists
    parametersData.removeWhere((_, list) => list.isEmpty);

    return parametersData;
  }

// ───────────────────────────────────────────────────────────────────────────────
//                    SINGLE VALUE CHART PARSERS
// ───────────────────────────────────────────────────────────────────────────────
  List<ChartData> _parseBDChartData(Map<String, dynamic> data, String type) {
    final items = data['items'] ?? [];
    return items.map<ChartData>((item) {
      if (item == null) return ChartData(timestamp: DateTime.now(), value: 0.0);

      return ChartData(
        timestamp: parseSensorDate(item['human_time']),
        value: double.tryParse(item[type]?.toString() ?? '0') ?? 0.0,
      );
    }).toList();
  }

  List<ChartData> _parseChartData(Map<String, dynamic> data, String type) {
    final items = data['weather_items'] ?? [];
    return items.map<ChartData>((item) {
      if (item == null) return ChartData(timestamp: DateTime.now(), value: 0.0);

      double value = 0.0;
      if (type == 'RainLevel' && item[type] is String) {
        value = double.tryParse(item[type].toString().split(' ')[0]) ?? 0.0;
      } else {
        value = double.tryParse(item[type]?.toString() ?? '0') ?? 0.0;
      }

      return ChartData(
        timestamp: parseSensorDate(item['HumanTime']),
        value: value,
      );
    }).toList();
  }

  List<ChartData> _parseRainDifferenceData(Map<String, dynamic> data) {
    final items = data['rain_hourly_items'] ?? [];
    return items.map<ChartData>((item) {
      if (item == null) return ChartData(timestamp: DateTime.now(), value: 0.0);

      final rainStr = item['RainDifference']?.toString().split(' ')[0] ?? '0';
      final value = double.tryParse(rainStr) ?? 0.0;

      return ChartData(
        timestamp: DateTime.parse(item['HourTimestamp'] ?? ''), // usually ISO
        value: value,
      );
    }).toList();
  }

  List<ChartData> _parsewaterChartData(Map<String, dynamic> data, String type) {
    final items = data['items'] ?? [];
    return items.map<ChartData>((item) {
      if (item == null) return ChartData(timestamp: DateTime.now(), value: 0.0);

      final valueStr = item[type]?.toString().split(' ')[0] ?? '0';
      final value = double.tryParse(valueStr) ?? 0.0;

      return ChartData(
        timestamp: parseSensorDate(item['HumanTime']),
        value: value,
      );
    }).toList();
  }

// ───────────────────────────────────────────────────────────────────────────────
//                    MULTI-PARAMETER SENSORS (using generic)
// ───────────────────────────────────────────────────────────────────────────────

  Map<String, List<ChartData>> _parseSMParametersData(dynamic data) {
    Map<String, List<ChartData>> result = {};
    List<dynamic> items = [];

    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic> && data['items'] != null) {
      items = data['items'];
    }

    if (items.isEmpty) {
      return result;
    }

    // ✅ Extract firmware
    _extractFirmwareVersion(items);
    for (var item in items) {
      DateTime timestamp;
      try {
        String timeStr = (item['TimeStamp'] ??
                item['Time_Stamp'] ??
                item['human_time'] ??
                item['HumanTime'] ??
                item['timestamp'] ??
                item['EpochTime'] ??
                '')
            .toString();
        timestamp = parseSensorDate(timeStr);
      } catch (e) {
        print("❌ SM Timestamp parse error: $e for item: $item");
        continue;
      }

      item.forEach((key, value) {
        if ([
          'TimeStamp',
          'TimeStampFormatted',
          'Topic',
          'IMEINumber',
          'DeviceId',
          'FirmwareVersion',
          'Longitude',
          'Latitude',
        ].contains(key)) return;

        // Skip null or "Null" string values
        if (value == null ||
            (value is String && value.toLowerCase() == 'null')) {
          return;
        }

        // Parse numeric value
        double? numValue;
        if (value is num) {
          numValue = value.toDouble();
        } else if (value is String) {
          numValue = double.tryParse(value);
        }

        // ✅ FIX: Allow 0 values (don't skip them)
        if (numValue != null) {
          if ((key.toLowerCase() == 'batteryvoltage' ||
                  key.toLowerCase() == 'battery_voltage') &&
              numValue == 0.0) {
            if (result[key] != null && result[key]!.isNotEmpty) {
              numValue = result[key]!.last.value;
            }
          }

          if (key == 'BatteryVoltage') {
            _lastBatteries[widget.deviceName] = numValue;
          }
          if (key == 'SignalStrength') {
            _lastSignalStrengths[widget.deviceName] = numValue;
          }
          if (key == 'Tilt' || key == 'Tilt_sensor') {
            _lastTiltStatuses[widget.deviceName] = numValue;
          }
          if (key == 'SDcardStatus') {
            _lastSDCardStatuses[widget.deviceName] = value.toString();
          }

          result.putIfAbsent(key, () => []);
          result[key]!.add(ChartData(
              timestamp: timestamp,
              value: numValue,
              filledFlag:
                  int.tryParse(item['filled_flag']?.toString() ?? '0') ?? 0));
        }
      });
    }

    return result;
  }

  DataRow buildDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Map<String, List<double?>> _calculateWeatherStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        'current': [null],
      };
    }

    double? current = data.last.value; // Get the most recent (current) value

    return {
      'current': [current], // Return the last (current) value
    };
  }

  Widget buildWeatherStatisticsTable() {
    final temperatureStats = _calculateWeatherStatistics(
        _parametersData['CurrentTemperature'] ?? []);
    final humidityStats =
        _calculateWeatherStatistics(_parametersData['CurrentHumidity'] ?? []);
    final lightIntensityStats =
        _calculateWeatherStatistics(_parametersData['LightIntensity'] ?? []);
    final solarIrradianceStats =
        _calculateWeatherStatistics(_parametersData['Radiation'] ?? []);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Centered heading for the table
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Center(
                child: Text(
                  'Data',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
                ),
                child: DataTable(
                  horizontalMargin: 16,
                  // columnSpacing: screenWidth < 700 ? 70 : 30,

                  columnSpacing: screenWidth < 362
                      ? 50
                      : screenWidth < 392
                          ? 80
                          : screenWidth < 500
                              ? 120
                              : screenWidth < 800
                                  ? 180
                                  : 70,

                  columns: [
                    DataColumn(
                      label: Text(
                        'Parameter',
                        style: TextStyle(
                            fontSize: headerFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue),
                      ),
                    ),
                    DataColumn(
                      label: Padding(
                        padding: EdgeInsets.only(
                          right: MediaQuery.of(context).size.width *
                              0.04, // Adjust padding based on screen width
                        ), // Adjust the value as needed
                        child: Text(
                          'Recent Value',
                          style: TextStyle(
                              fontSize: headerFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                  rows: [
                    buildWeatherDataRow(
                        'Temperature', temperatureStats, fontSize),
                    buildWeatherDataRow('Humidity', humidityStats, fontSize),
                    buildWeatherDataRow(
                        'Light Intensity', lightIntensityStats, fontSize),
                    buildWeatherDataRow(
                        'Solar Irradiance', solarIrradianceStats, fontSize),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow buildWeatherDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  Widget buildRainDataTable() {
    // Use the string values directly from the API
    String currentRain = _mostRecentHourRain ?? "-"; // If null, show "-"
    String totalRainLast24Hours =
        _totalRainLast24Hours ?? "-"; // If null, show "-"

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 18 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6), // Semi-transparent background
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'Rain Data',
                style: TextStyle(
                  fontSize: headerFontSize,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 16),
            DataTable(
              columnSpacing: screenWidth < 380
                  ? 70
                  : screenWidth < 500
                      ? 120
                      : screenWidth < 800
                          ? 200
                          : 50,
              columns: [
                DataColumn(
                  label: Text(
                    'Timeframe',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Value',
                    style: TextStyle(
                        fontSize: screenWidth < 800 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Recent Hour',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      currentRain,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
                DataRow(
                  cells: [
                    DataCell(Text(
                      'Last 24 Hours',
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                    DataCell(Text(
                      totalRainLast24Hours,
                      style: TextStyle(fontSize: fontSize, color: Colors.white),
                    )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Calculate average, min, and max values
  Map<String, List<double?>> _calculateNHStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  // Create a table displaying statistics
  Widget buildNHStatisticsTable() {
    final ammoniaStats =
        _calculateNHStatistics(_parametersData['AMMONIA'] ?? []);
    final temppStats = _calculateNHStatistics(_parametersData['TEMP'] ?? []);
    final humStats = _calculateNHStatistics(_parametersData['HUMIDITY'] ?? []);

    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth < 800 ? 13 : 16;
    double headerFontSize = screenWidth < 800 ? 16 : 22;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white, width: 1),
          borderRadius: BorderRadius.circular(16),
          color: Colors.black.withOpacity(0.6),
        ),
        margin: EdgeInsets.all(10),
        padding: EdgeInsets.all(8),
        width: screenWidth < 800 ? double.infinity : 500,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: screenWidth < 800 ? screenWidth - 32 : 500,
            ),
            child: DataTable(
              horizontalMargin: 16,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Text(
                    'Parameter',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Current',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Min',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Max',
                    style: TextStyle(
                        fontSize: headerFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue),
                  ),
                ),
              ],
              rows: [
                buildDataRow('AMMONIA', ammoniaStats, fontSize),
                buildDataRow('TEMP', temppStats, fontSize),
                buildDataRow('HUMIDITY', humStats, fontSize),
              ],
            ),
          ),
        ),
      ),
    );
  }

  DataRow buildNHDataRow(
      String parameter, Map<String, List<double?>> stats, double fontSize) {
    return DataRow(cells: [
      DataCell(Text(parameter,
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['current']?[0] != null
              ? stats['current']![0]!.toStringAsFixed(2)
              : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['min']?[0] != null ? stats['min']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
      DataCell(Text(
          stats['max']?[0] != null ? stats['max']![0]!.toStringAsFixed(2) : '-',
          style: TextStyle(fontSize: fontSize, color: Colors.white))),
    ]);
  }

  // Calculate average, min, and max values
  Map<String, List<double?>> _calculateITStatistics(List<ChartData> data) {
    if (data.isEmpty) {
      return {
        // 'average': [null],
        'current': [null],
        'min': [null],
        'max': [null],
      };
    }
    // double sum = 0.0;
    double? current = data.last.value;
    double min = double.infinity;
    double max = double.negativeInfinity;

    for (var entry in data) {
      if (entry.value < min) min = entry.value;
      if (entry.value > max) max = entry.value;
    }

    return {
      'current': [current],
      'min': [min],
      'max': [max],
    };
  }

  Future<void> _selectDate() async {
    print('selectDate: Opening date picker');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(1970),
      lastDate: DateTime(2027),
    );

    // ONLY proceed if the user pressed "OK" and selected a date
    if (picked != null && mounted) {
      print('selectDate: User picked $picked');
      setState(() {
        _selectedDay = picked; // Update the selected day
      });

      // NOW call reloadData. The dialog will show up here.
      _reloadData(range: 'single', selectedDate: _selectedDay);
    } else {
      // User pressed "Cancel" or didn't pick a date
      print('selectDate: No new date selected.');
    }
    // The reloadData call that was here has been moved inside the 'if' block.
  }

  Future<void> _selectMonthYear() async {
    final List<String> months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final List<int> years = [DateTime.now().year, DateTime.now().year - 1];

    int? tempMonth = _selectedMonth;
    int? tempYear = _selectedYear;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                'Select Month and Year',
                style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<int>(
                    value: tempMonth,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(months[index]),
                      );
                    }),
                    onChanged: (val) => setDialogState(() => tempMonth = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<int>(
                    value: tempYear,
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    items: years.map((year) {
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => tempYear = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tempMonth != null && tempYear != null) {
                      setState(() {
                        _selectedMonth = tempMonth!;
                        _selectedYear = tempYear!;
                      });
                      _reloadData(range: '30days');
                      _fetchDataForRange('30days');
                      Navigator.pop(context); // Close dialog
                    }
                  },
                  child: const Text('Select'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 🟢 REPLACE your old _reloadData function with this new one:

  void _reloadData({String range = 'single', DateTime? selectedDate}) async {
    // 1. Set internal loading state & START the animation
    // We start this *before* showing the dialog so the icon is already spinning
    setState(() {
      _isLoading = true; // This will disable the refresh button
      _selectedParam = null;
      _isParamHovering.updateAll((key, value) => false);
      _rotationController.repeat(); // <-- Starts the spinning
    });

    // 2. Show the new loading dialog
    showDialog(
      context: context,
      barrierDismissible: false, // User can't dismiss it
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          backgroundColor:
              isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Use the same rotating refresh icon from the app bar
                RotationTransition(
                  turns:
                      Tween(begin: 0.0, end: 1.0).animate(_rotationController),
                  child: Icon(
                    Icons.refresh,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    size: 28, // A bit larger for the dialog
                  ),
                ),
                SizedBox(width: 24),
                // Use a Column for two lines of text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Fetching your data...",
                      style: TextStyle(
                        fontSize: 17, // Slightly larger
                        fontWeight: FontWeight.bold, // Bolder
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Please wait a moment.", // Added "some more" text
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // 3. Run fetch operations
    try {
      await Future.wait([
        _fetchDataForRange(range, selectedDate),
        _fetchDeviceDetails(),
      ]);
    } catch (e) {
      print("Error during parallel reload: $e");
      // Optionally show an error SnackBar here
    } finally {
      // 4. Hide loading dialog AND stop animation
      if (mounted) {
        Navigator.of(context).pop(); // This closes the dialog
        setState(() {
          _isLoading = false; // Re-enable refresh button
          _rotationController.stop(canceled: true);
        });
      }
    }
  }

  Widget _buildHorizontalStatsRow(bool isDarkMode) {
    if (_config == null || _parametersData.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayParams = _config!.parameters.where((p) {
      if (p.isMetadata) return false;
      if (p.unit.isEmpty && p.key != 'aqi') return false;
      if (p.key == 'WindDirection' ||
          p.key == 'WindDir' ||
          p.key == 'CurrentWindDirection' ||
          p.key == 'now_wind_direction' ||
          p.key == 'NowWindDirection') return false;
      if (p.key == 'BatteryVoltage' ||
          p.key == 'SignalStrength' ||
          p.key == 'Battery_Voltage' ||
          p.key == 'Signal_Strength') return false;

      final data = _parametersData[p.key];
      return data != null && data.isNotEmpty;
    }).toList();

    if (displayParams.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    // Calculate required width for all cards in one row (approx 165px per card including padding)
    final double minRequiredWidth = displayParams.length * 165.0;
    final bool useSingleRow =
        screenWidth >= minRequiredWidth && screenWidth >= 600;

    final cards = displayParams.map((p) {
      var data = _parametersData[p.key]!;
      final correctedField = _parametersData['CorrectedField_${p.key}'];
      if (correctedField != null && correctedField.isNotEmpty) {
        data = _mergeCorrectedData(data, correctedField);
      } else if (p.displayName.toLowerCase().contains('temperature')) {
        final corrected = _parametersData['CorrectedTemp'];
        if (corrected != null && corrected.isNotEmpty) {
          data = _mergeCorrectedData(data, corrected);
        }
      } else if (p.displayName.toLowerCase().contains('humidity')) {
        final corrected = _parametersData['CorrectedHumidity'];
        if (corrected != null && corrected.isNotEmpty) {
          data = _mergeCorrectedData(data, corrected);
        }
      }
      final current = data.last.value;

      final values = data.map((d) => d.value).toList();
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);

      double? windDir;
      if (p.key == 'WindSpeed' ||
          p.key == 'Wind_Speed' ||
          p.key == 'CurrentWindSpeed' ||
          p.key == 'now_wind_speed' ||
          p.key == 'NowWindSpeed') {
        windDir = _parametersData['WindDirection']?.last.value ??
            _parametersData['WindDir']?.last.value ??
            _parametersData['Wind-Dir']?.last.value ??
            _parametersData['CurrentWindDirection']?.last.value ??
            _parametersData['now_wind_direction']?.last.value ??
            _parametersData['NowWindDirection']?.last.value;
      }

      double finalCurrent = current;
      double finalMin = min;
      double finalMax = max;
      String finalUnit = p.unit;

      if ((p.key == 'WindSpeed' || p.key == 'Wind_Speed') && _isKmPerHour) {
        finalCurrent = current * 3.6;
        finalMin = min * 3.6;
        finalMax = max * 3.6;
        finalUnit = 'km/h';
      }

      double? totalRainfall;
      if (p.key.toLowerCase().contains('rain')) {
        // For AM (CP01) devices: use the last Rainfall_Cumulative value directly.
        // The API reports a running cumulative total that resets daily,
        // so the most-recent record always holds the correct cumulative value.
        // For multi-day ranges, we sum the last Rainfall_Cumulative value seen
        // per calendar day (each day's final reading = that day's total rain).
        if (widget.deviceName.startsWith('AM') &&
            p.key == 'Rainfall' &&
            _parametersData.containsKey('Rainfall_Cumulative') &&
            _parametersData['Rainfall_Cumulative']!.isNotEmpty) {
          final cumulativeData = _parametersData['Rainfall_Cumulative']!;

          if (_lastSelectedRange == 'single') {
            // Single day: just take the last (most recent) cumulative value.
            totalRainfall = cumulativeData.last.value;
          } else {
            // Multi-day range: group cumulative readings by calendar date,
            // take the LAST value per day (= that day's total), then sum.
            final Map<String, double> dailyLast = {};
            for (final d in cumulativeData) {
              final dateKey =
                  '${d.timestamp.year}-${d.timestamp.month.toString().padLeft(2, '0')}-${d.timestamp.day.toString().padLeft(2, '0')}';
              dailyLast[dateKey] = d.value; // overwrite → keeps last of the day
            }
            totalRainfall =
                dailyLast.values.fold<double>(0.0, (sum, v) => sum + v);
          }
        } else {
          bool isIncremental = widget.deviceName.startsWith('JW');
          totalRainfall =
              _calculateTotalRainfall(data, isIncremental: isIncremental);
        }
      }

      return Padding(
        key: ValueKey('card_${p.key}'),
        padding: const EdgeInsets.all(8.0),
        child: _MetricSummaryCard(
          label: p.key == 'CurrentWindSpeed' ||
                  p.key == 'WindSpeed' ||
                  p.key == 'now_wind_speed'
              ? 'WIND'
              : p.displayName.toUpperCase(),
          current: finalCurrent,
          min: finalMin,
          max: finalMax,
          totalRainfall: totalRainfall,
          unit: finalUnit,
          isDarkMode: isDarkMode,
          color: _getParamColor(
              (p.key == 'WindSpeed' || p.key == 'now_wind_speed')
                  ? 'Wind'
                  : p.displayName),
          icon: _getParamIcon(
              (p.key == 'WindSpeed' || p.key == 'now_wind_speed')
                  ? 'Wind'
                  : p.displayName),
          windDirection: windDir,
          isRainfall: p.key.toLowerCase().contains('rain'),
          isWind: p.key.toLowerCase().contains('wind'),
          maxGustTime: (p.key == 'MaximumWindGustSpeed' ||
                  p.key == 'Maximum_wind_gust_speed' ||
                  p.key == 'max_wind_gust')
              ? _lastMaxGustTimes[widget.deviceName]
              : null,
          squallSpeed: (p.key == 'WindSpeed' ||
                  p.key == 'Wind_Speed' ||
                  p.key == 'CurrentWindSpeed' ||
                  p.key == 'now_wind_speed')
              ? _lastSquallSpeeds[widget.deviceName]
              : null,
          squallDirection: (p.key == 'WindSpeed' ||
                  p.key == 'Wind_Speed' ||
                  p.key == 'CurrentWindSpeed' ||
                  p.key == 'now_wind_speed')
              ? _lastSquallDirections[widget.deviceName]
              : null,
          squallTime: (p.key == 'WindSpeed' ||
                  p.key == 'Wind_Speed' ||
                  p.key == 'CurrentWindSpeed' ||
                  p.key == 'now_wind_speed')
              ? _lastSquallTimes[widget.deviceName]
              : null,
          tiltStatus: (p.key == 'MaximumWindGustSpeed' ||
                  p.key == 'Maximum_wind_gust_speed' ||
                  p.key == 'max_wind_gust')
              ? _lastTiltStatuses[widget.deviceName]
              : null,
          dailyMaxTemp: p.displayName.toLowerCase().contains('temperature')
              ? _lastDailyMaxTemps[widget.deviceName]
              : null,
          dailyMinTemp: p.displayName.toLowerCase().contains('temperature')
              ? _lastDailyMinTemps[widget.deviceName]
              : null,
          onTap: () =>
              _scrollToChart(p.key == 'WindSpeed' ? 'Wind' : p.displayName),
        ),
      );
    }).toList();

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: double.infinity,
      child: useSingleRow
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: cards
                    .map((card) => Expanded(
                          child: card,
                        ))
                    .toList(),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: cards,
              ),
            ),
    );
  }

  void _scrollToChart(String parameter) {
    setState(() {
      if (_selectedParam == parameter) {
        // If the same parameter is clicked again, clear the selection to remove effects
        _selectedParam = null;
      } else {
        // Scroll to the selected chart
        _selectedParam = parameter;
        final key = _chartKeys[parameter];
        if (key != null && key.currentContext != null) {
          final RenderBox renderBox =
              key.currentContext!.findRenderObject() as RenderBox;
          final position = renderBox.localToGlobal(Offset.zero).dy;
          final scrollPosition = _scrollController.offset +
              position -
              MediaQuery.of(context).padding.top -
              kToolbarHeight;
          _scrollController.animateTo(
            scrollPosition,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  Widget _buildParamStat(String label, double? current, double? min,
      double? max, String unit, bool isDarkMode,
      {double? windDirection, VoidCallback? onTap}) {
    final Map<String, IconData> parameterIcons = {
      'Atm Pressure': Icons.compress,
      'Light Intensity': Icons.wb_sunny,
      'Visibility': Icons.wb_sunny,
      'Rainfall': Icons.cloudy_snowing,
      'Rainfall Minutely': Icons.cloudy_snowing,
      'Rainfall Daily': Icons.cloudy_snowing,
      'Air Temperature': Icons.thermostat,
      'Soil Temperature': Icons.thermostat,
      'Temperature': Icons.thermostat,
      'Wind': Icons.air,
      'Humidity': Icons.water,
      'Air Humidity': Icons.water,
      'Soil Humidity': Icons.water,
      'TDS': Icons.water_drop,
      'COD': Icons.science,
      'BOD': Icons.science,
      'pH': Icons.opacity,
      'DO': Icons.bubble_chart,
      'EC': Icons.electrical_services,
      'Ammonia': Icons.cloud,
      'Pressure': Icons.compress,
      'Rain Level': Icons.cloudy_snowing,
      'Radiation': Icons.wb_sunny,
      'DO Value': Icons.bubble_chart,
      'DO Percentage': Icons.percent,
      'Potassium': Icons.bolt,
      'Nitrogen': Icons.grass,
      'Phosphorus': Icons.local_florist,
      'Salinity': Icons.waves,
      'Electrical Conductivity': Icons.electric_bolt,

      // ✅ SEN66 Air Quality Icons
      'PM1.0': Icons.blur_on,
      'PM2.5': Icons.blur_on,
      'PM4': Icons.blur_on,
      'PM10': Icons.blur_on,
      'AQI': Icons.air,
      'CO₂': Icons.co2,
      'VOC': Icons.cloud_queue,
      'NOx': Icons.cloud,
    };

    String displayValue = current != null ? current.toStringAsFixed(2) : '--';

    if (label == 'Wind') {
      // Extract just the speed unit (before the comma)
      String speedUnit = unit.contains(',') ? unit.split(',')[0].trim() : unit;
      if (windDirection != null) {
        displayValue =
            '${current?.toStringAsFixed(2) ?? '--'} $speedUnit (${windDirection.toStringAsFixed(0)}°)';
      } else {
        displayValue = '${current?.toStringAsFixed(2) ?? '--'} $speedUnit (--)';
      }
    }

    final IconData icon = parameterIcons[label] ?? Icons.help;

    bool isMobile = MediaQuery.of(context).size.width < 600;
    bool isSelected = _selectedParam == label;
    bool isHovered = _isParamHovering[label] ?? false;

    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
        }
      },
      onTapDown: (_) {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = true;
          });
        }
      },
      onTapUp: (_) {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = false;
          });
        }
      },
      onTapCancel: () {
        if (isMobile) {
          setState(() {
            _isParamHovering[label] = false;
          });
        }
      },
      child: MouseRegion(
        onEnter: (_) {
          if (!isMobile) {
            setState(() {
              _isParamHovering[label] = true;
            });
          }
        },
        onExit: (_) {
          if (!isMobile) {
            setState(() {
              _isParamHovering[label] = false;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: current != null
                ? (isSelected || isHovered
                    ? (isDarkMode
                        ? Colors.blueGrey[700]!
                        : const Color.fromARGB(255, 166, 163, 163))
                    : (isDarkMode
                        ? const Color(0xFF14212B)!
                        : Colors.grey[200]!))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: (isSelected || isHovered)
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 20.0,
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                displayValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              if (min != null)
                Text(
                  'Min: ${min.toStringAsFixed(2)} $unit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              if (max != null)
                Text(
                  'Max: ${max.toStringAsFixed(2)} $unit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewHeader(bool isDarkMode) {
    final String deviceName = _toAnnamDisplayName(widget.deviceName);
    final String? location = _getLocationForSensor(widget.deviceName);
    final String version = _firmwareVersion ?? 'v1.0.0';

    final String prefix = _getPrefix(widget.deviceName);
    final String idStr = widget.deviceName.substring(prefix.length);
    final int? targetIdNum = int.tryParse(idStr);

    DeviceStatus? currentDevice;
    try {
      currentDevice = _deviceStatuses.firstWhere(
        (d) {
          final String dIdStr = d.deviceId.replaceAll(RegExp(r'\D'), '');
          final int? dIdNum = int.tryParse(dIdStr);

          return d.activityType == prefix &&
              (d.deviceId == idStr ||
               dIdStr == idStr ||
               d.deviceId == widget.deviceName ||
               (dIdNum != null && dIdNum == targetIdNum));
        },
      );
    } catch (_) {
      currentDevice = DeviceStatus(
          deviceId: widget.deviceName,
          lastReceivedTime: 'N/A',
          activityType: prefix);
    }

    bool isLive = false;
    if (currentDevice?.lastReceivedTime != 'N/A') {
      try {
        final lastTime = DateFormat('dd-MM-yyyy HH:mm:ss')
            .parse(currentDevice!.lastReceivedTime);
        isLive = DateTime.now().difference(lastTime).inMinutes < 60;
      } catch (_) {}
    }

    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Theme Palette
    final bgColor =
        isDarkMode ? const Color(0xFF0B141D) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF14212B) : Colors.white;
    final appBarColor =
        isDarkMode ? const Color(0xFF14212B) : const Color(0xFF1976D2);
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

    if (isMobile) {
      final topPadding = MediaQuery.of(context).padding.top;
      return Container(
        padding: EdgeInsets.fromLTRB(
            16, topPadding > 0 ? topPadding + 10 : 20, 16, 12),
        color: appBarColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      text: deviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        TextSpan(
                          text: '  $version',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLiveIndicator(isLive, fontSize: 9),
                        const SizedBox(width: 4),
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 1.0)
                              .animate(_rotationController),
                          child: IconButton(
                            icon: const Icon(Icons.refresh_rounded,
                                color: Colors.white70, size: 20),
                            onPressed: () =>
                                _reloadData(range: _lastSelectedRange),
                            tooltip: 'Refresh Data',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    if (!isLive) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Last active: ${currentDevice?.lastReceivedTime ?? "N/A"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 0),
            Row(
              children: [
                const SizedBox(width: 36), // Offset for arrow_back
                const Icon(Icons.location_on, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location ?? "Unknown Location",
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLive)
              _buildMobileStatusBox(
                  currentDevice, isDarkMode, cardColor, borderColor),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      color: appBarColor,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    text: deviceName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: '  $version',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      location ?? "Unknown Location",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Last active: ${currentDevice?.lastReceivedTime ?? "N/A"}',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  _buildLiveIndicator(isLive),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeaderStatusIndicators(isDarkMode),
                  const SizedBox(width: 8),
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 1.0)
                        .animate(_rotationController),
                    child: IconButton(
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white70, size: 20),
                      onPressed: () => _reloadData(range: _lastSelectedRange),
                      tooltip: 'Refresh Data',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveIndicator(bool isLive, {double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLive
            ? Colors.green.withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isLive
                ? Colors.green.withOpacity(0.5)
                : Colors.grey.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 3,
            backgroundColor: isLive ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            isLive ? 'Live' : 'Offline',
            style: TextStyle(
              color: isLive ? Colors.green : Colors.grey,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatusBox(DeviceStatus? device, bool isDarkMode,
      Color cardColor, Color borderColor) {
    final batteryVal = _lastBatteries[widget.deviceName];
    final signalVal = _lastSignalStrengths[widget.deviceName];
    final sdStatus = _lastSDCardStatuses[widget.deviceName];
    final tiltVal = _lastTiltStatuses[widget.deviceName];

    final bool isWD = widget.deviceName.startsWith('WD');
    String batteryText = 'N/A';
    IconData batteryIcon = Icons.battery_unknown;
    Color batteryColor = Colors.grey;

    if (batteryVal != null) {
      final double percentage =
          isWD ? batteryVal : _convertVoltageToPercentage(batteryVal);
      batteryText = '${percentage.toStringAsFixed(2)}%';
      batteryIcon = isWD
          ? _getBatteryIcon(percentage.toInt())
          : _getpercentBatteryIcon(batteryVal);
      batteryColor = isWD
          ? _getBatteryLevelColor(percentage.toInt())
          : _getpercentBatteryColor(batteryVal);
    }

    String timeStr = 'N/A';
    if (device?.lastReceivedTime != null && device?.lastReceivedTime != 'N/A') {
      try {
        // Show date on one line and time on another
        timeStr = device!.lastReceivedTime.replaceFirst(' ', '\n');
      } catch (_) {}
    }

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final labelColor = isDarkMode ? Colors.white54 : Colors.black54;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _buildStatusBoxItem(
                'SIGNAL',
                signalVal != null
                    ? '${signalVal.toStringAsFixed(1)} dBm'
                    : 'N/A',
                Icons.signal_cellular_alt,
                _getSignalColor(signalVal),
                textColor,
                labelColor,
              ),
            ),
            VerticalDivider(color: borderColor, thickness: 1, width: 1),
            Expanded(
              child: _buildStatusBoxItem(
                'BATTERY',
                batteryText,
                batteryIcon,
                batteryColor,
                textColor,
                labelColor,
              ),
            ),
            VerticalDivider(color: borderColor, thickness: 1, width: 1),
            Expanded(
              child: _buildStatusBoxItem(
                'SD CARD',
                sdStatus ?? 'N/A',
                _getSDCardIcon(sdStatus),
                _getSDCardColor(sdStatus),
                textColor,
                labelColor,
              ),
            ),
            VerticalDivider(color: borderColor, thickness: 1, width: 1),
            Expanded(
              child: _buildStatusBoxItem(
                'LAST ACTIVE',
                timeStr,
                Icons.sync,
                isDarkMode ? Colors.white60 : Colors.black45,
                textColor,
                labelColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBoxItem(String label, String value, IconData icon,
      Color color, Color textColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
                color: labelColor, fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color.withOpacity(0.8)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 10, // Slightly smaller to fit better
                      height: 1.1,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getSignalColor(double? dBm) {
    if (dBm == null) return Colors.grey;
    if (dBm > -70) return Colors.green;
    if (dBm > -85) return Colors.amber;
    return Colors.red;
  }

  Color _getBatteryLevelColor(int percentage) {
    if (percentage > 80) return Colors.green;
    if (percentage > 30) return Colors.blue;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isDarkMode ? const Color(0xFF0B141D) : const Color(0xFFF5F7FA);
    final surfaceColor = isDarkMode ? const Color(0xFF14212B) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final strongText = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      body: Column(
        children: [
          _buildNewHeader(isDarkMode),
          _buildHorizontalStatsRow(isDarkMode),
          // Control Row (New Time Range Buttons + Status)
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 0.0, bottom: 8.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 32,
                ),
                child: Builder(
                  builder: (context) {
                    final bool isLarge =
                        MediaQuery.of(context).size.width > 1100;

                    final Widget timeFiltersRow = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        'single',
                        '7days',
                        '30days',
                        '3months',
                        '1year'
                      ].map((String value) {
                        String label = value == 'single'
                            ? DateFormat('dd/MM/yyyy').format(_selectedDay)
                            : value == '7days'
                                ? '7 Days'
                                : value == '30days'
                                    ? '1 Month'
                                    : value == '3months'
                                        ? '3 Months'
                                        : '1 Year';

                        final bool isSelected = _lastSelectedRange == value;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: InkWell(
                            onTap: () {
                              if (value == 'single') {
                                _selectDate();
                              } else if (value == '30days') {
                                _selectMonthYear();
                              } else {
                                _reloadData(range: value);
                                _fetchDataForRange(value);
                              }
                              setState(() => _lastSelectedRange = value);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : surfaceColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blueAccent
                                      : borderColor,
                                  width: 1,
                                ),
                                boxShadow: [
                                  if (!isDarkMode)
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                ],
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : strongText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );

                    final Widget dropdownsRow = (_isAdmin &&
                            _config != null &&
                            !_isLoading)
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isLarge) const SizedBox(width: 16),
                              if (MediaQuery.of(context).size.width > 800)
                                PopupMenuButton<int>(
                                  tooltip: 'Graphs per Row',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: surfaceColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: borderColor,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        if (!isDarkMode)
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.grid_view,
                                            size: 16, color: strongText),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Graphs per Row: $_graphsPerRow',
                                          style: TextStyle(
                                            color: strongText,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  onSelected: (int value) {
                                    setState(() {
                                      _graphsPerRow = value;
                                    });
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem(
                                      value: 1,
                                      child: Text('1 per row'),
                                    ),
                                    const PopupMenuItem(
                                      value: 2,
                                      child: Text('2 per row'),
                                    ),
                                    if (MediaQuery.of(context).size.width >
                                        1100)
                                      const PopupMenuItem(
                                        value: 3,
                                        child: Text('3 per row'),
                                      ),
                                  ],
                                ),
                              const SizedBox(width: 8),
                              PopupMenuButton<String>(
                                tooltip: 'Compare Sensors',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      if (!isDarkMode)
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.compare_arrows,
                                          size: 16, color: strongText),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Compare Sensors',
                                        style: TextStyle(
                                          color: strongText,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                itemBuilder: (BuildContext context) {
                                  List<StateSetter> setters = [];

                                  final allValidDisplayNames =
                                      _config!.parameters
                                          .where((p) {
                                            if (p.isMetadata) return false;
                                            if (p.key == 'WindDirection' ||
                                                p.key == 'WindDir' ||
                                                p.key == 'now_wind_direction' ||
                                                p.key == 'NowWindDirection')
                                              return false;
                                            final data = _parametersData[p.key];
                                            if (data == null || data.isEmpty)
                                              return false;
                                            return true;
                                          })
                                          .map((p) {
                                            if (p.key == 'WindSpeed' ||
                                                p.key == 'Wind_Speed' ||
                                                p.key == 'now_wind_speed' ||
                                                p.key == 'NowWindSpeed') {
                                              return 'Wind';
                                            }
                                            return p.displayName;
                                          })
                                          .toSet()
                                          .toList();

                                  List<PopupMenuEntry<String>> menuItems = [
                                    PopupMenuItem<String>(
                                      value: 'actions',
                                      enabled: false,
                                      child: StatefulBuilder(
                                        builder: (context, setMenuItemState) {
                                          if (!setters
                                              .contains(setMenuItemState)) {
                                            setters.add(setMenuItemState);
                                          }
                                          bool isAllSelected = true;
                                          for (var name
                                              in allValidDisplayNames) {
                                            if (!_visibleParameters
                                                .contains(name)) {
                                              isAllSelected = false;
                                              break;
                                            }
                                          }
                                          bool isNoneSelected =
                                              _visibleParameters.isEmpty;

                                          return Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _visibleParameters.addAll(
                                                          allValidDisplayNames);
                                                    });
                                                    for (var s in setters) {
                                                      s(() {});
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                        color: isAllSelected
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey.shade600,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Select all',
                                                      style: TextStyle(
                                                        color: isAllSelected
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey.shade600,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() {
                                                      _visibleParameters
                                                          .clear();
                                                    });
                                                    for (var s in setters) {
                                                      s(() {});
                                                    }
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(vertical: 8),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      border: Border.all(
                                                        color: isNoneSelected
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey.shade600,
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      'Deselect all',
                                                      style: TextStyle(
                                                        color: isNoneSelected
                                                            ? Colors.blue
                                                            : Colors
                                                                .grey.shade600,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                  ];

                                  menuItems.addAll(allValidDisplayNames
                                      .map((String displayName) {
                                    return PopupMenuItem<String>(
                                      value: displayName,
                                      child: StatefulBuilder(
                                        builder: (context, setMenuItemState) {
                                          if (!setters
                                              .contains(setMenuItemState)) {
                                            setters.add(setMenuItemState);
                                          }
                                          return CheckboxListTile(
                                            title: Text(displayName),
                                            value: _visibleParameters
                                                .contains(displayName),
                                            onChanged: (bool? val) {
                                              setState(() {
                                                if (val == true) {
                                                  _visibleParameters
                                                      .add(displayName);
                                                } else {
                                                  _visibleParameters
                                                      .remove(displayName);
                                                }
                                              });
                                              for (var s in setters) {
                                                s(() {});
                                              }
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  }).toList());

                                  return menuItems;
                                },
                              ),
                            ],
                          )
                        : const SizedBox.shrink();

                    if (isLarge) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                              width: MediaQuery.of(context).size.width - 32),
                          timeFiltersRow,
                          if (_isAdmin && _config != null && !_isLoading)
                            Positioned(right: 0, child: dropdownsRow),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          timeFiltersRow,
                          dropdownsRow,
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bgColor,
                        isDarkMode
                            ? const Color(0xFF091520)
                            : const Color(0xFFEBF4FF),
                      ],
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: () async {
                    _reloadData(range: _lastSelectedRange);
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // Parameters and Charts

                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 100),
                            child: CircularProgressIndicator(
                                color: Colors.blueAccent),
                          )
                        else if (_config != null)
                          Wrap(
                            spacing: 0,
                            runSpacing: 0,
                            alignment: WrapAlignment.center,
                            children: _config!.parameters.where((p) {
                              if (p.isMetadata) return false;
                              if (p.key == 'WindDirection' ||
                                  p.key == 'WindDir' ||
                                  p.key == 'now_wind_direction' ||
                                  p.key == 'NowWindDirection') return false;

                              String displayName = p.displayName;
                              if (p.key == 'WindSpeed' ||
                                  p.key == 'Wind_Speed' ||
                                  p.key == 'now_wind_speed' ||
                                  p.key == 'NowWindSpeed') {
                                displayName = 'Wind';
                              }
                              if (!_visibleParameters.contains(displayName))
                                return false;

                              final data = _parametersData[p.key];
                              return data != null && data.isNotEmpty;
                            }).map((p) {
                              var data = _parametersData[p.key]!;
                              if (p.key == 'WindSpeed' ||
                                  p.key == 'Wind_Speed' ||
                                  p.key == 'now_wind_speed' ||
                                  p.key == 'NowWindSpeed') {
                                Widget windChart = _buildWindChartContainer(
                                  'Wind',
                                  data,
                                  _parametersData['WindDirection'] ??
                                      _parametersData['WindDir'] ??
                                      _parametersData['now_wind_direction'] ??
                                      _parametersData['NowWindDirection'] ??
                                      [],
                                  isDarkMode,
                                );
                                return SizedBox(
                                  width: MediaQuery.of(context).size.width > 800
                                      ? MediaQuery.of(context).size.width /
                                          _graphsPerRow
                                      : MediaQuery.of(context).size.width,
                                  child: windChart,
                                );
                              }
                              List<ChartData>? secondaryData;
                              String? secondaryTitle;
                              if (_isAdmin) {
                                final correctedField =
                                    _parametersData['CorrectedField_${p.key}'];
                                if (correctedField != null &&
                                    correctedField.isNotEmpty) {
                                  secondaryData = correctedField;
                                  secondaryTitle = 'Corrected ${p.displayName}';
                                } else if (p.displayName
                                    .toLowerCase()
                                    .contains('temperature')) {
                                  final corrected =
                                      _parametersData['CorrectedTemp'];
                                  if (corrected != null &&
                                      corrected.isNotEmpty) {
                                    secondaryData = corrected;
                                    secondaryTitle = 'Corrected Temp';
                                  }
                                } else if (p.displayName
                                    .toLowerCase()
                                    .contains('humidity')) {
                                  final corrected =
                                      _parametersData['CorrectedHumidity'];
                                  if (corrected != null &&
                                      corrected.isNotEmpty) {
                                    secondaryData = corrected;
                                    secondaryTitle = 'Corrected Humidity';
                                  }
                                }
                              } else {
                                final correctedField =
                                    _parametersData['CorrectedField_${p.key}'];
                                if (correctedField != null &&
                                    correctedField.isNotEmpty) {
                                  data = _mergeCorrectedData(data, correctedField);
                                } else if (p.displayName
                                    .toLowerCase()
                                    .contains('temperature')) {
                                  final corrected =
                                      _parametersData['CorrectedTemp'];
                                  if (corrected != null &&
                                      corrected.isNotEmpty) {
                                    data = _mergeCorrectedData(data, corrected);
                                  }
                                } else if (p.displayName
                                    .toLowerCase()
                                    .contains('humidity')) {
                                  final corrected =
                                      _parametersData['CorrectedHumidity'];
                                  if (corrected != null &&
                                      corrected.isNotEmpty) {
                                    data = _mergeCorrectedData(data, corrected);
                                  }
                                }
                              }

                              Widget chart = _buildChartContainer(
                                p.displayName,
                                data,
                                p.unit.isNotEmpty ? '(${p.unit})' : '',
                                ChartType.line,
                                isDarkMode,
                                secondaryData: secondaryData,
                                secondaryTitle: secondaryTitle,
                              );

                              return SizedBox(
                                width: MediaQuery.of(context).size.width > 800
                                    ? MediaQuery.of(context).size.width /
                                        _graphsPerRow
                                    : MediaQuery.of(context).size.width,
                                child: chart,
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 100), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDownloadOptionsDialog(context),
        backgroundColor: Colors.blueAccent,
        elevation: 6,
        child: const Icon(Icons.download_rounded, color: Colors.white),
      ),
    );
  }

// Helper method to build sidebar buttons

  Widget _buildCurrentValue(
      String parameterName, String currentValue, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align text to the top
        children: [
          // Display both parameter and value together in a single text widget
          Text(
            '$parameterName: $currentValue $unit',
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

// This method will parse the percentage string (e.g., "84%") and return the numeric value
  int _parseBatteryPercentage(String batteryPercentage) {
    try {
      // Remove the '%' symbol and parse the number
      return int.parse(batteryPercentage.replaceAll('%', ''));
    } catch (e) {
      // If parsing fails, return a default value (e.g., 0)
      return 0;
    }
  }

  IconData _getBatteryIcon(int batteryPercentage) =>
      DevicePrefixUtils.getBatteryIcon(batteryPercentage);

  IconData _getpercentBatteryIcon(double voltage) =>
      DevicePrefixUtils.getBatteryIcon(
          _convertVoltageToPercentage(voltage).toInt());

  Color _getpercentBatteryColor(double voltage) =>
      DevicePrefixUtils.getBatteryColor(
          _convertVoltageToPercentage(voltage).toInt());

  IconData _getSDCardIcon(String? status) =>
      DevicePrefixUtils.getSDCardIcon(status);

  Color _getSDCardColor(String? status) =>
      DevicePrefixUtils.getSDCardColor(status);

  int _getSignalBars(double rssi) {
    if (rssi == 0) return 0;
    if (rssi >= -55) return 4;
    if (rssi >= -70) return 3;
    if (rssi >= -85) return 2;
    if (rssi >= -100) return 1;
    return 0;
  }

  Widget _buildSignalStrengthIndicator(double? rssi, bool isDarkMode) {
    if (rssi == null || rssi == 0) return const SizedBox.shrink();

    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double barWidth = isSmallScreen ? 3 : 4;
    final double barHeightFactor = isSmallScreen ? 3.5 : 5.0;

    int bars = _getSignalBars(rssi);
    Color barColor =
        bars >= 3 ? Colors.green : (bars == 2 ? Colors.orange : Colors.red);

    return Tooltip(
      message: 'RSSI : ${rssi.toStringAsFixed(0)} dBm',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(4, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1.0),
            width: barWidth,
            height: (index + 1) * barHeightFactor,
            decoration: BoxDecoration(
              color: index < bars
                  ? barColor
                  : (isDarkMode ? Colors.white24 : Colors.black12),
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHeaderStatusIndicators(bool isDarkMode,
      {bool isMobile = false}) {
    final double? batteryVal = _lastBatteries[widget.deviceName];
    final double? signalVal = _lastSignalStrengths[widget.deviceName];
    final String? sdStatus = _lastSDCardStatuses[widget.deviceName];

    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double iconSize = isSmallScreen ? 20 : 24;

    // Special case for WD devices (percentage-based battery)
    if (widget.deviceName.startsWith('WD')) {
      final int percentage = (batteryVal ?? 0).toInt();

      // Only show battery if we have a valid value
      if (batteryVal != null) {
        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sdStatus != null && sdStatus.isNotEmpty) ...[
                Tooltip(
                  message: 'SD Card: $sdStatus',
                  child: Icon(
                    _getSDCardIcon(sdStatus),
                    color: _getSDCardColor(sdStatus),
                    size: iconSize,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Tooltip(
                message: 'Battery: $percentage%',
                child: Transform.scale(
                  scaleX: 1.3,
                  child: Icon(
                    _getBatteryIcon(percentage),
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: iconSize,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        );
      } else {
        // For WD devices, if no battery → only show SD card if available
        if (sdStatus != null && sdStatus.isNotEmpty) {
          return Tooltip(
            message: 'SD Card: $sdStatus',
            child: Icon(
              _getSDCardIcon(sdStatus),
              color: _getSDCardColor(sdStatus),
              size: iconSize,
            ),
          );
        }
        return const SizedBox.shrink();
      }
    }

    // Normal devices (voltage-based battery)
    return _buildBatteryAndSignalGroup(
      batteryValue: batteryVal,
      signalValue: signalVal,
      sdCardStatus: sdStatus,
      panelValue: _lastPanelVoltages[widget.deviceName],
      tiltValue: _lastTiltStatuses[widget.deviceName],
      isDarkMode: isDarkMode,
      isMobile: isMobile,
    );
  }

// Updated helper method
  Widget _buildBatteryAndSignalGroup({
    required double? batteryValue,
    required double? signalValue,
    required String? sdCardStatus,
    required double? panelValue,
    required double? tiltValue,
    required bool isDarkMode,
    bool isMobile = false,
  }) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;
    final double iconSize = isSmallScreen ? 18 : 24;

    final bool hasBattery = batteryValue != null && batteryValue >= 0;
    final bool hasSignal = signalValue != null && signalValue != 0;
    final bool hasSDCard = sdCardStatus != null && sdCardStatus.isNotEmpty;
    final bool hasPanel = panelValue != null;
    final bool hasTilt = tiltValue != null;

    // If nothing to show, return empty
    if (!hasBattery && !hasSignal && !hasSDCard && !hasPanel && !hasTilt) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(right: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Signal Strength
          if (hasSignal) _buildSignalStrengthIndicator(signalValue, isDarkMode),

          if (hasSignal && (hasBattery || hasSDCard)) const SizedBox(width: 6),

          // SD Card
          if (hasSDCard) ...[
            Tooltip(
              message: 'SD Card: $sdCardStatus',
              child: Icon(
                _getSDCardIcon(sdCardStatus),
                color: _getSDCardColor(sdCardStatus),
                size: iconSize,
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Panel Voltage (Solar)
          if (hasPanel) ...[
            Tooltip(
              message: 'Panel Voltage: ${panelValue.toStringAsFixed(2)}V',
              child: Icon(
                Icons.wb_sunny_rounded,
                color: Colors.orangeAccent,
                size: iconSize,
              ),
            ),
            const SizedBox(width: 6),
          ],

          // Battery - ONLY show if we have a valid battery value
          if (hasBattery) ...[
            Tooltip(
              message:
                  'Battery: ${_convertVoltageToPercentage(batteryValue).toStringAsFixed(2)}%',
              child: Transform.scale(
                scaleX: 1.3,
                child: Icon(
                  _getpercentBatteryIcon(batteryValue),
                  color: _getpercentBatteryColor(batteryValue),
                  size: iconSize,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

// Add this helper method to detect gaps in data (1 day threshold)
  List<List<ChartData>> _splitDataByGaps(List<ChartData> data,
      {Duration maxGap = const Duration(days: 1)}) {
    if (data.isEmpty) return [];

    List<List<ChartData>> segments = [];
    List<ChartData> currentSegment = [data[0]];

    for (int i = 1; i < data.length; i++) {
      Duration gap = data[i].timestamp.difference(data[i - 1].timestamp);

      if (gap > maxGap) {
        // Gap detected - save current segment and start new one
        segments.add(currentSegment);
        currentSegment = [data[i]];
      } else {
        currentSegment.add(data[i]);
      }
    }

    // Add the last segment
    if (currentSegment.isNotEmpty) {
      segments.add(currentSegment);
    }

    return segments;
  }

// Add this helper to create gap connectors
  List<ChartData> _createGapConnector(ChartData start, ChartData end) {
    return [start, end];
  }

// Modified _getChartSeries method
  CartesianSeries<ChartData, DateTime> _getChartSeries(
      ChartType chartType, List<ChartData> data, String title) {
    switch (chartType) {
      case ChartType.line:
        if (widget.deviceName.startsWith('CL')) {
          // Chlorine sensor - keep existing behavior
          return LineSeries<ChartData, DateTime>(
            markerSettings: const MarkerSettings(
              height: 6.0,
              width: 6.0,
              isVisible: true,
            ),
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            color: Colors.blue,
            pointColorMapper: (ChartData data, _) {
              if (data.value >= 0.01 && data.value <= 0.5) {
                return Colors.green;
              } else if (data.value > 0.5 && data.value <= 1.0) {
                return Colors.yellow;
              } else if (data.value > 1.0 && data.value <= 4.0) {
                return Colors.orange;
              } else if (data.value > 4.0) {
                return Colors.red;
              }
              return Colors.white;
            },
          );
        } else {
          // For other devices, we'll need to use multiple series
          // This will be handled in the updated _buildChartContainer
          return AreaSeries<ChartData, DateTime>(
            dataSource: data,
            xValueMapper: (ChartData data, _) => data.timestamp,
            yValueMapper: (ChartData data, _) => data.value,
            name: title,
            borderColor: Theme.of(context).brightness == Brightness.light
                ? Color.fromARGB(255, 0, 120, 215)
                : Colors.blue,
            borderWidth: 3,
            gradient: LinearGradient(
              colors: [
                (Theme.of(context).brightness == Brightness.light
                    ? Color.fromARGB(255, 0, 120, 215).withOpacity(0.4)
                    : Colors.blue.withOpacity(0.4)),
                (Theme.of(context).brightness == Brightness.light
                    ? Color.fromARGB(255, 0, 120, 215).withOpacity(0.0)
                    : Colors.blue.withOpacity(0.0)),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            markerSettings: const MarkerSettings(isVisible: false),
          );
        }

      default:
        return AreaSeries<ChartData, DateTime>(
          dataSource: data,
          xValueMapper: (ChartData data, _) => data.timestamp,
          yValueMapper: (ChartData data, _) => data.value,
          name: title,
          borderColor: Colors.blue,
          borderWidth: 2,
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.4),
              Colors.blue.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          markerSettings: const MarkerSettings(isVisible: false),
        );
    }
  }

  Widget _buildWindChartContainer(
    String title,
    List<ChartData> speedData,
    List<ChartData> directionData,
    bool isDarkMode,
  ) {
    if (speedData.isEmpty) return const SizedBox.shrink();

    final convertedSpeed = _convertWindSpeed(speedData);
    final String unit = _isKmPerHour ? 'km/h' : 'm/s';
    final bool hasDirection =
        directionData.isNotEmpty && directionData.length == speedData.length;

    bool isSelected = _selectedParam == title;

    List<PlotBand> periodBands = [];
    if (widget.anomalyName != null &&
        widget.period != null &&
        widget.period!.isNotEmpty) {
      try {
        final period = widget.period!;
        final anomalies =
            widget.anomalyName!.split(",").map((a) => a.trim()).toList();
        String normalize(String s) => s.toLowerCase().replaceAll(' ', '');

        for (final anomaly in anomalies) {
          final cleanAnomaly =
              anomaly.contains(":") ? anomaly.split(":").last.trim() : anomaly;

          if (normalize(anomaly).contains("wind")) {
            if (period.startsWith("from") && period.contains("to")) {
              final regex = RegExp(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})');
              final matches = regex.allMatches(period).toList();

              if (matches.length >= 2) {
                final fromDate = DateTime.parse(matches[0].group(0)!);
                final toDate = DateTime.parse(matches[1].group(0)!);
                final midPoint = fromDate.add(Duration(
                    milliseconds:
                        toDate.difference(fromDate).inMilliseconds ~/ 2));
                bool isRightSide = midPoint.hour >= 12;

                periodBands.add(PlotBand(
                  isVisible: true,
                  start: fromDate,
                  end: toDate,
                  color: Colors.red.withOpacity(0.2),
                  text: cleanAnomaly,
                  textAngle: 0,
                  verticalTextAlignment: TextAnchor.start,
                  horizontalTextAlignment:
                      isRightSide ? TextAnchor.end : TextAnchor.start,
                ));
              }
            } else {
              final dt = DateTime.parse(period);
              bool isRightSide = dt.hour >= 12;

              periodBands.add(PlotBand(
                isVisible: true,
                start: dt,
                end: dt,
                borderWidth: 2,
                borderColor: Colors.red,
                text: cleanAnomaly,
                textAngle: 0,
                verticalTextAlignment: TextAnchor.start,
                horizontalTextAlignment:
                    isRightSide ? TextAnchor.end : TextAnchor.start,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint("Wind anomaly period parse error: $e");
      }
    }

    List<List<ChartData>> dataSegments =
        _splitDataByGaps(convertedSpeed, maxGap: Duration(days: 1));

    List<List<ChartData>> gapConnectors = [];
    for (int i = 0; i < dataSegments.length - 1; i++) {
      ChartData endOfSegment = dataSegments[i].last;
      ChartData startOfNextSegment = dataSegments[i + 1].first;
      gapConnectors.add(_createGapConnector(endOfSegment, startOfNextSegment));
    }

    // ✅ Wrap with Focus + Listener for Shift+Scroll zoom
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
            event.logicalKey == LogicalKeyboardKey.shiftRight) {
          setState(() {
            _isShiftPressed = event is KeyDownEvent;
          });
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: (event) {
          if (!_isShiftPressed && event is PointerScrollEvent) {
            // Let scroll pass through — do nothing here
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(0.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            key: _chartKeys[title],
            width: double.infinity,
            height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: isDarkMode ? const Color(0xFF14212B) : Colors.white,
              border: Border.all(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.08),
                width: 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: isSelected || _selectedParam == null ? 0.0 : 100.0,
                  sigmaY: isSelected || _selectedParam == null ? 0.0 : 100.0,
                ),
                child: Opacity(
                  opacity: isSelected || _selectedParam == null ? 1.0 : 0.2,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 12.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Center(
                              child: Text(
                                "$title ($unit)",
                                style: TextStyle(
                                  fontSize:
                                      MediaQuery.of(context).size.width < 800
                                          ? 18
                                          : 22,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.download_rounded,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    tooltip: 'Download Chart as PNG',
                                    onPressed: () => _exportChart(title, 'png'),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDarkMode
                                          ? Colors.white12
                                          : Colors.black12,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _isKmPerHour = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: !_isKmPerHour
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'm/s',
                                              style: TextStyle(
                                                color: !_isKmPerHour
                                                    ? Colors.white
                                                    : (isDarkMode
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(
                                              () => _isKmPerHour = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _isKmPerHour
                                                  ? Colors.blue
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              'km/h',
                                              style: TextStyle(
                                                color: _isKmPerHour
                                                    ? Colors.white
                                                    : (isDarkMode
                                                        ? Colors.white60
                                                        : Colors.black54),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
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
                          ],
                        ),
                      ),
                      Expanded(
                        child: SfCartesianChart(
                          key: _sfChartKeys[title],
                          plotAreaBackgroundColor: Colors.transparent,
                          primaryXAxis: DateTimeAxis(
                            dateFormat: DateFormat('MM/dd HH:mm'),
                            title: AxisTitle(
                              text: 'Time',
                              textStyle: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black,
                              ),
                            ),
                            labelStyle: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            labelRotation: 70,
                            edgeLabelPlacement: EdgeLabelPlacement.shift,
                            intervalType: DateTimeIntervalType.auto,
                            enableAutoIntervalOnZooming: true,
                            majorGridLines: MajorGridLines(
                              width: MediaQuery.of(context).size.width > 900
                                  ? 0.4
                                  : 0,
                              color:
                                  isDarkMode ? Colors.white10 : Colors.black12,
                            ),
                            minorGridLines: const MinorGridLines(width: 0),
                            majorTickLines:
                                const MajorTickLines(size: 0, width: 0),
                            minorTickLines:
                                const MinorTickLines(size: 0, width: 0),
                            plotBands: [...periodBands],
                          ),
                          primaryYAxis: NumericAxis(
                            labelStyle: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            axisLine: const AxisLine(width: 1),
                            majorGridLines: MajorGridLines(
                              width: MediaQuery.of(context).size.width > 900
                                  ? 0.4
                                  : 0,
                              color:
                                  isDarkMode ? Colors.white10 : Colors.black12,
                            ),
                            minorGridLines: const MinorGridLines(width: 0),
                          ),
                          trackballBehavior: TrackballBehavior(
                            enable: true,
                            activationMode: ActivationMode.singleTap,
                            lineType: TrackballLineType.vertical,
                            lineColor: isDarkMode
                                ? Colors.blue
                                : const Color.fromARGB(255, 42, 147, 212),
                            lineWidth: 1,
                            builder: (context, details) {
                              try {
                                final DateTime? time = details.point?.x;
                                final num? value = details.point?.y;
                                if (time == null || value == null) {
                                  return const SizedBox();
                                }

                                String formattedDate =
                                    DateFormat('MM/dd HH:mm').format(time);

                                String anomalyText = "";
                                for (var band in periodBands) {
                                  if (band.start != null &&
                                      band.end != null &&
                                      (time.isAtSameMomentAs(band.start!) ||
                                          (time.isAfter(band.start!) &&
                                              time.isBefore(band.end!)))) {
                                    anomalyText = band.text ?? "";
                                  }
                                }

                                Widget? arrowIcon;
                                String directionText = "";
                                if (hasDirection &&
                                    details.pointIndex != null) {
                                  final double dir =
                                      directionData[details.pointIndex!].value;
                                  directionText =
                                      " (${dir.toStringAsFixed(0)}°)";
                                  arrowIcon = Transform.rotate(
                                    angle: (dir * math.pi / 180) + math.pi,
                                    child: Icon(
                                      Icons.navigation,
                                      size: 24,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  );
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color.fromARGB(200, 0, 0, 0)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      if (arrowIcon != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 4.0),
                                          child: arrowIcon,
                                        ),
                                      Text(
                                        formattedDate,
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        "Speed: ${value.toStringAsFixed(1)} $unit$directionText",
                                        style: TextStyle(
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (anomalyText.isNotEmpty)
                                        Text(
                                          "Anomaly: $anomalyText",
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox();
                              }
                            },
                          ),
                          // ✅ enableMouseWheelZooming tied to _isShiftPressed
                          zoomPanBehavior: ZoomPanBehavior(
                            zoomMode: ZoomMode.x,
                            enablePanning: true,
                            enablePinching: true,
                            enableMouseWheelZooming: _isShiftPressed,
                          ),
                          series: <CartesianSeries<ChartData, DateTime>>[
                            ...dataSegments.map((segment) {
                              return AreaSeries<ChartData, DateTime>(
                                dataSource: segment,
                                xValueMapper: (ChartData data, _) =>
                                    data.timestamp,
                                yValueMapper: (ChartData data, _) => data.value,
                                name: title,
                                borderColor: _getParamColor('Wind'),
                                borderWidth: 3,
                                gradient: LinearGradient(
                                  colors: [
                                    _getParamColor('Wind').withOpacity(0.4),
                                    _getParamColor('Wind').withOpacity(0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                markerSettings:
                                    const MarkerSettings(isVisible: false),
                              );
                            }).toList(),
                            ...gapConnectors.map((connector) {
                              return LineSeries<ChartData, DateTime>(
                                dataSource: connector,
                                xValueMapper: (ChartData data, _) =>
                                    data.timestamp,
                                yValueMapper: (ChartData data, _) => data.value,
                                color: _getParamColor('Wind'),
                                width: 3,
                                dashArray: const <double>[5, 5],
                                markerSettings:
                                    const MarkerSettings(isVisible: false),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getParamColor(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('temp')) return const Color(0xFFFF9800); // Orange
    if (lowerTitle.contains('humid')) return const Color(0xFF2196F3); // Blue
    if (lowerTitle.contains('light')) return const Color(0xFFFFC107); // Amber
    if (lowerTitle.contains('rain'))
      return const Color(0xFF03A9F4); // Light Blue
    if (lowerTitle.contains('press')) return const Color(0xFF9C27B0); // Purple
    if (lowerTitle.contains('wind')) return const Color(0xFF4CAF50); // Green
    if (lowerTitle.contains('battery'))
      return const Color(0xFF8BC34A); // Light Green
    if (lowerTitle.contains('signal')) return const Color(0xFFFF4081); // Pink
    if (lowerTitle.contains('co2'))
      return const Color(0xFF7C4DFF); // Deep Purple
    if (lowerTitle.contains('pm2.5'))
      return const Color(0xFFFF5722); // Deep Orange
    if (lowerTitle.contains('pm10'))
      return const Color.fromARGB(255, 196, 130, 105); // Brown
    if (lowerTitle.contains('aqi'))
      return const Color(0xFF009688); // Teal
    if (lowerTitle.contains('radiation')) return Colors.orange;
    if (lowerTitle.contains('gust')) return Colors.deepOrangeAccent;
    if (lowerTitle.contains('layer')) return Colors.brown;
    return const Color(0xFF00BCD4); // Cyan
  }

  IconData _getParamIcon(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('temp')) return Icons.thermostat;
    if (lowerTitle.contains('humid')) return Icons.water_drop;
    if (lowerTitle.contains('light')) return Icons.wb_sunny_outlined;
    if (lowerTitle.contains('rain')) return Icons.umbrella;
    if (lowerTitle.contains('press')) return Icons.speed;
    if (lowerTitle.contains('wind')) return Icons.air;
    if (lowerTitle.contains('battery')) return Icons.battery_charging_full;
    if (lowerTitle.contains('signal')) return Icons.signal_cellular_alt;
    if (lowerTitle.contains('co2')) return Icons.cloud_outlined;
    if (lowerTitle.contains('pm2.5')) return Icons.grain;
    if (lowerTitle.contains('pm10')) return Icons.grain;
    if (lowerTitle.contains('aqi')) return Icons.air;
    if (title.contains('Radiation')) return Icons.wb_sunny;
    if (title.contains('Max Wind Gust')) return Icons.wind_power;
    return Icons.show_chart;
  }

  Widget _buildChartContainer(
    String title,
    List<ChartData> data,
    String yAxisTitle,
    ChartType chartType,
    bool isDarkMode, {
    List<ChartData>? secondaryData,
    String? secondaryTitle,
  }) {
    bool isSelected = _selectedParam == title;
    List<PlotBand> periodBands = [];

    if (widget.anomalyName != null &&
        widget.period != null &&
        widget.period!.isNotEmpty) {
      try {
        final period = widget.period!;
        final anomalies =
            widget.anomalyName!.split(",").map((a) => a.trim()).toList();
        String normalize(String s) => s.toLowerCase().replaceAll(' ', '');

        for (final anomaly in anomalies) {
          final cleanAnomaly =
              anomaly.contains(":") ? anomaly.split(":").last.trim() : anomaly;
          final normTitle = normalize(title);
          final normAnomaly = normalize(anomaly);

          if (normAnomaly.contains(normTitle)) {
            if (period.startsWith("from") && period.contains("to")) {
              final regex = RegExp(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})');
              final matches = regex.allMatches(period).toList();

              if (matches.length >= 2) {
                final fromDate = DateTime.parse(matches[0].group(0)!);
                final toDate = DateTime.parse(matches[1].group(0)!);
                final midPoint = fromDate.add(Duration(
                    milliseconds:
                        toDate.difference(fromDate).inMilliseconds ~/ 2));
                bool isRightSide = midPoint.hour >= 12;

                periodBands.add(PlotBand(
                  isVisible: true,
                  start: fromDate,
                  end: toDate,
                  color: Colors.red.withOpacity(0.2),
                  text: cleanAnomaly,
                  textAngle: 0,
                  verticalTextAlignment: TextAnchor.start,
                  horizontalTextAlignment:
                      isRightSide ? TextAnchor.end : TextAnchor.start,
                ));
              }
            } else {
              final dt = DateTime.parse(period);
              bool isRightSide = dt.hour >= 12;

              periodBands.add(PlotBand(
                isVisible: true,
                start: dt,
                end: dt,
                borderWidth: 2,
                borderColor: Colors.red,
                text: cleanAnomaly,
                textAngle: 0,
                verticalTextAlignment: TextAnchor.start,
                horizontalTextAlignment:
                    isRightSide ? TextAnchor.end : TextAnchor.start,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint("Period parse error: $e");
      }
    }

    List<List<ChartData>> dataSegments =
        _splitDataByGaps(data, maxGap: Duration(days: 1));

    List<List<ChartData>> gapConnectors = [];
    for (int i = 0; i < dataSegments.length - 1; i++) {
      ChartData endOfSegment = dataSegments[i].last;
      ChartData startOfNextSegment = dataSegments[i + 1].first;
      gapConnectors.add(_createGapConnector(endOfSegment, startOfNextSegment));
    }

    // Process secondary data if available
    List<List<ChartData>> secondarySegments = [];
    List<List<ChartData>> secondaryGapConnectors = [];
    if (secondaryData != null && secondaryData.isNotEmpty) {
      secondarySegments =
          _splitDataByGaps(secondaryData, maxGap: Duration(days: 1));
      for (int i = 0; i < secondarySegments.length - 1; i++) {
        ChartData endOfSegment = secondarySegments[i].last;
        ChartData startOfNextSegment = secondarySegments[i + 1].first;
        secondaryGapConnectors
            .add(_createGapConnector(endOfSegment, startOfNextSegment));
      }
    }

    // ✅ Wrap with Focus + Listener for Shift+Scroll zoom
    return data.isNotEmpty
        ? Focus(
            autofocus: false,
            onKeyEvent: (node, event) {
              if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                  event.logicalKey == LogicalKeyboardKey.shiftRight) {
                setState(() {
                  _isShiftPressed = event is KeyDownEvent;
                });
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Listener(
              onPointerSignal: (event) {
                if (!_isShiftPressed && event is PointerScrollEvent) {
                  // Let scroll pass through — do nothing
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(0.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  key: _chartKeys[title],
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.0),
                    color: isDarkMode ? const Color(0xFF14212B) : Colors.white,
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.08),
                      width: 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX:
                            isSelected || _selectedParam == null ? 0.0 : 100.0,
                        sigmaY:
                            isSelected || _selectedParam == null ? 0.0 : 100.0,
                      ),
                      child: Opacity(
                        opacity:
                            isSelected || _selectedParam == null ? 1.0 : 0.2,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                      width: 48), // Balance for the icon
                                  Expanded(
                                    child: Text(
                                      '$title $yAxisTitle',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize:
                                            MediaQuery.of(context).size.width <
                                                    800
                                                ? 18
                                                : 22,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.download_rounded,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 20,
                                    ),
                                    tooltip: 'Download Chart as PNG',
                                    onPressed: () => _exportChart(title, 'png'),
                                  ),
                                ],
                              ),
                            ),
                            if (widget.deviceName.startsWith('CL'))
                              Padding(
                                padding: const EdgeInsets.all(6.0),
                                child: _buildLegend(
                                    MediaQuery.of(context).size.width),
                              ),
                            Expanded(
                              child: SfCartesianChart(
                                key: _sfChartKeys[title],
                                plotAreaBackgroundColor: Colors.transparent,
                                primaryXAxis: DateTimeAxis(
                                  dateFormat: DateFormat('MM/dd HH:mm'),
                                  title: AxisTitle(
                                    text: 'Time',
                                    textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  labelStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  labelRotation: 70,
                                  edgeLabelPlacement: EdgeLabelPlacement.shift,
                                  intervalType: DateTimeIntervalType.auto,
                                  enableAutoIntervalOnZooming: true,
                                  majorGridLines: MajorGridLines(
                                    width:
                                        MediaQuery.of(context).size.width > 900
                                            ? 0.4
                                            : 0,
                                    color: isDarkMode
                                        ? Colors.white10
                                        : Colors.black12,
                                  ),
                                  minorGridLines:
                                      const MinorGridLines(width: 0),
                                  majorTickLines:
                                      const MajorTickLines(size: 0, width: 0),
                                  minorTickLines:
                                      const MinorTickLines(size: 0, width: 0),
                                  plotBands: [...periodBands],
                                ),
                                primaryYAxis: NumericAxis(
                                  labelStyle: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                  axisLine: const AxisLine(width: 1),
                                  majorGridLines: MajorGridLines(
                                    width:
                                        MediaQuery.of(context).size.width > 900
                                            ? 0.4
                                            : 0,
                                    color: isDarkMode
                                        ? Colors.white10
                                        : Colors.black12,
                                  ),
                                  minorGridLines:
                                      const MinorGridLines(width: 0),
                                ),
                                trackballBehavior: TrackballBehavior(
                                  enable: true,
                                  activationMode: ActivationMode.singleTap,
                                  tooltipDisplayMode:
                                      TrackballDisplayMode.groupAllPoints,
                                  lineType: TrackballLineType.vertical,
                                  lineColor: _getParamColor(title),
                                  lineWidth: 1,
                                  markerSettings: TrackballMarkerSettings(
                                    markerVisibility:
                                        TrackballVisibilityMode.visible,
                                    width: 8,
                                    height: 8,
                                    borderWidth: 2,
                                    color: _getParamColor(title),
                                  ),
                                  builder: (BuildContext context,
                                      TrackballDetails details) {
                                    try {
                                      DateTime? time;
                                      num? value;

                                      if (details.point != null) {
                                        time = details.point?.x;
                                        value = details.point?.y;
                                      } else if (details.groupingModeInfo !=
                                              null &&
                                          details.groupingModeInfo!.points
                                              .isNotEmpty) {
                                        time = details
                                            .groupingModeInfo!.points.first.x;

                                        // To ensure 'value' is the primary series value,
                                        // we try to find the point matching the primary series name,
                                        // otherwise default to the first point.
                                        final primaryName =
                                            secondaryData != null
                                                ? 'Current'
                                                : title;
                                        final primaryPoint = details
                                            .groupingModeInfo!.points.first;
                                        value = primaryPoint.y;
                                      }

                                      if (time == null || value == null) {
                                        return const SizedBox();
                                      }

                                      String formattedDate =
                                          DateFormat('MM/dd HH:mm')
                                              .format(time);

                                      try {
                                        final pt = data.firstWhere(
                                            (d) => d.timestamp == time);
                                        if (_isAdmin && pt.filledFlag > 0) {
                                          formattedDate += ' (Filled Data)';
                                        }
                                      } catch (_) {}

                                      // Find secondary value at same timestamp
                                      num? secValue;
                                      if (secondaryData != null) {
                                        try {
                                          secValue = secondaryData
                                              .firstWhere(
                                                  (d) => d.timestamp == time)
                                              .value;
                                        } catch (_) {}
                                      }

                                      String? anomalyText;
                                      for (var band in periodBands) {
                                        if (band.start != null &&
                                            band.end != null &&
                                            (time.isAtSameMomentAs(
                                                    band.start!) ||
                                                (time.isAfter(band.start!) &&
                                                    time.isBefore(
                                                        band.end!)))) {
                                          anomalyText = band.text;
                                        }
                                      }

                                      Widget buildRow(
                                          String name, num val, Color col) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                    color: col,
                                                    shape: BoxShape.circle),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$name: ',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white70
                                                        : Colors.black54,
                                                    fontSize: 12),
                                              ),
                                              Text(
                                                '$val',
                                                style: TextStyle(
                                                    color: isDarkMode
                                                        ? Colors.white
                                                        : Colors.black,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      String primaryLabel = title;
                                      if (secondaryData != null) {
                                        if (title
                                            .toLowerCase()
                                            .contains('temp')) {
                                          primaryLabel = 'Temp';
                                        } else if (title
                                            .toLowerCase()
                                            .contains('hum')) {
                                          primaryLabel = 'Humidity';
                                        }
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDarkMode
                                              ? const Color.fromARGB(
                                                  220, 10, 20, 30)
                                              : Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 4)
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              formattedDate,
                                              style: TextStyle(
                                                  color: isDarkMode
                                                      ? Colors.white70
                                                      : Colors.black54,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                            const SizedBox(height: 4),
                                            buildRow(primaryLabel, value,
                                                _getParamColor(title)),
                                            ...(() {
                                              try {
                                                final pt = data.firstWhere(
                                                    (d) => d.timestamp == time);
                                                if (pt.gustTime != null &&
                                                    pt.gustTime!.isNotEmpty) {
                                                  final formatted =
                                                      _formatGustTime(
                                                          pt.gustTime);
                                                  if (formatted.isNotEmpty) {
                                                    return [
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(top: 4.0),
                                                        child: Text(
                                                          'Range: $formatted',
                                                          style: TextStyle(
                                                              color: isDarkMode
                                                                  ? Colors
                                                                      .orangeAccent
                                                                  : Colors
                                                                      .deepOrange,
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold),
                                                        ),
                                                      )
                                                    ];
                                                  }
                                                }
                                              } catch (_) {}
                                              return <Widget>[];
                                            })(),
                                            if (secValue != null) ...[
                                              buildRow(
                                                  secondaryTitle ?? 'Corrected',
                                                  secValue,
                                                  title
                                                          .toLowerCase()
                                                          .contains('temp')
                                                      ? Colors.teal
                                                      : Colors.cyan),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    left: 14.0, bottom: 2.0),
                                                child: Text(
                                                  'Diff: ${(secValue - value).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white60
                                                          : Colors.black45,
                                                      fontSize: 10,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            ],
                                            if (title
                                                .toLowerCase()
                                                .contains('battery'))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 4.0),
                                                child: Text(
                                                  'Percentage: ${_convertVoltageToPercentage(value.toDouble()).toStringAsFixed(2)}%',
                                                  style: TextStyle(
                                                      color: isDarkMode
                                                          ? Colors.white
                                                          : Colors.black,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 11),
                                                ),
                                              ),
                                            if (anomalyText != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Anomaly: $anomalyText',
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      );
                                    } catch (e) {
                                      return const SizedBox();
                                    }
                                  },
                                ),
                                // ✅ enableMouseWheelZooming tied to _isShiftPressed
                                zoomPanBehavior: ZoomPanBehavior(
                                  zoomMode: ZoomMode.x,
                                  enablePanning: true,
                                  enablePinching: true,
                                  enableMouseWheelZooming: _isShiftPressed,
                                ),
                                series: <CartesianSeries<ChartData, DateTime>>[
                                  if (!widget.deviceName.startsWith('CL'))
                                    ...dataSegments.map((segment) {
                                      final Color seriesColor =
                                          _getParamColor(title);
                                      return AreaSeries<ChartData, DateTime>(
                                        dataSource: segment,
                                        xValueMapper: (ChartData data, _) =>
                                            data.timestamp,
                                        yValueMapper: (ChartData data, _) =>
                                            data.value,
                                        name: secondaryData != null
                                            ? (title
                                                    .toLowerCase()
                                                    .contains('temp')
                                                ? 'Temp'
                                                : (title
                                                        .toLowerCase()
                                                        .contains('hum')
                                                    ? 'Humidity'
                                                    : title))
                                            : title,
                                        borderColor: seriesColor,
                                        borderWidth: 3,
                                        gradient: LinearGradient(
                                          colors: title
                                                  .toLowerCase()
                                                  .contains('signal')
                                              ? [
                                                  seriesColor.withOpacity(0.0),
                                                  seriesColor.withOpacity(0.4),
                                                ]
                                              : [
                                                  seriesColor.withOpacity(0.4),
                                                  seriesColor.withOpacity(0.0),
                                                ],
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                        ),
                                        markerSettings: const MarkerSettings(
                                            isVisible: false),
                                      );
                                    }).toList(),
                                  if (!widget.deviceName.startsWith('CL'))
                                    ...gapConnectors.map((connector) {
                                      return LineSeries<ChartData, DateTime>(
                                        dataSource: connector,
                                        xValueMapper: (ChartData data, _) =>
                                            data.timestamp,
                                        yValueMapper: (ChartData data, _) =>
                                            data.value,
                                        color: _getParamColor(title),
                                        width: 3,
                                        dashArray: const <double>[5, 5],
                                        markerSettings: const MarkerSettings(
                                            isVisible: false),
                                      );
                                    }).toList(),

                                  // ✅ Corrected Data Series
                                  if (secondaryData != null)
                                    ...secondarySegments.map((segment) {
                                      final Color seriesColor =
                                          title.toLowerCase().contains('temp')
                                              ? Colors.teal
                                              : title.toLowerCase().contains('rain')
                                                  ? Colors.deepPurple
                                                  : Colors.cyan;
                                      return LineSeries<ChartData, DateTime>(
                                        dataSource: segment,
                                        xValueMapper: (ChartData data, _) =>
                                            data.timestamp,
                                        yValueMapper: (ChartData data, _) =>
                                            data.value,
                                        name: secondaryTitle ?? 'Corrected',
                                        color: seriesColor,
                                        width: 3,
                                        markerSettings: const MarkerSettings(
                                            isVisible: false),
                                      );
                                    }).toList(),
                                  if (secondaryData != null)
                                    ...secondaryGapConnectors.map((connector) {
                                      final Color seriesColor =
                                          title.toLowerCase().contains('temp')
                                              ? Colors.teal
                                              : title.toLowerCase().contains('rain')
                                                  ? Colors.deepPurple
                                                  : Colors.cyan;
                                      return LineSeries<ChartData, DateTime>(
                                        dataSource: connector,
                                        xValueMapper: (ChartData data, _) =>
                                            data.timestamp,
                                        yValueMapper: (ChartData data, _) =>
                                            data.value,
                                        color: seriesColor,
                                        width: 3,
                                        dashArray: const <double>[5, 5],
                                        markerSettings: const MarkerSettings(
                                            isVisible: false),
                                      );
                                    }).toList(),
                                  if (widget.deviceName.startsWith('CL'))
                                    _getChartSeries(chartType, data, title),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  Widget _buildLegend(double screenWidth) {
    double boxSize, textSize, spacing;

    if (screenWidth < 800) {
      boxSize = 15.0;
      textSize = 15.0;
      spacing = 12.0;
    } else {
      boxSize = 20.0;
      textSize = 16.0;
      spacing = 45.0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildColorBox(Colors.white, '< 0.01 ', boxSize, textSize),
          SizedBox(width: spacing),
          _buildColorBox(Colors.green, '> 0.01 - 0.5', boxSize, textSize),
          SizedBox(width: spacing),
          _buildColorBox(Colors.yellow, '> 0.5 - 1.0', boxSize, textSize),
          SizedBox(width: spacing),
          _buildColorBox(Colors.orange, '> 1.0 - 4.0', boxSize, textSize),
          SizedBox(width: spacing),
          _buildColorBox(Colors.red, 'Above 4.0', boxSize, textSize),
        ],
      ),
    );
  }

  Widget _buildColorBox(
      Color color, String range, double boxSize, double textSize) {
    return Row(
      children: [
        Container(
          width: boxSize,
          height: boxSize,
          color: color,
        ),
        SizedBox(width: 8), // Fixed width between box and text
        Text(
          range,
          style: TextStyle(
            color: Colors.white,
            fontSize: textSize,
          ),
        ),
      ],
    );
  }

  List<ChartData> _fillZerosWithLastNonZero(List<ChartData> data) {
    if (data.isEmpty) return data;

    List<ChartData> result = List.from(data);

    // ── Step 1: Forward fill (existing behavior) ──
    // Replace 0s with the last seen non-zero value
    double? lastNonZero;
    for (int i = 0; i < result.length; i++) {
      if (result[i].value != 0) {
        lastNonZero = result[i].value;
      } else if (lastNonZero != null) {
        result[i] = ChartData(
          timestamp: result[i].timestamp,
          value: lastNonZero,
        );
      }
    }

    // ── Step 2: Backward fill for leading zeros at start of each day ──
    // Group indices by date
    Map<String, List<int>> dayIndices = {};
    for (int i = 0; i < result.length; i++) {
      final dayKey =
          '${result[i].timestamp.year}-${result[i].timestamp.month}-${result[i].timestamp.day}';
      dayIndices.putIfAbsent(dayKey, () => []);
      dayIndices[dayKey]!.add(i);
    }

    for (final indices in dayIndices.values) {
      // Find first non-zero value in this day
      double? firstNonZeroOfDay;
      for (final idx in indices) {
        if (result[idx].value != 0) {
          firstNonZeroOfDay = result[idx].value;
          break;
        }
      }

      if (firstNonZeroOfDay == null) continue; // entire day is 0, skip

      // Backfill leading zeros with that first non-zero value
      for (final idx in indices) {
        if (result[idx].value == 0) {
          result[idx] = ChartData(
            timestamp: result[idx].timestamp,
            value: firstNonZeroOfDay!,
          );
        } else {
          break; // stop at first non-zero — only fill leading zeros
        }
      }
    }

    return result;
  }
  // CartesianSeries<ChartData, DateTime> _getChartSeries(
}

enum ChartType {
  line,
}

class ChartData {
  final DateTime timestamp;
  final double value;
  final String? gustTime;
  final int filledFlag;

  ChartData(
      {required this.timestamp,
      required this.value,
      this.gustTime,
      this.filledFlag = 0});
}

class _MetricSummaryCard extends StatelessWidget {
  final String label;
  final double? current;
  final double? min;
  final double? max;
  final double? totalRainfall;
  final String unit;
  final bool isDarkMode;
  final double? windDirection;
  final bool isRainfall;
  final bool isWind;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final double? squallSpeed;
  final double? squallDirection;
  final String? squallTime;
  final double? dailyMaxTemp;
  final double? dailyMinTemp;
  final String? maxGustTime;
  final double? tiltStatus;

  const _MetricSummaryCard({
    required this.label,
    required this.current,
    required this.min,
    required this.max,
    this.totalRainfall,
    required this.unit,
    required this.isDarkMode,
    required this.color,
    required this.icon,
    this.windDirection,
    this.isRainfall = false,
    this.isWind = false,
    this.maxGustTime,
    this.squallSpeed,
    this.squallDirection,
    this.squallTime,
    this.dailyMaxTemp,
    this.dailyMinTemp,
    this.tiltStatus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDarkMode ? const Color(0xFF14212B) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    final strongText = isDarkMode ? Colors.white : Colors.black87;
    final subtleText = isDarkMode ? Colors.white70 : Colors.black54;

    String displayVal = current?.toStringAsFixed(2) ?? '--';
    String minVal = min?.toStringAsFixed(2) ?? '--';
    String maxVal = max?.toStringAsFixed(2) ?? '--';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 150,
          maxWidth: 220,
          minHeight: 120,
        ),
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [
            if (!isDarkMode)
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 3, width: double.infinity, color: color),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          icon,
                          size: 14,
                          color: color.withOpacity(0.8),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            color: subtleText,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (isWind &&
                            squallSpeed != null &&
                            squallSpeed != 0) ...[
                          const Spacer(),
                          Tooltip(
                            message:
                                'Squall Time: ${_formatGustTime(squallTime)}',
                            child: Text(
                              'SQ: ${squallSpeed!.toStringAsFixed(2)} (${squallDirection?.toStringAsFixed(0) ?? "0"}°)',
                              style: const TextStyle(
                                color: Colors.orangeAccent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (tiltStatus != null) ...[
                          const Spacer(),
                          Tooltip(
                            message: 'Tilt Status',
                            child: Text(
                              'Tilt : ${tiltStatus!.toInt()}',
                              style: TextStyle(
                                color: subtleText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (dailyMaxTemp != null || dailyMinTemp != null) ...[
                          const Spacer(),
                          if (dailyMinTemp != null)
                            Text(
                              '${dailyMinTemp!.toStringAsFixed(2)}°',
                              style: const TextStyle(
                                  color: Colors.cyan,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          const Text(' / ',
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 10)),
                          if (dailyMaxTemp != null)
                            Text(
                              '${dailyMaxTemp!.toStringAsFixed(2)}°',
                              style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          displayVal,
                          style: TextStyle(
                            color: strongText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          unit,
                          style: TextStyle(
                            color: subtleText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isRainfall && current == 0.0)
                      Text(
                        'Total rain: ${totalRainfall?.toStringAsFixed(2) ?? "0.00"} $unit',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (isWind && windDirection != null)
                      Text(
                        '${windDirection!.toStringAsFixed(0)}° ${_getWindCardinal(windDirection!)}',
                        style: TextStyle(
                          color: subtleText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (maxGustTime != null && maxGustTime!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          _formatGustTime(maxGustTime),
                          style: TextStyle(
                            color: subtleText,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else if (!label.toLowerCase().contains('gust'))
                      Row(
                        children: [
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.blue, size: 18),
                          Text(
                            minVal,
                            style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.arrow_drop_up,
                              color: Colors.red, size: 18),
                          Text(
                            maxVal,
                            style: const TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
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

  String _getWindCardinal(double degrees) {
    const directions = [
      'North',
      'North East',
      'East',
      'South East',
      'South',
      'South West',
      'West',
      'North West'
    ];
    int index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index % 8];
  }
}

String _formatGustTime(String? rawRange) {
  if (rawRange == null || rawRange.isEmpty || rawRange.toLowerCase() == 'null')
    return '';
  try {
    // Expected Format: "2026-05-12 17-30-27-2026-05-12 17-30-30"
    if (rawRange.length >= 39) {
      final startPart = rawRange.substring(0, 19); // 2026-05-12 17-30-27
      final endPart = rawRange.substring(20); // 2026-05-12 17-30-30

      final startTime = startPart.split(' ').last.replaceAll('-', ':');
      final endTime = endPart.split(' ').last.replaceAll('-', ':');

      return '$startTime to $endTime';
    }
  } catch (e) {
    debugPrint("Error formatting gust time: $e");
  }
  return rawRange;
}
