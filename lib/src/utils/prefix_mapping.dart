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
    'PS', 'PJ', 'AM', 'SH', 'WN', 'JW',
  ];

  static String getSensorType(String deviceId) {
    final upper = deviceId.toUpperCase().trim();
    if (upper.startsWith('SH') ||
        upper.startsWith('WS_SOBHA') ||
        upper.startsWith('WS_SHOBHA') ||
        upper.startsWith('SOBHA')) {
      return 'Sobha Sensor';
    }
    if (upper.startsWith('PJ') ||
        upper.startsWith('ANNAM/PUNJAB') ||
        upper.startsWith('WS_PUNJAB') ||
        upper.startsWith('ANNAM-PB') ||
        upper.startsWith('ANNAM_PB')) {
      return 'Punjab Sensor';
    }
    if (upper.startsWith('KR') ||
        upper.startsWith('ANNAM/KERALA') ||
        upper.startsWith('ANNAM-KL') ||
        upper.startsWith('ANNAM_KL')) {
      return 'Kerala Sensor';
    }
    if (upper.startsWith('WJ') ||
        upper.startsWith('ANNAM-0126') ||
        upper.startsWith('ANNAM0126') ||
        upper.startsWith('WF') ||
        upper.startsWith('ANNAM-0226') ||
        upper.startsWith('ANNAM0226') ||
        upper.startsWith('WA') ||
        upper.startsWith('ANNAM-0426') ||
        upper.startsWith('ANNAM0426')) {
      return 'ANNAM Sensors';
    }
    if (upper.startsWith('WM') ||
        upper.startsWith('TS-0526') ||
        upper.startsWith('TS0526') ||
        upper.startsWith('ANNAM-0526') ||
        upper.startsWith('ANNAM0526') ||
        upper.startsWith('TESTING')) {
      return 'Testing Devices';
    }
    if (upper.startsWith('PS') ||
        upper.startsWith('ANNAM-CPS') ||
        upper.startsWith('ANNAM/CPS') ||
        upper.startsWith('CPS')) {
      return 'CPS Sensor';
    }
    if (upper.startsWith('AM') ||
        (upper.startsWith('ANNAM-CP') && !upper.startsWith('ANNAM-CPS')) ||
        upper.startsWith('ANNAM_CP')) {
      return 'Annam CP Sensor';
    }
    if (upper.startsWith('AT') ||
        upper.startsWith('AWS-TESTING') ||
        upper.startsWith('AWS_TESTING')) {
      return 'AWS Testing Sensor';
    }
    if (upper.startsWith('AW') ||
        upper.startsWith('AWS-') ||
        upper.startsWith('AWS_')) {
      return 'AWS Sensor';
    }
    if (upper.startsWith('PC') ||
        upper.startsWith('ANNAM-PC') ||
        upper.startsWith('ANNAM/PC')) {
      return 'Polytechnical Sensor';
    }
    if (upper.startsWith('GP') ||
        upper.startsWith('ANNAM-GPC') ||
        upper.startsWith('ANNAM/GPC')) {
      return 'GPC Sensor';
    }
    if (upper.startsWith('WN') ||
        upper.startsWith('WINDS')) {
      return 'Winds Weather Sensor';
    }
    if (upper.startsWith('JW') ||
        upper.startsWith('JIO-WINDS') ||
        upper.startsWith('JIO_WINDS')) {
      return 'Partnership Sensors';
    }
    if (upper.startsWith('ANNAM-') || upper.startsWith('ANNAM_') || upper.startsWith('ANNAM')) {
      return 'ANNAM Sensors';
    }
    if (upper.startsWith('TS-') || upper.startsWith('TS_') || upper.startsWith('TESTING-') || upper.startsWith('TESTING_') || upper.startsWith('TESTING')) {
      return 'Testing Devices';
    }
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
    if (deviceId.startsWith('WT')) return 'Weather OTA Sensors';
    if (deviceId.startsWith('SI')) return 'Synthite Industries Private Limited Sensor';
    if (deviceId.startsWith('CF')) return 'Sekhon Biotech Pvt Ltd Farm Sensor';
    if (deviceId.startsWith('SV')) return 'Sardar Vallabhbhai Patel University of Agriculture and TechnologySensor';
    if (deviceId.startsWith('CB')) return 'COD/BOD Sensor';
    if (deviceId.startsWith('KD')) return 'Kargil Sensor';
    if (deviceId.startsWith('VD')) return 'Vanix Sensor';
    if (deviceId.startsWith('NA')) return 'National Atmospheric Research Labortary Sensor';
    if (deviceId.startsWith('KJ')) return 'KJ Somaiya College of Engineering';
    if (deviceId.startsWith('MY')) return 'Mysuru NIE';
    if (deviceId.startsWith('CP')) return 'IIT Ropar Campus Sensor';
    if (deviceId.startsWith('DM')) return 'Demo Sensor';
    return 'Rain Sensor';
  }

  static String getCategoryDisplayName(String prefix) {
    final upper = prefix.toUpperCase().trim();
    switch (upper) {
      case 'CL':
      case 'BD':
        return 'Chlorine Sensors';
      case 'WD':
        return 'Weather Sensors';
      case 'TS':
      case 'WT':
      case 'DM':
      case 'WN':
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
      case 'PS':
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
      case 'WF':
      case 'WA':
      case 'CF':
        return 'ANNAM Sensors';
      case 'SI':
        return 'Synthite Industries\nPrivate Limited Sensors';
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
      case 'KJ':
        return 'KJ Somaiya College of Engineering Sensors';
      case 'MY':
        return 'Mysuru NIE Sensors';
      case 'JW':
        return 'Partnership Sensors';
      case 'SH':
      case 'SOBHA':
        return 'Sobha Sensors';
      default:
        return 'Rain Sensors';
    }
  }

  static bool isValidDeviceId(String deviceId) {
    if (deviceId.isEmpty) return false;

    deviceId = deviceId.trim().toUpperCase();

    // Ensure the display templates end with a numeric value
    final bool isDisplayTemplate = deviceId.startsWith('ANNAM-') ||
        deviceId.startsWith('ANNAM_') ||
        deviceId.startsWith('ANNAM0126_') ||
        deviceId.startsWith('ANNAM0226_') ||
        deviceId.startsWith('ANNAM0426_') ||
        deviceId.startsWith('ANNAM0526_') ||
        deviceId.startsWith('ANNAM-0126-') ||
        deviceId.startsWith('ANNAM-0226-') ||
        deviceId.startsWith('ANNAM-0426-') ||
        deviceId.startsWith('ANNAM-0526-') ||
        deviceId.startsWith('ANNAM/GPC_') ||
        deviceId.startsWith('ANNAM-GPC-') ||
        deviceId.startsWith('ANNAM/KERALA/') ||
        deviceId.startsWith('ANNAM-KL-') ||
        deviceId.startsWith('ANNAM/PUNJAB/') ||
        deviceId.startsWith('ANNAM-PB-') ||
        deviceId.startsWith('WS_PUNJAB_') ||
        deviceId.startsWith('AWS_') ||
        deviceId.startsWith('AWS-') ||
        deviceId.startsWith('TS0526_') ||
        deviceId.startsWith('TS-0526-') ||
        deviceId.startsWith('TS_') ||
        deviceId.startsWith('TS-') ||
        deviceId.startsWith('TESTING_') ||
        deviceId.startsWith('TESTING-') ||
        deviceId.startsWith('DM_') ||
        deviceId.startsWith('DM-') ||
        deviceId.startsWith('WINDS_') ||
        deviceId.startsWith('WINDS-') ||
        deviceId.startsWith('JIO_WINDS_') ||
        deviceId.startsWith('JIO-WINDS-') ||
        deviceId.startsWith('JW_') ||
        deviceId.startsWith('JW-') ||
        deviceId.startsWith('WS_SHOBHA_') ||
        deviceId.startsWith('WS_SOBHA_') ||
        deviceId.startsWith('SOBHA-') ||
        deviceId.startsWith('AWS_TESTING_') ||
        deviceId.startsWith('AWS-TESTING-') ||
        deviceId.startsWith('ANNAM_CP') ||
        deviceId.startsWith('ANNAM-CP-') ||
        deviceId.startsWith('ANNAM/CPS_') ||
        deviceId.startsWith('ANNAM-CPS-') ||
        RegExp(r'^ANNAM/PC_\d+$').hasMatch(deviceId) ||
        RegExp(r'^ANNAM-PC-\d+$').hasMatch(deviceId);

    if (isDisplayTemplate && RegExp(r'\d+$').hasMatch(deviceId)) {
      return true;
    }

    // Must be at least 3 characters, start with a valid prefix, and end with a number (optionally with an underscore or hyphen)
    if (deviceId.length >= 3 && RegExp(r'^[A-Z]{2,}[_-]?\d+$').hasMatch(deviceId)) {
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
  /// ANNAM-themed name (e.g., ANNAM-0126-201).
  static String toAnnamDisplayName(String internalId) {
    if (internalId == null || internalId.isEmpty) return "";

    final upper = internalId.toUpperCase().trim();
    // Already formatted ANNAM-<digits> (e.g. ANNAM-201, ANNAM-007, ANNAM-013)
    if (RegExp(r'^ANNAM-\d+$').hasMatch(upper)) {
      return upper;
    }
    // Already formatted TESTING-<digits> (e.g. TESTING-001, TESTING-101)
    if (RegExp(r'^TESTING-\d+$').hasMatch(upper)) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      return 'TESTING-${cleanDigits.padLeft(3, '0')}';
    }

    // Extract numeric part (e.g., WJ201 -> 201)
    final digits = upper.replaceAll(_prefixRegex, '');
    final prefix = _prefixRegex.stringMatch(upper) ?? '';

    // Sobha sensors -> SOBHA-01
    if (upper.startsWith('SH') ||
        upper.startsWith('WS_SHOBHA') ||
        upper.startsWith('WS_SOBHA') ||
        upper.startsWith('SOBHA')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'SOBHA-${num.toString().padLeft(2, '0')}' : 'SOBHA-$cleanDigits';
    }

    // Punjab Stations -> ANNAM-01
    if (upper.startsWith('PJ') ||
        upper.startsWith('ANNAM/PUNJAB') ||
        upper.startsWith('WS_PUNJAB') ||
        upper.startsWith('ANNAM-PB') ||
        upper.startsWith('ANNAM_PB')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-${num.toString().padLeft(2, '0')}' : 'ANNAM-$cleanDigits';
    }

    // Kerala Stations -> ANNAM-01
    if (upper.startsWith('KR') ||
        upper.startsWith('ANNAM/KERALA') ||
        upper.startsWith('ANNAM-KL') ||
        upper.startsWith('ANNAM_KL')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-${num.toString().padLeft(2, '0')}' : 'ANNAM-$cleanDigits';
    }

    // 1. WJ sensors (Jan Weather) -> ANNAM-201
    if (upper.startsWith('WJ') ||
        upper.startsWith('ANNAM0126') ||
        upper.startsWith('ANNAM-0126')) {
      String suffix = upper;
      if (upper.startsWith('WJ')) {
        suffix = upper.substring(2);
      } else if (upper.startsWith('ANNAM-0126-') || upper.startsWith('ANNAM-0126_')) {
        suffix = upper.substring(11);
      } else if (upper.startsWith('ANNAM0126_') || upper.startsWith('ANNAM0126-')) {
        suffix = upper.substring(10);
      } else if (upper.startsWith('ANNAM0126')) {
        suffix = upper.substring(9);
      }
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final padDigits = cleanDigits.length == 1 ? cleanDigits.padLeft(2, '0') : cleanDigits;
      return 'ANNAM-$padDigits';
    }

    // 2. WF sensors (Feb Weather) -> ANNAM-101
    if (upper.startsWith('WF') ||
        upper.startsWith('ANNAM0226') ||
        upper.startsWith('ANNAM-0226')) {
      String suffix = upper;
      if (upper.startsWith('WF')) {
        suffix = upper.substring(2);
      } else if (upper.startsWith('ANNAM-0226-') || upper.startsWith('ANNAM-0226_')) {
        suffix = upper.substring(11);
      } else if (upper.startsWith('ANNAM0226_') || upper.startsWith('ANNAM0226-')) {
        suffix = upper.substring(10);
      } else if (upper.startsWith('ANNAM0226')) {
        suffix = upper.substring(9);
      }
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final padDigits = cleanDigits.length == 1 ? cleanDigits.padLeft(2, '0') : cleanDigits;
      return 'ANNAM-$padDigits';
    }

    // 3. WA sensors (April Weather) -> ANNAM-101 / ANNAM-007
    if (upper.startsWith('WA') ||
        upper.startsWith('ANNAM0426') ||
        upper.startsWith('ANNAM-0426')) {
      String suffix = upper;
      if (upper.startsWith('WA')) {
        suffix = upper.substring(2);
      } else if (upper.startsWith('ANNAM-0426-') || upper.startsWith('ANNAM-0426_')) {
        suffix = upper.substring(11);
      } else if (upper.startsWith('ANNAM0426_') || upper.startsWith('ANNAM0426-')) {
        suffix = upper.substring(10);
      } else if (upper.startsWith('ANNAM0426')) {
        suffix = upper.substring(9);
      }
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final padDigits = cleanDigits.length == 1 ? cleanDigits.padLeft(2, '0') : cleanDigits;
      return 'ANNAM-$padDigits';
    }

    // 4. WM sensors (May Weather) -> TESTING-101 / TESTING-001
    if (upper.startsWith('WM') ||
        upper.startsWith('TS0526') ||
        upper.startsWith('TS-0526') ||
        upper.startsWith('ANNAM0526') ||
        upper.startsWith('ANNAM-0526') ||
        upper.startsWith('TESTING0526') ||
        upper.startsWith('TESTING-0526')) {
      String suffix = upper;
      if (upper.startsWith('WM')) {
        suffix = upper.substring(2);
      } else if (upper.startsWith('TS-0526-') || upper.startsWith('TS-0526_') ||
                 upper.startsWith('ANNAM-0526-') || upper.startsWith('ANNAM-0526_') ||
                 upper.startsWith('TESTING-0526-') || upper.startsWith('TESTING-0526_')) {
        final lastSep = upper.lastIndexOf(RegExp(r'[-_]'));
        suffix = lastSep != -1 ? upper.substring(lastSep + 1) : upper;
      } else if (upper.startsWith('TS0526_') || upper.startsWith('TS0526-') ||
                 upper.startsWith('ANNAM0526_') || upper.startsWith('ANNAM0526-') ||
                 upper.startsWith('TESTING0526_') || upper.startsWith('TESTING0526-')) {
        final lastSep = upper.lastIndexOf(RegExp(r'[-_]'));
        suffix = lastSep != -1 ? upper.substring(lastSep + 1) : upper;
      } else {
        final match = RegExp(r'\d+$').firstMatch(upper);
        suffix = match != null ? match.group(0)! : '';
      }
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final padDigits = cleanDigits.padLeft(3, '0');
      return 'TESTING-$padDigits';
    }

    // WN sensors (Winds Weather) -> WINDS-01
    if (upper.startsWith('WN') || upper.startsWith('WINDS')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'WINDS-${num.toString().padLeft(2, '0')}' : 'WINDS-$cleanDigits';
    }

    // JW sensors (Jio Winds) -> JIO-WINDS-01
    if (upper.startsWith('JW') || upper.startsWith('JIO_WINDS') || upper.startsWith('JIO-WINDS')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'JIO-WINDS-${num.toString().padLeft(2, '0')}' : 'JIO-WINDS-$cleanDigits';
    }

    // PS sensors (CPS) -> ANNAM-CPS-01
    if (upper.startsWith('PS') ||
        upper.startsWith('ANNAM/CPS') ||
        upper.startsWith('ANNAM-CPS') ||
        upper.startsWith('CPS')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-CPS-${num.toString().padLeft(2, '0')}' : 'ANNAM-CPS-$cleanDigits';
    }

    // AM sensors (Annam CP01) -> ANNAM-CP-01
    if (upper.startsWith('AM') ||
        upper.startsWith('ANNAM_CP') ||
        (upper.startsWith('ANNAM-CP') && !upper.startsWith('ANNAM-CPS'))) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-CP-${num.toString().padLeft(2, '0')}' : 'ANNAM-CP-$cleanDigits';
    }

    // AT sensors (AWS Testing) -> AWS-TESTING-01
    if (upper.startsWith('AT') || upper.startsWith('AWS_TESTING') || upper.startsWith('AWS-TESTING')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'AWS-TESTING-${num.toString().padLeft(2, '0')}' : 'AWS-TESTING-$cleanDigits';
    }

    // AW sensors (AWS) -> ANNAM-01 / ANNAM-62
    if (upper.startsWith('AW') || upper.startsWith('AWS_') || upper.startsWith('AWS-')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isEmpty) return upper;
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-${num.toString().padLeft(2, '0')}' : 'ANNAM-$cleanDigits';
    }

    // PC sensors (Polytechnic) -> ANNAM-PC-01
    if (upper.startsWith('PC') || upper.startsWith('ANNAM/PC') || upper.startsWith('ANNAM-PC')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-PC-${num.toString().padLeft(2, '0')}' : 'ANNAM-PC-$cleanDigits';
    }

    // GP sensors (Polytechnic) -> ANNAM-GPC-01
    if (upper.startsWith('GP') || upper.startsWith('ANNAM/GPC') || upper.startsWith('ANNAM-GPC')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'ANNAM-GPC-${num.toString().padLeft(2, '0')}' : 'ANNAM-GPC-$cleanDigits';
    }

    // Testing group (CP other than CP001, plus WT, TS, TESTING) -> TESTING-001
    if (upper.startsWith('WT') ||
        upper.startsWith('TS') ||
        upper.startsWith('TESTING') ||
        (upper.startsWith('CP') && !upper.startsWith('CPS') && upper != 'CP001' && upper != 'CP01' && upper != 'CP1')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'TESTING-${num.toString().padLeft(3, '0')}' : 'TESTING-$cleanDigits';
    }

    // DM sensors under Testing with DM- prefix
    if (upper.startsWith('DM')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'DM-${num.toString().padLeft(2, '0')}' : 'DM-$cleanDigits';
    }

    // Temperature Sensors -> TH-01
    if (upper.startsWith('TH')) {
      final cleanDigits = upper.replaceAll(RegExp(r'[^0-9]'), '');
      final num = int.tryParse(cleanDigits);
      return num != null ? 'TH-${num.toString().padLeft(2, '0')}' : 'TH-$cleanDigits';
    }

    // Other ANNAM group (CF, CP001, SW007, SW013)
    if (isAnnamCoreSensor(upper)) {
      final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
      return cleanDigits.isNotEmpty ? 'ANNAM-$cleanDigits' : upper;
    }

    // Default (Partnership/Others) - return prefix-digits or original if no digits
    final cleanDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isNotEmpty && prefix.isNotEmpty) {
      final num = int.tryParse(cleanDigits);
      final padDigits = (num != null && cleanDigits.length < 2)
          ? num.toString().padLeft(2, '0')
          : cleanDigits;
      return '$prefix-$padDigits';
    }
    return upper;
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

  /// Resolves canonical internal sensor name directly from a raw device Map entry.
  static String resolveSensorNameFromDevice(Map<String, dynamic>? d) {
    if (d == null) return "";
    final devKey = d["deviceid#topic"]?.toString() ?? "";
    final deviceId = (d['DeviceId'] ??
            d['Device_ID'] ??
            d['ANNAM_ID'] ??
            (devKey.contains('#') ? devKey.split('#')[0] : devKey))
        .toString();
    final rawTopic = (d['Topic'] ??
            d['topic'] ??
            (devKey.contains('#') ? devKey.split('#')[1] : ""))
        .toString()
        .trim();
    return resolveSensorName(deviceId, rawTopic);
  }

  /// Resolves user-facing display name (e.g. 'ANNAM-07') directly from a raw device Map entry.
  static String getDisplaySensorName(Map<String, dynamic>? d) {
    if (d == null) return "";
    final sensorName = resolveSensorNameFromDevice(d);
    final displayName = toAnnamDisplayName(sensorName);
    if (displayName.isNotEmpty) return displayName;
    final devKey = d["deviceid#topic"]?.toString() ?? "";
    return (d['DeviceId'] ?? d['Device_ID'] ?? (devKey.contains('#') ? devKey.split('#')[0] : devKey)).toString();
  }

  /// Categorizes if a sensor belongs to the core ANNAM group (non-testing).
  static bool isAnnamCoreSensor(String internalId) {
    if (internalId == null) return false;
    final upper = internalId.toUpperCase().trim();

    // Specific exclusions (Legacy sensors)
    if (upper == 'WJ156' || upper == 'WJ157') return false;

    if (upper.startsWith('ANNAM-') || upper.startsWith('ANNAM_') || upper.startsWith('ANNAM/')) {
      return true;
    }

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
    return (upper.startsWith('CP') && !upper.startsWith('CPS') && upper != 'CP001') ||
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

    // 1.7 Handle Shobha / Sobha sensors (SH)
    if (sensorName.startsWith('SH') ||
        sensorName.startsWith('WS_SHOBHA') ||
        sensorName.startsWith('WS_SOBHA')) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '1';
      final id = int.tryParse(digits) ?? 1;
      return "WS_Shobha_$id#WS/Shobha/$id";
    }

    // 2. Standard numeric extraction for standard prefixes (handles CL-101, WD-101, etc.)
    final reg = RegExp(r'^([A-Z]{1,4})[-_]?(\d{1,5})$');
    final match = reg.firstMatch(sensorName);

    if (match == null) {
      final digits = RegExp(r'\d+$').firstMatch(sensorName)?.group(0) ?? '0';
      final id = int.tryParse(digits) ?? 0;
      final prefixMatch = RegExp(r'^([A-Z]+)').firstMatch(sensorName);
      if (prefixMatch != null) {
        final p = prefixMatch.group(1)!;
        if (p == 'CL' || p == 'BD') return "$id#WS/Chloritrone/$id";
        if (p == 'WD') return "$id#WS/Weather/$id";
        if (p == 'WQ') return "$id#WS/Water/$id";
        return "$id#WS/$p/$id";
      }
      return "$id#WS/Unknown/$id";
    }

    final String prefix = match.group(1)!;
    final int id = int.parse(match.group(2)!);

    switch (prefix) {
      case "CL":
      case "BD":
        return "$id#WS/Chloritrone/$id";
      case "WD":
        return "$id#WS/Weather/$id";
      case "WQ":
        return "$id#WS/Water/$id";
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
        return "$id#WS/$prefix/$id";
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
    if (topicPath.startsWith('WS/Shobha/') ||
        topicPath.toLowerCase().contains('shobha') ||
        topicPath.toLowerCase().contains('sobha')) {
      final cleanId = id.replaceAll(RegExp(r'[^0-9]'), '');
      return 'SH${cleanId.padLeft(3, '0')}';
    }
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
      return (category: 'ANNAM Sensors', prefix: 'WJ');
    }
    if (topic.contains('Annam_0426')) {
      return (category: 'ANNAM Sensors', prefix: 'WA');
    }
    if (topic.contains('Annam_0526')) {
      return (category: 'Testing Devices', prefix: 'WM');
    }
    final lowerTopic = topic.toLowerCase();
    if (lowerTopic.contains('shobha') || lowerTopic.contains('sobha')) {
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
      return (category: 'ANNAM Sensors', prefix: 'WF');
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
        return 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/annamcpdata';
      case 'PJ':
        return 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/punjabdata';
      case 'WT':
        return 'https://uqevvzptx7.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_API_Weather_Sensor';
      case 'KR':
        return 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/keraladata';
      case 'AW':
      case 'AT':
        return 'https://p8aytf5ev5.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_AWS';
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
