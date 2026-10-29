import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_sense_webapp/src/utils/device_config.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/views/home/home_utils.dart';

/// Representation of a weather station candidate for comparison.
class StationCandidate {
  final String deviceKey; // raw deviceid#topic
  final String deviceId;  // extracted or raw id
  final String sensorName; // resolved internal name e.g. WJ214, KR01
  final String displayName; // formatted name e.g. ANNAM0126_214, ANNAM-KL-01
  final String topic;
  final String category;
  final String location;
  final String state;
  final bool isActive;
  final Map<String, dynamic> raw;

  StationCandidate({
    required this.deviceKey,
    required this.deviceId,
    required this.sensorName,
    required this.displayName,
    required this.topic,
    required this.category,
    required this.location,
    required this.state,
    required this.isActive,
    required this.raw,
  });
}

/// A single timestamped measurement
class ComparisonPoint {
  final DateTime timestamp;
  final double value;

  ComparisonPoint({required this.timestamp, required this.value});
}

/// An aligned point matching two or three stations at a given timestamp
class AlignedComparisonRow {
  final DateTime timestamp;
  final double? valA;
  final double? valB;
  final double? valC;

  double? get deltaAB => (valA != null && valB != null) ? (valA! - valB!) : null;

  AlignedComparisonRow({
    required this.timestamp,
    this.valA,
    this.valB,
    this.valC,
  });
}

/// Summary metrics computed across the dataset
class ComparisonStats {
  final double? currentA;
  final double? currentB;
  final double? currentDelta;
  final double? minA;
  final double? maxA;
  final double? avgA;
  final double? minB;
  final double? maxB;
  final double? avgB;
  final double? avgDelta;
  final double? maxDelta;
  final double? correlation; // Pearson r (-1 to +1)
  final String insight;

  ComparisonStats({
    this.currentA,
    this.currentB,
    this.currentDelta,
    this.minA,
    this.maxA,
    this.avgA,
    this.minB,
    this.maxB,
    this.avgB,
    this.avgDelta,
    this.maxDelta,
    this.correlation,
    required this.insight,
  });
}

/// Supported comparison parameters
enum ComparisonParam {
  temperature,
  humidity,
  pressure,
  windSpeed,
  rainfall,
  solar,
  heatIndex,
  dewPoint,
  deltaT,
  battery,
}

extension ComparisonParamExt on ComparisonParam {
  String get label {
    switch (this) {
      case ComparisonParam.temperature:
        return 'Temperature';
      case ComparisonParam.humidity:
        return 'Humidity';
      case ComparisonParam.pressure:
        return 'Atm Pressure';
      case ComparisonParam.windSpeed:
        return 'Wind Speed';
      case ComparisonParam.rainfall:
        return 'Rainfall';
      case ComparisonParam.solar:
        return 'Solar / Light';
      case ComparisonParam.heatIndex:
        return 'Heat Index';
      case ComparisonParam.dewPoint:
        return 'Dew Point';
      case ComparisonParam.deltaT:
        return 'Delta T (Spray)';
      case ComparisonParam.battery:
        return 'Battery Voltage';
    }
  }

  String get unit {
    switch (this) {
      case ComparisonParam.temperature:
      case ComparisonParam.heatIndex:
      case ComparisonParam.dewPoint:
      case ComparisonParam.deltaT:
        return '°C';
      case ComparisonParam.humidity:
        return '%';
      case ComparisonParam.pressure:
        return 'hPa';
      case ComparisonParam.windSpeed:
        return 'm/s';
      case ComparisonParam.rainfall:
        return 'mm';
      case ComparisonParam.solar:
        return 'W/m²';
      case ComparisonParam.battery:
        return 'V';
    }
  }

  String get iconSymbol {
    switch (this) {
      case ComparisonParam.temperature:
        return '🌡️';
      case ComparisonParam.humidity:
        return '💧';
      case ComparisonParam.pressure:
        return '⏱️';
      case ComparisonParam.windSpeed:
        return '💨';
      case ComparisonParam.rainfall:
        return '🌧️';
      case ComparisonParam.solar:
        return '☀️';
      case ComparisonParam.heatIndex:
        return '🔥';
      case ComparisonParam.dewPoint:
        return '❄️';
      case ComparisonParam.deltaT:
        return '🎯';
      case ComparisonParam.battery:
        return '🔋';
    }
  }
}

class StationComparisonService {
  static const List<String> _stationListUrls = [
    "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity",
    "https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api",
  ];

  /// Fetch and parse all active/available stations across the network
  static Future<List<StationCandidate>> fetchAllStations() async {
    try {
      final responses = await Future.wait(
        _stationListUrls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching station activity $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      final List<Map<String, dynamic>> allRaw = [];
      for (final res in responses) {
        if (res.statusCode == 200) {
          try {
            final data = json.decode(res.body);
            final List<dynamic>? list = data["devices"];
            if (list != null && list.isNotEmpty) {
              allRaw.addAll(list.cast<Map<String, dynamic>>());
            }
          } catch (_) {}
        }
      }

      final Map<String, StationCandidate> uniqueMap = {};
      final now = DateTime.now();

      for (final d in allRaw) {
        final devKey = d["deviceid#topic"]?.toString() ?? "";
        final deviceId = (d['DeviceId'] ??
                d['Device_ID'] ??
                d['ANNAM_ID'] ??
                (devKey.contains('#') ? devKey.split('#')[0] : devKey))
            .toString();

        final sensorName = DevicePrefixUtils.resolveSensorNameFromDevice(d);
        if (sensorName.isEmpty) continue;

        // Skip internal testing noise
        final snUpper = sensorName.toUpperCase();
        if (snUpper == 'TS018' || snUpper == 'ANNAM001') continue;

        final displaySensorName = DevicePrefixUtils.toAnnamDisplayName(sensorName);
        final rawTopic = (d['Topic'] ??
                d['topic'] ??
                (devKey.contains('#') ? devKey.split('#')[1] : ""))
            .toString()
            .trim();
        final mapped = DevicePrefixUtils.mapCategoryAndPrefix(rawTopic);
        final topic = (rawTopic.isNotEmpty && rawTopic != "Unknown")
            ? rawTopic
            : DevicePrefixUtils.buildTopicFromSensorName(sensorName).split('#').last;

        // Active state check (< 2 hours)
        DateTime? lastTime;
        final rawTime = d['TimeStamp_IST'] ??
            d['TimeStamp'] ??
            d['Time_Stamp'] ??
            d['human_time'] ??
            d['timestamp'];
        if (rawTime != null) {
          lastTime = DateTime.tryParse(rawTime.toString());
          if (lastTime == null) {
            try {
              lastTime = DateFormat("yyyy-MM-dd HH:mm:ss").parse(rawTime.toString());
            } catch (_) {}
          }
        }
        final bool isActive = lastTime != null && now.difference(lastTime).inHours <= 2;
        final location = HomeUtils.getFormattedLocation(d);
        final state = (d['State'] ?? d['state'] ?? '').toString();

        final candidate = StationCandidate(
          deviceKey: devKey.isNotEmpty ? devKey : '$sensorName#$topic',
          deviceId: deviceId,
          sensorName: sensorName,
          displayName: displaySensorName.isNotEmpty ? displaySensorName : sensorName,
          topic: topic,
          category: mapped.category,
          location: location.isNotEmpty ? location : 'India',
          state: state.isNotEmpty ? state : 'Punjab / Kerala',
          isActive: isActive,
          raw: d,
        );

        uniqueMap[sensorName] = candidate;
      }

      final list = uniqueMap.values.toList();
      // Natural sorting: active first, then alphabetic
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.displayName.compareTo(b.displayName);
      });

      return list;
    } catch (e) {
      debugPrint("Error in fetchAllStations: $e");
      return [];
    }
  }

  /// Fetches historical readings for a given station across a time range
  static Future<List<Map<String, dynamic>>> fetchStationHistory({
    required String sensorName,
    required String range, // '1day', '7days', '30days'
    DateTime? selectedDate,
  }) async {
    final config = DeviceConfig.getConfig(sensorName);
    if (config == null) return [];

    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate = now;

    switch (range) {
      case '7days':
        endDate = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        startDate = endDate.subtract(const Duration(days: 6));
        break;
      case '30days':
        startDate = now.subtract(const Duration(days: 30));
        break;
      case '1day':
      default:
        startDate = selectedDate ?? now;
        endDate = startDate;
        break;
    }

    final dateFormatter = DateFormat('dd-MM-yyyy');
    final startStr = dateFormatter.format(startDate);
    final endStr = dateFormatter.format(endDate);

    // Build URL from template
    String template = config.apiTemplate ?? '';
    if (range == '7days' && config.historyApiTemplate != null) {
      template = config.historyApiTemplate!;
    } else if (range == '30days' && config.monthHistoryApiTemplate != null) {
      template = config.monthHistoryApiTemplate!;
    }

    if (template.isEmpty) return [];

    // Numeric ID resolution
    String deviceIdOnly = sensorName.replaceAll(RegExp(r'[^0-9]'), '');
    int deviceIdNumeric = int.tryParse(deviceIdOnly) ?? 1;
    String deviceIdStr = sensorName;

    if (sensorName.startsWith('AWS_')) {
      deviceIdStr = sensorName.substring(4);
    } else if (RegExp(r'^[A-Za-z]{2}').hasMatch(sensorName)) {
      deviceIdStr = sensorName.substring(2);
    }
    if (RegExp(r'^\d+$').hasMatch(deviceIdStr)) {
      deviceIdStr = int.parse(deviceIdStr).toString();
    }

    if (sensorName.toUpperCase().startsWith('AT')) {
      deviceIdStr = 'AWS_Testing_$deviceIdNumeric';
    } else if (sensorName.startsWith('KR') ||
        sensorName.startsWith('PJ') ||
        sensorName.contains('Punjab') ||
        sensorName.contains('ANNAM-PB') ||
        sensorName.contains('ANNAM-KL')) {
      deviceIdStr = deviceIdNumeric.toString();
    } else if (sensorName.toUpperCase().startsWith('SH') ||
        sensorName.toUpperCase().startsWith('SOBHA')) {
      deviceIdStr = (deviceIdNumeric != 0 ? deviceIdNumeric : 1).toString();
    }

    String deviceIdPadded = deviceIdNumeric.toString().padLeft(3, '0');
    String deviceIdPadded2 = deviceIdNumeric.toString().padLeft(2, '0');
    String monthAbbr = DateFormat('MMM').format(endDate).toLowerCase();
    String startdateYMD = DateFormat('yyyy-MM-dd').format(startDate);
    String enddateYMD = DateFormat('yyyy-MM-dd').format(endDate);

    final url = template
        .replaceAll('{deviceId}', deviceIdStr)
        .replaceAll('{deviceIdPadded}', deviceIdPadded)
        .replaceAll('{deviceIdPadded2}', deviceIdPadded2)
        .replaceAll('{monthAbbr}', monthAbbr)
        .replaceAll('{deviceName}', sensorName)
        .replaceAll('{strDeviceId}', sensorName)
        .replaceAll('{cpDeviceId}', sensorName == 'CP001' ? '1' : '3')
        .replaceAll('{startdate}', startStr)
        .replaceAll('{enddate}', endStr)
        .replaceAll('{startdate_yyyy_mm_dd}', startdateYMD)
        .replaceAll('{enddate_yyyy_mm_dd}', enddateYMD)
        .replaceAll('{year}', endDate.year.toString())
        .replaceAll('{month}', endDate.month.toString());

    try {
      final sep = url.contains('?') ? '&' : '?';
      final cacheBusterUrl = '$url${sep}t=${DateTime.now().millisecondsSinceEpoch}';
      final res = await http.get(Uri.parse(cacheBusterUrl)).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        } else if (data is Map<String, dynamic>) {
          final List<dynamic>? items = data['items'] ?? data['sensor_data_items'] ?? data['weather_items'];
          if (items != null) {
            return items.cast<Map<String, dynamic>>();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching station history for $sensorName: $e");
    }
    return [];
  }

  /// Parses timestamps safely across diverse sensor formats
  static DateTime? parseSensorDate(dynamic dateVal) {
    if (dateVal == null) return null;
    final s = dateVal.toString().trim();
    if (s.isEmpty) return null;

    final epoch = int.tryParse(s);
    if (epoch != null && s.length >= 10) {
      if (s.length == 10) return DateTime.fromMillisecondsSinceEpoch(epoch * 1000);
      return DateTime.fromMillisecondsSinceEpoch(epoch);
    }

    final formats = [
      'yyyy-MM-dd HH:mm:ss',
      'dd-MM-yyyy HH:mm:ss',
      'dd/MM/yyyy HH:mm:ss',
      'yyyy-MM-ddTHH:mm:ss',
      'yyyy-MM-dd hh:mm a',
      'yyyy/MM/dd,HH:mm:ss',
      'yyyy-MM-dd',
      'dd-MM-yyyy',
    ];

    for (final fmt in formats) {
      try {
        return DateFormat(fmt).parse(s);
      } catch (_) {}
    }
    return DateTime.tryParse(s);
  }

  /// Extracts numeric value for the requested ComparisonParam
  static double? extractParamValue(Map<String, dynamic> item, ComparisonParam param) {
    double? parseD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    double? tryKeys(List<String> keys) {
      for (final k in keys) {
        if (item.containsKey(k) && item[k] != null) {
          final val = parseD(item[k]);
          if (val != null) return val;
        }
      }
      for (final k in keys) {
        final lowerK = k.toLowerCase();
        for (final entry in item.entries) {
          if (entry.key.toLowerCase() == lowerK && entry.value != null) {
            final val = parseD(entry.value);
            if (val != null) return val;
          }
        }
      }
      return null;
    }

    switch (param) {
      case ComparisonParam.temperature:
        return tryKeys([
          'CurrentTemperature',
          'current_temperature',
          'Temperature',
          'temperature',
          'NowTemperature',
          'now_temperature',
          'temp',
          'temp_c',
          'AverageTemperature',
          'DailyMaximumTemperature',
          'MaximumTemperature',
          'CorrectedTemp',
          'CorrectedTemperature',
        ]);

      case ComparisonParam.humidity:
        return tryKeys([
          'CurrentHumidity',
          'current_humidity',
          'Humidity',
          'humidity',
          'NowRelativeHumidity',
          'now_relative_humidity',
          'now_humidity',
          'AverageHumidity',
          'MaximumRelativeHumidity',
          'CorrectedHumidity',
        ]);

      case ComparisonParam.pressure:
        return tryKeys([
          'now_pressure',
          'NowPressure',
          'AtmPressure',
          'CurrentPressure',
          'pressure',
          'Pressure',
          'Average_Pressure',
          'Maximum_Pressure',
        ]);

      case ComparisonParam.windSpeed:
        return tryKeys([
          'NowWindSpeed',
          'now_wind_speed',
          'CurrentWindSpeed',
          'WindSpeed',
          'wind_speed',
          'AverageWindSpeed',
          'max_wind_gust',
        ]);

      case ComparisonParam.rainfall:
        return tryKeys([
          'Rainfall',
          'rainfall',
          'RainfallHourly',
          'RainfallDaily',
          'RainfallCumulative',
          'RainLevel',
          'RainfallHourlyComulative',
          'RainfallDailyComulative',
        ]);

      case ComparisonParam.solar:
        return tryKeys([
          'now_light',
          'Solar_Radiation',
          'SolarRadiation',
          'Radiation',
          'LightIntensity',
          'solar_radiation',
          'PAR',
          'lux',
        ]);

      case ComparisonParam.battery:
        return tryKeys([
          'BatteryVoltage',
          'battery_voltage',
          'voltage',
          'Battery',
          'PanelVoltage',
        ]);

      // Derived Metrics computed on-the-fly if not in backend payload
      case ComparisonParam.dewPoint:
        final existing = parseD(item['DewPoint'] ?? item['dew_point']);
        if (existing != null) return existing;
        final t = extractParamValue(item, ComparisonParam.temperature);
        final rh = extractParamValue(item, ComparisonParam.humidity);
        if (t != null && rh != null && rh > 0) {
          const a = 17.27;
          const b = 237.7;
          final alpha = ((a * t) / (b + t)) + math.log(rh / 100.0);
          return (b * alpha) / (a - alpha);
        }
        return null;

      case ComparisonParam.heatIndex:
        final existing = parseD(item['HeatIndex'] ?? item['Heat_Index_Feels_Like'] ?? item['feels_like']);
        if (existing != null) return existing;
        final t = extractParamValue(item, ComparisonParam.temperature);
        final rh = extractParamValue(item, ComparisonParam.humidity);
        if (t != null && rh != null) {
          if (t < 27.0) return t;
          final tf = (t * 9.0 / 5.0) + 32.0;
          final hiF = -42.379 +
              (2.04901523 * tf) +
              (10.14333127 * rh) -
              (0.22475541 * tf * rh) -
              (0.00683783 * tf * tf) -
              (0.05481717 * rh * rh) +
              (0.00122874 * tf * tf * rh) +
              (0.00085282 * tf * rh * rh) -
              (0.00000199 * tf * tf * rh * rh);
          return (hiF - 32.0) * 5.0 / 9.0;
        }
        return null;

      case ComparisonParam.deltaT:
        final existing = parseD(item['DeltaT'] ?? item['delta_t']);
        if (existing != null) return existing;
        final t = extractParamValue(item, ComparisonParam.temperature);
        final rh = extractParamValue(item, ComparisonParam.humidity);
        if (t != null && rh != null) {
          // Stull's Wet Bulb
          final twb = t * math.atan(0.151977 * math.sqrt(rh + 8.313659)) +
              math.atan(t + rh) -
              math.atan(rh - 1.676331) +
              0.00391838 * math.pow(rh, 1.5) * math.atan(0.023101 * rh) -
              4.686035;
          return t - twb;
        }
        return null;
    }
  }

  /// Converts raw records into timestamped ComparisonPoints sorted by time
  static List<ComparisonPoint> extractPoints(
    List<Map<String, dynamic>> rawList,
    ComparisonParam param,
  ) {
    final List<ComparisonPoint> points = [];
    for (final item in rawList) {
      final tsStr = item['TimeStamp_IST'] ??
          item['TimeStamp'] ??
          item['Time_Stamp'] ??
          item['human_time'] ??
          item['HumanTime'] ??
          item['timestamp'] ??
          item['EpochTime'];
      final dt = parseSensorDate(tsStr);
      if (dt == null) continue;

      final val = extractParamValue(item, param);
      if (val != null && !val.isNaN && !val.isInfinite) {
        // Sanity boundary checks
        if (param == ComparisonParam.humidity && (val < 0 || val > 100)) continue;
        if (param == ComparisonParam.temperature && (val < -40 || val > 75)) continue;
        if (param == ComparisonParam.pressure && (val < 300 || val > 1200)) continue;
        points.add(ComparisonPoint(timestamp: dt, value: val));
      }
    }
    points.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return points;
  }

  /// Aligns time series from Station A and Station B into matching time buckets
  static List<AlignedComparisonRow> alignSeries({
    required List<ComparisonPoint> seriesA,
    required List<ComparisonPoint> seriesB,
    List<ComparisonPoint>? seriesC,
    Duration bucketSize = const Duration(minutes: 30),
  }) {
    if (seriesA.isEmpty && seriesB.isEmpty) return [];

    // Bucket helper: rounds to bucketSize
    DateTime toBucket(DateTime dt) {
      final ms = dt.millisecondsSinceEpoch;
      final bucketMs = bucketSize.inMilliseconds;
      final rounded = (ms / bucketMs).round() * bucketMs;
      return DateTime.fromMillisecondsSinceEpoch(rounded);
    }

    final Map<DateTime, double> bucketA = {};
    for (final p in seriesA) {
      bucketA[toBucket(p.timestamp)] = p.value;
    }

    final Map<DateTime, double> bucketB = {};
    for (final p in seriesB) {
      bucketB[toBucket(p.timestamp)] = p.value;
    }

    final Map<DateTime, double> bucketC = {};
    if (seriesC != null) {
      for (final p in seriesC) {
        bucketC[toBucket(p.timestamp)] = p.value;
      }
    }

    final Set<DateTime> allTimes = {
      ...bucketA.keys,
      ...bucketB.keys,
      ...bucketC.keys,
    };

    final sortedTimes = allTimes.toList()..sort();
    return sortedTimes.map((t) {
      return AlignedComparisonRow(
        timestamp: t,
        valA: bucketA[t],
        valB: bucketB[t],
        valC: bucketC[t],
      );
    }).toList();
  }

  /// Computes statistical contrast and Pearson correlation between Station A and Station B
  static ComparisonStats computeStats({
    required List<AlignedComparisonRow> alignedRows,
    required String nameA,
    required String nameB,
    required ComparisonParam param,
  }) {
    final validA = alignedRows.where((r) => r.valA != null).map((r) => r.valA!).toList();
    final validB = alignedRows.where((r) => r.valB != null).map((r) => r.valB!).toList();

    double? minA = validA.isNotEmpty ? validA.reduce(math.min) : null;
    double? maxA = validA.isNotEmpty ? validA.reduce(math.max) : null;
    double? avgA = validA.isNotEmpty ? (validA.reduce((a, b) => a + b) / validA.length) : null;

    double? minB = validB.isNotEmpty ? validB.reduce(math.min) : null;
    double? maxB = validB.isNotEmpty ? validB.reduce(math.max) : null;
    double? avgB = validB.isNotEmpty ? (validB.reduce((a, b) => a + b) / validB.length) : null;

    final paired = alignedRows.where((r) => r.valA != null && r.valB != null).toList();
    double? avgDelta;
    double? maxDelta;
    double? rCoeff;

    if (paired.isNotEmpty) {
      final deltas = paired.map((r) => r.valA! - r.valB!).toList();
      avgDelta = deltas.reduce((a, b) => a + b) / deltas.length;
      maxDelta = deltas.map((d) => d.abs()).reduce(math.max);

      // Pearson correlation r calculation
      final n = paired.length;
      if (n >= 3) {
        final meanA = paired.map((p) => p.valA!).reduce((a, b) => a + b) / n;
        final meanB = paired.map((p) => p.valB!).reduce((a, b) => a + b) / n;

        double num = 0;
        double denA = 0;
        double denB = 0;

        for (final p in paired) {
          final da = p.valA! - meanA;
          final db = p.valB! - meanB;
          num += da * db;
          denA += da * da;
          denB += db * db;
        }

        final den = math.sqrt(denA * denB);
        if (den > 0) {
          rCoeff = (num / den).clamp(-1.0, 1.0);
        }
      }
    }

    final currentA = validA.isNotEmpty ? validA.last : null;
    final currentB = validB.isNotEmpty ? validB.last : null;
    final currentDelta = (currentA != null && currentB != null) ? (currentA - currentB) : null;

    // Generate analytical insight text
    String insight;
    if (avgDelta == null || avgA == null || avgB == null) {
      insight = "Waiting for overlapping sensor data between $nameA and $nameB to compute micro-climate correlation.";
    } else {
      final diffAbs = avgDelta.abs().toStringAsFixed(1);
      final higher = avgDelta > 0 ? nameA : nameB;
      final lower = avgDelta > 0 ? nameB : nameA;

      String corrText = "";
      if (rCoeff != null) {
        if (rCoeff > 0.8) {
          corrText = " Both stations exhibit very strong positive correlation (r = ${rCoeff.toStringAsFixed(2)}), moving synchronously with broader regional fronts.";
        } else if (rCoeff > 0.4) {
          corrText = " Moderate correlation (r = ${rCoeff.toStringAsFixed(2)}) reflects shared weather patterns with localized deviations.";
        } else if (rCoeff < -0.3) {
          corrText = " Inverse correlation (r = ${rCoeff.toStringAsFixed(2)}) indicates opposing micro-climates (e.g. coastal maritime vs. dry inland).";
        } else {
          corrText = " Low correlation (r = ${rCoeff.toStringAsFixed(2)}) highlights strong local micro-climate independence.";
        }
      }

      insight = "On average, $higher recorded $diffAbs${param.unit} higher ${param.label.toLowerCase()} than $lower across this period.$corrText";
    }

    return ComparisonStats(
      currentA: currentA,
      currentB: currentB,
      currentDelta: currentDelta,
      minA: minA,
      maxA: maxA,
      avgA: avgA,
      minB: minB,
      maxB: maxB,
      avgB: avgB,
      avgDelta: avgDelta,
      maxDelta: maxDelta,
      correlation: rCoeff,
      insight: insight,
    );
  }

  /// Converts aligned comparison rows into a standard CSV string
  static String generateCsv({
    required List<AlignedComparisonRow> rows,
    required String nameA,
    required String nameB,
    String? nameC,
    required ComparisonParam param,
  }) {
    final buffer = StringBuffer();
    final df = DateFormat('yyyy-MM-dd HH:mm:ss');

    if (nameC != null) {
      buffer.writeln('Timestamp,${nameA}_${param.label} (${param.unit}),${nameB}_${param.label} (${param.unit}),${nameC}_${param.label} (${param.unit}),Delta_${nameA}_minus_${nameB}');
      for (final r in rows) {
        final t = df.format(r.timestamp);
        final a = r.valA?.toStringAsFixed(2) ?? '';
        final b = r.valB?.toStringAsFixed(2) ?? '';
        final c = r.valC?.toStringAsFixed(2) ?? '';
        final delta = r.deltaAB?.toStringAsFixed(2) ?? '';
        buffer.writeln('$t,$a,$b,$c,$delta');
      }
    } else {
      buffer.writeln('Timestamp,${nameA}_${param.label} (${param.unit}),${nameB}_${param.label} (${param.unit}),Delta (${param.unit})');
      for (final r in rows) {
        final t = df.format(r.timestamp);
        final a = r.valA?.toStringAsFixed(2) ?? '';
        final b = r.valB?.toStringAsFixed(2) ?? '';
        final delta = r.deltaAB?.toStringAsFixed(2) ?? '';
        buffer.writeln('$t,$a,$b,$delta');
      }
    }

    return buffer.toString();
  }
}
