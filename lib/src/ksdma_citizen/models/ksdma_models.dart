import 'package:flutter/material.dart';

enum InstrumentType {
  rainGauge,
  maxMinThermometer,
  riverGauge,
  hygrometer,
  awsAutomaticStation,
}

extension InstrumentTypeExtension on InstrumentType {
  String get displayName {
    switch (this) {
      case InstrumentType.rainGauge:
        return 'Standard Rain Gauge';
      case InstrumentType.maxMinThermometer:
        return 'Max-Min Thermometer';
      case InstrumentType.riverGauge:
        return 'River Level Gauge';
      case InstrumentType.hygrometer:
        return 'Hygrometer (Humidity)';
      case InstrumentType.awsAutomaticStation:
        return 'Automatic Weather Station (AWS)';
    }
  }

  String get prefix {
    switch (this) {
      case InstrumentType.rainGauge:
        return 'RG';
      case InstrumentType.maxMinThermometer:
        return 'TM';
      case InstrumentType.riverGauge:
        return 'RL';
      case InstrumentType.hygrometer:
        return 'HM';
      case InstrumentType.awsAutomaticStation:
        return 'AWS';
    }
  }

  List<String> get allowedParameters {
    switch (this) {
      case InstrumentType.rainGauge:
        return ['rainfall'];
      case InstrumentType.maxMinThermometer:
        return ['maxTemp', 'minTemp'];
      case InstrumentType.riverGauge:
        return ['riverLevel'];
      case InstrumentType.hygrometer:
        return ['humidity'];
      case InstrumentType.awsAutomaticStation:
        return ['rainfall', 'maxTemp', 'minTemp', 'humidity', 'riverLevel'];
    }
  }
}

enum StationCategory {
  manual,
  aws,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

enum UserRole {
  admin,
  officer,
  volunteer,
  citizen,
}

enum UserCategory {
  adminHq,
  districtOfficer,
  schoolStudent,
  farmer,
  fisherman,
  ngoVolunteer,
  generalPublic,
}

extension UserCategoryExtension on UserCategory {
  String get label {
    switch (this) {
      case UserCategory.adminHq:
        return 'Admin HQ (KSDMA Headquarters)';
      case UserCategory.districtOfficer:
        return 'District Disaster Officer';
      case UserCategory.schoolStudent:
        return 'School Student';
      case UserCategory.farmer:
        return 'Farmer';
      case UserCategory.fisherman:
        return 'Fisherman';
      case UserCategory.ngoVolunteer:
        return 'NGO Volunteer';
      case UserCategory.generalPublic:
        return 'General Public';
    }
  }
}

class KsdmaUser {
  final String userId;
  final String fullName;
  final String mobileNumber;
  final String email;
  final UserRole role;
  final UserCategory category;
  final String district;
  final String taluk;
  final String gramaPanchayat;
  final String village;
  int streakDays;
  int maxStreak;
  int totalObservations;
  int todayReadings;
  DateTime? lastObservationDate;
  String badgeTier; // BRONZE, SILVER, GOLD
  String? avatarUrl;

  KsdmaUser({
    required this.userId,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
    this.role = UserRole.volunteer,
    required this.category,
    this.district = '',
    this.taluk = '',
    this.gramaPanchayat = '',
    this.village = '',
    this.streakDays = 0,
    this.maxStreak = 0,
    this.totalObservations = 0,
    this.todayReadings = 0,
    this.lastObservationDate,
    this.badgeTier = 'BRONZE',
    this.avatarUrl,
  });
}

class KsdmaStation {
  final String stationId;
  final String ownerUserId;
  final String ownerName;
  final UserCategory ownerCategory;
  final StationCategory category;
  final InstrumentType instrumentType;
  final String deviceMake;
  final String measurementLocation;
  final String? devicePhotoUrl;
  final double latitude;
  final double longitude;
  final String district;
  final String taluk;
  final String gramaPanchayat;
  final String village;
  ApprovalStatus approvalStatus;
  final String rejectionReason; // Reason when Admin rejects a station registration
  final DateTime createdAt;

  KsdmaStation({
    required this.stationId,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerCategory,
    required this.category,
    required this.instrumentType,
    required this.deviceMake,
    required this.measurementLocation,
    this.devicePhotoUrl,
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.taluk,
    required this.gramaPanchayat,
    required this.village,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason = '',
    required this.createdAt,
  });
}

class KsdmaObservation {
  final String observationId;
  final String stationId;
  final String submittedByUserId;
  final DateTime observationDate;
  final TimeOfDay observationTime;
  final DateTime submissionTimestamp;
  final String source; // WEB_FORM, CSV_BULK_UPLOAD

  final double? rainfallMm;
  final double? maxTemperatureC;
  final double? minTemperatureC;
  final double? riverWaterLevelM;
  final double? humidityPercent; // Maximum Humidity
  final double? avgHumidityPercent; // Average Humidity

  final bool isEdited;

  // Moderation state
  bool isRemoved;
  String? removalReason; // OUTLIER, DUPLICATE, WRONG_UNIT, UNREALISTIC_SPIKE
  String? removedByAdminId;

  KsdmaObservation({
    required this.observationId,
    required this.stationId,
    required this.submittedByUserId,
    required this.observationDate,
    required this.observationTime,
    required this.submissionTimestamp,
    this.source = 'WEB_FORM',
    this.rainfallMm,
    this.maxTemperatureC,
    this.minTemperatureC,
    this.riverWaterLevelM,
    this.humidityPercent,
    this.avgHumidityPercent,
    this.isEdited = false,
    this.isRemoved = false,
    this.removalReason,
    this.removedByAdminId,
  });
}

/// Official Kerala Administrative Boundaries Validator & Dynamic Helper
class KeralaAdminData {
  static ({double lat, double lng}) getDistrictCenter(String district, [List<Map<String, dynamic>>? boundaries]) {
    if (boundaries != null && boundaries.isNotEmpty) {
      for (var b in boundaries) {
        final name = (b['district_name'] ?? b['name'] ?? '').toString().trim();
        if (name.toLowerCase() == district.toLowerCase().trim()) {
          final lat = double.tryParse(b['latitude']?.toString() ?? '');
          final lng = double.tryParse(b['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            return (lat: lat, lng: lng);
          }
        }
      }
    }
    return (lat: 10.5276, lng: 76.2144); // State center default
  }

  static String findNearestDistrict(double lat, double lng, [List<Map<String, dynamic>>? boundaries]) {
    if (boundaries == null || boundaries.isEmpty) return 'Thiruvananthapuram';
    String nearest = boundaries.first['district_name']?.toString() ?? 'Thiruvananthapuram';
    double minDistance = double.infinity;
    for (var b in boundaries) {
      final name = (b['district_name'] ?? b['name'] ?? '').toString().trim();
      final bLat = double.tryParse(b['latitude']?.toString() ?? '');
      final bLng = double.tryParse(b['longitude']?.toString() ?? '');
      if (name.isNotEmpty && bLat != null && bLng != null) {
        final dLat = bLat - lat;
        final dLng = bLng - lng;
        final distSq = dLat * dLat + dLng * dLng;
        if (distSq < minDistance) {
          minDistance = distSq;
          nearest = name;
        }
      }
    }
    return nearest;
  }

  static List<String> getDistricts([List<Map<String, dynamic>>? boundaries]) {
    if (boundaries != null && boundaries.isNotEmpty) {
      final set = boundaries
          .map((b) => (b['district_name'] ?? b['name'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty)
          .toSet()
          .toList();
      set.sort();
      return set;
    }
    return [
      'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod',
      'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
      'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'
    ];
  }

  static List<String> getTaluks(String district, [Map<String, Map<String, List<String>>>? hierarchyTree]) {
    if (hierarchyTree != null && hierarchyTree.containsKey(district)) {
      final list = hierarchyTree[district]!.keys.toList();
      list.sort();
      return list;
    }
    return [];
  }

  static List<String> getPanchayats(String district, String taluk, [Map<String, Map<String, List<String>>>? hierarchyTree]) {
    if (hierarchyTree != null && hierarchyTree.containsKey(district)) {
      final distMap = hierarchyTree[district]!;
      if (distMap.containsKey(taluk)) {
        final list = List<String>.from(distMap[taluk]!);
        list.sort();
        return list;
      }
    }
    return [];
  }

  static String? validateCoordinates(double lat, double lng) {
    if (lat < 8.0 || lat > 13.1) {
      return '⚠️ Latitude $lat°N is outside Kerala state boundaries (Valid range: 8.0°N to 13.1°N).';
    }
    if (lng < 74.5 || lng > 77.8) {
      return '⚠️ Longitude $lng°E is outside Kerala state boundaries (Valid range: 74.5°E to 77.8°E).';
    }
    return null;
  }
}
