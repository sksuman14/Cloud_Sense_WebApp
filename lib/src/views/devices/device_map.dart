import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/views/home/home_utils.dart';

// ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──

String _toAnnamDisplayName(String internalSensorName) =>
    DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

bool _isAnnamSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamCoreSensor(internalSensorName);

bool _isAnnamTestingSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamTestingSensor(internalSensorName);



// =============================================================================
// Hardcoded IIT Ropar campus sensors
// CP001 anchor: 30.97 lat, 76.47 lon — others spread within ~150–300 m
// =============================================================================
const List<Map<String, dynamic>> _hardcodedCampusSensors = [
  // ── IIT Ropar campus (anchor CP001: 30.97, 76.47) ────────────────────────

  {
    'deviceId': 'CP019',
    'latitude': 30.9695,
    'longitude': 76.4682,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP019'
  },
  {
    'deviceId': 'CP022',
    'latitude': 30.9695,
    'longitude': 76.4682,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP022'
  },

  {
    'deviceId': 'WJ466',
    'latitude': 31.670918,
    'longitude': 75.633001,
    'category': 'Jan Weather Sensor',
    'place': 'Hoshiarpur',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ466'
  },

  {
    'deviceId': 'WJ080',
    'latitude': 74.88,
    'longitude': 30.45,
    'category': 'Jan Weather Sensor',
    'place': 'Jaito, Faridkot',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ080'
  },
  {
    'deviceId': 'WJ224',
    'latitude': 31.209927,
    'longitude': 74.633207,
    'category': 'Jan Weather Sensor',
    'place': 'Tarn Taran',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ224'
  },

  {
    'deviceId': 'WJ231',
    'latitude': 31.425423,
    'longitude': 75.707947,
    'category': 'Jan Weather Sensor',
    'place': 'Adampur, Jalandhar',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ231'
  },

  {
    'deviceId': 'WJ262',
    'latitude': 31.707428,
    'longitude': 74.93945200000002,
    'category': 'Jan Weather Sensor',
    'place': 'Amritsar, Amritsar district ',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ262'
  },

  {
    'deviceId': 'CP023',
    'latitude': 30.9683,
    'longitude': 76.4705,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP023'
  },

  {
    'deviceId': 'WT001',
    'latitude': 30.9673,
    'longitude': 76.4705,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'Weather/sensor/WT001'
  },

  {
    'deviceId': 'CP027',
    'latitude': 30.9685,
    'longitude': 76.4702,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP027'
  },

  {
    'deviceId': 'CP040',
    'latitude': 30.9684,
    'longitude': 76.4700,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP040'
  },

  {
    'deviceId': 'CP041',
    'latitude': 30.9680,
    'longitude': 76.4701,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP041'
  },

  {
    'deviceId': 'CP003',
    'latitude': 30.9692,
    'longitude': 76.4748,
    'category': 'IIT Ropar Sensor',
    'place': 'Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/CP048'
  },
  {
    'deviceId': 'SW003',
    'latitude': 20.332441,
    'longitude': 85.801874,
    'category': 'Bhubaneswar (M.Corp.) P.S.',
    'place': 'Khordha district',
    'state': 'Odisha',
    'topic': 'WS/Campus/SW003'
  },

  {
    "deviceId": "IT100",
    "latitude": 19.1334,
    "longitude": 72.9133,
    "category": "IIT Bombay Sensor",
    "place": "IIT Bombay",
    "state": "Maharashtra",
    "topic": "Awadh/IIT_B/IT100"
  },
  // ── SSMET sensors in Assam ───────────────────────────────────────────────
  // SM010 anchor: 24.80, 93.12  (Imphal West / Manipur border area)

  {
    'deviceId': 'SM003',
    'latitude': 24.8050,
    'longitude': 93.1200,
    'category': 'SSMET Sensor',
    'place': 'Cachar',
    'state': 'Assam',
    'topic': 'WS/SSMet/SM003'
  },
  {
    'deviceId': 'WJ240',
    'latitude': 31.0253,
    'longitude': 76.5896,
    'category': 'Jan Weather Sensor',
    'place': 'Ghanauli, Rupnagar',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ240'
  },
  {
    'deviceId': 'WJ247',
    'latitude': 31.8860,
    'longitude': 75.0440,
    'category': 'Jan Weather Sensor',
    'place': 'Kala Afgana, Gurdaspur',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ247'
  },
  {
    'deviceId': 'WJ276',
    'latitude': 31.8200,
    'longitude': 75.3900,
    'category': 'Jan Weather Sensor',
    'place': 'Qadian, Gurdaspur',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ276'
  },
  {
    'deviceId': 'WA013',
    'latitude': 32.6623,
    'longitude': 74.9135,
    'category': 'Annam Weather Sensor',
    'place': 'Gajansu Madh',
    'state': 'Jammu and Kashmir',
    'topic': 'WS/Campus/WA013'
  },
  {
    'deviceId': 'WA027',
    'latitude': 32.5184,
    'longitude': 74.8895,
    'category': 'Annam Weather Sensor',
    'place': 'Nandpur, Sambha',
    'state': 'Jammu and Kashmir',
    'topic': 'WS/Campus/WA027'
  },
  {
    'deviceId': 'WJ398',
    'latitude': 30.702,
    'longitude': 76.702,
    'category': 'Jan Weather Sensor',
    'place': 'District Administration Complex, Sector 76, Mohali',
    'state': 'Punjab',
    'topic': 'WS/Campus/WJ398'
  },
  {
    'deviceId': 'WJ221',
    'latitude': 30.97,
    'longitude': 74.99,
    'category': 'Jan Weather Sensor',
    'place': 'Zira tehsil, Firozpur district',
    'state': 'Punjab',
    'topic': 'WS/SSMet_0126/221'
  },
  {
    'deviceId': 'NA013',
    'latitude': 17.4197,
    'longitude': 78.4990,
    'category': 'NARL Sensor',
    'place': 'Hyderabad, Musheerabad mandal',
    'state': 'Telangana',
    'topic': 'WS/SSMet/NARL/13'
  },
  {
    'deviceId': 'WJ267',
    'latitude': 29.69,
    'longitude': 75.24,
    'category': 'Jan Weather Sensor',
    'place': 'Sardulgarh tehsil, Mansa district',
    'state': 'Punjab',
    'topic': 'WS/SSMet_0126/267'
  },
  {
    'deviceId': 'WA016',
    'latitude': 32.422158,
    'longitude': 75.257138,
    'category': 'Annam Weather Sensor',
    'place': 'Hiranagar, Kathua',
    'state': 'Jammu and Kashmir',
    'topic': 'WS/Campus/WA016'
  },
  {
    'deviceId': 'WJ214',
    'latitude': 32.1431,
    'longitude': 75.476092,
    'category': 'Jan Weather Sensor',
    'place': 'Dinanagar',
    'state': 'Punjab',
    'topic': 'WS/SSMet_0126/214'
  },
  {
    'deviceId': 'ANNAM0126_214',
    'latitude': 32.1431,
    'longitude': 75.476092,
    'category': 'Jan Weather Sensor',
    'place': 'Dinanagar',
    'state': 'Punjab',
    'topic': 'WS/SSMet_0126/214'
  },
];
List<Map<String, dynamic>> _buildHardcodedSensors() => _hardcodedCampusSensors
    .map((s) => <String, dynamic>{
          'deviceId': s['deviceId'],
          'rawDeviceId': s['deviceId'],
          'latitude': (s['latitude'] as num).toDouble(),
          'longitude': (s['longitude'] as num).toDouble(),
          'last_active': 'N/A',
          'category': s['category'],
          'source': 'CloudSense',
          'place': s['place'],
          'state': s['state'],
          'country': 'India',
          'topic': s['topic'],
        })
    .toList();

// =============================================================================
// Unified color constants
// =============================================================================
const Color _kAnnamGreen = Color(0xFF2E7D32);
const Color _kImdOrange  = Color(0xFFE65100);

// =============================================================================
// ANNAM.AI sensor marker – clean with pulsing ring animation
// =============================================================================
class _AnnamAiMarker extends StatelessWidget {
  final Animation<double>? pulseAnim;
  const _AnnamAiMarker({this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    const markerColor = Color(0xFF00C853); // Clean emerald
    const ringColor = Color(0xFF69F0AE);   // Lighter ring

    Widget core = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.sensors, color: Colors.white, size: 14),
    );

    if (pulseAnim == null) return Center(child: core);

    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim!,
        builder: (context, child) {
          final p = pulseAnim!.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Opacity(
                opacity: (1 - p).clamp(0.0, 0.7),
                child: Container(
                  width: 28 + p * 28,
                  height: 28 + p * 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: (2.0 * (1 - p)).clamp(0.5, 2.0),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

// =============================================================================
// Cluster bubble widget with clean pulsing ring animation
// =============================================================================
class _ClusterBubble extends StatelessWidget {
  final int count;
  final Color color;
  final double size;
  final IconData? topIcon;
  final Animation<double>? pulseAnim;

  const _ClusterBubble({
    required this.count,
    required this.color,
    this.size = 44,
    this.topIcon,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    Widget core = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (topIcon != null)
            Icon(topIcon, color: Colors.white, size: size * 0.28),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: size * (topIcon != null ? 0.28 : 0.38),
              height: 1.1,
              shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
            ),
          ),
        ],
      ),
    );

    if (pulseAnim == null) return Center(child: core);

    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim!,
        builder: (context, child) {
          final p = pulseAnim!.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring — subtle white/color fade
              Opacity(
                opacity: (1 - p).clamp(0.0, 0.55),
                child: Container(
                  width: size + p * size * 0.65,
                  height: size + p * size * 0.65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: (2.5 * (1 - p)).clamp(0.3, 2.5),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

// =============================================================================
// IMD sensor marker – clean with pulsing ring animation
// =============================================================================
class _ImdMarker extends StatelessWidget {
  final Animation<double>? pulseAnim;
  const _ImdMarker({this.pulseAnim});

  @override
  Widget build(BuildContext context) {
    const markerColor = Color(0xFFFF6D00); // Clean deep orange
    const ringColor = Color(0xFFFFAB40);   // Lighter amber ring

    Widget core = Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: const Icon(Icons.wb_sunny, color: Colors.white, size: 14),
    );

    if (pulseAnim == null) return Center(child: core);

    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim!,
        builder: (context, child) {
          final p = pulseAnim!.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - p).clamp(0.0, 0.7),
                child: Container(
                  width: 28 + p * 28,
                  height: 28 + p * 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor,
                      width: (2.0 * (1 - p)).clamp(0.5, 2.0),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

// =============================================================================
// Map legend – simplified: only ANNAM.AI and IMD, no state/district breakdown
// =============================================================================
class _MapLegend extends StatelessWidget {
  final int csCount;
  final int imdCount;
  final bool showImdCount;
  final bool showImdLegend;
  final bool isCompact;

  const _MapLegend({
    required this.csCount,
    required this.imdCount,
    this.showImdCount = true,
    this.showImdLegend = true,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ANNAM.AI row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: _kAnnamGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.sensors,
                          color: Colors.white, size: 10),
                    ),
                    const SizedBox(width: 5),
                    const Text('ANNAM.AI',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 5),
                    Text('$csCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
                // IMD row (conditional)
                if (showImdCount) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _kImdOrange,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.wb_sunny,
                            color: Colors.white, size: 10),
                      ),
                      const SizedBox(width: 5),
                      const Text('IMD',
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 5),
                      Text('$imdCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Count chips ───────────────────────────────────────────
              Row(
                children: [
                  _countChip(
                    color: _kAnnamGreen,
                    label: 'ANNAM.AI Sensors',
                    count: csCount,
                  ),
                  if (showImdCount) ...[
                    const SizedBox(width: 8),
                    _countChip(
                      color: _kImdOrange,
                      icon: Icons.wb_sunny,
                      label: 'IMD Sensors',
                      count: imdCount,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 10),

              // ── Marker key ────────────────────────────────────────────
              _row(
                const SizedBox(width: 22, height: 22, child: _AnnamAiMarker()),
                'ANNAM.AI Sensor',
              ),
              if (showImdLegend) ...[
                const SizedBox(height: 6),
                _row(
                  const SizedBox(width: 22, height: 22, child: _ImdMarker()),
                  'IMD Sensor',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _countChip({
    required Color color,
    IconData? icon,
    required String label,
    required int count,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: Colors.white70),
            const SizedBox(width: 4),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.white54, fontSize: 9)),
              Text('$count',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(Widget icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 26, child: Center(child: icon)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      );
}

// =============================================================================
// Weather layer helpers
// =============================================================================
enum WeatherLayer { clusters, temperature, humidity, wind, rainfall, pressure }

// =============================================================================
// Map section selector
// =============================================================================
enum MapSection { allSensors, annamWeather }

const Map<WeatherLayer, String> _layerLabels = {
  WeatherLayer.clusters: 'Sensor Clusters',
  WeatherLayer.temperature: 'Temperature',
  WeatherLayer.humidity: 'Humidity',
  WeatherLayer.wind: 'Wind',
  WeatherLayer.rainfall: 'Rainfall',
  WeatherLayer.pressure: 'Pressure',
};

/// Returns an intuitive warm color for temperature (light orange → orange → red).
Color _tempColor(double v) {
  if (v >= 42) return const Color(0xFFB71C1C); // dark red (extreme)
  if (v >= 38) return const Color(0xFFC62828); // red
  if (v >= 35) return const Color(0xFFD84315); // deep orange-red
  if (v >= 32) return const Color(0xFFE65100); // burnt orange
  if (v >= 29) return const Color(0xFFEF6C00); // orange
  if (v >= 26) return const Color(0xFFF57C00); // medium orange
  if (v >= 22) return const Color(0xFFFB8C00); // light orange
  if (v >= 18) return const Color(0xFFFFA726); // pale orange
  if (v >= 14) return const Color(0xFFFFB74D); // soft orange
  return const Color(0xFFFFCC80); // very pale orange (cold)
}

/// Humidity uses warm-to-cool gradient (dry orange → green → teal → wet blue).
Color _humidityColor(double v) {
  if (v >= 80) return const Color(0xFF1565C0); // deep blue (very humid)
  if (v >= 70) return const Color(0xFF0097A7); // dark cyan
  if (v >= 60) return const Color(0xFF00897B); // teal
  if (v >= 50) return const Color(0xFF43A047); // green
  if (v >= 40) return const Color(0xFF7CB342); // light green
  if (v >= 30) return const Color(0xFFFFA726); // orange (dry)
  return const Color(0xFFEF6C00); // deep orange (very dry)
}

/// Wind uses navy-blue tones.
Color _windColor(double v) {
  if (v >= 9) return const Color(0xFF1A237E); // deep navy (strong)
  if (v >= 7) return const Color(0xFF283593); // dark indigo
  if (v >= 5) return const Color(0xFF303F9F); // indigo
  if (v >= 3) return const Color(0xFF3949AB); // medium blue
  return const Color(0xFF5C6BC0); // light indigo (calm)
}

/// Rainfall uses water-themed blues.
Color _rainfallColor(double v) {
  if (v >= 50) return const Color(0xFF0D47A1); // navy (heavy)
  if (v >= 20) return const Color(0xFF1565C0); // deep blue
  if (v >= 10) return const Color(0xFF1976D2);
  if (v >= 2) return const Color(0xFF42A5F5); // medium blue
  if (v > 0) return const Color(0xFF4FC3F7); // light drizzle
  return const Color(0xFF81D4FA); // pale blue (no rain)
}

/// Pressure uses teal-to-purple.
Color _pressureColor(double v) {
  if (v >= 1030) return const Color(0xFF5E35B1); // deep purple (high)
  if (v >= 1020) return const Color(0xFF7E57C2);
  if (v >= 1010) return const Color(0xFF5C6BC0); // indigo
  if (v >= 1000) return const Color(0xFF26A69A); // teal
  return const Color(0xFF66BB6A); // green (low)
}

Color _colorForLayer(WeatherLayer layer, double value) {
  switch (layer) {
    case WeatherLayer.temperature:
      return _tempColor(value);
    case WeatherLayer.humidity:
      return _humidityColor(value);
    case WeatherLayer.wind:
      return _windColor(value);
    case WeatherLayer.rainfall:
      return _rainfallColor(value);
    case WeatherLayer.pressure:
      return _pressureColor(value);
    default:
      return Colors.grey;
  }
}

String _unitForLayer(WeatherLayer layer) {
  switch (layer) {
    case WeatherLayer.temperature:
      return '°C';
    case WeatherLayer.humidity:
      return '%';
    case WeatherLayer.wind:
      return 'm/s';
    case WeatherLayer.rainfall:
      return 'mm';
    case WeatherLayer.pressure:
      return 'hPa';
    default:
      return '';
  }
}

String _fieldForLayer(WeatherLayer layer) {
  switch (layer) {
    case WeatherLayer.temperature:
      return 'curr_temp';
    case WeatherLayer.humidity:
      return 'rh';
    case WeatherLayer.wind:
      return 'wind_speed';
    case WeatherLayer.rainfall:
      return 'rainfall';
    case WeatherLayer.pressure:
      return 'mslp';
    default:
      return '';
  }
}

String _formatMarkerValue(WeatherLayer layer, double value) {
  final roundedToInt = value.roundToDouble();
  if ((value - roundedToInt).abs() < 0.05) {
    return roundedToInt.toInt().toString();
  }

  switch (layer) {
    case WeatherLayer.rainfall:
      return value.toStringAsFixed(1);
    default:
      return roundedToInt.toInt().toString();
  }
}



// =============================================================================
// Weather value marker — circular bubble with value text
// =============================================================================
class _WeatherValueMarker extends StatelessWidget {
  final String displayValue;
  final String unit;
  final Color bgColor;
  final Animation<double>? pulseAnim;

  const _WeatherValueMarker({
    required this.displayValue,
    required this.unit,
    required this.bgColor,
    this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    Widget core = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            displayValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 7,
              height: 1.0,
            ),
          ),
        ],
      ),
    );

    if (pulseAnim == null) return Center(child: core);

    return Center(
      child: AnimatedBuilder(
        animation: pulseAnim!,
        builder: (context, child) {
          final p = pulseAnim!.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Expanding pulse ring
              Opacity(
                opacity: (1 - p).clamp(0.0, 0.65),
                child: Container(
                  width: 38 + p * 30,
                  height: 38 + p * 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: bgColor,
                      width: (2.5 * (1 - p)).clamp(0.3, 2.5),
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: core,
      ),
    );
  }
}

// =============================================================================
// Weather scale box — bottom-right gradient bar showing value range
// =============================================================================
class _WeatherScaleBox extends StatelessWidget {
  final WeatherLayer layer;
  final double boxWidth;

  const _WeatherScaleBox({required this.layer, this.boxWidth = 180});

  @override
  Widget build(BuildContext context) {
    final info = _scaleInfo(layer);

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: boxWidth,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _layerLabels[layer] ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(colors: info.colors),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(info.lowLabel,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: boxWidth < 150 ? 7 : 9),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(info.highLabel,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: boxWidth < 150 ? 7 : 9),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static _ScaleInfo _scaleInfo(WeatherLayer layer) {
    switch (layer) {
      case WeatherLayer.temperature:
        return _ScaleInfo(
          colors: [
            const Color(0xFFFFCC80),
            const Color(0xFFFFB74D),
            const Color(0xFFFFA726),
            const Color(0xFFF57C00),
            const Color(0xFFEF6C00),
            const Color(0xFFE65100),
            const Color(0xFFD84315),
            const Color(0xFFC62828),
          ],
          lowLabel: '12°C mild',
          highLabel: '42°C hot',
        );
      case WeatherLayer.humidity:
        return _ScaleInfo(
          colors: [
            const Color(0xFFEF6C00),
            const Color(0xFFFFA726),
            const Color(0xFF7CB342),
            const Color(0xFF43A047),
            const Color(0xFF00897B),
            const Color(0xFF0097A7),
            const Color(0xFF1565C0),
          ],
          lowLabel: '26% dry',
          highLabel: '84% wet',
        );
      case WeatherLayer.wind:
        return _ScaleInfo(
          colors: [
            const Color(0xFF5C6BC0),
            const Color(0xFF3949AB),
            const Color(0xFF303F9F),
            const Color(0xFF283593),
            const Color(0xFF1A237E),
          ],
          lowLabel: '2 calm',
          highLabel: '9 strong',
        );
      case WeatherLayer.rainfall:
        return _ScaleInfo(
          colors: [
            const Color(0xFF81D4FA),
            const Color(0xFF4FC3F7),
            const Color(0xFF42A5F5),
            const Color(0xFF1976D2),
            const Color(0xFF1565C0),
            const Color(0xFF0D47A1),
          ],
          lowLabel: '0 dry',
          highLabel: '6mm+',
        );
      case WeatherLayer.pressure:
        return _ScaleInfo(
          colors: [
            const Color(0xFF66BB6A),
            const Color(0xFF26A69A),
            const Color(0xFF5C6BC0),
            const Color(0xFF7E57C2),
            const Color(0xFF5E35B1),
          ],
          lowLabel: '<1000 hPa low',
          highLabel: '1030+ hPa high',
        );
      default:
        return _ScaleInfo(colors: [Colors.grey], lowLabel: '', highLabel: '');
    }
  }
}

class _ScaleInfo {
  final List<Color> colors;
  final String lowLabel;
  final String highLabel;
  _ScaleInfo(
      {required this.colors, required this.lowLabel, required this.highLabel});
}

// =============================================================================
// Main screen
// =============================================================================
class DeviceMapScreen extends StatefulWidget {
  final bool isComponent;
  final double height;

  DeviceMapScreen({this.isComponent = false, this.height = 600});

  @override
  _DeviceMapScreenState createState() => _DeviceMapScreenState();
}

class _DeviceMapScreenState extends State<DeviceMapScreen>
    with TickerProviderStateMixin {
  // ── Layer 1: In-Memory cache (survives navigation within same session) ─────
  static List<Map<String, dynamic>>? _memCachedDevices;
  static List<Map<String, dynamic>>? _memCachedImd;
  static int? _memCachedDashboardAnnamCount;
  static DateTime? _memCacheTimestamp;

  // ── Shared keys & expiry (Layer 2: disk cache) ────────────────────────────
  static const String _keyDevices = 'cached_device_locations';
  static const String _keyImd = 'cached_imd_locations';
  static const String _keyDashboardAnnamCount = 'cached_dashboard_annam_count';
  static const String _keyTimestamp = 'cached_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 30);
  // static const int _dashboardExtraSensorCount = 24;

  final MapController mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // ── Pulse animation for markers ───────────────────────────────────────────
  AnimationController? _pulseController;
  Animation<double>? _pulseAnim;

  LatLng centerCoordinates = LatLng(22.9734, 78.6569);
  double zoomLevel = 4.5;
  WeatherLayer _selectedLayer = WeatherLayer.clusters;
  MapSection _currentSection = MapSection.annamWeather;
  Marker? searchPin;
  String searchQuery = '';
  bool _isSearchExpanded = false;
  bool _isMapInteracted = false;
  LatLng? _preInteractionCenter;
  double? _preInteractionZoom;
  bool _isInitialLoad = true;

  List<Map<String, dynamic>> deviceLocations = [];
  List<Map<String, dynamic>> imdLocations = [];

  // ── Hardcoded IIT Ropar campus sensors ────────────────────────────────────
  final List<Map<String, dynamic>> hardcodedSensors = _buildHardcodedSensors();

  List<Map<String, dynamic>> suggestions = [];
  List<Map<String, dynamic>> visibleDevices = [];
  int _dashboardAnnamCount = 0;
  final Map<String, Map<String, dynamic>> _weatherSnapshots = {};
  DateTime? _lastWeatherSnapshotSyncAt;
  bool _isWeatherSnapshotSyncing = false;
  static const Duration _weatherSnapshotTtl = Duration(minutes: 3);

  bool isWeatherMapSelected = false;
  String selectedWeatherMetric = 'Sensor Clusters';
  static const List<String> weatherMetrics = [
    'Sensor Clusters',
    'Temperature',
    'Humidity',
    'Wind',
    'Rainfall',
    'Pressure',
  ];

  static const double CLUSTER_ZOOM_THRESHOLD = 7.0;
  static const double DISTRICT_ZOOM_THRESHOLD = 9.0;

  // ── 5-minute weather auto-refresh timer ──────────────────────────────────
  Timer? _weatherRefreshTimer;
  bool _isShiftPressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialLoad) {
      _isInitialLoad = false;
      final isMobile = MediaQuery.sizeOf(context).width < 600;
      if (isMobile) {
        // Shift center East (longitude 78.0) to move the map image Left, and zoom out more
        centerCoordinates = LatLng(22.9734, 78.0000);
        zoomLevel = 3.4;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAllData();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _weatherRefreshTimer = Timer.periodic(const Duration(seconds: 180), (_) {
      if (mounted) _refreshInBackground();
    });
    // Pulse animation — slow, smooth 2-second heartbeat
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: false);
    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeOut),
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (mounted) {
      setState(() {
        _isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      });
    }
    return false; // Don't consume the event
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _weatherRefreshTimer?.cancel();
    _pulseController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  int _getInteractiveFlags() {
    // In full-screen mode (isComponent = false), allow all interactions (zoom, pan, pinch)
    // across all platforms to provide the best user experience.
    if (!widget.isComponent) {
      return InteractiveFlag.all | InteractiveFlag.scrollWheelZoom;
    }

    // COMPONENT MODE (e.g. on homepage)
    // The user wants NO movement (moving or zoom) on the homepage map.
    return InteractiveFlag.none;
  }

  Future<void> _loadAllData() async {
    // ── Always show hardcoded sensors immediately ──────────────────────────
    setState(() {
      visibleDevices = hardcodedSensors.toList();
    });

    // ── Layer 1: Check in-memory cache first (RAM, instant) ───────────────
    final bool memValid = _memCachedDevices != null &&
        _memCachedImd != null &&
        _memCachedDashboardAnnamCount != null &&
        _memCacheTimestamp != null &&
        DateTime.now().difference(_memCacheTimestamp!) < _cacheDuration;

    if (memValid) {
      setState(() {
        deviceLocations = _memCachedDevices!;
        imdLocations = _memCachedImd!;
        _dashboardAnnamCount = _memCachedDashboardAnnamCount!;
        visibleDevices = _allDevices;
      });
      _refreshInBackground();
      return;
    }

    // ── Layer 2: Check disk cache (SharedPreferences, ~100ms) ─────────────
    final bool diskLoaded = await _loadCacheFromDisk();
    if (diskLoaded) {
      _refreshInBackground();
      return;
    }

    // ── Layer 3: No cache anywhere — fetch fresh from API ──────────────────
    await Future.wait([
      _loadDeviceDataFromApi(),
      _loadImdDataFromApi(),
    ]);
  }

  /// Fetches fresh data silently without clearing existing visible pins
  Future<void> _refreshInBackground() async {
    await Future.wait([
      _loadDeviceDataFromApi(),
      _loadImdDataFromApi(),
    ]);
    _syncOneDayWeatherSnapshots();
  }

  /// Saves current device + IMD data to both RAM and disk
  Future<void> _saveToCache() async {
    _memCachedDevices = deviceLocations;
    _memCachedImd = imdLocations;
    _memCachedDashboardAnnamCount = _dashboardAnnamCount;
    _memCacheTimestamp = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDevices, json.encode(deviceLocations));
      await prefs.setString(_keyImd, json.encode(imdLocations));
      await prefs.setInt(_keyDashboardAnnamCount, _dashboardAnnamCount);
      await prefs.setString(_keyTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('Disk cache save error: $e');
    }
  }

  /// Loads from disk cache into state, returns true if valid cache found
  Future<bool> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final String? timestampStr = prefs.getString(_keyTimestamp);
      if (timestampStr == null) return false;

      final DateTime timestamp = DateTime.parse(timestampStr);
      final bool isExpired =
          DateTime.now().difference(timestamp) > _cacheDuration;
      if (isExpired) return false;

      final String? devicesJson = prefs.getString(_keyDevices);
      final String? imdJson = prefs.getString(_keyImd);
      final int dashboardAnnamCount =
          prefs.getInt(_keyDashboardAnnamCount) ?? 0;
      if (devicesJson == null || imdJson == null) return false;

      final List<dynamic> decodedDevices = json.decode(devicesJson);
      final List<dynamic> decodedImd = json.decode(imdJson);

      final List<Map<String, dynamic>> devices =
          decodedDevices.map((e) => Map<String, dynamic>.from(e)).toList();
      final List<Map<String, dynamic>> imd =
          decodedImd.map((e) => Map<String, dynamic>.from(e)).toList();

      _memCachedDevices = devices;
      _memCachedImd = imd;
      _memCachedDashboardAnnamCount = dashboardAnnamCount;
      _memCacheTimestamp = timestamp;

      setState(() {
        deviceLocations = devices;
        imdLocations = imd;
        _dashboardAnnamCount = dashboardAnnamCount;
        visibleDevices = _allDevices;
      });
      return true;
    } catch (e) {
      debugPrint('Disk cache load error: $e');
      return false;
    }
  }

  Future<void> _loadImdDataFromApi() async {
    const url =
        'https://3xlnx8gixj.execute-api.us-east-1.amazonaws.com/city/api/aws_data_api.php';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        _showError('IMD API failed: ${response.statusCode}');
        return;
      }

      final List<dynamic> jsonList = json.decode(response.body);
      final List<Map<String, dynamic>> sensors = [];

      for (var item in jsonList) {
        final lat = double.tryParse(item['Latitude']?.toString() ?? '');
        final lon = double.tryParse(item['Longitude']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final date = item['DATE']?.toString() ?? '';
        final time = item['TIME']?.toString() ?? '';
        final lastActive = (date.isNotEmpty && time.isNotEmpty)
            ? '$date $time'
            : (date.isNotEmpty ? date : 'N/A');

        sensors.add({
          'deviceId': item['ID']?.toString() ?? 'IMD-Unknown',
          'rawDeviceId': item['ID']?.toString() ?? '',
          'latitude': lat,
          'longitude': lon,
          'last_active': lastActive,
          'category': 'IMD Sensor',
          'source': 'IMD',
          'city': item['STATION']?.toString() ?? '',
          'district':
              DevicePrefixUtils.cleanDistrict(item['DISTRICT']?.toString()),
          'place':
              DevicePrefixUtils.cleanDistrict(item['DISTRICT']?.toString()),
          'state': item['STATE']?.toString() ?? '',
          'country': 'India',
          'station': item['STATION']?.toString() ?? '',
          'curr_temp': item['CURR_TEMP']?.toString() ?? 'N/A',
          'feel_like': item['Feel Like']?.toString() ?? 'N/A',
          'rh': item['RH']?.toString() ?? 'N/A',
          'wind_speed': item['WIND_SPEED']?.toString() ?? 'N/A',
          'wind_dir': item['WIND_DIRECTION']?.toString() ?? 'N/A',
          'mslp': item['MSLP']?.toString() ?? 'N/A',
          'min_temp': item['MIN_TEMP']?.toString() ?? 'N/A',
          'max_temp': item['MAX_TEMP']?.toString() ?? 'N/A',
        });
      }

      setState(() {
        imdLocations = sensors;
        visibleDevices = _allDevices;
      });
      _saveToCache();
    } catch (e) {
      _showError('Error loading IMD data: $e');
    }
  }



  Future<void> _loadDeviceDataFromApi() async {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];

    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching device map data $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      // Mirror dashboard total logic:
      // count raw API devices with valid Latitude/Longitude, then add static extra sensors.
      final List<Map<String, dynamic>> rawDashboardDevices = [];

      // Store the most recent API record for each device
      final Map<String, Map<String, dynamic>> latestApiMap = {};

      for (int i = 0; i < responses.length; i++) {
        final response = responses[i];
        if (response.statusCode != 200) continue;

        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic>? devices = jsonResponse['devices'];
        if (devices == null || devices.isEmpty) continue;
        rawDashboardDevices.addAll(devices.cast<Map<String, dynamic>>());

        for (var item in devices) {
          final deviceIdTopic = item['deviceid#topic']?.toString() ?? '';
          if (deviceIdTopic.isEmpty) continue;
          final parts = deviceIdTopic.split('#');
          if (parts.length < 2) continue;

          final deviceId = parts[0];
          final topic = parts.sublist(1).join('#');
          if (topic.startsWith('BF/') || topic.startsWith('CS/')) continue;

          final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);
          final formattedDeviceId =
              DevicePrefixUtils.resolveSensorName(deviceId, topic);

          final latRaw = item['Latitude'] ?? item['LastKnownLatitude'];
          final lonRaw = item['Longitude'] ?? item['LastKnownLongitude'];
          final lat =
              latRaw != null ? double.tryParse(latRaw.toString()) : null;
          final lon =
              lonRaw != null ? double.tryParse(lonRaw.toString()) : null;
          String? tsStr = item['TimeStamp_IST']?.toString();
          if (topic.toLowerCase().contains('jw') ||
              topic.toLowerCase().contains('jio_logger')) {
            final mqttTime = item['MQTT_TopicTime'] ?? item['mqtt_topic_time'];
            if (mqttTime != null && mqttTime.toString().isNotEmpty) {
              tsStr = mqttTime.toString();
            }
          }
          final timestamp = parseDate(tsStr);

          // Apply the exact formatting algorithm used by home_page.dart's _formatValue
          String formatMetric(dynamic val) {
            if (val == null) return 'N/A';
            final str = val.toString().trim();
            if (str.isEmpty || str.toLowerCase() == 'null') return 'N/A';
            final num? number = num.tryParse(str);
            if (number != null) {
              double rounded = double.parse(number.toStringAsFixed(4));
              // Strip trailing '.0' if present to match the exact dashboard look
              if (rounded == rounded.toInt()) {
                return rounded.toInt().toString();
              }
              return rounded.toString();
            }
            return str;
          }

          // ── Dead-sensor detection: if all core metrics are 0, mark as N/A ──
          final rawTemp = item['CorrectedTemp'] ??
              item['correctedtemp'] ??
              item['CorrectedTemperature'] ??
              item['correctedtemperature'] ??
              item['CurrentTemperature'] ??
              item['currenttemperature'];
          final rawHum = item['CorrectedHumidity'] ??
              item['correctedhumidity'] ??
              item['CurrentHumidity'] ??
              item['currenthumidity'];
          final rawPres = item['CurrentPressure'] ?? item['AtmPressure'];
          final bool isDeadSensor =
              ((rawTemp != null && num.tryParse(rawTemp.toString()) == 0) &&
                  (rawHum != null && num.tryParse(rawHum.toString()) == 0) &&
                  (rawPres != null && num.tryParse(rawPres.toString()) == 0));

          // Format metric and apply plausibility check for weather fields
          String formatWeatherMetric(dynamic val, String fieldKey) {
            final formatted = formatMetric(val);
            if (isDeadSensor) return 'N/A';
            if (formatted == 'N/A') return 'N/A';
            final num? number = num.tryParse(formatted);
            if (number != null &&
                !_isPlausibleWeatherValue(fieldKey, number.toDouble())) {
              return 'N/A';
            }
            return formatted;
          }

          // Rainfall only: populates deviceData['rainfall']. Temperature, humidity,
          // wind, pressure, etc. are set separately below — this logic does not touch them.
          String selectRainfallMetric() {
            final hourlyVal = HomeUtils.getCorrectedValue(item, ['rainfallhourly', 'RainfallHourly']) ?? item['RainfallHourly'];
            final hourly = formatWeatherMetric(hourlyVal, 'rainfall');

            final hourlyCumVal = HomeUtils.getCorrectedValue(item, ['rainfallhourlycomulative', 'RainfallHourlyComulative']) ?? item['RainfallHourlyComulative'];
            final hourlyCumulative = formatWeatherMetric(hourlyCumVal, 'rainfall');

            final dailyVal = HomeUtils.getCorrectedValue(item, ['rainfalldaily', 'RainfallDaily']) ?? item['RainfallDaily'];
            final daily = formatWeatherMetric(dailyVal, 'rainfall');

            final dailyCumVal = HomeUtils.getCorrectedValue(item, ['rainfalldailycomulative', 'RainfallDailyComulative', 'rainfall_cumulative', 'Rainfall_Cumulative']) ?? item['RainfallDailyComulative'];
            final dailyCumulative = formatWeatherMetric(dailyCumVal, 'rainfall');

            bool isPositive(String v) =>
                v != 'N/A' && (double.tryParse(v) ?? 0) > 0;

            String prefer(String primary, [String? fallback]) {
              if (isPositive(primary)) return primary;
              if (fallback != null && isPositive(fallback)) return fallback;
              if (primary != 'N/A') return primary;
              if (fallback != null && fallback != 'N/A') return fallback;
              return 'N/A';
            }

            switch (mapped.prefix) {
              case 'CP':
                // CP graph header uses RainfallHourly; do not swap in Daily when hourly is 0.
                if (hourly != 'N/A') return hourly;
                return daily != 'N/A' ? daily : 'N/A';
              case 'SV':
              case 'VD':
                return prefer(hourlyCumulative, hourly);
              case 'NA':
              case 'SS':
                return prefer(daily, hourly);
              case 'SM':
                return prefer(dailyCumulative, hourly);
              default:
                return hourly;
            }
          }

          // Build our canonical format for map telemetry
          final deviceData = {
            'deviceId': formattedDeviceId,
            'rawDeviceId': deviceId,
            'latitude': lat,
            'longitude': lon,
            'last_active': timestamp?.toString() ?? 'N/A',
            'parsed_timestamp': timestamp,
            'topic': topic,
            'category': mapped.category,
            'source': 'CloudSense',
            'API': 'API ${i + 1}',
            'city': item['City']?.toString() ?? item['Place']?.toString() ?? '',
            'district':
                DevicePrefixUtils.cleanDistrict(item['District']?.toString()),
            'place':
                DevicePrefixUtils.cleanDistrict(item['District']?.toString()),
            'state': item['State']?.toString() ?? '',
            'country': 'India',
            // ── Weather telemetry formatted exactly like Dashboard ──
            'curr_temp': formatWeatherMetric(
                item['CorrectedTemp'] ??
                    item['correctedtemp'] ??
                    item['CorrectedTemperature'] ??
                    item['correctedtemperature'] ??
                    item['CurrentTemperature'] ??
                    item['currenttemperature'],
                'curr_temp'),
            'rh': formatWeatherMetric(
                item['CorrectedHumidity'] ??
                    item['correctedhumidity'] ??
                    item['CurrentHumidity'] ??
                    item['currenthumidity'],
                'rh'),
            'wind_speed': formatWeatherMetric(item['WindSpeed'], 'wind_speed'),
            'wind_dir': formatMetric(item['WindDirection']),
            'rainfall': selectRainfallMetric(),
            'rainfall_minutely_cumulative':
                formatMetric(item['RainfallMinutlyComulative']),
            'rainfall_hourly_cumulative':
                formatMetric(item['RainfallHourlyComulative']),
            'rainfall_daily_cumulative':
                formatMetric(item['RainfallDailyComulative']),
            'rainfall_hourly': formatMetric(item['RainfallHourly']),
            'rainfall_daily': formatMetric(item['RainfallDaily']),
            'rainfall_weekly': formatMetric(item['RainfallWeekly']),
            'mslp': formatWeatherMetric(
                item['CurrentPressure'] ?? item['AtmPressure'], 'mslp'),
            'light_intensity': formatMetric(item['LightIntensity']),
            'station': item['Station']?.toString() ?? '',
          };

          if (latestApiMap.containsKey(formattedDeviceId)) {
            final existingTs =
                latestApiMap[formattedDeviceId]!['parsed_timestamp']
                    as DateTime?;
            if (timestamp != null &&
                existingTs != null &&
                timestamp.isAfter(existingTs)) {
              // Safeguard: Do not overwrite valid older data with newer 'N/A' data
              final oldData = latestApiMap[formattedDeviceId]!;
              deviceData.forEach((k, v) {
                if (v == 'N/A' || v == null) {
                  deviceData[k] = oldData[k];
                }
              });
              latestApiMap[formattedDeviceId] = deviceData;
            } else if (existingTs == null && timestamp != null) {
              latestApiMap[formattedDeviceId] = deviceData;
            }
          } else {
            latestApiMap[formattedDeviceId] = deviceData;
          }
        }
      }

      final List<Map<String, dynamic>> finalDevices = [];
      for (var d in latestApiMap.values) {
        d.remove('parsed_timestamp');
        finalDevices.add(d);
      }

      // Match homepage/admin count logic: total record count from API passing topic filters (BF/, CS/)
      int rawApiCount = 0;
      for (var d in rawDashboardDevices) {
        final idTopic = d['deviceid#topic']?.toString() ?? '';
        if (idTopic.isNotEmpty) {
          final parts = idTopic.split('#');
          if (parts.length >= 2) {
            final topic = parts.sublist(1).join('#');
            if (!topic.startsWith('BF/') && !topic.startsWith('CS/')) {
              rawApiCount++;
            }
          }
        }
      }

      setState(() {
        deviceLocations = finalDevices;
        _dashboardAnnamCount = rawApiCount;
        if (searchQuery.isNotEmpty) {
          final trimmed = searchQuery.toLowerCase();
          visibleDevices = _allDevices
              .where((d) => _matchesDeviceSearch(d, trimmed))
              .toList();
        } else {
          visibleDevices = _allDevices;
        }
      });
      _saveToCache();
      _syncOneDayWeatherSnapshots();
    } catch (e) {
      _showError('Error loading devices: $e');
    }
  }

  // ── Deduplicated CloudSense/Annam Sensors ──────────────────────────────────
  List<Map<String, dynamic>> get _csDevices {
    final Map<String, Map<String, dynamic>> unique = {};

    // First, populate the base hardcoded sensors so that we don't lose them
    // just because the API doesn't know their location.
    for (var d in hardcodedSensors) {
      unique[d['deviceId']] = Map<String, dynamic>.from(d);
    }

    // Merge live API telemetry into the sensors
    for (var d in deviceLocations) {
      final id = d['deviceId'];
      if (unique.containsKey(id)) {
        // Safe Merge: Keep hardcoded coordinates, but pull in weather data!
        final existing = unique[id]!;
        d.forEach((k, v) {
          if (k == 'latitude' || k == 'longitude') {
            // Only overwrite coordinates if API gave us valid ones
            if (v != null && v != 0 && v != 0.0) {
              existing[k] = v;
            }
          } else if (k == 'state' || k == 'place' || k == 'category') {
            // Don't overwrite hardcoded location/category info with empty data
            if (v != null &&
                v.toString().trim().isNotEmpty &&
                v.toString().toLowerCase() != 'null') {
              existing[k] = v;
            }
          } else {
            existing[k] = v;
          }
        });
      } else {
        // For API sensors without a hardcoded location, only add them if they
        // actually reported a valid GPS coordinate.
        final lat = d['latitude'];
        final lon = d['longitude'];
        final bool hasValidGps = lat != null &&
            lon != null &&
            lat != 0 &&
            lon != 0 &&
            lat != 0.0 &&
            lon != 0.0;

        if (hasValidGps || DevicePrefixUtils.isAnnamTestingSensor(id)) {
          if (!hasValidGps) {
            // Fallback for TS (Testing) sensors: Rupnagar, Punjab
            d['latitude'] = 30.97;
            d['longitude'] = 76.47;
            d['place'] = 'Rupnagar';
            d['state'] = 'Punjab';
          }
          unique[id] = d;
        }
      }
    }
    return unique.values.toList();
  }

  // ── Combined list ──────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _allDevices => [
        ..._csDevices,
        ...imdLocations,
      ];

  // ── Active-device threshold: 1 hour ──────────────────────────────────────
  static const Duration _activeThreshold = Duration(hours: 1);

  /// Returns true if the device has sent data within the last 1 hour.
  bool _isActiveDevice(Map<String, dynamic> d) {
    final lastActiveStr = d['last_active']?.toString() ?? '';
    if (lastActiveStr.isEmpty || lastActiveStr == 'N/A') return false;
    final ts = parseDate(lastActiveStr);
    if (ts == null) return false;
    return DateTime.now().difference(ts) <= _activeThreshold;
  }

  // ── Helper: does a sensor have ANY valid weather data? ─────────────────────
  bool _hasAnyWeatherData(Map<String, dynamic> d) {
    const fields = ['curr_temp', 'rh', 'wind_speed', 'rainfall', 'mslp'];
    for (final f in fields) {
      final v = d[f]?.toString() ?? 'N/A';
      if (v != 'N/A' && double.tryParse(v) != null) return true;
    }
    return false;
  }

  // ── Active ANNAM devices (last seen within 1 hour) ─────────────────────────
  List<Map<String, dynamic>> get _activeAnnamDevices {
    return _csDevices
        .where((d) => d['source'] != 'IMD')
        .where(_isActiveDevice)
        .toList();
  }

  // ── ANNAM devices filtered to only those with weather data AND active today ─
  List<Map<String, dynamic>> get _annamDevicesWithData {
    return _activeAnnamDevices
        .where(_isFromToday)
        .map(_applyWeatherSnapshot)
        .where(_hasAnyWeatherData)
        .toList();
  }

  bool _isFromToday(Map<String, dynamic> d) {
    final lastActiveRaw = d['last_active']?.toString();
    final lastActive = parseDate(lastActiveRaw);
    if (lastActive == null) return false;
    final now = DateTime.now();
    return lastActive.year == now.year &&
        lastActive.month == now.month &&
        lastActive.day == now.day;
  }

  Map<String, dynamic> _applyWeatherSnapshot(Map<String, dynamic> d) {
    final id = d['deviceId']?.toString() ?? '';
    final snapshot = _weatherSnapshots[id];
    if (snapshot == null) return d;
    return {...d, ...snapshot};
  }

  String _formatMapMetric(dynamic val) {
    if (val == null) return 'N/A';
    final str = val.toString().trim();
    if (str.isEmpty || str.toLowerCase() == 'null') return 'N/A';
    final num? number = num.tryParse(str);
    if (number == null) return str;
    final rounded = double.parse(number.toStringAsFixed(4));
    if (rounded == rounded.toInt()) return rounded.toInt().toString();
    return rounded.toString();
  }

  String _formatMapWeatherMetric(dynamic val, String fieldKey) {
    final formatted = _formatMapMetric(val);
    if (formatted == 'N/A') return 'N/A';
    final number = double.tryParse(formatted);
    if (number != null && !_isPlausibleWeatherValue(fieldKey, number)) {
      return 'N/A';
    }
    return formatted;
  }

  bool _isPlausibleWeatherValue(String field, double value) {
    switch (field) {
      case 'curr_temp':
        return value >= -50 && value <= 60;
      case 'rh':
        return value >= 0 && value <= 100;
      case 'wind_speed':
        return value >= 0 && value <= 250;
      case 'mslp':
        return value >= 800 && value <= 1100;
      case 'rainfall':
        return value >= 0 && value <= 500;
      default:
        return true;
    }
  }

  DateTime _todayAtMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String? _buildGraphLikeWeatherApiUrl(Map<String, dynamic> device) {
    final deviceName = device['deviceId']?.toString() ?? '';
    if (deviceName.isEmpty) return null;

    final rawId = device['rawDeviceId']?.toString() ?? '';
    String extractedId = rawId.isNotEmpty ? rawId : deviceName;
    if (extractedId.startsWith('AWS_')) {
      extractedId = extractedId.substring(4);
    } else if (RegExp(r'^[A-Za-z]{2}').hasMatch(extractedId)) {
      extractedId = extractedId.substring(2);
    }
    if (RegExp(r'^\d+$').hasMatch(extractedId)) {
      extractedId = int.parse(extractedId).toString();
    }

    if (extractedId.isEmpty) return null;
    final String deviceIdNum =
        extractedId; // Kept variable name for minimal changes below
    final startdate = DateFormat('dd-MM-yyyy').format(_todayAtMidnight());
    final enddate = DateFormat('dd-MM-yyyy').format(_todayAtMidnight());

    String strdeviceId = deviceName.toUpperCase();
    final regExp = RegExp(r'([A-Z]\d+)$');
    final match = regExp.firstMatch(strdeviceId);
    strdeviceId = match?.group(1) ?? '';

    if (deviceName.startsWith('SM')) {
      return 'https://n42fiw7l89.execute-api.us-east-1.amazonaws.com/default/SSMet_API_Func?device_id=$deviceIdNum&start_date=$startdate&end_date=$enddate';
    } else if (deviceName.startsWith('WT')) {
      return 'https://p3jativhq1.execute-api.us-east-1.amazonaws.com/default/Weather_Sensor_Api_Function?DeviceId=$deviceIdNum&start_date=$startdate&end_date=$enddate';
    } else if (deviceName.startsWith('SW')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('WJ')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0126data?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('WF')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0226data?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('SI')) {
      return 'https://wr8ort42hi.execute-api.us-east-1.amazonaws.com/default/SSMet_Custom_API_func?deviceid=$strdeviceId&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('CF')) {
      return 'https://d3g5fo66jwc4iw.cloudfront.net/colonelfarmdata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('VD')) {
      return 'https://d3g5fo66jwc4iw.cloudfront.net/vanixdata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('PC')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/polytechnicdata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('SV')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/svpudata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('KD')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kargildata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('NA')) {
      return 'https://d3g5fo66jwc4iw.cloudfront.net/ssmetnarldata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('KJ')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kjscedata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('MY')) {
      return 'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/mysurudata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName == 'CP001' || deviceName == 'CP003') {
      final cpId = deviceName == 'CP001' ? '1' : '3';
      return 'https://d3g5fo66jwc4iw.cloudfront.net/campusdata?deviceid=$cpId&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('CP') && deviceName != 'CP001') {
      return 'https://d3dj66m23j48gu.cloudfront.net/campusdata?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('DM')) {
      return 'https://defj3npj8k.execute-api.us-east-1.amazonaws.com/default/Demo_Device_API_Function?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('IT')) {
      return 'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceId=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('FS')) {
      return 'https://d11aiifadm1oq5.cloudfront.net/default/SSMet_Forest_API_func?DeviceId=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    } else if (deviceName.startsWith('SS')) {
      return 'https://yebtmt03od.execute-api.us-east-1.amazonaws.com/default/SSMet_Soil_Api_Func?deviceid=$deviceIdNum&startdate=$startdate&enddate=$enddate';
    }
    return null;
  }

  List<Map<String, dynamic>> _extractWeatherRecords(dynamic payload) {
    dynamic candidate = payload;
    if (candidate is Map && candidate['body'] is String) {
      try {
        candidate = json.decode(candidate['body'] as String);
      } catch (_) {}
    }
    if (candidate is List) {
      return candidate
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (candidate is! Map) return <Map<String, dynamic>>[];
    const listKeys = ['items', 'weather_items', 'data', 'records', 'result'];
    for (final key in listKeys) {
      final value = candidate[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return <Map<String, dynamic>>[];
  }

  DateTime? _recordTimestamp(Map<String, dynamic> record) {
    const keys = [
      'TimeStamp_IST',
      'TimeStamp',
      'timestamp',
      'DateTime',
      'DATE',
      'date',
    ];
    for (final key in keys) {
      final value = record[key];
      if (value == null) continue;
      final parsed = parseDate(value.toString());
      if (parsed != null) return parsed;
    }
    return null;
  }

  /// Rainfall scalar only (for map); does not affect temp/humidity/wind/pressure.
  String _selectRainfallMetricFromRecord(
      String prefix, Map<String, dynamic> item) {
    final hourlyVal = HomeUtils.getCorrectedValue(item, ['rainfallhourly', 'RainfallHourly']) ?? item['RainfallHourly'];
    final hourly = _formatMapWeatherMetric(hourlyVal, 'rainfall');

    final hourlyCumVal = HomeUtils.getCorrectedValue(item, ['rainfallhourlycomulative', 'RainfallHourlyComulative']) ?? item['RainfallHourlyComulative'];
    final hourlyCumulative = _formatMapWeatherMetric(hourlyCumVal, 'rainfall');

    final dailyVal = HomeUtils.getCorrectedValue(item, ['rainfalldaily', 'RainfallDaily']) ?? item['RainfallDaily'];
    final daily = _formatMapWeatherMetric(dailyVal, 'rainfall');

    final dailyCumVal = HomeUtils.getCorrectedValue(item, ['rainfalldailycomulative', 'RainfallDailyComulative', 'rainfall_cumulative', 'Rainfall_Cumulative']) ?? item['RainfallDailyComulative'];
    final dailyCumulative = _formatMapWeatherMetric(dailyCumVal, 'rainfall');

    bool isPositive(String v) => v != 'N/A' && (double.tryParse(v) ?? 0) > 0;

    String prefer(String primary, [String? fallback]) {
      if (isPositive(primary)) return primary;
      if (fallback != null && isPositive(fallback)) return fallback;
      if (primary != 'N/A') return primary;
      if (fallback != null && fallback != 'N/A') return fallback;
      return 'N/A';
    }

    switch (prefix) {
      case 'CP':
        if (hourly != 'N/A') return hourly;
        return daily != 'N/A' ? daily : 'N/A';
      case 'SV':
      case 'VD':
        return prefer(hourlyCumulative, hourly);
      case 'NA':
      case 'SS':
        return prefer(daily, hourly);
      case 'SM':
        return prefer(dailyCumulative, hourly);
      default:
        return hourly;
    }
  }

  Future<Map<String, dynamic>?> _fetchOneDayWeatherSnapshot(
      Map<String, dynamic> device) async {
    final url = _buildGraphLikeWeatherApiUrl(device);
    if (url == null) return null;
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) return null;
      final dynamic decoded = json.decode(response.body);
      final records = _extractWeatherRecords(decoded);
      if (records.isEmpty) return null;

      Map<String, dynamic>? latestRecord;
      DateTime? latestTimestamp;
      for (final record in records) {
        final timestamp = _recordTimestamp(record);
        if (timestamp == null) continue;
        if (latestTimestamp == null || timestamp.isAfter(latestTimestamp)) {
          latestTimestamp = timestamp;
          latestRecord = record;
        }
      }
      latestRecord ??= records.last;
      final prefixMatch = RegExp(r'^[A-Za-z]+')
          .firstMatch(device['deviceId']?.toString() ?? '');
      final prefix = (prefixMatch?.group(0) ?? '').toUpperCase();

      return {
        'curr_temp': _formatMapWeatherMetric(
            latestRecord['CorrectedTemp'] ??
                latestRecord['correctedtemp'] ??
                latestRecord['CorrectedTemperature'] ??
                latestRecord['correctedtemperature'] ??
                latestRecord['CurrentTemperature'] ??
                latestRecord['currenttemperature'] ??
                latestRecord['AirTemperature'],
            'curr_temp'),
        'rh': _formatMapWeatherMetric(
            latestRecord['CorrectedHumidity'] ??
                latestRecord['correctedhumidity'] ??
                latestRecord['CurrentHumidity'] ??
                latestRecord['currenthumidity'] ??
                latestRecord['AirHumidity'],
            'rh'),
        'wind_speed':
            _formatMapWeatherMetric(latestRecord['WindSpeed'], 'wind_speed'),
        'wind_dir': _formatMapMetric(
            latestRecord['WindDirection'] ?? latestRecord['WindDir']),
        'rainfall': _selectRainfallMetricFromRecord(prefix, latestRecord),
        'mslp': _formatMapWeatherMetric(
            latestRecord['CurrentPressure'] ??
                latestRecord['AtmPressure'] ??
                latestRecord['BME680_Pressure'],
            'mslp'),
        'last_active':
            latestTimestamp?.toString() ?? device['last_active']?.toString(),
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _syncOneDayWeatherSnapshots({bool force = false}) async {
    if (_currentSection != MapSection.annamWeather ||
        _selectedLayer == WeatherLayer.clusters) {
      return;
    }
    if (_isWeatherSnapshotSyncing) return;
    if (!force &&
        _lastWeatherSnapshotSyncAt != null &&
        DateTime.now().difference(_lastWeatherSnapshotSyncAt!) <
            _weatherSnapshotTtl) {
      return;
    }
    final activeTodayDevices = _activeAnnamDevices.where(_isFromToday).toList();
    if (activeTodayDevices.isEmpty) return;

    _isWeatherSnapshotSyncing = true;
    try {
      final snapshots = await Future.wait(
          activeTodayDevices.map(_fetchOneDayWeatherSnapshot));
      if (!mounted) return;

      final Map<String, Map<String, dynamic>> nextSnapshots = {};
      for (int i = 0; i < activeTodayDevices.length; i++) {
        final deviceId = activeTodayDevices[i]['deviceId']?.toString() ?? '';
        final snapshot = snapshots[i];
        if (deviceId.isEmpty || snapshot == null) continue;
        nextSnapshots[deviceId] = snapshot;
      }
      setState(() {
        _weatherSnapshots.addAll(nextSnapshots);
      });
      _lastWeatherSnapshotSyncAt = DateTime.now();
    } finally {
      _isWeatherSnapshotSyncing = false;
    }
  }

  // ── ANNAM count aligned to dashboard semantics (live API-backed sensors) ──
  int get _dashboardAlignedAnnamCount {
    return _dashboardAnnamCount;
  }

  // ── Cluster builders (SOURCE-SEPARATED) ───────────────────────────────────

  double? _parseWeatherValue(String? valueStr) {
    if (valueStr == null || valueStr == 'N/A' || valueStr.isEmpty) return null;
    return double.tryParse(valueStr);
  }

  String _getMetricKey(String metric) {
    switch (metric) {
      case 'Temperature':
        return 'curr_temp';
      case 'Humidity':
        return 'rh';
      case 'Wind':
        return 'wind_speed';
      case 'Rainfall':
        return 'rainfall';
      case 'Pressure':
        return 'mslp';
      default:
        return '';
    }
  }



  Map<String, dynamic> _buildStateClusters(List<Map<String, dynamic>> source) {
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (var d in source) {
      groups.putIfAbsent(d['state'] ?? 'Unknown', () => []).add(d);
    }
    final Map<String, dynamic> clusters = {};
    final mk = _getMetricKey(selectedWeatherMetric);
    groups.forEach((state, devices) {
      if (devices.isEmpty) return;
      final avgLat =
          devices.map((d) => d['latitude'] as double).reduce((a, b) => a + b) /
              devices.length;
      final avgLon =
          devices.map((d) => d['longitude'] as double).reduce((a, b) => a + b) /
              devices.length;

      double? avgWeather;
      if (mk.isNotEmpty) {
        final withData = devices
            .map((d) => _parseWeatherValue(d[mk]?.toString()))
            .where((v) => v != null)
            .cast<double>()
            .toList();
        if (withData.isNotEmpty) {
          avgWeather = withData.reduce((a, b) => a + b) / withData.length;
        }
      }

      clusters[state] = {
        'count': devices.length,
        'latitude': avgLat,
        'longitude': avgLon,
        'devices': devices,
        'avgWeather': avgWeather
      };
    });
    return clusters;
  }

  Map<String, dynamic> _buildDistrictClusters(
      List<Map<String, dynamic>> source) {
    final Map<String, Map<String, List<Map<String, dynamic>>>> groups = {};
    for (var d in source) {
      groups
          .putIfAbsent(d['state'] ?? 'Unknown', () => {})
          .putIfAbsent(d['place'] ?? 'Unknown', () => [])
          .add(d);
    }
    final Map<String, dynamic> clusters = {};
    groups.forEach((state, districtMap) {
      districtMap.forEach((district, devices) {
        if (devices.isEmpty) return;
        final avgLat = devices
                .map((d) => d['latitude'] as double)
                .reduce((a, b) => a + b) /
            devices.length;
        final avgLon = devices
                .map((d) => d['longitude'] as double)
                .reduce((a, b) => a + b) /
            devices.length;
        clusters['$state||$district'] = {
          'state': state,
          'district': district,
          'count': devices.length,
          'latitude': avgLat,
          'longitude': avgLon,
          'devices': devices,
        };
      });
    });
    return clusters;
  }

  Map<String, dynamic> get _csStateClusters {
    if (_currentSection == MapSection.annamWeather &&
        _selectedLayer != WeatherLayer.clusters) {
      return _buildStateClusters(_annamDevicesWithData);
    }
    return _buildStateClusters(_csDevices);
  }

  Map<String, dynamic> get _csDistrictClusters {
    if (_currentSection == MapSection.annamWeather &&
        _selectedLayer != WeatherLayer.clusters) {
      return _buildDistrictClusters(_annamDevicesWithData);
    }
    return _buildDistrictClusters(_csDevices);
  }

  Map<String, dynamic> get _imdStateClusters =>
      _buildStateClusters(imdLocations);
  Map<String, dynamic> get _imdDistrictClusters =>
      _buildDistrictClusters(imdLocations);

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime? parseDate(String? dateStr) => DevicePrefixUtils.parseDate(dateStr);

  void _showError(String message) {
    if (!mounted) return;
    // Suppressed from UI as per user request:
    print('Error: $message');
  }

  // ── Shared list-item widget ────────────────────────────────────────────────
  Widget _deviceListItem(Map<String, dynamic> device, {VoidCallback? onTap}) {
    final bool isImd = device['source'] == 'IMD';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: onTap != null
              ? Border.all(color: Colors.white12, width: 1)
              : null,
        ),
        child: Row(
          children: [
            if (isImd)
              const SizedBox(width: 18, height: 18, child: _ImdMarker())
            else
              const SizedBox(width: 18, height: 18, child: _AnnamAiMarker()),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_toAnnamDisplayName(device['deviceId']),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                      ),
                      if (isImd)
                        _sourceBadge('IMD', _kImdOrange,
                            const Color(0xFFFFAB76), const Color(0xFFFFD5B0)),
                      const SizedBox(width: 4),
                      const Icon(Icons.my_location,
                          size: 13, color: Colors.white38),
                    ],
                  ),
                  Text(
                    {
                      if (device['place'] != null &&
                          device['place'].toString().isNotEmpty)
                        device['place'],
                      if (device['district'] != null &&
                          device['district'].toString().isNotEmpty)
                        device['district'],
                      if (device['state'] != null &&
                          device['state'].toString().isNotEmpty)
                        device['state'],
                    }.where((e) => e != null).join(', '),
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceBadge(String label, Color bg, Color border, Color text) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bg.withOpacity(0.25),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: border, width: 1),
        ),
        child: Text(label, style: TextStyle(color: text, fontSize: 10)),
      );

  // ── Glass dialog helper ────────────────────────────────────────────────────
  Widget _glassDialog({required Widget child, double width = 350}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: width,
            constraints: const BoxConstraints(maxHeight: 500),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _showDistrictDialog(
      BuildContext context, Map<String, dynamic> clusterData) {
    final state = clusterData['state'];
    final district = clusterData['district'];
    final devices = clusterData['devices'] as List<Map<String, dynamic>>;
    final count = clusterData['count'];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$district, $state',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total: $count',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (_, i) => _deviceListItem(devices[i], onTap: () {
                  Navigator.pop(context);
                  final lat = (devices[i]['latitude'] as num).toDouble();
                  final lon = (devices[i]['longitude'] as num).toDouble();
                  setState(() {
                    centerCoordinates = LatLng(lat, lon);
                    zoomLevel = 14.0;
                  });
                  mapController.move(LatLng(lat, lon), 14.0);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted) _showDeviceInfoDialog(context, devices[i]);
                  });
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  child: Text('Zoom to Area',
                      style: TextStyle(color: Colors.blue[300])),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      centerCoordinates = LatLng(
                          clusterData['latitude'], clusterData['longitude']);
                      zoomLevel = 11.0;
                    });
                    mapController.move(centerCoordinates, zoomLevel);
                  },
                ),
                TextButton(
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showClusterDialog(
      BuildContext context, String state, Map<String, dynamic> clusterData) {
    final devices = clusterData['devices'] as List<Map<String, dynamic>>;
    final count = clusterData['count'];

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(state,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total: $count',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 12),
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (_, i) => _deviceListItem(devices[i], onTap: () {
                  Navigator.pop(context);
                  final lat = (devices[i]['latitude'] as num).toDouble();
                  final lon = (devices[i]['longitude'] as num).toDouble();
                  setState(() {
                    centerCoordinates = LatLng(lat, lon);
                    zoomLevel = 14.0;
                  });
                  mapController.move(LatLng(lat, lon), 14.0);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted) _showDeviceInfoDialog(context, devices[i]);
                  });
                }),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  child: Text('Zoom to Area',
                      style: TextStyle(color: Colors.blue[300])),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      centerCoordinates = LatLng(
                          clusterData['latitude'], clusterData['longitude']);
                      zoomLevel = 8.0;
                    });
                    mapController.move(centerCoordinates, zoomLevel);
                  },
                ),
                TextButton(
                  child: const Text('Close',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Unified device info dispatcher ─────────────────────────────────────────
  void _showDeviceInfoDialog(
      BuildContext context, Map<String, dynamic> device) {
    if (device['source'] == 'IMD') {
      _showImdDeviceInfoDialog(context, device);
    } else {
      _showCloudSenseDeviceInfoDialog(context, device);
    }
  }

  void _showImdDeviceInfoDialog(
      BuildContext context, Map<String, dynamic> device) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        width: 320,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const SizedBox(width: 18, height: 18, child: _ImdMarker()),
              const SizedBox(width: 8),
              Expanded(
                child: Text('IMD: ${device['deviceId']}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
              _sourceBadge('IMD', _kImdOrange, const Color(0xFFFFAB76),
                  const Color(0xFFFFD5B0)),
            ]),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 6),
            _imdRow(Icons.location_city, 'Station', device['station'] ?? 'N/A'),
            _imdRow(Icons.place, 'Location',
                '${device['place']}, ${device['state']}'),
            _imdRow(Icons.my_location, 'Lat / Lon',
                '${device['latitude']}, ${device['longitude']}'),
            Align(
              alignment: Alignment.bottomRight,
              child: TextButton(
                child:
                    const Text('Close', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imdRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: const Color(0xFFFFD5B0)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  void _showCloudSenseDeviceInfoDialog(
      BuildContext context, Map<String, dynamic> device) {
    final topic = device['topic']?.toString() ?? '';
    final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const SizedBox(width: 18, height: 18, child: _AnnamAiMarker()),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Device ${_toAnnamDisplayName(device['deviceId'])}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Latitude: ${device['latitude']}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text('Longitude: ${device['longitude']}',
                style: const TextStyle(color: Colors.white, fontSize: 13)),
            Text(
              'Location: ' +
                  {
                    if (device['city'] != null &&
                        device['city'].toString().isNotEmpty)
                      device['city'],
                    if (device['district'] != null &&
                        device['district'].toString().isNotEmpty)
                      device['district'],
                    if (device['state'] != null &&
                        device['state'].toString().isNotEmpty)
                      device['state'],
                  }
                      .where((e) => e != null && e.toString().isNotEmpty)
                      .join(', '),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Builder(builder: (dialogContext) {
              final userEmail =
                  Provider.of<UserProvider>(dialogContext, listen: false)
                      .userEmail
                      ?.trim()
                      .toLowerCase();
              final isAdmin = DeviceUtils.adminEmails.contains(userEmail);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isAdmin)
                    TextButton.icon(
                      icon: const Icon(Icons.show_chart,
                          color: Colors.greenAccent, size: 18),
                      label: const Text('View Graph',
                          style: TextStyle(color: Colors.greenAccent)),
                      onPressed: () {
                        Navigator.pop(context);
                        NavigationUtils.navigateTo(
                          context,
                          isAdmin ? '/admin/devicegraph' : '/devicegraph',
                          arguments: {
                            'deviceName': device['deviceId'],
                            'sequentialName': mapped.category,
                            'backgroundImagePath': 'assets/backgroundd.jpg',
                          },
                        );
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton(
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Geocoding & search ─────────────────────────────────────────────────────
  Future<void> _geocode(String query) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json';
      final response = await http.get(Uri.parse(url),
          headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          final coords = LatLng(lat, lon);
          setState(() {
            centerCoordinates = coords;
            zoomLevel = 10.0;
            searchPin = Marker(
              width: 80,
              height: 80,
              point: coords,
              child: GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Searched Location'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Location: $query'),
                        Text('Latitude: $lat'),
                        Text('Longitude: $lon'),
                      ],
                    ),
                    actions: [
                      TextButton(
                          child: const Text('Close'),
                          onPressed: () => Navigator.pop(context))
                    ],
                  ),
                ),
                child: const Icon(Icons.location_pin,
                    size: 20, color: Colors.blue),
              ),
            );
          });
          mapController.move(coords, zoomLevel);
        } else {
          _showError("No results found for '$query'.");
        }
      }
    } catch (e) {
      _showError('Error during geocoding: $e');
    }
  }

  /// Same filtering as `origin/main` (GitHub): internal id, display name, place, state, country, category, station.
  bool _matchesDeviceSearch(Map<String, dynamic> d, String queryLower) {
    final internalId = d['deviceId']?.toString().toLowerCase() ?? '';
    final displayName =
        _toAnnamDisplayName(d['deviceId']?.toString() ?? '').toLowerCase();
    return internalId.contains(queryLower) ||
        displayName.contains(queryLower) ||
        (d['place']?.toString().toLowerCase().contains(queryLower) ?? false) ||
        (d['state']?.toString().toLowerCase().contains(queryLower) ?? false) ||
        (d['country']?.toString().toLowerCase().contains(queryLower) ??
            false) ||
        (d['category']?.toString().toLowerCase().contains(queryLower) ??
            false) ||
        (d['station']?.toString().toLowerCase().contains(queryLower) ?? false);
  }

  void _searchDevices(String query) async {
    final trimmed = query.trim().toLowerCase();
    setState(() => searchQuery = trimmed);

    if (trimmed.isEmpty) {
      setState(() {
        visibleDevices = _allDevices;
        centerCoordinates = LatLng(22.9734, 78.6569);
        zoomLevel = 5.5;
        searchPin = null;
        suggestions = [];
      });
      mapController.move(centerCoordinates, zoomLevel);
      return;
    }

    final filtered =
        _allDevices.where((d) => _matchesDeviceSearch(d, trimmed)).toList();

    if (filtered.isNotEmpty) {
      setState(() {
        visibleDevices = filtered;
        searchPin = null;
        centerCoordinates =
            LatLng(filtered.first['latitude'], filtered.first['longitude']);
        zoomLevel = 12.0;
      });
      mapController.move(centerCoordinates, zoomLevel);
    } else {
      setState(() {
        visibleDevices = [];
        searchPin = null;
      });
      await _geocode(query);
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
        searchPin = null;
      });
      return;
    }
    final ql = query.toLowerCase();
    setState(() {
      suggestions =
          _allDevices.where((d) => _matchesDeviceSearch(d, ql)).toList();
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    final displayName =
        _toAnnamDisplayName(suggestion['deviceId']?.toString() ?? '');
    _searchController.text = displayName;
    _searchDevices(displayName);
    setState(() => suggestions = []);
  }

  // ── Map tile layers ────────────────────────────────────────────────────────
  // Original Esri World Imagery satellite tiles
  TileLayer _getSatelliteTileLayer() => TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.CloudSenseVis',
        tileProvider: NetworkTileProvider(),
      );

  TileLayer _getLabelOverlayLayer() => TileLayer(
        urlTemplate:
            'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.CloudSenseVis',
        tileProvider: NetworkTileProvider(),
      );

  void _reloadDevices() async {
    _memCachedDevices = null;
    _memCachedImd = null;
    _memCachedDashboardAnnamCount = null;
    _memCacheTimestamp = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDevices);
    await prefs.remove(_keyImd);
    await prefs.remove(_keyDashboardAnnamCount);
    await prefs.remove(_keyTimestamp);

    setState(() {
      deviceLocations = [];
      imdLocations = [];
      _dashboardAnnamCount = 0;
      visibleDevices = hardcodedSensors.toList();
      centerCoordinates = LatLng(22.9734, 78.6569);
      zoomLevel = 5.5;
      searchPin = null;
      suggestions = [];
    });
    _searchController.clear();
    _loadAllData();
    mapController.move(centerCoordinates, zoomLevel);
  }

  // ── Marker list builders ───────────────────────────────────────────────────
  // ANNAM.AI: green (_kAnnamGreen) at every zoom level
  // IMD: orange (_kImdOrange) at every zoom level

  List<Marker> _buildCsStateMarkers() {
    final isWeather = _currentSection == MapSection.annamWeather &&
        _selectedLayer != WeatherLayer.clusters;
    final field = isWeather ? _fieldForLayer(_selectedLayer) : '';
    final unit = isWeather ? _unitForLayer(_selectedLayer) : '';

    return _csStateClusters.entries
        .map((e) {
          final cd = e.value;
          final devices = cd['devices'] as List<Map<String, dynamic>>;

          if (isWeather) {
            // Compute average from individual sensor values, applying sanity filter
            final values = devices
                .map((d) => double.tryParse(d[field]?.toString() ?? ''))
                .where((v) => v != null && _isPlausibleWeatherValue(field, v))
                .cast<double>()
                .toList();
            if (values.isEmpty) {
              // No valid data for this layer → skip (return invisible marker)
              return null;
            }
            final avg = values.reduce((a, b) => a + b) / values.length;
            final color = _colorForLayer(_selectedLayer, avg);
            return Marker(
              point: LatLng(cd['latitude'], cd['longitude']),
              width: 60,
              height: 60,
              child: GestureDetector(
                onTap: () => _showClusterDialog(context, e.key, cd),
                child: _WeatherValueMarker(
                  displayValue: _formatMarkerValue(_selectedLayer, avg),
                  unit: unit,
                  bgColor: color,
                  pulseAnim: _pulseAnim,
                ),
              ),
            );
          } else {
            // Sensor Clusters mode → show count
            return Marker(
              point: LatLng(cd['latitude'], cd['longitude']),
              width: 80,
              height: 80,
              child: GestureDetector(
                onTap: () => _showClusterDialog(context, e.key, cd),
                child: _ClusterBubble(
                    count: cd['count'],
                    color: _kAnnamGreen,
                    size: 44,
                    topIcon: Icons.sensors,
                    pulseAnim: _pulseAnim),
              ),
            );
          }
        })
        .where((m) => m != null)
        .cast<Marker>()
        .toList();
  }

  List<Marker> _buildImdStateMarkers() => _imdStateClusters.entries.map((e) {
        final cd = e.value;
        return Marker(
          point: LatLng(cd['latitude'], cd['longitude']),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showClusterDialog(context, e.key, cd),
            child: _ClusterBubble(
                count: cd['count'],
                color: _kImdOrange,
                size: 44,
                topIcon: Icons.wb_sunny,
                pulseAnim: _pulseAnim),
          ),
        );
      }).toList();

  List<Marker> _buildCsDistrictMarkers() =>
      _csDistrictClusters.entries.map((e) {
        final cd = e.value;
        return Marker(
          point: LatLng(cd['latitude'], cd['longitude']),
          width: 68,
          height: 68,
          child: GestureDetector(
            onTap: () => _showDistrictDialog(context, cd),
            child: _ClusterBubble(
                count: cd['count'],
                color: _kAnnamGreen,
                size: 36,
                pulseAnim: _pulseAnim),
          ),
        );
      }).toList();

  List<Marker> _buildImdDistrictMarkers() =>
      _imdDistrictClusters.entries.map((e) {
        final cd = e.value;
        return Marker(
          point: LatLng(cd['latitude'], cd['longitude']),
          width: 68,
          height: 68,
          child: GestureDetector(
            onTap: () => _showDistrictDialog(context, cd),
            child: _ClusterBubble(
                count: cd['count'],
                color: _kImdOrange,
                size: 36,
                topIcon: Icons.wb_sunny,
                pulseAnim: _pulseAnim),
          ),
        );
      }).toList();

  // CS individual markers (CloudSense + Aurassure) — always green
  List<Marker> _buildCsIndividualMarkers() =>
      visibleDevices.where((d) => d['source'] == 'CloudSense').map((device) {
        return Marker(
          point: LatLng((device['latitude'] as num).toDouble(),
              (device['longitude'] as num).toDouble()),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showCloudSenseDeviceInfoDialog(context, device),
            child: _AnnamAiMarker(pulseAnim: _pulseAnim),
          ),
        );
      }).toList();

  // IMD individual markers — always orange
  List<Marker> _buildImdIndividualMarkers() =>
      visibleDevices.where((d) => d['source'] == 'IMD').map((device) {
        return Marker(
          point: LatLng((device['latitude'] as num).toDouble(),
              (device['longitude'] as num).toDouble()),
          width: 60,
          height: 60,
          child: GestureDetector(
            onTap: () => _showImdDeviceInfoDialog(context, device),
            child: _ImdMarker(pulseAnim: _pulseAnim),
          ),
        );
      }).toList();



  // ── Weather-layer district cluster markers (mid zoom) ───────────────────

  // ── ANNAM-only weather markers (individual — high zoom) ─────────────────
  List<Marker> _buildAnnamWeatherMarkers() {
    final field = _fieldForLayer(_selectedLayer);
    final unit = _unitForLayer(_selectedLayer);
    // Filter devices strictly to those that have data for the specific chosen layer
    final devicesForLayer = _annamDevicesWithData.where((d) {
      final rawVal = d[field]?.toString() ?? 'N/A';
      final v = double.tryParse(rawVal);
      return v != null && _isPlausibleWeatherValue(field, v);
    }).toList();

    return devicesForLayer
        .map((device) {
          final rawVal = device[field]?.toString() ?? 'N/A';
          final numVal = double.tryParse(rawVal);
          // numVal is guaranteed not null due to above filter, but safe unwrap
          if (numVal == null) return null;

          final point = LatLng((device['latitude'] as num).toDouble(),
              (device['longitude'] as num).toDouble());

          // Valid data → show weather value bubble
          return Marker(
            point: point,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showWeatherTooltipDialog(context, device),
              child: _WeatherValueMarker(
                displayValue: _formatMarkerValue(_selectedLayer, numVal),
                unit: unit,
                bgColor: _colorForLayer(_selectedLayer, numVal),
                pulseAnim: _pulseAnim,
              ),
            ),
          );
        })
        .where((m) => m != null)
        .cast<Marker>()
        .toList();
  }

  // ── ANNAM-only weather state clusters (low zoom) ────────────────────────
  List<Marker> _buildAnnamWeatherStateClusters() {
    final field = _fieldForLayer(_selectedLayer);
    final unit = _unitForLayer(_selectedLayer);
    // Build clusters only from sensors with valid data for this layer
    final devicesForLayer = _annamDevicesWithData.where((d) {
      final rawVal = d[field]?.toString() ?? 'N/A';
      final v = double.tryParse(rawVal);
      return v != null && _isPlausibleWeatherValue(field, v);
    }).toList();
    final clusters = _buildStateClusters(devicesForLayer);

    return clusters.entries
        .map((e) {
          final cd = e.value;
          final devices = cd['devices'] as List<Map<String, dynamic>>;
          final values = devices
              .map((d) => double.tryParse(d[field]?.toString() ?? ''))
              .where((v) => v != null && _isPlausibleWeatherValue(field, v!))
              .cast<double>()
              .toList();

          if (values.isEmpty) return null; // Safe fallback

          final point = LatLng(cd['latitude'], cd['longitude']);

          final avg = values.reduce((a, b) => a + b) / values.length;
          return Marker(
            point: point,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showClusterWeatherTooltip(context, e.key, devices),
              child: _WeatherValueMarker(
                displayValue: _formatMarkerValue(_selectedLayer, avg),
                unit: unit,
                bgColor: _colorForLayer(_selectedLayer, avg),
                pulseAnim: _pulseAnim,
              ),
            ),
          );
        })
        .where((m) => m != null)
        .cast<Marker>()
        .toList();
  }

  // ── ANNAM-only weather district clusters (mid zoom) ─────────────────────
  List<Marker> _buildAnnamWeatherDistrictClusters() {
    final field = _fieldForLayer(_selectedLayer);
    final unit = _unitForLayer(_selectedLayer);
    // Build clusters only from sensors with valid data for this layer
    final devicesForLayer = _annamDevicesWithData.where((d) {
      final rawVal = d[field]?.toString() ?? 'N/A';
      final v = double.tryParse(rawVal);
      return v != null && _isPlausibleWeatherValue(field, v);
    }).toList();
    final clusters = _buildDistrictClusters(devicesForLayer);

    return clusters.entries
        .map((e) {
          final cd = e.value;
          final devices = cd['devices'] as List<Map<String, dynamic>>;
          final values = devices
              .map((d) => double.tryParse(d[field]?.toString() ?? ''))
              .where((v) => v != null && _isPlausibleWeatherValue(field, v!))
              .cast<double>()
              .toList();

          if (values.isEmpty) return null; // Safe fallback

          final point = LatLng(cd['latitude'], cd['longitude']);

          final avg = values.reduce((a, b) => a + b) / values.length;
          return Marker(
            point: point,
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () {
                final label = cd['district'] != null
                    ? '${cd['district']}, ${cd['state']}'
                    : e.key;
                _showClusterWeatherTooltip(context, label, devices);
              },
              child: _WeatherValueMarker(
                displayValue: _formatMarkerValue(_selectedLayer, avg),
                unit: unit,
                bgColor: _colorForLayer(_selectedLayer, avg),
                pulseAnim: _pulseAnim,
              ),
            ),
          );
        })
        .where((m) => m != null)
        .cast<Marker>()
        .toList();
  }

  // ── Weather tooltip for clusters (shows averaged data) ──────────────────
  void _showClusterWeatherTooltip(BuildContext context, String heading,
      List<Map<String, dynamic>> devices) {
    double _avg(String field) {
      final vals = devices
          .map((d) => double.tryParse(d[field]?.toString() ?? ''))
          .where((v) => v != null && _isPlausibleWeatherValue(field, v!))
          .cast<double>()
          .toList();
      if (vals.isEmpty) return double.nan;
      return vals.reduce((a, b) => a + b) / vals.length;
    }

    String _fmt(double v) => v.isNaN ? 'N/A' : v.toStringAsFixed(1);

    final temp = _avg('curr_temp');
    final rh = _avg('rh');
    final wind = _avg('wind_speed');
    final rainfall = _avg('rainfall');
    final pressure = _avg('mslp');

    Widget _row(String label, String value, Color valueColor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heading,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            Text('${devices.length} sensors (avg)',
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
            const SizedBox(height: 4),
            Text(
                devices
                    .map((d) =>
                        _toAnnamDisplayName(d['deviceId']?.toString() ?? ''))
                    .where((id) => id.isNotEmpty)
                    .join(', '),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            _row('Temperature', '${_fmt(temp)}°C',
                _tempColor(temp.isNaN ? 25 : temp)),
            _row(
                'Humidity', '${_fmt(rh)}%', _humidityColor(rh.isNaN ? 50 : rh)),
            _row(
                'Wind', '${_fmt(wind)} m/s', _windColor(wind.isNaN ? 0 : wind)),
            _row('Rainfall', '${_fmt(rainfall)} mm',
                _rainfallColor(rainfall.isNaN ? 0 : rainfall)),
            _row('Pressure', '${_fmt(pressure)} hPa',
                _pressureColor(pressure.isNaN ? 1013 : pressure)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                child:
                    const Text('Close', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Weather tooltip popup ──────────────────────────────────────────────────
  void _showWeatherTooltipDialog(
      BuildContext context, Map<String, dynamic> device) {
    final station = device['station']?.toString() ?? '';
    final city = device['city']?.toString() ?? '';
    final district = device['district']?.toString() ?? '';
    final state = device['state']?.toString() ?? '';
    final locationParts = {
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (state.isNotEmpty) state,
    };
    final heading = station.isNotEmpty
        ? station
        : (locationParts.isNotEmpty
            ? locationParts.join(', ')
            : _toAnnamDisplayName(device['deviceId'] ?? 'IMD'));

    Widget _weatherRow(String label, String value, Color valueColor) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text(value,
                style: TextStyle(
                    color: valueColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    final temp = device['curr_temp']?.toString() ?? 'N/A';
    final rh = device['rh']?.toString() ?? 'N/A';
    final wind = device['wind_speed']?.toString() ?? 'N/A';
    final windDir = device['wind_dir']?.toString() ?? 'N/A';
    final rainfall = device['rainfall']?.toString() ?? 'N/A';
    final pressure = device['mslp']?.toString() ?? 'N/A';
    final region = {
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (state.isNotEmpty) state,
    }.join(', ');

    // Build wind display with direction if available
    final windDisplay = (windDir != 'N/A' && windDir != 'null' && wind != 'N/A')
        ? '$wind m/s, $windDir°'
        : '$wind m/s';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (_) => _glassDialog(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heading,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('ID: ${_toAnnamDisplayName(device['deviceId'] ?? 'N/A')}',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            _weatherRow('Temperature', '$temp°C',
                _tempColor(double.tryParse(temp) ?? 25)),
            _weatherRow(
                'Humidity', '$rh%', _humidityColor(double.tryParse(rh) ?? 50)),
            _weatherRow(
                'Wind', windDisplay, _windColor(double.tryParse(wind) ?? 0)),
            _weatherRow('Rainfall', '$rainfall mm',
                _rainfallColor(double.tryParse(rainfall) ?? 0)),
            _weatherRow('Pressure', '$pressure hPa',
                _pressureColor(double.tryParse(pressure) ?? 1013)),
            const SizedBox(height: 8),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Region',
                    style:
                        const TextStyle(color: Colors.white38, fontSize: 11)),
                Flexible(
                  child: Text(region,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(builder: (dialogContext) {
              final userEmail =
                  Provider.of<UserProvider>(dialogContext, listen: false)
                      .userEmail
                      ?.trim()
                      .toLowerCase();
              final isAdmin = DeviceUtils.adminEmails.contains(userEmail);
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isAdmin && device['source'] != 'IMD')
                    TextButton.icon(
                      icon: const Icon(Icons.show_chart,
                          color: Colors.greenAccent, size: 18),
                      label: const Text('View Graph',
                          style: TextStyle(color: Colors.greenAccent)),
                      onPressed: () {
                        Navigator.pop(context);
                        final topic = device['topic']?.toString() ?? '';
                        final mapped =
                            DevicePrefixUtils.mapCategoryAndPrefix(topic);
                        NavigationUtils.navigateTo(
                          context,
                          isAdmin ? '/admin/devicegraph' : '/devicegraph',
                          arguments: {
                            'deviceName': device['deviceId'],
                            'sequentialName': mapped.category,
                            'backgroundImagePath': 'assets/backgroundd.jpg',
                          },
                        );
                      },
                    )
                  else
                    const SizedBox.shrink(),
                  TextButton(
                    child: const Text('Close',
                        style: TextStyle(color: Colors.white)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Section toggle widget ───────────────────────────────────────────────────
  String _sectionLabel(MapSection section, {bool compact = false}) {
    if (!compact) {
      return section == MapSection.annamWeather
          ? 'ANNAM.AI sensors'
          : 'ANNAM+IMD Sensors';
    }

    return section == MapSection.annamWeather ? 'Sensors' : 'Both';
  }

  String _layerLabel(WeatherLayer layer, {bool compact = false}) {
    if (!compact) return _layerLabels[layer] ?? '';

    switch (layer) {
      case WeatherLayer.clusters:
        return 'Clusters';
      case WeatherLayer.temperature:
        return 'Temp';
      case WeatherLayer.humidity:
        return 'Humidity';
      case WeatherLayer.wind:
        return 'Wind';
      case WeatherLayer.rainfall:
        return 'Rain';
      case WeatherLayer.pressure:
        return 'Pressure';
    }
  }

  Widget _buildSectionToggle({bool isMobile = false}) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isNarrow = isMobile && screenWidth <= 380;

    Widget _tab(MapSection section, String label, IconData icon) {
      final isSelected = _currentSection == section;

      Widget labelWidget = Text(
        label,
        maxLines: 1,
        overflow: isNarrow ? TextOverflow.visible : TextOverflow.ellipsis,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: isMobile ? 10 : 12.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: 0.3,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 4),
          ],
        ),
      );

      return TextButton.icon(
        onPressed: () {
          setState(() {
            _currentSection = section;
            if (section == MapSection.allSensors) {
              _selectedLayer = WeatherLayer.clusters;
            }
          });
          _syncOneDayWeatherSnapshots(force: true);
        },
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor:
              isSelected ? Colors.white.withOpacity(0.22) : Colors.transparent,
          padding: EdgeInsets.symmetric(
            vertical: isMobile ? 7 : 10,
            horizontal: isMobile ? 10 : 18,
          ),
          minimumSize: Size(0, isMobile ? 36 : 42),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? const BorderSide(color: Colors.white38, width: 1)
                : BorderSide.none,
          ),
        ),
        icon: Icon(icon,
            size: isMobile ? 14 : 15,
            color: isSelected ? Colors.white : Colors.white60,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 3),
            ]),
        label: isNarrow
            ? FittedBox(fit: BoxFit.scaleDown, child: labelWidget)
            : labelWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: isMobile
              ? Row(
                  mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                  children: [
                    isNarrow
                        ? Expanded(
                            child: _tab(
                                MapSection.allSensors,
                                _sectionLabel(MapSection.allSensors),
                                Icons.map),
                          )
                        : _tab(MapSection.allSensors,
                            _sectionLabel(MapSection.allSensors), Icons.map),
                    const SizedBox(width: 4),
                    isNarrow
                        ? Expanded(
                            child: _tab(
                                MapSection.annamWeather,
                                _sectionLabel(MapSection.annamWeather),
                                Icons.thermostat),
                          )
                        : _tab(
                            MapSection.annamWeather,
                            _sectionLabel(MapSection.annamWeather),
                            Icons.thermostat),
                  ],
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _tab(MapSection.allSensors, 'ANNAM.AI + IMD Sensors',
                          Icons.map),
                      const SizedBox(width: 6),
                      _tab(MapSection.annamWeather, 'ANNAM.AI Weather',
                          Icons.thermostat),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSidebarToggle(
      MapSection section, String label, IconData icon, bool isDark) {
    final isSelected = _currentSection == section;
    final activeBlue = const Color(0xFF1976D2);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _currentSection = section;
            if (section == MapSection.allSensors)
              _selectedLayer = WeatherLayer.clusters;
          });
          _syncOneDayWeatherSnapshots(force: true);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? Colors.white.withOpacity(0.2)
                    : activeBlue.withOpacity(0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.white38 : activeBlue.withOpacity(0.5))
                    : (isDark ? Colors.white12 : Colors.black12),
                width: 1),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: isSelected
                      ? (isDark ? Colors.white : activeBlue)
                      : (isDark ? Colors.white54 : Colors.black54),
                  size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: isSelected
                          ? (isDark ? Colors.white : activeBlue)
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _layerIcon(WeatherLayer layer) {
    switch (layer) {
      case WeatherLayer.clusters:
        return Icons.group_work;
      case WeatherLayer.temperature:
        return Icons.thermostat;
      case WeatherLayer.humidity:
        return Icons.water_drop;
      case WeatherLayer.wind:
        return Icons.air;
      case WeatherLayer.rainfall:
        return Icons.umbrella;
      case WeatherLayer.pressure:
        return Icons.speed;
    }
  }

  Widget _buildSidebarLayerChip(WeatherLayer layer, bool isDark) {
    final isSelected = _selectedLayer == layer;
    final activeBlue = const Color(0xFF1976D2);
    final isCluster = layer == WeatherLayer.clusters;
    final activeColor = isDark ? const Color(0xFF40C4FF) : const Color(0xFF1565C0);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedLayer = layer),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? activeColor.withOpacity(0.3)
                    : activeColor.withOpacity(0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isSelected
                    ? (isDark ? activeColor : activeColor.withOpacity(0.5))
                    : (isDark ? Colors.white24 : Colors.black12),
                width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_layerIcon(layer),
                  size: 14,
                  color: isSelected
                      ? (isDark ? activeColor : activeColor)
                      : (isDark ? Colors.white70 : Colors.black54)),
              const SizedBox(width: 6),
              Text(
                _layerLabel(layer),
                style: TextStyle(
                    color: isSelected
                        ? (isDark ? activeColor : activeColor)
                        : (isDark ? Colors.white70 : Colors.black87),
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Layer bar widget ───────────────────────────────────────────────────────
  Widget _buildLayerChip(WeatherLayer layer, bool isDark,
      {bool isMobile = false}) {
    final isSelected = _selectedLayer == layer;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _selectedLayer = layer),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 10,
            vertical: isMobile ? 4 : 5,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFF1976D2).withOpacity(0.12))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white60 : const Color(0xFF1976D2))
                  : (isDark ? Colors.white30 : Colors.black12),
              width: 1,
            ),
          ),
          child: Text(
            _layerLabel(layer, compact: isMobile),
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1976D2))
                  : (isDark
                      ? Colors.white.withOpacity(0.85)
                      : Colors.black.withOpacity(0.65)),
              fontSize: isMobile ? 11 : 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayerBar(bool isDark, {bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.4) : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black26 : Colors.black12,
              blurRadius: 4.0,
              offset: const Offset(0, 2))
        ],
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: WeatherLayer.values
                    .map((layer) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _buildLayerChip(layer, isDark, isMobile: true),
                        ))
                    .toList(),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  ...WeatherLayer.values.map((layer) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _buildLayerChip(layer, isDark),
                      )),
                ],
              ),
            ),
    );
  }

  void _openWeatherParametersSheet({required bool compact}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: isDark ? const Color(0xFF0F1115) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.tune,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Weather Parameters',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close,
                        color: isDark ? Colors.white70 : Colors.black54),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WeatherLayer.values.map((layer) {
                  final isSelected = _selectedLayer == layer;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedLayer = layer);
                        Navigator.of(ctx).pop();
                        _syncOneDayWeatherSnapshots(force: true);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 10 : 12,
                          vertical: compact ? 8 : 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? Colors.white.withOpacity(0.18)
                                  : const Color(0xFF1976D2).withOpacity(0.12))
                              : (isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.black.withOpacity(0.04)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? (isDark
                                    ? Colors.white70
                                    : const Color(0xFF1976D2))
                                : (isDark ? Colors.white24 : Colors.black12),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _layerLabel(layer, compact: compact),
                          style: TextStyle(
                            color: isSelected
                                ? (isDark
                                    ? Colors.white
                                    : const Color(0xFF1976D2))
                                : (isDark
                                    ? Colors.white.withOpacity(0.85)
                                    : Colors.black.withOpacity(0.65)),
                            fontSize: compact ? 12 : 13,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showStateClusters = zoomLevel < CLUSTER_ZOOM_THRESHOLD;
    final showDistrictClusters = zoomLevel >= CLUSTER_ZOOM_THRESHOLD &&
        zoomLevel < DISTRICT_ZOOM_THRESHOLD;
    final screenSize = MediaQuery.sizeOf(context);
    final topInset = MediaQuery.paddingOf(context).top;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;
    final horizontalPadding = isMobile ? 10.0 : (isTablet ? 12.0 : 16.0);
    final double controlMaxWidth;
    if (isMobile) {
      final full = screenSize.width - (horizontalPadding * 2);
      controlMaxWidth = full > 420 ? 420.0 : full;
    } else if (isTablet) {
      controlMaxWidth = screenSize.width * 0.55;
    } else {
      controlMaxWidth = 620.0;
    }
    final controlsTop = topInset + kToolbarHeight + (isMobile ? 4.0 : 16.0);

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeBlue = const Color(0xFF1976D2);
    final bgColor = isDarkMode
        ? Colors.black.withOpacity(0.25)
        : Colors.white.withOpacity(0.95);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final textSubColor = isDarkMode ? Colors.white70 : Colors.black87;
    final hintColor = isDarkMode ? Colors.white54 : Colors.black54;
    final borderColor = isDarkMode ? const Color(0xFF40C4FF).withOpacity(0.35) : Colors.black12;

    final useColumnLayout = isMobile || isTablet;

    if (widget.isComponent) {
      final double outerPadding = isMobile ? 12 : (isTablet ? 20 : 40);

      // Reusable Map Container
      Widget mapContainer = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            if (isDarkMode)
              BoxShadow(
                color: const Color(0xFF40C4FF).withOpacity(0.15),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            _buildFlutterMap(showStateClusters, showDistrictClusters),
            // Legends on top of map
            Positioned(
              bottom: 16,
              left: 16,
              child: _currentSection == MapSection.allSensors
                  ? _MapLegend(
                      csCount: _dashboardAlignedAnnamCount,
                      imdCount: imdLocations.length,
                      isCompact: true,
                    )
                  : _MapLegend(
                      csCount: _dashboardAlignedAnnamCount,
                      imdCount: 0,
                      showImdCount: false,
                      showImdLegend: false,
                      isCompact: true,
                    ),
            ),
            if (_currentSection == MapSection.annamWeather &&
                _selectedLayer != WeatherLayer.clusters)
              Positioned(
                bottom: 16,
                right: 16,
                child: _WeatherScaleBox(
                  layer: _selectedLayer,
                  boxWidth: 140,
                ),
              ),
          ],
        ),
      );

      // Reusable Control Content
      Widget controlContent = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- SECTION 1: SEARCH ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tune, color: textSubColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Controls",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: isDarkMode
                            ? null
                            : Border.all(color: Colors.black12, width: 1),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: textColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search sensors...',
                          hintStyle: TextStyle(color: hintColor, fontSize: 13),
                          prefixIcon:
                              Icon(Icons.search, color: hintColor, size: 18),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) {
                          _updateSuggestions(v);
                          setState(() {});
                        },
                        onSubmitted: _searchDevices,
                      ),
                    ),
                    if (suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        height: 150,
                        child: ListView.builder(
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final s = suggestions[index];
                            return ListTile(
                              dense: true,
                              title: Text(
                                  _toAnnamDisplayName(s['deviceId'] ?? ''),
                                  style: TextStyle(
                                      color: textColor, fontSize: 12)),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 32),

                // --- SECTION 2: TOGGLES ---
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.layers_outlined,
                            color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Section",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSidebarToggle(MapSection.allSensors,
                        'ANNAM+IMD Sensors', Icons.map, isDarkMode),
                    const SizedBox(height: 8),
                    _buildSidebarToggle(MapSection.annamWeather,
                        'ANNAM.AI sensors', Icons.thermostat, isDarkMode),
                  ],
                ),

                const SizedBox(height: 32),

                // --- SECTION 3: PARAMETERS ---
                if (_currentSection == MapSection.annamWeather)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list,
                              color: textSubColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Parameters",
                            style: TextStyle(
                                color: textSubColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: WeatherLayer.values
                            .map((l) => _buildSidebarLayerChip(l, isDarkMode))
                            .toList(),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 32),

            // --- SECTION 4: RELOAD ---
            Center(
              child: TextButton.icon(
                onPressed: _reloadDevices,
                icon: Icon(Icons.refresh,
                    color: isDarkMode ? const Color(0xFF40C4FF) : activeBlue,
                    size: 16),
                label: Text("Reload Data",
                    style: TextStyle(
                        color: isDarkMode ? const Color(0xFF40C4FF) : activeBlue,
                        fontSize: 12)),
              ),
            ),
          ],
        ),
      );

      // --- RENDER TABLET/MOBILE OVERLAY LAYOUT (Matching Mappage) ---
      if (useColumnLayout) {
        return Container(
          height: widget.height,
          padding: EdgeInsets.symmetric(horizontal: outerPadding, vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // 1. BACKGROUND: MAP
                _buildFlutterMap(showStateClusters, showDistrictClusters),

                // 2. OVERLAID CONTROLS (TOP)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Column(
                    children: [
                      // Floating Search Bar
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: borderColor, width: 1),
                              ),
                              child: TextField(
                                controller: _searchController,
                                style:
                                    TextStyle(color: textColor, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Search sensors...',
                                  hintStyle:
                                      TextStyle(color: hintColor, fontSize: 13),
                                  prefixIcon: Icon(Icons.search,
                                      color: hintColor, size: 18),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onChanged: (v) {
                                  _updateSuggestions(v);
                                  setState(() {});
                                },
                                onSubmitted: _searchDevices,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Floating Reload Icon
                          GestureDetector(
                            onTap: _reloadDevices,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: borderColor, width: 1),
                              ),
                              child: Icon(Icons.refresh,
                                  color: textSubColor, size: 20),
                            ),
                          ),
                        ],
                      ),

                      // Suggestions Overlay
                      if (suggestions.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 4, right: 46),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.black.withOpacity(0.9)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: suggestions.length,
                            itemBuilder: (context, index) {
                              final s = suggestions[index];
                              return ListTile(
                                dense: true,
                                title: Text(
                                    _toAnnamDisplayName(s['deviceId'] ?? ''),
                                    style: TextStyle(
                                        color: textColor, fontSize: 12)),
                                onTap: () => _selectSuggestion(s),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 10),

                      // Floating Section Toggles
                      screenSize.width <= 380
                          ? Material(
                              color: Colors.transparent,
                              child: _buildSectionToggle(isMobile: true),
                            )
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Material(
                                color: Colors.transparent,
                                child: _buildSectionToggle(isMobile: true),
                              ),
                            ),

                      if (_currentSection == MapSection.annamWeather) ...[
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _openWeatherParametersSheet(
                              compact: true,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: Colors.white12, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.tune,
                                      color: textSubColor, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _layerLabel(_selectedLayer, compact: true),
                                    style: TextStyle(
                                      color: textSubColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // 3. LEGEND (BOTTOM LEFT)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: _currentSection == MapSection.allSensors
                      ? _MapLegend(
                          csCount: _dashboardAlignedAnnamCount,
                          imdCount: imdLocations.length,
                          isCompact: true,
                        )
                      : _MapLegend(
                          csCount: _dashboardAlignedAnnamCount,
                          imdCount: 0,
                          showImdCount: false,
                          showImdLegend: false,
                          isCompact: true,
                        ),
                ),

                // 4. SCALE BOX (BOTTOM RIGHT)
                if (_currentSection == MapSection.annamWeather &&
                    _selectedLayer != WeatherLayer.clusters)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child:
                        _WeatherScaleBox(layer: _selectedLayer, boxWidth: 130),
                  ),
              ],
            ),
          ),
        );
      }

      // --- RENDER DESKTOP ROW LAYOUT ---
      return Container(
        height: widget.height,
        padding: EdgeInsets.symmetric(horizontal: outerPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- LEFT SECTION: MAP ---
            Expanded(
              flex: 7,
              child: mapContainer,
            ),

            const SizedBox(width: 16),

            // --- RIGHT SECTION: CONTROLS ---
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    if (isDarkMode)
                      BoxShadow(
                        color: const Color(0xFF40C4FF).withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: widget.height - 32,
                    ),
                    child: controlContent,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: !useColumnLayout,
      appBar: AppBar(
        backgroundColor: useColumnLayout
            ? Colors.black.withOpacity(0.35)
            : Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: useColumnLayout
                ? Colors.transparent
                : Colors.black.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        title: Container(
          height: 38,
          decoration: BoxDecoration(
            color: useColumnLayout
                ? Colors.white.withOpacity(0.12)
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: useColumnLayout ? Colors.white12 : Colors.transparent,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: TextStyle(
              color: useColumnLayout ? Colors.white : Colors.black,
              fontSize: isMobile ? 13 : 14,
            ),
            decoration: InputDecoration(
              hintText: isMobile
                  ? 'Search sensors...'
                  : 'Search City, State, Device ID, Station or Category',
              hintStyle: TextStyle(
                color: useColumnLayout ? Colors.white54 : Colors.black,
                fontSize: isMobile ? 13 : 14,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: useColumnLayout ? Colors.white54 : Colors.black,
                size: isMobile ? 18 : 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close,
                          color:
                              useColumnLayout ? Colors.white54 : Colors.black54,
                          size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _searchDevices('');
                        setState(() => suggestions = []);
                      },
                    )
                  : null,
              filled: false,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide.none,
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
            ),
            onChanged: (v) {
              _updateSuggestions(v);
              setState(() {});
            },
            onSubmitted: _searchDevices,
          ),
        ),
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Reload Devices',
            onPressed: _reloadDevices,
          ),
        ],
      ),
      body: useColumnLayout
          ? _buildMobileBody(
              showStateClusters: showStateClusters,
              showDistrictClusters: showDistrictClusters,
              isMobile: isMobile,
              isTablet: isTablet,
              controlMaxWidth: controlMaxWidth,
              horizontalPadding: horizontalPadding,
            )
          : Stack(
              children: [
                // ── Flutter map ────────────────────────────────────────────────
                _buildFlutterMap(showStateClusters, showDistrictClusters),

                // ── Search suggestions dropdown (below AppBar) ────────────────
                if (suggestions.isNotEmpty)
                  Positioned(
                    top: controlsTop - 8,
                    left: horizontalPadding + 48,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: controlMaxWidth),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8.0),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4.0,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final s = suggestions[index];
                            final isImd = s['source'] == 'IMD';
                            return ListTile(
                              leading: isImd
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: _ImdMarker())
                                  : const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: _AnnamAiMarker()),
                              title: Text(
                                _toAnnamDisplayName(s['deviceId'] ?? ''),
                                style: const TextStyle(
                                    color: Colors.black, fontSize: 14),
                              ),
                              subtitle: Text(
                                {
                                  if (s['city'] != null &&
                                      s['city'].toString().isNotEmpty)
                                    s['city'],
                                  if (s['district'] != null &&
                                      s['district'].toString().isNotEmpty)
                                    s['district'],
                                  if (s['state'] != null &&
                                      s['state'].toString().isNotEmpty)
                                    s['state'],
                                }
                                    .where((e) =>
                                        e != null && e.toString().isNotEmpty)
                                    .join(', '),
                                style: const TextStyle(
                                    color: Colors.black54, fontSize: 12),
                              ),
                              tileColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // ── Section toggle + Layer bar (single row, below AppBar) ───
                Positioned(
                  top: controlsTop,
                  left: horizontalPadding,
                  right: horizontalPadding,
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Material(
                        color: Colors.transparent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSectionToggle(isMobile: false),
                            if (_currentSection == MapSection.annamWeather) ...[
                              const SizedBox(width: 10),
                              _buildLayerBar(isDarkMode, isMobile: false),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Legend (bottom-left) ──────────────────────────────────────
                Positioned(
                  bottom: 24,
                  left: 16,
                  child: _currentSection == MapSection.allSensors
                      ? _MapLegend(
                          csCount: _dashboardAlignedAnnamCount,
                          imdCount: imdLocations.length,
                        )
                      : _MapLegend(
                          csCount: _dashboardAlignedAnnamCount,
                          imdCount: 0,
                          showImdCount: false,
                          showImdLegend: false,
                        ),
                ),

                // ── Scale box (bottom-right) ─────────────────────────────────
                if (_currentSection == MapSection.annamWeather &&
                    _selectedLayer != WeatherLayer.clusters)
                  Positioned(
                    bottom: 24,
                    right: 16,
                    child: _WeatherScaleBox(
                      layer: _selectedLayer,
                      boxWidth: isTablet ? 160 : 180,
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Mobile body: controls ABOVE map, not overlaying ─────────────────────────
  Widget _buildMobileBody({
    required bool showStateClusters,
    required bool showDistrictClusters,
    required bool isMobile,
    required bool isTablet,
    required double controlMaxWidth,
    required double horizontalPadding,
  }) {
    return Stack(
      children: [
        // ── Map fills the entire area ──────────────────────────────────
        _buildFlutterMap(showStateClusters, showDistrictClusters),

        // ── Section toggle (overlayed on map) ─────────────────────────
        Positioned(
          top: 6,
          left: horizontalPadding,
          right: horizontalPadding,
          child: Center(
            child: MediaQuery.sizeOf(context).width <= 380
                ? Material(
                    color: Colors.transparent,
                    child: _buildSectionToggle(isMobile: isMobile),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Material(
                      color: Colors.transparent,
                      child: _buildSectionToggle(isMobile: isMobile),
                    ),
                  ),
          ),
        ),

        // ── Weather parameters button (no map-covering bar) ───────────
        if (_currentSection == MapSection.annamWeather)
          Positioned(
            top: 52,
            right: horizontalPadding,
            child: GestureDetector(
              onTap: () => _openWeatherParametersSheet(compact: true),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tune, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _layerLabel(_selectedLayer, compact: true),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Search suggestions dropdown (below AppBar) ────────────────
        if (suggestions.isNotEmpty)
          Positioned(
            top: 0,
            left: horizontalPadding,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: controlMaxWidth),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12, width: 1),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: suggestions.length,
                  itemBuilder: (context, index) {
                    final s = suggestions[index];
                    final isImd = s['source'] == 'IMD';
                    return ListTile(
                      dense: true,
                      leading: isImd
                          ? const SizedBox(
                              width: 18, height: 18, child: _ImdMarker())
                          : const SizedBox(
                              width: 18, height: 18, child: _AnnamAiMarker()),
                      title: Text(
                        _toAnnamDisplayName(s['deviceId'] ?? ''),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                      subtitle: Text(
                        {
                          if (s['city'] != null &&
                              s['city'].toString().isNotEmpty)
                            s['city'],
                          if (s['district'] != null &&
                              s['district'].toString().isNotEmpty)
                            s['district'],
                          if (s['state'] != null &&
                              s['state'].toString().isNotEmpty)
                            s['state'],
                        }
                            .where((e) => e != null && e.toString().isNotEmpty)
                            .join(', '),
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      tileColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      onTap: () => _selectSuggestion(s),
                    );
                  },
                ),
              ),
            ),
          ),

        // ── Legend (bottom-left) ──────────────────────────────────────
        Positioned(
          bottom: 10,
          left: 8,
          child: _currentSection == MapSection.allSensors
              ? _MapLegend(
                  csCount: _dashboardAlignedAnnamCount,
                  imdCount: imdLocations.length,
                )
              : _MapLegend(
                  csCount: _dashboardAlignedAnnamCount,
                  imdCount: 0,
                  showImdCount: false,
                  showImdLegend: false,
                ),
        ),

        // ── Scale box (bottom-right) ─────────────────────────────────
        if (_currentSection == MapSection.annamWeather &&
            _selectedLayer != WeatherLayer.clusters)
          Positioned(
            bottom: 10,
            right: 8,
            child: _WeatherScaleBox(
              layer: _selectedLayer,
              boxWidth: 140,
            ),
          ),
      ],
    );
  }

  // ── Shared FlutterMap builder ────────────────────────────────────────────────
  Widget _buildFlutterMap(bool showStateClusters, bool showDistrictClusters) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: centerCoordinates,
            initialZoom: zoomLevel,
            minZoom: 2.0,
            maxZoom: 19.0,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture) {
                setState(() {
                  if (!_isMapInteracted) {
                    _preInteractionCenter = centerCoordinates;
                    _preInteractionZoom = zoomLevel;
                    _isMapInteracted = true;
                  }
                  zoomLevel = position.zoom ?? zoomLevel;
                  centerCoordinates = position.center ?? centerCoordinates;
                });
              }
            },
            interactionOptions: InteractionOptions(
              flags: _getInteractiveFlags(),
              enableMultiFingerGestureRace: true,
              pinchZoomThreshold: 0.01,
              pinchMoveThreshold: 0.01,
            ),
            keepAlive: true,
            cameraConstraint: CameraConstraint.contain(
              bounds: LatLngBounds(
                LatLng(-85.05112878, -180),
                LatLng(85.05112878, 180),
              ),
            ),
          ),
          children: [
            // Satellite tiles with a very subtle dark overlay
            _getSatelliteTileLayer(),
            // Slight darkening overlay — makes it look slightly moodier/cooler
            IgnorePointer(
              child: Container(
                color: const Color(0xFF000000).withValues(alpha: 0.22),
              ),
            ),
            Opacity(opacity: 0.8, child: _getLabelOverlayLayer()),
            MarkerLayer(
              markers: [
                if (_currentSection == MapSection.allSensors) ...[
                  if (showStateClusters) ...[
                    ..._buildImdStateMarkers(),
                    ..._buildCsStateMarkers(),
                  ] else if (showDistrictClusters) ...[
                    ..._buildImdDistrictMarkers(),
                    ..._buildCsDistrictMarkers(),
                  ] else ...[
                    ..._buildImdIndividualMarkers(),
                    ..._buildCsIndividualMarkers(),
                  ],
                ] else ...[
                  if (_selectedLayer == WeatherLayer.clusters) ...[
                    if (showStateClusters) ...[
                      ..._buildCsStateMarkers(),
                    ] else if (showDistrictClusters) ...[
                      ..._buildCsDistrictMarkers(),
                    ] else ...[
                      ..._buildCsIndividualMarkers(),
                    ],
                  ] else ...[
                    if (showStateClusters)
                      ..._buildAnnamWeatherStateClusters()
                    else if (showDistrictClusters)
                      ..._buildAnnamWeatherDistrictClusters()
                    else
                      ..._buildAnnamWeatherMarkers(),
                  ],
                ],
                if (searchPin != null) searchPin!,
              ],
            ),
          ],
        ),
        // Zoom Controls
        Positioned(
          bottom: (_currentSection == MapSection.annamWeather &&
                  _selectedLayer != WeatherLayer.clusters)
              ? 110
              : 16,
          right: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isComponent) ...[
                _zoomButton(Icons.fullscreen, () {
                  NavigationUtils.navigateTo(
                    context,
                    '/devicemapinfo',
                  );
                }),
                const SizedBox(height: 6),
              ],
              if (!widget.isComponent) ...[
                _zoomButton(Icons.add, () {
                  setState(() {
                    if (!_isMapInteracted) {
                      _preInteractionCenter = centerCoordinates;
                      _preInteractionZoom = zoomLevel;
                      _isMapInteracted = true;
                    }
                    zoomLevel = (zoomLevel + 1).clamp(2.0, 19.0);
                  });
                  mapController.move(centerCoordinates, zoomLevel);
                }),
                const SizedBox(height: 6),
                _zoomButton(Icons.remove, () {
                  setState(() {
                    if (!_isMapInteracted) {
                      _preInteractionCenter = centerCoordinates;
                      _preInteractionZoom = zoomLevel;
                      _isMapInteracted = true;
                    }
                    zoomLevel = (zoomLevel - 1).clamp(2.0, 19.0);
                  });
                  mapController.move(centerCoordinates, zoomLevel);
                }),
                const SizedBox(height: 6),
              ],
              _zoomButton(Icons.my_location, () {
                final isMobile = MediaQuery.sizeOf(context).width < 600;
                final defaultCenter = isMobile
                    ? LatLng(22.9734, 78.0000)
                    : LatLng(22.9734, 78.6569);
                final defaultZoom = isMobile ? 3.4 : 4.5;

                setState(() {
                  _isMapInteracted = false;
                  // ALWAYS reset to the appropriate default location regardless of previous interactions,
                  // so the right side is completely visible after panning around.
                  centerCoordinates = defaultCenter;
                  zoomLevel = defaultZoom;
                  _preInteractionCenter = defaultCenter;
                  _preInteractionZoom = defaultZoom;
                });
                mapController.move(centerCoordinates, zoomLevel);
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
