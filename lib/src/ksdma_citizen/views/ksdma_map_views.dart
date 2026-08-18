import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_aws_station_detail_view.dart';

enum MapViewLevel { state, district, taluk, panchayat, station }

class KsdmaMultiMapView extends StatefulWidget {
  final MapViewLevel level;

  const KsdmaMultiMapView({super.key, required this.level});

  @override
  State<KsdmaMultiMapView> createState() => _KsdmaMultiMapViewState();
}

class _KsdmaMultiMapViewState extends State<KsdmaMultiMapView> {
  late MapController _mapController;
  String _selectedDistrict = 'All Districts';
  String _selectedParam = 'All Parameters';
  bool _isSatellite = false;

  final Map<String, LatLng> _districtCoords = {
    'Thiruvananthapuram': const LatLng(8.5241, 76.9366),
    'Kollam': const LatLng(8.8932, 76.6141),
    'Pathanamthitta': const LatLng(9.2648, 76.7870),
    'Alappuzha': const LatLng(9.4981, 76.3388),
    'Kottayam': const LatLng(9.5916, 76.5222),
    'Idukki': const LatLng(9.8497, 76.9813),
    'Ernakulam': const LatLng(9.9816, 76.2999),
    'Thrissur': const LatLng(10.5276, 76.2144),
    'Palakkad': const LatLng(10.7867, 76.6548),
    'Malappuram': const LatLng(11.0728, 76.0740),
    'Kozhikode': const LatLng(11.2588, 75.7804),
    'Wayanad': const LatLng(11.6854, 76.1320),
    'Kannur': const LatLng(11.8745, 75.3704),
    'Kasaragod': const LatLng(12.5102, 74.9852),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<KsdmaStateService>(context, listen: false).fetchStationsIfNeeded();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  LatLng _getMapCenter(List<KsdmaStation> approved) {
    if (widget.level == MapViewLevel.state || widget.level == MapViewLevel.station || _selectedDistrict == 'All Districts') {
      return const LatLng(10.4505, 76.3711);
    }
    if (_districtCoords.containsKey(_selectedDistrict)) {
      return _districtCoords[_selectedDistrict]!;
    }
    final distStations = approved.where((s) => s.district.toLowerCase() == _selectedDistrict.toLowerCase()).toList();
    if (distStations.isNotEmpty) {
      return LatLng(distStations.first.latitude, distStations.first.longitude);
    }
    return const LatLng(10.4505, 76.3711);
  }

  double _getMapZoom() {
    switch (widget.level) {
      case MapViewLevel.state:
        return 7.5;
      case MapViewLevel.district:
        return 9.2;
      case MapViewLevel.taluk:
        return 9.8;
      case MapViewLevel.panchayat:
        return 10.5;
      case MapViewLevel.station:
        return 8.0;
    }
  }

  void _onDistrictChanged(String newDist, List<KsdmaStation> approved) {
    setState(() {
      _selectedDistrict = newDist;
    });
    if (newDist == 'All Districts') {
      _mapController.move(const LatLng(10.4505, 76.3711), 7.5);
    } else {
      final newCenter = _getMapCenter(approved);
      _mapController.move(newCenter, _getMapZoom());
    }
  }

  void _showStationDetailsDialog(BuildContext context, KsdmaStation s, KsdmaStateService state) {
    final bool isAwsStation = s.category == StationCategory.aws ||
        s.instrumentType == InstrumentType.awsAutomaticStation ||
        s.stationId.startsWith('WS_');

    final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
    final wsRaw = state.getWsDeviceRaw(s.stationId);

    if (isAwsStation) {
      final String tempStr = wsRaw?['Temperature'] != null 
          ? '${wsRaw!['Temperature']} °C' 
          : (obs?.maxTemperatureC != null ? '${obs!.maxTemperatureC} °C' : 'N/A');
          
      final String humStr = wsRaw?['Humidity'] != null 
          ? '${wsRaw!['Humidity']} %' 
          : (obs?.humidityPercent != null ? '${obs!.humidityPercent} %' : 'N/A');
          
      final String rainStr = wsRaw?['Rainfall'] != null 
          ? '${wsRaw!['Rainfall']} mm' 
          : (obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '0.0 mm');
          
      final String pressStr = wsRaw?['AtmPressure'] != null 
          ? '${wsRaw!['AtmPressure']} hPa' 
          : (obs?.riverWaterLevelM != null ? '${obs!.riverWaterLevelM} m' : 'N/A');
          
      final String windSpdStr = wsRaw?['WindSpeed'] != null ? '${wsRaw!['WindSpeed']} m/s' : 'N/A';
      final String windDirStr = wsRaw?['WindDirection'] != null ? '${wsRaw!['WindDirection']}°' : 'N/A';
      final String windGustStr = wsRaw?['WindGust'] != null ? '${wsRaw!['WindGust']} m/s' : 'N/A';
      final String timeStr = wsRaw?['TimeStamp']?.toString() ?? (obs != null ? '${obs.observationDate.toIso8601String().split('T')[0]} ${obs.observationTime.hour.toString().padLeft(2, '0')}:${obs.observationTime.minute.toString().padLeft(2, '0')}' : 'Live');

      showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.sensors, color: Color(0xFF2563EB), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFF86EFAC)),
                                      ),
                                      child: const Text('LIVE TELEMETRY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text('${s.gramaPanchayat}, ${s.taluk}, ${s.district} District • Lat: ${s.latitude.toStringAsFixed(4)}, Lng: ${s.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                      style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('⚡ Device Sensor Readings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Updated: $timeStr', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildMetricTile('Rainfall', rainStr, Icons.water_drop, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                    _buildMetricTile('Temperature', tempStr, Icons.thermostat, const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
                    _buildMetricTile('Humidity', humStr, Icons.opacity, const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
                    _buildMetricTile('Atm. Pressure', pressStr, Icons.speed, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
                    _buildMetricTile('Wind Speed', windSpdStr, Icons.air, const Color(0xFF0288D1), const Color(0xFFE0F2FE)),
                    _buildMetricTile('Wind Direction', windDirStr, Icons.explore, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                    _buildMetricTile('Wind Gust', windGustStr, Icons.cyclone, const Color(0xFF475569), const Color(0xFFF1F5F9)),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ChangeNotifierProvider<KsdmaStateService>.value(
                              value: state,
                              child: KsdmaAwsStationDetailView(stationId: s.stationId),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.bar_chart, size: 16),
                      label: const Text('Show Detail Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // Manual station dialog
    _showManualStationGraphDialog(context, s, state);
  }

  void _showManualStationGraphDialog(BuildContext context, KsdmaStation s, KsdmaStateService state) {
    final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${s.stationId} • ${s.district}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Owner: ${s.ownerName} (${s.ownerCategory.label})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('Location: ${s.gramaPanchayat}, ${s.taluk}, ${s.district}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('Instrument: ${s.instrumentType.displayName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const Divider(height: 20),
            const Text('Latest Observation Reading:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            if (obs != null) ...[
              if (obs.rainfallMm != null) Text('🌧 Rainfall: ${obs.rainfallMm} mm', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              if (obs.maxTemperatureC != null) Text('🌡 Max Temp: ${obs.maxTemperatureC} °C', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
              if (obs.humidityPercent != null) Text('💧 Humidity: ${obs.humidityPercent} %', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
              if (obs.riverWaterLevelM != null) Text('🌊 River Level: ${obs.riverWaterLevelM} m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
            ] else ...[
              const Text('No reading submitted today.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF146356), foregroundColor: Colors.white),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, Color bg) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final approved = state.stations;

    final List<String> allDistrictsList = [
      'All Districts',
      ...(state.districtNames.isNotEmpty ? state.districtNames : _districtCoords.keys.toList())
    ];

    if (_selectedDistrict != 'All Districts' && !allDistrictsList.contains(_selectedDistrict)) {
      _selectedDistrict = 'All Districts';
    }

    final title = widget.level == MapViewLevel.state
        ? 'State View (Kerala)'
        : widget.level == MapViewLevel.district
            ? 'District View ($_selectedDistrict)'
            : widget.level == MapViewLevel.taluk
                ? 'Taluk View ($_selectedDistrict)'
                : widget.level == MapViewLevel.panchayat
                    ? 'Grama Panchayat View ($_selectedDistrict)'
                    : 'Station View (Live Stations)';

    final subtitle = 'Live Monitoring Across ${approved.length} Weather Stations in Kerala';
    final center = _getMapCenter(approved);
    final zoom = _getMapZoom();

    // 1. District filter (State View and Station View show all stations across Kerala)
    final distFiltered = (widget.level == MapViewLevel.state || widget.level == MapViewLevel.station || _selectedDistrict == 'All Districts')
        ? approved
        : approved.where((s) => s.district.toLowerCase() == _selectedDistrict.toLowerCase()).toList();

    // Fallback to approved if district filter returned 0 stations so map is NEVER empty
    final effectiveBaseStations = distFiltered.isNotEmpty ? distFiltered : approved;

    // 2. Working parameter filter (All Parameters, Rainfall, Temperature, River Level, Humidity)
    final displayedStations = effectiveBaseStations.where((s) {
      if (_selectedParam == 'All Parameters') return true;
      if (_selectedParam == 'Rainfall') {
        return s.instrumentType == InstrumentType.rainGauge ||
            s.category == StationCategory.aws ||
            s.instrumentType == InstrumentType.awsAutomaticStation;
      } else if (_selectedParam == 'Temperature') {
        return s.instrumentType == InstrumentType.maxMinThermometer ||
            s.category == StationCategory.aws ||
            s.instrumentType == InstrumentType.awsAutomaticStation;
      } else if (_selectedParam == 'Humidity') {
        return s.instrumentType == InstrumentType.hygrometer ||
            s.category == StationCategory.aws ||
            s.instrumentType == InstrumentType.awsAutomaticStation;
      } else if (_selectedParam == 'River Level') {
        return s.instrumentType == InstrumentType.riverGauge ||
            s.category == StationCategory.aws ||
            s.instrumentType == InstrumentType.awsAutomaticStation;
      }
      return true;
    }).toList();

    // 3. Offset duplicate/overlapping coordinates so ALL markers at identical Lat/Lng are clearly visible & clickable
    final Map<String, List<KsdmaStation>> coordGroups = {};
    for (var s in displayedStations) {
      final key = "${s.latitude.toStringAsFixed(4)}_${s.longitude.toStringAsFixed(4)}";
      coordGroups.putIfAbsent(key, () => []).add(s);
    }

    final List<Marker> markersList = [];
    coordGroups.forEach((key, group) {
      for (int i = 0; i < group.length; i++) {
        final s = group[i];
        double lat = s.latitude;
        double lng = s.longitude;

        if (group.length > 1) {
          final angle = (2 * pi * i) / group.length;
          const offsetRadius = 0.0035; // ~350m spiral offset for clear pin separation
          lat += offsetRadius * cos(angle);
          lng += offsetRadius * sin(angle);
        }

        final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
        final isApproved = s.approvalStatus == ApprovalStatus.approved;

        String valStr = '0.0mm';
        if (obs != null) {
          if (_selectedParam == 'Temperature') {
            valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC}°C' : '—';
          } else if (_selectedParam == 'Humidity') {
            valStr = obs.humidityPercent != null ? '${obs.humidityPercent}%' : '—';
          } else if (_selectedParam == 'River Level') {
            valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM}m' : '—';
          } else if (_selectedParam == 'Rainfall') {
            valStr = obs.rainfallMm != null ? '${obs.rainfallMm}mm' : '0.0mm';
          } else {
            // All Parameters: native station reading
            switch (s.instrumentType) {
              case InstrumentType.hygrometer:
                valStr = obs.humidityPercent != null ? '${obs.humidityPercent}%' : '—';
                break;
              case InstrumentType.maxMinThermometer:
                valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC}°C' : '—';
                break;
              case InstrumentType.riverGauge:
                valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM}m' : '—';
                break;
              case InstrumentType.rainGauge:
              case InstrumentType.awsAutomaticStation:
                valStr = obs.rainfallMm != null ? '${obs.rainfallMm}mm' : '0.0mm';
                break;
            }
          }
        }

        final accentColor = s.instrumentType == InstrumentType.maxMinThermometer || _selectedParam == 'Temperature'
            ? const Color(0xFFEA580C)
            : s.instrumentType == InstrumentType.hygrometer || _selectedParam == 'Humidity'
                ? const Color(0xFF7C3AED)
                : s.instrumentType == InstrumentType.riverGauge || _selectedParam == 'River Level'
                    ? const Color(0xFF0D9488)
                    : const Color(0xFF2563EB);

        markersList.add(
          Marker(
            point: LatLng(lat, lng),
            width: 110,
            height: 34,
            child: GestureDetector(
              onTap: () => _showStationDetailsDialog(context, s, state),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isApproved ? accentColor : Colors.amber, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: isApproved ? accentColor : Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        '${s.stationId}: $valStr',
                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 950;

        final mapWidget = Container(
          height: isMobile ? 380 : 500,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: zoom,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _isSatellite
                          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cloudsense.webapp',
                    ),
                    MarkerLayer(markers: markersList),
                  ],
                ),

                // Top Left Overlay Badge
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                        const SizedBox(width: 6),
                        Text(
                          '${displayedStations.length} Active Pins',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ),

                // Satellite / Map Layer Toggle (Top Right)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isSatellite = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: !_isSatellite ? const Color(0xFF146356) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: !_isSatellite ? Colors.white : const Color(0xFF0F172A))),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isSatellite = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _isSatellite ? const Color(0xFF146356) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Satellite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isSatellite ? Colors.white : const Color(0xFF0F172A))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Map Legend Overlay Bar
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLegendPill('Rainfall', const Color(0xFF2563EB)),
                        _buildLegendPill('Humidity', const Color(0xFF7C3AED)),
                        _buildLegendPill('Temperature', const Color(0xFFEA580C)),
                        _buildLegendPill('River Level', const Color(0xFF0D9488)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final summaryWidget = Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.leaderboard_outlined, color: Color(0xFF146356), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.level == MapViewLevel.state ? 'Kerala District Leaderboard' : '$_selectedDistrict Station Readings',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20, color: Color(0xFFE2E8F0)),
                if (displayedStations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No active stations found for selected filters in $_selectedDistrict.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  )
                else
                  ...displayedStations.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final s = entry.value;
                    final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
                    String valStr = '0.0 mm';
                    if (obs != null) {
                      if (_selectedParam == 'Temperature') {
                        valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC} °C' : '—';
                      } else if (_selectedParam == 'Humidity') {
                        valStr = obs.humidityPercent != null ? '${obs.humidityPercent} %' : '—';
                      } else if (_selectedParam == 'River Level') {
                        valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM} m' : '—';
                      } else if (_selectedParam == 'Rainfall') {
                        valStr = obs.rainfallMm != null ? '${obs.rainfallMm} mm' : '0.0 mm';
                      } else {
                        switch (s.instrumentType) {
                          case InstrumentType.hygrometer:
                            valStr = obs.humidityPercent != null ? '${obs.humidityPercent} %' : '—';
                            break;
                          case InstrumentType.maxMinThermometer:
                            valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC} °C' : '—';
                            break;
                          case InstrumentType.riverGauge:
                            valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM} m' : '—';
                            break;
                          case InstrumentType.rainGauge:
                          case InstrumentType.awsAutomaticStation:
                            valStr = obs.rainfallMm != null ? '${obs.rainfallMm} mm' : '0.0 mm';
                            break;
                        }
                      }
                    }

                    return _buildRankRow(
                      '$idx',
                      s.stationId,
                      '${s.gramaPanchayat.isNotEmpty ? s.gramaPanchayat : s.district}',
                      valStr,
                      const Color(0xFF2563EB),
                      () => _showStationDetailsDialog(context, s, state),
                    );
                  }),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Filter Toolbar Cards
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6)],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildFilterCard('Parameter', _selectedParam, ['All Parameters', 'Rainfall', 'Temperature', 'River Level', 'Humidity'], Icons.tune, (v) => setState(() => _selectedParam = v)),
                    if (widget.level != MapViewLevel.state && widget.level != MapViewLevel.station && allDistrictsList.isNotEmpty)
                      _buildFilterCard('District', _selectedDistrict, allDistrictsList, Icons.map_outlined, (v) => _onDistrictChanged(v, approved)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Section Header
              Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text('Home > Map View > ', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF146356), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),

              const SizedBox(height: 16),

              // 3. Main Map & Summary Grid
              if (isMobile) ...[
                mapWidget,
                const SizedBox(height: 16),
                summaryWidget,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: mapWidget),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: summaryWidget),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterCard(String label, String value, List<String> items, IconData icon, Function(String) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF146356)),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF334155))),
          DropdownButton<String>(
            value: items.contains(value) ? value : items.first,
            dropdownColor: Colors.white,
            underline: const SizedBox(),
            isDense: true,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildRankRow(String rank, String stationId, String loc, String val, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF64748B))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stationId, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text(loc, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11.5)),
            ),
          ],
        ),
      ),
    );
  }
}
