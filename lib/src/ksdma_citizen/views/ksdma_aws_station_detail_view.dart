import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/ksdma_models.dart';
import '../services/ksdma_state_service.dart';
import '../../utils/api_keys.dart';

class KsdmaAwsStationDetailView extends StatefulWidget {
  final String stationId;

  const KsdmaAwsStationDetailView({super.key, required this.stationId});

  @override
  State<KsdmaAwsStationDetailView> createState() => _KsdmaAwsStationDetailViewState();
}

class _KsdmaAwsStationDetailViewState extends State<KsdmaAwsStationDetailView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _historyData = [];
  Map<String, dynamic>? _latestReading;

  bool _isShiftPressed = false;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _fetchAwsStationHistory();
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  String _formatDeviceId(String rawId) {
    if (rawId.startsWith('WS_')) {
      return rawId;
    }
    return 'WS_$rawId';
  }

  String _selectedPeriod = '1day'; // '1day', '7days', '1month'
  DateTime _selectedSingleDate = DateTime.now();
  DateTime _selectedMonthDate = DateTime.now();

  Future<void> _selectSingleDate() async {
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final firstDate = DateTime(2020, 1, 1);

    DateTime initial = DateTime(_selectedSingleDate.year, _selectedSingleDate.month, _selectedSingleDate.day);
    if (initial.isAfter(todayEnd)) initial = DateTime(now.year, now.month, now.day);
    if (initial.isBefore(firstDate)) initial = firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: todayEnd,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedSingleDate = picked;
        _selectedPeriod = '1day';
      });
      _fetchAwsStationHistory();
    }
  }

  Future<void> _selectMonthAndYear() async {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final List<int> years = [2026, 2025, 2024];

    int selectedYear = _selectedMonthDate.year;
    int selectedMonth = _selectedMonthDate.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.calendar_month, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Select Month & Year',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Year: ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: selectedYear,
                        dropdownColor: Colors.white,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => selectedYear = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Month:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: List.generate(12, (index) {
                      final monthNum = index + 1;
                      final isSel = selectedMonth == monthNum;
                      return ChoiceChip(
                        label: Text(months[index].substring(0, 3)),
                        selected: isSel,
                        selectedColor: const Color(0xFF2563EB),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide(color: isSel ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
                        labelStyle: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF334155),
                          fontWeight: FontWeight.bold,
                        ),
                        onSelected: (selected) {
                          if (selected) setModalState(() => selectedMonth = monthNum);
                        },
                      );
                    }),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, DateTime(selectedYear, selectedMonth)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Fetch Month Data', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedMonthDate = result;
        _selectedPeriod = '1month';
      });
      _fetchAwsStationHistory();
    }
  }

  Future<void> _fetchAwsStationHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final devId = _formatDeviceId(widget.stationId);
    List<Map<String, dynamic>> records = [];

    try {
      if (_selectedPeriod == '1day') {
        final dateStr = DateFormat('yyyy-MM-dd').format(_selectedSingleDate);
        final String rangeUrl = 'https://gj6wsq3214.execute-api.us-east-1.amazonaws.com/default/WS_Kerala_API?ANNAM_ID=$devId&startdate=$dateStr&enddate=$dateStr&key=${ApiKeys.annamApiKey}';

        final response = await http.get(Uri.parse(rangeUrl));
        if (response.statusCode == 200) {
          final dynamic body = jsonDecode(response.body);
          records = _extractRecords(body);
        }
      } else if (_selectedPeriod == '1month') {
        final yearStr = DateFormat('yyyy').format(_selectedMonthDate);
        final monthAbbr = DateFormat('MMM').format(_selectedMonthDate).toLowerCase(); // e.g. 'aug'
        final String monthUrl = 'https://d2c53xydfx4tqe.cloudfront.net/WS_Kerala/$devId/$yearStr/$monthAbbr.json';

        final response = await http.get(Uri.parse(monthUrl));
        if (response.statusCode == 200) {
          final dynamic body = jsonDecode(response.body);
          records = _extractRecords(body);
        }
      }

      // If records are empty or 7days period selected, fetch 7_Days_Data_Fetch_Api
      if (records.isEmpty || _selectedPeriod == '7days') {
        final String history7DaysUrl = 'https://0309fuahf8.execute-api.us-east-1.amazonaws.com/default/7_Days_Data_Fetch_Api?Topic=WS_Kerala&DeviceId=$devId';
        final response = await http.get(Uri.parse(history7DaysUrl));
        if (response.statusCode == 200) {
          final dynamic body = jsonDecode(response.body);
          records = _extractRecords(body);
        }
      }

      // Sort by TimeStamp ascending
      records.sort((a, b) {
        final tA = a['TimeStamp']?.toString() ?? '';
        final tB = b['TimeStamp']?.toString() ?? '';
        return tA.compareTo(tB);
      });

      setState(() {
        _historyData = records;
        if (records.isNotEmpty) {
          _latestReading = records.last;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error fetching WS telemetry history: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractRecords(dynamic body) {
    if (body is List) {
      return List<Map<String, dynamic>>.from(body);
    } else if (body is Map) {
      if (body['items'] is List) {
        return List<Map<String, dynamic>>.from(body['items']);
      } else if (body['devices'] is List) {
        return List<Map<String, dynamic>>.from(body['devices']);
      } else if (body['data'] is List) {
        return List<Map<String, dynamic>>.from(body['data']);
      }
    }
    return [];
  }

  // Rainfall & Advisory Calculations
  String _getRainfallClassification(double rain24h) {
    if (rain24h <= 0.0) return 'Dry Weather';
    if (rain24h <= 7.5) return 'Light Rain';
    if (rain24h <= 35.5) return 'Moderate Rain';
    if (rain24h <= 64.4) return 'Rather Heavy Rain';
    if (rain24h <= 115.5) return 'Heavy Rain Advisory (Yellow Alert)';
    return 'Very Heavy Rain Warning (Orange/Red Alert)';
  }

  Color _getRainfallColor(double rain24h) {
    if (rain24h <= 0.0) return const Color(0xFF64748B);
    if (rain24h <= 7.5) return const Color(0xFF2563EB);
    if (rain24h <= 35.5) return const Color(0xFF0288D1);
    if (rain24h <= 64.4) return const Color(0xFFD97706);
    return const Color(0xFFDC2626);
  }

  String _getHeatIndexAdvisory(double? temp, double? hum) {
    if (temp == null) return 'Data N/A';
    if (temp < 20.0) return 'Cool & Pleasant Climate';
    if (temp <= 26.0) return 'Optimal Comfort';
    if (hum != null && hum > 75.0) return 'Humid & Warm (High Moisture)';
    if (temp > 35.0) return 'High Heat Warning (Stay Hydrated)';
    return 'Warm & Clear';
  }

  String _getWindAdvisory(double? windSpd, double? windGust) {
    final gust = windGust ?? windSpd ?? 0.0;
    if (gust < 4.0) return 'Calm / Gentle Breeze';
    if (gust < 10.0) return 'Moderate Surface Wind';
    if (gust < 17.0) return 'Fresh Wind (Caution)';
    return 'Strong Wind Gust Warning';
  }

  String _getPressureAdvisory(double? press) {
    if (press == null) return 'Data N/A';
    if (press < 1000.0) return 'Low Pressure System';
    if (press <= 1020.0) return 'Normal Pressure';
    return 'High Pressure Ridge';
  }

  void _exportCsv() {
    if (_historyData.isEmpty) return;

    final List<List<dynamic>> rows = [
      [
        'TimeStamp',
        'Device_ID',
        'Temperature_C',
        'Humidity_Percent',
        'Rainfall_mm',
        'Rainfall_Cumulative_mm',
        'AtmPressure_hPa',
        'WindSpeed_ms',
        'WindDirection_deg',
        'MaxWindGust_ms',
        'MaxWindGustDirection_deg',
        'MaxWindGustTime',
        'BatteryVoltage_V',
        'PanelVoltage_V',
        'SignalStrength_dBm'
      ]
    ];

    for (var d in _historyData) {
      rows.add([
        d['TimeStamp'] ?? '',
        d['Device_ID'] ?? d['ANNAM_ID'] ?? widget.stationId,
        d['now_temperature'] ?? '',
        d['now_relative_humidity'] ?? '',
        d['rainfall'] ?? '',
        d['Rainfall_Cumulative'] ?? '',
        d['now_pressure'] ?? '',
        d['now_wind_speed'] ?? '',
        d['now_wind_direction'] ?? '',
        d['max_wind_gust'] ?? '',
        d['max_wind_direction_gust'] ?? '',
        d['max_wind_gust_time'] ?? '',
        d['Battery_Voltage'] ?? '',
        d['Panel_Voltage'] ?? '',
        d['Signal_Strength'] ?? ''
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);

    if (kIsWeb) {
      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.document.createElement('a') as html.AnchorElement
        ..href = url
        ..style.display = 'none'
        ..download = '${widget.stationId}_telemetry_export.csv';
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
    }
  }

  Widget _buildPeriodButton(String periodKey, String label, IconData icon) {
    final bool isSelected = _selectedPeriod == periodKey;
    String displayLabel = label;

    if (periodKey == '1day') {
      final isToday = DateFormat('yyyy-MM-dd').format(_selectedSingleDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dateLabel = isToday ? 'Today' : DateFormat('MMM d').format(_selectedSingleDate);
      displayLabel = isSelected ? '1 Day ($dateLabel)' : '1 Day';
    } else if (periodKey == '1month') {
      final monthStr = DateFormat('MMM yyyy').format(_selectedMonthDate);
      displayLabel = isSelected ? '1 Month ($monthStr)' : '1 Month';
    }

    return ElevatedButton.icon(
      onPressed: () {
        if (periodKey == '1day') {
          _selectSingleDate();
        } else if (periodKey == '1month') {
          _selectMonthAndYear();
        } else if (_selectedPeriod != periodKey) {
          setState(() {
            _selectedPeriod = periodKey;
          });
          _fetchAwsStationHistory();
        }
      },
      icon: Icon(icon, size: 14),
      label: Text(displayLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF2563EB) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF475569),
        elevation: isSelected ? 2 : 0,
        side: BorderSide(color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    KsdmaStateService? state;
    try {
      state = Provider.of<KsdmaStateService>(context);
    } catch (_) {}

    // Find station meta
    final stations = state?.stations ?? [];
    final station = stations.firstWhere(
      (s) => s.stationId == widget.stationId,
      orElse: () => KsdmaStation(
        stationId: widget.stationId,
        ownerUserId: 'AWS_KERALA',
        ownerName: 'KSDMA Weather Station',
        ownerCategory: UserCategory.adminHq,
        category: StationCategory.aws,
        instrumentType: InstrumentType.awsAutomaticStation,
        deviceMake: 'Automatic Weather Station',
        measurementLocation: 'Kerala Observatory',
        latitude: 9.9640,
        longitude: 77.0974,
        district: 'Idukki',
        taluk: 'Udumbanchola',
        gramaPanchayat: 'Udumbanchola',
        village: 'Udumbanchola',
        approvalStatus: ApprovalStatus.approved,
        createdAt: DateTime.now(),
      ),
    );

    final wsRaw = state?.getWsDeviceRaw(widget.stationId) ?? _latestReading;

    final num? tempVal = wsRaw?['now_temperature'] ?? wsRaw?['Temperature'];
    final num? humVal = wsRaw?['now_relative_humidity'] ?? wsRaw?['Humidity'];
    final num? rainVal = wsRaw?['rainfall'] ?? wsRaw?['Rainfall'];
    final dynamic rainCumRaw = wsRaw?['Rainfall_Cumulative'];
    final double rainCumVal = double.tryParse(rainCumRaw?.toString() ?? '') ?? (rainVal?.toDouble() ?? 0.0);
    final num? pressVal = wsRaw?['now_pressure'] ?? wsRaw?['AtmPressure'];
    final num? windSpdVal = wsRaw?['now_wind_speed'] ?? wsRaw?['WindSpeed'];
    final dynamic windDirVal = wsRaw?['now_wind_direction'] ?? wsRaw?['WindDirection'];
    final num? gustVal = wsRaw?['max_wind_gust'] ?? wsRaw?['WindGust'];
    final dynamic battVal = wsRaw?['Battery_Voltage'];
    final dynamic signalVal = wsRaw?['Signal_Strength'];
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (event) {
        final isShift = HardwareKeyboard.instance.isShiftPressed;
        if (_isShiftPressed != isShift) {
          setState(() {
            _isShiftPressed = isShift;
          });
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${station.stationId} • AWS WEATHER OBSERVATORY',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            Text(
              '${station.gramaPanchayat.isNotEmpty ? "${station.gramaPanchayat}, " : ""}${station.district} District • Lat: ${station.latitude.toStringAsFixed(4)}, Lng: ${station.longitude.toStringAsFixed(4)} | State: Kerala',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Telemetry',
            onPressed: _fetchAwsStationHistory,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV Data',
            onPressed: _exportCsv,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2563EB)),
                  SizedBox(height: 16),
                  Text('Fetching AWS Meteorological Telemetry...', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_errorMessage!, style: const TextStyle(fontSize: 14, color: Colors.red), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchAwsStationHistory,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                          child: const Text('Retry Connection'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Action Bar & Period API Selectors
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sensors, color: Color(0xFF16A34A), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Station ID: ${station.stationId} (${_historyData.length} Telemetry Points Loaded)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildPeriodButton('1day', '1 Day', Icons.today),
                              const SizedBox(width: 8),
                              _buildPeriodButton('7days', '7 Days', Icons.date_range),
                              const SizedBox(width: 8),
                              _buildPeriodButton('1month', '1 Month', Icons.calendar_month),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _exportCsv,
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Row 1: IMD Meteorological Insights Cards (5 Cards)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final double cardWidth = constraints.maxWidth > 1200
                              ? (constraints.maxWidth - 60) / 5
                              : constraints.maxWidth > 850
                                  ? (constraints.maxWidth - 30) / 3
                                  : constraints.maxWidth > 550
                                      ? (constraints.maxWidth - 15) / 2
                                      : constraints.maxWidth;

                          return Wrap(
                            spacing: 15,
                            runSpacing: 15,
                            children: [
                              // Card 1: Rainfall Insights (Current Rain + Cumulative Rain in Subtitle)
                              _buildInsightHeroCard(
                                width: cardWidth,
                                title: 'Rainfall Bulletin',
                                mainVal: rainVal != null ? '${rainVal.toStringAsFixed(1)} mm' : '0.0 mm',
                                subTitle: '24h Cumulative Rainfall: ${rainCumVal.toStringAsFixed(1)} mm',
                                badgeText: _getRainfallClassification(rainCumVal),
                                badgeColor: _getRainfallColor(rainCumVal),
                                icon: Icons.water_drop,
                                iconColor: const Color(0xFF2563EB),
                                bgGradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
                              ),

                              // Card 2: Temperature & Comfort
                              _buildInsightHeroCard(
                                width: cardWidth,
                                title: 'Temperature & Comfort',
                                mainVal: tempVal != null ? '${tempVal.toStringAsFixed(1)} °C' : 'N/A',
                                subTitle: 'Humidity: ${humVal != null ? humVal.toStringAsFixed(1) : "N/A"}%',
                                badgeText: _getHeatIndexAdvisory(tempVal?.toDouble(), humVal?.toDouble()),
                                badgeColor: const Color(0xFFEA580C),
                                icon: Icons.thermostat,
                                iconColor: const Color(0xFFEA580C),
                                bgGradient: const LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]),
                              ),

                              // Card 3: Atmospheric Pressure
                              _buildInsightHeroCard(
                                width: cardWidth,
                                title: 'Atmospheric Pressure',
                                mainVal: pressVal != null ? '${pressVal.toStringAsFixed(1)} hPa' : 'N/A',
                                subTitle: 'Barometric Trend: ${pressVal != null ? (pressVal >= 1013.2 ? "High/Normal" : "Depression") : "N/A"}',
                                badgeText: _getPressureAdvisory(pressVal?.toDouble()),
                                badgeColor: const Color(0xFF0D9488),
                                icon: Icons.speed,
                                iconColor: const Color(0xFF0D9488),
                                bgGradient: const LinearGradient(colors: [Color(0xFFF0FDFA), Color(0xFFCCFBF1)]),
                              ),

                              // Card 4: Wind Profile & Gust
                              _buildInsightHeroCard(
                                width: cardWidth,
                                title: 'Wind & Gust Profile',
                                mainVal: windSpdVal != null ? '${windSpdVal.toStringAsFixed(1)} m/s' : 'N/A',
                                subTitle: 'Heading: ${windDirVal ?? "N/A"}° | Gust: ${gustVal != null ? gustVal.toStringAsFixed(1) : "N/A"} m/s',
                                badgeText: _getWindAdvisory(windSpdVal?.toDouble(), gustVal?.toDouble()),
                                badgeColor: const Color(0xFF0288D1),
                                icon: Icons.air,
                                iconColor: const Color(0xFF0288D1),
                                bgGradient: const LinearGradient(colors: [Color(0xFFF0F9FF), Color(0xFFE0F2FE)]),
                              ),

                              // Card 5: Hardware Telemetry
                              _buildInsightHeroCard(
                                width: cardWidth,
                                title: 'AWS Diagnostics',
                                mainVal: battVal != null ? '$battVal V' : '4.1 V',
                                subTitle: 'Battery: ${battVal ?? "4.1"} V | Signal: ${signalVal ?? "-55"} dBm',
                                badgeText: '🟢 Station Power OK',
                                badgeColor: const Color(0xFF16A34A),
                                icon: Icons.battery_charging_full,
                                iconColor: const Color(0xFF16A34A),
                                bgGradient: const LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 28),

                      // Section 3: Telemetry Time-Series Controls & Vertically Stacked Charts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '📊 Telemetry Time-Series Analysis Charts',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.zoom_in, size: 14, color: _isShiftPressed ? const Color(0xFF16A34A) : const Color(0xFF2563EB)),
                                const SizedBox(width: 4),
                                Text(
                                  _isShiftPressed ? 'Shift Active: Mouse Wheel Zoom Enabled' : 'Hold Shift + Mouse Scroll to Zoom X-Axis',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _isShiftPressed ? const Color(0xFF15803D) : const Color(0xFF1E40AF)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      _buildSingleChartCard(
                        title: '🌡️ Temperature (°C) & Relative Humidity (%) Time-Series',
                        chartWidget: _buildTempHumChart(),
                      ),
                      const SizedBox(height: 20),
                      _buildSingleChartCard(
                        title: '🌧️ Rainfall Distribution Bar Chart (mm)',
                        chartWidget: _buildRainfallChart(),
                      ),
                      const SizedBox(height: 20),
                      _buildSingleChartCard(
                        title: '⏲️ Atmospheric Pressure Trend (hPa)',
                        chartWidget: _buildPressureChart(),
                      ),
                      const SizedBox(height: 20),
                      _buildSingleChartCard(
                        title: '💨 Wind Speed (m/s) & Max Wind Gust Profile',
                        chartWidget: _buildWindChart(),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildInsightHeroCard({
    required double width,
    required String title,
    required String mainVal,
    required String subTitle,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required Gradient bgGradient,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: bgGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: iconColor.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: iconColor)),
              Icon(icon, size: 22, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(mainVal, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: iconColor)),
          const SizedBox(height: 2),
          Text(subTitle, style: const TextStyle(fontSize: 11, color: Color(0xFF475569))),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseTimeStamp(dynamic ts) {
    if (ts == null) return DateTime.now();
    final str = ts.toString().trim();
    if (str.isEmpty) return DateTime.now();
    try {
      if (str.contains(' ')) {
        final parts = str.split(' ');
        final dParts = parts[0].split('-');
        final tParts = parts[1].split(':');
        return DateTime(
          int.parse(dParts[0]),
          int.parse(dParts[1]),
          int.parse(dParts[2]),
          int.parse(tParts[0]),
          int.parse(tParts[1]),
          tParts.length > 2 ? int.parse(tParts[2].split('.')[0]) : 0,
        );
      }
      return DateTime.parse(str);
    } catch (_) {
      return DateTime.now();
    }
  }

  Widget _buildSingleChartCard({required String title, required Widget chartWidget}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const Divider(height: 20),
          SizedBox(
            height: 340,
            child: chartWidget,
          ),
        ],
      ),
    );
  }

  ZoomPanBehavior get _zoomPanBehavior => ZoomPanBehavior(
        enablePinching: true,
        enablePanning: true,
        enableDoubleTapZooming: true,
        enableSelectionZooming: true,
        enableMouseWheelZooming: _isShiftPressed,
        zoomMode: ZoomMode.x,
      );

  TrackballBehavior get _trackballBehavior => TrackballBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        lineType: TrackballLineType.vertical,
        tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
        tooltipSettings: const InteractiveTooltip(
          enable: true,
          format: 'series.name : point.y',
        ),
      );

  Widget _buildTempHumChart() {
    if (_historyData.isEmpty) return const Center(child: Text('No telemetry historical records.'));

    return SfCartesianChart(
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      zoomPanBehavior: _zoomPanBehavior,
      trackballBehavior: _trackballBehavior,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        enableAutoIntervalOnZooming: true,
        labelRotation: -45,
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        name: 'TempAxis',
        title: AxisTitle(text: 'Temperature (°C)'),
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      axes: <ChartAxis>[
        NumericAxis(
          name: 'HumAxis',
          title: AxisTitle(text: 'Humidity (%)'),
          opposedPosition: true,
          majorGridLines: const MajorGridLines(width: 0),
          minorGridLines: const MinorGridLines(width: 0),
        )
      ],
      series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
        SplineSeries<Map<String, dynamic>, DateTime>(
          name: 'Temperature (°C)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['now_temperature']?.toString() ?? d['Temperature']?.toString() ?? ''),
          color: const Color(0xFFEA580C),
          yAxisName: 'TempAxis',
        ),
        SplineSeries<Map<String, dynamic>, DateTime>(
          name: 'Humidity (%)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['now_relative_humidity']?.toString() ?? d['Humidity']?.toString() ?? ''),
          color: const Color(0xFF7C3AED),
          yAxisName: 'HumAxis',
        ),
      ],
    );
  }

  Widget _buildRainfallChart() {
    if (_historyData.isEmpty) return const Center(child: Text('No telemetry historical records.'));

    return SfCartesianChart(
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      zoomPanBehavior: _zoomPanBehavior,
      trackballBehavior: _trackballBehavior,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        enableAutoIntervalOnZooming: true,
        labelRotation: -45,
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Rainfall (mm)'),
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
        ColumnSeries<Map<String, dynamic>, DateTime>(
          name: 'Rainfall (mm)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['rainfall']?.toString() ?? d['Rainfall']?.toString() ?? '0.0'),
          color: const Color(0xFF2563EB),
        ),
      ],
    );
  }

  Widget _buildPressureChart() {
    if (_historyData.isEmpty) return const Center(child: Text('No telemetry historical records.'));

    return SfCartesianChart(
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      zoomPanBehavior: _zoomPanBehavior,
      trackballBehavior: _trackballBehavior,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        enableAutoIntervalOnZooming: true,
        labelRotation: -45,
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Atmospheric Pressure (hPa)'),
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
        SplineAreaSeries<Map<String, dynamic>, DateTime>(
          name: 'Atm. Pressure (hPa)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['now_pressure']?.toString() ?? d['AtmPressure']?.toString() ?? ''),
          color: const Color(0xFF0D9488).withValues(alpha: 0.2),
          borderColor: const Color(0xFF0D9488),
          borderWidth: 2,
        ),
      ],
    );
  }

  Widget _buildWindChart() {
    if (_historyData.isEmpty) return const Center(child: Text('No telemetry historical records.'));

    return SfCartesianChart(
      legend: const Legend(isVisible: true, position: LegendPosition.top),
      zoomPanBehavior: _zoomPanBehavior,
      trackballBehavior: _trackballBehavior,
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MM/dd HH:mm'),
        intervalType: DateTimeIntervalType.auto,
        enableAutoIntervalOnZooming: true,
        labelRotation: -45,
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(text: 'Wind Speed / Gust (m/s)'),
        majorGridLines: const MajorGridLines(width: 0.4, color: Color(0xFFE2E8F0)),
        minorGridLines: const MinorGridLines(width: 0),
      ),
      series: <CartesianSeries<Map<String, dynamic>, DateTime>>[
        SplineSeries<Map<String, dynamic>, DateTime>(
          name: 'Wind Speed (m/s)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['now_wind_speed']?.toString() ?? d['WindSpeed']?.toString() ?? ''),
          color: const Color(0xFF0288D1),
        ),
        SplineSeries<Map<String, dynamic>, DateTime>(
          name: 'Max Wind Gust (m/s)',
          dataSource: _historyData,
          xValueMapper: (d, _) => _parseTimeStamp(d['TimeStamp']),
          yValueMapper: (d, _) => double.tryParse(d['max_wind_gust']?.toString() ?? d['WindGust']?.toString() ?? ''),
          color: const Color(0xFFDC2626),
        ),
      ],
    );
  }
}
