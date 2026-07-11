import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:universal_html/html.dart' as html;

import 'package:cloud_sense_webapp/src/data/datasheets_download.dart';
import 'package:cloud_sense_webapp/src/widgets/appbar.dart';
import 'package:cloud_sense_webapp/src/widgets/drawer.dart';
import 'package:cloud_sense_webapp/src/widgets/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
//  Design Tokens — dark teal industrial theme
// ─────────────────────────────────────────────
class _T {
  final BuildContext context;
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  _T(this.context);

  // Backgrounds
  Color get bgDeep =>
      isDark ? const Color(0xFF0B141D) : const Color(0xFFF0F4F8);
  Color get bgBase =>
      isDark ? const Color(0xFF091520) : const Color(0xFFFFFFFF);
  Color get bgCard =>
      isDark ? const Color(0xFF0D1F2D) : const Color(0xFFFFFFFF);
  Color get bgCardHov =>
      isDark ? const Color(0xFF102536) : const Color(0xFFF1F3F4);
  Color get bgTag => isDark ? const Color(0x1F1FCB8A) : const Color(0x1F0D47A1);

  // Accent
  Color get accent =>
      isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);
  Color get accentMid =>
      isDark ? const Color(0xFF0FA86E) : const Color(0xFF1565C0);
  Color get accentBdr =>
      isDark ? const Color(0x401FCB8A) : const Color(0x400D47A1);

  // Text
  Color get textPrimary =>
      isDark ? const Color(0xFFE8F4F0) : const Color(0xFF1A1A1A);
  Color get textSecondary =>
      isDark ? const Color(0x73E8F4F0) : const Color(0x991A1A1A);
  Color get textMuted =>
      isDark ? const Color(0x38E8F4F0) : const Color(0x611A1A1A);

  // Border
  Color get border =>
      isDark ? const Color(0x12FFFFFF) : const Color(0x1F000000);
  Color get borderLight =>
      isDark ? const Color(0x1FFFFFFF) : const Color(0x12000000);

  // Radius (remains static)
  static const r4 = 4.0;
  static const r8 = 8.0;
  static const r12 = 12.0;
  static const r14 = 14.0;
  static const r20 = 20.0;
  static const r50 = 50.0;
}

// ─────────────────────────────────────────────
//  Sensor Data
// ─────────────────────────────────────────────
final List<Map<String, dynamic>> allSensors = [
  {
    "title": "Data",
    "highlightText": "Logger",
    "subtitle": "Reliable data logging & seamless connectivity",
    "eyebrow": "4G Dual SIM · IP65 · Solar ready",
    "bannerPoints": [
      "4G Dual SIM with multi-protocol support",
      "Advanced power management with solar charging",
      "Robust design with IP65 rating",
    ],
    "stats": [
      {"val": "30 days", "lbl": "Data backup"},
      {"val": "4G+GPS", "lbl": "Connectivity"},
      {"val": "IP65", "lbl": "Protection"},
    ],
    "features": [
      "4G Dual SIM connectivity",
      "25–30 days data backup",
      "Multi-protocol communication interfaces",
      "Robust IP65 enclosure for harsh weather",
      "Solar and battery powered option for remote sites",
    ],
    "applications": [
      "Remote weather monitoring stations",
      "Smart agriculture and irrigation management",
      "Industrial and environmental monitoring",
      "Smart cities and IoT projects",
      "Cold storage management",
    ],
    "specifications": [
      {"label": "Supply voltage", "value": "5–16 V DC"},
      {"label": "Interfaces", "value": "ADC, UART, I2C, SPI, RS232, RS485"},
      {"label": "Data protocols", "value": "HTTP, HTTPS, MQTT, FTP"},
      {"label": "Power source", "value": "USB Type-C or Li-Ion battery"},
      {"label": "Local storage", "value": "Micro SD card supported"},
      {"label": "Antennas", "value": "Built-in High-gain LTE & GPS"},
      {"label": "RTC", "value": "Battery-backed Real-time clock"},
      {"label": "Standby mode", "value": "Ultra-low power sleep enabled"},
    ],
    "techHighlights": [
      {
        "value": "4G/LTE",
        "label": "Dual SIM Connectivity",
        "description":
            "Equipped with dual-SIM fallback and manual routing for mission-critical reliability in remote connectivity environments."
      },
      {
        "value": "30 Days",
        "label": "On-board Data Resilience",
        "description":
            "High-capacity internal storage ensures your primary data remains safe and retrievable during infrastructure outages or server downtime."
      },
      {
        "value": "5-16V",
        "label": "Industrial Voltage Support",
        "description":
            "Optimized for industrial power supplies and solar charging systems with built-in voltage regulation and surge protection."
      },
    ],
    "imagePath": "assets/images/dataloggerrender.png",
    "email": "communications@annam.ai",
    "datasheetKey": "DataLogger",
    "detailedFeatures": [
      {
        "title": "Advanced Connectivity",
        "description":
            "4G Dual SIM support with multi-protocol interfaces including RS485, UART, and I2C for universal sensor integration.",
        "icon": Icons.lan_outlined
      },
      {
        "title": "Resilient Data Backup",
        "description":
            "Internal data logging with 25–30 days of storage. Reliable data persistence even during connectivity outages.",
        "icon": Icons.save_outlined
      },
      {
        "title": "Smart Power Mgmt",
        "description":
            "Optimized for solar charging with ultra-low power sleep modes. Ideal for remote stations and off-grid deployments.",
        "icon": Icons.battery_charging_full_outlined
      },
      {
        "title": "Industrial Integrity",
        "description":
            "Rugged IP65 enclosure designed for extreme environmental stress. Built-in LTE/GPS antennas and wide voltage input.",
        "icon": Icons.verified_user_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Remote weather monitoring",
        "description":
            "High-fidelity data collection for synoptic stations, agriculture networks, and environmental research.",
        "tag": "Meteorology"
      },
      {
        "title": "Smart Irrigation",
        "description":
            "Water management optimization with real-time soil moisture and weather data integration for precise farming.",
        "tag": "AgriTech"
      },
      {
        "title": "Industrial IoT",
        "description":
            "Monitoring factory environments, cold storage, and complex machinery health with multi-protocol sensor support.",
        "tag": "Industrial"
      },
      {
        "title": "Urban Flood Tracking",
        "description":
            "Early warning systems for urban areas, measuring rainfall and water levels to mitigate disaster risks.",
        "tag": "Safety"
      },
    ],
  },
  {
    "title": "Rain",
    "highlightText": "Gauge",
    "subtitle": "Tipping bucket rain gauge for precise rainfall measurement",
    "eyebrow": "Tipping bucket · Reed switch · ABS",
    "bannerPoints": [
      "Measures rain via tipping bucket mechanism",
      "Accurate and low-maintenance design",
      "Robust build for all weather conditions",
    ],
    "stats": [
      {"val": "0.2 mm", "lbl": "Resolution"},
      {"val": "200 cm²", "lbl": "Collection"},
      {"val": "ABS", "lbl": "Material"},
    ],
    "features": [
      "Balanced tipping bucket mechanism ensures high accuracy",
      "Minimal moving parts → long-term reliability with low maintenance",
      "Reed switch / magnetic sensor for precise tip detection",
      "Durable ABS body with weather resistance",
      "Easy integration with data loggers and weather stations",
    ],
    "applications": [
      "Meteorological stations for rainfall monitoring",
      "Agriculture & irrigation planning",
      "Environmental monitoring & climate research",
      "Precise/general purpose rain monitoring",
      "Urban drainage & stormwater management",
    ],
    "specifications": [
      {"label": "Material", "value": "UV-resistant high-impact ABS"},
      {"label": "Diameter options", "value": "159.5 mm / 200 mm"},
      {"label": "Collection area", "value": "200 cm² / 314 cm²"},
      {"label": "Measurement res.", "value": "0.2 mm / 0.5 mm"},
      {"label": "Sensor type", "value": "Magnetic reed switch"},
      {"label": "Digital output", "value": "Pulse output (Tips × Res)"},
      {"label": "Calibration", "value": "Individually factory verified"},
    ],
    "techHighlights": [
      {
        "value": "0.2 mm",
        "label": "Precision Resolution",
        "description":
            "Balanced tipping bucket mechanism designed for absolute measurement precision across diverse precipitation intensities."
      },
      {
        "value": "ABS+",
        "label": "Industrial Build Quality",
        "description":
            "Advanced UV-stabilized ABS construction engineered for 10+ years of maintenance-free operation in extreme UVB environments."
      },
      {
        "value": "Reed",
        "label": "Inductive Sensing",
        "description":
            "Fully-potted magnetic reed switch providing zero mechanical friction and infinite cycle life for long-term field stability."
      },
    ],
    "imagePath": "assets/images/gauge.png",
    "email": "communications@annam.ai",
    "datasheetKey": "RainGauge",
    "detailedFeatures": [
      {
        "title": "Precision Mechanism",
        "description":
            "Balanced tipping bucket design with high-sensitivity magnetic reed switch for millimeter-precise rainfall detection.",
        "icon": Icons.water_drop_outlined
      },
      {
        "title": "Low-Maintenance",
        "description":
            "Zero calibration drift and minimal moving parts ensure years of reliable operation with basic periodic cleaning.",
        "icon": Icons.build_circle_outlined
      },
      {
        "title": "All-Weather Build",
        "description":
            "High-grade ABS construction with UV protection. Designed to withstand reach and persistent humidity.",
        "icon": Icons.wb_sunny_outlined
      },
      {
        "title": "Universal Output",
        "description":
            "Simple digital pulse output compatible with all industrial data loggers. Standard 0.2mm resolution for accuracy.",
        "icon": Icons.settings_input_component_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Meteorological networks",
        "description":
            "Nationwide rainfall monitoring for weather forecasting, climate modeling, and hydrology research.",
        "tag": "Meteorology"
      },
      {
        "title": "Agricultural planning",
        "description":
            "Precise rainfall data for planting schedules, irrigation management, and crop health diagnostics.",
        "tag": "AgriTech"
      },
      {
        "title": "Stormwater management",
        "description":
            "Urban drainage monitoring and flood risk assessment for city planners and civil engineering.",
        "tag": "Infrastructure"
      },
      {
        "title": "Watershed research",
        "description":
            "Long-term data collection in forest and basin areas to study environmental changes and water cycles.",
        "tag": "Research"
      },
    ],
  },
  {
    "title": "Ultrasonic",
    "highlightText": "Anemometer",
    "subtitle": "Precise wind speed and wind direction monitoring",
    "eyebrow": "δ ToF wind sensing · RS485 / RS232",
    "bannerPoints": [
      "Accurate wind monitoring with no moving parts",
      "Real-time speed and direction measurement",
      "Robust and compact design for all weather conditions",
    ],
    "stats": [
      {"val": "65 m/s", "lbl": "Max speed"},
      {"val": "1°", "lbl": "Resolution"},
      {"val": "0.5 kg", "lbl": "Weight"},
    ],
    "features": [
      "High-quality measurement up to 65 m/s (234 km/h)",
      "High accuracy with fast response time",
      "0°–359° wind direction coverage with 1° resolution",
      "Low maintenance, ensuring low cost of ownership",
      "Robust design for all weather conditions",
    ],
    "applications": [
      "Weather monitoring stations",
      "Smart agriculture and precision farming",
      "Ports and harbours",
      "Runways and helipads",
      "Wind turbine performance monitoring",
    ],
    "specifications": [
      {"label": "Max wind speed", "value": "65 m/s (234 km/h)"},
      {"label": "Direction coverage", "value": "0°–359°, 1° resolution"},
      {"label": "Measurement method", "value": "Delta Time-of-Flight (δ ToF)"},
      {"label": "Input supply voltage", "value": "2 V – 16 V DC"},
      {
        "label": "Communication protocol",
        "value": "RS232 or RS485 (Modbus RTU)"
      },
      {
        "label": "Operating temperature",
        "value": "−40°C to +70°C (with heating)"
      },
      {"label": "Weight", "value": "0.5 kg"},
      {"label": "Power mode", "value": "Ultra low power sleep mode"},
      {"label": "Moving parts", "value": "None — fully solid state"},
      {"label": "Heating option", "value": "Available (standard config)"},
    ],
    "techHighlights": [
      {
        "value": "65 m/s",
        "label": "Max wind speed",
        "description":
            "Measures massive wind speeds up to 234 km/h, covering Category 5 hurricane conditions with sub-second accuracy."
      },
      {
        "value": "0 parts",
        "label": "Moving mechanical components",
        "description":
            "No cups, no bearings, no wear — resulting in significantly lower maintenance costs and longer service life compared to mechanical designs."
      },
      {
        "value": "110°C",
        "label": "Total operating temperature span",
        "description":
            "−40°C to +70°C with the heating option. Operates reliably from arctic deployments to desert solar farm installations."
      },
    ],
    "imagePath": "assets/images/ultrasonic.png",
    "email": "communications@annam.ai",
    "datasheetKey": "WindSensor",
    "detailedFeatures": [
      {
        "title": "High-precision measurement",
        "description":
            "Measures up to 65 m/s (234 km/h) with fast response time and sub-second update rates for real-time monitoring.",
        "icon": Icons.check_circle_outline
      },
      {
        "title": "Full 360° direction",
        "description":
            "0°–359° wind direction coverage with 1° angular resolution. No dead zones, no blind spots — complete awareness.",
        "icon": Icons.compass_calibration_outlined
      },
      {
        "title": "All-weather robustness",
        "description":
            "Heating option enables operation from -40°C to +70°C. No mechanical parts to freeze, jam, or corrode over time.",
        "icon": Icons.home_repair_service_outlined
      },
      {
        "title": "Ultra-low power",
        "description":
            "Sleep mode with 2V minimum input. Ideal for solar-powered remote stations and off-grid deployments with tight budgets.",
        "icon": Icons.auto_awesome_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Weather monitoring stations",
        "description":
            "High-accuracy data for meteorological networks, NWP model inputs, and research facilities.",
        "tag": "Meteorology"
      },
      {
        "title": "Smart agriculture",
        "description":
            "Precision farming with real-time wind data for spray management and crop microclimate monitoring.",
        "tag": "AgriTech"
      },
      {
        "title": "Ports and harbours",
        "description":
            "Continuous wind monitoring at berths and channels enables safe vessel navigation.",
        "tag": "Maritime"
      },
      {
        "title": "Runways and helipads",
        "description":
            "Aviation-grade wind reporting for safe takeoffs, landings, and ground operations compliance.",
        "tag": "Aviation"
      },
      {
        "title": "Wind turbine monitoring",
        "description":
            "Turbine performance optimization, yaw control, and SCADA integration with fast, accurate data.",
        "tag": "Energy"
      },
      {
        "title": "Construction & safety",
        "description":
            "Crane safety systems, high-rise construction monitoring, and real-time wind thresholds.",
        "tag": "Industrial"
      },
    ],
  },
  {
    "title": "Temperature Humidity Light & Pressure",
    "highlightText": "Sensor",
    "subtitle": "Compact environmental sensing unit for precise measurements",
    "eyebrow": "Multi-parameter · IP65 · I2C",
    "bannerPoints": [
      "High-precision measurements with cutting-edge sensor technology",
      "Robust design for long-term reliability in field deployments",
      "Flexible model to support diverse applications",
    ],
    "stats": [
      {"val": "±1°C", "lbl": "Temp accuracy"},
      {"val": "140 klx", "lbl": "Max light"},
      {"val": "IP65", "lbl": "Protection"},
    ],
    "features": [
      "Accurate wide environmental measurement range",
      "Maintenance-free for long-term field deployment",
      "Low power consumption, suitable for remote stations",
      "Robust IP65 compact design",
      "All-weather protection",
      "Compact & lightweight, easy to install with radiation shield",
    ],
    "applications": [
      "Agriculture and smart irrigation systems",
      "Environmental monitoring",
      "Healthcare & medical facilities",
      "Greenhouses and indoor farming",
      "Industrial process monitoring (HVAC, food processing)",
      "Safety and security",
    ],
    "specifications": [
      {"label": "Supply voltage", "value": "3.3 V DC"},
      {"label": "Temperature range", "value": "−40 to +85 °C"},
      {"label": "Humidity range", "value": "0–100% RH"},
      {"label": "Pressure range", "value": "300–1100 hPa"},
      {"label": "Light intensity", "value": "0–140 000 Lux"},
      {"label": "Digital protocol", "value": "I2C"},
      {"label": "Temp accuracy", "value": "±1 °C"},
      {"label": "LUX accuracy", "value": "±3%"},
    ],
    "techHighlights": [
      {
        "value": "140k lx",
        "label": "High Dynamic Light Range",
        "description":
            "Precise tracking of intense solar irradiance, essential for PV yield monitoring and agricultural micro-climate studies."
      },
      {
        "value": "IP65+",
        "label": "Environmental Resilience",
        "description":
            "Advanced internal sealing technology designed for permanent outdoor performance in saline, tropical, and industrial zones."
      },
      {
        "value": "I2C",
        "label": "Native Digital Sampling",
        "description":
            "High-fidelity digital bus output providing 16-bit precision for all four parameters with zero analog signal interference."
      },
    ],
    "imagePath": "assets/images/luxpressure.png",
    "email": "communications@annam.ai",
    "datasheetKey": "ARTH",
    "detailedFeatures": [
      {
        "title": "Multi-Sensing Array",
        "description":
            "Simultaneous monitoring of temperature, humidity, light intensity, and atmospheric pressure in one compact unit.",
        "icon": Icons.layers_outlined
      },
      {
        "title": "High Dynamic Range",
        "description":
            "Measure up to 140,000 Lux and 1100 hPa pressure with high-fidelity digital output and low noise floor.",
        "icon": Icons.wb_iridescent_outlined
      },
      {
        "title": "I2C Communication",
        "description":
            "Standard I2C interface for high-speed digital data transfer. Easy integration for embedded precision analytics.",
        "icon": Icons.settings_ethernet_outlined
      },
      {
        "title": "Shield Compatibility",
        "description":
            "Optimized airflow geometry for integration with physical radiation shields, ensuring true environmental readings.",
        "icon": Icons.wb_twilight_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Greenhouse Automation",
        "description":
            "Precision climate control for high-yield indoor farming through real-time Temp, Humidity, and Light sensing.",
        "tag": "AgriTech"
      },
      {
        "title": "Cleanroom Monitoring",
        "description":
            "Maintaining strict environmental standards in pharmaceutical and medical manufacturing facilities.",
        "tag": "Healthcare"
      },
      {
        "title": "Public Spaces",
        "description":
            "Monitoring air quality and comfort levels in malls, airports, and smart city hubs for visitor experience.",
        "tag": "Smart City"
      },
      {
        "title": "Laboratory Safety",
        "description":
            "Tracking subtle pressure and humidity changes to ensure experiment integrity and biosafety compliance.",
        "tag": "Scientific"
      },
    ],
  },
  {
    "title": "Temperature and Humidity",
    "highlightText": "Probe",
    "subtitle": "Accurate measurements for temperature and humidity",
    "eyebrow": "Precision sensing · RS485 / ADC",
    "bannerPoints": [
      "Real-time temperature & humidity sensing for critical applications",
      "Provides both analog (0–1000 mV) and digital (RS485) output",
      "Reliable industrial-grade monitoring with CRC-validated communications",
    ],
    "stats": [
      {"val": "±0.1°C", "lbl": "Temp accuracy"},
      {"val": "±3% RH", "lbl": "Humidity acc."},
      {"val": "RS485", "lbl": "Protocol"},
    ],
    "features": [
      "High-precision temperature and humidity sensing probe",
      "Compact low-power design suitable for IoT and embedded applications",
      "Robust RS485/MODBUS RTU communications for industrial use",
      "CRC validations provide reliable and error-free data transfer",
      "Output provides both analog and digital value",
    ],
    "applications": [
      "Healthcare and medical facilities",
      "Agriculture and farming",
      "Cold storage and warehouse",
      "Food and beverage industry",
      "Transportation and logistics",
    ],
    "specifications": [
      {"label": "Supply voltage", "value": "5–12 V DC"},
      {"label": "Temperature range", "value": "−40 to +85 °C"},
      {"label": "Humidity range", "value": "0–100% RH"},
      {"label": "Digital output", "value": "RS485 (Modbus RTU)"},
      {"label": "Analog output", "value": "0–1 V (ADC)"},
      {"label": "Temp accuracy", "value": "±0.1 °C"},
      {"label": "Humidity accuracy", "value": "±3.0% RH"},
    ],
    "techHighlights": [
      {
        "value": "±0.1°C",
        "label": "Clinical Grade Precision",
        "description":
            "Individually calibrated sensor elements that meet the highest international standards for healthcare and vaccine storage safety."
      },
      {
        "value": "RS485",
        "label": "Industrial Modbus Support",
        "description":
            "Native Modbus RTU implementation with hardware CRC error checking for robust long-distance industrial wiring and PLC integration."
      },
      {
        "value": "Slim",
        "label": "Versatile Probe Profile",
        "description":
            "Slender, reinforced probe design ideal for reaching deep into clinical deep-freezes, silos, and environmental chambers."
      },
    ],
    "imagePath": "assets/images/thprobe.png",
    "email": "communications@annam.ai",
    "datasheetKey": "TempHumidityProbe",
    "detailedFeatures": [
      {
        "title": "Medical Grade Accuracy",
        "description":
            "±0.1°C temperature and ±3% RH precision. Ideal for mission-critical monitoring in labs and hospitals.",
        "icon": Icons.biotech_outlined
      },
      {
        "title": "Industrial Modbus",
        "description":
            "Native RS485 Modbus RTU support with CRC validation. Seamless integration into industrial PLC and SCADA systems.",
        "icon": Icons.compare_arrows_outlined
      },
      {
        "title": "Analogue & Digital",
        "description":
            "Dual output capability providing both 0–1 V analog and RS485 digital signals for universal compatibility.",
        "icon": Icons.settings_outlined
      },
      {
        "title": "Compact & Durable",
        "description":
            "Reinforced probe housing designed for long-term immersion in critical cold storage and storage environments.",
        "icon": Icons.medical_services_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Vaccine Cold Chain",
        "description":
            "Ultra-precise temperature tracking in pharmaceutical refrigerators and deep-freeze storage units.",
        "tag": "Healthcare"
      },
      {
        "title": "Grain Storage",
        "description":
            "Monitoring humidity in silos and warehouses to prevent mold growth and ensure food security.",
        "tag": "Agriculture"
      },
      {
        "title": "Server Rooms",
        "description":
            "Preventing equipment failure by monitoring ambient humidity and temperature in mission-critical data centers.",
        "tag": "IT Infrastructure"
      },
      {
        "title": "Clinical Trials",
        "description":
            "Reliable data logging for sensitive laboratory trials requiring ±0.1°C temperature precision.",
        "tag": "Research"
      },
    ],
  },
  {
    "title": "BLE",
    "highlightText": "Gateway",
    "subtitle": "BLE gateway for industrial IoT applications",
    "eyebrow": "BLE 5.4 · 4G / WiFi / LAN · 100+ nodes",
    "bannerPoints": [
      "Multi-industry IoT gateway solution",
      "Real-time data aggregation at scale",
      "Scalable gateway supporting 100+ nodes",
    ],
    "stats": [
      {"val": "100+", "lbl": "Node support"},
      {"val": "1 km", "lbl": "BLE LoS range"},
      {"val": "BLE 5.4", "lbl": "Version"},
    ],
    "features": [
      "Real-time monitoring with low power consumption",
      "FOTA (Firmware Over the Air) updates",
      "Supports 100+ nodes with BLE range up to 1 km LoS",
      "IP65 & compact design",
      "Connectivity: 4G, WiFi, LAN",
    ],
    "applications": [
      "Smart agriculture & precision farming",
      "Logistics and asset tracking",
      "Industrial equipment health monitoring",
      "Healthcare wearable data collection",
      "Home automation and energy management",
    ],
    "specifications": [
      {"label": "Input voltage", "value": "5–30 V DC"},
      {"label": "Processor", "value": "Dual-Core ARM Cortex-M33"},
      {"label": "BLE Controller", "value": "nRF5340 (Nordic)"},
      {"label": "BLE Protocol", "value": "Bluetooth 5.4"},
      {"label": "On-board memory", "value": "512 KB RAM + 1 MB Flash"},
      {"label": "System interfaces", "value": "SPI, I2C, I2S, UART"},
      {"label": "Connectivity", "value": "4G / WiFi / LAN"},
      {"label": "Power options", "value": "Internal Battery + Solar Panel"},
    ],
    "techHighlights": [
      {
        "value": "100+",
        "label": "Seamless Node Mesh",
        "description":
            "Advanced nRF5340 dual-core architecture allows concurrent processing of telemetry from over 100 wireless sensor nodes."
      },
      {
        "value": "1 km",
        "label": "High-Sensitivity Range",
        "description":
            "Bluetooth 5.4 PA/LNA front-end module achieving massive line-of-sight coverage for expansive farm and facility deployments."
      },
      {
        "value": "Triple",
        "label": "Redundant Data Path",
        "description":
            "Automatic failover between LTE, WiFi, and LAN ensuring your facility monitoring never goes offline during infrastructure failure."
      },
    ],
    "imagePath": "assets/images/blegateway.png",
    "email": "communications@annam.ai",
    "datasheetKey": "Gateway",
    "detailedFeatures": [
      {
        "title": "Massive Scalability",
        "description":
            "Support for 100+ concurrent BLE nodes with seamless real-time data aggregation and processing.",
        "icon": Icons.hub_outlined
      },
      {
        "title": "Long-Range BLE",
        "description":
            "Bluetooth 5.4 implementation reaching up to 1km Line-of-Sight (LoS) for expansive facility coverage.",
        "icon": Icons.settings_input_antenna_outlined
      },
      {
        "title": "Triple Connectivity",
        "description":
            "Uninterrupted data flow via 4G/LTE, WiFi, and LAN fallback mechanisms for critical reliability.",
        "icon": Icons.router_outlined
      },
      {
        "title": "Remote Mgmt (FOTA)",
        "description":
            "Full remote management with Firmware Over the Air (FOTA) updates and real-time node health monitoring.",
        "icon": Icons.system_update_alt_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Smart Asset Tracking",
        "description":
            "Real-time location and status monitoring for 100+ BLE tags in large warehouses and industrial sites.",
        "tag": "Logistics"
      },
      {
        "title": "Agricultural Sensor Mesh",
        "description":
            "Aggregating data from dispersed soil and weather nodes across large plantations for unified control.",
        "tag": "AgriTech"
      },
      {
        "title": "Industrial Health",
        "description":
            "Wireless monitoring of vibration and temperature sensors on factory floors for predictive maintenance.",
        "tag": "Industrial"
      },
      {
        "title": "Smart Hospitals",
        "description":
            "Tracking medical equipment and monitoring patient environments using low-power BLE 5.4 connectivity.",
        "tag": "Healthcare"
      },
    ],
  },
  {
    "title": "Soil",
    "highlightText": "Spectra",
    "subtitle": "Smart soil sensing for modern precision agriculture",
    "eyebrow": "7-in-1 · IP68 · RS485 Modbus RTU",
    "bannerPoints": [
      "Supports RS485 Modbus RTU for reliable long-distance communication",
      "Captures soil health: Moisture, Temp, EC, pH, N, P, K",
      "Ideal for agriculture & environmental monitoring",
    ],
    "stats": [
      {"val": "7-in-1", "lbl": "Parameters"},
      {"val": "<1 sec", "lbl": "Response"},
      {"val": "IP68", "lbl": "Protection"},
    ],
    "features": [
      "7-in-1 multi-parameter soil measurement (Moisture, Temp, EC, pH, N, P, K)",
      "Long-distance RS485 Modbus RTU communication",
      "Rugged IP68 protection for field and buried installation",
      "High accuracy with fast response time (<1 sec)",
      "Factory calibrated with traceable soil standards",
      "Low power — ideal for IoT and remote deployments",
      "Strong corrosion and shock resistance for long-term durability",
    ],
    "applications": [
      "Smart agriculture & irrigation automation",
      "Greenhouse and indoor farming control",
      "Soil mapping for precision farming",
      "Environmental and climate research",
      "Soil quality assessment for crop planning",
      "Sustainable agriculture — govt./NGO programs",
      "Farms of all scales — small to large agritech",
    ],
    "specifications": [
      {"label": "Operating supply", "value": "5 V DC (USB/External)"},
      {"label": "Output signal", "value": "RS485 Modbus RTU"},
      {"label": "Reaction time", "value": "<1 second"},
      {"label": "Moisture span", "value": "0–100% RH (±3%/±5%)"},
      {"label": "Temp span", "value": "−45 °C to +115 °C (±0.5 °C)"},
      {"label": "pH measurement", "value": "0–14 (±0.3)"},
      {"label": "EC measurement", "value": "0–10 000 µS/cm"},
      {"label": "NPK precision", "value": "±2% F.S. (0-1999 mg/kg)"},
    ],
    "techHighlights": [
      {
        "value": "7-in-1",
        "label": "Complete Soil Diagnostics",
        "description":
            "Simultaneous monitoring of Moisture, Temp, EC, pH, and NPK in one IP68-sealed high-precision multi-probe."
      },
      {
        "value": "IP68",
        "label": "Permanent Burial Design",
        "description":
            "Vacuum-sealed epoxy encapsulation designed for 5+ years of maintenance-free performance in harsh saline and acidic soils."
      },
      {
        "value": "<1 sec",
        "label": "Instant Analysis",
        "description":
            "High-frequency dielectric sensing delivering lab-grade soil parameters in under one second for automated fertigation control."
      },
    ],
    "imagePath": "assets/images/soil.png",
    "email": "communications@annam.ai",
    "datasheetKey": "Soil",
    "detailedFeatures": [
      {
        "title": "7-in-1 Soil Intelligence",
        "description":
            "Comprehensive tracking of Moisture, Temp, EC, pH, Nitrogen, Phosphorus, and Potassium in one probe.",
        "icon": Icons.analytics_outlined
      },
      {
        "title": "Extreme Durability",
        "description":
            "IP68 rated for permanent burial. High resistance to saline-alkali corrosion and vibration shock.",
        "icon": Icons.terrain_outlined
      },
      {
        "title": "Fast-Response Sensing",
        "description":
            "High-frequency sensing technology providing precise parameters in under one second for real-time irrigation control.",
        "icon": Icons.bolt_outlined
      },
      {
        "title": "Easy Integration",
        "description":
            "Standard RS485 Modbus RTU output for seamless connectivity with PLC, SCADA, and IoT gateways.",
        "icon": Icons.electrical_services_outlined
      },
    ],
    "detailedApplications": [
      {
        "title": "Precision Fertigation",
        "description":
            "Optimizing NPK application through real-time soil chemistry analysis, reducing costs and runoff.",
        "tag": "AgriTech"
      },
      {
        "title": "Erosion Control",
        "description":
            "Monitoring soil moisture and structural stability in hilly regions to prevent landslides and soil loss.",
        "tag": "Environment"
      },
      {
        "title": "Golf Course Mgmt",
        "description":
            "Scientific turf management through precise monitoring of EC and moisture to keep greens in peak condition.",
        "tag": "Sports"
      },
      {
        "title": "Land Reclamation",
        "description":
            "Tracking pH and nutrient recovery in former mining sites to ensure successful re-vegetation.",
        "tag": "Restoration"
      },
    ],
  },
];

// ─────────────────────────────────────────────
//  Product Page
// ─────────────────────────────────────────────
class ProductPage extends StatelessWidget {
  final int sensorIndex;
  const ProductPage({super.key, required this.sensorIndex});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final sensor = allSensors[sensorIndex];
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 1024;
    final isTablet = w > 700 && w <= 1024;

    return Scaffold(
      backgroundColor: t.bgDeep,
      appBar: AppBarWidget(),
      endDrawer: !isWide ? const EndDrawerWidget() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero ──────────────────────────────
              _HeroSection(sensor: sensor, isWide: isWide, isTablet: isTablet)
                  .animate()
                  .fadeIn(duration: 700.ms)
                  .slideY(
                      begin: -0.06, duration: 700.ms, curve: Curves.easeOut),

              // ── Key Features (New Design) ──────────
              _DetailedFeatureSection(
                      sensor: sensor, isWide: isWide, isTablet: isTablet)
                  .animate()
                  .fadeIn(duration: 700.ms, delay: 250.ms)
                  .slideY(begin: 0.05, duration: 700.ms, delay: 250.ms),

              // ── Technical Specifications (New Design) ────
              _DetailedSpecSection(
                      sensor: sensor, isWide: isWide, isTablet: isTablet)
                  .animate()
                  .fadeIn(duration: 700.ms, delay: 300.ms)
                  .slideY(begin: 0.08, duration: 700.ms, delay: 300.ms),

              // ── Applications (New Design) ──────────
              _DetailedApplicationSection(
                      sensor: sensor, isWide: isWide, isTablet: isTablet)
                  .animate()
                  .fadeIn(duration: 700.ms, delay: 400.ms)
                  .slideY(begin: 0.08, duration: 700.ms, delay: 400.ms),

              const SizedBox(height: 24),
              _ReadyToDeploySection(sensor: sensor)
                  .animate()
                  .fadeIn(duration: 600.ms, delay: 450.ms),
              const Footer().animate().fadeIn(duration: 600.ms, delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Hero Section
// ─────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final Map sensor;
  final bool isWide;
  final bool isTablet;
  const _HeroSection(
      {required this.sensor, required this.isWide, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final content = _HeroContent(sensor: sensor, isWide: isWide);
    final image = _DeviceVisual(
        imagePath: sensor["imagePath"] as String,
        modelPath: sensor["modelPath"] as String?,
        stats: sensor["stats"] as List);

    return Container(
      decoration: BoxDecoration(
        color: t.bgBase,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Stack(
        children: [
          // Grid background
          Positioned.fill(child: _GridBackground()),
          // Decorative Glows
          Positioned(
            top: -150,
            right: isWide ? 100 : -20,
            child: _GlowCircle(size: 600, color: t.accent.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -100,
            left: -50,
            child: _GlowCircle(size: 400, color: t.accent.withOpacity(0.05)),
          ),
          // Content
          Padding(
            padding: EdgeInsets.fromLTRB(
              isWide ? 80 : (isTablet ? 40 : 24),
              isWide ? 72 : 56,
              isWide ? 80 : (isTablet ? 40 : 24),
              isWide ? 64 : 48,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 55, child: content),
                          const SizedBox(width: 48),
                          Expanded(flex: 45, child: image),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          content,
                          const SizedBox(height: 40),
                          Center(child: image),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroContent extends StatelessWidget {
  final Map sensor;
  final bool isWide;
  const _HeroContent({required this.sensor, required this.isWide});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final h1Size = isWide ? 58.0 : 38.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eyebrow pill
        _EyebrowTag(text: sensor["eyebrow"] as String),
        const SizedBox(height: 22),

        // Headline
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [t.textPrimary, t.accent, t.accentMid],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${sensor["title"]}\n',
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: h1Size,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                ),
                TextSpan(
                  text: sensor["highlightText"],
                  style: TextStyle(
                    fontFamily: 'Syne',
                    fontSize: h1Size,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Underline bar
        Container(
          margin: const EdgeInsets.only(top: 14, bottom: 18),
          height: 2,
          width: h1Size * 3.5,
          decoration: BoxDecoration(
            color: t.accent,
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        // Subtitle
        Text(
          sensor["subtitle"] as String,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: t.textSecondary,
            height: 1.7,
          ),
        ),
        const SizedBox(height: 22),

        // Banner bullet points
        ...((sensor["bannerPoints"] as List)
            .map((p) => _BannerBullet(text: p as String))),
        const SizedBox(height: 32),

        // CTA buttons
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            _PrimaryButton(
              label: 'Enquire now',
              icon: Icons.arrow_forward_rounded,
              onTap: () => _sendEmail(context, sensor["email"] as String),
            ),
            _GhostButton(
              label: 'Download datasheet',
              icon: Icons.download_rounded,
              onTap: () => DownloadManager.downloadFile(
                context: context,
                sensorKey: sensor["datasheetKey"] as String,
                fileType: "datasheet",
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceVisual extends StatelessWidget {
  final String imagePath;
  final String? modelPath;
  final List stats;
  const _DeviceVisual(
      {required this.imagePath, this.modelPath, required this.stats});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(_T.r20),
          child: Container(
            height: 420,
            decoration: BoxDecoration(
              color: t.bgCard,
              borderRadius: BorderRadius.circular(_T.r20),
              border: Border.all(color: t.accentBdr.withOpacity(0.2)),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: const _ScannerEffect()),
                Padding(
                  padding: const EdgeInsets.all(48.0),
                  child: Image.asset(
                    imagePath,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ).animate(onPlay: (c) => c.repeat()).shimmer(
                        duration: 3.seconds,
                        color: t.accent.withOpacity(0.2),
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                  child: _StatPill(
                val: stats[i]["val"] as String,
                lbl: stats[i]["lbl"] as String,
              )),
            ],
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Detailed Features Section (New Design)
// ─────────────────────────────────────────────
class _DetailedFeatureSection extends StatelessWidget {
  final Map sensor;
  final bool isWide;
  final bool isTablet;

  const _DetailedFeatureSection({
    required this.sensor,
    required this.isWide,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final features = sensor["detailedFeatures"] as List?;
    if (features == null || features.isEmpty) return const SizedBox.shrink();

    final hPad = isWide ? 80.0 : (isTablet ? 40.0 : 24.0);
    final crossAxisCount = isWide ? 4 : (isTablet ? 2 : 1);

    return Container(
      color: t.bgDeep,
      padding: EdgeInsets.fromLTRB(hPad, 80, hPad, 80),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Why it\'s different'),
              const SizedBox(height: 12),
              Text(
                'Built for the real world',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: isWide ? 42 : 32,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  sensor["subtitle"] as String,
                  style: TextStyle(
                    fontSize: 16,
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Feature Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  if (isWide) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: features
                            .map((f) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: _FeatureCardV2(feature: f as Map),
                                  ),
                                ))
                            .toList(),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 260,
                    ),
                    itemCount: features.length,
                    itemBuilder: (context, index) => _FeatureCardV2(
                      feature: features[index] as Map,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCardV2 extends StatelessWidget {
  final Map feature;
  const _FeatureCardV2({required this.feature});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(_T.r14),
        border: Border.all(color: t.accentBdr.withOpacity(0.4), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.bgTag,
              borderRadius: BorderRadius.circular(_T.r8),
            ),
            child: Icon(
              feature["icon"] as IconData,
              color: t.accent,
              size: 20,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            feature["title"] as String,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 12),

          // Description
          Text(
            feature["description"] as String,
            style: TextStyle(
              fontSize: 14,
              color: t.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Detailed Applications Section (New Design)
// ─────────────────────────────────────────────
class _DetailedApplicationSection extends StatelessWidget {
  final Map sensor;
  final bool isWide;
  final bool isTablet;

  const _DetailedApplicationSection({
    required this.sensor,
    required this.isWide,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final apps = sensor["detailedApplications"] as List?;
    if (apps == null || apps.isEmpty) return const SizedBox.shrink();

    final hPad = isWide ? 80.0 : (isTablet ? 40.0 : 24.0);
    final crossAxisCount = isWide ? 3 : (isTablet ? 2 : 1);

    // Custom intro text or fallback
    String getIntro() {
      final name = sensor["title"] as String;
      if (name.contains("Ultrasonic")) {
        return "Any environment that demands reliable wind data — from the field to the sky.";
      }
      if (name.contains("Logger")) {
        return "Critical infrastructure requiring precise, real-time telemetry and long-term data resilience.";
      }
      return "Optimized for high-precision environmental monitoring in diverse field and industrial conditions.";
    }

    return Container(
      color: t.bgDeep, // Alternate from bgBase above
      padding: EdgeInsets.fromLTRB(hPad, 100, hPad, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Where it\'s used'),
              const SizedBox(height: 12),
              Text(
                'Applications',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  getIntro(),
                  style: TextStyle(
                    fontSize: 16,
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 64),

              // Application Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  mainAxisExtent: 260,
                ),
                itemCount: apps.length,
                itemBuilder: (context, index) => _ApplicationCardV2(
                  index: index + 1,
                  app: apps[index] as Map,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ApplicationCardV2 extends StatefulWidget {
  final int index;
  final Map app;
  const _ApplicationCardV2({required this.index, required this.app});

  @override
  State<_ApplicationCardV2> createState() => _ApplicationCardV2State();
}

class _ApplicationCardV2State extends State<_ApplicationCardV2> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: _hov ? t.bgCardHov : t.bgCard,
          borderRadius: BorderRadius.circular(_T.r20),
          border: Border.all(
            color: _hov ? t.accent : t.accentBdr.withOpacity(0.4),
            width: 1,
          ),
          boxShadow: _hov
              ? [
                  BoxShadow(
                    color: t.accent.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index Number
            Text(
              widget.index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: t.accent,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              widget.app["title"] as String,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: t.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 12),

            // Description
            Expanded(
              child: Text(
                widget.app["description"] as String,
                style: TextStyle(
                  fontSize: 13.5,
                  color: t.textSecondary,
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 20),

            // Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: t.bgTag.withOpacity(0.08),
                borderRadius: BorderRadius.circular(_T.r50),
                border: Border.all(color: t.accentBdr.withOpacity(0.3)),
              ),
              child: Text(
                widget.app["tag"] as String,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: t.accent,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Technical Specifications Section (New Design)
// ─────────────────────────────────────────────
class _DetailedSpecSection extends StatelessWidget {
  final Map sensor;
  final bool isWide;
  final bool isTablet;

  const _DetailedSpecSection({
    required this.sensor,
    required this.isWide,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final specs = sensor["specifications"] as List?;
    final highlights = sensor["techHighlights"] as List?;
    if (specs == null || specs.isEmpty) return const SizedBox.shrink();

    final hPad = isWide ? 80.0 : (isTablet ? 40.0 : 24.0);

    return Container(
      color: t.bgBase,
      padding: EdgeInsets.fromLTRB(hPad, 100, hPad, 100),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(text: 'Technical specifications'),
              const SizedBox(height: 12),
              Text(
                'Everything you need to know',
                style: TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Text(
                  'Full technical detail for systems integrators, procurement, and engineering teams.',
                  style: TextStyle(
                    fontSize: 16,
                    color: t.textSecondary,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 64),
              isWide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left: Spec Table
                          Expanded(
                            flex: 6,
                            child: _SpecTable(specs: specs),
                          ),
                          const SizedBox(width: 48),
                          // Right: Highlights
                          if (highlights != null)
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  for (int i = 0;
                                      i < highlights.length;
                                      i++) ...[
                                    Expanded(
                                      child: _SpecHighlightCard(
                                          highlight: highlights[i] as Map),
                                    ),
                                    if (i < highlights.length - 1)
                                      const SizedBox(height: 16),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _SpecTable(specs: specs),
                        if (highlights != null) ...[
                          const SizedBox(height: 48),
                          ...highlights.map((h) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _SpecHighlightCard(highlight: h as Map),
                              )),
                        ],
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpecTable extends StatelessWidget {
  final List specs;
  const _SpecTable({required this.specs});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(_T.r14),
        border: Border.all(color: t.accentBdr.withOpacity(0.4), width: 1.0),
      ),
      child: Column(
        children: [
          for (int i = 0; i < specs.length; i++)
            _SpecRow(
              label: specs[i]["label"] as String,
              value: specs[i]["value"] as String,
              isLast: i == specs.length - 1,
              isEven: i % 2 == 0,
            ),
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;
  final bool isEven;
  const _SpecRow({
    required this.label,
    required this.value,
    required this.isLast,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: BoxDecoration(
        color: isEven ? t.bgBase.withOpacity(0.3) : Colors.transparent,
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: t.border, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: t.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: t.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecHighlightCard extends StatelessWidget {
  final Map highlight;
  const _SpecHighlightCard({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: t.bgCard,
        borderRadius: BorderRadius.circular(_T.r14),
        border: Border.all(color: t.accentBdr.withOpacity(0.4), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.bgTag.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_T.r50),
              border: Border.all(color: t.accentBdr.withOpacity(0.3)),
            ),
            child: Text(
              "TECH HIGHLIGHT",
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: t.accent,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            highlight["value"] as String,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: t.accent,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            highlight["label"] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: t.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            highlight["description"] as String,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: t.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Reusable small widgets
// ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
        color: t.accent,
      ),
    );
  }
}

class _EyebrowTag extends StatelessWidget {
  final String text;
  const _EyebrowTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: t.bgTag,
        borderRadius: BorderRadius.circular(_T.r50),
        border: Border.all(color: t.accentBdr),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: t.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: t.accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerBullet extends StatelessWidget {
  final String text;
  const _BannerBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: t.textSecondary,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckItem extends StatefulWidget {
  final String text;
  const _CheckItem({required this.text});

  @override
  State<_CheckItem> createState() => _CheckItemState();
}

class _CheckItemState extends State<_CheckItem> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: _hov ? t.bgCardHov : t.bgBase,
          borderRadius: BorderRadius.circular(_T.r8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check, size: 10, color: t.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: t.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String val;
  final String lbl;
  const _StatPill({required this.val, required this.lbl});

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: t.bgCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: t.accentBdr.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: t.accent,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            lbl.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: _hov ? t.bgCardHov : t.bgCard,
          borderRadius: BorderRadius.circular(_T.r14),
          border: Border.all(
            color: _hov ? t.accentBdr : t.border,
            width: _hov ? 1 : 0.5,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Ready to Deploy Section
// ─────────────────────────────────────────────
class _DeployCTA extends StatefulWidget {
  final Map sensor;
  const _DeployCTA({required this.sensor});

  @override
  State<_DeployCTA> createState() => _DeployCTAState();
}

class _DeployCTAState extends State<_DeployCTA> {
  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            // Eyebrow
            Text(
              'GET STARTED TODAY',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: t.accent.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(
                  fontFamily: 'Syne',
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1,
                ),
                children: [
                  TextSpan(
                      text: 'Ready to\n',
                      style: TextStyle(color: t.textPrimary)),
                  TextSpan(text: 'deploy?', style: TextStyle(color: t.accent)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Download the full datasheet or speak with the CloudSense engineering team about your specific application and integration requirements.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: t.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),

            // Action Row: Enquire & Download
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 60),
              child: isMobile
                  ? Column(
                      children: [
                        _buildEnquireButton(),
                        const SizedBox(height: 16),
                        _buildDownloadButton(),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(child: _buildEnquireButton()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildDownloadButton()),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnquireButton() {
    return _PrimaryButton(
      label: 'Enquire',
      icon: Icons.chat_bubble_outline_rounded,
      onTap: () => _sendEmail(context, widget.sensor["email"] as String),
      large: true,
    );
  }

  Widget _buildDownloadButton() {
    return _PrimaryButton(
      label: 'Download datasheet',
      icon: Icons.download_rounded,
      onTap: () => DownloadManager.downloadFile(
        context: context,
        sensorKey: widget.sensor["datasheetKey"] as String,
        fileType: "datasheet",
      ),
      large: true,
    );
  }
}

// ─────────────────────────────────────────────
//  Buttons
// ─────────────────────────────────────────────
class _PrimaryButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool large;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.large = false,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: EdgeInsets.symmetric(
            horizontal: widget.large ? 40 : 28,
            vertical: widget.large ? 18 : 14,
          ),
          decoration: BoxDecoration(
            color: _hov ? Colors.white : t.accent,
            borderRadius: BorderRadius.circular(_T.r50),
            boxShadow: _hov
                ? [
                    BoxShadow(
                        color: t.accent.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: t.bgDeep),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.large ? 16 : 14,
                  fontWeight: FontWeight.w800,
                  color: t.bgDeep,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostButton(
      {required this.label, required this.icon, required this.onTap});

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: _hov ? t.border : Colors.transparent,
            borderRadius: BorderRadius.circular(_T.r50),
            border: Border.all(
              color: _hov ? t.borderLight : t.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 16, color: _hov ? t.textPrimary : t.textSecondary),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: _hov ? t.textPrimary : t.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Decorative widgets
// ─────────────────────────────────────────────
class _GridBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return CustomPaint(
        painter: _GridPainter(color: t.accent.withOpacity(0.04)));
  }
}

class _GridPainter extends CustomPainter {
  final Color color;
  _GridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const step = 56.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}



class _SpinningRing extends StatefulWidget {
  final double size;
  final Color color;
  final bool reverse;
  final bool dashed;
  const _SpinningRing({
    required this.size,
    required this.color,
    this.reverse = false,
    this.dashed = false,
  });

  @override
  State<_SpinningRing> createState() => _SpinningRingState();
}

class _SpinningRingState extends State<_SpinningRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.reverse ? 28 : 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: RotationTransition(
        turns:
            widget.reverse ? Tween(begin: 1.0, end: 0.0).animate(_ctrl) : _ctrl,
        child: CustomPaint(
          painter: _RingPainter(
            color: widget.color,
            dashed: widget.dashed,
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _RingPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    if (dashed) {
      const dashCount = 24;
      const dashAngle = math.pi * 2 / dashCount;
      for (int i = 0; i < dashCount; i++) {
        if (i % 2 == 0) {
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            i * dashAngle,
            dashAngle * 0.6,
            false,
            paint,
          );
        }
      }
    } else {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
//  Ready to Deploy Section
// ─────────────────────────────────────────────
class _ReadyToDeploySection extends StatefulWidget {
  final Map sensor;
  const _ReadyToDeploySection({required this.sensor});

  @override
  State<_ReadyToDeploySection> createState() => _ReadyToDeploySectionState();
}

class _ReadyToDeploySectionState extends State<_ReadyToDeploySection> {
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 700;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 60 : 100,
        horizontal: isMobile ? 24 : 40,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF091520), // Premium deep dark background
        border: Border(
          top: BorderSide(color: t.border, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Eyebrow
          Text(
            "GET STARTED TODAY",
            style: TextStyle(
              color: t.accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 16),

          // Main Title
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: isMobile ? 36 : 64,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                fontFamily: 'OpenSans',
                letterSpacing: -1.5,
                height: 1.1,
              ),
              children: [
                const TextSpan(text: "Ready to "),
                TextSpan(
                  text: "deploy?",
                  style: TextStyle(
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF1FCB8A), Color(0xFF0FA86E)],
                      ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Subtext
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Text(
              "Download the full datasheet or speak with the ANNAM.AI engineering team about your specific application and integration requirements.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: isMobile ? 14 : 18,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Primary Actions: Enquire & Download
          _buildPrimaryActions(isMobile, t),
        ],
      ),
    );
  }

  Widget _buildPrimaryActions(bool isMobile, _T t) {
    final List<Widget> buttons = [
      _buildEnquireButton(t, isFullWidth: isMobile),
      if (!isMobile) const SizedBox(width: 16),
      if (isMobile) const SizedBox(height: 12),
      _ActionBtn(
        label: "Download datasheet",
        icon: Icons.download_rounded,
        isPrimary: true,
        onTap: () => DownloadManager.downloadFile(
          context: context,
          sensorKey: widget.sensor["datasheetKey"] ?? "DataLogger",
          fileType: "datasheet",
        ),
      ),
    ];

    if (isMobile) {
      return Column(children: buttons);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons,
    );
  }

  Widget _buildEnquireButton(_T t, {bool isFullWidth = false}) {
    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 52, // Matched height with ActionBtn
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ElevatedButton(
          onPressed: () => _sendEmail(
              context, widget.sensor["email"] ?? "communications@annam.ai"),
          style: ElevatedButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            padding: const EdgeInsets.symmetric(horizontal: 32),
          ),
          child: const Text(
            "Enquire",
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isPrimary ? const Color(0xFF1FCB8A) : Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isPrimary
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 18,
                    color: isPrimary
                        ? Colors.white
                        : Colors.white.withOpacity(0.8)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color:
                      isPrimary ? Colors.white : Colors.white.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Email helper (unchanged)
// ─────────────────────────────────────────────
Future<void> _sendEmail(BuildContext context, String email) async {
  final subject = Uri.encodeComponent("Product Enquiry");
  final body = Uri.encodeComponent("Hello, I am interested in your product.");

  final Uri mailtoUri = Uri(
    scheme: 'mailto',
    path: email,
    query: "subject=$subject&body=$body",
  );

  try {
    bool launched = false;

    if (kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android)) {
      launched = await launchUrl(mailtoUri);
    } else if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      launched =
          await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    } else {
      final gmailUrl = Uri.parse(
        "https://mail.google.com/mail/?view=cm&fs=1"
        "&to=${Uri.encodeComponent(email)}&su=$subject&body=$body",
      );
      launched =
          await launchUrl(gmailUrl, mode: LaunchMode.externalApplication);
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open email client.")),
      );
    }
  } catch (e) {
    debugPrint("Email error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to open email client.")),
      );
    }
  }
}

// ─────────────────────────────────────────────
//  Legacy exports kept for compatibility
// ─────────────────────────────────────────────
class SimpleListItem extends StatelessWidget {
  final String text;
  final bool isDarkMode;
  const SimpleListItem(
      {super.key, required this.text, required this.isDarkMode});

  @override
  Widget build(BuildContext context) => _CheckItem(text: text);
}

class HoverableCard extends StatelessWidget {
  final Widget child;
  const HoverableCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) => _HoverCard(child: child);
}

class BannerPoint extends StatelessWidget {
  final String text;
  final double? fontSize;
  const BannerPoint(this.text, {super.key, this.fontSize});

  @override
  Widget build(BuildContext context) => _BannerBullet(text: text);
}

class _ScannerEffect extends StatelessWidget {
  const _ScannerEffect();

  @override
  Widget build(BuildContext context) {
    final t = _T(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container()
                .animate(onPlay: (controller) => controller.repeat())
                .custom(
                  duration: 2.5.seconds,
                  builder: (context, value, child) {
                    return Positioned(
                      top: value * constraints.maxHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              t.accent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: t.accent.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ],
        );
      },
    );
  }
}
