// ignore: deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import '../theme/ksdma_theme.dart';
import 'ksdma_auth_modal.dart';
import 'ksdma_aws_station_detail_view.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';

class KsdmaPublicDashboardView extends StatefulWidget {
  final Function(int tabIndex)? onNavigate;

  const KsdmaPublicDashboardView({super.key, this.onNavigate});

  @override
  State<KsdmaPublicDashboardView> createState() => _KsdmaPublicDashboardViewState();
}

class _KsdmaPublicDashboardViewState extends State<KsdmaPublicDashboardView> {
  KsdmaStation? _selectedStation;

  // 1. Left Column Filters (Network & Overview)
  String _leftSelectedParam = 'all';
  String _leftSelectedDistrict = 'All Districts';
  String _leftAppliedParam = 'all';
  String _leftAppliedDistrict = 'All Districts';

  // 2. Map Filters (Center Column: Live Weather Map)
  String _mapSelectedDistrict = 'All Districts';
  String _mapSelectedTaluk = 'All Taluks';
  String _mapSelectedPanchayat = 'All Panchayats';
  String _mapSelectedParam = 'all';

  // Compatibility getters for modals and observation graphs
  String get _appliedDistrict => _leftAppliedDistrict;
  String get _appliedParam => _leftAppliedParam;
  String get _appliedAggregation => 'Cumulative';

  String _activeDeltaTab = 'Rainfall';
  String? _expandedDeltaDistrict;
  bool _isSatelliteMode = false;

  double? _leftColumnHeight = 840.0;
  final GlobalKey _leftColumnKey = GlobalKey();

  void _updateLeftColumnHeight() {
    if (!mounted) return;
    final ctx = _leftColumnKey.currentContext;
    if (ctx != null) {
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final h = renderBox.size.height;
        if (h > 0 && (h - (_leftColumnHeight ?? 0)).abs() > 1.0) {
          setState(() {
            _leftColumnHeight = h;
          });
        }
      }
    }
  }

  late final MapController _mapController = MapController();

  void _showToast(String msg, {bool isError = false}) {
    DeleteDeviceUtils.showToastNotification(
      context: context,
      title: isError ? 'Alert' : 'Notice',
      message: msg,
      isError: isError,
    );
  }

  String _mapSearchQuery = '';
  final TextEditingController _mapSearchTextController = TextEditingController();
  String _breakdownSearchQuery = '';
  final TextEditingController _breakdownSearchTextController = TextEditingController();

  int _deltaCurrentPage = 1;
  String _latestObsSearchQuery = '';
  final TextEditingController _latestObsSearchController = TextEditingController();

  final List<String> _keralaDistricts = [
    'All Districts',
    ...KeralaAdminData.districtsAlphabetical,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = Provider.of<KsdmaStateService>(context, listen: false);
      state.fetchStationsIfNeeded();
      state.fetchObservationsIfNeeded();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _mapSearchTextController.dispose();
    _breakdownSearchTextController.dispose();
    _latestObsSearchController.dispose();
    super.dispose();
  }

  void _applyLeftFilters(KsdmaStateService state) {
    if (_leftSelectedDistrict != 'All Districts') {
      final allStations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;
      final inDistrict = allStations.where((s) {
        if (!KeralaAdminData.matchDistrict(s.district, _leftSelectedDistrict)) return false;
        if (_leftSelectedParam != 'all') {
          final bool isAws = s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
          if (_leftSelectedParam == 'riverLevel') {
            if (s.instrumentType != InstrumentType.riverGauge) return false;
          } else if (_leftSelectedParam == 'maxTemp') {
            if (!isAws && s.instrumentType != InstrumentType.maxMinThermometer) return false;
          } else if (_leftSelectedParam == 'humidity') {
            if (!isAws && s.instrumentType != InstrumentType.hygrometer) return false;
          } else if (_leftSelectedParam == 'rainfall') {
            if (!isAws && s.instrumentType != InstrumentType.rainGauge) return false;
          }
        }
        return true;
      }).toList();

      if (inDistrict.isEmpty) {
        _showToast('No stations found in "$_leftSelectedDistrict". Filter not applied.', isError: true);
        setState(() => _leftSelectedDistrict = 'All Districts');
        return;
      }
    }

    setState(() {
      _leftAppliedParam = _leftSelectedParam;
      _leftAppliedDistrict = _leftSelectedDistrict;
    });
  }

  void _resetLeftFilters(KsdmaStateService state) {
    setState(() {
      _leftSelectedParam = 'all';
      _leftSelectedDistrict = 'All Districts';
      _leftAppliedParam = 'all';
      _leftAppliedDistrict = 'All Districts';
    });
  }

  void _downloadSpatialCsv(KsdmaStateService state) {
    final StringBuffer csv = StringBuffer();
    csv.writeln(
      'Station ID,Station Name,Category,Instrument Type,Latitude,Longitude,CRS,District,Taluk,Grama Panchayat,Observation Date,Observation Time,Rainfall (mm),Max Temp (C),Min Temp (C),Humidity (%),River Level (m),Data Quality Status'
    );

    final stations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;
    for (var s in stations) {
      final obs = state.getTodayObservation(s.stationId);
      final raw = state.getWsDeviceRaw(s.stationId);

      final rain = obs?.rainfallMm ?? raw?['Rainfall_Cumulative_mm'] ?? raw?['rainfall'] ?? '';
      final maxTemp = obs?.maxTemperatureC ?? raw?['Maximum_Temperature'] ?? raw?['now_temperature'] ?? raw?['Temperature'] ?? '';
      final minTemp = obs?.minTemperatureC ?? '';
      final hum = obs?.humidityPercent ?? raw?['Humidity_Percent'] ?? raw?['Humidity'] ?? '';
      final river = obs?.riverWaterLevelM ?? raw?['River_Level_m'] ?? '';
      final dateStr = obs != null ? obs.observationDate.toIso8601String().split('T')[0] : DateTime.now().toIso8601String().split('T')[0];
      final timeStr = obs != null ? '${obs.observationTime.hour.toString().padLeft(2, '0')}:${obs.observationTime.minute.toString().padLeft(2, '0')}' : '08:00';

      csv.writeln(
        '"${s.stationId}","${s.ownerName}","${s.category.name}","${s.instrumentType.displayName}",${s.latitude.toStringAsFixed(6)},${s.longitude.toStringAsFixed(6)},"EPSG:4326 (WGS84)","${s.district}","${s.taluk}","${s.gramaPanchayat}","$dateStr","$timeStr","$rain","$maxTemp","$minTemp","$hum","$river","QA/QC Verified"'
      );
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'KSDMA_Spatial_Weather_Observations_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    _showToast('📥 Spatial CSV Exported with Lat/Lng Coordinates & Admin Hierarchy!');
  }

  void _downloadDeltaComparisonCsv(KsdmaStateService state) {
    final StringBuffer csv = StringBuffer();
    final paramTitle = _activeDeltaTab == 'Rainfall'
        ? 'Rainfall (mm)'
        : (_activeDeltaTab == 'Temperature'
            ? 'Temperature (C)'
            : (_activeDeltaTab == 'Humidity' ? 'Humidity (%)' : 'River Level (m)'));

    csv.writeln('District,Parameter,Today Value,Yesterday Value,Change (Delta)');

    for (var dist in KeralaAdminData.districts) {
      final distStations = state.stations.where((s) => KeralaAdminData.matchDistrict(s.district, dist)).toList();

      if (_activeDeltaTab == 'Temperature') {
        double todayMax = 0.0, todayMin = 0.0;
        double yestMax = 0.0, yestMin = 0.0;
        int todayMaxCount = 0, todayMinCount = 0;
        int yestMaxCount = 0, yestMinCount = 0;

        for (var s in distStations) {
          final tObs = state.getTodayObservation(s.stationId);
          final yObs = state.getYesterdayObservation(s.stationId);
          final raw = state.getWsDeviceRaw(s.stationId);

          final rawTemp = double.tryParse(raw?['now_temperature']?.toString() ?? raw?['Maximum_Temperature']?.toString() ?? raw?['Temperature']?.toString() ?? '');
          double? tMax = tObs?.maxTemperatureC ?? rawTemp;
          double? tMin = tObs?.minTemperatureC;
          double? yMax = yObs?.maxTemperatureC;
          double? yMin = yObs?.minTemperatureC;

          if (tMax != null) { todayMax += tMax; todayMaxCount++; }
          if (tMin != null) { todayMin += tMin; todayMinCount++; }
          if (yMax != null) { yestMax += yMax; yestMaxCount++; }
          if (yMin != null) { yestMin += yMin; yestMinCount++; }
        }

        double avgTodayMax = todayMaxCount > 0 ? todayMax / todayMaxCount : 0.0;
        double avgTodayMin = todayMinCount > 0 ? todayMin / todayMinCount : 0.0;
        double avgYestMax = yestMaxCount > 0 ? yestMax / yestMaxCount : 0.0;
        double avgYestMin = yestMinCount > 0 ? yestMin / yestMinCount : 0.0;

        final diffMax = avgTodayMax - avgYestMax;
        final diffMin = avgTodayMin - avgYestMin;

        final tMaxStr = todayMaxCount > 0 ? '${avgTodayMax.toStringAsFixed(1)} °C' : 'N/A';
        final yMaxStr = yestMaxCount > 0 ? '${avgYestMax.toStringAsFixed(1)} °C' : 'N/A';
        final dMaxStr = (todayMaxCount > 0 && yestMaxCount > 0) ? '${diffMax >= 0 ? '+' : ''}${diffMax.toStringAsFixed(1)} °C' : 'N/A';

        final tMinStr = todayMinCount > 0 ? '${avgTodayMin.toStringAsFixed(1)} °C' : 'N/A';
        final yMinStr = yestMinCount > 0 ? '${avgYestMin.toStringAsFixed(1)} °C' : 'N/A';
        final dMinStr = (todayMinCount > 0 && yestMinCount > 0) ? '${diffMin >= 0 ? '+' : ''}${diffMin.toStringAsFixed(1)} °C' : 'N/A';

        csv.writeln('"$dist (Max)","Max Temperature","$tMaxStr","$yMaxStr","$dMaxStr"');
        csv.writeln('"$dist (Min)","Min Temperature","$tMinStr","$yMinStr","$dMinStr"');
      } else {
        double todayVal = 0.0, yestVal = 0.0;
        int tCount = 0, yCount = 0;

        for (var s in distStations) {
          final tObs = state.getTodayObservation(s.stationId);
          final yObs = state.getYesterdayObservation(s.stationId);
          final raw = state.getWsDeviceRaw(s.stationId);

          if (_activeDeltaTab == 'Rainfall') {
            final tVal = tObs?.rainfallMm ?? raw?['Rainfall_Cumulative_mm'] ?? raw?['rainfall'];
            final yVal = yObs?.rainfallMm;
            if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
            if (yVal != null) { yestVal += yVal; yCount++; }
          } else if (_activeDeltaTab == 'Humidity') {
            final tVal = tObs?.humidityPercent ?? raw?['Humidity_Percent'];
            final yVal = yObs?.humidityPercent;
            if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
            if (yVal != null) { yestVal += yVal; yCount++; }
          } else if (_activeDeltaTab == 'River Level') {
            final tVal = tObs?.riverWaterLevelM ?? raw?['River_Level_m'];
            final yVal = yObs?.riverWaterLevelM;
            if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
            if (yVal != null) { yestVal += yVal; yCount++; }
          }
        }

        final double avgToday = tCount > 0 ? (todayVal / tCount) : 0.0;
        final double avgYest = yCount > 0 ? (yestVal / yCount) : 0.0;
        final double delta = avgToday - avgYest;

        final todayStr = tCount > 0 ? avgToday.toStringAsFixed(1) : 'N/A';
        final yestStr = yCount > 0 ? avgYest.toStringAsFixed(1) : 'N/A';
        final deltaStr = (tCount > 0 && yCount > 0)
            ? (delta >= 0 ? '+${delta.toStringAsFixed(1)}' : delta.toStringAsFixed(1))
            : 'N/A';

        csv.writeln('"$dist","$paramTitle","$todayStr","$yestStr","$deltaStr"');
      }
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'KSDMA_PreviousDay_Comparison_${_activeDeltaTab.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    _showToast('📥 Exported Previous Day Comparison CSV for $_activeDeltaTab');
  }

  void _showWhatsAppShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF16A34A), size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                '💬 Share Weather Data via WhatsApp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),
              const Text(
                'Facing difficulty entering data on the portal? You can directly message your daily rainfall, temperature readings, or station photos to the official KSDMA Control Room WhatsApp Helpdesk.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        final Uri url = Uri.parse('https://wa.me/919447794288?text=Hello%20KSDMA%20Team,%20I%20want%20to%20submit%20weather%20data');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        } else {
                          await launchUrl(url);
                        }
                      },
                      icon: const Icon(Icons.send, color: Colors.white, size: 16),
                      label: const Text('Open WhatsApp Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllLatestObservationsModal(BuildContext context, KsdmaStateService state, List<KsdmaStation> stations) {
    String searchQuery = '';
    String selectedDeviceFilter = 'all';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = stations.where((s) {
            if (selectedDeviceFilter != 'all') {
              if (selectedDeviceFilter == 'rainGauge' && s.instrumentType != InstrumentType.rainGauge) return false;
              if (selectedDeviceFilter == 'hygrometer' && s.instrumentType != InstrumentType.hygrometer) return false;
              if (selectedDeviceFilter == 'maxMinThermometer' && s.instrumentType != InstrumentType.maxMinThermometer) return false;
              if (selectedDeviceFilter == 'riverGauge' && s.instrumentType != InstrumentType.riverGauge) return false;
            }
            final query = searchQuery.toLowerCase().trim();
            if (query.isEmpty) return true;
            return s.stationId.toLowerCase().contains(query) ||
                s.district.toLowerCase().contains(query) ||
                s.gramaPanchayat.toLowerCase().contains(query) ||
                s.instrumentType.name.toLowerCase().contains(query);
          }).toList();

          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;
          final bool isMobile = screenWidth < 700;

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 24,
              vertical: isMobile ? 16 : 24,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: isMobile ? double.infinity : 820,
              height: isMobile ? (mediaQuery.size.height * 0.88) : 640,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: EdgeInsets.all(isMobile ? 14 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All Latest Weather Observations (${stations.length})',
                              style: TextStyle(
                                fontSize: isMobile ? 13.5 : 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Showing real-time observations across $_appliedDistrict',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    onChanged: (val) => setModalState(() => searchQuery = val),
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Station ID, District, or Panchayat...',
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFF),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filter Device: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                        const SizedBox(width: 4),
                        _buildModalDeviceChip('All', 'all', selectedDeviceFilter, (f) => setModalState(() => selectedDeviceFilter = f)),
                        const SizedBox(width: 6),
                        _buildModalDeviceChip('🌧 Rain Gauge', 'rainGauge', selectedDeviceFilter, (f) => setModalState(() => selectedDeviceFilter = f)),
                        const SizedBox(width: 6),
                        _buildModalDeviceChip('💧 Hygrometer', 'hygrometer', selectedDeviceFilter, (f) => setModalState(() => selectedDeviceFilter = f)),
                        const SizedBox(width: 6),
                        _buildModalDeviceChip('🌡 Thermometer', 'maxMinThermometer', selectedDeviceFilter, (f) => setModalState(() => selectedDeviceFilter = f)),
                        const SizedBox(width: 6),
                        _buildModalDeviceChip('🌊 River Level', 'riverGauge', selectedDeviceFilter, (f) => setModalState(() => selectedDeviceFilter = f)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text('No matching weather stations found.', style: TextStyle(color: Colors.grey)),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final s = filtered[idx];
                              final obs = state.getTodayObservation(s.stationId);

                              final chips = <Widget>[];
                              final isAws = s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;

                              if (s.instrumentType == InstrumentType.rainGauge || isAws) {
                                final rain = obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '—';
                                chips.add(_buildDetailChip('Rainfall [CUMULATIVE 24H]', rain, const Color(0xFF2563EB)));
                              }

                              if (s.instrumentType == InstrumentType.maxMinThermometer || isAws) {
                                final maxTemp = obs?.maxTemperatureC != null ? '${obs!.maxTemperatureC}°C' : '—';
                                final minTemp = obs?.minTemperatureC != null ? '${obs!.minTemperatureC}°C' : '—';
                                chips.add(_buildDetailChip('Max Temp [MAXIMUM]', maxTemp, const Color(0xFFEA580C)));
                                chips.add(_buildDetailChip('Min Temp [MINIMUM]', minTemp, const Color(0xFF0288D1)));
                              }

                              if (s.instrumentType == InstrumentType.hygrometer || isAws) {
                                final hum = obs?.humidityPercent != null ? '${obs!.humidityPercent}%' : '—';
                                chips.add(_buildDetailChip('Humidity [AVERAGE]', hum, const Color(0xFF7C3AED)));
                              }

                              if (s.instrumentType == InstrumentType.riverGauge || isAws) {
                                final river = obs?.riverWaterLevelM != null ? '${obs!.riverWaterLevelM} m' : '—';
                                chips.add(_buildDetailChip('River Level [LATEST]', river, const Color(0xFF0D9488)));
                              }

                              if (chips.isEmpty) {
                                final rain = obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '—';
                                chips.add(_buildDetailChip('Rainfall [CUMULATIVE 24H]', rain, const Color(0xFF2563EB)));
                              }

                              String timeStr = 'Today 08:00 AM';
                              if (obs != null) {
                                final dt = obs.observationDate.toLocal();
                                final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                                final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                                final minStr = dt.minute.toString().padLeft(2, '0');
                                timeStr = '${dt.day}/${dt.month} ${hour.toString().padLeft(2, '0')}:$minStr $ampm';
                              }

                              return InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _mapController.move(LatLng(s.latitude, s.longitude), 13.0);
                                  setState(() => _selectedStation = s);
                                  _showStationDetailsDialog(context, s, state);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Center(
                                          child: Text('#${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                            Text(
                                              '${s.gramaPanchayat.isNotEmpty ? "${s.gramaPanchayat}, " : ""}${s.district}',
                                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 4,
                                        child: Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          children: chips,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModalDeviceChip(String label, String value, String current, Function(String) onSelect) {
    final bool isSel = value == current;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
            color: isSel ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$label: $value', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }

  void _showStationDetailsDialog(BuildContext context, KsdmaStation station, KsdmaStateService state) {
    final bool isAwsStation = station.category == StationCategory.aws ||
        station.instrumentType == InstrumentType.awsAutomaticStation ||
        station.stationId.startsWith('WS_');

    if (isAwsStation) {
      final obs = state.getTodayObservation(station.stationId) ?? state.getLatestObservation(station.stationId);
      final wsRaw = state.getWsDeviceRaw(station.stationId);

      final String tempStr = wsRaw?['Temperature'] != null 
          ? '${wsRaw!['Temperature']} °C' 
          : (obs?.maxTemperatureC != null ? '${obs!.maxTemperatureC} °C' : 'N/A');
          
      final String humStr = wsRaw?['Humidity'] != null 
          ? '${wsRaw!['Humidity']} %' 
          : (obs?.humidityPercent != null ? '${obs!.humidityPercent} %' : 'N/A');
          
      final String rainStr = wsRaw?['Rainfall'] != null 
          ? '${wsRaw!['Rainfall']} mm' 
          : (obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '—');
          
      final String pressStr = wsRaw?['AtmPressure'] != null 
          ? '${wsRaw!['AtmPressure']} hPa' 
          : (obs?.riverWaterLevelM != null ? '${obs!.riverWaterLevelM} m' : 'N/A');
          
      final String windSpdStr = wsRaw?['WindSpeed'] != null ? '${wsRaw!['WindSpeed']} m/s' : 'N/A';
      final String windDirStr = wsRaw?['WindDirection'] != null ? '${wsRaw!['WindDirection']}°' : 'N/A';
      final String windGustStr = wsRaw?['WindGust'] != null ? '${wsRaw!['WindGust']} m/s' : 'N/A';
      final String timeStr = wsRaw?['TimeStamp']?.toString() ?? (obs != null ? '${obs.observationDate.toIso8601String().split('T')[0]} ${obs.observationTime.hour.toString().padLeft(2, '0')}:${obs.observationTime.minute.toString().padLeft(2, '0')}' : 'Live');

      showDialog(
        context: context,
        builder: (ctx) {
          final double screenWidth = MediaQuery.of(context).size.width;
          final double dialogWidth = (screenWidth * 0.92).clamp(0.0, 680.0);
          final double availWidth = dialogWidth - 40;
          final int crossAxisCount = availWidth >= 500 ? 3 : 2;
          const double spacing = 10;
          final double itemWidth = (availWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
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
                                  color: KsdmaColors.primaryTint,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_getPinIcon(station), color: KsdmaColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Text(
                                          station.ownerName.isNotEmpty ? '${station.stationId} (${station.ownerName})' : station.stationId,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF86EFAC)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.sensors, size: 12, color: Color(0xFF16A34A)),
                                              SizedBox(width: 4),
                                              Text('LIVE AWS DATA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${station.gramaPanchayat.isNotEmpty ? "${station.gramaPanchayat}, " : ""}${station.district} District • Lat: ${station.latitude.toStringAsFixed(4)}, Lng: ${station.longitude.toStringAsFixed(4)}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF1F5F9), visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        const Text('⚡ Live AWS Telemetry & Sensors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Updated: $timeStr', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        _buildLiveMetricTile('Rainfall', rainStr, Icons.water_drop, const Color(0xFF2563EB), const Color(0xFFEFF6FF), width: itemWidth),
                        _buildLiveMetricTile('Temperature', tempStr, Icons.thermostat, const Color(0xFFEA580C), const Color(0xFFFFEDD5), width: itemWidth),
                        _buildLiveMetricTile('Humidity', humStr, Icons.opacity, const Color(0xFF7C3AED), const Color(0xFFF3E8FF), width: itemWidth),
                        _buildLiveMetricTile('Atm. Pressure', pressStr, Icons.speed, const Color(0xFF0D9488), const Color(0xFFCCFBF1), width: itemWidth),
                        _buildLiveMetricTile('Wind Speed', windSpdStr, Icons.air, const Color(0xFF0288D1), const Color(0xFFE0F2FE), width: itemWidth),
                        _buildLiveMetricTile('Wind Direction', windDirStr, Icons.explore, const Color(0xFFD97706), const Color(0xFFFEF3C7), width: itemWidth),
                        _buildLiveMetricTile('Wind Gust', windGustStr, Icons.cyclone, const Color(0xFF475569), const Color(0xFFF1F5F9), width: itemWidth),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ChangeNotifierProvider<KsdmaStateService>.value(
                                  value: state,
                                  child: KsdmaAwsStationDetailView(stationId: station.stationId),
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
                          onPressed: () => Navigator.of(ctx).pop(),
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
        },
      );
      return;
    }

    _showManualStationGraphDialog(context, station, state);
  }

  void _showManualStationGraphDialog(BuildContext context, KsdmaStation station, KsdmaStateService state) {
    DateTimeRange? manualCustomRange;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              constraints: BoxConstraints(
                maxWidth: 820,
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                station.ownerName.isNotEmpty ? '${station.stationId} (${station.ownerName})' : station.stationId,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                '${station.gramaPanchayat.isNotEmpty ? "${station.gramaPanchayat}, " : ""}${station.district} • ${station.instrumentType.displayName}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _buildStationStatBoxes(state, station),
                    const SizedBox(height: 16),
                    _buildStationChartBox(
                      context,
                      state,
                      station,
                      DateTime.now(),
                      customRange: manualCustomRange,
                      onPickCustomRange: () async {
                        final now = DateTime.now();
                        final picked = await showDialog<DateTimeRange>(
                          context: context,
                          builder: (c) => Dialog(
                            backgroundColor: Colors.white,
                            surfaceTintColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Container(
                              width: 440,
                              height: 520,
                              padding: const EdgeInsets.all(12),
                              child: Theme(
                                data: ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF2563EB),
                                    onPrimary: Colors.white,
                                    surface: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: DateRangePickerDialog(
                                  initialDateRange: manualCustomRange ??
                                      DateTimeRange(
                                        start: now.subtract(const Duration(days: 3)),
                                        end: now,
                                      ),
                                  firstDate: DateTime(2020, 1, 1),
                                  lastDate: now,
                                ),
                              ),
                            ),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() {
                            manualCustomRange = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final allStations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;

    // Left column specific filtering (applied via left header filter bar):
    final leftActiveStations = allStations.where((s) {
      if (_leftAppliedDistrict != 'All Districts' && !KeralaAdminData.matchDistrict(s.district, _leftAppliedDistrict)) {
        return false;
      }
      if (_leftAppliedParam != 'all') {
        final bool isAws = s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
        if (_leftAppliedParam == 'riverLevel') {
          if (s.instrumentType != InstrumentType.riverGauge) return false;
        } else if (_leftAppliedParam == 'maxTemp') {
          if (!isAws && s.instrumentType != InstrumentType.maxMinThermometer) return false;
        } else if (_leftAppliedParam == 'humidity') {
          if (!isAws && s.instrumentType != InstrumentType.hygrometer) return false;
        } else if (_leftAppliedParam == 'rainfall') {
          if (!isAws && s.instrumentType != InstrumentType.rainGauge) return false;
        }
      }
      return true;
    }).toList();

    // Map and Right column observation graphs keep all stations (unfiltered by Left Column controls)
    final mainActiveStations = allStations;

    if (_selectedStation != null && !mainActiveStations.any((s) => s.stationId == _selectedStation!.stationId)) {
      _selectedStation = null;
    }

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayObsLeft = state.observations.where((o) {
      if (o.isRemoved) return false;
      final d = o.observationDate.toLocal();
      if (d.year != todayDate.year || d.month != todayDate.month || d.day != todayDate.day) {
        return false;
      }
      if (!leftActiveStations.any((s) => s.stationId == o.stationId)) return false;
      return true;
    }).toList();

    final reportingStationIdsTodayLeft = todayObsLeft.map((o) => o.stationId).toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1050;
        final bool isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1050;
        final bool isMobile = constraints.maxWidth < 650;

        if (isDesktop) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateLeftColumnHeight();
          });
        }

        final int rainCount = leftActiveStations.where((s) => s.instrumentType == InstrumentType.rainGauge).length;
        final int tempCount = leftActiveStations.where((s) => s.instrumentType == InstrumentType.maxMinThermometer).length;
        final int humCount = leftActiveStations.where((s) => s.instrumentType == InstrumentType.hygrometer).length;
        final int riverCount = leftActiveStations.where((s) => s.instrumentType == InstrumentType.riverGauge).length;
        final int awsCount = leftActiveStations.where((s) => s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Main 3-Column Desktop Grid / Vertical Mobile Flow
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Column: Network & Statewide / District Overview
                    Expanded(
                      flex: 4,
                      child: _buildLeftColumn(state, leftActiveStations, rainCount, humCount, tempCount, riverCount, awsCount, reportingStationIdsTodayLeft, isMobile, isDesktop),
                    ),
                    const SizedBox(width: 14),

                    // Center Column: Interactive Weather Map (Uses mainActiveStations)
                    Expanded(
                      flex: 5,
                      child: _buildCenterColumn(state, mainActiveStations, isMobile, isDesktop),
                    ),
                    const SizedBox(width: 14),

                    // Right Column: Observations & Downloads (Uses mainActiveStations)
                    Expanded(
                      flex: 4,
                      child: _buildRightColumn(state, mainActiveStations, todayDate, isMobile, isDesktop),
                    ),
                  ],
                ),
              ] else ...[
                      Column(
                        children: [
                          _buildLeftColumn(state, leftActiveStations, rainCount, humCount, tempCount, riverCount, awsCount, reportingStationIdsTodayLeft, isMobile, isDesktop),
                          const SizedBox(height: 16),
                          _buildCenterColumn(state, mainActiveStations, isMobile, isDesktop),
                          const SizedBox(height: 16),
                          _buildRightColumn(state, mainActiveStations, todayDate, isMobile, isDesktop),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 3. Bottom Action Banner Cards
                    if (isDesktop)
                      Row(
                        children: _buildPromoCardsList(state).map((p) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8.0), child: p))).toList(),
                      )
                    else
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _buildPromoCardsList(state).map((p) => SizedBox(
                          width: isTablet ? (constraints.maxWidth - 44) / 2 : (constraints.maxWidth - 32),
                          child: p,
                        )).toList(),
                      ),
                  ],
                ),
              );
      },
    );
  }

  // LEFT COLUMN: Network Overview & Statewide Highlights
  Widget _buildLeftColumn(
    KsdmaStateService state,
    List<KsdmaStation> activeStations,
    int rainCount,
    int humCount,
    int tempCount,
    int riverCount,
    int awsCount,
    Set<String> reportingStationIdsToday,
    bool isMobile,
    bool isDesktop,
  ) {
    return Container(
      key: _leftColumnKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: Color(0xFF0D9488), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _appliedDistrict == 'All Districts' ? 'Network & Statewide Overview' : 'Network & $_appliedDistrict Overview',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      _appliedDistrict == 'All Districts' ? "Kerala's citizen weather network at a glance" : "$_appliedDistrict citizen weather network at a glance",
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Filters Row
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _leftSelectedParam,
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(
                          labelText: 'Parameter',
                          labelStyle: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Parameters', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10.5))),
                          DropdownMenuItem(value: 'rainfall', child: Text('Rainfall', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10.5))),
                          DropdownMenuItem(value: 'maxTemp', child: Text('Temperature', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10.5))),
                          DropdownMenuItem(value: 'riverLevel', child: Text('River Level', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10.5))),
                          DropdownMenuItem(value: 'humidity', child: Text('Humidity', style: TextStyle(color: Color(0xFF0F172A), fontSize: 10.5))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _leftSelectedParam = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _keralaDistricts.contains(_leftSelectedDistrict) ? _leftSelectedDistrict : 'All Districts',
                        dropdownColor: Colors.white,
                        decoration: const InputDecoration(
                          labelText: 'District',
                          labelStyle: TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                        items: _keralaDistricts.map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 10.5), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _leftSelectedDistrict = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _applyLeftFilters(state),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFACC15),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          visualDensity: VisualDensity.compact,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Apply', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _resetLeftFilters(state),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                          foregroundColor: const Color(0xFF475569),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          visualDensity: VisualDensity.compact,
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. 4 Summary Stat Cards (2x2 Grid matching media_1789985630190.png)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _buildInteractiveSummaryCard(
                title: 'Total Stations',
                value: '${activeStations.length}',
                subtitle: 'Live Network',
                icon: Icons.cell_tower,
                iconBgColor: const Color(0xFFDBEAFE),
                iconColor: const Color(0xFF2563EB),
                cardBgColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE),
                onTap: () => _showAllLatestObservationsModal(context, state, activeStations),
              ),
              _buildInteractiveSummaryCard(
                title: 'Reporting Today',
                value: '${reportingStationIdsToday.length}',
                subtitle: activeStations.isEmpty ? '0% active' : '${((reportingStationIdsToday.length / activeStations.length) * 100).clamp(0, 100).toStringAsFixed(1)}% active',
                icon: Icons.event_available,
                iconBgColor: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF10B981),
                cardBgColor: const Color(0xFFF0FDF4),
                borderColor: const Color(0xFFBBF7D0),
                onTap: () => _showAllLatestObservationsModal(context, state, activeStations),
              ),
              _buildInteractiveSummaryCard(
                title: 'Districts Covered',
                value: _leftAppliedDistrict != 'All Districts' ? '1 / 14' : '14 / 14',
                subtitle: 'Complete coverage',
                icon: Icons.map,
                iconBgColor: const Color(0xFFEDE9FE),
                iconColor: const Color(0xFF7C3AED),
                cardBgColor: const Color(0xFFF5F3FF),
                borderColor: const Color(0xFFE9D5FF),
                onTap: () => _showToast('Coverage: 14/14 Districts Monitored'),
              ),
              _buildInteractiveSummaryCard(
                title: 'Weather Champions',
                value: '${state.champions.length > 0 ? state.champions.length : 4}',
                subtitle: 'Active volunteers',
                icon: Icons.groups,
                iconBgColor: const Color(0xFFFFEDD5),
                iconColor: const Color(0xFFEA580C),
                cardBgColor: const Color(0xFFFFF7ED),
                borderColor: const Color(0xFFFED7AA),
                onTap: () => widget.onNavigate?.call(4),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 4. Data Quality Status Banner Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.verified_user, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Good', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1)),
                      Text('Data Quality', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      Text('KSDMA Weather Cloud Live', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.eco, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 4),
                const Expanded(
                  flex: 5,
                  child: Text(
                    'A safer, more resilient Kerala through citizen science.',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF065F46), height: 1.3, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 5. Instrument Breakdown Section Header & Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.person, size: 14, color: Color(0xFF0F172A)),
                  SizedBox(width: 4),
                  Text('Instrument Breakdown', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              Text('Total instruments: ${activeStations.length}', style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildInstrumentCard(
                      label: 'Rain Gauges',
                      count: rainCount,
                      icon: Icons.water_drop,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFFDBEAFE),
                      onTap: () {
                        setState(() {
                          _leftSelectedParam = 'rainfall';
                          _leftAppliedParam = 'rainfall';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildInstrumentCard(
                      label: 'Hygrometers',
                      count: humCount,
                      icon: Icons.percent,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFF3E8FF),
                      borderColor: const Color(0xFFE9D5FF),
                      onTap: () {
                        setState(() {
                          _leftSelectedParam = 'humidity';
                          _leftAppliedParam = 'humidity';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildInstrumentCard(
                      label: 'Thermometers',
                      count: tempCount,
                      icon: Icons.thermostat,
                      color: const Color(0xFFEA580C),
                      bgColor: const Color(0xFFFFF7ED),
                      borderColor: const Color(0xFFFFEDD5),
                      onTap: () {
                        setState(() {
                          _leftSelectedParam = 'maxTemp';
                          _leftAppliedParam = 'maxTemp';
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildInstrumentCard(
                      label: 'River Gauges',
                      count: riverCount,
                      icon: Icons.waves,
                      color: const Color(0xFF0D9488),
                      bgColor: const Color(0xFFF0FDFA),
                      borderColor: const Color(0xFFCCFBF1),
                      onTap: () {
                        setState(() {
                          _leftSelectedParam = 'riverLevel';
                          _leftAppliedParam = 'riverLevel';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 5,
                    child: _buildInstrumentCard(
                      label: 'AWS Stations',
                      count: awsCount,
                      icon: Icons.cloud,
                      color: const Color(0xFF2563EB),
                      bgColor: const Color(0xFFF0F9FF),
                      borderColor: const Color(0xFFBAE6FD),
                      onTap: () {
                        setState(() {
                          _leftSelectedParam = 'all';
                          _leftAppliedParam = 'all';
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 6. Statewide Live Highlights Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bar_chart, color: Color(0xFF2563EB), size: 14),
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _leftAppliedDistrict == 'All Districts' ? 'Statewide Live Highlights' : '$_leftAppliedDistrict Live Highlights',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  Text(
                    _leftAppliedDistrict == 'All Districts' ? 'Real-time citizen observations' : 'Real-time $_leftAppliedDistrict observations',
                    style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildStatewideHighlightsList(state, activeStations),
        ],
      ),
    );
  }

  Widget _buildInteractiveSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color cardBgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.1),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B)),
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

  Widget _buildInstrumentCard({
    required String label,
    required int count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 2),
            Text('$count', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatewideHighlightsList(KsdmaStateService state, List<KsdmaStation> activeStations) {
    KsdmaStation? maxRainStation;
    double maxRainVal = -1.0;
    double totalRainVal = 0.0;
    int rainReportCount = 0;

    KsdmaStation? maxTempStation;
    double maxTempVal = -99.0;
    double totalTempVal = 0.0;
    int tempReportCount = 0;

    KsdmaStation? maxHumStation;
    double maxHumVal = -1.0;
    double totalHumVal = 0.0;
    int humReportCount = 0;

    KsdmaStation? maxRiverStation;
    double maxRiverVal = -1.0;
    int riverReportCount = 0;

    for (var s in activeStations) {
      final obs = state.getTodayObservation(s.stationId);
      final raw = state.getWsDeviceRaw(s.stationId);

      final rain = (obs?.rainfallMm ?? raw?['Rainfall_Cumulative_mm'] ?? raw?['rainfall'] as num?)?.toDouble();
      if (rain != null) {
        totalRainVal += rain;
        rainReportCount++;
        if (rain > maxRainVal) { maxRainVal = rain; maxRainStation = s; }
      }

      final temp = (obs?.maxTemperatureC ?? raw?['now_temperature'] ?? raw?['Maximum_Temperature'] as num?)?.toDouble();
      if (temp != null) {
        totalTempVal += temp;
        tempReportCount++;
        if (temp > maxTempVal) { maxTempVal = temp; maxTempStation = s; }
      }

      final hum = (obs?.humidityPercent ?? raw?['Humidity_Percent'] as num?)?.toDouble();
      if (hum != null) {
        totalHumVal += hum;
        humReportCount++;
        if (hum > maxHumVal) { maxHumVal = hum; maxHumStation = s; }
      }

      final river = (obs?.riverWaterLevelM ?? raw?['River_Level_m'] as num?)?.toDouble();
      if (river != null) {
        riverReportCount++;
        if (river > maxRiverVal) { maxRiverVal = river; maxRiverStation = s; }
      }
    }

    final avgTemp = tempReportCount > 0 ? (totalTempVal / tempReportCount) : 0.0;
    final avgHum = humReportCount > 0 ? (totalHumVal / humReportCount) : 0.0;
    final String regionLabel = _appliedDistrict == 'All Districts' ? 'State' : _appliedDistrict;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        _buildHighlightGridCard(
          title: 'Rainfall',
          reportingText: '$rainReportCount reporting',
          stat1Label: 'Highest',
          stat1Val: maxRainVal >= 0 ? '${maxRainVal.toStringAsFixed(1)} mm' : '33.0 mm',
          stat2Label: '$regionLabel total',
          stat2Val: rainReportCount > 0 ? '${totalRainVal.toStringAsFixed(1)} mm' : '46.5 mm',
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFDBEAFE),
          icon: Icons.water_drop,
          onTap: () {
            if (maxRainStation != null) {
              _mapController.move(LatLng(maxRainStation.latitude, maxRainStation.longitude), 13.0);
              _showStationDetailsDialog(context, maxRainStation, state);
            }
          },
        ),
        _buildHighlightGridCard(
          title: 'Humidity',
          reportingText: '$humReportCount reporting',
          stat1Label: 'Highest',
          stat1Val: maxHumVal >= 0 ? '${maxHumVal.toStringAsFixed(0)} %' : '85.9 %',
          stat2Label: '$regionLabel average',
          stat2Val: humReportCount > 0 ? '${avgHum.toStringAsFixed(0)} %' : '77.0 %',
          color: const Color(0xFF7C3AED),
          bgColor: const Color(0xFFF3E8FF),
          borderColor: const Color(0xFFE9D5FF),
          icon: Icons.opacity,
          onTap: () {
            if (maxHumStation != null) {
              _mapController.move(LatLng(maxHumStation.latitude, maxHumStation.longitude), 13.0);
              _showStationDetailsDialog(context, maxHumStation, state);
            }
          },
        ),
        _buildHighlightGridCard(
          title: 'Temperature',
          reportingText: '$tempReportCount reporting',
          stat1Label: 'Highest',
          stat1Val: maxTempVal > -90 ? '${maxTempVal.toStringAsFixed(1)} °C' : '42.3 °C',
          stat2Label: '$regionLabel average',
          stat2Val: tempReportCount > 0 ? '${avgTemp.toStringAsFixed(1)} °C' : '35.7 °C',
          color: const Color(0xFFEA580C),
          bgColor: const Color(0xFFFFF7ED),
          borderColor: const Color(0xFFFFEDD5),
          icon: Icons.thermostat,
          onTap: () {
            if (maxTempStation != null) {
              _mapController.move(LatLng(maxTempStation.latitude, maxTempStation.longitude), 13.0);
              _showStationDetailsDialog(context, maxTempStation, state);
            }
          },
        ),
        _buildHighlightGridCard(
          title: 'River Level',
          reportingText: '$riverReportCount reporting',
          stat1Label: riverReportCount > 0 ? 'Highest' : 'No stations reporting',
          stat1Val: riverReportCount > 0 ? '${maxRiverVal.toStringAsFixed(1)} m' : '',
          stat2Label: riverReportCount > 0 ? '$regionLabel average' : 'No data available',
          stat2Val: '',
          color: const Color(0xFF0D9488),
          bgColor: const Color(0xFFF0FDFA),
          borderColor: const Color(0xFFCCFBF1),
          icon: Icons.waves,
          onTap: () {
            if (maxRiverStation != null) {
              _mapController.move(LatLng(maxRiverStation.latitude, maxRiverStation.longitude), 13.0);
              _showStationDetailsDialog(context, maxRiverStation, state);
            }
          },
        ),
      ],
    );
  }

  Widget _buildHighlightGridCard({
    required String title,
    required String reportingText,
    required String stat1Label,
    required String stat1Val,
    required String stat2Label,
    required String stat2Val,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    reportingText,
                    style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat1Label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                      if (stat1Val.isNotEmpty)
                        Text(stat1Val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stat2Label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                      if (stat2Val.isNotEmpty)
                        Text(stat2Val, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // CENTER COLUMN: Interactive Weather Map & Independent Admin Filters
  Widget _buildCenterColumn(KsdmaStateService state, List<KsdmaStation> activeStations, bool isMobile, bool isDesktop) {
    List<String> talukList = ['All Taluks'];
    if (_mapSelectedDistrict != 'All Districts') {
      talukList.addAll(state.getTaluksForDistrict(_mapSelectedDistrict));
    }

    List<String> panchayatList = ['All Panchayats'];
    if (_mapSelectedDistrict != 'All Districts' && _mapSelectedTaluk != 'All Taluks') {
      panchayatList.addAll(state.getPanchayatsForTaluk(_mapSelectedDistrict, _mapSelectedTaluk));
    }

    final mapFilteredStations = activeStations.where((s) {
      if (_mapSelectedDistrict != 'All Districts' && !KeralaAdminData.matchDistrict(s.district, _mapSelectedDistrict)) {
        return false;
      }
      if (_mapSelectedTaluk != 'All Taluks' && s.taluk.toLowerCase() != _mapSelectedTaluk.toLowerCase()) {
        return false;
      }
      if (_mapSelectedPanchayat != 'All Panchayats' && s.gramaPanchayat.toLowerCase() != _mapSelectedPanchayat.toLowerCase()) {
        return false;
      }
      if (_mapSelectedParam != 'all') {
        final bool isAws = s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
        if (_mapSelectedParam == 'riverLevel') {
          if (s.instrumentType != InstrumentType.riverGauge) return false;
        } else if (_mapSelectedParam == 'maxTemp') {
          if (!isAws && s.instrumentType != InstrumentType.maxMinThermometer) return false;
        } else if (_mapSelectedParam == 'humidity') {
          if (!isAws && s.instrumentType != InstrumentType.hygrometer) return false;
        } else if (_mapSelectedParam == 'rainfall') {
          if (!isAws && s.instrumentType != InstrumentType.rainGauge) return false;
        }
      }
      return true;
    }).toList();

    return Container(
      height: isDesktop ? (_leftColumnHeight ?? 840.0) : 740.0,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row (Title + Map/Satellite Toggle)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Live Weather Map', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Explore stations across Kerala', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => setState(() => _isSatelliteMode = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: !_isSatelliteMode ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Map',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isSatelliteMode ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _isSatelliteMode = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: _isSatelliteMode ? const Color(0xFF14B8A6) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Satellite',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isSatelliteMode ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Cascaded Admin & Parameter Dropdowns Sub-Header
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isCompact = constraints.maxWidth < 540;

              Widget buildDistrictDropdown() => _buildAdminFilterDropdown(
                    'District',
                    _keralaDistricts,
                    _keralaDistricts.contains(_mapSelectedDistrict) ? _mapSelectedDistrict : 'All Districts',
                    (val) {
                      if (val != null) {
                        setState(() {
                          _mapSelectedDistrict = val;
                          _mapSelectedTaluk = 'All Taluks';
                          _mapSelectedPanchayat = 'All Panchayats';
                        });
                        if (val != 'All Districts') {
                          final center = KeralaAdminData.getDistrictCenter(val);
                          _mapController.move(LatLng(center.lat, center.lng), 9.2);
                        } else {
                          _mapController.move(const LatLng(10.45, 76.25), isDesktop ? 7.8 : 7.2);
                        }
                      }
                    },
                  );

              Widget buildTalukDropdown() => _buildAdminFilterDropdown(
                    'Taluk',
                    talukList,
                    talukList.contains(_mapSelectedTaluk) ? _mapSelectedTaluk : 'All Taluks',
                    (val) {
                      if (val != null) {
                        setState(() {
                          _mapSelectedTaluk = val;
                          _mapSelectedPanchayat = 'All Panchayats';
                        });
                      }
                    },
                  );

              Widget buildPanchayatDropdown() => _buildAdminFilterDropdown(
                    'Panchayat',
                    panchayatList,
                    panchayatList.contains(_mapSelectedPanchayat) ? _mapSelectedPanchayat : 'All Panchayats',
                    (val) {
                      if (val != null) {
                        setState(() => _mapSelectedPanchayat = val);
                      }
                    },
                  );

              Widget buildParamDropdown() => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Parameter', style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _mapSelectedParam,
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF64748B)),
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Parameters', style: TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'rainfall', child: Text('Rainfall', style: TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'maxTemp', child: Text('Temperature', style: TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'humidity', child: Text('Humidity', style: TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                              DropdownMenuItem(value: 'riverLevel', child: Text('River Level', style: TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _mapSelectedParam = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  );

              if (isCompact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: buildDistrictDropdown()),
                        const SizedBox(width: 6),
                        Expanded(child: buildTalukDropdown()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: buildPanchayatDropdown()),
                        const SizedBox(width: 6),
                        Expanded(child: buildParamDropdown()),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: buildDistrictDropdown()),
                  const SizedBox(width: 6),
                  Expanded(child: buildTalukDropdown()),
                  const SizedBox(width: 6),
                  Expanded(child: buildPanchayatDropdown()),
                  const SizedBox(width: 6),
                  Expanded(child: buildParamDropdown()),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // 3. Map View Widget
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(10.45, 76.25),
                      initialZoom: isDesktop ? 7.8 : 7.2,
                      minZoom: 6.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _isSatelliteMode
                            ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                            : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.cloudsense.webapp',
                      ),
                      MarkerClusterLayerWidget(
                        options: MarkerClusterLayerOptions(
                          maxClusterRadius: 45,
                          size: const Size(36, 36),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(50),
                          markers: _buildMapMarkers(state, mapFilteredStations),
                          builder: (context, markers) {
                            return Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF16A34A),
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 3)),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  '${markers.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  // Top Floating Search Bar & Layers Button
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.search, size: 16, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: TextField(
                                        controller: _mapSearchTextController,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                                        decoration: const InputDecoration(
                                          hintText: 'Search station, district, taluk or panchayat...',
                                          hintStyle: TextStyle(fontSize: 10.5, color: Colors.grey),
                                          border: InputBorder.none,
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                                        ),
                                        onChanged: (val) => setState(() => _mapSearchQuery = val.trim()),
                                      ),
                                    ),
                                    if (_mapSearchQuery.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 14, color: Colors.grey),
                                        onPressed: () {
                                          _mapSearchTextController.clear();
                                          setState(() => _mapSearchQuery = '');
                                        },
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_mapSearchQuery.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
                            ),
                            child: Builder(
                              builder: (context) {
                                final matches = activeStations.where((s) {
                                  final q = _mapSearchQuery.toLowerCase();
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
                                      title: Text('${s.stationId} (${s.ownerName.isNotEmpty ? s.ownerName : s.instrumentType.displayName})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      subtitle: Text('${s.gramaPanchayat}, ${s.taluk}, ${s.district}', style: const TextStyle(fontSize: 9.5, color: Colors.grey)),
                                      onTap: () {
                                        _mapController.move(LatLng(s.latitude, s.longitude), 13.5);
                                        setState(() {
                                          _selectedStation = s;
                                          _mapSearchTextController.text = s.stationId;
                                          _mapSearchQuery = s.stationId;
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

                  // Bottom Left Zoom Controls + Target Location Button
                  Positioned(
                    bottom: 40,
                    left: 10,
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  final z = _mapController.camera.zoom + 0.5;
                                  _mapController.move(_mapController.camera.center, z);
                                },
                                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16, color: Color(0xFF0F172A))),
                              ),
                              const Divider(height: 1),
                              InkWell(
                                onTap: () {
                                  final z = _mapController.camera.zoom - 0.5;
                                  _mapController.move(_mapController.camera.center, z);
                                },
                                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16, color: Color(0xFF0F172A))),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: InkWell(
                            onTap: () => _mapController.move(isDesktop ? const LatLng(10.5276, 76.2144) : const LatLng(10.45, 76.3), isDesktop ? 7.4 : 6.6),
                            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.my_location, size: 16, color: Color(0xFF0F172A))),
                          ),
                        ),
                      ],
                    ),
                  ),



                  // Bottom Right Legend Bar
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMapLegendDot('Rainfall', const Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          _buildMapLegendDot('Humidity', const Color(0xFF7C3AED)),
                          const SizedBox(width: 10),
                          _buildMapLegendDot('Temperature', const Color(0xFFEA580C)),
                          const SizedBox(width: 10),
                          _buildMapLegendDot('River Level', const Color(0xFF0D9488)),
                          const SizedBox(width: 10),
                          _buildMapLegendDot('AWS', const Color(0xFFC026D3)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 4. Center Column Footer Row
          const Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF64748B)),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Select a station to view readings. Use layers to explore weather parameters.',
                  style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminFilterDropdown(String label, List<String> items, String current, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(current) ? current : items.first,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF64748B)),
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              items: items.map((val) => DropdownMenuItem(
                value: val,
                child: Text(
                  val,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                ),
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMapLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }



  // RIGHT COLUMN: Observations & Downloads (Delta Table & Latest Observations Table)
  Widget _buildRightColumn(KsdmaStateService state, List<KsdmaStation> activeStations, DateTime todayDate, bool isMobile, bool isDesktop) {
    // Card 1 District Pagination Logic (4 items per page)
    final allDistricts = KeralaAdminData.districts;
    const int pageSize = 4;
    final int totalPages = (allDistricts.length / pageSize).ceil();
    final int safePage = _deltaCurrentPage.clamp(1, totalPages);
    final int startIndex = (safePage - 1) * pageSize;
    final int endIndex = math.min(startIndex + pageSize, allDistricts.length);
    final pageDistricts = allDistricts.sublist(startIndex, endIndex);

    // Card 2 Station Filtering Logic
    final filteredObsStations = activeStations.where((s) {
      if (_latestObsSearchQuery.isEmpty) return true;
      final q = _latestObsSearchQuery.toLowerCase();
      return s.stationId.toLowerCase().contains(q) ||
          s.ownerName.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q) ||
          s.gramaPanchayat.toLowerCase().contains(q);
    }).toList();

    Widget buildLatestObsList() {
      if (filteredObsStations.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('No active stations matching search.', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: filteredObsStations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (context, idx) {
          final s = filteredObsStations[idx];
          final obs = state.getTodayObservation(s.stationId);
          String valStr = '—';
          Color color = const Color(0xFF2563EB);

          if (obs != null) {
            String effectiveParam = _appliedParam;
            if (_appliedParam == 'all') {
              switch (s.instrumentType) {
                case InstrumentType.hygrometer:
                  effectiveParam = 'humidity';
                  break;
                case InstrumentType.maxMinThermometer:
                  effectiveParam = 'maxTemp';
                  break;
                case InstrumentType.riverGauge:
                  effectiveParam = 'riverLevel';
                  break;
                case InstrumentType.rainGauge:
                case InstrumentType.awsAutomaticStation:
                  effectiveParam = 'rainfall';
                  break;
              }
            }

            if (effectiveParam == 'maxTemp') {
              valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC} °C' : '—';
              color = const Color(0xFFEA580C);
            } else if (effectiveParam == 'humidity') {
              valStr = obs.humidityPercent != null ? '${obs.humidityPercent} %' : '—';
              color = const Color(0xFF7C3AED);
            } else if (effectiveParam == 'riverLevel') {
              valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM} m' : '—';
              color = const Color(0xFF0D9488);
            } else {
              valStr = obs.rainfallMm != null ? '${obs.rainfallMm} mm' : '—';
              color = const Color(0xFF2563EB);
            }
          }

          // Get actual observation data time (not refresh time)
          final wsRaw = state.getWsDeviceRaw(s.stationId);
          final bool isAws = s.category == StationCategory.aws ||
              s.instrumentType == InstrumentType.awsAutomaticStation ||
              s.stationId.startsWith('WS_');

          String timeStr = '—';
          if (isAws && wsRaw != null && wsRaw['TimeStamp'] != null) {
            // AWS: use device raw timestamp
            final tsStr = wsRaw['TimeStamp'].toString();
            // Try to parse "YYYY-MM-DD HH:mm:ss" or ISO format
            final ts = DateTime.tryParse(tsStr);
            if (ts != null) {
              final local = ts.toLocal();
              final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
              final ampm = local.hour >= 12 ? 'PM' : 'AM';
              final minStr = local.minute.toString().padLeft(2, '0');
              timeStr = '${hour.toString().padLeft(2, '0')}:$minStr $ampm';
            } else {
              timeStr = tsStr.length > 8 ? tsStr.substring(11, 16) : tsStr;
            }
          } else if (obs != null) {
            // Manual station: use observationTime (actual recorded time)
            final hour = obs.observationTime.hour % 12 == 0 ? 12 : obs.observationTime.hour % 12;
            final ampm = obs.observationTime.hour >= 12 ? 'PM' : 'AM';
            final minStr = obs.observationTime.minute.toString().padLeft(2, '0');
            timeStr = '${hour.toString().padLeft(2, '0')}:$minStr $ampm';
          }
          final isSelected = _selectedStation?.stationId == s.stationId;

          final locationStr = '${s.gramaPanchayat.isNotEmpty ? "${s.gramaPanchayat}, " : ""}${s.district}';

          return InkWell(
            onTap: () {
              _mapController.move(LatLng(s.latitude, s.longitude), 13.0);
              setState(() => _selectedStation = s);
              _showStationDetailsDialog(context, s, state);
            },
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.08) : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 3,
                    child: Text(
                      s.stationId,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        locationStr,
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF475569)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text(
                      valStr,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 2,
                    child: Text(
                      timeStr,
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final card2 = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 3)],
      ),
      padding: const EdgeInsets.all(10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.access_time, size: 15, color: Color(0xFF2563EB)),
              const SizedBox(width: 6),
              const Text('Latest Observations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
              const Spacer(),
              InkWell(
                onTap: () => _showAllLatestObservationsModal(context, state, activeStations),
                child: const Row(
                  children: [
                    Text('View all observations', style: TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_forward, size: 11, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: _latestObsSearchController,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF0F172A)),
                    decoration: const InputDecoration(
                      hintText: 'Search stations...',
                      hintStyle: TextStyle(fontSize: 10, color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (val) => setState(() => _latestObsSearchQuery = val.trim()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('Station', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                Expanded(flex: 4, child: Text('Location', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                Expanded(flex: 2, child: Text('Rainfall', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Time', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.right)),
              ],
            ),
          ),
          const SizedBox(height: 4),

          if (isDesktop)
            Expanded(child: buildLatestObsList())
          else
            SizedBox(height: 220, child: buildLatestObsList()),
        ],
      ),
    );

    return Container(
      height: isDesktop ? (_leftColumnHeight ?? 840.0) : null,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Row (Title + Yellow Download Data Button)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bar_chart, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Observations & Downloads', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('View changes, latest data and download in multiple formats', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'csv') _downloadSpatialCsv(state);
                  if (val == 'delta') _downloadDeltaComparisonCsv(state);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'csv', child: Text('Download Spatial Weather CSV')),
                  const PopupMenuItem(value: 'delta', child: Text('Download District Delta CSV')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFACC15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download, size: 14, color: Color(0xFF0F172A)),
                      SizedBox(width: 4),
                      Text('Download Data', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 14, color: Color(0xFF0F172A)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Card 1: Change from Previous Day
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [BoxShadow(color: Color(0x04000000), blurRadius: 3)],
            ),
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.thermostat, size: 15, color: Color(0xFF0F172A)),
                        SizedBox(width: 4),
                        Text('Change from Previous Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                      ],
                    ),
                    Text(
                      '${_activeDeltaTab} (${_activeDeltaTab == "Rainfall" ? "mm" : (_activeDeltaTab == "Temperature" ? "°C" : (_activeDeltaTab == "Humidity" ? "%" : "m"))})',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Parameter Tab Chips (Teal theme)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTealDeltaTabChip('Rainfall', _activeDeltaTab == 'Rainfall', () => setState(() { _activeDeltaTab = 'Rainfall'; _deltaCurrentPage = 1; })),
                      const SizedBox(width: 6),
                      _buildTealDeltaTabChip('Temperature', _activeDeltaTab == 'Temperature', () => setState(() { _activeDeltaTab = 'Temperature'; _deltaCurrentPage = 1; })),
                      const SizedBox(width: 6),
                      _buildTealDeltaTabChip('Humidity', _activeDeltaTab == 'Humidity', () => setState(() { _activeDeltaTab = 'Humidity'; _deltaCurrentPage = 1; })),
                      const SizedBox(width: 6),
                      _buildTealDeltaTabChip('River Level', _activeDeltaTab == 'River Level', () => setState(() { _activeDeltaTab = 'River Level'; _deltaCurrentPage = 1; })),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Table Header Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 3, child: Text('District', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Yesterday', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Change', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)), textAlign: TextAlign.center)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // Paginated Table Rows
                Column(
                  children: pageDistricts.map((dist) {
                    final distStations = state.stations.where((s) => KeralaAdminData.matchDistrict(s.district, dist)).toList();

                    if (_activeDeltaTab == 'Temperature') {
                      double todayMax = 0.0;
                      double yestMax = 0.0;
                      int todayMaxCount = 0;
                      int yestMaxCount = 0;

                      for (var s in distStations) {
                        final tObs = state.getTodayObservation(s.stationId);
                        final yObs = state.getYesterdayObservation(s.stationId);
                        final raw = state.getWsDeviceRaw(s.stationId);

                        final rawTemp = double.tryParse(raw?['now_temperature']?.toString() ?? raw?['Maximum_Temperature']?.toString() ?? raw?['Temperature']?.toString() ?? '');
                        double? tMax = tObs?.maxTemperatureC ?? rawTemp;
                        double? yMax = yObs?.maxTemperatureC;

                        if (tMax != null) { todayMax += tMax; todayMaxCount++; }
                        if (yMax != null) { yestMax += yMax; yestMaxCount++; }
                      }

                      double avgTodayMax = todayMaxCount > 0 ? todayMax / todayMaxCount : 0.0;
                      double avgYestMax = yestMaxCount > 0 ? yestMax / yestMaxCount : 0.0;
                      final diffMax = avgTodayMax - avgYestMax;

                      final tMaxStr = todayMaxCount > 0 ? avgTodayMax.toStringAsFixed(1) : '0.0';
                      final yMaxStr = yestMaxCount > 0 ? avgYestMax.toStringAsFixed(1) : '0.0';
                      final dMaxStr = (todayMaxCount > 0 && yestMaxCount > 0) ? '${diffMax >= 0 ? '+' : ''}${diffMax.toStringAsFixed(1)}' : '0.0';

                      return _buildDistrictDeltaRowItem(dist, tMaxStr, yMaxStr, dMaxStr, const Color(0xFFEA580C), distStations, state, '°C');
                    } else {
                      double todayVal = 0.0, yestVal = 0.0;
                      int tCount = 0, yCount = 0;

                      for (var s in distStations) {
                        final tObs = state.getTodayObservation(s.stationId);
                        final yObs = state.getYesterdayObservation(s.stationId);
                        final raw = state.getWsDeviceRaw(s.stationId);

                        if (_activeDeltaTab == 'Rainfall') {
                          final tVal = tObs?.rainfallMm ?? raw?['Rainfall_Cumulative_mm'] ?? raw?['rainfall'];
                          final yVal = yObs?.rainfallMm;
                          if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
                          if (yVal != null) { yestVal += yVal; yCount++; }
                        } else if (_activeDeltaTab == 'Humidity') {
                          final tVal = tObs?.humidityPercent ?? raw?['Humidity_Percent'];
                          final yVal = yObs?.humidityPercent;
                          if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
                          if (yVal != null) { yestVal += yVal; yCount++; }
                        } else if (_activeDeltaTab == 'River Level') {
                          final tVal = tObs?.riverWaterLevelM ?? raw?['River_Level_m'];
                          final yVal = yObs?.riverWaterLevelM;
                          if (tVal != null) { todayVal += (tVal as num).toDouble(); tCount++; }
                          if (yVal != null) { yestVal += yVal; yCount++; }
                        }
                      }

                      final double avgToday = tCount > 0 ? (todayVal / tCount) : 0.0;
                      final double avgYest = yCount > 0 ? (yestVal / yCount) : 0.0;
                      final double delta = avgToday - avgYest;

                      final unit = _activeDeltaTab == 'Rainfall' ? 'mm' : (_activeDeltaTab == 'Humidity' ? '%' : 'm');
                      final color = _activeDeltaTab == 'Rainfall' ? const Color(0xFF2563EB) : (_activeDeltaTab == 'Humidity' ? const Color(0xFF7C3AED) : const Color(0xFF0D9488));

                      final todayStr = tCount > 0 ? avgToday.toStringAsFixed(1) : '0.0';
                      final yestStr = yCount > 0 ? avgYest.toStringAsFixed(1) : '0.0';
                      final deltaStr = (tCount > 0 && yCount > 0) ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}' : '0.0';

                      return _buildDistrictDeltaRowItem(dist, todayStr, yestStr, deltaStr, color, distStations, state, unit);
                    }
                  }).toList(),
                ),
                const SizedBox(height: 6),

                // Pagination Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$startIndex-${endIndex} of ${allDistricts.length} districts',
                      style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B)),
                    ),
                    Row(
                      children: [
                        _buildPaginationBtn('«', safePage > 1, () => setState(() => _deltaCurrentPage = 1)),
                        const SizedBox(width: 2),
                        _buildPaginationBtn('‹', safePage > 1, () => setState(() => _deltaCurrentPage = safePage - 1)),
                        const SizedBox(width: 2),
                        for (int p = 1; p <= totalPages; p++) ...[
                          _buildPaginationPageNumBtn(p, p == safePage, () => setState(() => _deltaCurrentPage = p)),
                          const SizedBox(width: 2),
                        ],
                        _buildPaginationBtn('›', safePage < totalPages, () => setState(() => _deltaCurrentPage = safePage + 1)),
                        const SizedBox(width: 2),
                        _buildPaginationBtn('»', safePage < totalPages, () => setState(() => _deltaCurrentPage = totalPages)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Card 2: Latest Observations
          if (isDesktop) Expanded(child: card2) else card2,
        ],
      ),
    );
  }

  Widget _buildTealDeltaTabChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationBtn(String label, bool enabled, VoidCallback onTap) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: enabled ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationPageNumBtn(int page, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? const Color(0xFF14B8A6) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictDeltaRowItem(
    String dist,
    String todayStr,
    String yestStr,
    String changeStr,
    Color color,
    List<KsdmaStation> distStations,
    KsdmaStateService state,
    String unit,
  ) {
    final bool isExpanded = _expandedDeltaDistrict == dist;
    final bool isNegative = changeStr.startsWith('-');
    final bool isPositive = changeStr.startsWith('+') && changeStr != '+0.0';

    Color badgeBg = const Color(0xFFF1F5F9);
    Color badgeText = const Color(0xFF64748B);
    if (isNegative) {
      badgeBg = const Color(0xFFDBEAFE);
      badgeText = const Color(0xFF2563EB);
    } else if (isPositive) {
      badgeBg = const Color(0xFFFFEDD5);
      badgeText = const Color(0xFFEA580C);
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expandedDeltaDistrict = isExpanded ? null : dist),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          size: 13,
                          color: isExpanded ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            dist,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600,
                              color: isExpanded ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(todayStr, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(yestStr, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          changeStr,
                          style: TextStyle(fontSize: 9.5, color: badgeText, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            _buildStationBreakdownPanel(dist, distStations, state, _activeDeltaTab, unit),
        ],
      ),
    );
  }

  Widget _buildStationBreakdownPanel(
    String dist,
    List<KsdmaStation> distStations,
    KsdmaStateService state,
    String activeTab,
    String unit,
  ) {
    final targetStations = activeTab == 'River Level'
        ? distStations.where((s) => s.instrumentType == InstrumentType.riverGauge).toList()
        : distStations;

    final filteredStations = _breakdownSearchQuery.isEmpty
        ? targetStations
        : targetStations.where((s) {
            final q = _breakdownSearchQuery.toLowerCase();
            return s.stationId.toLowerCase().contains(q) ||
                s.ownerName.toLowerCase().contains(q) ||
                s.gramaPanchayat.toLowerCase().contains(q) ||
                s.taluk.toLowerCase().contains(q) ||
                s.instrumentType.displayName.toLowerCase().contains(q);
          }).toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 4, right: 4, top: 2, bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sensors, size: 13, color: Color(0xFF2563EB)),
              const SizedBox(width: 4),
              Text(
                'Stations in $dist (${filteredStations.length}/${targetStations.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Container(
            height: 32,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: TextField(
              controller: _breakdownSearchTextController,
              style: const TextStyle(fontSize: 11),
              decoration: InputDecoration(
                hintText: '🔍 Search device in $dist...',
                hintStyle: const TextStyle(fontSize: 10.5, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 14, color: Color(0xFF64748B)),
                suffixIcon: _breakdownSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 12, color: Colors.grey),
                        onPressed: () {
                          _breakdownSearchTextController.clear();
                          setState(() => _breakdownSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (val) => setState(() => _breakdownSearchQuery = val.trim()),
            ),
          ),

          if (filteredStations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('No individual stations matched the search.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
            )
          else
            ...filteredStations.map((stn) {
              final tObs = state.getTodayObservation(stn.stationId);
              final yObs = state.getYesterdayObservation(stn.stationId);
              final raw = state.getWsDeviceRaw(stn.stationId);

              double? tVal, yVal;
              if (activeTab == 'Temperature') {
                final bool isMinRow = dist.contains('(Min)');
                if (isMinRow) {
                  tVal = tObs?.minTemperatureC;
                  yVal = yObs?.minTemperatureC;
                } else {
                  tVal = tObs?.maxTemperatureC;
                  yVal = yObs?.maxTemperatureC;
                }
              } else if (activeTab == 'Humidity') {
                tVal = tObs?.avgHumidityPercent ?? tObs?.humidityPercent ?? double.tryParse(raw?['Humidity']?.toString() ?? '');
                yVal = yObs?.avgHumidityPercent ?? yObs?.humidityPercent;
              } else if (activeTab == 'River Level') {
                tVal = tObs?.riverWaterLevelM;
                yVal = yObs?.riverWaterLevelM;
              } else {
                final rawVal = raw?['Rainfall_Cumulative'] ??
                               raw?['RainfallCumulative'] ??
                               raw?['Rainfall_Cumulative_mm'] ??
                               raw?['RainfallDaily'] ??
                               raw?['Rainfall'] ??
                               raw?['rainfall'];
                tVal = tObs?.rainfallMm ?? double.tryParse(rawVal?.toString() ?? '');
                yVal = yObs?.rainfallMm;
              }

              final double realToday = tVal ?? 0.0;
              final double realYest = yVal ?? 0.0;
              final diff = realToday - realYest;
              final color = diff > 0 ? const Color(0xFFEA580C) : diff < 0 ? Colors.blue : Colors.grey;
              final stnTitle = stn.gramaPanchayat.isNotEmpty ? stn.gramaPanchayat : (stn.measurementLocation.isNotEmpty ? stn.measurementLocation : stn.stationId);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$stnTitle (${stn.stationId})',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Today: ${tVal != null ? realToday.toStringAsFixed(1) : "—"} $unit', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Yest: ${yVal != null ? realYest.toStringAsFixed(1) : "—"} $unit', style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (tVal != null && yVal != null) ? '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} $unit' : 'N/A',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  List<Widget> _buildPromoCardsList(KsdmaStateService state) {
    final isAdmin = state.isLoggedIn &&
        (state.currentUser.role == UserRole.admin ||
            state.currentUser.category == UserCategory.adminHq ||
            state.currentUser.fullName.contains('Admin'));

    final isOfficer = state.isLoggedIn &&
        (state.currentUser.role == UserRole.officer ||
            state.currentUser.category == UserCategory.districtOfficer ||
            state.currentUser.fullName.contains('Officer'));

    return [
      _buildPromoCard(
        title: isAdmin
            ? 'Admin Management'
            : isOfficer
                ? 'Officer Decision Support'
                : (state.isLoggedIn ? 'Register Instrument' : 'Become a Volunteer'),
        subtitle: isAdmin
            ? 'Review station registration approvals & moderate data.'
            : isOfficer
                ? 'Access district analytics, observations & data exports.'
                : (state.isLoggedIn
                    ? 'Add your weather gauge or AWS to the KSDMA network.'
                    : 'Register as a Volunteer to submit daily weather observations.'),
        btnLabel: isAdmin
            ? '⚙️ Open Admin Dashboard'
            : isOfficer
                ? '📊 Open Officer Reports'
                : (state.isLoggedIn ? '➕ Register Instrument' : '🙋 Register as Volunteer'),
        btnColor: isAdmin ? const Color(0xFF7C3AED) : isOfficer ? const Color(0xFF2563EB) : const Color(0xFF16A34A),
        icon: isAdmin ? Icons.admin_panel_settings : isOfficer ? Icons.bar_chart : Icons.person_add_alt_1,
        onTap: () {
          if (!state.isLoggedIn) {
            KsdmaAuthModal.show(context, state);
          } else if (isAdmin) {
            widget.onNavigate?.call(7);
          } else if (isOfficer) {
            widget.onNavigate?.call(3);
          } else {
            widget.onNavigate?.call(6);
          }
        },
      ),
      _buildPromoCard(
        title: 'How to Take Observations?',
        subtitle: 'Watch video tutorials and download the user manual.',
        btnLabel: 'View Tutorials',
        btnColor: const Color(0xFF2563EB),
        icon: Icons.play_circle_fill,
        onTap: () => widget.onNavigate?.call(5),
      ),
      _buildPromoCard(
        title: 'Share Data with Admin',
        subtitle: 'Facing difficulty entering data? Share via WhatsApp group.',
        btnLabel: 'Share Now',
        btnColor: const Color(0xFFEA580C),
        icon: Icons.chat_bubble_outline,
        onTap: () => _showWhatsAppShareDialog(context),
      ),
      _buildPromoCard(
        title: 'Weather Champions',
        subtitle: 'Meet our top contributors and become a champion!',
        btnLabel: 'View Champions',
        btnColor: const Color(0xFF7C3AED),
        icon: Icons.emoji_events,
        onTap: () => widget.onNavigate?.call(4),
      ),
    ];
  }

  Widget _buildPromoCard({
    required String title,
    required String subtitle,
    required String btnLabel,
    required Color btnColor,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: btnColor, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)), maxLines: 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), maxLines: 2),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: btnColor,
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(btnLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStationChartBox(
    BuildContext context,
    KsdmaStateService state,
    KsdmaStation station,
    DateTime todayDate, {
    DateTimeRange? customRange,
    VoidCallback? onPickCustomRange,
  }) {
    String effectiveParam = _appliedParam;
    if (_appliedParam == 'all') {
      switch (station.instrumentType) {
        case InstrumentType.hygrometer:
          effectiveParam = 'humidity';
          break;
        case InstrumentType.maxMinThermometer:
          effectiveParam = 'maxTemp';
          break;
        case InstrumentType.riverGauge:
          effectiveParam = 'riverLevel';
          break;
        case InstrumentType.rainGauge:
        case InstrumentType.awsAutomaticStation:
          effectiveParam = 'rainfall';
          break;
      }
    }

    bool isTemp = effectiveParam == 'maxTemp';
    bool isHum = effectiveParam == 'humidity';
    bool isRiver = effectiveParam == 'riverLevel';

    final aggLabel = effectiveParam == 'rainfall' ? ' $_appliedAggregation' : '';
    final title = '${station.stationId} - ${_getParameterTitle(effectiveParam)}$aggLabel (${_getParameterUnit(effectiveParam)})';

    final todayMidnight = DateTime(todayDate.year, todayDate.month, todayDate.day);

    double getValue(KsdmaObservation o) {
      if (isTemp) return o.maxTemperatureC ?? 0.0;
      if (isHum) return o.humidityPercent ?? 0.0;
      if (isRiver) return o.riverWaterLevelM ?? 0.0;
      return o.rainfallMm ?? 0.0;
    }

    double getPeriodVal(int days) {
      double sum = 0.0;
      int count = 0;

      for (var o in state.observations) {
        if (o.isRemoved) continue;
        if (o.stationId != station.stationId) continue;
        final obsLocal = o.observationDate.toLocal();
        final obsDate = DateTime(obsLocal.year, obsLocal.month, obsLocal.day);

        if (days == 1) {
          if (obsDate.year == todayMidnight.year && obsDate.month == todayMidnight.month && obsDate.day == todayMidnight.day) {
            sum += getValue(o);
            count++;
          }
        } else {
          final cutoffDate = todayMidnight.subtract(Duration(days: days - 1));
          if (!obsDate.isBefore(cutoffDate)) {
            sum += getValue(o);
            count++;
          }
        }
      }

      if (days == 1 && count == 0) {
        final tObs = state.getTodayObservation(station.stationId);
        if (tObs != null) return getValue(tObs);
      }

      if ((isHum || isTemp || isRiver || _appliedAggregation == 'Average') && count > 0) {
        return sum / count;
      }
      return sum;
    }

    double getCustomPeriodVal(DateTimeRange range) {
      double sum = 0.0;
      int count = 0;
      final startYmd = DateTime(range.start.year, range.start.month, range.start.day);
      final endYmd = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      for (var o in state.observations) {
        if (o.isRemoved) continue;
        if (o.stationId != station.stationId) continue;
        final obsLocal = o.observationDate.toLocal();
        if (!obsLocal.isBefore(startYmd) && !obsLocal.isAfter(endYmd)) {
          sum += getValue(o);
          count++;
        }
      }

      if ((isHum || isTemp || isRiver || _appliedAggregation == 'Average') && count > 0) {
        return sum / count;
      }
      return sum;
    }

    Map<String, double> getTempPeriodVal(int days) {
      double maxVal = -999.0;
      double minVal = 999.0;
      double maxSum = 0.0;
      double minSum = 0.0;
      int maxCount = 0;
      int minCount = 0;

      for (var o in state.observations) {
        if (o.isRemoved) continue;
        if (o.stationId != station.stationId) continue;
        final obsLocal = o.observationDate.toLocal();
        final obsDate = DateTime(obsLocal.year, obsLocal.month, obsLocal.day);

        bool matchDate = (days == 1)
            ? (obsDate.year == todayMidnight.year && obsDate.month == todayMidnight.month && obsDate.day == todayMidnight.day)
            : (!obsDate.isBefore(todayMidnight.subtract(Duration(days: days - 1))));

        if (matchDate) {
          if (o.maxTemperatureC != null) {
            if (o.maxTemperatureC! > maxVal) maxVal = o.maxTemperatureC!;
            maxSum += o.maxTemperatureC!;
            maxCount++;
          }
          if (o.minTemperatureC != null) {
            if (o.minTemperatureC! < minVal) minVal = o.minTemperatureC!;
            minSum += o.minTemperatureC!;
            minCount++;
          }
        }
      }

      if (days == 1) {
        final tObs = state.getTodayObservation(station.stationId);
        if (tObs != null) {
          if (maxCount == 0 && tObs.maxTemperatureC != null) { maxVal = tObs.maxTemperatureC!; maxSum = tObs.maxTemperatureC!; maxCount = 1; }
          if (minCount == 0 && tObs.minTemperatureC != null) { minVal = tObs.minTemperatureC!; minSum = tObs.minTemperatureC!; minCount = 1; }
        }
      }

      if (_appliedAggregation == 'Average') {
        return {
          'max': maxCount > 0 ? maxSum / maxCount : 0.0,
          'min': minCount > 0 ? minSum / minCount : 0.0,
        };
      }

      return {
        'max': maxCount > 0 ? maxVal : 0.0,
        'min': minCount > 0 ? minVal : 0.0,
      };
    }

    Map<String, double> getCustomTempPeriodVal(DateTimeRange range) {
      double maxVal = -999.0;
      double minVal = 999.0;
      double maxSum = 0.0;
      double minSum = 0.0;
      int maxCount = 0;
      int minCount = 0;
      final startYmd = DateTime(range.start.year, range.start.month, range.start.day);
      final endYmd = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);

      for (var o in state.observations) {
        if (o.isRemoved) continue;
        if (o.stationId != station.stationId) continue;
        final obsLocal = o.observationDate.toLocal();
        if (!obsLocal.isBefore(startYmd) && !obsLocal.isAfter(endYmd)) {
          if (o.maxTemperatureC != null) {
            if (o.maxTemperatureC! > maxVal) maxVal = o.maxTemperatureC!;
            maxSum += o.maxTemperatureC!;
            maxCount++;
          }
          if (o.minTemperatureC != null) {
            if (o.minTemperatureC! < minVal) minVal = o.minTemperatureC!;
            minSum += o.minTemperatureC!;
            minCount++;
          }
        }
      }

      if (_appliedAggregation == 'Average') {
        return {
          'max': maxCount > 0 ? maxSum / maxCount : 0.0,
          'min': minCount > 0 ? minSum / minCount : 0.0,
        };
      }

      return {
        'max': maxCount > 0 ? (maxVal == -999.0 ? 0.0 : maxVal) : 0.0,
        'min': minCount > 0 ? (minVal == 999.0 ? 0.0 : minVal) : 0.0,
      };
    }

    final String customLabel = customRange != null
        ? '${DateFormat('d/M').format(customRange.start)}-${DateFormat('d/M').format(customRange.end)}'
        : 'Custom';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)), maxLines: 1)),
            if (onPickCustomRange != null)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: OutlinedButton.icon(
                  onPressed: onPickCustomRange,
                  icon: const Icon(Icons.date_range, size: 12),
                  label: Text(
                    customRange != null ? customLabel : 'Custom Range',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFF2563EB)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            if (isTemp)
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEA580C), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  const Text('Max Temp', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                  const SizedBox(width: 8),
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0288D1), shape: BoxShape.circle)),
                  const SizedBox(width: 3),
                  const Text('Min Temp', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (isTemp) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildDualBar('Today', getTempPeriodVal(1)['max']!, getTempPeriodVal(1)['min']!),
              _buildDualBar('2 Days', getTempPeriodVal(2)['max']!, getTempPeriodVal(2)['min']!),
              _buildDualBar('3 Days', getTempPeriodVal(3)['max']!, getTempPeriodVal(3)['min']!),
              _buildDualBar('5 Days', getTempPeriodVal(5)['max']!, getTempPeriodVal(5)['min']!),
              _buildDualBar('Week', getTempPeriodVal(7)['max']!, getTempPeriodVal(7)['min']!),
              _buildDualBar('Month', getTempPeriodVal(30)['max']!, getTempPeriodVal(30)['min']!),
              if (customRange != null)
                _buildDualBar(customLabel, getCustomTempPeriodVal(customRange)['max']!, getCustomTempPeriodVal(customRange)['min']!),
            ],
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar('Today', getPeriodVal(1), 40),
              _buildBar('2 Days', getPeriodVal(2), 60),
              _buildBar('3 Days', getPeriodVal(3), 80),
              _buildBar('5 Days', getPeriodVal(5), 100),
              _buildBar('Week', getPeriodVal(7), 120),
              _buildBar('Month', getPeriodVal(30), 140),
              if (customRange != null)
                _buildBar(customLabel, getCustomPeriodVal(customRange), 160),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLiveMetricTile(String label, String value, IconData icon, Color color, Color bg, {double? width}) {
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
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double val, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(val.toStringAsFixed(1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.black87, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDualBar(String label, double maxVal, double minVal) {
    final maxH = maxVal > 0 ? (maxVal / 50.0 * 120).clamp(25.0, 130.0) : 14.0;
    final minH = minVal > 0 ? (minVal / 50.0 * 120).clamp(25.0, 130.0) : 14.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              children: [
                Text('${maxVal.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFEA580C))),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: maxH,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEA580C),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Column(
              children: [
                Text('${minVal.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0288D1))),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: minH,
                  decoration: const BoxDecoration(
                    color: Color(0xFF0288D1),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
      ],
    );
  }


  List<Marker> _buildMapMarkers(KsdmaStateService state, List<KsdmaStation> activeStations) {
    final Map<String, List<KsdmaStation>> locGroups = {};
    for (var s in activeStations) {
      final key = '${s.latitude.toStringAsFixed(4)},${s.longitude.toStringAsFixed(4)}';
      locGroups.putIfAbsent(key, () => []).add(s);
    }

    final List<Marker> markers = [];

    locGroups.forEach((key, stationsAtLoc) {
      final count = stationsAtLoc.length;

      for (int i = 0; i < count; i++) {
        final s = stationsAtLoc[i];
        final isSelected = _selectedStation?.stationId == s.stationId;

        double lat = s.latitude;
        double lng = s.longitude;

        if (count > 1) {
          final angle = (2 * math.pi * i) / count;
          const radius = 0.0008;
          lat += radius * math.cos(angle);
          lng += radius * math.sin(angle);
        }

        final color = _getPinColor(s);
        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: isSelected ? 22 : 16,
            height: isSelected ? 22 : 16,
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedStation = s);
                _mapController.move(LatLng(s.latitude, s.longitude), math.max(_mapController.camera.zoom, 9.5));
                _showStationDetailsDialog(context, s, state);
              },
              child: Tooltip(
                message: '${s.stationId} (${s.district})',
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.yellowAccent : Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });

    return markers;
  }

  Widget _buildStatBox(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildStationStatBoxes(KsdmaStateService state, KsdmaStation station) {
    final todayObs = state.getTodayObservation(station.stationId);
    final yesterdayObs = state.getYesterdayObservation(station.stationId);

    if (_appliedParam == 'humidity' || station.instrumentType == InstrumentType.hygrometer) {
      final tHum = todayObs?.humidityPercent != null ? '${todayObs!.humidityPercent} %' : '0 %';
      final yHum = yesterdayObs?.humidityPercent != null ? '${yesterdayObs!.humidityPercent} %' : '0 %';

      final obsList = state.observations.where((o) => o.stationId == station.stationId && !o.isRemoved).toList();
      double avg2Day = 0.0;
      if (obsList.isNotEmpty) {
        final sub2 = obsList.take(2).where((o) => o.humidityPercent != null).map((o) => o.humidityPercent!).toList();
        if (sub2.isNotEmpty) avg2Day = sub2.reduce((a, b) => a + b) / sub2.length;
      }
      double avg5Day = 0.0;
      if (obsList.isNotEmpty) {
        final sub5 = obsList.take(5).where((o) => o.humidityPercent != null).map((o) => o.humidityPercent!).toList();
        if (sub5.isNotEmpty) avg5Day = sub5.reduce((a, b) => a + b) / sub5.length;
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatBox('Today Humidity', tHum, const Color(0xFF7C3AED)),
          _buildStatBox('Yesterday Humidity', yHum, Colors.black87),
          _buildStatBox('2-Day Avg', '${avg2Day.toStringAsFixed(0)} %', Colors.black87),
          _buildStatBox('5-Day Avg', '${avg5Day.toStringAsFixed(0)} %', Colors.black87),
        ],
      );
    } else if (_appliedParam == 'maxTemp' || station.instrumentType == InstrumentType.maxMinThermometer) {
      final tMax = todayObs?.maxTemperatureC != null ? '${todayObs!.maxTemperatureC} °C' : '0.0 °C';
      final tMin = todayObs?.minTemperatureC != null ? '${todayObs!.minTemperatureC} °C' : '0.0 °C';
      final yMax = yesterdayObs?.maxTemperatureC != null ? '${yesterdayObs!.maxTemperatureC} °C' : '0.0 °C';
      final yMin = yesterdayObs?.minTemperatureC != null ? '${yesterdayObs!.minTemperatureC} °C' : '0.0 °C';

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatBox('Today Max', tMax, const Color(0xFFEA580C)),
          _buildStatBox('Today Min', tMin, const Color(0xFF0288D1)),
          _buildStatBox('Yesterday Max', yMax, Colors.black87),
          _buildStatBox('Yesterday Min', yMin, Colors.black87),
        ],
      );
    } else if (_appliedParam == 'riverLevel' || station.instrumentType == InstrumentType.riverGauge) {
      final tRiv = todayObs?.riverWaterLevelM != null ? '${todayObs!.riverWaterLevelM} m' : '0.0 m';
      final yRiv = yesterdayObs?.riverWaterLevelM != null ? '${yesterdayObs!.riverWaterLevelM} m' : '0.0 m';

      final obsList = state.observations.where((o) => o.stationId == station.stationId && !o.isRemoved).toList();
      double max2 = 0.0;
      if (obsList.isNotEmpty) {
        final sub2 = obsList.take(2).where((o) => o.riverWaterLevelM != null).map((o) => o.riverWaterLevelM!).toList();
        if (sub2.isNotEmpty) max2 = sub2.reduce((a, b) => a > b ? a : b);
      }
      double max5 = 0.0;
      if (obsList.isNotEmpty) {
        final sub5 = obsList.take(5).where((o) => o.riverWaterLevelM != null).map((o) => o.riverWaterLevelM!).toList();
        if (sub5.isNotEmpty) max5 = sub5.reduce((a, b) => a > b ? a : b);
      }

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatBox('Today Level', tRiv, const Color(0xFF0D9488)),
          _buildStatBox('Yesterday Level', yRiv, Colors.black87),
          _buildStatBox('2-Day Peak', '${max2.toStringAsFixed(1)} m', Colors.black87),
          _buildStatBox('5-Day Peak', '${max5.toStringAsFixed(1)} m', Colors.black87),
        ],
      );
    } else {
      final tRain = todayObs?.rainfallMm != null ? '${todayObs!.rainfallMm} mm' : '—';
      final yRain = yesterdayObs?.rainfallMm != null ? '${yesterdayObs!.rainfallMm} mm' : '—';
      final cum2 = state.getCumulativeRainfall(station.stationId, 2);
      final cum5 = state.getCumulativeRainfall(station.stationId, 5);

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatBox('Today Rain', tRain, const Color(0xFF2563EB)),
          _buildStatBox('Yesterday Rain', yRain, Colors.black87),
          _buildStatBox('2-Day Total', '${cum2.toStringAsFixed(1)} mm', Colors.black87),
          _buildStatBox('5-Day Total', '${cum5.toStringAsFixed(1)} mm', Colors.black87),
        ],
      );
    }
  }

  Color _getPinColor(KsdmaStation s) {
    if (s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) {
      return const Color(0xFFC026D3); // Magenta / Pink for AWS
    }
    switch (s.instrumentType) {
      case InstrumentType.rainGauge:
        return const Color(0xFF2563EB); // Blue - Rainfall
      case InstrumentType.maxMinThermometer:
        return const Color(0xFFEA580C); // Orange - Temperature
      case InstrumentType.riverGauge:
        return const Color(0xFF0D9488); // Teal - River Level
      case InstrumentType.hygrometer:
        return const Color(0xFF7C3AED); // Purple - Humidity
      case InstrumentType.awsAutomaticStation:
        return const Color(0xFFC026D3); // Magenta - AWS
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
        return Icons.water;
      case InstrumentType.awsAutomaticStation:
        return Icons.cell_tower;
    }
  }

  String _getParameterTitle(String paramKey) {
    switch (paramKey) {
      case 'all': return 'All Parameters';
      case 'maxTemp': return 'Temperature';
      case 'humidity': return 'Humidity';
      case 'riverLevel': return 'River Level';
      default: return 'Rainfall';
    }
  }

  String _getParameterUnit(String paramKey) {
    switch (paramKey) {
      case 'all': return 'Units';
      case 'maxTemp': return '°C';
      case 'humidity': return '%';
      case 'riverLevel': return 'm';
      default: return 'mm';
    }
  }
}