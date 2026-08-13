import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

enum MapViewLevel { state, district, taluk, panchayat, station }

class KsdmaMultiMapView extends StatefulWidget {
  final MapViewLevel level;

  const KsdmaMultiMapView({super.key, required this.level});

  @override
  State<KsdmaMultiMapView> createState() => _KsdmaMultiMapViewState();
}

class _KsdmaMultiMapViewState extends State<KsdmaMultiMapView> {
  late MapController _mapController;
  String _selectedDistrict = 'Alappuzha';
  String _selectedParam = 'Rainfall';
  String _selectedTimePeriod = 'Today';
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
    // Lazy load: fetch stations only when Map View opens
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
    if (widget.level == MapViewLevel.state) {
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
        return 9.5;
      case MapViewLevel.taluk:
        return 10.8;
      case MapViewLevel.panchayat:
        return 11.5;
      case MapViewLevel.station:
        return 12.2;
    }
  }

  void _onDistrictChanged(String newDist, List<KsdmaStation> approved) {
    setState(() {
      _selectedDistrict = newDist;
    });
    final newCenter = _getMapCenter(approved);
    _mapController.move(newCenter, _getMapZoom());
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final approved = state.stations;

    final dbDistricts = state.districtNames.isNotEmpty
        ? state.districtNames
        : _districtCoords.keys.toList();

    if (!dbDistricts.contains(_selectedDistrict) && dbDistricts.isNotEmpty) {
      _selectedDistrict = dbDistricts.first;
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

    // Filter displayed stations for local views
    final displayedStations = (widget.level == MapViewLevel.state)
        ? approved
        : approved.where((s) => s.district.toLowerCase() == _selectedDistrict.toLowerCase()).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 950;

        final mapWidget = Container(
          height: isMobile ? 380 : 480,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
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
                    MarkerLayer(
                      markers: (displayedStations.isNotEmpty ? displayedStations : approved).map((s) {
                        final obs = state.getTodayObservation(s.stationId);
                        final isApproved = s.approvalStatus == ApprovalStatus.approved;
                        final valStr = obs != null
                            ? s.instrumentType == InstrumentType.maxMinThermometer
                                ? '${obs.maxTemperatureC ?? 0.0}°C'
                                : s.instrumentType == InstrumentType.hygrometer
                                    ? '${obs.humidityPercent ?? 0.0}%'
                                    : s.instrumentType == InstrumentType.riverGauge
                                        ? '${obs.riverWaterLevelM ?? 0.0}m'
                                        : '${obs.rainfallMm ?? 0.0}mm'
                            : (isApproved ? '0.0mm' : 'Pending');

                        return Marker(
                          point: LatLng(s.latitude, s.longitude),
                          width: 95,
                          height: 32,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isApproved ? const Color(0xFF38BDF8) : Colors.amber, width: 1.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on, color: isApproved ? const Color(0xFF38BDF8) : Colors.amber, size: 12),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    '${s.stationId}: $valStr',
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                // Satellite Toggle
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isSatellite = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: !_isSatellite ? const Color(0xFF2563EB) : Colors.white,
                            child: Text('Map', style: TextStyle(fontSize: 11, color: !_isSatellite ? Colors.white : Colors.black87)),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => _isSatellite = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            color: _isSatellite ? const Color(0xFF2563EB) : Colors.white,
                            child: Text('Satellite', style: TextStyle(fontSize: 11, color: _isSatellite ? Colors.white : Colors.black87)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        final summaryWidget = Card(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.level == MapViewLevel.state ? 'Kerala District Summary' : '$_selectedDistrict Station List',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const Divider(height: 16),
                if (displayedStations.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(
                      child: Text('No active stations registered for $_selectedDistrict.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  )
                else
                  ...displayedStations.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final s = entry.value;
                    final obs = state.getTodayObservation(s.stationId);
                    final valStr = obs != null
                        ? s.instrumentType == InstrumentType.maxMinThermometer
                            ? '${obs.maxTemperatureC ?? 0.0} °C'
                            : '${obs.rainfallMm ?? 0.0} mm'
                        : '0.0 mm';
                    return _buildRankRow('$idx', '${s.stationId} (${s.gramaPanchayat.isNotEmpty ? s.gramaPanchayat : s.district})', valStr, const Color(0xFF2563EB));
                  }),
              ],
            ),
          ),
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildDrop('Parameter', _selectedParam, ['Rainfall', 'Temperature', 'River Level', 'Humidity'], (v) => setState(() => _selectedParam = v)),
                    _buildDrop('Time Period', _selectedTimePeriod, ['Today', '2 Days', '3 Days', '5 Days'], (v) => setState(() => _selectedTimePeriod = v)),
                    if (widget.level != MapViewLevel.state && dbDistricts.isNotEmpty)
                      _buildDrop('District', _selectedDistrict, dbDistricts, (v) => _onDistrictChanged(v, approved)),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Title & Breadcrumb
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Text('Home > Map View > ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),

              const SizedBox(height: 14),

              // Main Map & Summary Layout
              if (isMobile) ...[
                mapWidget,
                const SizedBox(height: 14),
                summaryWidget,
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: mapWidget),
                    const SizedBox(width: 14),
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

  Widget _buildDrop(String label, String value, List<String> items, [Function(String)? onChanged]) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        DropdownButton<String>(
          value: items.contains(value) ? value : items.first,
          underline: const SizedBox(),
          isDense: true,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 11)))).toList(),
          onChanged: (val) {
            if (val != null && onChanged != null) onChanged(val);
          },
        ),
      ],
    );
  }

  Widget _buildRankRow(String rank, String title, String val, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text('#$rank', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
