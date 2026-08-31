import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';

class KsdmaGpMapView extends StatefulWidget {
  const KsdmaGpMapView({super.key});

  @override
  State<KsdmaGpMapView> createState() => _KsdmaGpMapViewState();
}

class _KsdmaGpMapViewState extends State<KsdmaGpMapView> {
  String _selectedParameter = 'Rainfall';
  String _selectedTimePeriod = 'Today';
  String _selectedDistrict = 'Kozhikode';
  bool _isSatellite = false;

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final approved = state.approvedStations;

    final dbDistricts = state.districtNames;
    if (dbDistricts.isNotEmpty && !dbDistricts.contains(_selectedDistrict)) {
      _selectedDistrict = dbDistricts.first;
    }

    final gpStations = approved.where((s) => s.district == _selectedDistrict).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Filter Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _buildInlineFilter('Parameter', Icons.water_drop_outlined, _selectedParameter, ['Rainfall', 'Temperature', 'River Level', 'Humidity'], (v) => setState(() => _selectedParameter = v)),
                _buildInlineFilter('Time Period', Icons.calendar_today_outlined, _selectedTimePeriod, ['Today', '2 Days', '3 Days', '5 Days'], (v) => setState(() => _selectedTimePeriod = v)),
                if (dbDistricts.isNotEmpty)
                  _buildInlineFilter('District', null, _selectedDistrict, dbDistricts, (v) => setState(() => _selectedDistrict = v)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 2. Title & Breadcrumbs Section
          const Text('Grama Panchayat View', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 2),
          Row(
            children: const [
              Text('Home > Map View > ', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('Grama Panchayat View', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text('District GP Level Live Weather Station Distribution in $_selectedDistrict', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),

          const SizedBox(height: 14),

          // 3. Map View Component
          Container(
            height: 520,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: gpStations.isNotEmpty
                          ? LatLng(gpStations.first.latitude, gpStations.first.longitude)
                          : (state.stations.isNotEmpty
                              ? LatLng(state.stations.first.latitude, state.stations.first.longitude)
                              : const LatLng(10.5276, 76.2144)),
                      initialZoom: 9.8,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _isSatellite
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'gov.kerala.ksdma.cloudsense',
                      ),
                      MarkerLayer(
                        markers: gpStations.map((s) {
                          final obs = state.getTodayObservation(s.stationId);
                          final valStr = obs != null ? '${obs.rainfallMm ?? 0} mm' : 'No Data';

                          return Marker(
                            point: LatLng(s.latitude, s.longitude),
                            width: 80,
                            height: 60,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade900,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    valStr,
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // Map Controls (Satellite Toggle)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                      child: IconButton(
                        icon: Icon(_isSatellite ? Icons.map : Icons.satellite_alt, color: const Color(0xFF2563EB)),
                        onPressed: () => setState(() => _isSatellite = !_isSatellite),
                        tooltip: 'Toggle Layer',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineFilter(String label, IconData? icon, String value, List<String> options, ValueChanged<String> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(width: 4),
        ],
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
        DropdownButton<String>(
          value: options.contains(value) ? value : options.first,
          underline: const SizedBox(),
          style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
          items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
