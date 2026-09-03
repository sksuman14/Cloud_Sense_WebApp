import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_aws_station_detail_view.dart';

enum MapViewLevel { state, district, taluk, panchayat }

class KsdmaMultiMapView extends StatefulWidget {
  final MapViewLevel level;

  const KsdmaMultiMapView({super.key, required this.level});

  @override
  State<KsdmaMultiMapView> createState() => _KsdmaMultiMapViewState();
}

class _KsdmaMultiMapViewState extends State<KsdmaMultiMapView> {
  late MapController _mapController;
  String _selectedDistrict = 'All Districts';
  String _selectedTaluk = 'All Taluks';
  String _selectedPanchayat = 'All Panchayats';
  String _selectedParam = 'All Parameters';
  bool _isSatellite = false;
  String _searchQuery = '';
  final TextEditingController _searchTextController = TextEditingController();

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
    _searchTextController.dispose();
    super.dispose();
  }

  LatLng _getMapCenter(List<KsdmaStation> approved) {
    if (widget.level == MapViewLevel.state || _selectedDistrict == 'All Districts') {
      return const LatLng(10.4505, 76.3711);
    }
    // 1. Panchayat center focus
    if (_selectedPanchayat != 'All Panchayats') {
      final pStns = approved.where((s) => s.gramaPanchayat.toLowerCase() == _selectedPanchayat.toLowerCase()).toList();
      if (pStns.isNotEmpty) return LatLng(pStns.first.latitude, pStns.first.longitude);
    }
    // 2. Taluk center focus
    if (_selectedTaluk != 'All Taluks') {
      final tStns = approved.where((s) => s.taluk.toLowerCase() == _selectedTaluk.toLowerCase()).toList();
      if (tStns.isNotEmpty) return LatLng(tStns.first.latitude, tStns.first.longitude);
    }
    // 3. District center focus
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
    if (_selectedPanchayat != 'All Panchayats') return 12.2;
    if (_selectedTaluk != 'All Taluks') return 10.8;
    if (_selectedDistrict != 'All Districts') return 9.5;

    switch (widget.level) {
      case MapViewLevel.state:
        return 7.5;
      case MapViewLevel.district:
        return 9.5;
      case MapViewLevel.taluk:
        return 10.8;
      case MapViewLevel.panchayat:
        return 12.2;
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

    final obs = state.getTodayObservation(s.stationId);
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.95,
            constraints: BoxConstraints(
              maxWidth: 680,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.sensors, color: Color(0xFF2563EB), size: 22),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFDCFCE7),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFF86EFAC)),
                                        ),
                                        child: const Text('LIVE TELEMETRY', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text('${s.gramaPanchayat}, ${s.taluk}, ${s.district} District • Lat: ${s.latitude.toStringAsFixed(4)}, Lng: ${s.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
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
                  const Divider(height: 20),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('⚡ Device Sensor Readings', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Updated: $timeStr', style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double cardWidth = constraints.maxWidth < 450
                          ? (constraints.maxWidth - 10) / 2
                          : 155.0;

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _buildMetricTile('Rainfall', rainStr, Icons.water_drop, const Color(0xFF2563EB), const Color(0xFFEFF6FF), width: cardWidth),
                          _buildMetricTile('Temperature', tempStr, Icons.thermostat, const Color(0xFFEA580C), const Color(0xFFFFEDD5), width: cardWidth),
                          _buildMetricTile('Humidity', humStr, Icons.opacity, const Color(0xFF7C3AED), const Color(0xFFF3E8FF), width: cardWidth),
                          _buildMetricTile('Atm. Pressure', pressStr, Icons.speed, const Color(0xFF0D9488), const Color(0xFFCCFBF1), width: cardWidth),
                          _buildMetricTile('Wind Speed', windSpdStr, Icons.air, const Color(0xFF0288D1), const Color(0xFFE0F2FE), width: cardWidth),
                          _buildMetricTile('Wind Direction', windDirStr, Icons.explore, const Color(0xFFD97706), const Color(0xFFFEF3C7), width: cardWidth),
                          _buildMetricTile('Wind Gust', windGustStr, Icons.cyclone, const Color(0xFF475569), const Color(0xFFF1F5F9), width: cardWidth),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
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
                        icon: const Icon(Icons.bar_chart, size: 15),
                        label: const Text('Show Detail Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      ),
                    ],
                  ),
                ],
              ),
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
    final obs = state.getTodayObservation(s.stationId);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
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
            Text('Owner: ${s.ownerName} (${s.ownerCategory.label})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 3),
            Text('Location: ${s.gramaPanchayat}, ${s.taluk}, ${s.district}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            Text('Instrument: ${s.instrumentType.displayName}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
            const Divider(height: 20, color: Color(0xFFE2E8F0)),
            const Text("Today's Reported Reading:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),
            if (obs != null) ...[
              if (obs.rainfallMm != null)
                Text('🌧 Rainfall: ${obs.rainfallMm} mm', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              if (obs.maxTemperatureC != null)
                Text('🌡 Max Temp: ${obs.maxTemperatureC} °C', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
              if (obs.minTemperatureC != null)
                Text('🌡 Min Temp: ${obs.minTemperatureC} °C', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFD97706))),
              if (obs.humidityPercent != null)
                Text('💧 Humidity: ${obs.humidityPercent} %', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
              if (obs.riverWaterLevelM != null)
                Text('🌊 River Level: ${obs.riverWaterLevelM} m', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0D9488))),
            ] else ...[
              const Text('⚠️ No reading submitted today.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7), foregroundColor: Colors.white),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, Color bg, {double? width}) {
    return Container(
      width: width ?? 155,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    // Exclude rejected stations completely
    final approved = state.stations.where((s) => s.approvalStatus != ApprovalStatus.rejected).toList();

    final List<String> allDistrictsList = [
      'All Districts',
      ...(state.districtNames.isNotEmpty ? state.districtNames : _districtCoords.keys.toList())
    ];

    if (_selectedDistrict != 'All Districts' && !allDistrictsList.contains(_selectedDistrict)) {
      _selectedDistrict = 'All Districts';
    }

    final title = widget.level == MapViewLevel.state
        ? 'Statewide Map View (Kerala)'
        : widget.level == MapViewLevel.district
            ? 'District Map View (${_selectedDistrict == 'All Districts' ? 'All 14 Districts' : _selectedDistrict})'
            : widget.level == MapViewLevel.taluk
                ? 'Taluk Map View (${_selectedTaluk == 'All Taluks' ? _selectedDistrict : '$_selectedDistrict → $_selectedTaluk'})'
                : 'Grama Panchayat Map View (${_selectedPanchayat == 'All Panchayats' ? _selectedDistrict : '$_selectedDistrict → $_selectedPanchayat'})';

    final subtitle = widget.level == MapViewLevel.state
        ? 'Comprehensive Overview Across All 14 Districts (${approved.length} Active Stations)'
        : widget.level == MapViewLevel.district
            ? 'District-Level Real-Time Telemetry & Sensor Network'
            : widget.level == MapViewLevel.taluk
                ? 'Sub-District Taluk Level Hydro-Meteorological Monitoring'
                : 'Local Micro-Level Grama Panchayat Sensor Network';

    final center = _getMapCenter(approved);
    final zoom = _getMapZoom();

    // 1. Strict Level & Cascading Administrative Boundary Filtering
    final effectiveBaseStations = approved.where((s) {
      if (widget.level == MapViewLevel.state) return true;

      if (_selectedDistrict != 'All Districts' && s.district.toLowerCase() != _selectedDistrict.toLowerCase()) {
        return false;
      }
      if ((widget.level == MapViewLevel.taluk || widget.level == MapViewLevel.panchayat) &&
          _selectedTaluk != 'All Taluks' &&
          s.taluk.toLowerCase() != _selectedTaluk.toLowerCase()) {
        return false;
      }
      if (widget.level == MapViewLevel.panchayat &&
          _selectedPanchayat != 'All Panchayats' &&
          s.gramaPanchayat.toLowerCase() != _selectedPanchayat.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();

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

    final searchFilteredStations = _searchQuery.isEmpty
        ? displayedStations
        : displayedStations.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.stationId.toLowerCase().contains(q) ||
                s.ownerName.toLowerCase().contains(q) ||
                s.district.toLowerCase().contains(q) ||
                s.taluk.toLowerCase().contains(q) ||
                s.gramaPanchayat.toLowerCase().contains(q) ||
                s.instrumentType.displayName.toLowerCase().contains(q);
          }).toList();

    // 3. Offset duplicate/overlapping coordinates so ALL markers at identical Lat/Lng are clearly visible & clickable
    final Map<String, List<KsdmaStation>> coordGroups = {};
    for (var s in searchFilteredStations) {
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

        final pinBg = _getPinColor(s);
        final pinIcon = _getPinIcon(s);

        markersList.add(
          Marker(
            point: LatLng(lat, lng),
            width: 36,
            height: 36,
            child: GestureDetector(
              onTap: () => _showStationDetailsDialog(context, s, state),
              child: Tooltip(
                message: '${s.stationId} (${s.district})\nTap to view full telemetry',
                child: Container(
                  decoration: BoxDecoration(
                    color: pinBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Icon(pinIcon, color: Colors.white, size: 18),
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
        final double equalHeight = isMobile ? 440.0 : 620.0;

        final mapWidget = Container(
          height: equalHeight,
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

                // Device Search Overlay Bar
                Positioned(
                  top: 10,
                  left: 10,
                  right: isMobile ? 120 : 160,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, size: 18, color: Color(0xFF2563EB)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchTextController,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                decoration: const InputDecoration(
                                  hintText: '🔍 Search device by ID, name, district...',
                                  hintStyle: TextStyle(fontSize: 11, color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: Colors.grey),
                                onPressed: () {
                                  _searchTextController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              ),
                          ],
                        ),
                      ),
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                          ),
                          child: Builder(
                            builder: (context) {
                              final matches = approved.where((s) {
                                final q = _searchQuery.toLowerCase();
                                return s.stationId.toLowerCase().contains(q) ||
                                    s.ownerName.toLowerCase().contains(q) ||
                                    s.district.toLowerCase().contains(q) ||
                                    s.taluk.toLowerCase().contains(q) ||
                                    s.gramaPanchayat.toLowerCase().contains(q) ||
                                    s.instrumentType.displayName.toLowerCase().contains(q);
                              }).take(6).toList();

                              if (matches.isEmpty) {
                                return const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Text('No devices found matching query', style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: matches.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final s = matches[idx];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.sensors, size: 16, color: Color(0xFF2563EB)),
                                    title: Text('${s.stationId} (${s.ownerName.isNotEmpty ? s.ownerName : s.instrumentType.displayName})', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                                    subtitle: Text('${s.gramaPanchayat}, ${s.taluk}, ${s.district}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    onTap: () {
                                      _mapController.move(LatLng(s.latitude, s.longitude), 13.5);
                                      setState(() {
                                        _searchTextController.text = s.stationId;
                                        _searchQuery = s.stationId;
                                      });
                                      _showStationDetailsDialog(context, s, state);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
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

        final summaryWidget = Container(
          height: equalHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
          ),
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
              Expanded(
                child: displayedStations.isEmpty
                    ? const Center(
                        child: Text('No active stations found for selected filters.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: displayedStations.asMap().entries.map((entry) {
                            final idx = entry.key + 1;
                            final s = entry.value;
                            final obs = state.getTodayObservation(s.stationId);
                            String valStr = 'No Report Today';
                            Color bColor = const Color(0xFF64748B);

                            if (obs != null) {
                              if (_selectedParam == 'Temperature') {
                                if (obs.maxTemperatureC != null && obs.minTemperatureC != null) {
                                  valStr = '🌡 Max: ${obs.maxTemperatureC}°C  Min: ${obs.minTemperatureC}°C';
                                } else if (obs.maxTemperatureC != null) {
                                  valStr = '🌡 Max Temp: ${obs.maxTemperatureC}°C';
                                } else {
                                  valStr = '—';
                                }
                                bColor = const Color(0xFFEA580C);
                              } else if (_selectedParam == 'Humidity') {
                                valStr = obs.humidityPercent != null ? '💧 ${obs.humidityPercent}%' : '—';
                                bColor = const Color(0xFF7C3AED);
                              } else if (_selectedParam == 'River Level') {
                                valStr = obs.riverWaterLevelM != null ? '🌊 ${obs.riverWaterLevelM}m' : '—';
                                bColor = const Color(0xFF0D9488);
                              } else if (_selectedParam == 'Rainfall') {
                                valStr = obs.rainfallMm != null ? '🌧 ${obs.rainfallMm}mm' : '0.0mm';
                                bColor = const Color(0xFF2563EB);
                              } else {
                                // All Parameters -> AWS Weather Station vs Single Instrument
                                final bool isAws = s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
                                if (isAws) {
                                  final List<String> parts = [];
                                  if (obs.rainfallMm != null) parts.add('🌧 ${obs.rainfallMm}mm');
                                  if (obs.maxTemperatureC != null && obs.minTemperatureC != null) {
                                    parts.add('🌡 Max: ${obs.maxTemperatureC}°C / Min: ${obs.minTemperatureC}°C');
                                  } else if (obs.maxTemperatureC != null) {
                                    parts.add('🌡 Max: ${obs.maxTemperatureC}°C');
                                  }
                                  if (obs.humidityPercent != null) parts.add('💧 ${obs.humidityPercent}%');
                                  valStr = parts.isNotEmpty ? parts.join('  ') : 'AWS Active';
                                  bColor = const Color(0xFF0284C7);
                                } else {
                                  switch (s.instrumentType) {
                                    case InstrumentType.hygrometer:
                                      valStr = obs.humidityPercent != null ? '💧 ${obs.humidityPercent}%' : '—';
                                      bColor = const Color(0xFF7C3AED);
                                      break;
                                    case InstrumentType.maxMinThermometer:
                                      if (obs.maxTemperatureC != null && obs.minTemperatureC != null) {
                                        valStr = '🌡 Max: ${obs.maxTemperatureC}°C / Min: ${obs.minTemperatureC}°C';
                                      } else if (obs.maxTemperatureC != null) {
                                        valStr = '🌡 Max: ${obs.maxTemperatureC}°C';
                                      } else {
                                        valStr = '—';
                                      }
                                      bColor = const Color(0xFFEA580C);
                                      break;
                                    case InstrumentType.riverGauge:
                                      valStr = obs.riverWaterLevelM != null ? '🌊 ${obs.riverWaterLevelM}m' : '—';
                                      bColor = const Color(0xFF0D9488);
                                      break;
                                    case InstrumentType.rainGauge:
                                    default:
                                      valStr = obs.rainfallMm != null ? '🌧 ${obs.rainfallMm}mm' : '0.0mm';
                                      bColor = const Color(0xFF2563EB);
                                      break;
                                  }
                                }
                              }
                            }

                            return _buildRankRow(
                              '$idx',
                              s.stationId,
                              '${s.gramaPanchayat.isNotEmpty ? s.gramaPanchayat : s.district}',
                              valStr,
                              bColor,
                              () => _showStationDetailsDialog(context, s, state),
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Cascading Administrative Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6)],
                ),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Parameter Filter
                    _buildFilterCard(
                      'Parameter',
                      _selectedParam,
                      ['All Parameters', 'Rainfall', 'Temperature', 'River Level', 'Humidity'],
                      Icons.tune,
                      (v) => setState(() => _selectedParam = v),
                    ),

                    // Tier 1: District Filter (Shown for District, Taluk & Panchayat views)
                    if (widget.level != MapViewLevel.state)
                      _buildFilterCard(
                        'District',
                        _selectedDistrict,
                        allDistrictsList,
                        Icons.map_outlined,
                        (v) {
                          setState(() {
                            _selectedDistrict = v;
                            _selectedTaluk = 'All Taluks';
                            _selectedPanchayat = 'All Panchayats';
                            state.selectedDistrict = v;
                            state.selectedTaluk = 'All Taluks';
                            state.selectedGramaPanchayat = 'All Panchayats';
                          });
                          _onDistrictChanged(v, approved);
                        },
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF146356).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF146356).withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public, size: 14, color: Color(0xFF146356)),
                            SizedBox(width: 6),
                            Text('State: Kerala (All 14 Districts)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF146356))),
                          ],
                        ),
                      ),

                    // Tier 2: Taluk Filter (Shown for Taluk & Panchayat views)
                    if (widget.level == MapViewLevel.taluk || widget.level == MapViewLevel.panchayat)
                      _buildFilterCard(
                        'Taluk',
                        _selectedTaluk,
                        ['All Taluks', ...state.getTaluksForDistrict(_selectedDistrict)],
                        Icons.location_city,
                        (v) {
                          setState(() {
                            _selectedTaluk = v;
                            _selectedPanchayat = 'All Panchayats';
                            state.selectedTaluk = v;
                            state.selectedGramaPanchayat = 'All Panchayats';
                          });
                          final newCenter = _getMapCenter(approved);
                          _mapController.move(newCenter, _getMapZoom());
                        },
                      ),

                    // Tier 3: Grama Panchayat Filter (Shown for Panchayat view)
                    if (widget.level == MapViewLevel.panchayat)
                      _buildFilterCard(
                        'Grama Panchayat',
                        _selectedPanchayat,
                        ['All Panchayats', ...state.getPanchayatsForTaluk(_selectedDistrict, _selectedTaluk)],
                        Icons.home_work_outlined,
                        (v) {
                          setState(() {
                            _selectedPanchayat = v;
                            state.selectedGramaPanchayat = v;
                          });
                          final newCenter = _getMapCenter(approved);
                          _mapController.move(newCenter, _getMapZoom());
                        },
                      ),
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

              const SizedBox(height: 20),

              // 4. Real-time Telemetry Summary Metric Cards
              _buildMapAnalyticalRow(displayedStations, state, isMobile),

              const SizedBox(height: 16),

              // 5. KSDMA Telemetry Export & Advisory Banner Card
              _buildKsdmaAdvisoryBanner(context, displayedStations, state, isMobile),
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
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Rank Number + Station ID + Location
            Row(
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
                Text(stationId, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '• $loc',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),

            // Bottom Row: Telemetry Pill Badge below in next line
            Padding(
              padding: const EdgeInsets.only(left: 30.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPinColor(KsdmaStation s) {
    if (s.category == StationCategory.aws) return const Color(0xFF8E24AA);
    switch (s.instrumentType) {
      case InstrumentType.rainGauge:
        return const Color(0xFF2563EB);
      case InstrumentType.maxMinThermometer:
        return const Color(0xFFEA580C);
      case InstrumentType.riverGauge:
        return const Color(0xFF0D9488);
      case InstrumentType.hygrometer:
        return const Color(0xFF7C3AED);
      case InstrumentType.awsAutomaticStation:
        return const Color(0xFF8E24AA);
    }
  }

  IconData _getPinIcon(KsdmaStation s) {
    if (s.category == StationCategory.aws) return Icons.cell_tower;
    switch (s.instrumentType) {
      case InstrumentType.rainGauge:
        return Icons.water_drop;
      case InstrumentType.maxMinThermometer:
        return Icons.thermostat;
      case InstrumentType.riverGauge:
        return Icons.waves;
      case InstrumentType.hygrometer:
        return Icons.opacity;
      case InstrumentType.awsAutomaticStation:
        return Icons.cell_tower;
    }
  }

  Widget _buildMapAnalyticalRow(List<KsdmaStation> stations, KsdmaStateService state, bool isMobile) {
    // 1. Max Rain Today
    double maxRain = -1;
    KsdmaStation? maxRainStn;
    // 2. Max Temp Today
    double maxTemp = -1;
    KsdmaStation? maxTempStn;
    // 3. Avg Humidity
    double totalHum = 0;
    int humCount = 0;
    // 4. Reporting stations count today
    int reportingTodayCount = 0;

    for (var s in stations) {
      final obs = state.getTodayObservation(s.stationId);
      if (obs != null) {
        reportingTodayCount++;
        if (obs.rainfallMm != null && obs.rainfallMm! > maxRain) {
          maxRain = obs.rainfallMm!;
          maxRainStn = s;
        }
        if (obs.maxTemperatureC != null && obs.maxTemperatureC! > maxTemp) {
          maxTemp = obs.maxTemperatureC!;
          maxTempStn = s;
        }
        if (obs.humidityPercent != null) {
          totalHum += obs.humidityPercent!;
          humCount++;
        }
      }
    }

    final double avgHum = humCount > 0 ? totalHum / humCount : 0;
    final int inactiveCount = stations.length - reportingTodayCount;
    final String reportingPct = stations.isEmpty ? '0%' : '${((reportingTodayCount / stations.length) * 100).toStringAsFixed(0)}%';

    final String humTitle = (_selectedDistrict == 'All Districts' || widget.level == MapViewLevel.state)
        ? 'Statewide Avg Humidity'
        : 'Avg Humidity';

    final cards = [
      _buildAnalyticalStatCard(
        title: 'Highest Rainfall Today',
        value: maxRainStn != null ? '${maxRain.toStringAsFixed(1)} mm' : '0.0 mm',
        subtitle: maxRainStn != null ? '${maxRainStn.stationId} (${maxRainStn.district})' : 'All Clear',
        icon: Icons.water_drop,
        color: const Color(0xFF2563EB),
      ),
      _buildAnalyticalStatCard(
        title: 'Highest Temperature Today',
        value: maxTempStn != null ? '${maxTemp.toStringAsFixed(1)} °C' : 'N/A',
        subtitle: maxTempStn != null ? '${maxTempStn.stationId} (${maxTempStn.district})' : 'Normal',
        icon: Icons.thermostat,
        color: const Color(0xFFEA580C),
      ),
      _buildAnalyticalStatCard(
        title: humTitle,
        value: humCount > 0 ? '${avgHum.toStringAsFixed(1)} %' : 'N/A',
        subtitle: 'Across $humCount Active Sensors',
        icon: Icons.opacity,
        color: const Color(0xFF7C3AED),
      ),
      _buildAnalyticalStatCard(
        title: 'Active Reporting Network',
        value: '$reportingTodayCount / ${stations.length}',
        subtitle: inactiveCount > 0 ? '$reportingPct Active ($inactiveCount Inactive)' : '100% Operational Status',
        icon: Icons.verified_user_outlined,
        color: reportingTodayCount == stations.length ? const Color(0xFF146356) : const Color(0xFFEA580C),
      ),
    ];

    if (isMobile) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: c)).toList(),
      );
    }

    return Row(
      children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList(),
    );
  }

  Widget _buildAnalyticalStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildKsdmaAdvisoryBanner(BuildContext context, List<KsdmaStation> stations, KsdmaStateService state, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F3D36), Color(0xFF146356)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x1A0F3D36), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'KSDMA Automated Hydro-Meteorological Portal',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Real-time automated telemetry data synced every 15 minutes across AWS, Rain Gauges, River Gauges, Thermometers, and Hygrometers for instant disaster preparedness.',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5, height: 1.4),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _exportMapDataCsv(context, stations, state),
                    icon: const Icon(Icons.download, size: 15),
                    label: const Text('Export Telemetry CSV Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F3D36),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            )
          : Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KSDMA Automated Hydro-Meteorological Monitoring Network',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Live telemetry auto-synced across ${stations.length} active stations for state disaster preparedness and early warnings.',
                        style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _exportMapDataCsv(context, stations, state),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export Telemetry Data (.CSV)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F3D36),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
    );
  }

  void _exportMapDataCsv(BuildContext context, List<KsdmaStation> stations, KsdmaStateService state) {
    final StringBuffer csv = StringBuffer();
    csv.writeln('Station ID,District,Taluk,Grama Panchayat,Instrument Type,Observation Date,Rainfall (mm),Max Temp (C),Min Temp (C),Humidity (%),River Level (m)');

    int count = 0;
    for (var s in stations) {
      final obs = state.getTodayObservation(s.stationId);
      final dateStr = obs != null ? "${obs.observationDate.year}-${obs.observationDate.month.toString().padLeft(2, '0')}-${obs.observationDate.day.toString().padLeft(2, '0')}" : 'No Report Today';

      csv.writeln(
        '"${s.stationId}","${s.district}","${s.taluk}","${s.gramaPanchayat}","${s.instrumentType.name}","${dateStr}",${obs?.rainfallMm ?? ""},${obs?.maxTemperatureC ?? ""},${obs?.minTemperatureC ?? ""},${obs?.humidityPercent ?? ""},${obs?.riverWaterLevelM ?? ""}'
      );
      count++;
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'KSDMA_Map_Telemetry_${_selectedDistrict.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF146356),
        content: Text('📥 Successfully downloaded CSV data for $count stations in $_selectedDistrict!'),
      ),
    );
  }
}
