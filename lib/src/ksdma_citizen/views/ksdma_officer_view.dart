// ignore: deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import '../theme/ksdma_theme.dart';
import '../../utils/api_keys.dart';

class KsdmaOfficerView extends StatefulWidget {
  const KsdmaOfficerView({super.key});

  @override
  State<KsdmaOfficerView> createState() => _KsdmaOfficerViewState();
}

class _KsdmaOfficerViewState extends State<KsdmaOfficerView> {
  String _selectedTableParam = 'all';
  String _selectedTableDistrict = 'All Districts';
  String _tableSearchQuery = '';
  final TextEditingController _tableSearchTextController = TextEditingController();
  String? _expandedStationId;

  @override
  void dispose() {
    _tableSearchTextController.dispose();
    super.dispose();
  }
  // Export State Variables
  String _exportDataSource = 'Volunteer'; // 'Volunteer' or 'AWS'
  String _exportAwsStationId = 'WS_1';
  String _exportParameter = 'All';
  String _exportDistrict = 'All Districts';
  String _exportDatePreset = 'Past 30 Days';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _exportFormat = 'CSV';

  void _onSelectDatePreset(String preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    setState(() {
      _exportDatePreset = preset;
      if (preset == 'Today') {
        _startDate = todayStart;
        _endDate = now;
      } else if (preset == 'Past 7 Days') {
        _startDate = todayStart.subtract(const Duration(days: 7));
        _endDate = now;
      } else if (preset == 'Past 30 Days') {
        _startDate = todayStart.subtract(const Duration(days: 30));
        _endDate = now;
      } else if (preset == 'All Time') {
        _startDate = DateTime(2020);
        _endDate = now;
      }
    });
  }

  Future<void> _pickExportDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF146356),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _exportDatePreset = 'Custom';
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  Future<void> _generateAndDownloadDataset(KsdmaStateService state) async {
    final bool isAwsMode = _exportDataSource == 'AWS';
    final startDay = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final endDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

    final observations = List<KsdmaObservation>.from(state.observations.where((o) => !o.isRemoved));

    // Trigger AWS S3 Direct Download if in AWS Mode
    if (isAwsMode) {
      final krDateFmt = DateFormat('dd-MM-yyyy');
      final krStartDate = krDateFmt.format(_startDate);
      final krEndDate = krDateFmt.format(_endDate);

      String annamId = _exportAwsStationId;
      if (annamId == 'ALL_AWS') {
        annamId = 'KR';
      } else if (!annamId.startsWith('WS_') && annamId != 'KR') {
        annamId = 'WS_$annamId';
      }

      final String apiUrl =
          'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/keraladata?startdate=$krStartDate&enddate=$krEndDate&annam_id=$annamId&key=${ApiKeys.annamApiKey}&mode=download';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏳ Requesting AWS S3 Download for $annamId ($krStartDate to $krEndDate)...'),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 2),
        ),
      );

      try {
        final response = await http.get(Uri.parse(apiUrl));
        if (response.statusCode == 200) {
          final dynamic data = json.decode(response.body);
          String? downloadUrl;
          if (data is Map<String, dynamic>) {
            downloadUrl = data['download_url'] as String?;
          }

          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            final fileName = '${annamId}_${krStartDate}_to_${krEndDate}_AWS_Telemetry.csv';
            if (kIsWeb) {
              html.AnchorElement(href: downloadUrl)
                ..setAttribute('download', fileName)
                ..click();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📥 Downloaded AWS S3 Telemetry ($fileName)'),
                backgroundColor: const Color(0xFF15803D),
              ),
            );
            return;
          }
        }
      } catch (e) {
        debugPrint('AWS keraladata API S3 Download Error: $e');
      }

      final awsDeviceIds = state.stations
          .where((s) => s.stationId.startsWith('WS_') || s.category == StationCategory.aws)
          .map((s) => s.stationId)
          .toList();
      if (awsDeviceIds.isNotEmpty) {
        try {
          final rangeObs = await state.apiService.fetchAwsObservationsForDateRange(awsDeviceIds, _startDate, _endDate);
          if (rangeObs.isNotEmpty) {
            final fetchedAwsIds = rangeObs.map((o) => o.stationId).toSet();
            observations.removeWhere((o) => fetchedAwsIds.contains(o.stationId) && o.source.contains('AWS'));
            observations.addAll(rangeObs);
          }
        } catch (e) {
          debugPrint('Error fetching AWS range observations: $e');
        }
      }
    }

    final String selectedParam = isAwsMode ? 'all' : _exportParameter.toLowerCase().trim();

    final StringBuffer csv = StringBuffer();

    // Dynamic CSV Header
    if (selectedParam == 'rainfall') {
      csv.writeln('Station ID,Station Name,District,Taluk,Grama Panchayat,Network Type,Observation Date,Observation Time,Rainfall (mm)');
    } else if (selectedParam == 'temperature') {
      csv.writeln('Station ID,Station Name,District,Taluk,Grama Panchayat,Network Type,Observation Date,Observation Time,Max Temp (C),Min Temp (C)');
    } else if (selectedParam == 'riverlevel') {
      csv.writeln('Station ID,Station Name,District,Taluk,Grama Panchayat,Network Type,Observation Date,Observation Time,River Level (m)');
    } else if (selectedParam == 'humidity') {
      csv.writeln('Station ID,Station Name,District,Taluk,Grama Panchayat,Network Type,Observation Date,Observation Time,Humidity (%)');
    } else {
      csv.writeln('Station ID,Station Name,District,Taluk,Grama Panchayat,Network Type,Observation Date,Observation Time,Rainfall (mm),Max Temp (C),Min Temp (C),Humidity (%),River Level (m)');
    }

    int count = 0;
    for (var o in observations) {
      // Date filter
      if (o.observationDate.isBefore(startDay) || o.observationDate.isAfter(endDay)) continue;

      final stnList = state.stations.where((s) => s.stationId == o.stationId).toList();
      final stn = stnList.isNotEmpty ? stnList.first : null;

      final bool isAwsStation = (stn?.category == StationCategory.aws || o.stationId.startsWith('WS_'));

      // STRICT NETWORK TYPE FILTERING:
      if (isAwsMode) {
        // AWS Mode: ONLY include AWS Stations!
        if (!isAwsStation) continue;
        if (_exportAwsStationId != 'ALL_AWS' && o.stationId != _exportAwsStationId) continue;
      } else {
        // Volunteer Mode: ONLY include Volunteer/Manual Stations! EXCLUDE WS_ AWS STATIONS!
        if (isAwsStation) continue;
        final district = stn?.district ?? '';
        if (_exportDistrict != 'All Districts' && district.toLowerCase().trim() != _exportDistrict.toLowerCase().trim()) {
          continue;
        }
      }

      // Parameter filter
      if (selectedParam == 'rainfall' && o.rainfallMm == null) continue;
      if (selectedParam == 'temperature' && o.maxTemperatureC == null && o.minTemperatureC == null) continue;
      if (selectedParam == 'humidity' && o.humidityPercent == null) continue;
      if (selectedParam == 'riverlevel' && o.riverWaterLevelM == null) continue;

      final stnName = stn?.ownerName ?? o.stationId;
      final district = stn?.district ?? '';
      final taluk = stn?.taluk ?? '';
      final panchayat = stn?.gramaPanchayat ?? '';
      final networkTypeLabel = isAwsStation ? 'Automatic Weather Station (AWS)' : 'Manual Volunteer PWS';

      final dateStr = DateFormat('yyyy-MM-dd').format(o.observationDate);
      final timeStr = "${o.observationTime.hour.toString().padLeft(2, '0')}:${o.observationTime.minute.toString().padLeft(2, '0')}";

      if (selectedParam == 'rainfall') {
        csv.writeln('"${o.stationId}","${stnName}","${district}","${taluk}","${panchayat}","${networkTypeLabel}","${dateStr}","${timeStr}",${o.rainfallMm ?? ""}');
      } else if (selectedParam == 'temperature') {
        csv.writeln('"${o.stationId}","${stnName}","${district}","${taluk}","${panchayat}","${networkTypeLabel}","${dateStr}","${timeStr}",${o.maxTemperatureC ?? ""},${o.minTemperatureC ?? ""}');
      } else if (selectedParam == 'riverlevel') {
        csv.writeln('"${o.stationId}","${stnName}","${district}","${taluk}","${panchayat}","${networkTypeLabel}","${dateStr}","${timeStr}",${o.riverWaterLevelM ?? ""}');
      } else if (selectedParam == 'humidity') {
        csv.writeln('"${o.stationId}","${stnName}","${district}","${taluk}","${panchayat}","${networkTypeLabel}","${dateStr}","${timeStr}",${o.humidityPercent ?? ""}');
      } else {
        csv.writeln('"${o.stationId}","${stnName}","${district}","${taluk}","${panchayat}","${networkTypeLabel}","${dateStr}","${timeStr}",${o.rainfallMm ?? ""},${o.maxTemperatureC ?? ""},${o.minTemperatureC ?? ""},${o.humidityPercent ?? ""},${o.riverWaterLevelM ?? ""}');
      }
      count++;
    }

    if (kIsWeb) {
      final bytes = utf8.encode(csv.toString());
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final modeTag = isAwsMode ? 'AWS_Telemetry' : 'Volunteer_Readings';
      final fileName = 'KSDMA_${modeTag}_${DateFormat('yyyyMMdd').format(_startDate)}_to_${DateFormat('yyyyMMdd').format(_endDate)}.csv';
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📥 Downloaded CSV with $count observation records!'),
        backgroundColor: isAwsMode ? const Color(0xFF2563EB) : const Color(0xFF146356),
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

    final filteredStations = _tableSearchQuery.isEmpty
        ? stations
        : stations.where((s) {
            final q = _tableSearchQuery.toLowerCase();
            return s.stationId.toLowerCase().contains(q) ||
                s.ownerName.toLowerCase().contains(q) ||
                s.district.toLowerCase().contains(q) ||
                s.taluk.toLowerCase().contains(q) ||
                s.gramaPanchayat.toLowerCase().contains(q) ||
                s.instrumentType.displayName.toLowerCase().contains(q);
          }).toList();

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
                    final awsCount = filteredStations.where((s) => s.category == StationCategory.aws || s.instrumentType == InstrumentType.awsAutomaticStation).length;
                    final manualCount = filteredStations.length - awsCount;
                    final tagText = manualCount > 0 ? '${filteredStations.length} Reporting ($awsCount AWS · $manualCount Manual)' : '$awsCount AWS Reporting';
                    return KsdmaBadgeTag(text: tagText, type: KsdmaTagType.good);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // District, Search & Parameter Filter Bar for Table
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Device Search Box for Officer Table
                Container(
                  height: 32,
                  width: 240,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          controller: _tableSearchTextController,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            hintText: '🔍 Search station ID, name, location...',
                            hintStyle: TextStyle(fontSize: 10.5, color: Colors.grey, fontWeight: FontWeight.normal),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (val) => setState(() => _tableSearchQuery = val.trim()),
                        ),
                      ),
                      if (_tableSearchQuery.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _tableSearchTextController.clear();
                            setState(() => _tableSearchQuery = '');
                          },
                          child: const Icon(Icons.clear, size: 14, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
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

            if (filteredStations.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No active stations matching selected filters/search.', style: TextStyle(color: Color(0xFF64748B))),
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
                itemCount: filteredStations.length,
                itemBuilder: (context, i) {
                  return _buildExpandableStationRow(i + 1, filteredStations[i], state);
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
    final awsStations = state.stations.where((s) => s.category == StationCategory.aws || s.stationId.startsWith('WS_')).toList();

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

            const Text('Select Data Network Source:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.people_alt, size: 14, color: _exportDataSource == 'Volunteer' ? Colors.white : const Color(0xFF146356)),
                    label: const Text('Volunteer Readings (DB)'),
                    selected: _exportDataSource == 'Volunteer',
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF146356),
                    labelStyle: TextStyle(color: _exportDataSource == 'Volunteer' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5),
                    onSelected: (sel) => setState(() => _exportDataSource = 'Volunteer'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    avatar: Icon(Icons.sensors, size: 14, color: _exportDataSource == 'AWS' ? Colors.white : const Color(0xFF2563EB)),
                    label: const Text('AWS Cloud Telemetry (S3)'),
                    selected: _exportDataSource == 'AWS',
                    backgroundColor: const Color(0xFFF1F5F9),
                    selectedColor: const Color(0xFF2563EB),
                    labelStyle: TextStyle(color: _exportDataSource == 'AWS' ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 11.5),
                    onSelected: (sel) => setState(() => _exportDataSource = 'AWS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_exportDataSource == 'AWS') ...[
              const Text('Select Target AWS Station:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: awsStations.any((s) => s.stationId == _exportAwsStationId)
                    ? _exportAwsStationId
                    : (awsStations.isNotEmpty ? awsStations.first.stationId : null),
                dropdownColor: Colors.white,
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF2563EB))),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: awsStations.map((stn) => DropdownMenuItem(
                  value: stn.stationId,
                  child: Text('${stn.stationId} - ${stn.district} (${stn.gramaPanchayat.isNotEmpty ? stn.gramaPanchayat : "AWS Station"})'),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _exportAwsStationId = val);
                },
              ),
              const SizedBox(height: 14),
            ] else ...[
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
                items: districtList.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All Districts' ? 'All 14 Districts (Statewide Volunteer PWS)' : '$d District'))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _exportDistrict = val);
                },
              ),
              const SizedBox(height: 14),

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
                  DropdownMenuItem(value: 'Rainfall', child: Text('Rainfall Observations (mm)')),
                  DropdownMenuItem(value: 'Temperature', child: Text('Temperature Readings (°C)')),
                  DropdownMenuItem(value: 'RiverLevel', child: Text('River Water Levels (m)')),
                  DropdownMenuItem(value: 'Humidity', child: Text('Humidity Logs (%)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _exportParameter = val);
                },
              ),
              const SizedBox(height: 14),
            ],

            const Text('Select Time Period & Date Range:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip('Today'),
                  const SizedBox(width: 6),
                  _buildPresetChip('Past 7 Days'),
                  const SizedBox(width: 6),
                  _buildPresetChip('Past 30 Days'),
                  const SizedBox(width: 6),
                  _buildPresetChip('All Time'),
                ],
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickExportDate(isStart: true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 15, color: Color(0xFF146356)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('START DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                Text(DateFormat('dd MMM yyyy').format(_startDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(Icons.arrow_forward, size: 14, color: Color(0xFF94A3B8)),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickExportDate(isStart: false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event, size: 15, color: Color(0xFF146356)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('END DATE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                Text(DateFormat('dd MMM yyyy').format(_endDate), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildPresetChip(String label) {
    final isSelected = _exportDatePreset == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: const Color(0xFF146356),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF0F172A),
        fontWeight: FontWeight.bold,
        fontSize: 11,
      ),
      visualDensity: VisualDensity.compact,
      onSelected: (_) => _onSelectDatePreset(label),
    );
  }
}


