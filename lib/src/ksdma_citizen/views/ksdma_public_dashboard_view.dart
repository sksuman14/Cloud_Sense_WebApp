// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_auth_modal.dart';

class KsdmaPublicDashboardView extends StatefulWidget {
  final Function(int tabIndex)? onNavigate;

  const KsdmaPublicDashboardView({super.key, this.onNavigate});

  @override
  State<KsdmaPublicDashboardView> createState() => _KsdmaPublicDashboardViewState();
}

class _KsdmaPublicDashboardViewState extends State<KsdmaPublicDashboardView> {
  KsdmaStation? _selectedStation;

  String _selectedParam = 'rainfall';
  String _selectedAggregation = 'Cumulative';
  String _selectedDistrict = 'All Districts';

  String _appliedParam = 'rainfall';
  String _appliedAggregation = 'Cumulative';
  String _appliedDistrict = 'All Districts';

  String _activeDeltaTab = 'Rainfall';

  final List<String> _keralaDistricts = const [
    'All Districts',
    'Alappuzha',
    'Ernakulam',
    'Idukki',
    'Kannur',
    'Kasaragod',
    'Kollam',
    'Kottayam',
    'Kozhikode',
    'Malappuram',
    'Palakkad',
    'Pathanamthitta',
    'Thiruvananthapuram',
    'Thrissur',
    'Wayanad',
  ];

  @override
  void initState() {
    super.initState();
    // Lazy load: fetch stations & observations only when Dashboard opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = Provider.of<KsdmaStateService>(context, listen: false);
      state.fetchStationsIfNeeded();
      state.fetchObservationsIfNeeded();
    });
  }

  void _applyFilters(KsdmaStateService state) {
    // Check if the selected district has any stations
    if (_selectedDistrict != 'All Districts') {
      final allStations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;
      final inDistrict = allStations.where((s) {
        if (s.district.toLowerCase().trim() != _selectedDistrict.toLowerCase().trim()) return false;
        // Filter by Parameter: only include stations supporting the selected parameter
        if (s.category != StationCategory.aws && s.instrumentType != InstrumentType.awsAutomaticStation) {
          if (_selectedParam == 'maxTemp' && s.instrumentType != InstrumentType.maxMinThermometer) return false;
          if (_selectedParam == 'humidity' && s.instrumentType != InstrumentType.hygrometer) return false;
          if (_selectedParam == 'riverLevel' && s.instrumentType != InstrumentType.riverGauge) return false;
          if (_selectedParam == 'rainfall' && s.instrumentType != InstrumentType.rainGauge) return false;
        }
        return true;
      }).toList();

      if (inDistrict.isEmpty) {
        // Show message and reset district back to previous value
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No stations found in "$_selectedDistrict". Filter not applied.',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
        // Reset district selection back to All Districts
        setState(() => _selectedDistrict = 'All Districts');
        return;
      }
    }

    setState(() {
      _appliedParam = _selectedParam;
      // Aggregation only makes physical sense for Rainfall (cumulative total vs average).
      // For Temperature/Humidity/River Level always use Average — force it here so every
      // panel (chart, delta table, stat boxes, CSV) stays consistent with the dropdown.
      _appliedAggregation = _selectedParam == 'rainfall' ? _selectedAggregation : 'Average';
      _appliedDistrict = _selectedDistrict;

      state.selectedParameter = _selectedParam;
      state.selectedDistrict = _selectedDistrict;

      if (_selectedParam == 'maxTemp') {
        _activeDeltaTab = 'Temperature';
      } else if (_selectedParam == 'humidity') {
        _activeDeltaTab = 'Humidity';
      } else if (_selectedParam == 'riverLevel') {
        _activeDeltaTab = 'River Level';
      } else {
        _activeDeltaTab = 'Rainfall';
      }
    });
  }

  void _resetFilters(KsdmaStateService state) {
    setState(() {
      _selectedParam = 'rainfall';
      _selectedAggregation = 'Cumulative';
      _selectedDistrict = 'All Districts';

      _appliedParam = 'rainfall';
      _appliedAggregation = 'Cumulative';
      _appliedDistrict = 'All Districts';

      _selectedStation = null; // Reset station selection to show all stations

      state.selectedParameter = 'rainfall';
      state.selectedDistrict = 'All Districts';
      _activeDeltaTab = 'Rainfall';
    });
  }

  void _downloadFilteredDataCsv(KsdmaStateService state) {
    final observations = state.observations.where((o) => !o.isRemoved).toList();

    final StringBuffer csv = StringBuffer();
    csv.writeln('Station ID,District,Grama Panchayat,Observation Date,Observation Time,Rainfall (mm),Max Temp (C),Min Temp (C),Humidity (%),River Level (m),Source');

    int count = 0;
    for (var o in observations) {
      final stnList = state.stations.where((s) => s.stationId == o.stationId).toList();
      final stn = stnList.isNotEmpty ? stnList.first : null;

      final district = stn?.district ?? 'Kerala';
      final panchayat = stn?.gramaPanchayat ?? '';

      if (_appliedDistrict != 'All Districts' && district.toLowerCase().trim() != _appliedDistrict.toLowerCase().trim()) {
        continue;
      }

      final dateStr = "${o.observationDate.year}-${o.observationDate.month.toString().padLeft(2, '0')}-${o.observationDate.day.toString().padLeft(2, '0')}";
      final timeStr = "${o.observationTime.hour.toString().padLeft(2, '0')}:${o.observationTime.minute.toString().padLeft(2, '0')}";

      csv.writeln(
        '"${o.stationId}","${district}","${panchayat}","${dateStr}","${timeStr}",${o.rainfallMm ?? ""},${o.maxTemperatureC ?? ""},${o.minTemperatureC ?? ""},${o.humidityPercent ?? ""},${o.riverWaterLevelM ?? ""},"${o.source}"'
      );
      count++;
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final fileName = 'KSDMA_Weather_${_appliedDistrict.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Downloaded CSV with $count observation records for $_appliedDistrict'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 4),
      ),
    );
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = stations.where((s) {
            final query = searchQuery.toLowerCase().trim();
            if (query.isEmpty) return true;
            return s.stationId.toLowerCase().contains(query) ||
                s.district.toLowerCase().contains(query) ||
                s.gramaPanchayat.toLowerCase().contains(query) ||
                s.instrumentType.name.toLowerCase().contains(query);
          }).toList();

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 800,
              height: 620,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'All Latest Weather Observations (${stations.length} Active Stations)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                              ),
                              Text(
                                'Showing real-time weather observations across $_appliedDistrict',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

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

                  const SizedBox(height: 14),

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
                              final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);

                              final rain = obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '0.0 mm';
                              final maxTemp = obs?.maxTemperatureC != null ? '${obs!.maxTemperatureC}°C' : '—';
                              final minTemp = obs?.minTemperatureC != null ? '${obs!.minTemperatureC}°C' : '—';
                              final hum = obs?.humidityPercent != null ? '${obs!.humidityPercent}%' : '—';
                              final river = obs?.riverWaterLevelM != null ? '${obs!.riverWaterLevelM} m' : '—';

                              String timeStr = 'Today 08:00 AM';
                              if (obs != null) {
                                final dt = obs.observationDate.toLocal();
                                final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                                final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                                final minStr = dt.minute.toString().padLeft(2, '0');
                                timeStr = '${dt.day}/${dt.month} ${hour.toString().padLeft(2, '0')}:$minStr $ampm';
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                                          Row(
                                            children: [
                                              Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(s.instrumentType.name, style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '${s.gramaPanchayat.isNotEmpty ? "${s.gramaPanchayat}, " : ""}${s.district}',
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Wrap(
                                        spacing: 12,
                                        children: [
                                          _buildDetailChip('Rainfall', rain, const Color(0xFF1D4ED8)),
                                          _buildDetailChip('Max Temp', maxTemp, const Color(0xFFE65100)),
                                          _buildDetailChip('Min Temp', minTemp, const Color(0xFF0288D1)),
                                          _buildDetailChip('Humidity', hum, const Color(0xFF7E22CE)),
                                          _buildDetailChip('River Level', river, const Color(0xFF0D9488)),
                                        ],
                                      ),
                                    ),
                                    Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
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

  Widget _buildDetailChip(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final allStations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;
    final filteredStations = allStations.where((s) {
      if (_appliedDistrict != 'All Districts' && s.district.toLowerCase() != _appliedDistrict.toLowerCase()) {
        return false;
      }
      // Parameter Capability Filter: Rain Gauges measure Rainfall, Hygrometers measure Humidity, etc.
      // AWS stations measure all parameters.
      if (s.category != StationCategory.aws && s.instrumentType != InstrumentType.awsAutomaticStation) {
        if (_appliedParam == 'maxTemp' && s.instrumentType != InstrumentType.maxMinThermometer) return false;
        if (_appliedParam == 'humidity' && s.instrumentType != InstrumentType.hygrometer) return false;
        if (_appliedParam == 'riverLevel' && s.instrumentType != InstrumentType.riverGauge) return false;
        if (_appliedParam == 'rainfall' && s.instrumentType != InstrumentType.rainGauge) return false;
      }
      return true;
    }).toList();

    final activeStations = filteredStations;

    if (_selectedStation != null && !activeStations.any((s) => s.stationId == _selectedStation!.stationId)) {
      _selectedStation = null;
    }

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todayObs = state.observations.where((o) {
      if (o.isRemoved) return false;
      final d = o.observationDate.toLocal();
      if (d.year != todayDate.year || d.month != todayDate.month || d.day != todayDate.day) {
        return false;
      }
      if (_appliedDistrict != 'All Districts') {
        final st = activeStations.firstWhere(
          (s) => s.stationId == o.stationId,
          orElse: () => KsdmaStation(
            stationId: '', ownerUserId: 'N/A', ownerName: 'N/A',
            ownerCategory: UserCategory.generalPublic, category: StationCategory.manual,
            instrumentType: InstrumentType.rainGauge, deviceMake: 'Standard',
            measurementLocation: 'Open Field', latitude: 0, longitude: 0,
            district: '', taluk: '', gramaPanchayat: '', village: '',
            approvalStatus: ApprovalStatus.pending, createdAt: DateTime.now(),
          ),
        );
        if (st.stationId.isEmpty) return false;
      }
      return true;
    }).toList();

    // Distinct stations that actually reported today (an entries-count can exceed the
    // station count if a station submitted more than once, which used to push the
    // "Observations Today" metric above 100%).
    final reportingStationIdsToday = todayObs.map((o) => o.stationId).toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop = constraints.maxWidth >= 1050;
        final bool isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1050;
        final bool isMobile = constraints.maxWidth < 650;

        final metricCardsList = [
          _buildMetricCard(
            title: 'Total Stations',
            value: '${activeStations.length}',
            subtitle: _appliedDistrict == 'All Districts' ? 'Across Kerala' : 'In $_appliedDistrict',
            icon: Icons.cell_tower,
            color: const Color(0xFF1565C0),
          ),
          _buildMetricCard(
            title: 'Stations Reporting Today',
            value: '${reportingStationIdsToday.length}',
            subtitle: activeStations.isEmpty
                ? '0% Active'
                : '${((reportingStationIdsToday.length / activeStations.length) * 100).clamp(0, 100).toStringAsFixed(1)}% Active',
            icon: Icons.assignment_turned_in,
            color: const Color(0xFF00897B),
          ),
          _buildMetricCard(
            title: 'Districts Covered',
            value: _appliedDistrict != 'All Districts'
                ? '1 / 14'
                : '${activeStations.map((s) => s.district).toSet().length} / 14',
            subtitle: _appliedDistrict != 'All Districts' ? 'Filtered Region' : 'Coverage',
            icon: Icons.map,
            color: const Color(0xFF6D4C41),
          ),
          _buildMetricCard(
            title: 'Weather Champions',
            value: '${state.champions.where((c) => _appliedDistrict == 'All Districts' || c.district.toLowerCase() == _appliedDistrict.toLowerCase()).length}',
            subtitle: 'Active Volunteers',
            icon: Icons.groups,
            color: const Color(0xFFE65100),
          ),
          _buildMetricCard(
            title: 'Data Quality',
            value: 'Good',
            subtitle: 'KSDMA Weather Cloud Live',
            icon: Icons.verified,
            color: const Color(0xFF2E7D32),
          ),
        ];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Filter Toolbar Ribbon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Wrap(
                  spacing: isMobile ? 6 : 12,
                  runSpacing: isMobile ? 8 : 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildToolbarDropdown(
                      'Parameter',
                      DropdownButton<String>(
                        value: _selectedParam,
                        style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold),
                        dropdownColor: Colors.white,
                        iconEnabledColor: const Color(0xFF0F172A),
                        underline: const SizedBox(),
                        isDense: true,
                        items: [
                          DropdownMenuItem(value: 'rainfall', child: Text('Rainfall', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'maxTemp', child: Text('Temperature', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'riverLevel', child: Text('River Level', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'humidity', child: Text('Humidity', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedParam = val;
                              // Non-rainfall parameters are always shown as an Average
                              // (cumulative humidity/temperature/river level has no
                              // physical meaning), so reset the aggregation choice.
                              if (val != 'rainfall') _selectedAggregation = 'Average';
                            });
                          }
                        },
                      ),
                      isMobile: isMobile,
                    ),
                    _buildToolbarDropdown(
                      'Aggregation',
                      DropdownButton<String>(
                        value: _selectedAggregation,
                        style: TextStyle(
                          color: _selectedParam == 'rainfall' ? const Color(0xFF0F172A) : Colors.grey,
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.bold,
                        ),
                        dropdownColor: Colors.white,
                        iconEnabledColor: _selectedParam == 'rainfall' ? const Color(0xFF0F172A) : Colors.grey,
                        underline: const SizedBox(),
                        isDense: true,
                        items: [
                          DropdownMenuItem(value: 'Cumulative', child: Text('Cumulative', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'Average', child: Text('Average', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                        ],
                        // Only Rainfall supports Cumulative vs Average. For every other
                        // parameter this dropdown is disabled (greyed out) instead of
                        // silently being ignored everywhere else in the dashboard.
                        onChanged: _selectedParam == 'rainfall'
                            ? (val) {
                                if (val != null) setState(() => _selectedAggregation = val);
                              }
                            : null,
                      ),
                      isMobile: isMobile,
                    ),
                    _buildToolbarDropdown(
                      'District',
                      DropdownButton<String>(
                        value: _keralaDistricts.contains(_selectedDistrict) ? _selectedDistrict : 'All Districts',
                        style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12, fontWeight: FontWeight.bold),
                        dropdownColor: Colors.white,
                        iconEnabledColor: const Color(0xFF0F172A),
                        underline: const SizedBox(),
                        isDense: true,
                        items: _keralaDistricts.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDistrict = val);
                        },
                      ),
                      isMobile: isMobile,
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _applyFilters(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _resetFilters(state),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Colors.black26),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                          child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _downloadFilteredDataCsv(state),
                          icon: const Icon(Icons.download, size: 14),
                          label: const Text('Download Data', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Top Metric Cards Row (Responsive Grid / Row)
              if (isDesktop)
                Row(
                  children: metricCardsList.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8.0), child: c))).toList(),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: metricCardsList.map((c) => SizedBox(
                    width: isTablet ? (constraints.maxWidth - 52) / 3 : (constraints.maxWidth - 44) / 2,
                    child: c,
                  )).toList(),
                ),

              const SizedBox(height: 14),

              // 3. Main Dashboard Grid (Responsive Desktop Row vs Mobile Column)
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildDashboardCol1(state, activeStations, isMobile)),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildDashboardCol2(state, activeStations, todayDate)),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildDashboardCol3(state, activeStations)),
                  ],
                ),
              ] else ...[
                Column(
                  children: [
                    _buildDashboardCol1(state, activeStations, isMobile),
                    const SizedBox(height: 14),
                    _buildDashboardCol2(state, activeStations, todayDate),
                    const SizedBox(height: 14),
                    _buildDashboardCol3(state, activeStations),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              // 4. Bottom Action Banner Cards (Responsive Grid / Row)
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

  Widget _buildDashboardCol1(KsdmaStateService state, List<KsdmaStation> activeStations, bool isMobile) {
    return Column(
      children: [
        // Live Spatial Map Box
        Container(
          height: isMobile ? 320 : 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: activeStations.isNotEmpty
                        ? LatLng(activeStations.first.latitude, activeStations.first.longitude)
                        : const LatLng(10.8505, 76.2711),
                    initialZoom: _appliedDistrict == 'All Districts' ? 7.2 : 9.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cloudsense.webapp',
                    ),
                    MarkerLayer(
                      markers: _buildMapMarkers(activeStations),
                    ),
                  ],
                ),

                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Text(
                      'Live ${_getParameterTitle(_appliedParam)} Map ($_appliedDistrict)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Latest Observations Table
        Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Latest Observations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                    InkWell(
                      onTap: () => _showAllLatestObservationsModal(context, state, activeStations),
                      child: const Text('View All >', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                if (activeStations.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(
                      child: Text('No active stations found for selected filters.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ),
                  )
                else ...[
                  ...activeStations.take(5).map((s) {
                    final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
                    String valStr = '0.0 mm';
                    if (obs != null) {
                      if (_appliedParam == 'maxTemp') {
                        valStr = obs.maxTemperatureC != null ? '${obs.maxTemperatureC} °C' : '0.0 °C';
                      } else if (_appliedParam == 'humidity') {
                        valStr = obs.humidityPercent != null ? '${obs.humidityPercent} %' : '0 %';
                      } else if (_appliedParam == 'riverLevel') {
                        valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM} m' : '0.0 m';
                      } else {
                        valStr = obs.rainfallMm != null ? '${obs.rainfallMm} mm' : '0.0 mm';
                      }
                    }

                    String timeStr = '08:00 AM';
                    if (obs != null) {
                      final dt = obs.observationDate.toLocal();
                      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
                      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                      final minStr = dt.minute.toString().padLeft(2, '0');
                      timeStr = '${hour.toString().padLeft(2, '0')}:$minStr $ampm';
                    }
                    final isSelected = _selectedStation?.stationId == s.stationId;
                    return InkWell(
                      onTap: () => setState(() => _selectedStation = s),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1565C0).withValues(alpha: 0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: _buildObsRow(s.stationId, '${s.gramaPanchayat.isNotEmpty ? "${s.gramaPanchayat}, " : ""}${s.district}', valStr, timeStr, Colors.blue),
                      ),
                    );
                  }),
                  if (activeStations.length > 5) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => _showAllLatestObservationsModal(context, state, activeStations),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: Text(
                          'View All ${activeStations.length} Stations & Observations →',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardCol2(KsdmaStateService state, List<KsdmaStation> activeStations, DateTime todayDate) {
    return Column(
      children: [
        // Dynamic Parameter Chart Box
        Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Builder(
              builder: (context) {
                bool isTemp = _appliedParam == 'maxTemp';
                bool isHum = _appliedParam == 'humidity';
                bool isRiver = _appliedParam == 'riverLevel';

                // No station selected → show rich Statewide Parameter Summary View
                if (_selectedStation == null) {
                  KsdmaStation? topStation;
                  KsdmaStation? lowStation;
                  double topVal = -999.0;
                  double lowVal = 999.0;
                  double totalVal = 0.0;
                  int reportingCount = 0;

                  for (var s in activeStations) {
                    final obs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
                    if (obs != null) {
                      double val = 0.0;
                      if (isTemp) val = obs.maxTemperatureC ?? 0.0;
                      else if (isHum) val = obs.humidityPercent ?? 0.0;
                      else if (isRiver) val = obs.riverWaterLevelM ?? 0.0;
                      else val = obs.rainfallMm ?? 0.0;

                      totalVal += val;
                      reportingCount++;
                      if (val > topVal) { topVal = val; topStation = s; }
                      if (val < lowVal) { lowVal = val; lowStation = s; }
                    }
                  }

                  final avgVal = reportingCount > 0 ? totalVal / reportingCount : 0.0;
                  final unit = _getParameterUnit(_appliedParam);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Statewide ${_getParameterTitle(_appliedParam)} Highlights',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.touch_app, size: 12, color: Color(0xFF1565C0)),
                                SizedBox(width: 4),
                                Text('Tap card to inspect station', style: TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryOverviewCard(
                              title: 'Highest Recorded',
                              station: topStation,
                              value: topStation != null ? '${topVal.toStringAsFixed(1)} $unit' : 'N/A',
                              color: const Color(0xFFE65100),
                              icon: Icons.north_east,
                              onTap: topStation != null ? () => setState(() => _selectedStation = topStation) : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryOverviewCard(
                              title: 'Lowest Recorded',
                              station: lowStation,
                              value: lowStation != null ? '${lowVal.toStringAsFixed(1)} $unit' : 'N/A',
                              color: const Color(0xFF0288D1),
                              icon: Icons.south_east,
                              onTap: lowStation != null ? () => setState(() => _selectedStation = lowStation) : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatBox('Kerala Avg ${_getParameterTitle(_appliedParam)}', '${avgVal.toStringAsFixed(1)} $unit', const Color(0xFF1565C0)),
                            _buildStatBox('Reporting Stations', '$reportingCount / ${activeStations.length}', const Color(0xFF00897B)),
                            _buildStatBox('Region Filter', _appliedDistrict, const Color(0xFF6D4C41)),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final title = '${_selectedStation!.stationId} - ${_getParameterTitle(_appliedParam)} $_appliedAggregation (${_getParameterUnit(_appliedParam)})';

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
                    if (_selectedStation != null && o.stationId != _selectedStation!.stationId) {
                      continue;
                    }
                    final obsLocal = o.observationDate.toLocal();
                    final obsDate = DateTime(obsLocal.year, obsLocal.month, obsLocal.day);

                    if (days == 1) {
                      if (obsDate.year == todayDate.year && obsDate.month == todayDate.month && obsDate.day == todayDate.day) {
                        sum += getValue(o);
                        count++;
                      }
                    } else {
                      final cutoffDate = todayDate.subtract(Duration(days: days - 1));
                      if (!obsDate.isBefore(cutoffDate)) {
                        sum += getValue(o);
                        count++;
                      }
                    }
                  }

                  if (days == 1 && count == 0 && _selectedStation != null) {
                    final tObs = state.getTodayObservation(_selectedStation!.stationId);
                    if (tObs != null) return getValue(tObs);
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
                    if (_selectedStation != null && o.stationId != _selectedStation!.stationId) continue;
                    final obsLocal = o.observationDate.toLocal();
                    final obsDate = DateTime(obsLocal.year, obsLocal.month, obsLocal.day);

                    bool matchDate = (days == 1)
                        ? (obsDate.year == todayDate.year && obsDate.month == todayDate.month && obsDate.day == todayDate.day)
                        : (!obsDate.isBefore(todayDate.subtract(Duration(days: days - 1))));

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

                  if (days == 1 && _selectedStation != null) {
                    final tObs = state.getTodayObservation(_selectedStation!.stationId);
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

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B)), maxLines: 1)),
                        if (isTemp)
                          Row(
                            children: [
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFE65100), shape: BoxShape.circle)),
                              const SizedBox(width: 3),
                              const Text('Max Temp', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
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
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 12),

          // Station Details Card
        if (_selectedStation != null)
          Card(
            color: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _getPinColor(_selectedStation!).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(_getPinIcon(_selectedStation!), color: _getPinColor(_selectedStation!), size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_selectedStation!.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Active', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            Text('Owner: ${_selectedStation!.ownerName}', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500)),
                            Text('Device: ${_selectedStation!.instrumentType.displayName}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                        tooltip: 'Deselect Station',
                        onPressed: () => setState(() => _selectedStation = null),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  _buildStationStatBoxes(state, _selectedStation!),
                ],
              ),
            ),
          )
        else
          Card(
            color: const Color(0xFFF8FAFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.blue.shade100, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_outlined, color: Color(0xFF1565C0), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Overview — All Stations',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeStations.length} stations available — tap a map pin or a station row to view details',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  // Previously computed but never rendered — now the "no station selected"
                  // state actually shows an aggregate summary instead of an empty prompt.
                  _buildAllStationsStatBoxes(state, activeStations),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDashboardCol3(KsdmaStateService state, List<KsdmaStation> activeStations) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change with respect to Previous Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),

            // Parameter Sub-tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Rainfall', 'Temperature', 'Humidity', 'River Level'].map((tab) {
                  final isSel = _activeDeltaTab == tab;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(tab, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSel ? Colors.white : const Color(0xFF0F172A))),
                      selected: isSel,
                      backgroundColor: const Color(0xFFF1F5F9),
                      selectedColor: const Color(0xFF1565C0),
                      onSelected: (_) => setState(() => _activeDeltaTab = tab),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 8),

            // District Delta Table
            if (activeStations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No stations available for selected filters.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              )
            else
              Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(1.5),
                3: FlexColumnWidth(1.5),
              },
              children: [
                const TableRow(
                  decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                  children: [
                    Padding(padding: EdgeInsets.all(6), child: Text('District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                  ],
                ),
                ...() {
                    if (_activeDeltaTab == 'Temperature') {
                      final List<TableRow> tempRows = [];
                      for (var dist in activeStations.map((s) => s.district).toSet()) {
                        final distStations = activeStations.where((s) => s.district == dist).toList();
                        double todayMax = 0.0, todayMin = 0.0;
                        double yestMax = 0.0, yestMin = 0.0;
                        int todayMaxCount = 0, todayMinCount = 0;
                        int yestMaxCount = 0, yestMinCount = 0;

                        for (var s in distStations) {
                          final tObs = state.getTodayObservation(s.stationId);
                          final yObs = state.getYesterdayObservation(s.stationId);

                          if (tObs != null) {
                            if (tObs.maxTemperatureC != null) { todayMax += tObs.maxTemperatureC!; todayMaxCount++; }
                            if (tObs.minTemperatureC != null) { todayMin += tObs.minTemperatureC!; todayMinCount++; }
                          }
                          if (yObs != null) {
                            if (yObs.maxTemperatureC != null) { yestMax += yObs.maxTemperatureC!; yestMaxCount++; }
                            if (yObs.minTemperatureC != null) { yestMin += yObs.minTemperatureC!; yestMinCount++; }
                          }
                        }

                        final avgTodayMax = todayMaxCount > 0 ? todayMax / todayMaxCount : 0.0;
                        final avgTodayMin = todayMinCount > 0 ? todayMin / todayMinCount : 0.0;
                        final avgYestMax = yestMaxCount > 0 ? yestMax / yestMaxCount : 0.0;
                        final avgYestMin = yestMinCount > 0 ? yestMin / yestMinCount : 0.0;

                        final diffMax = avgTodayMax - avgYestMax;
                        final diffMin = avgTodayMin - avgYestMin;

                        tempRows.add(_buildTableRow(
                          '$dist (Max)',
                          '${avgTodayMax.toStringAsFixed(1)} °C',
                          '${avgYestMax.toStringAsFixed(1)} °C',
                          '${diffMax > 0 ? '+' : ''}${diffMax.toStringAsFixed(1)} °C ${diffMax > 0 ? '↑' : diffMax < 0 ? '↓' : '—'}',
                          diffMax > 0 ? const Color(0xFFE65100) : Colors.grey,
                        ));

                        tempRows.add(_buildTableRow(
                          '$dist (Min)',
                          '${avgTodayMin.toStringAsFixed(1)} °C',
                          '${avgYestMin.toStringAsFixed(1)} °C',
                          '${diffMin > 0 ? '+' : ''}${diffMin.toStringAsFixed(1)} °C ${diffMin > 0 ? '↑' : diffMin < 0 ? '↓' : '—'}',
                          diffMin > 0 ? const Color(0xFF0288D1) : Colors.grey,
                        ));
                      }
                      return tempRows;
                    }

                    return activeStations.map((s) => s.district).toSet().map((dist) {
                      final distStations = activeStations.where((s) => s.district == dist).toList();
                      double todayTotal = 0.0;
                      double yestTotal = 0.0;
                      int todayCount = 0;
                      int yestCount = 0;
                      final unit = _activeDeltaTab == 'Humidity'
                          ? '%'
                          : _activeDeltaTab == 'River Level'
                              ? 'm'
                              : 'mm';

                      for (var s in distStations) {
                        final tObs = state.getTodayObservation(s.stationId);
                        final yObs = state.getYesterdayObservation(s.stationId);

                        if (tObs != null) {
                          double? val;
                          if (_activeDeltaTab == 'Humidity') val = tObs.humidityPercent;
                          else if (_activeDeltaTab == 'River Level') val = tObs.riverWaterLevelM;
                          else val = tObs.rainfallMm;
                          if (val != null) { todayTotal += val; todayCount++; }
                        }

                        if (yObs != null) {
                          double? val;
                          if (_activeDeltaTab == 'Humidity') val = yObs.humidityPercent;
                          else if (_activeDeltaTab == 'River Level') val = yObs.riverWaterLevelM;
                          else val = yObs.rainfallMm;
                          if (val != null) { yestTotal += val; yestCount++; }
                        }
                      }

                      final bool isAvg = _activeDeltaTab == 'Humidity' || _activeDeltaTab == 'River Level';
                      final todayVal = (isAvg && todayCount > 0) ? todayTotal / todayCount : todayTotal;
                      final yestVal = (isAvg && yestCount > 0) ? yestTotal / yestCount : yestTotal;
                      final diff = todayVal - yestVal;

                      return _buildTableRow(
                        dist,
                        '${todayVal.toStringAsFixed(1)} $unit',
                        '${yestVal.toStringAsFixed(1)} $unit',
                        '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} $unit ${diff > 0 ? '↑' : diff < 0 ? '↓' : '—'}',
                        diff > 0 ? const Color(0xFFE65100) : diff < 0 ? Colors.blue : Colors.grey,
                      );
                    }).toList();
                  }(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPromoCardsList(KsdmaStateService state) {
    final isAdmin = state.isLoggedIn &&
        (state.currentUser.role == UserRole.admin ||
            state.currentUser.category == UserCategory.adminHq ||
            state.currentUser.fullName.contains('Admin'));

    return [
      _buildPromoCard(
        title: isAdmin
            ? 'Admin Management'
            : (state.isLoggedIn ? 'Register Instrument' : 'Become a Volunteer'),
        subtitle: isAdmin
            ? 'Review station registration approvals & moderate data.'
            : (state.isLoggedIn
                ? 'Add your weather gauge or AWS to the KSDMA network.'
                : 'Register as a Volunteer to submit daily weather observations.'),
        btnLabel: isAdmin
            ? '⚙️ Open Admin Dashboard'
            : (state.isLoggedIn ? '➕ Register Instrument' : '🙋 Register as Volunteer'),
        btnColor: isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF2E7D32),
        icon: isAdmin ? Icons.admin_panel_settings : Icons.person_add_alt_1,
        onTap: () {
          if (!state.isLoggedIn) {
            KsdmaAuthModal.show(context, state);
          } else if (isAdmin) {
            widget.onNavigate?.call(7);
          } else {
            widget.onNavigate?.call(6);
          }
        },
      ),
      _buildPromoCard(
        title: 'How to Take Observations?',
        subtitle: 'Watch video tutorials and download the user manual.',
        btnLabel: 'View Tutorials',
        btnColor: const Color(0xFF1565C0),
        icon: Icons.play_circle_fill,
        onTap: () => widget.onNavigate?.call(5),
      ),
      _buildPromoCard(
        title: 'Share Data with Admin',
        subtitle: 'Facing difficulty entering data? Share via WhatsApp group.',
        btnLabel: 'Share Now',
        btnColor: const Color(0xFFE65100),
        icon: Icons.chat_bubble_outline,
        onTap: () => _showWhatsAppShareDialog(context),
      ),
      _buildPromoCard(
        title: 'Weather Champions',
        subtitle: 'Meet our top contributors and become a champion!',
        btnLabel: 'View Champions',
        btnColor: const Color(0xFF6A1B9A),
        icon: Icons.emoji_events,
        onTap: () => widget.onNavigate?.call(4),
      ),
    ];
  }

  String _getParameterTitle(String paramKey) {
    switch (paramKey) {
      case 'maxTemp': return 'Temperature';
      case 'humidity': return 'Humidity';
      case 'riverLevel': return 'River Level';
      default: return 'Rainfall';
    }
  }

  String _getParameterUnit(String paramKey) {
    switch (paramKey) {
      case 'maxTemp': return '°C';
      case 'humidity': return '%';
      case 'riverLevel': return 'm';
      default: return 'mm';
    }
  }

  Widget _buildToolbarDropdown(String label, Widget child, {bool isMobile = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 10 : 12, color: const Color(0xFF334155))),
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 5 : 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.black12),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)), maxLines: 1),
                Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey), maxLines: 1),
              ],
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
            color: const Color(0xFF1565C0),
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
                Text('${maxVal.toStringAsFixed(1)}°', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFE65100))),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: maxH,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE65100),
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

  Widget _buildObsRow(String title, String loc, String val, String time, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 14),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Text(loc, style: const TextStyle(fontSize: 9, color: Colors.black54)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(val, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              Text(time, style: const TextStyle(fontSize: 9, color: Colors.black54)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryOverviewCard({
    required String title,
    required KsdmaStation? station,
    required String value,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                Icon(icon, size: 14, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(
              station != null ? '${station.stationId} (${station.district})' : 'No station data',
              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  TableRow _buildTableRow(String dist, String today, String yest, String change, Color color) {
    return TableRow(
      children: [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(dist, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(today, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)))),
        Padding(padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6), child: Text(yest, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)))),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              change,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStationStatBoxes(KsdmaStateService state, KsdmaStation station) {
    final todayObs = state.getTodayObservation(station.stationId);
    final yesterdayObs = state.getYesterdayObservation(station.stationId);

    // If selected parameter filter is Humidity (or station is Hygrometer)
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

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Today Humidity', tHum, const Color(0xFF8E24AA)),
          _buildStatBox('Yesterday Humidity', yHum, Colors.black87),
          _buildStatBox('2-Day Avg', '${avg2Day.toStringAsFixed(0)} %', Colors.black87),
          _buildStatBox('5-Day Avg', '${avg5Day.toStringAsFixed(0)} %', Colors.black87),
        ],
      );
    } 
    // If selected parameter filter is Temperature (or station is Thermometer)
    else if (_appliedParam == 'maxTemp' || station.instrumentType == InstrumentType.maxMinThermometer) {
      final tMax = todayObs?.maxTemperatureC != null ? '${todayObs!.maxTemperatureC} °C' : '0.0 °C';
      final tMin = todayObs?.minTemperatureC != null ? '${todayObs!.minTemperatureC} °C' : '0.0 °C';
      final yMax = yesterdayObs?.maxTemperatureC != null ? '${yesterdayObs!.maxTemperatureC} °C' : '0.0 °C';
      final yMin = yesterdayObs?.minTemperatureC != null ? '${yesterdayObs!.minTemperatureC} °C' : '0.0 °C';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Today Max', tMax, const Color(0xFF1565C0)),
          _buildStatBox('Today Min', tMin, const Color(0xFF0288D1)),
          _buildStatBox('Yesterday Max', yMax, Colors.black87),
          _buildStatBox('Yesterday Min', yMin, Colors.black87),
        ],
      );
    } 
    // If selected parameter filter is River Level (or station is River Gauge)
    else if (_appliedParam == 'riverLevel' || station.instrumentType == InstrumentType.riverGauge) {
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

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Today Level', tRiv, const Color(0xFF00ACC1)),
          _buildStatBox('Yesterday Level', yRiv, Colors.black87),
          _buildStatBox('2-Day Peak', '${max2.toStringAsFixed(1)} m', Colors.black87),
          _buildStatBox('5-Day Peak', '${max5.toStringAsFixed(1)} m', Colors.black87),
        ],
      );
    } 
    // Default: Rainfall
    else {
      final tRain = todayObs?.rainfallMm != null ? '${todayObs!.rainfallMm} mm' : '0.0 mm';
      final yRain = yesterdayObs?.rainfallMm != null ? '${yesterdayObs!.rainfallMm} mm' : '0.0 mm';
      final cum2 = state.getCumulativeRainfall(station.stationId, 2);
      final cum5 = state.getCumulativeRainfall(station.stationId, 5);

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Today Rain', tRain, const Color(0xFF1565C0)),
          _buildStatBox('Yesterday Rain', yRain, Colors.black87),
          _buildStatBox('2-Day Total', '${cum2.toStringAsFixed(1)} mm', Colors.black87),
          _buildStatBox('5-Day Total', '${cum5.toStringAsFixed(1)} mm', Colors.black87),
        ],
      );
    }
  }

  Widget _buildAllStationsStatBoxes(KsdmaStateService state, List<KsdmaStation> activeStations) {
    if (_appliedParam == 'humidity') {
      double todayHumSum = 0.0;
      int humCount = 0;
      for (var s in activeStations) {
        final tObs = state.getTodayObservation(s.stationId);
        if (tObs?.humidityPercent != null) {
          todayHumSum += tObs!.humidityPercent!;
          humCount++;
        }
      }
      final avgHum = humCount > 0 ? todayHumSum / humCount : 0.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Active Stations', '${activeStations.length}', const Color(0xFF1565C0)),
          _buildStatBox('Avg Today Humidity', '${avgHum.toStringAsFixed(0)} %', const Color(0xFF8E24AA)),
          _buildStatBox('Reporting Stations', '$humCount / ${activeStations.length}', Colors.black87),
          _buildStatBox('Humidity Status', avgHum > 70 ? 'High' : 'Normal', Colors.green),
        ],
      );
    } else if (_appliedParam == 'maxTemp') {
      double todayTempSum = 0.0;
      int tempCount = 0;
      for (var s in activeStations) {
        final tObs = state.getTodayObservation(s.stationId);
        if (tObs?.maxTemperatureC != null) {
          todayTempSum += tObs!.maxTemperatureC!;
          tempCount++;
        }
      }
      final avgTemp = tempCount > 0 ? todayTempSum / tempCount : 0.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Active Stations', '${activeStations.length}', const Color(0xFF1565C0)),
          _buildStatBox('Avg Today Temp', '${avgTemp.toStringAsFixed(1)} °C', const Color(0xFFE65100)),
          _buildStatBox('Reporting Stations', '$tempCount / ${activeStations.length}', Colors.black87),
          _buildStatBox('Temp Status', avgTemp > 35 ? 'Warm' : 'Normal', Colors.blue),
        ],
      );
    } else if (_appliedParam == 'riverLevel') {
      double todayRivSum = 0.0;
      int rivCount = 0;
      for (var s in activeStations) {
        final tObs = state.getTodayObservation(s.stationId);
        if (tObs?.riverWaterLevelM != null) {
          todayRivSum += tObs!.riverWaterLevelM!;
          rivCount++;
        }
      }
      final avgRiv = rivCount > 0 ? todayRivSum / rivCount : 0.0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Active Stations', '${activeStations.length}', const Color(0xFF1565C0)),
          _buildStatBox('Avg River Level', '${avgRiv.toStringAsFixed(1)} m', const Color(0xFF00ACC1)),
          _buildStatBox('Reporting Stations', '$rivCount / ${activeStations.length}', Colors.black87),
          _buildStatBox('Level Status', 'Normal', Colors.green),
        ],
      );
    } else {
      double todayRainSum = 0.0;
      double yesterdayRainSum = 0.0;
      for (var s in activeStations) {
        final tObs = state.getTodayObservation(s.stationId);
        final yObs = state.getYesterdayObservation(s.stationId);
        if (tObs?.rainfallMm != null) todayRainSum += tObs!.rainfallMm!;
        if (yObs?.rainfallMm != null) yesterdayRainSum += yObs!.rainfallMm!;
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatBox('Active Stations', '${activeStations.length}', const Color(0xFF1565C0)),
          _buildStatBox('Today Total Rain', '${todayRainSum.toStringAsFixed(1)} mm', const Color(0xFF0288D1)),
          _buildStatBox('Yesterday Total Rain', '${yesterdayRainSum.toStringAsFixed(1)} mm', Colors.black87),
          _buildStatBox('Rain Status', todayRainSum > 50 ? 'Heavy' : 'Normal', Colors.green),
        ],
      );
    }
  }

  /// Builds map markers with slight coordinate jitter/offset for stations sharing identical lat/lng coordinates
  List<Marker> _buildMapMarkers(List<KsdmaStation> activeStations) {
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
          const radius = 0.0008; // ~90m offset so overlapping pins are clearly separated
          lat += radius * math.cos(angle);
          lng += radius * math.sin(angle);
        }

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: 38,
            height: 38,
            child: GestureDetector(
              onTap: () => setState(() => _selectedStation = s),
              child: Tooltip(
                message: '${s.stationId} (${s.district})',
                child: Container(
                  decoration: BoxDecoration(
                    color: _getPinColor(s),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.yellow : Colors.white,
                      width: isSelected ? 3 : 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(_getPinIcon(s), color: Colors.white, size: 18),
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
        border: Border.all(color: Colors.black12),
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
            child: Text(btnLabel, style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Color _getPinColor(KsdmaStation s) {
    if (s.category == StationCategory.aws) return const Color(0xFF8E24AA);
    switch (s.instrumentType) {
      case InstrumentType.rainGauge:
        return const Color(0xFF1E88E5);
      case InstrumentType.maxMinThermometer:
        return const Color(0xFFFB8C00);
      case InstrumentType.riverGauge:
        return const Color(0xFF00ACC1);
      case InstrumentType.hygrometer:
        return const Color(0xFF8E24AA);
      case InstrumentType.awsAutomaticStation:
        return const Color(0xFFD81B60);
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
}