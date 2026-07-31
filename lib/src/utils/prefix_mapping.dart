import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Central utility for mapping internal device IDs to display-friendly ANNAM prefixes.
/// Consistent naming convention for CloudSense WebApp modernization.

class DevicePrefixUtils {
  static const List<String> validPrefixes = [
    'WD', 'CL', 'BD', 'SS', 'WQ', 'WS', 'DO', 'LU', 'TE', 'AC',
    'BF', 'CS', 'TH', 'NH', 'IT', 'FS', 'SM', 'SW', 'SI', 'CF',
    'SV', 'CB', 'WF', 'KD', 'VD', 'PC', 'KR', 'AW', 'GP', 'NA',
    'CP', 'KJ', 'MY', 'DM', 'WJ', 'WF', 'WT', 'WA', 'WM', 'TS',
    'PS', 'PJ',
  ];

  static String getSensorType(String deviceId) {
    if (deviceId.startsWith('WD')) return 'Weather Sensor';
    if (deviceId.startsWith('CL') || deviceId.startsWith('BD')) return 'Chlorine Sensor';
    if (deviceId.startsWith('SS')) return 'Soil Sensor';
    if (deviceId.startsWith('WQ')) return 'Water Quality Sensor';
    if (deviceId.startsWith('WS')) return 'Water Sensor';
    if (deviceId.startsWith('IT')) return 'IIT Bombay Sensor';
    if (deviceId.startsWith('DO')) return 'DO Sensor';
    if (deviceId.startsWith('LU')) return 'LU Sensor';
    if (deviceId.startsWith('TE')) return 'TE Sensor';
    if (deviceId.startsWith('AC')) return 'AC Sensor';
    if (deviceId.startsWith('BF')) return 'BF Sensor';
    if (deviceId.startsWith('CS')) return 'Cow Sensor';
    if (deviceId.startsWith('TH')) return 'Temperature Sensor';
    if (deviceId.startsWith('NH')) return 'Ammonia Sensor';
    if (deviceId.startsWith('FS')) return 'Forest Sensor (Bhopal)';
    if (deviceId.startsWith('SM')) return 'SSMET Sensor';
    if (deviceId.startsWith('SW')) return 'SSMET Weather Sensor';
    if (deviceId.startsWith('WJ')) return 'Jan Weather Sensors';
    if (deviceId.startsWith('WA')) return 'April Weather Sensors';
    if (deviceId.startsWith('WT')) return 'Weather OTA Sensors';
    if (deviceId.startsWith('WF')) return 'Feb Weather Sensors';
    if (deviceId.startsWith('WM')) return 'Testing Devices';
    if (deviceId.startsWith('SI')) return 'Synthite Industries Private Limited Sensor';
    if (deviceId.startsWith('CF')) return 'Sekhon Biotech Pvt Ltd Farm Sensor';
    if (deviceId.startsWith('SV')) return 'Sardar Vallabhbhai Patel University of Agriculture and TechnologySensor';
    if (deviceId.startsWith('CB')) return 'COD/BOD Sensor';
    if (deviceId.startsWith('WF')) return 'WF Sensor';
    if (deviceId.startsWith('KD')) return 'Kargil Sensor';
    if (deviceId.startsWith('VD')) return 'Vanix Sensor';
    if (deviceId.startsWith('PC')) return 'Polytechnical Sensor';
    if (deviceId.startsWith('KR')) return 'Kerala Sensor';
    if (deviceId.startsWith('PJ')) return 'Punjab Sensor';
    if (deviceId.startsWith('AW')) return 'AWS Sensor';
    if (deviceId.startsWith('GP')) return 'GPC Sensor';
    if (deviceId.startsWith('NA')) return 'National Atmospheric Research Labortary Sensor';
    if (deviceId.startsWith('KJ')) return 'KJ Somaiya College of Engineering';
    if (deviceId.startsWith('MY')) return 'Mysuru NIE';
    if (deviceId.startsWith('CP')) return 'IIT Ropar Campus Sensor';
    if (deviceId.startsWith('DM')) return 'Demo Sensor';
    if (deviceId.startsWith('WN')) return 'Winds Weather Sensor';
    if (deviceId.startsWith('JW')) return 'Partnership Sensors';
    if (deviceId.startsWith('SH')) return 'Shobha Sensor';
    if (deviceId.startsWith('AT')) return 'AWS Testing Sensor';
    if (deviceId.startsWith('AM')) return 'Annam CP Sensor';
    if (deviceId.startsWith('PS')) return 'CPS Sensor';
    return 'Rain Sensor';
  }

  static String getCategoryDisplayName(String prefix) {
    switch (prefix) {
      case 'CL':
      case 'BD':
        return 'Chlorine Sensors';
      case 'WD':
        return 'Weather Sensors';
      case 'WT':
        return 'Testing Devices';
      case 'SS':
        return 'SSMet Soil Sensors';
      case 'WQ':
        return 'Water Quality Sensors';
      case 'DO':
        return 'DO Sensors';
      case 'IT':
        return 'IIT Bombay\nSensors';
      case 'WS':
        return 'Water Sensors';
      case 'LU':
      case 'TE':
      case 'AC':
        return 'CPS Lab Sensors';
      case 'BF':
        return 'Buffalo Sensors';
      case 'CS':
        return 'Cow Sensors';
      case 'TH':
        return 'Temperature Sensors';
      case 'NH':
        return 'Ammonia Sensors';
      case 'FS':
        return 'SSMet Forest Sensors\n(Bhopal)';
      case 'SM':
        return 'SSMET Sensors';
      case 'SW':
        return 'SSMET Weather Sensors';
      case 'WJ':
        return 'ANNAM Sensors';
      case 'WF':
        return 'Feb Weather Sensors';
      case 'WA':
        return 'ANNAM Sensors';
      case 'SI':
        return 'Synthite Industries\nPrivate Limited Sensors';
      case 'CF':
        return 'ANNAM Sensors';
      case 'SV':
        return 'Sardar Vallabhbhai Patel University of Agriculture\nand Technology Sensors (Meerut)';
      case 'CB':
        return 'COD/BOD Sensors';
      case 'KD':
        return 'Kargil Sensors';
      case 'VD':
        return 'Vanix Sensors';
      case 'PC':
        return 'Polytechnical Sensors';
      case 'PJ':
        return 'Punjab Sensors';
      case 'KR':
        return 'Kerala Sensors';
      case 'AW':
        return 'AWS Sensors';
      case 'GP':
        return 'GPC Sensors';
      case 'NA':
        return 'National Atmospheric Research Labortary\nSensors';
      case 'CP':
        return 'IIT Ropar Campus\nSensors';
      case 'DM':
        return 'Testing Devices';
      case 'KJ':
        return 'KJ Somaiya College of Engineering Sensors';
      case 'MY':
        return 'Mysuru NIE Sensors';
      case 'JW':
        return 'Partnership Sensors';
      case 'SH':
        return 'Partnership Sensors';
      case 'WN':
        return 'Testing Devices';
      case 'PS':
        return 'CPS Sensors';
      default:
        return 'Rain Sensors';
    }
  }

  static bool isValidDeviceId(String deviceId) {
    if (deviceId.isEmpty) return false;

    deviceId = deviceId.trim().toUpperCase();

    // Ensure the display templates end with a numeric value
    final bool isDisplayTemplate = deviceId.startsWith('ANNAM0126_') ||
        deviceId.startsWith('ANNAM0226_') ||
        deviceId.startsWith('ANNAM0426_') ||
        deviceId.startsWith('ANNAM0526_') ||
        deviceId.startsWith('ANNAM/GPC_') ||
        deviceId.startsWith('ANNAM/KERALA/') ||
        deviceId.startsWith('ANNAM/PUNJAB/') ||
        deviceId.startsWith('WS_PUNJAB_') ||
        deviceId.startsWith('AWS_') ||
        deviceId.startsWith('TS0526_') ||
        deviceId.startsWith('TS_') ||
        deviceId.startsWith('DM_') ||
        deviceId.startsWith('Winds_') ||
        deviceId.startsWith('JIO_WINDS_') ||
        deviceId.startsWith('JW_') ||
        deviceId.startsWith('WS_SHOBHA_') ||
        deviceId.startsWith('AWS_TESTING_') ||
        deviceId.startsWith('ANNAM_CP') ||
        deviceId.startsWith('ANNAM/CPS_') ||
        RegExp(r'^ANNAM/PC_\d+$').hasMatch(deviceId);

    if (isDisplayTemplate && RegExp(r'\d+$').hasMatch(deviceId)) {
      return true;
    }

    // Must be at least 3 characters, start with a valid prefix, and end with a number (optionally with an underscore)
    if (deviceId.length >= 3 && RegExp(r'^[A-Z]{2,}_?\d+$').hasMatch(deviceId)) {
      String prefix = deviceId.substring(0, 2);
      if (validPrefixes.contains(prefix)) {
        return true;
      }
    }

    return false;
  }

  /// Strips administrative suffixes from district strings.
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

    // NEW: AM sensors (Annam CP01) -> ANNAM_CP01
    if (upper.startsWith('AM')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM_CP${num.toString().padLeft(2, '0')}' : 'ANNAM_CP$cleanDigits';
    }
    
    if (upper.startsWith('ANNAM_CP')) {
      return upper;
    }

    // NEW: PS sensors (CPS) -> ANNAM/CPS_
    if (upper.startsWith('PS')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM/CPS_$num' : 'ANNAM/CPS_$cleanDigits';
    }

    // NEW: PJ sensors (Punjab) -> ANNAM/Punjab/WS_
    if (upper.startsWith('PJ') || upper.startsWith('WS_PUNJAB')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? "ANNAM/Punjab/WS_$num" : "ANNAM/Punjab/WS_$cleanDigits";
    }

    // NEW: KR sensors (Kerala) -> ANNAM/Kerala/WS_
    if (upper.startsWith('KR')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM/Kerala/WS_$num' : 'ANNAM/Kerala/WS_$cleanDigits';
    }

    // NEW: AT sensors (AWS Testing) -> AWS_Testing_
    if (upper.startsWith('AT') || upper.startsWith('AWS_TESTING')) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'AWS_Testing_$num' : 'AWS_Testing_$cleanDigits';
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
        upper.startsWith('AM') ||
        upper.startsWith('PJ') ||
        upper.startsWith('KR') ||
        upper.startsWith('AW') ||
        upper.startsWith('PS') ||
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
        upper.startsWith('AT') ||
        upper.startsWith('AWS_TESTING') ||
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

    // 1.4 Handle PJWS_NNN (Punjab devices)
    if (sensorName.startsWith('PJWS_') || sensorName.startsWith('PJ')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "WS_Punjab_$id#WS/Punjab/$id";
    }

    // 1.5 Handle KRWS_NNN (Kerala devices)
    if (sensorName.startsWith('KRWS_')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "WS_$id#WS/Kerala/$id";
    }

    // 1.5.5 Handle AWS Testing devices (AT)
    if (sensorName.startsWith('AWS_TESTING_') || sensorName.startsWith('AT')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      return "$id#Testing/nRF52840";
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
      case "AM":
        return "ANNAM_CP${id.toString().padLeft(2, '0')}#WS/ANNAM_CP${id.toString().padLeft(2, '0')}";
      case "PJ":
        return "WS_Punjab_$id#WS/Punjab/$id";
      case "KR":
        return "WS_$id#WS/Kerala/$id";
      case "SH":
        return "WS_Shobha_$id#WS/Shobha/$id";
      case "AT":
        return "$id#Testing/nRF52840";
      case "PS":
        return "$id#WS/CPS/$id";
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
    if (topicPath.startsWith('WS/ANNAM_CP')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'AM${cleanId.padLeft(2, '0')}';
    }
    if (topicPath.startsWith('WS/Punjab/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'PJWS_$cleanId';
    }
    if (topicPath.startsWith('WS/Kerala/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'KRWS_$cleanId';
    }
    if (topicPath.startsWith('WS/AWS/') || topicPath.startsWith('AWS/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'AW${cleanId.padLeft(3, '0')}';
    }
    if (topicPath.startsWith('WS/CPS/')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'PS${cleanId.padLeft(3, '0')}';
    }
    if (topicPath.startsWith('Weather/sensor/')) return 'WT$paddedId';
    if (topicPath.startsWith('Testing/nRF52840') || topicPath.startsWith('AWS/Testing/')) return 'AT$paddedId';

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
    if (topic.contains('Testing/nRF52840') || topic.contains('AWS/Testing')) {
      return (category: 'Testing Devices', prefix: 'AT');
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
    if (topic.contains('WS/ANNAM_CP')) {
      return (category: 'ANNAM Sensors', prefix: 'AM');
    }
    if (topic.contains('WS/Punjab') || topic.contains('Punjab')) {
      return (category: 'ANNAM Sensors', prefix: 'PJ');
    }
    if (topic.contains('WS/Kerala')) {
      return (category: 'ANNAM Sensors', prefix: 'KR');
    }
    if (topic.contains('WS/AWS') || topic.contains('AWS/')) {
      return (category: 'ANNAM Sensors', prefix: 'AW');
    }
    if (topic.contains('WS/CPS') || topic.contains('WS/CPS/')) {
      return (category: 'CPS Sensors', prefix: 'PS');
    }
    if (topic.contains('SSMet/Soil')) {
      return (category: 'SSMet Soil sensor', prefix: 'SS');
    }
    if (topic.contains('WS/Aurassure')) {
      return (category: 'Aurassure Sensor', prefix: 'AS');
    }

    // Special non-standard topic handlers
    if (topic.contains('chloritrone')) {
      return (category: 'Chlorine Sensors', prefix: 'CL');
    }
    if (topic.contains('WS/Water') || topic.contains('water')) {
      return (category: 'Water Quality Sensors', prefix: 'WQ');
    }
    if (topic.contains('WS/Weather') || topic.contains('weather')) {
      return (category: 'Weather Sensors', prefix: 'weather');
    }
    if (topic.contains('WS/JioData') || topic.contains('JioData') || topic.contains('Awadh_Jio') || topic.contains('Awadh_jio')) {
      return (category: 'Partnership Sensors', prefix: 'Awadh_Jio');
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
      case 'PJ':
        return 'Punjab Sensors';
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
      case 'AM':
        return 'https://or0lazdry7.execute-api.us-east-1.amazonaws.com/default/Annam_CP01_Api_Function';
      case 'WT':
        return 'https://uqevvzptx7.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_API_Weather_Sensor';
      case 'PJ':
        return 'Punjab Sensors';
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
