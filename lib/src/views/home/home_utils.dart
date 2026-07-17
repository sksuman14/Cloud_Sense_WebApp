import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

class HomeUtils {
  static String formatValue(dynamic val) {
    if (val == null) return "--";
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") return "--";

    final num? number = num.tryParse(str);
    if (number != null) {
      double rounded = double.parse(number.toStringAsFixed(4));
      return rounded.toString();
    }
    return str;
  }

  static bool isNullOrEmpty(dynamic val) {
    if (val == null) return true;
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == "null") return true;
    return false;
  }

  static IconData getIconForKey(String key) {
    key = key.toLowerCase();
    if (key.contains("humidity")) return Icons.water_drop;
    if (key.contains("pressure")) return Icons.speed;
    if (key.contains("light")) return Icons.light_mode;
    if (key.contains("battery")) return Icons.battery_full;
    if (key.contains("temperature")) return Icons.thermostat;
    if (key.contains("device")) return Icons.memory;
    if (key.contains("voltage")) return Icons.bolt;
    if (key.contains("soil")) return Icons.grass;
    if (key.contains("rain")) return Icons.cloudy_snowing;
    if (key.contains("wind")) return Icons.wind_power;
    return Icons.circle;
  }

  static String getNameForKey(String paramName) {
    if (paramName == 'ElectricalConductivity') {
      return 'Elec Conductivity';
    }

    if (paramName.startsWith("Current")) {
      paramName = paramName.replaceFirst("Current", "");
    }

    String result = paramName.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    return result[0].toUpperCase() + result.substring(1);
  }

  static String getUnitForKey(String paramName) {
    if (paramName.contains('Rainfall')) return 'mm';
    if (paramName.contains('Voltage')) return 'V';
    if (paramName.contains('SignalStrength')) return 'dBm';
    if (paramName.contains('Latitude') || paramName.contains('Longitude'))
      return '°';
    if (paramName.contains('Temperature')) return '°C';
    if (paramName.contains('Humidity')) return '%';
    if (paramName.contains('Pressure')) return 'hPa';
    if (paramName.contains('LightIntensity')) return 'Lux';
    if (paramName.contains('WindSpeed')) return 'm/s';
    if (paramName.contains('WindDirection')) return '°';
    if (paramName.contains('Potassium')) return 'mg/Kg';
    if (paramName.contains('Nitrogen')) return 'mg/Kg';
    if (paramName.contains('Salinity')) return 'mg/L';
    if (paramName.contains('ElectricalConductivity')) return 'µS/cm';
    if (paramName.contains('Phosphorus')) return 'mg/Kg';
    if (paramName.contains('pH')) return 'pH';
    if (paramName.contains('Irradiance') || paramName.contains('Radiation'))
      return 'W/m²';
    if (paramName.contains('Chlorine') ||
        paramName.contains('COD') ||
        paramName.contains('BOD') ||
        paramName.contains('DO')) return 'mg/L';
    if (paramName.contains('TDS')) return 'ppm';
    if (paramName.contains('EC')) return 'mS/cm';
    if (paramName.contains('Ammonia')) return 'PPM';
    if (paramName.contains('Visibility')) return 'm';
    if (paramName.contains('ElectrodeSignal')) return 'mV';
    return '';
  }

  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    double dLat = (lat2 - lat1) * pi / 180;
    double dLon = (lon2 - lon1) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static String formatNumber(int number) {
    if (number < 1000) {
      return number.toString();
    }
    double numInK = number / 1000.0;
    return '${numInK.toStringAsFixed(numInK.truncateToDouble() == numInK ? 0 : 1)}K';
  }

  static double convertVoltageToPercentage(double voltage) {
    const double maxVoltage = 4.2;
    const double minVoltage = 2.8;

    if (voltage >= maxVoltage) return 100.0;
    if (voltage <= minVoltage) return 0.0;

    return ((voltage - minVoltage) / (maxVoltage - minVoltage)) * 100.0;
  }

  static bool shouldHideLocation(String? deviceId) {
    if (deviceId == null) return false;
    return deviceId == "1#Demo/Device/1" || deviceId.contains("DM001");
  }

  static bool isDemoDevice(String? topic) {
    if (topic == null) return false;
    return topic.contains("Demo/Device") || topic.contains("#Demo/Device/");
  }

  static String getDeviceIdFromTopic(String? topic) {
    if (topic == null || topic.isEmpty) return "";

    final parts = topic.split('#');
    if (parts.length < 2) return "";

    final id = parts[0];
    final topicPath = parts[1];

    final fullTopic = "$id#$topicPath/$id";
    final internalId = DevicePrefixUtils.getSensorNameFromTopic(fullTopic);
    if (internalId != null) {
      return DevicePrefixUtils.toAnnamDisplayName(internalId);
    }
    return "";
  }

  static List<String> getAvailableDeviceIds(
      List<dynamic> devices, Map<String, dynamic>? selectedDevice) {
    List<String> deviceIds = [];

    for (var device in devices) {
      final topic = device["deviceid#topic"]?.toString() ?? "";
      if (topic.isEmpty) continue;

      final displayId = getDeviceIdFromTopic(topic);
      if (displayId.isNotEmpty && !deviceIds.contains(displayId)) {
        deviceIds.add(displayId);
      }
    }

    deviceIds.sort((a, b) {
      final aPrefix = RegExp(r'^([A-Za-z]+)').firstMatch(a)?.group(1) ?? "";
      final bPrefix = RegExp(r'^([A-Za-z]+)').firstMatch(b)?.group(1) ?? "";
      final aNum =
          int.tryParse(RegExp(r'(\d+)$').firstMatch(a)?.group(1) ?? "0") ?? 0;
      final bNum =
          int.tryParse(RegExp(r'(\d+)$').firstMatch(b)?.group(1) ?? "0") ?? 0;

      if (aPrefix != bPrefix) return aPrefix.compareTo(bPrefix);
      return aNum.compareTo(bNum);
    });

    return deviceIds;
  }

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
    'SW003': 'Rupnagar, Punjab',
    'GPS': 'Rupnagar, Punjab',
    'gps': 'Rupnagar, Punjab',
    'WJ221': 'Zira tehsil, Firozpur district, Punjab',
    'NA013': 'Hyderabad, Musheerabad mandal, Telangana',
    'WJ267': 'Sardulgarh tehsil, Mansa district, Punjab',
    'WA016': 'Hiranagar, Kathua, Jammu and Kashmir',
  };

  static String getFormattedLocation(Map<String, dynamic>? device) {
    if (device == null) return "";

    final city = (device['City'] ??
            device['city'] ??
            device['Place'] ??
            device['place'] ??
            '')
        .toString()
        .trim();
    final district =
        (device['District'] ?? device['district'] ?? '').toString().trim();
    final state = (device['State'] ?? device['state'] ?? '').toString().trim();

    final parts = {
      if (city.isNotEmpty && city.toLowerCase() != 'null') city,
      if (district.isNotEmpty && district.toLowerCase() != 'null') district,
      if (state.isNotEmpty && state.toLowerCase() != 'null') state
    }.toList();

    if (parts.isNotEmpty) {
      return parts.join(', ');
    }

    final rawTopic =
        (device['deviceid#topic'] ?? device['Topic'] ?? '').toString();
    if (rawTopic.isNotEmpty) {
      final internalId = DevicePrefixUtils.getSensorNameFromTopic(rawTopic);
      if (internalId != null) {
        if (_hardcodedLocationMap.containsKey(internalId)) {
          return _hardcodedLocationMap[internalId]!;
        }
        // Fallback for TS (Testing) sensors: Rupnagar, Punjab
        if (DevicePrefixUtils.isAnnamTestingSensor(internalId)) {
          return 'Rupnagar, Punjab';
        }
      }
    }

    return "Latitude: ${formatValue(device["Latitude"])} , Longitude: ${formatValue(device["Longitude"])}";
  }

  static int getResponsiveCrossAxisCount(double screenWidth) {
    if (screenWidth < 700) return 1;
    if (screenWidth < 1000) return 2;
    return 3;
  }

  static Map<String, dynamic>? getDeviceByDisplayId(
      String displayId, List<dynamic> devicesList) {
    final topic = buildTopicFromDisplayId(displayId);

    try {
      return devicesList.firstWhere(
        (d) =>
            d["deviceid#topic"].toString().toLowerCase() == topic.toLowerCase(),
      );
    } catch (e) {
      debugPrint("Device $displayId not found with topic $topic");
      return null;
    }
  }

  static int getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) {
      return 1;
    } else if (screenWidth < 1300) {
      return 2;
    } else {
      return 3;
    }
  }

  static double getCardAspectRatio(double screenWidth) {
    if (screenWidth < 600) {
      return 0.6;
    } else if (screenWidth < 1300) {
      return 0.8;
    } else {
      return 1.3;
    }
  }

  static double getHorizontalPadding(double screenWidth) {
    if (screenWidth < 600) {
      return 10;
    } else if (screenWidth < 1300) {
      return 40;
    } else {
      return 70;
    }
  }

  static String buildTopicFromDisplayId(String displayId) {
    String internalId = displayId;
    if (displayId.startsWith('ANNAM_CP')) {
      internalId = 'AM${displayId.replaceFirst('ANNAM_CP', '').padLeft(2, '0')}';
    } else if (displayId.startsWith('ANNAM0126_')) {
      internalId =
          'WJ${displayId.replaceFirst('ANNAM0126_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('ANNAM0426_')) {
      internalId =
          'WA${displayId.replaceFirst('ANNAM0426_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('ANNAM/PC_')) {
      internalId =
          'PC${displayId.replaceFirst('ANNAM/PC_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('ANNAM/Kerala/')) {
      internalId =
          'KR${displayId.replaceFirst('ANNAM/Kerala/', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('AWS_')) {
      internalId =
          'AW${displayId.replaceFirst('AWS_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('ANNAM/GPC_')) {
      internalId =
          'GP${displayId.replaceFirst('ANNAM/GPC_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('TS_')) {
      internalId = 'CP${displayId.replaceFirst('TS_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('WT_')) {
      internalId = 'WT${displayId.replaceFirst('WT_', '').padLeft(3, '0')}';
    } else if (displayId.startsWith('ANNAM')) {
      final idStr = displayId.replaceFirst('ANNAM', '');
      final id = int.tryParse(idStr) ?? 0;
      if (id == 7 || id == 13)
        internalId = 'SW${idStr.padLeft(3, '0')}';
      else if (id == 1)
        internalId = 'CP001';
      else if (id == 2)
        internalId = 'CF002';
      else
        internalId = 'CF${idStr.padLeft(3, '0')}';
    }

    return DevicePrefixUtils.buildTopicFromSensorName(internalId);
  }
}
