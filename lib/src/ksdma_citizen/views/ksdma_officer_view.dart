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
  String? _expandedStationId;
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
      final todayObs = state.getTodayObservation(s.stationId);
      if (todayObs == null) {
        return false; // Exclude stations that have not reported today
      }
      if (_selectedTableParam == 'rainfall') {
        return (s.instrumentType == InstrumentType.rainGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && todayObs.rainfallMm != null;
      }
      if (_selectedTableParam == 'humidity') {
        return (s.instrumentType == InstrumentType.hygrometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && todayObs.humidityPercent != null;
      }
      if (_selectedTableParam == 'maxTemp') {
        return (s.instrumentType == InstrumentType.maxMinThermometer || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && (todayObs.maxTemperatureC != null || todayObs.minTemperatureC != null);
      }
      if (_selectedTableParam == 'riverLevel') {
        return (s.instrumentType == InstrumentType.riverGauge || s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation) && todayObs.riverWaterLevelM != null;
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
                Builder(
                  builder: (context) {
                    final awsCount = stations.where((s) => s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation).length;
                    final manualCount = stations.length - awsCount;
                    final tagText = manualCount > 0 ? '${stations.length} Reporting ($awsCount AWS · $manualCount Manual)' : '$awsCount AWS Reporting';
                    return KsdmaBadgeTag(text: tagText, type: KsdmaTagType.good);
                  },
                ),
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
            else ...[
              // Legend Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    SizedBox(width: 36, child: Text('Sl.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    Expanded(flex: 2, child: Text('Station ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    Expanded(flex: 3, child: Text('Instrument Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    Expanded(flex: 2, child: Text('District', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    SizedBox(width: 70, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)))),
                    SizedBox(width: 100, child: Align(alignment: Alignment.centerRight, child: Text('Details & Dropdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stations.length,
                itemBuilder: (context, i) {
                  return _buildExpandableStationRow(i + 1, stations[i], state);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExpandableStationRow(int index, KsdmaStation s, KsdmaStateService state) {
    final bool isExpanded = _expandedStationId == s.stationId;
    final todayObs = state.getTodayObservation(s.stationId);
    final yestObs = state.getYesterdayObservation(s.stationId);
    final wsRaw = state.getWsDeviceRaw(s.stationId);

    String fmtNum(double? v) => v != null ? (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1)) : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isExpanded ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? const Color(0xFF146356) : const Color(0xFFE2E8F0), width: isExpanded ? 1.5 : 1),
        boxShadow: [
          if (isExpanded)
            BoxShadow(color: const Color(0xFF146356).withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedStationId = isExpanded ? null : s.stationId;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('#$index', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(s.instrumentType.displayName, style: const TextStyle(fontSize: 10.5, color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(s.district, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                  ),
                  SizedBox(
                    width: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Active', textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          isExpanded ? 'Hide' : 'Readings',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF146356)),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: const Color(0xFF146356),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // 📍 1. Full Metadata Card
                      _buildDetailBox(
                        title: '📍 Station Metadata',
                        color: const Color(0xFF0F172A),
                        icon: Icons.location_on_outlined,
                        items: [
                          'Station ID: ${s.stationId}',
                          'Type: ${s.instrumentType.displayName}',
                          'District: ${s.district}',
                          if (s.taluk.isNotEmpty) 'Taluk: ${s.taluk}',
                          if (s.gramaPanchayat.isNotEmpty) 'Grama Panchayat: ${s.gramaPanchayat}',
                          'Coordinates: ${s.latitude.toStringAsFixed(4)}° N, ${s.longitude.toStringAsFixed(4)}° E',
                          'Category: ${s.category.name.toUpperCase()}',
                          if (s.ownerName.isNotEmpty) 'Owner / Operator: ${s.ownerName}',
                          'Approval Status: ${s.approvalStatus.name.toUpperCase()}',
                        ],
                      ),

                      // 📊 2. Measured Reading (Today)
                      _buildDetailBox(
                        title: '📊 Today\'s Measured Reading',
                        color: const Color(0xFF146356),
                        icon: Icons.analytics_outlined,
                        items: [
                          '🌧 Rainfall: ${wsRaw?['Rainfall'] ?? (todayObs?.rainfallMm != null ? fmtNum(todayObs!.rainfallMm) : '0')} mm',
                          '🌡 Max Temp: ${todayObs?.maxTemperatureC != null ? "${fmtNum(todayObs!.maxTemperatureC)} °C" : (wsRaw?['Temperature'] != null ? "${wsRaw!['Temperature']} °C" : "N/A")}',
                          if (todayObs?.minTemperatureC != null) '🌡 Min Temp: ${fmtNum(todayObs!.minTemperatureC)} °C',
                          '💧 Humidity: ${wsRaw?['Humidity'] ?? (todayObs?.humidityPercent != null ? fmtNum(todayObs!.humidityPercent) : 'N/A')} %',
                          if (todayObs?.riverWaterLevelM != null) '🌊 River Level: ${fmtNum(todayObs!.riverWaterLevelM)} m',
                          if (wsRaw?['WindSpeed'] != null) '💨 Wind Speed: ${wsRaw!['WindSpeed']} m/s',
                          if (wsRaw?['AtmPressure'] != null) '🧭 Pressure: ${wsRaw!['AtmPressure']} hPa',
                          'Timestamp: ${wsRaw?['TimeStamp'] ?? (todayObs != null ? "${todayObs.observationDate.toIso8601String().split('T')[0]} ${todayObs.observationTime.hour.toString().padLeft(2, '0')}:${todayObs.observationTime.minute.toString().padLeft(2, '0')}" : "Live")}',
                        ],
                      ),

                      // 📅 3. Yesterday's Reading
                      _buildDetailBox(
                        title: '📅 Yesterday\'s Reading',
                        color: const Color(0xFF64748B),
                        icon: Icons.history,
                        items: [
                          '🌧 Rainfall: ${yestObs?.rainfallMm != null ? "${fmtNum(yestObs!.rainfallMm)} mm" : "0.0 mm"}',
                          '🌡 Max Temp: ${yestObs?.maxTemperatureC != null ? "${fmtNum(yestObs!.maxTemperatureC)} °C" : "N/A"}',
                          '🌡 Min Temp: ${yestObs?.minTemperatureC != null ? "${fmtNum(yestObs!.minTemperatureC)} °C" : "N/A"}',
                          '💧 Humidity: ${yestObs?.humidityPercent != null ? "${fmtNum(yestObs!.humidityPercent)} %" : "N/A"}',
                          if (yestObs?.riverWaterLevelM != null) '🌊 River Level: ${fmtNum(yestObs!.riverWaterLevelM)} m',
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailBox({required String title, required Color color, required IconData icon, required List<String> items}) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color))),
            ],
          ),
          const Divider(height: 12, color: Color(0xFFE2E8F0)),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(item, style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
          )),
        ],
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


