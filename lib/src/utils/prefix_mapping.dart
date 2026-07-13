import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Central utility for mapping internal device IDs to display-friendly ANNAM prefixes.
/// Consistent naming convention for CloudSense WebApp modernization.

class DevicePrefixUtils {
  /// Strips administrative suffixes from district strings.
  /// e.g. "Rupnagar district" → "Rupnagar", "Rupnagar Tahsil" → "Rupnagar"
  static String cleanDistrict(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    const suffixes = [
      'sub-district',
      'sub district',
      'district',
      'tahsil',
      'tehsil',
      'division',
      'taluka',
      'taluk',
      'block',
      'mandal',
    ];
    String result = raw.trim();
    final lower = result.toLowerCase();
    for (final suffix in suffixes) {
      if (lower.endsWith(' $suffix')) {
        result = result.substring(0, result.length - suffix.length - 1).trim();
        break;
      }
    }
    // Capitalise first letter, lowercase the rest
    if (result.isEmpty) return '';
    return result[0].toUpperCase() + result.substring(1);
  }

  /// Regular expression to match prefix letters at the start of an ID.
  static final RegExp _prefixRegex = RegExp(r'^[A-Z]{2}');

  /// Converts an internal sensor name (e.g., WJ201) to its display-friendly
  /// ANNAM-themed name (e.g., ANNAM0126_201).
  static String toAnnamDisplayName(String internalId) {
    if (internalId == null || internalId.isEmpty) return "";

    final upper = internalId.toUpperCase().trim();
    // Extract numeric part (e.g., WJ201 -> 201)
    final digits = upper.replaceAll(_prefixRegex, '');
    final prefix = _prefixRegex.stringMatch(upper) ?? '';

    // NEW: SH sensors (Shobha) -> WS_Shobha_
    if (upper.startsWith('SH')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'WS_Shobha_$num' : 'WS_Shobha_$cleanDigits';
    }

    // 1. WJ sensors (Jan Weather 0126) -> ANNAM0126_
    if (upper.startsWith('WJ')) return 'ANNAM0126_$digits';

    // 2. WF sensors (Feb Weather 0226) -> ANNAM0226_
    if (upper.startsWith('WF')) return 'ANNAM0226_$digits';

    // 3. WA sensors (April Weather 0426) -> ANNAM0426_
    if (upper.startsWith('WA')) return 'ANNAM0426_$digits';

    // 4. WM sensors (May Weather 0526) -> TS0526_
    if (upper.startsWith('WM')) return 'TS0526_$digits';

    // NEW: WN sensors (Winds Weather) -> Winds_
    if (upper.startsWith('WN')) return 'Winds_$digits';

    // NEW: JW sensors (Jio Winds) -> JIO_WINDS_
    if (upper.startsWith('JW')) return 'JIO_WINDS_$digits';

    // NEW: KR sensors (Kerala) -> ANNAM/Kerala/WS_
    if (upper.startsWith('KR')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM/Kerala/WS_$num' : 'ANNAM/Kerala/WS_$cleanDigits';
    }

    // NEW: AW sensors (AWS) -> AWS_
    if (upper.startsWith('AW')) {
      // If it already starts with AWS_, the digits part might contain 'S_'
      // Let's strip any non-digit characters to get just the number
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'AWS_$num' : 'AWS_$cleanDigits';
    }

    // 5. PC sensors (Polytechnic) -> ANNAM/PC_
    if (upper.startsWith('PC')) return 'ANNAM/PC_$digits';

    // 6. GP sensors (Polytechnic) -> ANNAM/PC_
    if (upper.startsWith('GP')) return 'ANNAM/GPC_$digits';

    // 5. Testing group (CP other than CP001, plus WT) -> TS_
    if (upper.startsWith('WT') ||
        (upper.startsWith('CP') && upper != 'CP001')) {
      return 'TS_$digits';
    }

    // NEW: DM sensors under Testing with DM_ prefix
    if (upper.startsWith('DM')) {
      return 'DM_$digits';
    }

    // 6. Other ANNAM group (CF, CP001, SW007, SW013)
    if (isAnnamCoreSensor(upper)) {
      return 'ANNAM$digits';
    }

    // 7. Default (Partnership/Others) - return prefix_digits or original if no digits
    return digits.isNotEmpty ? '${prefix}_$digits' : upper;
  }

  /// Resolves a canonical internal sensor ID (e.g. 'SH001', 'WJ201') from
  /// a raw API [deviceId] and its MQTT [topic].
  ///
  /// This is the recommended approach when building sensor names from API list
  /// responses (admin page, device map, etc.) because it safely handles cases
  /// where the API already returns the full prefixed display name as the
  /// deviceId (e.g. Shobha returns 'WS_Shobha_1' as DeviceId).
  ///
  /// If [topic] is non-empty the function maps the topic to the correct
  /// two-letter prefix and derives the numeric suffix purely from digits in
  /// [deviceId], avoiding duplication.  Falls back to [deviceId] when no
  /// prefix can be determined.
  static String resolveSensorName(String deviceId, String topic) {
    final mapped = mapCategoryAndPrefix(topic);
    final prefix = mapped.prefix;
    if (prefix.isEmpty) return deviceId;

    // Extract only the trailing numeric portion of deviceId so we never
    // concatenate an already-prefixed string (e.g. 'WS_Shobha_1' → '1').
    final digitsMatch = RegExp(r'\d+$').firstMatch(deviceId);
    if (digitsMatch == null) {
      // No digits found; use deviceId as-is to avoid returning garbage.
      return deviceId;
    }
    final digits = digitsMatch.group(0)!;
    return '$prefix${digits.padLeft(3, '0')}';
  }

  /// Categorizes if a sensor belongs to the core ANNAM group (non-testing).
  static bool isAnnamCoreSensor(String internalId) {
    if (internalId == null) return false;
    final upper = internalId.toUpperCase().trim();

    // Specific exclusions (Legacy sensors)
    if (upper == 'WJ156' || upper == 'WJ157') return false;

    return upper.startsWith('CF') ||
        upper.startsWith('WJ') ||
        upper.startsWith('WA') ||
        upper.startsWith('WF') ||
        upper.startsWith('PC') ||
        upper.startsWith('GP') ||
        upper.startsWith('KR') ||
        upper.startsWith('AW') ||
        upper == 'CP001' ||
        upper == 'SW007' ||
        upper == 'SW013';
  }

  /// Identifies if a sensor is part of the ANNAM Testing group (TS_).
  static bool isAnnamTestingSensor(String internalId) {
    if (internalId == null) return false;
    final upper = internalId.toUpperCase().trim();
    return (upper.startsWith('CP') && upper != 'CP001') ||
        upper.startsWith('WT') ||
        upper.startsWith('DM') ||
        upper.startsWith('WM') ||
        upper.startsWith('WN');
  }

  /// Converts an internal sensor name (e.g., 'WJ201') into its MQTT topic string
  /// (e.g., '201#WS/SSMet_0126/201').
  static String buildTopicFromSensorName(String sensorName) {
    sensorName = sensorName.trim().toUpperCase();

    // 1. SI (Synthite) sensors
    if (sensorName.startsWith('SI')) {
      final match = RegExp(r'([A-Z]\d)$').firstMatch(sensorName);
      if (match != null) {
        final idPart = match.group(1)!;
        return "$idPart#SSMet/custom/1225/$idPart";
      }
      return "C0#SSMet/custom/1225/C0";
    }

    // 1.5 Handle KRWS_NNN (Kerala devices)
    if (sensorName.startsWith('KRWS_')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "WS_$id#WS/Kerala/$id";
    }

    // 1.6 Handle AWS devices
    if (sensorName.startsWith('AW')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "AWS_$id#AWS/$id";
    }

    // 2. Standard numeric extraction for standard prefixes
    final reg = RegExp(r'^([A-Z]{1,3})(\d{1,4})$');
    final match = reg.firstMatch(sensorName);

    if (match == null) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "$id#WS/Unknown/$id";
    }

    final String prefix = match.group(1)!;
    final int id = int.parse(match.group(2)!);

    switch (prefix) {
      case "NA":
        return "$id#WS/SSMet/NARL/$id";
      case "CP":
        return "$id#WS/Campus/$id";
      case "WT":
        return "$id#Weather/sensor/$id";
      case "DM":
        return "$id#Demo/Device/$id";
      case "IT":
        return "$id#Awadh/IIT_B";
      case "CF":
        return "2#WS/Campus/2";
      case "KJ":
        return "$id#WS/SSMet/KJSCE/$id";
      case "SM":
        // Special case for SM001
        if (id == 1) return "1#IIT/WS/SSMet/1";
        return "$id#WS/SSMet/Railway/$id";
      case "SW":
        return "$id#WS/SSMET_1225/$id";
      case "WJ":
        return "$id#WS/SSMet_0126/$id";
      case "WF":
        return "$id#WS/SSMET_0226/$id";
      case "WA":
        return "$id#WS/Annam_0426/$id";
      case "WM":
        return "$id#WS/Annam_0526/$id";
      case "WN":
        return "$id#Winds/Sensor/$id";
      case "JW":
        return "$id#WS_WINDS/Jio_Logger/$id";
      case "FS":
        return "$id#SSMet/Forest";
      case "SV":
        return "$id#WS/SVPU/$id";
      case "MY":
        return "$id#WS/Mysuru/$id";
      case "KD":
        return "$id#WS/KARGIL/$id";
      case "SS":
        return "$id#SSMet/Soil/$id";
      case "VD":
        return "$id#WS/Vanix/0$id";
      case "PC":
        return "$id#WS/Polytechnic/$id";
      case "GP":
        return "$id#WS/GPC/$id";
      case "KR":
        return "WS_$id#WS/Kerala/$id";
      case "SH":
        return "WS_Shobha_$id#WS/Shobha/$id";
      default:
        return "$id#WS/Unknown/$id";
    }
  }

  /// Extracts the internal sensor name from a full topic string (e.g., '201#WS/SSMet_0126/201' -> 'WJ201').
  /// Returns null if the topic format is unrecognized.
  static String? getSensorNameFromTopic(String fullTopic) {
    if (fullTopic.isEmpty) return null;
    final parts = fullTopic.split('#');
    if (parts.length < 2) return null;

    final id = parts[0];
    final topicPath = parts[1];
    final paddedId = id.toString().padLeft(3, '0');

    // Logic based on home_page.dart's topic discovery
    if (topicPath.startsWith('Demo/Device/')) return 'DM$paddedId';
    if (topicPath.startsWith('WS/Campus/')) {
      if (paddedId == '002') return 'CF002';
      if (paddedId == '001') return 'CP001';
      return 'CP$paddedId'; // Default for Campus if not 001/002
    }
    if (topicPath.startsWith('WS/SSMet/NARL/')) return 'NA$paddedId';
    if (topicPath.startsWith('WS/SSMet/KJSCE/')) return 'KJ$paddedId';
    if (topicPath.startsWith('WS/SSMet_0126/')) return 'WJ$paddedId';
    if (topicPath.startsWith('WS/Annam_0426/')) return 'WA$paddedId';
    if (topicPath.startsWith('WS_WINDS/Jio_Logger/')) return 'JW$paddedId';
    if (topicPath.startsWith('WS/Winds_WN/') ||
        topicPath.startsWith('WINDS/') ||
        topicPath.startsWith('Winds/Sensor/')) return 'WN$paddedId';
    if (topicPath.startsWith('WS/Annam_0526/')) return 'WM$paddedId';
    if (topicPath.startsWith('WS/SSMET_0226/')) return 'WF$paddedId';
    if (topicPath.startsWith('WS/SSMET_1225/')) {
      if (paddedId == '007' || paddedId == '013') return 'SW$paddedId';
      return 'SW$paddedId';
    }
    if (topicPath.startsWith('WS/SSMet/Railway/')) return 'SM$paddedId';
    if (topicPath.startsWith('WS/SSMet/')) return 'SM$paddedId';
    if (topicPath.startsWith('SSMet/Forest')) return 'FS$paddedId';
    if (topicPath.startsWith('WS/SVPU/')) return 'SV$paddedId';
    if (topicPath.startsWith('WS/Mysuru/')) return 'MY$paddedId';
    if (topicPath.startsWith('WS/KARGIL/')) return 'KD$paddedId';
    if (topicPath.startsWith('SSMet/Soil/')) return 'SS$paddedId';
    if (topicPath.startsWith('WS/Vanix/'))
      return 'VD${id.toString().padLeft(3, '0')}';
    if (topicPath.startsWith('SSMet/custom/1225/'))
      return 'SI${id.toString().padLeft(2, '0')}';
    if (topicPath.startsWith('Awadh/IIT_B')) return 'IT$paddedId';
    if (topicPath.startsWith('WS/Polytechnic/')) return 'PC$paddedId';
    if (topicPath.startsWith('WS/Shobha/')) return 'SH$paddedId';
    if (topicPath.startsWith('WS/GP/')) return 'GP$paddedId';
    if (topicPath.startsWith('WS/Kerala/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'KRWS_$cleanId';
    }
    if (topicPath.startsWith('WS/AWS/') || topicPath.startsWith('AWS/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'AW${cleanId.padLeft(3, '0')}';
    }
    if (topicPath.startsWith('Weather/sensor/')) return 'WT$paddedId';

    return null;
  }

  /// Maps an MQTT topic to its respective Category Name and internal Prefix.
  /// Used for grouping and labeling sensors in the Map and Admin views.
  static ({String category, String prefix}) mapCategoryAndPrefix(String topic) {
    if (topic == 'WS/Campus/2') {
      return (category: 'Sekhon Farm Sensor', prefix: 'CF');
    }
    if (topic.contains('WS/Campus')) {
      return (category: 'IIT Ropar Sensor', prefix: 'CP');
    }
    if (topic.contains('WS/SSMet/NARL')) {
      return (category: 'NARL Sensor', prefix: 'NA');
    }
    if (topic.contains('WS/SSMet/KJSCE')) {
      return (category: 'KJ Sensor', prefix: 'KJ');
    }
    if (topic.contains('IIT/WS/SSMet/1') ||
        topic.contains('WS/SSMet/Railway')) {
      return (category: 'SSMET Sensor', prefix: 'SM');
    }
    if (topic.contains('WS/SSMet_0126')) {
      return (category: 'Jan Weather Sensors', prefix: 'WJ');
    }
    if (topic.contains('Annam_0426')) {
      return (category: 'April Weather Sensors', prefix: 'WA');
    }
    if (topic.contains('Annam_0526')) {
      return (category: 'Testing Devices', prefix: 'WM');
    }
    final lowerTopic = topic.toLowerCase();
    if (lowerTopic.contains('shobha')) {
      return (category: 'Partnership', prefix: 'SH');
    }
    if (lowerTopic.contains('ws_winds/jio_logger') ||
        lowerTopic.contains('jio_logger')) {
      return (category: 'Partnership', prefix: 'JW');
    }
    if (lowerTopic.contains('winds_wn') ||
        lowerTopic.contains('winds/') ||
        lowerTopic.contains('winds_')) {
      return (category: 'Testing Devices', prefix: 'WN');
    }
    if (topic.contains('Weather/sensor')) {
      return (category: 'Testing Devices', prefix: 'WT');
    }
    if (topic.contains('WS/SSMet_0226')) {
      return (category: 'Feb Weather Sensors', prefix: 'WF');
    }
    if (topic.contains('WS/SSMET_1225')) {
      if (topic.startsWith('13#') || topic.contains('/13')) {
        return (category: 'Agri Bazar Sensor', prefix: 'SW');
      }
      if (topic.startsWith('7#') || topic.contains('/7')) {
        return (category: 'IMD Chandigarh Sensor', prefix: 'SW');
      } else {
        return (category: 'SSMET Weather sensor', prefix: 'SW');
      }
    }
    if (topic.contains('SSMet/custom/1225/C0')) {
      return (
        category: 'Synthite Industries\nPrivate Limited Sensor',
        prefix: 'SI'
      );
    }
    if (topic.contains('WS/SVPU')) {
      return (category: 'SVPU Sensor', prefix: 'SV');
    }
    if (topic.contains('Demo/Device')) {
      return (category: 'Testing Devices', prefix: 'DM');
    }
    if (topic.contains('Awadh/IIT_B')) {
      return (category: 'IIT Bombay Sensor', prefix: 'IT');
    }
    if (topic.contains('WS/Mysuru')) {
      return (category: 'Mysuru NIE Sensor', prefix: 'MY');
    }
    if (topic.contains('WS/KARGIL')) {
      return (category: 'Kargil Sensor', prefix: 'KD');
    }
    if (topic.contains('SSMet/Forest')) {
      return (category: 'Forest Sensor (Bhopal)', prefix: 'FS');
    }
    if (topic.contains('WS/Vanix')) {
      return (category: 'Vanix Sensor', prefix: 'VD');
    }
    if (topic.contains('WS/Polytechnic')) {
      return (category: 'ANNAM Sensors', prefix: 'PC');
    }

    if (topic.contains('WS/GPC')) {
      return (category: 'ANNAM Sensors', prefix: 'GP');
    }
    if (topic.contains('WS/Kerala')) {
      return (category: 'ANNAM Sensors', prefix: 'KR');
    }
    if (topic.contains('WS/AWS') || topic.contains('AWS/')) {
      return (category: 'ANNAM Sensors', prefix: 'AW');
    }
    if (topic.contains('SSMet/Soil')) {
      return (category: 'SSMet Soil sensor', prefix: 'SS');
    }
    if (topic.contains('WS/Aurassure')) {
      return (category: 'Aurassure Sensor', prefix: 'AS');
    }

    // Fallback search to catch standard SSMet generic topics
    if (topic.contains('WS/SSMet')) {
      return (category: 'SSMET Sensor', prefix: 'SM');
    }

    return (category: 'Unknown Sensor', prefix: '');
  }

  /// Parses various date formats returned by different sensor APIs.
  /// Handles: yyyyMMddTHHmmss, yyyy-MM-dd HH:mm:ss, and dd-MM-yyyy HH:mm:ss.
  static DateTime? parseDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty || dateStr == "N/A") return null;
    try {
      dateStr = dateStr.trim().replaceAll(RegExp(r'\s+'), ' ');

      // Compact format: yyyyMMddTHHmmss
      final compactRegex = RegExp(r'^\d{8}T\d{6}$');
      if (compactRegex.hasMatch(dateStr)) {
        final y = int.parse(dateStr.substring(0, 4));
        final m = int.parse(dateStr.substring(4, 6));
        final d = int.parse(dateStr.substring(6, 8));
        final H = int.parse(dateStr.substring(9, 11));
        final M = int.parse(dateStr.substring(11, 13));
        final S = int.parse(dateStr.substring(13, 15));
        return DateTime(y, m, d, H, M, S);
      }

      // Standard format: yyyy-MM-dd HH:mm:ss
      final standardRegex = RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$');
      if (standardRegex.hasMatch(dateStr)) return DateTime.parse(dateStr);

      // Custom format: dd-MM-yyyy HH:mm:ss
      final customRegex = RegExp(r'^\d{2}-\d{2}-\d{4} \d{2}:\d{2}:\d{2}$');
      if (customRegex.hasMatch(dateStr)) {
        final parts = dateStr.split(' ');
        final dateParts = parts[0].split('-');
        final timeParts = parts[1].split(':');
        final d = int.parse(dateParts[0]);
        final m = int.parse(dateParts[1]);
        final y = int.parse(dateParts[2]);
        final H = int.parse(timeParts[0]);
        final M = int.parse(timeParts[1]);
        final S = int.parse(timeParts[2]);
        return DateTime(y, m, d, H, M, S);
      }

      // Custom format: yyyy/MM/dd,HH:mm:ss (Winds WN Sensors)
      final windsRegex = RegExp(r'^\d{4}/\d{2}/\d{2},\d{2}:\d{2}:\d{2}$');
      if (windsRegex.hasMatch(dateStr)) {
        final parts = dateStr.split(',');
        final dateParts = parts[0].split('/');
        final timeParts = parts[1].split(':');
        final y = int.parse(dateParts[0]);
        final m = int.parse(dateParts[1]);
        final d = int.parse(dateParts[2]);
        final H = int.parse(timeParts[0]);
        final M = int.parse(timeParts[1]);
        final S = int.parse(timeParts[2]);
        return DateTime(y, m, d, H, M, S);
      }

      return DateTime.tryParse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Returns the appropriate OTA (Data Fetch) API URL for a given device.
  static String? getOtaApiUrl(String prefix, {String sensorName = ''}) {
    switch (prefix.toUpperCase()) {
      case 'KR':
        return 'https://f1hgmtzq6h.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Kerala';
      case 'CP':
        if (sensorName == 'CP001') {
          return 'https://eceufa3wc6.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_BTP';
        }
        return 'https://vczv54nfdc.execute-api.us-east-1.amazonaws.com/default/Data_fetch_Btp';
      case 'CF':
        return 'https://eceufa3wc6.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_BTP';
      case 'WF':
        return 'https://apen68q46i.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_SSMet0226';
      case 'WJ':
        return 'https://2jajsh64sd.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_SSMet0126';
      case "WA":
        return "https://k17dioqtpk.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Annam_0426";
      case "WM":
        return "https://kor2v4qdkj.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Annam_0526";
      case 'WN':
        return 'https://dwqomhli00.execute-api.us-east-1.amazonaws.com/default/Winds_WS_Data_API';
      case 'JW':
        return 'https://277fj9qud6.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Jio_Logger';
      case 'IT':
        return 'https://hg6lmrdyee.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Awadh_IITB';
      case 'WT':
        return 'https://uqevvzptx7.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_API_Weather_Sensor';
      case 'KR':
        return 'https://gj6wsq3214.execute-api.us-east-1.amazonaws.com/default/WS_Kerala_API';
      case 'AW':
        return 'https://ag25teqhvi.execute-api.us-east-1.amazonaws.com/default/AWS_Api_Function';
      case 'SH':
        return 'https://915gy7u30a.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_Shobha';
      default:
        return null;
    }
  }

  /// Returns the expected update interval for specific sensors.
  static String? getExpectedInterval(String sensorName) {
    const Map<String, String> updateIntervals = {
      'CP001': '5 min',
      'KJ001': '5 min',
      'IT001': '1 min',
      'FS101': '1 min',
      'CP011': '5 min',
      'CP015': '5 min',
      'NA016': '5 min',
      'VD002': '5 min',
      'CF002': '10 min',
      'NA023': '5 min',
      'CP005': '5 min',
      'CP009': '5 min',
      'PC001': '1 hour',
    };
    return updateIntervals[sensorName.toUpperCase()];
  }

  /// Returns a battery icon corresponding to the charge level.
  static IconData getBatteryIcon(int percentage) {
    if (percentage >= 95) return Icons.battery_full;
    if (percentage >= 85) return Icons.battery_6_bar;
    if (percentage >= 70) return Icons.battery_5_bar;
    if (percentage >= 55) return Icons.battery_4_bar;
    if (percentage >= 40) return Icons.battery_3_bar;
    if (percentage >= 25) return Icons.battery_2_bar;
    if (percentage >= 10) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  /// Returns a color representing the battery health.
  static Color getBatteryColor(int percentage) {
    if (percentage > 70) return Colors.green;
    if (percentage > 20) return Colors.orange;
    return Colors.red;
  }

  /// Returns a signal strength icon corresponding to the RSSI level.
  static IconData getSignalIcon(int strength) {
    if (strength >= 80) return Icons.signal_cellular_4_bar;
    if (strength >= 60) return Icons.signal_cellular_4_bar; // Fallback
    if (strength >= 40) return Icons.signal_cellular_4_bar; // Fallback
    if (strength >= 20) return Icons.signal_cellular_0_bar; // Fallback
    return Icons.signal_cellular_0_bar;
  }

  /// Returns a color representing the signal quality.
  static Color getSignalColor(int strength) {
    if (strength > 75) return Colors.green;
    if (strength > 40) return Colors.orange;
    return Colors.red;
  }

  /// Returns an icon for the SD card status.
  static IconData getSDCardIcon(String? status) {
    return Icons.sd_storage;
  }

  /// Returns a color representing the SD card mounting status.
  static Color getSDCardColor(String? status) {
    final s = status?.trim().toLowerCase();
    if (s == 'mounted') return Colors.green;
    if (s == 'unmounted' || s == 'not mounted') return Colors.red;
    return (s == null || s.isEmpty) ? Colors.transparent : Colors.grey;
  }
}
