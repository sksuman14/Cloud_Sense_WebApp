import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_sense_webapp/src/models/derived_weather_keys.dart';
import 'package:cloud_sense_webapp/src/views/home/home_utils.dart';

class DerivedKeysService {
  /// Builds a DerivedWeatherKeys object from raw device payload.
  /// If `derived_fields` exists in the payload, its values are prioritized.
  /// Any missing values are derived using calibrated physics calculations.
  static DerivedWeatherKeys buildDerivedKeys(Map<String, dynamic>? device) {
    if (device == null) {
      return const DerivedWeatherKeys();
    }

    // 1. Check if backend already supplied derived_fields
    Map<String, dynamic>? backendDerived;
    if (device['derived_fields'] != null && device['derived_fields'] is Map) {
      backendDerived = Map<String, dynamic>.from(device['derived_fields']);
    }

    // Helper to safely parse double from dynamic
    double? parseD(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? parseI(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    // 2. Extract calibrated / corrected base sensors
    final tempRaw = HomeUtils.getCorrectedValue(device, [
      "CorrectedTemp",
      "correctedtemp",
      "CurrentTemperature",
      "currenttemperature",
      "NowTemperature",
      "now_temperature",
      "AverageTemperature",
      "average_temperature",
      "MaximumTemperature",
      "MinimumTemperature",
      "Maximum_Temperature",
      "Minimum_Temperature",
      "temperature"
    ]);

    final humRaw = HomeUtils.getCorrectedValue(device, [
      "CorrectedHumidity",
      "correctedhumidity",
      "CurrentHumidity",
      "currenthumidity",
      "NowRelativeHumidity",
      "now_relative_humidity",
      "now_humidity",
      "NowHumidity",
      "AverageHumidity",
      "average_humidity",
      "MaximumHumidity",
      "MinimumHumidity",
      "Maximum_Relative_Humidity",
      "Minimum_Relative_Humidity",
      "humidity"
    ]);

    final pressRaw = HomeUtils.getCorrectedValue(device, [
      "CurrentPressure",
      "AtmPressure",
      "atmpressure",
      "now_pressure",
      "NowPressure",
      "Average_Pressure",
      "average_pressure",
      "Maximum_Pressure",
      "Minimum_Pressure",
      "pressure"
    ]);

    final windSpeedRaw = HomeUtils.getCorrectedValue(device, [
      "WindSpeed",
      "windspeed",
      "NowWindSpeed",
      "now_wind_speed",
      "AverageWindSpeed",
      "average_wind_speed",
      "Minimum_wind_speed",
      "Maximum_wind_speed",
      "wind_speed"
    ]);

    final windDirRaw = HomeUtils.getCorrectedValue(device, [
      "WindDirection",
      "winddirection",
      "NowWindDirection",
      "now_wind_direction",
      "AverageWindDirection",
      "average_wind_direction",
      "max_wind_direction_gust"
    ]);

    final rainRaw = HomeUtils.getCorrectedValue(device, [
      "RainfallHourly",
      "rainfallhourly",
      "Rainfall",
      "rainfall",
      "RainfallDaily",
      "rainfalldaily",
      "RainfallCumulative",
      "Rainfall_Cumulative",
      "Rain_Rate",
      "rain_rate"
    ]);

    double? t = parseD(tempRaw);
    double? rh = parseD(humRaw);
    double? p = parseD(pressRaw);
    double? ws = parseD(windSpeedRaw) ?? 0.0;
    double? wd = parseD(windDirRaw);
    double? rain = parseD(rainRaw) ?? 0.0;

    // Validate and sanitize base values
    if (rh != null) {
      if (rh <= 0 && (t != null && t < -50)) {
        // Sensor failure / disconnected
      } else {
        rh = rh.clamp(0.1, 100.0);
      }
    }
    if (p != null && (p < 300 || p > 1200)) {
      // Pressure sensor glitch or negative, fallback to standard sea level pressure 1013.25
      p = 1013.25;
    }

    // 3. Extract or Compute Each Derived Metric

    // A. Saturated Vapor Pressure (e_s in kPa) via Buck/Tetens formula
    double? es = parseD(backendDerived?['SaturatedVaporPressure']);
    if (es == null && t != null) {
      es = 0.61078 * math.exp((17.27 * t) / (t + 237.3));
      es = _round(es, 3);
    }

    // B. Actual Vapor Pressure (e_a in kPa)
    double? ea = parseD(backendDerived?['ActualVaporPressure']);
    if (ea == null && es != null && rh != null) {
      ea = (rh / 100.0) * es;
      ea = _round(ea, 3);
    }

    // C. Dew Point (T_dp in °C) via Magnus-Tetens
    double? dewPoint = parseD(backendDerived?['DewPoint']);
    if (dewPoint == null && t != null && rh != null && rh > 0) {
      const a = 17.27;
      const b = 237.7;
      final alpha = ((a * t) / (b + t)) + math.log(rh / 100.0);
      dewPoint = (b * alpha) / (a - alpha);
      dewPoint = _round(dewPoint, 2);
    }

    // D. Wet Bulb Temperature (T_wb in °C) via Stull's 2011 Formula
    double? wetBulb = parseD(backendDerived?['WetBulbTemperature']);
    if (wetBulb == null && t != null && rh != null) {
      wetBulb = t * math.atan(0.151977 * math.sqrt(rh + 8.313659)) +
          math.atan(t + rh) -
          math.atan(rh - 1.676331) +
          0.00391838 * math.pow(rh, 1.5) * math.atan(0.023101 * rh) -
          4.686035;
      wetBulb = _round(wetBulb, 2);
    }

    // E. Delta T (Wet Bulb Depression) in °C: T - T_wb
    double? deltaT = parseD(backendDerived?['DeltaT']);
    if (deltaT == null && t != null && wetBulb != null) {
      deltaT = t - wetBulb;
      deltaT = _round(deltaT, 2);
    }

    // F. Heat Index (HI in °C) via NOAA / Rothfusz
    double? heatIndex = parseD(backendDerived?['HeatIndex']);
    if (heatIndex == null && t != null && rh != null) {
      if (t < 27.0) {
        heatIndex = _round(t, 2);
      } else {
        // Rothfusz polynomial in Fahrenheit
        final tf = (t * 9.0 / 5.0) + 32.0;
        double hiF = -42.379 +
            (2.04901523 * tf) +
            (10.14333127 * rh) -
            (0.22475541 * tf * rh) -
            (0.00683783 * tf * tf) -
            (0.05481717 * rh * rh) +
            (0.00122874 * tf * tf * rh) +
            (0.00085282 * tf * rh * rh) -
            (0.00000199 * tf * tf * rh * rh);
        final hiC = (hiF - 32.0) * 5.0 / 9.0;
        heatIndex = _round(hiC, 2);
      }
    }

    // G. Feels Like (T_fl in °C)
    double? feelsLike = parseD(backendDerived?['FeelsLike']);
    if (feelsLike == null) {
      if (heatIndex != null && t != null && t >= 27.0) {
        feelsLike = heatIndex;
      } else if (t != null && t <= 10.0 && ws > 1.3) {
        // Wind Chill
        final vKmh = ws * 3.6;
        feelsLike = 13.12 + (0.6215 * t) - (11.37 * math.pow(vKmh, 0.16)) + (0.3965 * t * math.pow(vKmh, 0.16));
        feelsLike = _round(feelsLike, 2);
      } else {
        feelsLike = t != null ? _round(t, 2) : null;
      }
    }

    // H. Humidex (in °C) via Canadian Meteorological formula
    double? humidex = parseD(backendDerived?['Humidex']);
    if (humidex == null && t != null && dewPoint != null) {
      final eMb = 6.11 * math.exp(5417.7530 * ((1.0 / 273.16) - (1.0 / (273.15 + dewPoint))));
      humidex = t + (5.0 / 9.0) * (eMb - 10.0);
      humidex = _round(humidex, 2);
    }

    // I. Vapor Pressure Deficit (VPD in kPa)
    double? vpd = parseD(backendDerived?['VaporPressureDeficit']);
    if (vpd == null && es != null && ea != null) {
      vpd = math.max(0.0, es - ea);
      vpd = _round(vpd, 2);
    }

    // J. Absolute Humidity (AH in g/m³)
    double? absHumidity = parseD(backendDerived?['AbsoluteHumidity']);
    if (absHumidity == null && ea != null && t != null) {
      absHumidity = (2167.0 * ea) / (t + 273.15);
      absHumidity = _round(absHumidity, 2);
    }

    // K. Air Density (ρ in kg/m³)
    double? airDensity = parseD(backendDerived?['AirDensity']);
    if (airDensity == null && t != null) {
      final currentP = (p != null && p > 300) ? p : 1013.25;
      final tk = t + 273.15;
      final pv = (ea ?? 1.5) * 1000.0; // Pa
      final pd = (currentP * 100.0) - pv; // Pa
      const rd = 287.058;
      const rv = 461.495;
      airDensity = (pd / (rd * tk)) + (pv / (rv * tk));
      airDensity = _round(airDensity, 3);
    }

    // L. Cloud Base Altitude (LCL in m)
    double? cloudBase = parseD(backendDerived?['CloudBaseAltitude']);
    if (cloudBase == null && t != null && dewPoint != null) {
      final diff = math.max(0.0, t - dewPoint);
      cloudBase = _round(diff * 125.0, 0);
    }

    // M. Wind Beaufort Scale (0 - 12)
    int? beaufortScale = parseI(backendDerived?['WindBeaufortScale']);
    if (beaufortScale == null) {
      beaufortScale = _calcBeaufortScale(ws);
    }

    // N. Wind Beaufort Description
    String? beaufortDesc = backendDerived?['WindBeaufortDescription']?.toString();
    if (beaufortDesc == null || beaufortDesc.isEmpty) {
      beaufortDesc = _calcBeaufortDesc(beaufortScale);
    }

    // O. Compass Direction
    String? compassDir = backendDerived?['CompassDirection']?.toString();
    if ((compassDir == null || compassDir.isEmpty) && wd != null) {
      compassDir = _calcCompassDirection(wd);
    }

    // P. Rain Intensity Category
    String? rainCat = backendDerived?['RainIntensityCategory']?.toString();
    if (rainCat == null || rainCat.isEmpty) {
      rainCat = _calcRainCategory(rain);
    }

    return DerivedWeatherKeys(
      dewPoint: dewPoint,
      feelsLike: feelsLike,
      heatIndex: heatIndex,
      humidex: humidex,
      wetBulbTemperature: wetBulb,
      deltaT: deltaT,
      absoluteHumidity: absHumidity,
      actualVaporPressure: ea,
      saturatedVaporPressure: es,
      vaporPressureDeficit: vpd,
      airDensity: airDensity,
      cloudBaseAltitude: cloudBase,
      windBeaufortScale: beaufortScale,
      windBeaufortDescription: beaufortDesc,
      compassDirection: compassDir,
      rainIntensityCategory: rainCat,
    );
  }

  /// Converts a DerivedWeatherKeys object into a list of 16 Pluck Card view items
  static List<DerivedPluckKeyItem> getPluckCardItems(DerivedWeatherKeys keys) {
    List<DerivedPluckKeyItem> items = [];

    // 1. Dew Point
    if (keys.dewPoint != null) {
      final dp = keys.dewPoint!;
      String badge;
      Color badgeColor;
      if (dp < 10) {
        badge = "Dry & Crisp";
        badgeColor = const Color(0xFF0284C7);
      } else if (dp <= 16) {
        badge = "Comfortable";
        badgeColor = const Color(0xFF10B981);
      } else if (dp <= 21) {
        badge = "Somewhat Humid";
        badgeColor = const Color(0xFFF59E0B);
      } else if (dp <= 24) {
        badge = "Oppressive Muggy";
        badgeColor = const Color(0xFFF97316);
      } else {
        badge = "Severe Discomfort";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'DewPoint',
        title: 'Dew Point',
        shortLabel: 'DEW POINT',
        value: '${dp.toStringAsFixed(1)}',
        unit: '°C',
        rawNumeric: dp,
        category: DerivedKeyCategory.thermal,
        icon: Icons.water_drop_rounded,
        accentColor: const Color(0xFF0284C7),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Condensation temperature of atmospheric moisture.',
        scientificMeaning:
            'Dew point reflects absolute water vapor concentration. Unlike relative humidity, it does not swing with diurnal temperature changes. High values impede human perspiration efficiency.',
        formula: 'T_dp = (237.7 × α) / (17.27 - α), where α = (17.27·T)/(237.7+T) + ln(RH/100)',
        optimalRange: '10.0 - 16.0 °C (Optimal Human Comfort)',
        operationalAdvisories: [
          'Dew point > 21°C causes noticeable stickiness and elevated cardiovascular strain during exercise.',
          'Dew point close to ambient air temperature indicates impending fog or dew formation.',
          'Critical for aircraft carburetor icing hazard risk assessment.',
        ],
      ));
    }

    // 2. Feels Like
    if (keys.feelsLike != null) {
      final fl = keys.feelsLike!;
      String badge;
      Color badgeColor;
      if (fl < 15) {
        badge = "Chilly";
        badgeColor = const Color(0xFF06B6D4);
      } else if (fl <= 26) {
        badge = "Pleasant";
        badgeColor = const Color(0xFF10B981);
      } else if (fl <= 34) {
        badge = "Warm Warning";
        badgeColor = const Color(0xFFF59E0B);
      } else if (fl <= 41) {
        badge = "Extreme Heat Caution";
        badgeColor = const Color(0xFFF97316);
      } else {
        badge = "Dangerous Heat Stress";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'FeelsLike',
        title: 'Feels Like',
        shortLabel: 'FEELS LIKE',
        value: '${fl.toStringAsFixed(1)}',
        unit: '°C',
        rawNumeric: fl,
        category: DerivedKeyCategory.thermal,
        icon: Icons.accessibility_new_rounded,
        accentColor: const Color(0xFFF59E0B),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Apparent perceived temperature for human skin.',
        scientificMeaning:
            'Integrates air temperature, relative humidity (suppressed sweating), and wind velocity (convective heat loss) to estimate true thermal load experienced by the body.',
        formula: 'Composite model of Steadman & Rothfusz heat index and Siple wind chill formulation',
        optimalRange: '18.0 - 25.0 °C',
        operationalAdvisories: [
          'Above 35°C: Hydrate frequently and limit continuous outdoor manual labor.',
          'Above 41°C: High susceptibility to heat cramps, exhaustion, and stroke.',
          'Essential metric for school athletic schedules and industrial worker safety protocols.',
        ],
      ));
    }

    // 3. Wet Bulb Temperature
    if (keys.wetBulbTemperature != null) {
      final wb = keys.wetBulbTemperature!;
      String badge;
      Color badgeColor;
      if (wb < 20) {
        badge = "Cool & Safe";
        badgeColor = const Color(0xFF10B981);
      } else if (wb <= 26) {
        badge = "Moderate Load";
        badgeColor = const Color(0xFF0284C7);
      } else if (wb <= 29) {
        badge = "Heavy Physiological Stress";
        badgeColor = const Color(0xFFF59E0B);
      } else if (wb <= 31) {
        badge = "Extreme Danger";
        badgeColor = const Color(0xFFF97316);
      } else {
        badge = "Lethal Threshold (Limit: 35°C)";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'WetBulbTemperature',
        title: 'Wet Bulb Temperature',
        shortLabel: 'WET BULB',
        value: '${wb.toStringAsFixed(1)}',
        unit: '°C',
        rawNumeric: wb,
        category: DerivedKeyCategory.thermal,
        icon: Icons.thermostat_auto_rounded,
        accentColor: const Color(0xFF10B981),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Lowest temp reached by evaporative water cooling.',
        scientificMeaning:
            'The absolute upper limit of human thermal survivability is approximately 35°C wet bulb. Beyond this, even young healthy adults in shade cannot shed metabolic heat by perspiration.',
        formula: 'Stull (2011) multi-harmonic inverse tangent empirical equation',
        optimalRange: '< 24.0 °C',
        operationalAdvisories: [
          'Wet Bulb > 28°C triggers wet-bulb globe temperature (WBGT) warnings for military and athletic drills.',
          'Critical indicator for cooling tower efficiency and evaporative swamp cooler operation.',
        ],
      ));
    }

    // 6. Delta T (Ag Spraying Delta)
    if (keys.deltaT != null) {
      final dt = keys.deltaT!;
      String badge;
      Color badgeColor;
      if (dt < 2.0) {
        badge = "Poor (Droplets Live Too Long / Washout)";
        badgeColor = const Color(0xFF0284C7);
      } else if (dt <= 8.0) {
        badge = "Ideal for Agricultural Spraying";
        badgeColor = const Color(0xFF10B981);
      } else if (dt <= 10.0) {
        badge = "Marginal (Fast Evaporation)";
        badgeColor = const Color(0xFFF59E0B);
      } else {
        badge = "Unsuitable (Rapid Evaporation & Drift)";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'DeltaT',
        title: 'Delta T (Spray Delta)',
        shortLabel: 'DELTA T',
        value: '${dt.toStringAsFixed(1)}',
        unit: '°C',
        rawNumeric: dt,
        category: DerivedKeyCategory.agronomy,
        icon: Icons.eco_rounded,
        accentColor: const Color(0xFF84CC16),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Difference between dry-bulb and wet-bulb temperature.',
        scientificMeaning:
            'The global agricultural benchmark for chemical spraying decision making. When Delta T is between 2°C and 8°C, spray droplets maintain optimal survival without drifting or evaporating prematurely.',
        formula: 'ΔT = Dry Bulb Air Temp - Wet Bulb Temp',
        optimalRange: '2.0 - 8.0 °C (Gold Standard for Ag Spraying)',
        operationalAdvisories: [
          'ΔT < 2°C: High droplet survival; droplets can remain suspended in inversion layers and drift off-target.',
          'ΔT 2 - 8°C: Golden window for pesticide, herbicide, and foliar fertilizer application.',
          'ΔT > 10°C: Droplets evaporate rapidly before hitting target canopy, leading to chemical wastage and vapor drift.',
        ],
      ));
    }

    // 7. Vapor Pressure Deficit (VPD)
    if (keys.vaporPressureDeficit != null) {
      final vpd = keys.vaporPressureDeficit!;
      String badge;
      Color badgeColor;
      if (vpd < 0.4) {
        badge = "Very Low (Fungal / Mold Risk)";
        badgeColor = const Color(0xFF3B82F6);
      } else if (vpd <= 0.8) {
        badge = "Low / Propagation Phase";
        badgeColor = const Color(0xFF06B6D4);
      } else if (vpd <= 1.2) {
        badge = "Optimal Vegetative Growth";
        badgeColor = const Color(0xFF10B981);
      } else if (vpd <= 1.6) {
        badge = "Optimal Flowering / Fruiting";
        badgeColor = const Color(0xFF84CC16);
      } else {
        badge = "High Deficit (Plant Water Stress)";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'VaporPressureDeficit',
        title: 'Vapor Pressure Deficit',
        shortLabel: 'VPD',
        value: '${vpd.toStringAsFixed(2)}',
        unit: 'kPa',
        rawNumeric: vpd,
        category: DerivedKeyCategory.agronomy,
        icon: Icons.spa_rounded,
        accentColor: const Color(0xFF14B8A6),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Atmospheric drying power driving plant transpiration.',
        scientificMeaning:
            'Measures difference between saturation vapor pressure and actual air vapor pressure. Dictates crop stomatal opening, nutrient uptake, and disease susceptibility in greenhouses & open fields.',
        formula: 'VPD = Saturated Vapor Pressure (e_s) - Actual Vapor Pressure (e_a)',
        optimalRange: '0.80 - 1.50 kPa (Ideal Crop Transpiration)',
        operationalAdvisories: [
          'Low VPD (< 0.4 kPa): Air is near saturation; plants cannot transpire, leading to calcium deficiency & mold.',
          'Optimal VPD (0.8 - 1.2 kPa): Maximum photosynthetic rate and calcium transport to growing tips.',
          'High VPD (> 1.6 kPa): Stomata close to prevent dehydration, halting photosynthesis and causing leaf tip burn.',
        ],
      ));
    }

    // 8. Absolute Humidity
    if (keys.absoluteHumidity != null) {
      final ah = keys.absoluteHumidity!;
      String badge;
      Color badgeColor;
      if (ah < 10) {
        badge = "Dry Air Mass";
        badgeColor = const Color(0xFF0EA5E9);
      } else if (ah <= 15) {
        badge = "Moderate Moisture";
        badgeColor = const Color(0xFF10B981);
      } else if (ah <= 20) {
        badge = "High Moisture Density";
        badgeColor = const Color(0xFFF59E0B);
      } else {
        badge = "Very Dense Moisture";
        badgeColor = const Color(0xFFEF4444);
      }

      items.add(DerivedPluckKeyItem(
        key: 'AbsoluteHumidity',
        title: 'Absolute Humidity',
        shortLabel: 'ABS HUMIDITY',
        value: '${ah.toStringAsFixed(1)}',
        unit: 'g/m³',
        rawNumeric: ah,
        category: DerivedKeyCategory.atmosphere,
        icon: Icons.grain_rounded,
        accentColor: const Color(0xFF06B6D4),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Mass of water vapor per cubic meter of air.',
        scientificMeaning:
            'Direct volumetric measure of atmospheric water content independent of ambient temperature. Vital parameter for industrial drying, cleanroom climate HVAC, and greenhouse dehumidification.',
        formula: 'AH = (2167 × e_a) / (T + 273.15), where e_a is in kPa',
        optimalRange: '8.0 - 15.0 g/m³',
        operationalAdvisories: [
          'High absolute humidity increases sensible heat retention in microclimates during nighttime.',
          'Indicates total available moisture supply for thunderstorm convection.',
        ],
      ));
    }

    // 7. Cloud Base Altitude
    if (keys.cloudBaseAltitude != null) {
      final cb = keys.cloudBaseAltitude!;
      String badge;
      Color badgeColor;
      if (cb < 600) {
        badge = "Low Ceiling / Fog / IFR";
        badgeColor = const Color(0xFFEF4444);
      } else if (cb <= 1500) {
        badge = "Moderate Cloud Base";
        badgeColor = const Color(0xFFF59E0B);
      } else if (cb <= 2500) {
        badge = "High Cumulus Base";
        badgeColor = const Color(0xFF10B981);
      } else {
        badge = "Clear / Elevated Ceiling";
        badgeColor = const Color(0xFF06B6D4);
      }

      items.add(DerivedPluckKeyItem(
        key: 'CloudBaseAltitude',
        title: 'Cloud Base Altitude',
        shortLabel: 'CLOUD BASE',
        value: '${cb.toInt()}',
        unit: 'm',
        rawNumeric: cb,
        category: DerivedKeyCategory.atmosphere,
        icon: Icons.cloud_queue_rounded,
        accentColor: const Color(0xFF6366F1),
        statusBadge: badge,
        statusColor: badgeColor,
        description: 'Estimated height of convective cumulus cloud base (LCL).',
        scientificMeaning:
            'Lifted Condensation Level (LCL) estimates the altitude where rising ground thermals cool to their dew point and form cumulus clouds. Fundamental metric for general aviation and glider flight planning.',
        formula: 'Espy’s Equation: Altitude (m) = 125 × (Temperature - DewPoint)',
        optimalRange: '> 1000 m (VFR Flight Conditions)',
        operationalAdvisories: [
          'Cloud base under 600m restricts visual flight rules (VFR) for ultralight aircraft and drones.',
          'Rapidly lowering cloud base altitude signals approaching weather fronts or squall lines.',
        ],
      ));
    }

    return items;
  }

  // --- Helper math & classification methods ---

  static double _round(double val, int decimals) {
    final mod = math.pow(10.0, decimals);
    return ((val * mod).roundToDouble()) / mod;
  }

  static int _calcBeaufortScale(double speedMps) {
    if (speedMps < 0.3) return 0;
    if (speedMps <= 1.5) return 1;
    if (speedMps <= 3.3) return 2;
    if (speedMps <= 5.4) return 3;
    if (speedMps <= 7.9) return 4;
    if (speedMps <= 10.7) return 5;
    if (speedMps <= 13.8) return 6;
    if (speedMps <= 17.1) return 7;
    if (speedMps <= 20.7) return 8;
    if (speedMps <= 24.4) return 9;
    if (speedMps <= 28.4) return 10;
    if (speedMps <= 32.6) return 11;
    return 12;
  }

  static String _calcBeaufortDesc(int scale) {
    switch (scale) {
      case 0:
        return 'Calm';
      case 1:
        return 'Light Air';
      case 2:
        return 'Light Breeze';
      case 3:
        return 'Gentle Breeze';
      case 4:
        return 'Moderate Breeze';
      case 5:
        return 'Fresh Breeze';
      case 6:
        return 'Strong Breeze';
      case 7:
        return 'Near Gale';
      case 8:
        return 'Gale';
      case 9:
        return 'Strong Gale';
      case 10:
        return 'Storm';
      case 11:
        return 'Violent Storm';
      case 12:
        return 'Hurricane';
      default:
        return 'Calm';
    }
  }

  static String _calcCompassDirection(double degrees) {
    const directions = [
      'N', 'NNE', 'NE', 'ENE',
      'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW',
      'W', 'WNW', 'NW', 'NNW'
    ];
    final normalized = (degrees % 360 + 360) % 360;
    final index = (((normalized + 11.25) % 360) / 22.5).floor();
    return directions[index % 16];
  }

  static String _calcRainCategory(double hourlyMm) {
    if (hourlyMm <= 0.0) return 'No Rain';
    if (hourlyMm < 2.5) return 'Light Rain';
    if (hourlyMm <= 7.6) return 'Moderate Rain';
    if (hourlyMm <= 50.0) return 'Heavy Rain';
    return 'Violent Rain';
  }
}
