// ignore: deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import '../theme/ksdma_theme.dart';

class KsdmaOfficerView extends StatefulWidget {
  const KsdmaOfficerView({super.key});

  @override
  State<KsdmaOfficerView> createState() => _KsdmaOfficerViewState();
}

class _KsdmaOfficerViewState extends State<KsdmaOfficerView> {
  String _selectedTableParam = 'all';
  String _selectedTableDistrict = 'All Districts';
  String _exportParameter = 'All';
  String _exportDistrict = 'All Districts';
  String _exportDateRange = 'All Time Historical';
  String _exportFormat = 'CSV';

  Future<void> _generateAndDownloadDataset(KsdmaStateService state) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
    final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
    final ninetyDaysAgo = todayStart.subtract(const Duration(days: 90));

    DateTime startDate = todayStart;
    if (_exportDateRange == 'Past 7 Days') {
      startDate = sevenDaysAgo;
    } else if (_exportDateRange == 'Past 30 Days') {
      startDate = thirtyDaysAgo;
    } else if (_exportDateRange == 'All Time Historical') {
      startDate = ninetyDaysAgo;
    }

    final observations = List<KsdmaObservation>.from(state.observations.where((o) => !o.isRemoved));

    // If historical range selected, fetch full date range telemetry for AWS sensors directly from AWS KeralaData API
    if (_exportDateRange != 'Today Only') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Fetching $_exportDateRange AWS sensor telemetry & daily averages...'),
          backgroundColor: const Color(0xFF0F766E),
          duration: const Duration(seconds: 2),
        ),
      );

      final awsDeviceIds = state.stations.where((s) => s.stationId.startsWith('WS_')).map((s) => s.stationId).toList();
      if (awsDeviceIds.isNotEmpty) {
        try {
          final rangeObs = await state.apiService.fetchAwsObservationsForDateRange(awsDeviceIds, startDate, now);
          if (rangeObs.isNotEmpty) {
            final fetchedAwsIds = rangeObs.map((o) => o.stationId).toSet();
            observations.removeWhere((o) => fetchedAwsIds.contains(o.stationId) && o.source.contains('AWS'));
            observations.addAll(rangeObs);
          }
        } catch (e) {
          debugPrint('Error fetching range observations: $e');
        }
      }
    }

    final StringBuffer csv = StringBuffer();

    // Dynamic CSV Header based on selected parameter (Source column removed)
    if (_exportParameter == 'Rainfall') {
      csv.writeln('Station ID,District,Grama Panchayat,Instrument Type,Observation Date,Observation Time,Rainfall (mm)');
    } else if (_exportParameter == 'Temperature') {
      csv.writeln('Station ID,District,Grama Panchayat,Instrument Type,Observation Date,Observation Time,Max Temp (C),Min Temp (C)');
    } else if (_exportParameter == 'RiverLevel') {
      csv.writeln('Station ID,District,Grama Panchayat,Instrument Type,Observation Date,Observation Time,River Level (m)');
    } else if (_exportParameter == 'Humidity') {
      csv.writeln('Station ID,District,Grama Panchayat,Instrument Type,Observation Date,Observation Time,Humidity (%)');
    } else {
      csv.writeln('Station ID,District,Grama Panchayat,Instrument Type,Observation Date,Observation Time,Rainfall (mm),Max Temp (C),Min Temp (C),Humidity (%),River Level (m)');
    }

    int count = 0;
    for (var o in observations) {
      final stnList = state.stations.where((s) => s.stationId == o.stationId).toList();
      final stn = stnList.isNotEmpty ? stnList.first : null;

      final district = stn?.district ?? '';
      final panchayat = stn?.gramaPanchayat ?? '';
      final instType = stn?.instrumentType.displayName ?? 'Manual Station';

      // Strictly filter by selected District
      if (_exportDistrict != 'All Districts' && district.toLowerCase().trim() != _exportDistrict.toLowerCase().trim()) {
        continue;
      }

      if (_exportDateRange == 'Today Only' && o.observationDate.isBefore(todayStart)) continue;
      if (_exportDateRange == 'Past 7 Days' && o.observationDate.isBefore(sevenDaysAgo)) continue;
      if (_exportDateRange == 'Past 30 Days' && o.observationDate.isBefore(thirtyDaysAgo)) continue;

      if (_exportParameter == 'Rainfall' && o.rainfallMm == null) continue;
      if (_exportParameter == 'Temperature' && o.maxTemperatureC == null && o.minTemperatureC == null) continue;
      if (_exportParameter == 'Humidity' && o.humidityPercent == null) continue;
      if (_exportParameter == 'RiverLevel' && o.riverWaterLevelM == null) continue;

      final dateStr = "${o.observationDate.year}-${o.observationDate.month.toString().padLeft(2, '0')}-${o.observationDate.day.toString().padLeft(2, '0')}";
      final timeStr = "${o.observationTime.hour.toString().padLeft(2, '0')}:${o.observationTime.minute.toString().padLeft(2, '0')}";

      // Dynamic Row Content (Source column removed completely)
      if (_exportParameter == 'Rainfall') {
        csv.writeln('"${o.stationId}","${district}","${panchayat}","${instType}","${dateStr}","${timeStr}",${o.rainfallMm ?? ""}');
      } else if (_exportParameter == 'Temperature') {
        csv.writeln('"${o.stationId}","${district}","${panchayat}","${instType}","${dateStr}","${timeStr}",${o.maxTemperatureC ?? ""},${o.minTemperatureC ?? ""}');
      } else if (_exportParameter == 'RiverLevel') {
        csv.writeln('"${o.stationId}","${district}","${panchayat}","${instType}","${dateStr}","${timeStr}",${o.riverWaterLevelM ?? ""}');
      } else if (_exportParameter == 'Humidity') {
        csv.writeln('"${o.stationId}","${district}","${panchayat}","${instType}","${dateStr}","${timeStr}",${o.humidityPercent ?? ""}');
      } else {
        csv.writeln('"${o.stationId}","${district}","${panchayat}","${instType}","${dateStr}","${timeStr}",${o.rainfallMm ?? ""},${o.maxTemperatureC ?? ""},${o.minTemperatureC ?? ""},${o.humidityPercent ?? ""},${o.riverWaterLevelM ?? ""}');
      }
      count++;
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final extension = 'csv';
      final fileName = 'KSDMA_Official_Report_${_exportParameter}_${_exportDistrict.replaceAll(" ", "_")}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Downloaded $_exportFormat report with $count observation records for $_exportDistrict'),
        backgroundColor: const Color(0xFF15803D),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final approvedStations = state.approvedStations.isNotEmpty ? state.approvedStations : state.stations;

    final filteredTableStations = approvedStations.where((s) {
      if (_selectedTableDistrict != 'All Districts' && s.district.toLowerCase().trim() != _selectedTableDistrict.toLowerCase().trim()) {
        return false;
      }
      if (_selectedTableParam == 'rainfall') {
        return s.instrumentType == InstrumentType.rainGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
      }
      if (_selectedTableParam == 'humidity') {
        return s.instrumentType == InstrumentType.hygrometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
      }
      if (_selectedTableParam == 'maxTemp') {
        return s.instrumentType == InstrumentType.maxMinThermometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
      }
      if (_selectedTableParam == 'riverLevel') {
        return s.instrumentType == InstrumentType.riverGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation;
      }
      return true;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF0A322C),
              borderRadius: BorderRadius.circular(16),
              boxShadow: KsdmaColors.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E463E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield, color: Color(0xFFF59E0B), size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      KsdmaEyebrow('DISASTER MANAGEMENT AUTHORITY', color: Color(0xFFF59E0B)),
                      SizedBox(height: 4),
                      Text(
                        'Officer Decision Support Dashboard',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Statewide weather observations, parameter filters & official dataset export.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Main 2-Column Responsive Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final bool isWide = constraints.maxWidth >= 900;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildTableCard(state, filteredTableStations)),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildExportPanel(state)),
                      ],
                    )
                  : Column(
                      children: [
                        _buildTableCard(state, filteredTableStations),
                        const SizedBox(height: 16),
                        _buildExportPanel(state),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(KsdmaStateService state, List<KsdmaStation> stations) {
    final districtList = ['All Districts', ...state.stations.map((s) => s.district).where((d) => d.trim().isNotEmpty).toSet()];
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Statewide Station Observations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                KsdmaBadgeTag(text: '${stations.length} Reporting', type: KsdmaTagType.good),
              ],
            ),
            const SizedBox(height: 12),

            // District & Parameter Filter Bar for Table
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('District: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                    const SizedBox(width: 4),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: districtList.contains(_selectedTableDistrict) ? _selectedTableDistrict : 'All Districts',
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.5, fontWeight: FontWeight.bold),
                          icon: const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF475569)),
                          items: districtList.map((d) => DropdownMenuItem(
                            value: d,
                            child: Text(d == 'All Districts' ? 'All 14 Districts (Statewide)' : '$d District'),
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedTableDistrict = val);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const Text('Parameter: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
                      const SizedBox(width: 4),
                      _buildTableFilterChip('All Parameters', 'all'),
                      const SizedBox(width: 6),
                      _buildTableFilterChip('🌧 Rainfall', 'rainfall'),
                      const SizedBox(width: 6),
                      _buildTableFilterChip('💧 Humidity', 'humidity'),
                      const SizedBox(width: 6),
                      _buildTableFilterChip('🌡 Temperature', 'maxTemp'),
                      const SizedBox(width: 6),
                      _buildTableFilterChip('🌊 River Level', 'riverLevel'),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24, color: Color(0xFFE2E8F0)),

            if (stations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No active stations matching selected parameter filter.', style: TextStyle(color: Color(0xFF64748B))),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                  dataRowColor: WidgetStateProperty.all(Colors.white),
                  columns: [
                    const DataColumn(label: Text('Station ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                    const DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                    const DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                    if (_selectedTableParam == 'all') ...[
                      const DataColumn(label: Text('Measured Reading', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      const DataColumn(label: Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      const DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                    ] else ...[
                      const DataColumn(label: Text('Today Reading', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      const DataColumn(label: Text('Yesterday', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                      const DataColumn(label: Text('Change (Δ)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                    ],
                  ],
                  rows: stations.map((s) {
                    final todayObs = state.getTodayObservation(s.stationId) ?? state.getLatestObservation(s.stationId);
                    final yestObs = state.getYesterdayObservation(s.stationId);

                    if (_selectedTableParam == 'all') {
                      String valStr = '0.0 mm';
                      String yestStr = '—';
                      if (todayObs != null) {
                        switch (s.instrumentType) {
                          case InstrumentType.hygrometer:
                            valStr = todayObs.humidityPercent != null ? '${todayObs.humidityPercent}%' : '—';
                            yestStr = yestObs?.humidityPercent != null ? '${yestObs!.humidityPercent}%' : '—';
                            break;
                          case InstrumentType.maxMinThermometer:
                            valStr = todayObs.maxTemperatureC != null ? '${todayObs.maxTemperatureC}°C' : '—';
                            yestStr = yestObs?.maxTemperatureC != null ? '${yestObs!.maxTemperatureC}°C' : '—';
                            break;
                          case InstrumentType.riverGauge:
                            valStr = todayObs.riverWaterLevelM != null ? '${todayObs.riverWaterLevelM} m' : '—';
                            yestStr = yestObs?.riverWaterLevelM != null ? '${yestObs!.riverWaterLevelM} m' : '—';
                            break;
                          case InstrumentType.rainGauge:
                          case InstrumentType.awsAutomaticStation:
                            valStr = todayObs.rainfallMm != null ? '${todayObs.rainfallMm} mm' : '0.0 mm';
                            yestStr = yestObs?.rainfallMm != null ? '${yestObs!.rainfallMm} mm' : '0.0 mm';
                            break;
                        }
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(s.instrumentType.displayName, style: const TextStyle(fontSize: 10, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                            ),
                          ),
                          DataCell(Text(s.district, style: const TextStyle(color: Color(0xFF334155)))),
                          DataCell(Text(valStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF146356)))),
                          DataCell(Text(yestStr, style: const TextStyle(color: Color(0xFF64748B)))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('Active', style: TextStyle(fontSize: 10, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      );
                    }

                    double todayVal = 0.0;
                    double yestVal = 0.0;
                    String unit = 'mm';

                    if (_selectedTableParam == 'humidity') {
                      unit = '%';
                      todayVal = todayObs?.humidityPercent ?? 0.0;
                      yestVal = yestObs?.humidityPercent ?? 0.0;
                    } else if (_selectedTableParam == 'maxTemp') {
                      unit = '°C';
                      todayVal = todayObs?.maxTemperatureC ?? 0.0;
                      yestVal = yestObs?.maxTemperatureC ?? 0.0;
                    } else if (_selectedTableParam == 'riverLevel') {
                      unit = 'm';
                      todayVal = todayObs?.riverWaterLevelM ?? 0.0;
                      yestVal = yestObs?.riverWaterLevelM ?? 0.0;
                    } else {
                      unit = 'mm';
                      todayVal = todayObs?.rainfallMm ?? 0.0;
                      yestVal = yestObs?.rainfallMm ?? 0.0;
                    }

                    double delta = todayVal - yestVal;

                    return DataRow(
                      cells: [
                        DataCell(Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A)))),
                        DataCell(Text(s.instrumentType.displayName, style: const TextStyle(fontSize: 11, color: Color(0xFF334155)))),
                        DataCell(Text(s.district, style: const TextStyle(color: Color(0xFF334155)))),
                        DataCell(Text('$todayVal $unit', style: TextStyle(fontWeight: FontWeight.bold, color: todayVal > 0 ? const Color(0xFF146356) : const Color(0xFF64748B)))),
                        DataCell(Text('$yestVal $unit', style: const TextStyle(color: Color(0xFF64748B)))),
                        DataCell(
                          Text(
                            '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)} $unit',
                            style: TextStyle(color: delta > 0 ? Colors.orange.shade800 : delta < 0 ? Colors.blue : const Color(0xFF64748B), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableFilterChip(String label, String paramKey) {
    final bool isSel = _selectedTableParam == paramKey;
    return InkWell(
      onTap: () => setState(() => _selectedTableParam = paramKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF146356) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSel ? const Color(0xFF146356) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
            color: isSel ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildExportPanel(KsdmaStateService state) {
    final districtList = ['All Districts', ...state.stations.map((s) => s.district).where((d) => d.trim().isNotEmpty).toSet()];

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.download_for_offline, color: Color(0xFF146356)),
                SizedBox(width: 8),
                Text(
                  'Download Official Dataset',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const Divider(height: 24, color: Color(0xFFE2E8F0)),

            const Text('Select Parameter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _exportParameter,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'All', child: Text('All Parameters (Combined)')),
                DropdownMenuItem(value: 'Rainfall', child: Text('Rainfall Observations')),
                DropdownMenuItem(value: 'Temperature', child: Text('Temperature Readings')),
                DropdownMenuItem(value: 'RiverLevel', child: Text('River Water Levels')),
                DropdownMenuItem(value: 'Humidity', child: Text('Humidity Logs')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _exportParameter = val);
              },
            ),

            const SizedBox(height: 14),

            const Text('Select Region:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: districtList.contains(_exportDistrict) ? _exportDistrict : 'All Districts',
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: districtList.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All Districts' ? 'All 14 Districts (Statewide)' : '$d District'))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _exportDistrict = val);
              },
            ),

            const SizedBox(height: 14),

            const Text('Select Time Period:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _exportDateRange,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'All Time Historical', child: Text('All Time Historical Dataset (Full DB)')),
                DropdownMenuItem(value: 'Today Only', child: Text('Today Only (Real-time Latest)')),
                DropdownMenuItem(value: 'Past 7 Days', child: Text('Past 7 Days Observations')),
                DropdownMenuItem(value: 'Past 30 Days', child: Text('Past 30 Days Observations')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _exportDateRange = val);
              },
            ),

            const SizedBox(height: 14),

            const Text('Export Format:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('CSV Format'),
                    selected: _exportFormat == 'CSV',
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF146356),
                    labelStyle: TextStyle(color: _exportFormat == 'CSV' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    onSelected: (sel) => setState(() => _exportFormat = 'CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Excel (.xlsx)'),
                    selected: _exportFormat == 'Excel',
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF146356),
                    labelStyle: TextStyle(color: _exportFormat == 'Excel' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
                    onSelected: (sel) => setState(() => _exportFormat = 'Excel'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () => _generateAndDownloadDataset(state),
                icon: const Icon(Icons.file_download, color: Colors.white),
                label: Text(
                  'GENERATE & DOWNLOAD $_exportFormat',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF146356),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


