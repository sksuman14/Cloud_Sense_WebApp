import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'dart:async';
import 'package:cloud_sense_webapp/src/utils/device_config.dart';

class WeatherNowcastingPage extends StatefulWidget {
  final String deviceName;
  final String sequentialName;

  const WeatherNowcastingPage({
    Key? key,
    required this.deviceName,
    required this.sequentialName,
  }) : super(key: key);

  @override
  State<WeatherNowcastingPage> createState() => _WeatherNowcastingPageState();
}

class _WeatherNowcastingPageState extends State<WeatherNowcastingPage>
    with TickerProviderStateMixin {
  String _selectedParameter = 'Temperature';
  bool _isLoading = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _sunController;
  late AnimationController _cloudController;

  List<NowcastData> _historicalTemperature = [];
  List<NowcastData> _historicalPressure = [];
  List<NowcastData> _historicalHumidity = [];
  List<NowcastData> _historicalWind = [];
  List<NowcastData> _historicalRain = [];
  List<NowcastData> _forecastTemperature = [];
  List<NowcastData> _forecastPressure = [];
  List<NowcastData> _forecastHumidity = [];
  List<NowcastData> _shortForecastTemp = [];
  List<double> _shortForecastDewPoint = [];
  List<IconData> _shortForecastIcons = [];
  List<String> _shortForecastTimes = [];

  List<NowcastData> _forecastWind = [];
  List<NowcastData> _forecastRain = [];
  List<NowcastData> _forecastRainProb = [];
  String _currentCondition = '';
  List<String> _hourlyConditions = [];
  List<Map<String, dynamic>> _forecastRawList = [];
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _sunController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _cloudController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _sunController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  double _round1Decimal(double val) {
    return (val * 10).round() / 10.0;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_fetchHistoricalData(), _fetchForecastData()]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchHistoricalData() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    final config = DeviceConfig.getConfig(widget.deviceName);
    if (config == null) return;

    String template = config.apiTemplate ?? '';
    if (template.isEmpty) return;

    String deviceIdStr = widget.deviceName;
    if (widget.deviceName.startsWith('AWS_')) {
      deviceIdStr = widget.deviceName.substring(4);
    } else if (RegExp(r'^[A-Za-z]{2}').hasMatch(widget.deviceName)) {
      deviceIdStr = widget.deviceName.substring(2);
    }
    if (RegExp(r'^\d+$').hasMatch(deviceIdStr)) {
      deviceIdStr = int.parse(deviceIdStr).toString();
    }
    final int deviceIdNumeric = int.tryParse(deviceIdStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;

    String deviceIdPadded = deviceIdNumeric.toString().padLeft(3, '0');
    String deviceIdPadded2 = deviceIdNumeric.toString().padLeft(2, '0');

    final String startdateStr = DateFormat('dd-MM-yyyy').format(startOfDay);
    final String enddateStr = DateFormat('dd-MM-yyyy').format(now);
    final String startdateYMD = DateFormat('yyyy-MM-dd').format(startOfDay);
    final String enddateYMD = DateFormat('yyyy-MM-dd').format(now);

    final String url = template
        .replaceAll('{deviceId}', deviceIdStr)
        .replaceAll('{deviceIdPadded}', deviceIdPadded)
        .replaceAll('{deviceIdPadded2}', deviceIdPadded2)
        .replaceAll('{deviceName}', widget.deviceName)
        .replaceAll('{startdate}', startdateStr)
        .replaceAll('{enddate}', enddateStr)
        .replaceAll('{startdate_yyyy_mm_dd}', startdateYMD)
        .replaceAll('{enddate_yyyy_mm_dd}', enddateYMD);

    final separator = url.contains('?') ? '&' : '?';
    final cacheBusterUrl = '$url${separator}t=${DateTime.now().millisecondsSinceEpoch}';
    final response = await http.get(Uri.parse(cacheBusterUrl));
    if (response.statusCode != 200) return;

    final data = json.decode(response.body);
    final List<dynamic> items = data is List
        ? data
        : ((data as Map<String, dynamic>)['items'] as List?) ?? [];
    if (items.isEmpty) return;

    // Parse all readings
    final List<NowcastData> allTemp = [];
    final List<NowcastData> allPres = [];
    final List<NowcastData> allHum = [];
    final List<NowcastData> allWind = [];
    final List<NowcastData> allRain = [];

    for (final item in items) {
      final tsStr = (item['TimeStamp'] ?? item['human_time'] ?? item['timestamp'] ?? item['Time_Stamp'] ?? '').toString();
      if (tsStr.isEmpty) continue;
      final ts = DateTime.parse(tsStr);
      if (ts.isBefore(startOfDay)) continue;

      final temp = double.tryParse((item['CurrentTemperature'] ?? item['now_temperature'] ?? '0').toString()) ?? 0.0;
      final pres = double.tryParse((item['AtmPressure'] ?? item['now_pressure'] ?? '0').toString()) ?? 0.0;
      final hum = double.tryParse((item['CurrentHumidity'] ?? item['now_relative_humidity'] ?? '0').toString()) ?? 0.0;
      final wind = double.tryParse((item['WindSpeed'] ?? item['now_wind_speed'] ?? '0').toString()) ?? 0.0;
      final rain = double.tryParse((item['RainfallHourly'] ?? item['rainfall'] ?? '0').toString()) ?? 0.0;

      allTemp.add(NowcastData(ts, temp));
      allPres.add(NowcastData(ts, pres));
      allHum.add(NowcastData(ts, hum));
      allWind.add(NowcastData(ts, wind / 3.6));
      allRain.add(NowcastData(ts, rain));
    }

    // Sort just in case the API doesn't return sorted data
    allTemp.sort((a, b) => a.time.compareTo(b.time));
    allPres.sort((a, b) => a.time.compareTo(b.time));
    allHum.sort((a, b) => a.time.compareTo(b.time));
    allWind.sort((a, b) => a.time.compareTo(b.time));
    allRain.sort((a, b) => a.time.compareTo(b.time));

    // ────────────────────────────────────────────────
    //   Find where the current (incomplete) hour starts
    // ────────────────────────────────────────────────
    final currentHourStart =
        DateTime(now.year, now.month, now.day, now.hour, 0, 0);

    // ────────────────────────────────────────────────
    //   Helper: get data up to (but not including) current hour
    // ────────────────────────────────────────────────
    List<NowcastData> getCompletedHours(List<NowcastData> all) {
      final result = <NowcastData>[];

      var hourStart = startOfDay;
      while (hourStart.isBefore(currentHourStart)) {
        final hourEnd = hourStart.add(const Duration(hours: 1));

        // All readings that belong to this hour
        final inHour = all
            .where(
                (d) => !d.time.isBefore(hourStart) && d.time.isBefore(hourEnd))
            .toList();

        if (inHour.isEmpty) {
          hourStart = hourEnd;
          continue;
        }

        // Take the LAST (most recent) value that arrived in this hour
        final latestValue = inHour.last.value;

        // But place it exactly at the START of the hour for clean labeling
        result.add(NowcastData(hourStart, latestValue));

        hourStart = hourEnd;
      }

      return result;
    }

    // ────────────────────────────────────────────────
    //   Current (incomplete) hour → ALL points
    // ────────────────────────────────────────────────
    List<NowcastData> getCurrentHour(List<NowcastData> all) {
      return all.where((d) => !d.time.isBefore(currentHourStart)).toList();
    }

    if (mounted) {
      setState(() {
        _historicalTemperature = [
          ...getCompletedHours(allTemp),
          ...getCurrentHour(allTemp),
        ];

        _historicalPressure = [
          ...getCompletedHours(allPres),
          ...getCurrentHour(allPres),
        ];

        _historicalHumidity = [
          ...getCompletedHours(allHum),
          ...getCurrentHour(allHum),
        ];

        _historicalWind = [
          ...getCompletedHours(allWind),
          ...getCurrentHour(allWind),
        ];

        _historicalRain = [
          ...getCompletedHours(allRain),
          ...getCurrentHour(allRain),
        ];
      });
    }
  }

  Future<void> _fetchForecastData() async {
    final url =
        'https://pov4sqw1t1.execute-api.us-east-1.amazonaws.com/prod/forecast?t=${DateTime.now().millisecondsSinceEpoch}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final forecastItems = (data['forecast'] as List<dynamic>?) ?? [];

      List<NowcastData> tempData = [],
          pressureData = [],
          humidityData = [],
          windData = [],
          rainData = [],
          rainProbData = [];

      List<NowcastData> shortTemp = [];
      List<IconData> shortIcons = [];
      List<String> shortTimes = [];
      List<String> hourlyConditions = [];

      for (int i = 0; i < forecastItems.length; i++) {
        final item = forecastItems[i];
        final timestamp = DateTime.parse(item['time'] as String);
        final condition = (item['condition'] as String?) ?? '';

        // Store condition for each hour
        hourlyConditions.add(condition);

        tempData.add(NowcastData(
            timestamp, _round1Decimal((item['temp'] as num).toDouble())));
        pressureData.add(NowcastData(
            timestamp, _round1Decimal((item['pressure'] as num).toDouble())));
        humidityData.add(NowcastData(
            timestamp, _round1Decimal((item['humidity'] as num).toDouble())));

        final windKmh = (item['wind_speed'] as num).toDouble();
        final windMs = windKmh / 3.6;
        windData.add(NowcastData(timestamp, _round1Decimal(windMs)));

        rainData.add(NowcastData(
            timestamp, _round1Decimal((item['rain'] as num).toDouble())));

        rainProbData.add(NowcastData(
            timestamp, _round1Decimal((item['rain_prob'] as num).toDouble())));

        if (i < 4) {
          final timeLabel =
              i == 0 ? 'Now' : DateFormat('h a').format(timestamp);

          shortTemp.add(NowcastData(
              timestamp, _round1Decimal((item['temp'] as num).toDouble())));

          final dewPoint = (item['dew_point'] as num?)?.toDouble() ?? 0.0;
          _shortForecastDewPoint.add(_round1Decimal(dewPoint));

          IconData icon = Icons.wb_sunny;
          if (condition.contains('CLEAR') || condition.contains('☀️')) {
            icon = Icons.wb_sunny;
          } else if (condition.contains('CLOUDY') || condition.contains('☁️')) {
            icon = Icons.cloud;
          } else if (condition.contains('RAIN') ||
              condition.contains('SHOWER')) {
            icon = Icons.grain;
          } else if (condition.contains('DRIZZLE')) {
            icon = Icons.grain;
          } else {
            icon = Icons.cloud_queue;
          }
          shortIcons.add(icon);
          shortTimes.add(timeLabel);
        }
      }

      if (mounted) {
        setState(() {
          _forecastRawList = List<Map<String, dynamic>>.from(forecastItems);
          _forecastTemperature = tempData;
          _forecastPressure = pressureData;
          _forecastHumidity = humidityData;
          _forecastWind = windData;
          _forecastRain = rainData;
          _forecastRainProb = rainProbData;
          _hourlyConditions = hourlyConditions;

          _shortForecastTemp = shortTemp;
          _shortForecastIcons = shortIcons;
          _shortForecastTimes = shortTimes;

          _currentCondition = forecastItems.isNotEmpty
              ? _formatCondition(forecastItems[0]['condition'] as String? ?? '')
              : '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(isDarkMode, isMobile),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode
                ? [
                    const Color(0xFF14212B),
                    const Color(0xFF0B141D),
                  ]
                : [
                    Colors.grey[200]!,
                    Colors.white,
                  ],
          ),
        ),
        child: _isLoading
            ? _buildLoadingState(isDarkMode)
            : _historicalTemperature.isEmpty
                ? _buildEmptyState(isDarkMode)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      _buildWeatherHeader(isDarkMode, isMobile),
                      const SizedBox(height: 24),
                      _buildParameterTabs(isDarkMode),
                      const SizedBox(height: 16),
                      _buildNowcastChart(isDarkMode),
                      const SizedBox(height: 24),
                      _buildDetailedForecastSection(isDarkMode),
                    ])),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, bool isMobile) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
      leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weather Nowcasting',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              )),
          Text('${widget.sequentialName} (${widget.deviceName})',
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              )),
        ],
      ),
      actions: [
        IconButton(
            icon: Icon(Icons.refresh, color: isDarkMode ? Colors.white : Colors.black87),
            onPressed: _loadData,
            tooltip: 'Refresh')
      ],
    );
  }

  Widget _buildWeatherHeader(bool isDarkMode, bool isMobile) {
    if (_historicalTemperature.isEmpty) return const SizedBox.shrink();

    final temp = _historicalTemperature.last.value.toStringAsFixed(1);
    final humidity = _historicalHumidity.last.value.toStringAsFixed(1);
    
    // Dynamic gradients with high contrast and colors
    final String conditionLower = _currentCondition.toLowerCase();
    LinearGradient cardGradient;
    Color glowColor;
    if (conditionLower.contains('clear')) {
      cardGradient = LinearGradient(
        colors: isDarkMode 
            ? [const Color(0xFF1E3C72), const Color(0xFF2A5298)]
            : [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      glowColor = Colors.blueAccent;
    } else if (conditionLower.contains('rain') || conditionLower.contains('drizzle')) {
      cardGradient = LinearGradient(
        colors: isDarkMode
            ? [const Color(0xFF374151), const Color(0xFF1F2937)]
            : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      glowColor = Colors.grey;
    } else {
      cardGradient = LinearGradient(
        colors: isDarkMode
            ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
            : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      glowColor = Colors.indigoAccent;
    }

    final Widget weatherStatusCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white24 : Colors.black12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(isDarkMode ? 0.25 : 0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT CONDITIONS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedParameter = 'Temperature';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedParameter == 'Temperature'
                          ? (isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.05))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedParameter == 'Temperature'
                            ? (isDarkMode ? Colors.white30 : Colors.black12)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$temp',
                          style: TextStyle(
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          '°C',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Glowing Weather Condition Pill Badge!
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.blueAccent, Colors.cyanAccent],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Text(
                    _currentCondition,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 90,
            width: 1.5,
            color: isDarkMode ? Colors.white24 : Colors.black12,
            margin: const EdgeInsets.symmetric(horizontal: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClickableMiniStat(
                icon: Icons.water_drop,
                label: 'Hum',
                value: '$humidity%',
                parameterName: 'Humidity',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 10),
              _buildClickableMiniStat(
                icon: Icons.speed,
                label: 'Pres',
                value: '${_historicalPressure.last.value.toStringAsFixed(0)} hPa',
                parameterName: 'Pressure',
                isDarkMode: isDarkMode,
              ),
              const SizedBox(height: 10),
              _buildClickableMiniStat(
                icon: Icons.air,
                label: 'Wind',
                value: '${_historicalWind.last.value.toStringAsFixed(1)} m/s',
                parameterName: 'Wind Speed',
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );

    final insights = _generateWeatherInsights();
    final Widget insightsCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode ? Colors.white24 : Colors.black12,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(isDarkMode ? 0.25 : 0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WEATHER INSIGHTS & ALERTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: insights.map((alert) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (alert['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (alert['color'] as Color).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      alert['icon'] as IconData,
                      color: alert['color'] as Color,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alert['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            alert['message'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );

    if (isMobile) {
      return Column(
        children: [
          weatherStatusCard,
          const SizedBox(height: 16),
          insightsCard,
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: weatherStatusCard),
          const SizedBox(width: 16),
          Expanded(flex: 5, child: insightsCard),
        ],
      );
    }
  }

  Widget _buildClickableMiniStat({
    required IconData icon,
    required String label,
    required String value,
    required String parameterName,
    required bool isDarkMode,
  }) {
    final isSelected = _selectedParameter == parameterName;
    final textCol = isDarkMode ? Colors.white : Colors.black87;
    final activeBg = isDarkMode ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.08);
    final inactiveBg = isDarkMode ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedParameter = parameterName;
          });
        },
        borderRadius: BorderRadius.circular(16),
        hoverColor: Colors.blueAccent.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? Colors.cyanAccent : (isDarkMode ? Colors.white12 : Colors.black12),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.blueAccent.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.cyanAccent : Colors.blueAccent,
              ),
              const SizedBox(width: 10),
              Text(
                '$label: ',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _generateWeatherInsights() {
    final List<Map<String, dynamic>> insights = [];

    if (_historicalTemperature.isNotEmpty) {
      final currentTemp = _historicalTemperature.last.value;
      if (currentTemp > 35.0) {
        insights.add({
          'type': 'warning',
          'icon': Icons.light_mode,
          'color': Colors.orangeAccent,
          'title': 'High Temperature Warning',
          'message': 'Temperatures are very high (${currentTemp.toStringAsFixed(1)}°C). Stay indoors and stay hydrated!'
        });
      } else if (currentTemp < 15.0) {
        insights.add({
          'type': 'info',
          'icon': Icons.ac_unit,
          'color': Colors.blueAccent,
          'title': 'Cold Weather Alert',
          'message': 'It is currently cool (${currentTemp.toStringAsFixed(1)}°C). Dress warmly!'
        });
      }
    }

    if (_historicalHumidity.isNotEmpty) {
      final currentHum = _historicalHumidity.last.value;
      if (currentHum > 80.0) {
        insights.add({
          'type': 'info',
          'icon': Icons.water_drop,
          'color': Colors.blue,
          'title': 'High Humidity Alert',
          'message': 'Relative humidity is very high ($currentHum%). It may feel warmer than the actual temperature.'
        });
      }
    }

    if (_historicalWind.isNotEmpty) {
      final currentWind = _historicalWind.last.value;
      if (currentWind > 15.0) {
        insights.add({
          'type': 'warning',
          'icon': Icons.air,
          'color': Colors.amber,
          'title': 'Strong Winds Alert',
          'message': 'Winds are currently strong (${currentWind.toStringAsFixed(1)} m/s). Secure loose outdoor items.'
        });
      }
    }

    if (_forecastRainProb.isNotEmpty) {
      final rainProbVal = _forecastRainProb.first.value;
      if (rainProbVal > 50.0) {
        insights.add({
          'type': 'warning',
          'icon': Icons.umbrella,
          'color': Colors.lightBlueAccent,
          'title': 'Rain Expected Soon',
          'message': 'There is a high chance of rain ($rainProbVal%) in the next 1-2 hours. Carry an umbrella!'
        });
      } else if (rainProbVal > 20.0) {
        insights.add({
          'type': 'info',
          'icon': Icons.cloudy_snowing,
          'color': Colors.grey,
          'title': 'Slight Chance of Rain',
          'message': 'A light drizzle is possible ($rainProbVal% probability) shortly.'
        });
      }
    }

    if (_forecastRawList.isNotEmpty) {
      final firstForecast = _forecastRawList.first;
      final presChange = double.tryParse(firstForecast['pressure_change_3h']?.toString() ?? '0') ?? 0.0;
      if (presChange < -1.5) {
        insights.add({
          'type': 'warning',
          'icon': Icons.trending_down,
          'color': Colors.redAccent,
          'title': 'Rapid Pressure Drop',
          'message': 'Atmospheric pressure is dropping fast, indicating a possible storm or weather change!'
        });
      } else if (presChange > 1.5) {
        insights.add({
          'type': 'info',
          'icon': Icons.trending_up,
          'color': Colors.greenAccent,
          'title': 'Pressure Rising',
          'message': 'Atmospheric pressure is rising, indicating clear skies and stable weather ahead.'
        });
      }
    }

    if (insights.isEmpty) {
      insights.add({
        'type': 'stable',
        'icon': Icons.check_circle_outline,
        'color': Colors.green,
        'title': 'Stable Weather Conditions',
        'message': 'No critical weather changes or alerts for the next few hours. Outdoor activities are safe.'
      });
    }

    return insights;
  }

  // Small drizzle icon for hourly cards - sun behind cloud with drops below
  Widget _buildSmallDrizzleIcon() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        children: [
          // Sun in the back
          Positioned(
            top: 2,
            right: 5,
            child: Icon(
              Icons.wb_sunny,
              size: 22,
              color: Color(0xFFFFD700),
            ),
          ),
          // Cloud in front
          Positioned(
            top: 5,
            left: 3,
            child: Icon(
              Icons.cloud,
              size: 35,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          // Small water drops below cloud
          Positioned(
            bottom: 5,
            left: 8,
            child: Icon(
              Icons.water_drop,
              size: 6,
              color: Color(0xFF64B5F6),
            ),
          ),
          Positioned(
            bottom: 7,
            left: 16,
            child: Icon(
              Icons.water_drop,
              size: 5,
              color: Color(0xFF64B5F6),
            ),
          ),
          Positioned(
            bottom: 6,
            left: 23,
            child: Icon(
              Icons.water_drop,
              size: 5,
              color: Color(0xFF64B5F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWeatherBackground(bool isDay) {
    final conditionLower = _currentCondition.toLowerCase();

    // Clear/Sunny
    if (conditionLower.contains('clear')) {
      return _buildClearWeatherBackground(isDay);
    }
    // Drizzle
    else if (conditionLower.contains('drizzle')) {
      return _buildDrizzleWeatherBackground();
    }
    // Rainy
    else if (conditionLower.contains('rain') ||
        conditionLower.contains('shower')) {
      return _buildRainyWeatherBackground();
    }
    // Cloudy
    else if (conditionLower.contains('cloudy')) {
      return _buildCloudyWeatherBackground(isDay);
    }
    // Thunderstorm
    else if (conditionLower.contains('thunder') ||
        conditionLower.contains('storm')) {
      return _buildThunderstormBackground();
    }
    // Foggy
    else if (conditionLower.contains('fog') ||
        conditionLower.contains('mist')) {
      return _buildFoggyWeatherBackground();
    }
    // Default
    else {
      return _buildClearWeatherBackground(isDay);
    }
  }

// Clear Weather Background with Landscape
  Widget _buildClearWeatherBackground(bool isDay) {
    return Stack(
      children: [
        // Sky gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDay
                  ? [
                      const Color(0xFF2193b0),
                      const Color(0xFF6dd5ed),
                    ]
                  : [
                      const Color(0xFF0F2027),
                      const Color(0xFF2C5364),
                    ],
            ),
          ),
        ),

        // Animated sun rays
        if (isDay)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sunController,
              builder: (context, child) {
                return CustomPaint(
                  painter: SunRaysPainter(_sunController.value),
                );
              },
            ),
          ),

        // Cartoon landscape at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: _buildCartoonLandscape(isDay),
        ),
      ],
    );
  }

// Drizzle Weather Background
  Widget _buildDrizzleWeatherBackground() {
    return Stack(
      children: [
        // Light gray cloudy sky
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF3a7bd5),
                const Color(0xFF3a6073),
              ],
            ),
          ),
        ),

        // Cartoon landscape
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: _buildCartoonLandscape(false, isDrizzle: true),
        ),
      ],
    );
  }

// Rainy Weather Background
  Widget _buildRainyWeatherBackground() {
    return Stack(
      children: [
        // Dark cloudy sky
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF2b5876),
                const Color(0xFF4e4376),
              ],
            ),
          ),
        ),

        // Animated rain
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: RainPainter(_cloudController.value),
              );
            },
          ),
        ),

        // Cartoon landscape
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: _buildCartoonLandscape(false, isRainy: true),
        ),
      ],
    );
  }

// Cloudy Weather Background
  Widget _buildCloudyWeatherBackground(bool isDay) {
    return Stack(
      children: [
        // Sky
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF61a5c2),
                const Color(0xFF89c2d9),
              ],
            ),
          ),
        ),

        // Animated clouds
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: CloudsPainter(_cloudController.value),
              );
            },
          ),
        ),

        // Cartoon landscape
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: _buildCartoonLandscape(isDay),
        ),
      ],
    );
  }

// Thunderstorm Background
  Widget _buildThunderstormBackground() {
    return Stack(
      children: [
        // Dark storm sky
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF141E30),
                const Color(0xFF243B55),
              ],
            ),
          ),
        ),

        // Heavy rain
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: RainPainter(_cloudController.value, isHeavy: true),
              );
            },
          ),
        ),

        // Lightning effect
        AnimatedBuilder(
          animation: _sunController,
          builder: (context, child) {
            if (_sunController.value > 0.9 || _sunController.value < 0.1) {
              return Container(
                color: Colors.white.withOpacity(0.3),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Cartoon landscape
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: _buildCartoonLandscape(false, isRainy: true),
        ),
      ],
    );
  }

// Foggy Weather Background
  Widget _buildFoggyWeatherBackground() {
    return Stack(
      children: [
        // Misty sky
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF757F9A),
                const Color(0xFFD7DDE8),
              ],
            ),
          ),
        ),

        // Animated fog layers
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: FogPainter(_cloudController.value),
              );
            },
          ),
        ),

        // Cartoon landscape (partially obscured)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: Opacity(
            opacity: 0.6,
            child: _buildCartoonLandscape(true),
          ),
        ),
      ],
    );
  }

// Cartoon Landscape
  Widget _buildCartoonLandscape(bool isDay,
      {bool isRainy = false, bool isDrizzle = false}) {
    return const SizedBox.shrink();
  }

  Widget _buildWeatherStat(
    IconData icon,
    String label,
    String value,
    Color accentColor,
    bool isDarkMode,
  ) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      children: [
        Icon(icon, color: accentColor, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildShortHourlyOverview(bool isDarkMode) {
    if (_shortForecastTemp.isEmpty || _shortForecastTimes.isEmpty) {
      return const SizedBox.shrink();
    }

    final forecastTemps = _shortForecastTemp.take(3).toList();
    final forecastHumidities = _forecastHumidity.take(3).toList();
    final forecastWinds = _forecastWind.take(3).toList();
    final forecastRains = _forecastRain.take(3).toList();

    // Get the actual forecast times from the data
    final forecastTimes = List.generate(
      3,
      (i) => DateTime.now().add(Duration(hours: i + 1)),
    );

    final times = List.generate(
      3,
      (i) => DateFormat('h a').format(forecastTimes[i]),
    );

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color.fromARGB(150, 0, 0, 0)
            : Color.fromARGB(173, 227, 220, 220),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '3-Hour Nowcast',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(3, (index) {
                return _buildHourlyCard(
                  times[index],
                  forecastTemps[index].value.round(),
                  forecastHumidities[index].value.round(),
                  forecastWinds[index].value,
                  forecastRains[index].value,
                  forecastTimes[index],
                  isDarkMode,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyCard(String time, int temp, int humidity, double wind,
      double rain, DateTime forecastTime, bool isDarkMode) {
    final isDay = forecastTime.hour >= 6 && forecastTime.hour < 18;

    // Get the weather condition for this forecast hour
    String condition = '';
    if (_forecastTemperature.isNotEmpty && _hourlyConditions.isNotEmpty) {
      // Find the forecast entry for this time
      final index = _forecastTemperature.indexWhere(
        (data) =>
            data.time.hour == forecastTime.hour &&
            data.time.day == forecastTime.day,
      );
      if (index >= 0 && index < _hourlyConditions.length) {
        condition = _formatCondition(_hourlyConditions[index]);
      } else {
        condition = _currentCondition;
      }
    } else {
      condition = _currentCondition;
    }

    // Determine icon based on condition and time of day
    IconData weatherIcon;
    Color iconColor;

    final conditionLower = condition.toLowerCase();

    if (conditionLower.contains('clear')) {
      // Fully clear sky
      if (isDay) {
        weatherIcon = Icons.wb_sunny;
        iconColor = Color(0xFFFFD700);
      } else {
        weatherIcon = Icons.nightlight_round;
        iconColor = Color(0xFFFFA726);
      }
    } else if (conditionLower.contains('drizzle')) {
      // Light rain/drizzle - cloud with sun and drops
      weatherIcon = Icons.wb_cloudy;
      iconColor = Color(0xFF64B5F6);
    } else if (conditionLower.contains('partly') ||
        conditionLower.contains('partly cloudy') ||
        conditionLower.contains('mostly clear')) {
      // Partly cloudy - sun/moon with clouds
      if (isDay) {
        weatherIcon = Icons.wb_cloudy;
        iconColor = Color(0xFFFFD700);
      } else {
        weatherIcon = Icons.nights_stay;
        iconColor = Color(0xFFFFA726);
      }
    } else if (conditionLower.contains('mostly cloudy') ||
        conditionLower.contains('cloudy') ||
        conditionLower.contains('overcast')) {
      // Mostly/fully cloudy
      weatherIcon = Icons.cloud;
      iconColor = Colors.white70;
    } else if (conditionLower.contains('rain') ||
        conditionLower.contains('shower')) {
      // Rain
      weatherIcon = Icons.water_drop;
      iconColor = Color(0xFF29b6f6);
    } else if (conditionLower.contains('thunder') ||
        conditionLower.contains('storm')) {
      // Thunderstorm
      weatherIcon = Icons.flash_on;
      iconColor = Color(0xFFFFEB3B);
    } else if (conditionLower.contains('fog') ||
        conditionLower.contains('mist') ||
        conditionLower.contains('haze')) {
      // Fog/Mist
      weatherIcon = Icons.blur_on;
      iconColor = Colors.white54;
    } else if (conditionLower.contains('snow')) {
      // Snow
      weatherIcon = Icons.ac_unit;
      iconColor = Colors.lightBlue[100]!;
    } else {
      // Default fallback - show partly cloudy for unknown conditions
      if (isDay) {
        weatherIcon = Icons.wb_cloudy;
        iconColor = Color(0xFFFFD700);
      } else {
        weatherIcon = Icons.nights_stay;
        iconColor = Color(0xFFFFA726);
      }
    }

    return Container(
      width: 140,
      margin: EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color.fromARGB(100, 0, 0, 0)
            : Color.fromARGB(120, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            time,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          // Weather icon
          if (conditionLower.contains('drizzle'))
            _buildSmallDrizzleIcon()
          else
            Icon(
              weatherIcon,
              color: iconColor,
              size: 48,
            ),
          SizedBox(height: 12),
          Text(
            '$temp°',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          _buildSmallStat(
              Icons.water_drop, '$humidity%', Colors.blue[300]!, isDarkMode),
          SizedBox(height: 8),
          _buildSmallStat(
            Icons.water,
            rain > 0
                ? (rain >= 1
                    ? '${rain.toInt()} mm'
                    : '${rain.toStringAsFixed(1)} mm')
                : '0 mm',
            rain > 0 ? Colors.lightBlue[300]! : Colors.grey[500]!,
            isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStat(
      IconData icon, String value, Color color, bool isDarkMode) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Loading weather data...',
              style: TextStyle(color: Colors.white, fontSize: 16))
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off, size: 64, color: Colors.white54),
          SizedBox(height: 16),
          Text('No data available',
              style: TextStyle(fontSize: 18, color: Colors.white)),
          SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[700],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDarkMode, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(2, 0),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Parameter',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black)),
                SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.blueGrey[800] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isDarkMode
                            ? Colors.blueGrey[700]!
                            : Colors.grey[300]!),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedParameter,
                      isExpanded: true,
                      dropdownColor:
                          isDarkMode ? Colors.blueGrey[800] : Colors.white,
                      icon: Icon(Icons.arrow_drop_down,
                          color: isDarkMode ? Colors.white : Colors.black),
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      items: [
                        _buildDropdownItem(
                            'Temperature', Icons.thermostat, isDarkMode),
                        _buildDropdownItem('Pressure', Icons.speed, isDarkMode),
                        _buildDropdownItem(
                            'Humidity', Icons.water_drop, isDarkMode),
                        _buildDropdownItem('Wind Speed', Icons.air, isDarkMode),
                        _buildDropdownItem('Rainfall', Icons.water, isDarkMode)
                      ],
                      onChanged: (v) => v != null
                          ? setState(() => _selectedParameter = v)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(bool isDarkMode) => Drawer(
        backgroundColor: isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 50),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select Parameter',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black)),
                  SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.blueGrey[800] : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDarkMode
                              ? Colors.blueGrey[700]!
                              : Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedParameter,
                        isExpanded: true,
                        dropdownColor:
                            isDarkMode ? Colors.blueGrey[800] : Colors.white,
                        icon: Icon(Icons.arrow_drop_down,
                            color: isDarkMode ? Colors.white : Colors.black),
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        items: [
                          _buildDropdownItem(
                              'Temperature', Icons.thermostat, isDarkMode),
                          _buildDropdownItem(
                              'Pressure', Icons.speed, isDarkMode),
                          _buildDropdownItem(
                              'Humidity', Icons.water_drop, isDarkMode),
                          _buildDropdownItem(
                              'Wind Speed', Icons.air, isDarkMode),
                          _buildDropdownItem(
                              'Rainfall', Icons.water, isDarkMode)
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedParameter = v);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  DropdownMenuItem<String> _buildDropdownItem(
          String param, IconData icon, bool isDarkMode) =>
      DropdownMenuItem(
        value: param,
        child: Row(
          children: [
            Icon(icon,
                size: 20, color: isDarkMode ? Colors.white70 : Colors.black87),
            SizedBox(width: 12),
            Text(param,
                style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 14))
          ],
        ),
      );

  Widget _buildNowcastChart(bool isDarkMode) {
    final historicalData = _getHistoricalData();
    final forecastData = _getForecastData();
    final unit = _getUnit();
    double? minY;
    double? maxY;
    if (_selectedParameter == 'Rain Probability' || _selectedParameter == 'Wind Speed' || _selectedParameter == 'Humidity') {
      minY = 0.0;
    }
    double maxVal = 0.0;
    for (var d in historicalData) { if (d.value > maxVal) maxVal = d.value; }
    for (var d in forecastData) { if (d.value > maxVal) maxVal = d.value; }
    if (maxVal == 0.0) { maxY = 5.0; }

    final DateTime? minX = historicalData.isNotEmpty
        ? historicalData.first.time
        : (forecastData.isNotEmpty ? forecastData.first.time : null);
    final DateTime? maxX = forecastData.isNotEmpty
        ? forecastData.last.time
        : (historicalData.isNotEmpty ? historicalData.last.time : null);

    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.width < 800 ? 400 : 500,
      margin: EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDarkMode
            ? const Color.fromARGB(150, 0, 0, 0)
            : const Color.fromARGB(173, 227, 220, 220),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text('Weather Nowcast - $_selectedParameter ($unit)',
                  style: TextStyle(
                    fontSize: MediaQuery.of(context).size.width < 800 ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black,
                  )),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Historical',
                      Color.fromARGB(255, 0, 120, 215), false, isDarkMode),
                  SizedBox(width: 20),
                  _buildLegendItem('Forecast', Colors.orange, true, isDarkMode),
                ],
              ),
            ),
            Expanded(
              child: historicalData.isEmpty && forecastData.isEmpty
                  ? Center(
                      child: Text('No data',
                          style: TextStyle(color: Colors.white70)))
                  : SfCartesianChart(
                      plotAreaBackgroundColor: isDarkMode
                          ? Color.fromARGB(100, 0, 0, 0)
                          : Color.fromARGB(189, 222, 218, 218),
                      primaryXAxis: DateTimeAxis(
                        minimum: minX,
                        maximum: maxX,
                        dateFormat: DateFormat('HH:mm'),
                        title: AxisTitle(
                          text: 'Time',
                          textStyle: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black),
                        ),
                        labelStyle: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black),
                        edgeLabelPlacement: EdgeLabelPlacement.shift,
                        labelRotation: 0,
                        labelIntersectAction: AxisLabelIntersectAction.rotate45,
                        interval: 2,
                        intervalType: DateTimeIntervalType.hours,
                        majorGridLines: MajorGridLines(
                            width: 0.5, color: isDarkMode ? Colors.white12 : Colors.black12),
                        minorGridLines: MinorGridLines(width: 0),
                        majorTickLines: MajorTickLines(size: 0),
                        minorTickLines: MinorTickLines(size: 0),
                      ),
                      primaryYAxis: NumericAxis(
                        minimum: minY,
                        maximum: maxY,
                        labelStyle: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black),
                        axisLine: AxisLine(width: 1),
                        majorGridLines: MajorGridLines(width: 0),
                        minorGridLines: MinorGridLines(width: 0),
                      ),
                      trackballBehavior: TrackballBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                        lineType: TrackballLineType.vertical,
                        lineColor: isDarkMode
                            ? Colors.blue
                            : Color.fromARGB(255, 42, 147, 212),
                        lineWidth: 1,
                        markerSettings: TrackballMarkerSettings(
                          markerVisibility: TrackballVisibilityMode.visible,
                          width: 8,
                          height: 8,
                          borderWidth: 2,
                        ),
                        builder:
                            (BuildContext context, TrackballDetails details) {
                          try {
                            final time = details.point?.x as DateTime?;
                            final value = details.point?.y as double?;
                            if (time == null || value == null)
                              return const SizedBox.shrink();

                            final isForecast = time.isAfter(DateTime.now());

                            String valueStr;
                            if (_selectedParameter == 'Wind Speed') {
                              valueStr = value.toStringAsFixed(2);
                            } else {
                              valueStr = value.toStringAsFixed(1);
                            }

                            final unit = _getUnit();

                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? const Color.fromARGB(200, 0, 0, 0)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  )
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('dd MMM HH:mm').format(time),
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Value: $valueStr $unit',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isForecast
                                        ? 'Type: Forecast'
                                        : 'Type: Historical',
                                    style: TextStyle(
                                      color: isForecast
                                          ? Colors.orange
                                          : Colors.blue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } catch (e) {
                            return const SizedBox.shrink();
                          }
                        },
                      ),
                      zoomPanBehavior: ZoomPanBehavior(
                        zoomMode: ZoomMode.x,
                        enablePanning: true,
                        enablePinching: true,
                        enableMouseWheelZooming: true,
                      ),
                      series: [
                        AreaSeries<NowcastData, DateTime>(
                          dataSource: historicalData,
                          xValueMapper: (d, _) => d.time,
                          yValueMapper: (d, _) => d.value,
                          borderColor: isDarkMode
                              ? Colors.blue
                              : Color.fromARGB(255, 0, 120, 215),
                          borderWidth: 3,
                          gradient: LinearGradient(
                            colors: [
                              (isDarkMode
                                  ? Colors.blue.withOpacity(0.4)
                                  : Color.fromARGB(255, 0, 120, 215)
                                      .withOpacity(0.4)),
                              (isDarkMode
                                  ? Colors.blue.withOpacity(0)
                                  : Color.fromARGB(255, 0, 120, 215)
                                      .withOpacity(0))
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          markerSettings: MarkerSettings(isVisible: false),
                        ),
                        // Forecast - orange area + dashed line on top
                        AreaSeries<NowcastData, DateTime>(
                          dataSource: forecastData,
                          xValueMapper: (d, _) => d.time,
                          yValueMapper: (d, _) => d.value,
                          name: 'Forecast',
                          color:
                              Colors.orange.withOpacity(0.20), // ← fill color
                          borderColor: Colors.orange,
                          borderWidth: 2.8,
                          dashArray: <double>[6, 3], // keep dashed border
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.orange.withOpacity(0.40),
                              Colors.orange.withOpacity(0.03),
                            ],
                          ),
                          markerSettings: MarkerSettings(
                            isVisible: true,
                            shape: DataMarkerType.circle,
                            width: 7,
                            height: 7,
                            borderWidth: 2.2,
                            borderColor: Colors.orange[800]!,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
      String label, Color color, bool isDashed, bool isDarkMode) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (isDashed) ...[
          SizedBox(width: 2),
          Container(width: 3, height: 3, color: Colors.transparent),
          SizedBox(width: 2),
          Container(
            width: 10,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastTable(bool isDarkMode) {
    final forecastData = _getForecastData();
    final unit = _getUnit();

    return Container(
      margin: EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDarkMode
            ? Color.fromARGB(150, 0, 0, 0)
            : Color.fromARGB(173, 227, 220, 220),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Forecast Details',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                )),
            SizedBox(height: 12),
            Table(
              columnWidths: {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(2),
                2: FlexColumnWidth(1)
              },
              border: TableBorder.all(color: Colors.white.withOpacity(0.3)),
              children: [
                TableRow(
                  decoration:
                      BoxDecoration(color: Colors.white.withOpacity(0.1)),
                  children: [
                    _buildTableCell('Time', isDarkMode, isHeader: true),
                    _buildTableCell('Value', isDarkMode, isHeader: true),
                    _buildTableCell('Trend', isDarkMode, isHeader: true)
                  ],
                ),
                ...forecastData.asMap().entries.map((e) {
                  final idx = e.key;
                  final data = e.value;
                  final trend = idx > 0
                      ? (data.value - forecastData[idx - 1].value)
                      : 0.0;
                  return TableRow(children: [
                    _buildTableCell(
                        DateFormat('HH:mm').format(data.time), isDarkMode),
                    _buildTableCell('${data.value.toStringAsFixed(1)} $unit', isDarkMode),
                    _buildTableCell('', isDarkMode,
                        isIcon: true, trendValue: trend)
                  ]);
                }).toList()
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildParameterTabs(bool isDarkMode) {
    final parameters = [
      {'name': 'Temperature', 'icon': Icons.thermostat},
      {'name': 'Humidity', 'icon': Icons.water_drop},
      {'name': 'Pressure', 'icon': Icons.speed},
      {'name': 'Wind Speed', 'icon': Icons.air},
      {'name': 'Rain Probability', 'icon': Icons.umbrella},
    ];

    final activeColor = Colors.blueAccent;
    final borderCol = isDarkMode ? Colors.white12 : Colors.black12;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0F1B25) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderCol),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: parameters.map((param) {
            final name = param['name'] as String;
            final icon = param['icon'] as IconData;
            final isSelected = _selectedParameter == name;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedParameter = name;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: activeColor.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDetailedForecastSection(bool isDarkMode) {
    if (_forecastRawList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Text(
            '3-Hour Forecast Analysis',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _forecastRawList.map((item) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildDetailedForecastCard(item, isDarkMode),
                        ),
                      );
                    }).toList(),
                  )
                : Column(
                    children: _forecastRawList.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _buildDetailedForecastCard(item, isDarkMode),
                      );
                    }).toList(),
                  );
          },
        ),
      ],
    );
  }

  Widget _buildDetailedForecastCard(Map<String, dynamic> item, bool isDarkMode) {
    final String timeStr = item['time'] as String? ?? '';
    DateTime? parsedTime;
    try {
      parsedTime = DateTime.parse(timeStr);
    } catch (_) {}
    final String displayTime = parsedTime != null
        ? DateFormat('hh:mm a').format(parsedTime)
        : timeStr;

    final String condition = item['condition'] as String? ?? 'N/A';
    
    final double tempLocal = double.tryParse(item['temp']?.toString() ?? '0') ?? 0.0;
    final double tempGlobal = double.tryParse(item['temp_global']?.toString() ?? '0') ?? 0.0;
    
    final double humLocal = double.tryParse(item['humidity']?.toString() ?? '0') ?? 0.0;
    final double humGlobal = double.tryParse(item['humidity_global']?.toString() ?? '0') ?? 0.0;
    
    final double windLocal = double.tryParse(item['wind_speed']?.toString() ?? '0') ?? 0.0;
    final double windGlobal = double.tryParse(item['wind_speed_global']?.toString() ?? '0') ?? 0.0;
    
    final double presLocal = double.tryParse(item['pressure']?.toString() ?? '0') ?? 0.0;
    final double presGlobal = double.tryParse(item['pressure_global']?.toString() ?? '0') ?? 0.0;
    
    final double rainProb = double.tryParse(item['rain_prob']?.toString() ?? '0') ?? 0.0;
    final double dewPoint = double.tryParse(item['dew_point']?.toString() ?? '0') ?? 0.0;
    final double dewPointDep = double.tryParse(item['dew_point_depression']?.toString() ?? '0') ?? 0.0;
    final double presChange = double.tryParse(item['pressure_change_3h']?.toString() ?? '0') ?? 0.0;

    final cardBgColor = isDarkMode
        ? const Color(0xFF182A3A).withOpacity(0.65)
        : Colors.white.withOpacity(0.85);
    final textCol = isDarkMode ? Colors.white : Colors.black87;
    final subTextCol = isDarkMode ? Colors.white60 : Colors.black54;
    final borderCol = isDarkMode ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                displayTime,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  condition,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${tempLocal.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Global: ${tempGlobal.toStringAsFixed(1)}°C',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextCol,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: borderCol, height: 1),
          const SizedBox(height: 16),
          _buildDetailRow(Icons.water_drop, 'Humidity', '${humLocal.toStringAsFixed(1)}%', 'Global: ${humGlobal.toStringAsFixed(0)}%', isDarkMode),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.air, 'Wind Speed', '${windLocal.toStringAsFixed(1)} m/s', 'Global: ${windGlobal.toStringAsFixed(1)}', isDarkMode),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.speed, 'Pressure', '${presLocal.toStringAsFixed(1)} hPa', 'Global: ${presGlobal.toStringAsFixed(0)}', isDarkMode),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.umbrella, 'Rain Prob.', '${rainProb.toStringAsFixed(0)}%', '', isDarkMode),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.thermostat, 'Dew Point', '${dewPoint.toStringAsFixed(1)}°C', 'Depr: ${dewPointDep.toStringAsFixed(1)}°C', isDarkMode),
          const SizedBox(height: 8),
          _buildDetailRow(Icons.trending_up, 'Pres. Change', '${presChange >= 0 ? '+' : ''}${presChange.toStringAsFixed(2)} hPa', '', isDarkMode),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, String subValue, bool isDarkMode) {
    final textCol = isDarkMode ? Colors.white: Colors.black87;
    final subTextCol = isDarkMode ? Colors.white60 : Colors.black54;

    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueAccent.withOpacity(0.8)),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: subTextCol,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
              if (subValue.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  subValue,
                  style: TextStyle(
                    fontSize: 10,
                    color: subTextCol,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableCell(
    String text,
    bool isDarkMode, {
    bool isHeader = false,
    bool isIcon = false,
    double trendValue = 0.0,
  }) {
    if (isIcon) {
      IconData icon;
      Color iconColor;

      if (trendValue > 0.1) {
        icon = Icons.arrow_upward;
        iconColor = Colors.green; // increase
      } else if (trendValue < -0.1) {
        icon = Icons.arrow_downward;
        iconColor = Colors.red; // decrease
      } else {
        icon = Icons.remove; // no change
        iconColor = isDarkMode ? Colors.white : Colors.black;
      }

      return Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: iconColor),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  List<NowcastData> _getHistoricalData() {
    switch (_selectedParameter) {
      case 'Temperature':
        return _historicalTemperature;
      case 'Pressure':
        return _historicalPressure;
      case 'Humidity':
        return _historicalHumidity;
      case 'Wind Speed':
        return _historicalWind;
      case 'Rain Probability':
        return []; // No historical data for rain probability
      default:
        return [];
    }
  }

  List<NowcastData> _getForecastData() {
    switch (_selectedParameter) {
      case 'Temperature':
        return _forecastTemperature;
      case 'Pressure':
        return _forecastPressure;
      case 'Humidity':
        return _forecastHumidity;
      case 'Wind Speed':
        return _forecastWind;
      case 'Rain Probability':
        return _forecastRainProb;
      default:
        return [];
    }
  }

  String _getUnit() {
    switch (_selectedParameter) {
      case 'Temperature':
        return '°C';
      case 'Pressure':
        return 'hPa';
      case 'Humidity':
        return '%';
      case 'Wind Speed':
        return 'm/s';
      case 'Rain Probability':
        return '%';
      default:
        return '';
    }
  }
}

// Sun Rays Painter
class SunRaysPainter extends CustomPainter {
  final double animation;
  SunRaysPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.yellow.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width * 0.8, size.height * 0.2);

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30 + animation * 360) * math.pi / 180;
      final path = Path();
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + math.cos(angle) * 100,
        center.dy + math.sin(angle) * 100,
      );
      path.lineTo(
        center.dx + math.cos(angle + 0.1) * 100,
        center.dy + math.sin(angle + 0.1) * 100,
      );
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SunRaysPainter oldDelegate) => true;
}

// Rain Painter
class RainPainter extends CustomPainter {
  final double animation;
  final bool isHeavy;
  RainPainter(this.animation, {this.isHeavy = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.4)
      ..strokeWidth = isHeavy ? 3 : 2
      ..strokeCap = StrokeCap.round;

    final dropCount = isHeavy ? 80 : 50;
    final random = math.Random(42);

    for (int i = 0; i < dropCount; i++) {
      final x = random.nextDouble() * size.width;
      final baseY = random.nextDouble() * size.height;
      final speed = random.nextDouble() * 0.5 + 0.5;
      final y = (baseY + animation * size.height * speed) % size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x - 5, y + (isHeavy ? 20 : 15)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(RainPainter oldDelegate) => true;
}

// Clouds Painter
class CloudsPainter extends CustomPainter {
  final double animation;
  CloudsPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    // Draw multiple clouds
    _drawCloud(canvas, size, paint,
        Offset((animation * size.width) % (size.width + 200) - 100, 40), 80);
    _drawCloud(
        canvas,
        size,
        paint,
        Offset(
            ((animation * 0.7) * size.width) % (size.width + 200) - 100, 100),
        60);
    _drawCloud(
        canvas,
        size,
        paint,
        Offset(((animation * 1.3) * size.width) % (size.width + 200) - 100, 70),
        70);
  }

  void _drawCloud(
      Canvas canvas, Size size, Paint paint, Offset position, double scale) {
    canvas.drawCircle(position, scale * 0.5, paint);
    canvas.drawCircle(position.translate(scale * 0.4, 0), scale * 0.6, paint);
    canvas.drawCircle(position.translate(scale * 0.8, 0), scale * 0.5, paint);
    canvas.drawCircle(
        position.translate(scale * 0.4, -scale * 0.2), scale * 0.4, paint);
  }

  @override
  bool shouldRepaint(CloudsPainter oldDelegate) => true;
}

// Fog Painter
class FogPainter extends CustomPainter {
  final double animation;
  FogPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final paint2 = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    // Multiple fog layers moving at different speeds
    final offset1 = (animation * size.width * 0.5) % size.width;
    final offset2 = (animation * size.width * 0.3) % size.width;

    // First fog layer
    final path1 = Path();
    path1.moveTo(-100 + offset1, size.height * 0.3);
    for (double i = -100 + offset1; i < size.width + 100; i += 50) {
      path1.lineTo(i, size.height * 0.3 + math.sin(i / 50) * 20);
    }
    path1.lineTo(size.width + 100, size.height * 0.5);
    path1.lineTo(-100 + offset1, size.height * 0.5);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Second fog layer
    final path2 = Path();
    path2.moveTo(-100 + offset2, size.height * 0.5);
    for (double i = -100 + offset2; i < size.width + 100; i += 50) {
      path2.lineTo(i, size.height * 0.5 + math.sin(i / 40) * 15);
    }
    path2.lineTo(size.width + 100, size.height * 0.7);
    path2.lineTo(-100 + offset2, size.height * 0.7);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(FogPainter oldDelegate) => true;
}

// Landscape Painter
class LandscapePainter extends CustomPainter {
  final bool isDay;
  final bool isRainy;
  final bool isDrizzle;

  LandscapePainter(
      {required this.isDay, this.isRainy = false, this.isDrizzle = false});

  @override
  void paint(Canvas canvas, Size size) {
    // Ground - slightly different color for drizzle
    final groundPaint = Paint()
      ..color = isDrizzle
          ? Color(0xFF6B8E6B)
          : (isRainy ? Color(0xFF4A6741) : Color(0xFF7CB342))
      ..style = PaintingStyle.fill;

    final groundPath = Path();
    groundPath.moveTo(0, size.height * 0.4);
    groundPath.lineTo(0, size.height);
    groundPath.lineTo(size.width, size.height);
    groundPath.lineTo(size.width, size.height * 0.4);
    for (double i = size.width; i >= 0; i -= 30) {
      groundPath.lineTo(i, size.height * 0.4 + math.sin(i / 20) * 5);
    }
    groundPath.close();
    canvas.drawPath(groundPath, groundPaint);

    // Hills in background
    _drawHill(canvas, size, Offset(size.width * 0.2, size.height * 0.5), 100,
        60, Color(0xFF8BC34A).withOpacity(0.7));
    _drawHill(canvas, size, Offset(size.width * 0.7, size.height * 0.5), 120,
        70, Color(0xFF9CCC65).withOpacity(0.7));

    // Trees
    _drawTree(canvas, size.width * 0.15, size.height * 0.45, 35);
    _drawTree(canvas, size.width * 0.4, size.height * 0.48, 30);
    _drawTree(canvas, size.width * 0.85, size.height * 0.47, 32);

    // House
    _drawHouse(canvas, size.width * 0.6, size.height * 0.5);
  }

  void _drawHill(Canvas canvas, Size size, Offset center, double width,
      double height, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx - width, center.dy);
    path.quadraticBezierTo(
        center.dx, center.dy - height, center.dx + width, center.dy);
    path.lineTo(center.dx + width, size.height);
    path.lineTo(center.dx - width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTree(Canvas canvas, double x, double y, double size) {
    // Trunk
    final trunkPaint = Paint()..color = Color(0xFF6D4C41);
    canvas.drawRect(
      Rect.fromLTWH(x - size * 0.1, y, size * 0.2, size * 0.4),
      trunkPaint,
    );

    // Leaves
    final leavesPaint = Paint()..color = Color(0xFF2E7D32);
    canvas.drawCircle(Offset(x, y - size * 0.1), size * 0.3, leavesPaint);
    canvas.drawCircle(Offset(x - size * 0.2, y), size * 0.25, leavesPaint);
    canvas.drawCircle(Offset(x + size * 0.2, y), size * 0.25, leavesPaint);
  }

  void _drawHouse(Canvas canvas, double x, double y) {
    // House body
    final bodyPaint = Paint()..color = Color(0xFFFFEBEE);
    canvas.drawRect(
      Rect.fromLTWH(x, y, 40, 30),
      bodyPaint,
    );

    // Roof
    final roofPaint = Paint()..color = Color(0xFFD32F2F);
    final roofPath = Path();
    roofPath.moveTo(x - 5, y);
    roofPath.lineTo(x + 20, y - 15);
    roofPath.lineTo(x + 45, y);
    roofPath.close();
    canvas.drawPath(roofPath, roofPaint);

    // Door
    final doorPaint = Paint()..color = Color(0xFF5D4037);
    canvas.drawRect(
      Rect.fromLTWH(x + 15, y + 15, 10, 15),
      doorPaint,
    );

    // Window
    final windowPaint = Paint()..color = Color(0xFF81D4FA);
    canvas.drawRect(
      Rect.fromLTWH(x + 5, y + 8, 8, 8),
      windowPaint,
    );
  }

  @override
  bool shouldRepaint(LandscapePainter oldDelegate) => false;
}

String _formatCondition(String raw) {
  final upper = raw.trim().toUpperCase();

  if (upper.contains('CLEAR_DAY') ||
      upper.contains('CLEAR_NIGHT') ||
      upper == 'CLEAR') {
    return 'Clear';
  }
  if (upper.contains('DRIZZLE')) {
    return 'Drizzle';
  }
  if (upper.contains('CLOUDY') ||
      upper.contains('PARTLY_CLOUDY') ||
      upper.contains('MOSTLY_CLOUDY') ||
      upper.contains('OVERCAST')) {
    return 'Cloudy';
  }
  if (upper.contains('FOG') ||
      upper.contains('HAZE') ||
      upper.contains('MIST')) {
    return 'Foggy';
  }
  if (upper.contains('RAIN') ||
      upper.contains('SHOWER') ||
      upper.contains('PRECIP')) {
    return 'Rainy';
  }
  if (upper.contains('THUNDER') || upper.contains('STORM')) {
    return 'Thunderstorm';
  }
  if (upper.contains('SNOW') || upper.contains('FLURRIES')) {
    return 'Snowy';
  }
  if (upper.contains('WINDY') || upper.contains('BREEZY')) {
    return 'Windy';
  }

  return raw
      .trim()
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

class NowcastData {
  final DateTime time;
  final double value;
  NowcastData(this.time, this.value);
}
