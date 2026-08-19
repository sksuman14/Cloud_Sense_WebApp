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
import '../theme/ksdma_theme.dart';
import 'ksdma_auth_modal.dart';
import 'ksdma_aws_station_detail_view.dart';

class KsdmaPublicDashboardView extends StatefulWidget {
  final Function(int tabIndex)? onNavigate;

  const KsdmaPublicDashboardView({super.key, this.onNavigate});

  @override
  State<KsdmaPublicDashboardView> createState() => _KsdmaPublicDashboardViewState();
}

class _KsdmaPublicDashboardViewState extends State<KsdmaPublicDashboardView> {
  KsdmaStation? _selectedStation;

  String _selectedParam = 'all';
  String _selectedAggregation = 'Cumulative';
  String _selectedDistrict = 'All Districts';

  String _appliedParam = 'all';
  String _appliedAggregation = 'Cumulative';
  String _appliedDistrict = 'All Districts';

  String _activeDeltaTab = 'Rainfall';
  String? _expandedDeltaDistrict;

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
        if (_selectedParam != 'all' && s.category != StationCategory.aws && s.instrumentType != InstrumentType.awsAutomaticStation) {
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
      _selectedParam = 'all';
      _selectedAggregation = 'Cumulative';
      _selectedDistrict = 'All Districts';

      _appliedParam = 'all';
      _appliedAggregation = 'Cumulative';
      _appliedDistrict = 'All Districts';

      _selectedStation = null; // Reset station selection to show all stations

      state.selectedParameter = 'all';
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

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 820,
              height: 640,
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
                                final rain = obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '0.0 mm';
                                chips.add(_buildDetailChip('Rainfall', rain, const Color(0xFF1D4ED8)));
                              }

                              if (s.instrumentType == InstrumentType.maxMinThermometer || isAws) {
                                final maxTemp = obs?.maxTemperatureC != null ? '${obs!.maxTemperatureC}°C' : '—';
                                final minTemp = obs?.minTemperatureC != null ? '${obs!.minTemperatureC}°C' : '—';
                                chips.add(_buildDetailChip('Max Temp', maxTemp, const Color(0xFFE65100)));
                                chips.add(_buildDetailChip('Min Temp', minTemp, const Color(0xFF0288D1)));
                              }

                              if (s.instrumentType == InstrumentType.hygrometer || isAws) {
                                final hum = obs?.humidityPercent != null ? '${obs!.humidityPercent}%' : '—';
                                chips.add(_buildDetailChip('Humidity', hum, const Color(0xFF7E22CE)));
                              }

                              if (s.instrumentType == InstrumentType.riverGauge || isAws) {
                                final river = obs?.riverWaterLevelM != null ? '${obs!.riverWaterLevelM} m' : '—';
                                chips.add(_buildDetailChip('River Level', river, const Color(0xFF0D9488)));
                              }

                              if (chips.isEmpty) {
                                final rain = obs?.rainfallMm != null ? '${obs!.rainfallMm} mm' : '0.0 mm';
                                chips.add(_buildDetailChip('Rainfall', rain, const Color(0xFF1D4ED8)));
                              }

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
                                                child: Text(s.instrumentType.displayName, style: const TextStyle(fontSize: 9, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
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
                                        runSpacing: 6,
                                        children: chips,
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

  // ignore: unused_element
  Widget _buildStationChartBox(BuildContext context, KsdmaStateService state, KsdmaStation station, DateTime todayDate) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)), maxLines: 1)),
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
  }

  Widget _buildLiveMetricTile(String label, String value, IconData icon, Color color, Color bg) {
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
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
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
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.92,
            constraints: const BoxConstraints(maxWidth: 680),
            padding: const EdgeInsets.all(20),
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
                                Row(
                                  children: [
                                    Text(station.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A))),
                                    const SizedBox(width: 8),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('⚡ Live AWS Telemetry & Sensors', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Updated: $timeStr', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildLiveMetricTile('Rainfall', rainStr, Icons.water_drop, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                    _buildLiveMetricTile('Temperature', tempStr, Icons.thermostat, const Color(0xFFEA580C), const Color(0xFFFFEDD5)),
                    _buildLiveMetricTile('Humidity', humStr, Icons.opacity, const Color(0xFF7C3AED), const Color(0xFFF3E8FF)),
                    _buildLiveMetricTile('Atm. Pressure', pressStr, Icons.speed, const Color(0xFF0D9488), const Color(0xFFCCFBF1)),
                    _buildLiveMetricTile('Wind Speed', windSpdStr, Icons.air, const Color(0xFF0288D1), const Color(0xFFE0F2FE)),
                    _buildLiveMetricTile('Wind Direction', windDirStr, Icons.explore, const Color(0xFFD97706), const Color(0xFFFEF3C7)),
                    _buildLiveMetricTile('Wind Gust', windGustStr, Icons.cyclone, const Color(0xFF475569), const Color(0xFFF1F5F9)),
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
      return;
    }

    // For NON-AWS manual stations: show the original dialog with Graph & Stat Boxes
    _showManualStationGraphDialog(context, station, state);
  }

  void _showManualStationGraphDialog(BuildContext context, KsdmaStation station, KsdmaStateService state) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.92,
          constraints: BoxConstraints(
            maxWidth: 780,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: KsdmaColors.primaryTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_getPinIcon(station), color: KsdmaColors.primary, size: 22),
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
                                    Text(station.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                                    KsdmaBadgeTag(text: station.instrumentType.displayName),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${station.gramaPanchayat.isNotEmpty ? "${station.gramaPanchayat}, " : ""}${station.district} District',
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
                const Divider(height: 20),

                Card(
                  color: Colors.white,
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: _buildStationChartBox(context, state, station, DateTime.now()),
                  ),
                ),

                const SizedBox(height: 16),
                _buildStationStatBoxes(state, station),
              ],
            ),
          ),
        ),
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

  Widget _buildModalDeviceChip(String label, String value, String current, ValueChanged<String> onSelect) {
    final bool isSel = current == value;
    return InkWell(
      onTap: () => onSelect(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
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
      if (_appliedParam != 'all' && s.category != StationCategory.aws && s.instrumentType != InstrumentType.awsAutomaticStation) {
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

        final int rainCount = activeStations.where((s) => s.instrumentType == InstrumentType.rainGauge).length;
        final int tempCount = activeStations.where((s) => s.instrumentType == InstrumentType.maxMinThermometer).length;
        final int humCount = activeStations.where((s) => s.instrumentType == InstrumentType.hygrometer).length;
        final int riverCount = activeStations.where((s) => s.instrumentType == InstrumentType.riverGauge).length;
        final int awsCount = activeStations.where((s) => s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation).length;

        final metricCardsList = [
          _buildMetricCard(
            title: 'Total Stations',
            value: '${activeStations.length}',
            subtitle: 'Live Network',
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
                          DropdownMenuItem(value: 'all', child: Text('All Parameters', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'rainfall', child: Text('Rainfall', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'maxTemp', child: Text('Temperature', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'riverLevel', child: Text('River Level', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                          DropdownMenuItem(value: 'humidity', child: Text('Humidity', style: TextStyle(color: const Color(0xFF0F172A), fontSize: isMobile ? 11 : 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedParam = val;
                              if (val != 'rainfall') _selectedAggregation = 'Average';
                            });
                          }
                        },
                      ),
                      icon: Icons.tune,
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
                        onChanged: _selectedParam == 'rainfall'
                            ? (val) {
                                if (val != null) setState(() => _selectedAggregation = val);
                              }
                            : null,
                      ),
                      icon: Icons.assessment_outlined,
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
                      icon: Icons.map_outlined,
                      isMobile: isMobile,
                    ),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed: () => _applyFilters(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF146356),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Apply', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _resetFilters(state),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _downloadFilteredDataCsv(state),
                          icon: const Icon(Icons.download, size: 14),
                          label: const Text('Download Data', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A322C),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                  spacing: 8,
                  runSpacing: 8,
                  children: metricCardsList.map((c) => SizedBox(width: isTablet ? (constraints.maxWidth - 48) / 3 : constraints.maxWidth - 32, child: c)).toList(),
                ),

              const SizedBox(height: 10),

              // 2b. Station Instrument Breakdown Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFDFE4DA)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.pie_chart_outline, size: 14, color: Color(0xFF475569)),
                        SizedBox(width: 4),
                        Text(
                          'Instrument Breakdown:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    _buildInstrumentCountChip('🌧 Rain Gauges', rainCount, const Color(0xFF3E7CB1)),
                    _buildInstrumentCountChip('💧 Hygrometers (Humidity)', humCount, const Color(0xFF8E44AD)),
                    _buildInstrumentCountChip('🌡 Thermometers', tempCount, const Color(0xFFE65100)),
                    _buildInstrumentCountChip('🌊 River Gauges', riverCount, const Color(0xFF00897B)),
                    if (awsCount > 0)
                      _buildInstrumentCountChip('📡 AWS Automatic Stations', awsCount, const Color(0xFF1565C0)),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 3. Main Dashboard Grid (Responsive Desktop Row vs Mobile Column)
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _buildDashboardCol1(state, activeStations, isMobile)),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildDashboardCol2(state, activeStations, todayDate, isMobile)),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: _buildDashboardCol3(state, activeStations, isMobile)),
                  ],
                ),
              ] else ...[
                Column(
                  children: [
                    _buildDashboardCol1(state, activeStations, isMobile),
                    const SizedBox(height: 14),
                    _buildDashboardCol2(state, activeStations, todayDate, isMobile),
                    const SizedBox(height: 14),
                    _buildDashboardCol3(state, activeStations, isMobile),
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
    return Container(
      height: isMobile ? 340 : 620,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
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
                  markers: _buildMapMarkers(state, activeStations),
                ),
              ],
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      'Live Map (${activeStations.length} Active Pins)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ),
            ),
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
                    _buildMapLegendChip('Rainfall', const Color(0xFF2563EB)),
                    _buildMapLegendChip('Humidity', const Color(0xFF7C3AED)),
                    _buildMapLegendChip('Temperature', const Color(0xFFEA580C)),
                    _buildMapLegendChip('River Level', const Color(0xFF0D9488)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapLegendChip(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildDashboardCol2(KsdmaStateService state, List<KsdmaStation> activeStations, DateTime todayDate, bool isMobile) {
    final colContent = Column(
      children: [
        // Card 1: Statewide Live Highlights
        Card(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Builder(
              builder: (context) {
                if (_appliedParam == 'all') {
                  KsdmaStation? topRainStation, topHumStation, topTempStation, topRiverStation;
                  double topRainVal = -999, topHumVal = -999, topTempVal = -999, topRiverVal = -999;
                  double sumRain = 0, sumHum = 0, sumTemp = 0, sumRiver = 0;
                  int countRain = 0, countHum = 0, countTemp = 0, countRiver = 0;

                  for (var s in activeStations) {
                    final obs = state.getTodayObservation(s.stationId);
                    if (obs == null) continue;

                    if ((s.instrumentType == InstrumentType.rainGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && obs.rainfallMm != null) {
                      sumRain += obs.rainfallMm!;
                      countRain++;
                      if (obs.rainfallMm! > topRainVal) { topRainVal = obs.rainfallMm!; topRainStation = s; }
                    }
                    if ((s.instrumentType == InstrumentType.hygrometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && obs.humidityPercent != null) {
                      final double humForAvg = obs.avgHumidityPercent ?? obs.humidityPercent!;
                      sumHum += humForAvg;
                      countHum++;
                      if (obs.humidityPercent! > topHumVal) { topHumVal = obs.humidityPercent!; topHumStation = s; }
                    }
                    if ((s.instrumentType == InstrumentType.maxMinThermometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && obs.maxTemperatureC != null) {
                      sumTemp += obs.maxTemperatureC!;
                      countTemp++;
                      if (obs.maxTemperatureC! > topTempVal) { topTempVal = obs.maxTemperatureC!; topTempStation = s; }
                    }
                    if (s.instrumentType == InstrumentType.riverGauge && obs.riverWaterLevelM != null) {
                      sumRiver += obs.riverWaterLevelM!;
                      countRiver++;
                      if (obs.riverWaterLevelM! > topRiverVal) { topRiverVal = obs.riverWaterLevelM!; topRiverStation = s; }
                    }
                  }

                  final avgHum = countHum > 0 ? sumHum / countHum : 0.0;
                  final avgTemp = countTemp > 0 ? sumTemp / countTemp : 0.0;
                  final avgRiver = countRiver > 0 ? sumRiver / countRiver : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Statewide Live Highlights',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.touch_app, size: 11, color: Color(0xFF1565C0)),
                                SizedBox(width: 3),
                                Text('Inspect', style: TextStyle(fontSize: 9.5, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final bool isTight = gridConstraints.maxWidth < 280;
                          return GridView.count(
                            crossAxisCount: isTight ? 1 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                            childAspectRatio: isTight ? 2.6 : 1.45,
                            children: [
                              _buildParamHighlightCard(
                                paramTitle: '🌧 Rainfall',
                                topStation: topRainStation,
                                topVal: topRainStation != null ? '${topRainVal.toStringAsFixed(1)} mm' : 'N/A',
                                avgVal: '${sumRain.toStringAsFixed(1)} mm',
                                avgLabel: 'State Total',
                                stationCountText: '$countRain reporting',
                                accentColor: const Color(0xFF3E7CB1),
                                onTap: topRainStation != null ? () => _showStationDetailsDialog(context, topRainStation!, state) : null,
                              ),
                              _buildParamHighlightCard(
                                paramTitle: '💧 Humidity',
                                topStation: topHumStation,
                                topVal: topHumStation != null ? '${topHumVal.toStringAsFixed(1)} %' : 'N/A',
                                avgVal: '${avgHum.toStringAsFixed(1)} %',
                                stationCountText: '$countHum reporting',
                                accentColor: const Color(0xFF8E44AD),
                                onTap: topHumStation != null ? () => _showStationDetailsDialog(context, topHumStation!, state) : null,
                              ),
                              _buildParamHighlightCard(
                                paramTitle: '🌡 Temp (°C)',
                                topStation: topTempStation,
                                topVal: topTempStation != null ? '${topTempVal.toStringAsFixed(1)} °C' : 'N/A',
                                avgVal: '${avgTemp.toStringAsFixed(1)} °C',
                                stationCountText: '$countTemp reporting',
                                accentColor: const Color(0xFFE65100),
                                onTap: topTempStation != null ? () => _showStationDetailsDialog(context, topTempStation!, state) : null,
                              ),
                              _buildParamHighlightCard(
                                paramTitle: '🌊 River Level',
                                topStation: topRiverStation,
                                topVal: topRiverStation != null ? '${topRiverVal.toStringAsFixed(1)} m' : 'N/A',
                                avgVal: '${avgRiver.toStringAsFixed(1)} m',
                                stationCountText: '$countRiver reporting',
                                accentColor: const Color(0xFF00897B),
                                onTap: topRiverStation != null ? () => _showStationDetailsDialog(context, topRiverStation!, state) : null,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                }

                bool isTemp = _appliedParam == 'maxTemp';
                bool isHum = _appliedParam == 'humidity';
                bool isRiver = _appliedParam == 'riverLevel';

                KsdmaStation? topStation;
                KsdmaStation? lowStation;
                double topVal = -999.0;
                double lowVal = 999.0;
                double totalVal = 0.0;
                int reportingCount = 0;
                int capableStationsCount = 0;

                for (var s in activeStations) {
                  bool isCapable = false;
                  if (isTemp) {
                    isCapable = s.instrumentType == InstrumentType.maxMinThermometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
                  } else if (isHum) {
                    isCapable = s.instrumentType == InstrumentType.hygrometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
                  } else if (isRiver) {
                    isCapable = s.instrumentType == InstrumentType.riverGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
                  } else {
                    isCapable = s.instrumentType == InstrumentType.rainGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
                  }

                  if (!isCapable) continue;
                  capableStationsCount++;

                  final obs = state.getTodayObservation(s.stationId);
                  if (obs != null) {
                    double? val;
                    if (isTemp) val = obs.maxTemperatureC;
                    else if (isHum) val = obs.humidityPercent;
                    else if (isRiver) val = obs.riverWaterLevelM;
                    else val = obs.rainfallMm;

                    if (val != null) {
                      totalVal += val;
                      reportingCount++;
                      if (val > topVal) { topVal = val; topStation = s; }
                      if (val < lowVal) { lowVal = val; lowStation = s; }
                    }
                  }
                }

                final avgVal = reportingCount > 0 ? totalVal / reportingCount : 0.0;
                final summaryParamKey = _appliedParam;
                final unit = _getParameterUnit(summaryParamKey);
                final summaryParamTitle = _getParameterTitle(summaryParamKey);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Statewide $summaryParamTitle Highlights',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
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
                              Text('Inspect station', style: TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
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
                            onTap: topStation != null ? () => _showStationDetailsDialog(context, topStation!, state) : null,
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
                            onTap: lowStation != null ? () => _showStationDetailsDialog(context, lowStation!, state) : null,
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
                          _buildStatBox('Kerala Avg $summaryParamTitle', '${avgVal.toStringAsFixed(1)} $unit', const Color(0xFF1565C0)),
                          _buildStatBox('Reporting Stations', '$reportingCount / ${capableStationsCount > 0 ? capableStationsCount : activeStations.length}', const Color(0xFF00897B)),
                          _buildStatBox('Region Filter', _appliedDistrict, const Color(0xFF6D4C41)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Card 2: Latest Observations Table
        Expanded(
          flex: isMobile ? 0 : 1,
          child: Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Latest Observations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                      InkWell(
                        onTap: () => _showAllLatestObservationsModal(context, state, activeStations),
                        child: const Text('View All >', style: TextStyle(fontSize: 10.5, color: Color(0xFF1565C0), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (activeStations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: Text('No active stations found for selected filters.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            ...activeStations.take(5).map((s) {
                              final obs = state.getTodayObservation(s.stationId);
                              String valStr = '0.0 mm';
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
                                } else if (effectiveParam == 'humidity') {
                                  valStr = obs.humidityPercent != null ? '${obs.humidityPercent} %' : '—';
                                } else if (effectiveParam == 'riverLevel') {
                                  valStr = obs.riverWaterLevelM != null ? '${obs.riverWaterLevelM} m' : '—';
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
                                onTap: () => _showStationDetailsDialog(context, s, state),
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF1565C0).withValues(alpha: 0.1) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: _buildObsRow(s.stationId, '${s.gramaPanchayat.isNotEmpty ? "${s.gramaPanchayat}, " : ""}${s.district}', valStr, timeStr, Colors.blue),
                                ),
                              );
                            }),
                            if (activeStations.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.0),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () => _showAllLatestObservationsModal(context, state, activeStations),
                                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                                    child: Text(
                                      'View All ${activeStations.length} Stations →',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF1565C0), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (isMobile) return colContent;
    return SizedBox(height: 620, child: colContent);
  }

  Widget _buildDashboardCol3(KsdmaStateService state, List<KsdmaStation> activeStations, bool isMobile) {
    final cardContent = Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          children: [
            const Text('Change with respect to Previous Day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            const SizedBox(height: 8),

            // Parameter Sub-tabs with Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDeltaTabChip('Rainfall', _activeDeltaTab == 'Rainfall', () => setState(() => _activeDeltaTab = 'Rainfall')),
                  const SizedBox(width: 4),
                  _buildDeltaTabChip('Temp', _activeDeltaTab == 'Temperature', () => setState(() => _activeDeltaTab = 'Temperature')),
                  const SizedBox(width: 4),
                  _buildDeltaTabChip('Humidity', _activeDeltaTab == 'Humidity', () => setState(() => _activeDeltaTab = 'Humidity')),
                  const SizedBox(width: 4),
                  _buildDeltaTabChip('River Level', _activeDeltaTab == 'River Level', () => setState(() => _activeDeltaTab = 'River Level')),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // District Delta Table inside Scrollable Container
            if (activeStations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text('No stations available for selected filters.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                        child: const Row(
                          children: [
                            Expanded(flex: 3, child: Text('District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text('Today', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)))),
                            Expanded(flex: 2, child: Text('Change', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      ...() {
                        final List<Widget> districtWidgets = [];
                        const List<String> keralaDistricts = [
                          'Thiruvananthapuram',
                          'Kollam',
                          'Pathanamthitta',
                          'Alappuzha',
                          'Kottayam',
                          'Idukki',
                          'Ernakulam',
                          'Thrissur',
                          'Palakkad',
                          'Malappuram',
                          'Kozhikode',
                          'Wayanad',
                          'Kannur',
                          'Kasaragod',
                        ];

                        bool matchDistrict(String sDist, String tDist) {
                          final s = sDist.toLowerCase().replaceAll('district', '').trim();
                          final t = tDist.toLowerCase().replaceAll('district', '').trim();
                          return s.contains(t) || t.contains(s);
                        }

                        final allStations = state.stations.isNotEmpty ? state.stations : activeStations;

                        if (_activeDeltaTab == 'Temperature') {
                          for (var dist in keralaDistricts) {
                            final distStations = allStations.where((s) => matchDistrict(s.district, dist)).toList();
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

                            districtWidgets.add(_buildDistrictRowItem(
                              '$dist (Max)',
                              '${avgTodayMax.toStringAsFixed(1)} °C',
                              '${avgYestMax.toStringAsFixed(1)} °C',
                              '${diffMax > 0 ? '+' : ''}${diffMax.toStringAsFixed(1)} °C ${diffMax > 0 ? '↑' : diffMax < 0 ? '↓' : '—'}',
                              diffMax > 0 ? const Color(0xFFE65100) : Colors.grey,
                              distStations,
                              state,
                              '°C',
                            ));

                            districtWidgets.add(_buildDistrictRowItem(
                              '$dist (Min)',
                              '${avgTodayMin.toStringAsFixed(1)} °C',
                              '${avgYestMin.toStringAsFixed(1)} °C',
                              '${diffMin > 0 ? '+' : ''}${diffMin.toStringAsFixed(1)} °C ${diffMin > 0 ? '↑' : diffMin < 0 ? '↓' : '—'}',
                              diffMin > 0 ? const Color(0xFF0288D1) : Colors.grey,
                              distStations,
                              state,
                              '°C',
                            ));
                          }
                          return districtWidgets;
                        }

                        for (var dist in keralaDistricts) {
                          final distStations = allStations.where((s) => matchDistrict(s.district, dist)).toList();
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
                            if (_activeDeltaTab == 'River Level' && s.instrumentType != InstrumentType.riverGauge) {
                              continue;
                            }
                            final tObs = state.getTodayObservation(s.stationId);
                            final yObs = state.getYesterdayObservation(s.stationId);
                            final raw = state.getWsDeviceRaw(s.stationId);

                            double? tVal, yVal;
                            if (_activeDeltaTab == 'Humidity') {
                              tVal = tObs?.avgHumidityPercent ?? tObs?.humidityPercent ?? double.tryParse(raw?['Humidity']?.toString() ?? '');
                              yVal = yObs?.avgHumidityPercent ?? yObs?.humidityPercent;
                            } else if (_activeDeltaTab == 'River Level') {
                              tVal = tObs?.riverWaterLevelM;
                              yVal = yObs?.riverWaterLevelM;
                            } else {
                              final rawVal = raw?['Rainfall_Cumulative'] ??
                                             raw?['RainfallCumulative'] ??
                                             raw?['Rainfall_Cumulative_mm'] ??
                                             raw?['RainfallDaily'] ??
                                             raw?['RainfallDailyComulative'] ??
                                             raw?['Rainfall'] ??
                                             raw?['rainfall'];
                              tVal = tObs?.rainfallMm ?? double.tryParse(rawVal?.toString() ?? '');
                              yVal = yObs?.rainfallMm;
                            }

                            if (tVal != null) { todayTotal += tVal; todayCount++; }
                            if (yVal != null) { yestTotal += yVal; yestCount++; }
                          }

                          final bool isAvg = _activeDeltaTab == 'Humidity' || _activeDeltaTab == 'River Level';
                          double todayVal = (isAvg && todayCount > 0) ? todayTotal / todayCount : todayTotal;
                          double yestVal = (isAvg && yestCount > 0) ? yestTotal / yestCount : yestTotal;



                          final diff = todayVal - yestVal;

                          districtWidgets.add(_buildDistrictRowItem(
                            dist,
                            '${todayVal.toStringAsFixed(1)} $unit',
                            '${yestVal.toStringAsFixed(1)} $unit',
                            '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} $unit ${diff > 0 ? '↑' : diff < 0 ? '↓' : '—'}',
                            diff > 0 ? const Color(0xFFE65100) : diff < 0 ? Colors.blue : Colors.grey,
                            distStations,
                            state,
                            unit,
                          ));
                        }

                        return districtWidgets;
                      }(),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (isMobile) return cardContent;
    return SizedBox(height: 620, child: cardContent);
  }

  Widget _buildDistrictRowItem(
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                          size: 14,
                          color: isExpanded ? const Color(0xFF1565C0) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dist,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isExpanded ? FontWeight.bold : FontWeight.w600,
                              color: isExpanded ? const Color(0xFF1565C0) : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(todayStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(yestStr, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        changeStr,
                        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
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
              const Icon(Icons.sensors, size: 13, color: Color(0xFF1565C0)),
              const SizedBox(width: 4),
              Text(
                'Stations in $dist (${targetStations.length}):',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10.5, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),

          if (targetStations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text('No individual stations mapped to this district.', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
            )
          else
            ...targetStations.map((stn) {
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
              final color = diff > 0 ? const Color(0xFFE65100) : diff < 0 ? Colors.blue : Colors.grey;
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
                        Text('Today: ${realToday.toStringAsFixed(1)} $unit', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        Text('Yest: ${realYest.toStringAsFixed(1)} $unit', style: const TextStyle(fontSize: 9.5, color: Color(0xFF64748B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} $unit',
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

  Widget _buildDeltaTabChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
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
        btnColor: isAdmin ? const Color(0xFF7C3AED) : isOfficer ? const Color(0xFF1565C0) : const Color(0xFF2E7D32),
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

  Widget _buildParamHighlightCard({
    required String paramTitle,
    required KsdmaStation? topStation,
    required String topVal,
    required String avgVal,
    required String stationCountText,
    required Color accentColor,
    String avgLabel = 'State Avg',
    IconData? icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accentColor.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 13, color: accentColor),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    paramTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: accentColor),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  stationCountText,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Highest', style: TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(topVal, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: accentColor)),
                      ),
                      if (topStation != null)
                        Text(
                          '${topStation.stationId} (${topStation.district.length > 6 ? topStation.district.substring(0, 4) + '...' : topStation.district})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 8.5, color: Color(0xFF475569)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(avgLabel, style: const TextStyle(fontSize: 8.5, color: Color(0xFF64748B))),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(avgVal, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                      ),
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

  Widget _buildToolbarDropdown(String label, Widget child, {IconData? icon, bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12, vertical: isMobile ? 4 : 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x05000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 14, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: isMobile ? 9 : 10, color: const Color(0xFF64748B))),
              const SizedBox(height: 2),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstrumentCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return KsdmaStatCard(
      num: value,
      label: title,
      subtext: subtitle,
      icon: icon,
      gaugeFill: color,
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
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 16),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 2),
                  Text(loc, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(width: 8),
              Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
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



  // ignore: unused_element
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

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
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

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
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

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
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

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.spaceAround,
        children: [
          _buildStatBox('Today Rain', tRain, const Color(0xFF1565C0)),
          _buildStatBox('Yesterday Rain', yRain, Colors.black87),
          _buildStatBox('2-Day Total', '${cum2.toStringAsFixed(1)} mm', Colors.black87),
          _buildStatBox('5-Day Total', '${cum5.toStringAsFixed(1)} mm', Colors.black87),
        ],
      );
    }
  }

  /// Builds map markers with slight coordinate jitter/offset for stations sharing identical lat/lng coordinates
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
              onTap: () => _showStationDetailsDialog(context, s, state),
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