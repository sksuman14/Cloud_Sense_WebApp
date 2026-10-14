import 'package:flutter/material.dart';

enum DerivedKeyCategory {
  all,
  thermal,
  atmosphere,
  agronomy,
  wind,
  precipitation,
}

extension DerivedKeyCategoryExt on DerivedKeyCategory {
  String get label {
    switch (this) {
      case DerivedKeyCategory.all:
        return 'All Derived';
      case DerivedKeyCategory.thermal:
        return 'Thermal & Comfort';
      case DerivedKeyCategory.atmosphere:
        return 'Atmospheric Physics';
      case DerivedKeyCategory.agronomy:
        return 'Agri & Crop VPD';
      case DerivedKeyCategory.wind:
        return 'Wind & Aerodynamics';
      case DerivedKeyCategory.precipitation:
        return 'Precipitation';
    }
  }

  IconData get icon {
    switch (this) {
      case DerivedKeyCategory.all:
        return Icons.auto_awesome;
      case DerivedKeyCategory.thermal:
        return Icons.thermostat;
      case DerivedKeyCategory.atmosphere:
        return Icons.cloud;
      case DerivedKeyCategory.agronomy:
        return Icons.eco;
      case DerivedKeyCategory.wind:
        return Icons.air;
      case DerivedKeyCategory.precipitation:
        return Icons.water_drop;
    }
  }
}

/// Represents an individual derived meteorological key with full metadata for Pluck Cards
class DerivedPluckKeyItem {
  final String key;
  final String title;
  final String shortLabel;
  final String value;
  final String unit;
  final double? rawNumeric;
  final DerivedKeyCategory category;
  final IconData icon;
  final Color accentColor;
  final String statusBadge;
  final Color statusColor;
  final String description;
  final String scientificMeaning;
  final String formula;
  final String optimalRange;
  final List<String> operationalAdvisories;

  const DerivedPluckKeyItem({
    required this.key,
    required this.title,
    required this.shortLabel,
    required this.value,
    required this.unit,
    this.rawNumeric,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.statusBadge,
    required this.statusColor,
    required this.description,
    required this.scientificMeaning,
    required this.formula,
    required this.optimalRange,
    required this.operationalAdvisories,
  });
}

/// Holds all 16 derived meteorological keys for a weather station
class DerivedWeatherKeys {
  final double? dewPoint;
  final double? feelsLike;
  final double? heatIndex;
  final double? humidex;
  final double? wetBulbTemperature;
  final double? deltaT;
  final double? absoluteHumidity;
  final double? actualVaporPressure;
  final double? saturatedVaporPressure;
  final double? vaporPressureDeficit;
  final double? airDensity;
  final double? cloudBaseAltitude;
  final int? windBeaufortScale;
  final String? windBeaufortDescription;
  final String? compassDirection;
  final String? rainIntensityCategory;

  const DerivedWeatherKeys({
    this.dewPoint,
    this.feelsLike,
    this.heatIndex,
    this.humidex,
    this.wetBulbTemperature,
    this.deltaT,
    this.absoluteHumidity,
    this.actualVaporPressure,
    this.saturatedVaporPressure,
    this.vaporPressureDeficit,
    this.airDensity,
    this.cloudBaseAltitude,
    this.windBeaufortScale,
    this.windBeaufortDescription,
    this.compassDirection,
    this.rainIntensityCategory,
  });

  /// Convert to a map of raw key-values
  Map<String, dynamic> toMap() {
    return {
      'DewPoint': dewPoint,
      'FeelsLike': feelsLike,
      'HeatIndex': heatIndex,
      'Humidex': humidex,
      'WetBulbTemperature': wetBulbTemperature,
      'DeltaT': deltaT,
      'AbsoluteHumidity': absoluteHumidity,
      'ActualVaporPressure': actualVaporPressure,
      'SaturatedVaporPressure': saturatedVaporPressure,
      'VaporPressureDeficit': vaporPressureDeficit,
      'AirDensity': airDensity,
      'CloudBaseAltitude': cloudBaseAltitude,
      'WindBeaufortScale': windBeaufortScale,
      'WindBeaufortDescription': windBeaufortDescription,
      'CompassDirection': compassDirection,
      'RainIntensityCategory': rainIntensityCategory,
    };
  }
}
