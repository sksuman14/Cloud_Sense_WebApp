import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_sense_webapp/src/admin/device_health_status.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

class QualityDiagnosticsPage extends StatefulWidget {
  final String deviceId;
  final String deviceIdTopic;
  final String displayName;
  final bool isDark;

  const QualityDiagnosticsPage({
    Key? key,
    required this.deviceId,
    required this.deviceIdTopic,
    required this.displayName,
    required this.isDark,
  }) : super(key: key);

  @override
  State<QualityDiagnosticsPage> createState() => _QualityDiagnosticsPageState();
}

class _QualityDiagnosticsPageState extends State<QualityDiagnosticsPage> {
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<DeviceQualityHistoryRecord> _records = [];
  String? _error;
  String? _nextToken;
  bool _hasMore = false;
  bool _isShiftPressed = false;
  Map<String, dynamic>? _spatialNeighbors;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _fetchQualityStatus();
    _fetchSpatialNeighbors();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    if (_isShiftPressed != isShift) {
      if (mounted) {
        setState(() => _isShiftPressed = isShift);
      }
    }
    return false;
  }

  Future<void> _fetchSpatialNeighbors() async {
    try {
      final String topicParam;
      if (widget.deviceIdTopic.contains('#')) {
        topicParam = widget.deviceIdTopic;
      } else {
        topicParam = '${widget.deviceId}#${widget.deviceIdTopic}';
      }

      final uri = Uri.parse(
          'https://sqg9bdaim9.execute-api.us-east-1.amazonaws.com/default/getSpatialNeighbours?deviceId_topic=${Uri.encodeComponent(topicParam)}');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _spatialNeighbors = json.decode(response.body);
          });
        }
      } else {
        debugPrint('Failed to fetch neighbors: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching neighbors: $e');
    }
  }

  Future<void> _fetchQualityStatus() async {
    try {
      final topic = widget.deviceIdTopic.split('#').last;
      final uri = Uri.https(
        'xj0wfbsjyi.execute-api.us-east-1.amazonaws.com',
        '/default/IoT_QC_Api_Func',
        {
          'device_id': widget.deviceId,
          'topic': topic,
          'history': 'true',
          'limit': '150',
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recordsJson = data['records'] ?? [];
        if (mounted) {
          setState(() {
            _records = recordsJson
                .map((r) => DeviceQualityHistoryRecord.fromJson(r))
                .toList();
            _nextToken = data['nextToken']?.toString();
            _hasMore = data['has_more'] == true;
            _isLoading = false;
          });
        }
      } else {
        throw Exception(
            'Failed to load records (Status: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchMoreHistory() async {
    if (_isLoadingMore || !_hasMore || _nextToken == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final topic = widget.deviceIdTopic.split('#').last;
      final uri = Uri.https(
        'xj0wfbsjyi.execute-api.us-east-1.amazonaws.com',
        '/default/IoT_QC_Api_Func',
        {
          'device_id': widget.deviceId,
          'topic': topic,
          'history': 'true',
          'limit': '150',
          'nextToken': _nextToken!,
        },
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> recordsJson = data['records'] ?? [];
        final newRecords = recordsJson
            .map((r) => DeviceQualityHistoryRecord.fromJson(r))
            .toList();

        if (mounted) {
          setState(() {
            _records.addAll(newRecords);
            _nextToken = data['nextToken']?.toString();
            _hasMore = data['has_more'] == true;
            _isLoadingMore = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strong = widget.isDark ? Colors.white : Colors.black87;
    final bgColor =
        widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: strong),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quality Diagnostics',
              style: TextStyle(
                  color: strong, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  widget.displayName,
                  style:
                      TextStyle(color: strong.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(width: 16),
                InkWell(
                  onTap: () {
                    String? sensorName =
                        DevicePrefixUtils.getSensorNameFromTopic(
                            widget.deviceIdTopic);
                    if (sensorName == null &&
                        widget.deviceIdTopic.contains('WS/SSMet_0126')) {
                      sensorName = 'WJ${widget.deviceId.padLeft(3, '0')}';
                    }

                    final mapping = DevicePrefixUtils.mapCategoryAndPrefix(
                        widget.deviceIdTopic.contains('WS/SSMet_0126')
                            ? widget.deviceIdTopic
                            : '0#${widget.deviceIdTopic}');

                    NavigationUtils.navigateTo(
                      context,
                      '/admin/devicegraph',
                      arguments: {
                        'deviceName': sensorName ?? widget.deviceId,
                        'sequentialName': mapping.category,
                        'backgroundImagePath': 'assets/backgroundd.jpg',
                      },
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(Icons.show_chart,
                          color: Colors.blueAccent, size: 14),
                      SizedBox(width: 4),
                      Text(
                        "View Graph",
                        style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: strong),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchQualityStatus();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)))
              : _records.isEmpty
                  ? const Center(child: Text('No history found'))
                  : _buildContent(strong, cardColor),
    );
  }

  Widget _buildContent(Color strong, Color cardColor) {
    // Identify all parameters across all records
    final allParams = <String>{};
    for (var r in _records) {
      allParams.addAll(r.rawSnapshot.keys);
    }
    // Filter out system parameters
    allParams.removeWhere((p) {
      final lp = p.toLowerCase();
      return lp.contains('battery') ||
          lp.contains('signalstrength') ||
          lp.contains('firmware') ||
          lp.contains('sd_card');
    });
    final paramsList = allParams.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(strong, cardColor),
          const SizedBox(height: 24),
          Text(
            'PARAMETER DIAGNOSTICS',
            style: TextStyle(
              color: strong.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth > 1200
                ? 3
                : (constraints.maxWidth > 800 ? 2 : 1);
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 320,
              ),
              itemCount: paramsList.length,
              itemBuilder: (context, index) {
                return _buildParameterChart(
                    paramsList[index], strong, cardColor);
              },
            );
          }),
          if (_hasMore) ...[
            const SizedBox(height: 32),
            Center(
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _fetchMoreHistory,
                      icon: const Icon(Icons.add_chart),
                      label: const Text('Load More Data Points'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Color strong, Color cardColor) {
    final latest = _records.first;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strong.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('LATEST OVERALL STATUS',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  _buildFlagBadge(latest.overallFlag),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('LAST RECORDED AT',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const SizedBox(height: 4),
                  Text(latest.timestamp,
                      style: TextStyle(
                          color: strong,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const Divider(height: 32),
          const Text('STATUS LEGEND',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _buildLegendItem('Good', Colors.greenAccent),
              _buildLegendItem('Suspect', Colors.orangeAccent),
              _buildLegendItem('Erroneous', Colors.redAccent),
              _buildLegendItem(
                  'Inconsistent', const Color.fromARGB(255, 209, 233, 114)),
              _buildLegendItem(
                  'Missing', const Color.fromARGB(255, 111, 223, 238)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParameterChart(String param, Color strong, Color cardColor) {
    final baseColor = _getParamColor(param);
    final chartData = _records
        .map((r) {
          DateTime time;
          try {
            time = DateFormat("yyyy-MM-dd HH:mm:ss").parse(r.timestamp);
          } catch (e) {
            time = DateTime.now();
          }

          final rawVal = r.rawSnapshot[param];
          final value = double.tryParse(rawVal?.toString() ?? '');

          dynamic fieldData = r.flaggedFields[param];
          if (fieldData == null) {
            final lowerParam = param.toLowerCase();
            for (var key in r.flaggedFields.keys) {
              if (key.toLowerCase() == lowerParam) {
                fieldData = r.flaggedFields[key];
                break;
              }
            }
          }

          String pointStatus = 'GOOD';
          String? reason;

          if (fieldData is Map) {
            pointStatus = fieldData['flag']?.toString().toUpperCase() ?? 'GOOD';
            reason = fieldData['reason']?.toString();
          } else if (fieldData != null) {
            pointStatus = fieldData.toString().toUpperCase();
          }

          // // Check for spatial anomaly and append its reason
          // if (r.flaggedFields.containsKey('spatial')) {
          //   final spatialData = r.flaggedFields['spatial'];
          //   if (spatialData is Map) {
          //     final spatialReason = spatialData['reason']?.toString();
          //     if (spatialReason != null && spatialReason.isNotEmpty) {
          //       if (reason != null && reason.isNotEmpty) {
          //         reason = "$reason, Spatial Anomaly: $spatialReason";
          //       } else {
          //         reason = "Spatial Anomaly: $spatialReason";
          //       }
          //     }
          //   }
          // }

          final pointColor = _getFlagColor(pointStatus);

          return _ChartData(time, value ?? 0, pointColor, pointStatus, reason,
              r.flaggedFields, fieldData);
        })
        .toList()
        .reversed
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: strong.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getDisplayName(param),
            style: TextStyle(
                color: strong, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SfCartesianChart(
              margin: EdgeInsets.zero,
              plotAreaBorderWidth: 0,
              primaryXAxis: DateTimeAxis(
                isVisible: true,
                labelStyle:
                    TextStyle(color: strong.withOpacity(0.5), fontSize: 8),
                dateFormat: DateFormat('HH:mm\ndd MMM'),
                majorGridLines: const MajorGridLines(width: 0),
                axisLine: const AxisLine(width: 0),
              ),
              primaryYAxis: NumericAxis(
                labelStyle:
                    TextStyle(color: strong.withOpacity(0.5), fontSize: 9),
                majorGridLines: MajorGridLines(
                    color: strong.withOpacity(0.05), dashArray: const [5, 5]),
                axisLine: const AxisLine(width: 0),
              ),
              zoomPanBehavior: ZoomPanBehavior(
                enablePanning: true,
                enablePinching: true,
                enableMouseWheelZooming: _isShiftPressed,
                zoomMode: ZoomMode.x,
              ),
              tooltipBehavior: TooltipBehavior(
                enable: true,
                header: '',
                activationMode: ActivationMode.singleTap,
                duration: 15000,
                builder: (dynamic data, dynamic point, dynamic series,
                    int pointIndex, int seriesIndex) {
                  final _ChartData d = data;
                  return SelectionContainer.disabled(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF1E293B)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4)
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(DateFormat('dd MMM, HH:mm').format(d.x),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Text('Value: ${d.y.toStringAsFixed(2)}',
                              style: TextStyle(
                                  color: strong, fontWeight: FontWeight.bold)),
                          Text(d.flag,
                              style: TextStyle(
                                  color: d.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900)),
                          if (d.reason != null && d.reason!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text('Reason: ${d.reason}',
                                style: TextStyle(
                                    color: strong.withOpacity(0.7),
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic)),
                          ],
                          if (d.reason?.toLowerCase().contains('spatial') ==
                                  true &&
                              _spatialNeighbors != null) ...[
                            const SizedBox(height: 6),
                            const Text('Neighbouring Devices:',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueAccent)),
                            ...List.generate(
                              _spatialNeighbors!['total_neighbors_found'] ?? 0,
                              (i) {
                                final rawId = _spatialNeighbors![
                                        'neighbor_${i + 1}_raw_id'] ??
                                    'Unknown';
                                final fullId = _spatialNeighbors![
                                        'neighbor_${i + 1}_id'] ??
                                    '';
                                final dist = _spatialNeighbors![
                                        'neighbor_${i + 1}_dist'] ??
                                    0.0;

                                String displayName = rawId;
                                if (fullId.isNotEmpty) {
                                  final internalId =
                                      DevicePrefixUtils.getSensorNameFromTopic(
                                          fullId);
                                  if (internalId != null) {
                                    displayName =
                                        DevicePrefixUtils.toAnnamDisplayName(
                                            internalId);
                                  }
                                }

                                String? neighbourValStr;
                                if (d.fieldData is Map) {
                                  for (int n = 1; n <= 10; n++) {
                                    if (fullId.isNotEmpty &&
                                        d.fieldData['n${n}_id'] == fullId) {
                                      final val = d.fieldData['n${n}_val'];
                                      if (val != null) {
                                        neighbourValStr = val is double
                                            ? val.toStringAsFixed(2)
                                            : val.toString();
                                      }
                                      break;
                                    } else if (rawId != 'Unknown' &&
                                        d.fieldData['n${n}_id'] == rawId) {
                                      final val = d.fieldData['n${n}_val'];
                                      if (val != null) {
                                        neighbourValStr = val is double
                                            ? val.toStringAsFixed(2)
                                            : val.toString();
                                      }
                                      break;
                                    }
                                  }
                                }

                                String displayText =
                                    '$displayName (${dist} km)';
                                if (neighbourValStr != null) {
                                  displayText += '  [Val: $neighbourValStr]';
                                }

                                return Text(displayText,
                                    style: TextStyle(
                                        color: strong,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 9));
                              },
                            ),
                          ] else if ((d.reason
                                          ?.toLowerCase()
                                          .contains('spatial') ==
                                      true ||
                                  d.flaggedParams.containsKey('spatial')) &&
                              _spatialNeighbors == null) ...[
                            const SizedBox(height: 6),
                            const Text('Fetching neighbors...',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
              series: <CartesianSeries<_ChartData, DateTime>>[
                AreaSeries<_ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (_ChartData d, _) => d.x,
                  yValueMapper: (_ChartData d, _) => d.y,
                  color: baseColor.withOpacity(0.1),
                  borderColor: baseColor.withOpacity(0.5),
                  borderWidth: 2,
                  gradient: LinearGradient(
                    colors: [
                      baseColor.withOpacity(0.3),
                      baseColor.withOpacity(0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                ScatterSeries<_ChartData, DateTime>(
                  dataSource: chartData,
                  xValueMapper: (_ChartData d, _) => d.x,
                  yValueMapper: (_ChartData d, _) => d.y,
                  pointColorMapper: (_ChartData d, _) => d.color,
                  markerSettings: const MarkerSettings(
                      isVisible: true, height: 6, width: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlagBadge(String flag) {
    Color color = _getFlagColor(flag);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        flag.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getFlagColor(String flag) {
    flag = flag.toUpperCase();
    if (flag == 'GOOD') return Colors.greenAccent;
    if (flag == 'SUSPECT') return Colors.orangeAccent;
    if (flag == 'ERRONEOUS') return Colors.redAccent;
    if (flag == 'INCONSISTENT') return const Color.fromARGB(255, 209, 233, 114);
    if (flag == 'MISSING') return const Color.fromARGB(255, 111, 223, 238);
    return Colors.grey;
  }

  Color _getParamColor(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('temp')) return const Color(0xFF00897B); // Teal
    if (lowerTitle.contains('humid')) return const Color(0xFF2196F3); // Blue
    if (lowerTitle.contains('light'))
      return const Color.fromARGB(255, 201, 161, 40); // Amber
    if (lowerTitle.contains('rain')) return const Color(0xFF4CAF50); // Green
    if (lowerTitle.contains('press')) return const Color(0xFFFF7043); // Coral
    if (lowerTitle.contains('wind')) return const Color(0xFF536DFE); // Indigo
    if (lowerTitle.contains('battery')) return const Color(0xFF8BC34A); // Lime
    if (lowerTitle.contains('signal')) return const Color(0xFFFF4081); // Pink
    if (lowerTitle.contains('co2'))
      return const Color(0xFF7C4DFF); // Deep Purple
    if (lowerTitle.contains('pm2.5'))
      return const Color(0xFFFF5722); // Deep Orange
    if (lowerTitle.contains('pm10'))
      return const Color.fromARGB(255, 196, 130, 105); // Brown
    return const Color(0xFF00BCD4); // Cyan
  }

  String _getDisplayName(String key) {
    const Map<String, String> names = {
      "MaximumTemperature": "Maximum Temperature",
      "HumidityHourlyComulative": "Humidity Hourly Comulative",
      "AtmPressure": "Pressure",
      "AverageTemperature": "Average Temperature",
      "MaximumHumidity": "Maximum Humidity",
      "MinimumTemperature": "Minimum Temperature",
      "PressureHourlyComulative": "Pressure Hourly Comulative",
      "LightIntensity": "Light Intensity",
      "RainfallMinutly": "Rainfall Minutly",
      "CurrentTemperature": "Temperature",
      "WindDirection": "Wind Direction",
      "WindSpeed": "Wind Speed",
      "RainfallWeekly": "Rainfall Weekly",
      "RainfallDaily": "Rainfall Daily",
      "AverageHumidity": "Average Humidity",
      "BatteryVoltage": "Battery Voltage",
      "MinimumHumidity": "Minimum Humidity",
      "CurrentHumidity": "Humidity",
      "RainfallHourly": "Rainfall Hourly",
      "LuxHourlyComulative": "Lux Hourly Comulative",
      "TemperatureHourlyComulative": "Temperature Hourly Comulative",
      "SunshineHours": "Sunshine Hours",
      "PAR": "PAR",
      "UVRadiation": "UV Radiation",
      "SolarRadiation": "Solar Radiation",
      "CurrentRelativeHumidity": "Relative Humidity",
      "MinimumRelativeHumidity": "Min Humidity",
      "MaximumRelativeHumidity": "Max Humidity",
      "AverageWindSpeed": "Avg Wind Speed",
      "CurrentWindSpeed": "Wind Speed",
      "CurrentWindDirection": "Wind Direction",
      "MaximumWindGustSpeed": "Max Wind Gust",
      "MaximumWindGustDirection": "Max Gust Direction",
      "SquallWindSpeed": "Squall Wind Speed",
      "RainfallCumulative": "Rainfall Cumulative",
      "Rainfall": "Rainfall",
      "Tilt": "Tilt",
      "PanelVoltage": "Panel Voltage",
      "spatial": "Spatial Anomaly",
    };

    if (names.containsKey(key)) return names[key]!;

    final lowerKey = key.toLowerCase();
    for (var entry in names.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }

    return key;
  }
}

class _ChartData {
  _ChartData(this.x, this.y, this.color, this.flag, this.reason,
      this.flaggedParams, this.fieldData);
  final DateTime x;
  final double y;
  final Color color;
  final String flag;
  final String? reason;
  final Map<String, dynamic> flaggedParams;
  final dynamic fieldData;
}

class DeviceQualityHistoryRecord {
  final String timestamp;
  final String overallFlag;
  final Map<String, dynamic> flaggedFields;
  final int intervalMin;
  final Map<String, dynamic> rawSnapshot;

  DeviceQualityHistoryRecord({
    required this.timestamp,
    required this.overallFlag,
    required this.flaggedFields,
    required this.intervalMin,
    required this.rawSnapshot,
  });

  factory DeviceQualityHistoryRecord.fromJson(Map<String, dynamic> json) {
    return DeviceQualityHistoryRecord(
      timestamp: json['timestamp']?.toString() ?? '',
      overallFlag: json['overall_flag']?.toString() ?? 'UNKNOWN',
      flaggedFields: Map<String, dynamic>.from(json['flagged_fields'] ?? {}),
      intervalMin: (json['interval_min'] as num?)?.toInt() ?? 0,
      rawSnapshot: Map<String, dynamic>.from(json['raw_snapshot'] ?? {}),
    );
  }
}
