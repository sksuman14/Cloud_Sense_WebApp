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

    if (!topic.contains('#')) {
      return topic;
    }

    final parts = topic.split('#');
    if (parts.length < 2) return parts[0];

    final id = parts[0];
    final topicPath = parts[1];

    final fullTopic = "$id#$topicPath/$id";
    final internalId = DevicePrefixUtils.getSensorNameFromTopic(fullTopic);
    if (internalId != null) {
      return DevicePrefixUtils.toAnnamDisplayName(internalId);
    }
    return parts[0];
  }

  static List<String> getAvailableDeviceIds(
      List<dynamic> devices, Map<String, dynamic>? selectedDevice) {
    List<String> deviceIds = [];

    for (var device in devices) {
      if (device is! Map) continue;
      String displayId = getDeviceIdFromTopic(device["deviceid#topic"]?.toString());
      if (displayId.isEmpty) {
        displayId = device["Device_ID"]?.toString() ??
                    device["ANNAM_ID"]?.toString() ??
                    device["DeviceId"]?.toString() ??
                    device["Topic"]?.toString() ?? "";
      }
      if (displayId.isNotEmpty && !deviceIds.contains(displayId)) {
        deviceIds.add(displayId);
      }
    }

    deviceIds.sort((a, b) {
      final aPrefix = RegExp(r'^([A-Za-z_]+)').firstMatch(a)?.group(1) ?? "";
      final bPrefix = RegExp(r'^([A-Za-z_]+)').firstMatch(b)?.group(1) ?? "";
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

  static String getFormattedLocation(Map<String, dynamic>? device) {
    if (device == null) return "";

    final rawDeviceId = (device['deviceId'] ?? device['Device_ID'] ?? device['ANNAM_ID'] ?? '').toString();
    final rawTopic = (device['deviceid#topic'] ?? device['Topic'] ?? '').toString();
    final internalId = DevicePrefixUtils.getSensorNameFromTopic(rawTopic) ?? rawDeviceId;

    if (_hardcodedLocationMap.containsKey(internalId)) {
      return _hardcodedLocationMap[internalId]!;
    }
    if (_hardcodedLocationMap.containsKey(rawDeviceId)) {
      return _hardcodedLocationMap[rawDeviceId]!;
    }

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

    if (rawTopic.isNotEmpty) {
      final topicSensor = DevicePrefixUtils.getSensorNameFromTopic(rawTopic);
      if (topicSensor != null) {
        if (_hardcodedLocationMap.containsKey(topicSensor)) {
          return _hardcodedLocationMap[topicSensor]!;
        }
        // Fallback for TS (Testing) sensors: Rupnagar, Punjab
        if (DevicePrefixUtils.isAnnamTestingSensor(topicSensor)) {
          return 'Rupnagar, Punjab';
        }
      }
    }

    final latStr = formatValue(device["Latitude"]);
    final lonStr = formatValue(device["Longitude"]);
    if ((latStr == "--" || latStr == "N/A" || latStr.isEmpty) &&
        (lonStr == "--" || lonStr == "N/A" || lonStr.isEmpty)) {
      return "";
    }
    return "Latitude: $latStr , Longitude: $lonStr";
  }

  static int getResponsiveCrossAxisCount(double screenWidth) {
    if (screenWidth < 700) return 1;
    if (screenWidth < 1000) return 2;
    return 3;
  }

  static Map<String, dynamic>? getDeviceByDisplayId(
      String displayId, List<dynamic> devicesList) {
    if (displayId.trim().isEmpty) return null;
    final searchLower = displayId.trim().toLowerCase();
    final topic = buildTopicFromDisplayId(displayId).toLowerCase();

    for (var item in devicesList) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      final devIdTopic = map["deviceid#topic"]?.toString().toLowerCase() ?? '';
      final deviceId = map["Device_ID"]?.toString().toLowerCase() ?? '';
      final annamId = map["ANNAM_ID"]?.toString().toLowerCase() ?? '';
      final devId = map["DeviceId"]?.toString().toLowerCase() ?? '';
      final topicStr = map["Topic"]?.toString().toLowerCase() ?? '';

      if (devIdTopic == searchLower || devIdTopic == topic ||
          deviceId == searchLower || deviceId == topic ||
          annamId == searchLower || annamId == topic ||
          devId == searchLower || devId == topic ||
          topicStr == searchLower || topicStr == topic ||
          topicStr.replaceAll('/', '_') == searchLower ||
          topicStr.replaceAll('/', '_') == topic) {
        return map;
      }

      final searchClean = searchLower.replaceAll('_', '').replaceAll('/', '').replaceAll('-', '');
      if (searchClean.isNotEmpty) {
        if (devIdTopic.replaceAll('_', '').replaceAll('/', '').replaceAll('-', '') == searchClean ||
            deviceId.replaceAll('_', '').replaceAll('/', '').replaceAll('-', '') == searchClean ||
            annamId.replaceAll('_', '').replaceAll('/', '').replaceAll('-', '') == searchClean ||
            topicStr.replaceAll('_', '').replaceAll('/', '').replaceAll('-', '') == searchClean) {
          return map;
        }
      }
    }

    debugPrint("Device $displayId not found");
    return null;
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
    final lower = displayId.toLowerCase();
    if (lower.startsWith('annam_cp')) {
      internalId =
          'AM${displayId.substring('annam_cp'.length).padLeft(2, '0')}';
    } else if (lower.startsWith('annam0126_')) {
      internalId =
          'WJ${displayId.substring('annam0126_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('annam0426_')) {
      internalId =
          'WA${displayId.substring('annam0426_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('annam/pc_')) {
      internalId =
          'PC${displayId.substring('annam/pc_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('annam/kerala/')) {
      internalId =
          'KR${displayId.substring('annam/kerala/'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('aws_')) {
      internalId = 'AW${displayId.substring('aws_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('annam/gpc_')) {
      internalId =
          'GP${displayId.substring('annam/gpc_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('ts_')) {
      internalId = 'CP${displayId.substring('ts_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('wt_')) {
      internalId = 'WT${displayId.substring('wt_'.length).padLeft(3, '0')}';
    } else if (lower.startsWith('annam')) {
      final idStr = displayId.substring('annam'.length);
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

  static dynamic getCorrectedValue(Map? selectedDevice, List<String> parameterKeys) {
    if (selectedDevice == null) return null;

    // 1. Check corrected_fields first (1st Priority)
    if (selectedDevice['corrected_fields'] != null && selectedDevice['corrected_fields'] is Map) {
      final correctedFields = selectedDevice['corrected_fields'] as Map;
      for (var key in parameterKeys) {
        final lowerKey = key.toLowerCase();
        if (correctedFields.containsKey(lowerKey)) {
          final correctedData = correctedFields[lowerKey];
          if (correctedData is Map && correctedData['corrected_value'] != null) {
            final val = correctedData['corrected_value'];
            if (val != null && val.toString().toLowerCase() != 'null') {
              return val;
            }
          }
        }
      }
    }

    // 2. Check exact keys
    for (var key in parameterKeys) {
      if (selectedDevice.containsKey(key)) {
        final val = selectedDevice[key];
        if (val != null && val.toString().toLowerCase() != 'null') {
          return val;
        }
      }
    }

    // 3. Check case-insensitive keys
    for (var key in parameterKeys) {
      final lowerKey = key.toLowerCase();
      for (var entry in selectedDevice.entries) {
        if (entry.key.toString().toLowerCase() == lowerKey) {
          final val = entry.value;
          if (val != null && val.toString().toLowerCase() != 'null') {
            return val;
          }
        }
      }
    }

    return null;
  }
}
