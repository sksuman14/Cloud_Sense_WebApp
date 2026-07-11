import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

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
  String _currentCondition = '';
  List<String> _hourlyConditions = [];

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
  }

  @override
  void dispose() {
    _sunController.dispose();
    _cloudController.dispose();
    super.dispose();
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

    final url =
        'https://d3g5fo66jwc4iw.cloudfront.net/campusdata?deviceid=1&startdate=${DateFormat('dd-MM-yyyy').format(startOfDay)}&enddate=${DateFormat('dd-MM-yyyy').format(now)}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return;

    final data = json.decode(response.body);
    final items = (data['items'] as List?) ?? [];
    if (items.isEmpty) return;

    // Parse all readings
    final List<NowcastData> allTemp = [];
    final List<NowcastData> allPres = [];
    final List<NowcastData> allHum = [];
    final List<NowcastData> allWind = [];
    final List<NowcastData> allRain = [];

    for (final item in items) {
      final ts = DateTime.parse(item['TimeStamp']);
      if (ts.isBefore(startOfDay)) continue;

      final temp = (item['CurrentTemperature'] as num?)?.toDouble() ?? 0.0;
      final pres = (item['AtmPressure'] as num?)?.toDouble() ?? 0.0;
      final hum = (item['CurrentHumidity'] as num?)?.toDouble() ?? 0.0;
      final wind = (item['WindSpeed'] as num?)?.toDouble() ?? 0.0;
      final rain = (item['RainfallHourly'] as num?)?.toDouble() ?? 0.0;

      allTemp.add(NowcastData(ts, temp));
      allPres.add(NowcastData(ts, pres));
      allHum.add(NowcastData(ts, hum));
      allWind.add(NowcastData(ts, wind / 3.6)); // already in m/s
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
        'https://fpoc1yed39.execute-api.us-east-1.amazonaws.com/prod/forecast';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final forecastItems = data['data'] as List<dynamic>;

      List<NowcastData> tempData = [],
          pressureData = [],
          humidityData = [],
          windData = [],
          rainData = [];

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
            timestamp, (item['temp'] as num).toDouble().roundToDouble()));
        pressureData.add(NowcastData(
            timestamp, (item['pressure'] as num).toDouble().roundToDouble()));
        humidityData.add(NowcastData(
            timestamp, (item['humidity'] as num).toDouble().roundToDouble()));

        final windKmh = (item['wind_speed'] as num).toDouble();
        final windMs = windKmh / 3.6;
        windData.add(NowcastData(timestamp, windMs));

        rainData.add(NowcastData(
            timestamp, (item['rain'] as num).toDouble().roundToDouble()));

        if (i < 4) {
          final timeLabel =
              i == 0 ? 'Now' : DateFormat('h a').format(timestamp);

          shortTemp.add(NowcastData(
              timestamp, (item['temp'] as num).toDouble().roundToDouble()));

          final dewPoint = (item['dew_point'] as num?)?.toDouble() ?? 0.0;
          _shortForecastDewPoint.add(dewPoint.roundToDouble());

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
          _forecastTemperature = tempData;
          _forecastPressure = pressureData;
          _forecastHumidity = humidityData;
          _forecastWind = windData;
          _forecastRain = rainData;
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
      drawer: isMobile ? _buildDrawer(isDarkMode) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(isDarkMode, 280.0),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          Color.fromARGB(255, 192, 185, 185),
                          Color.fromARGB(255, 123, 159, 174)
                        ]
                      : [
                          Color.fromARGB(255, 126, 171, 166),
                          Color.fromARGB(255, 54, 58, 59)
                        ],
                ),
              ),
              child: _isLoading
                  ? _buildLoadingState(isDarkMode)
                  : _historicalTemperature.isEmpty
                      ? _buildEmptyState(isDarkMode)
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(16),
                          child: Column(children: [
                            _buildWeatherHeader(isDarkMode, isMobile),
                            const SizedBox(height: 24),
                            _buildShortHourlyOverview(isDarkMode),
                            const SizedBox(height: 24),
                            _buildNowcastChart(isDarkMode),
                            SizedBox(height: 20),
                            _buildForecastTable(isDarkMode)
                          ])),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDarkMode, bool isMobile) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
      leading: isMobile
          ? IconButton(
              icon: Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer())
          : IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weather Nowcasting',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text('${widget.sequentialName} (${widget.deviceName})',
              style: TextStyle(fontSize: 12)),
        ],
      ),
      actions: [
        IconButton(
            icon: Icon(Icons.refresh), onPressed: _loadData, tooltip: 'Refresh')
      ],
    );
  }

  Widget _buildWeatherHeader(bool isDarkMode, bool isMobile) {
    if (_historicalTemperature.isEmpty) return SizedBox.shrink();

    final temp = _historicalTemperature.last.value.toInt();
    final humidity = _historicalHumidity.last.value.toInt();
    final isDay = DateTime.now().hour >= 6 && DateTime.now().hour < 18;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Color.fromARGB(150, 0, 0, 0)
            : Color.fromARGB(173, 227, 220, 220),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated Weather Background
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: _buildAnimatedWeatherBackground(isDay),
            ),
          ),

          // Main Content
          Column(
            children: [
              // Weather icon with animation
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_currentCondition.contains('Clear') && isDay)
                    AnimatedBuilder(
                      animation: _sunController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _sunController.value * 2 * math.pi,
                          child: child,
                        );
                      },
                      child: Icon(Icons.wb_sunny,
                          size: 100, color: Color(0xFFFFD700)),
                    )
                  else if (_currentCondition.contains('Clear') && !isDay)
                    Icon(Icons.nightlight_round,
                        size: 100, color: Color(0xFFFFA726))
                  else if (_currentCondition.contains('Cloudy'))
                    AnimatedBuilder(
                      animation: _cloudController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_cloudController.value * 10 - 5, 0),
                          child: child,
                        );
                      },
                      child:
                          Icon(Icons.cloud, size: 100, color: Colors.white70),
                    )
                  else if (_currentCondition.contains('Rain'))
                    Icon(Icons.water_drop, size: 100, color: Color(0xFF29b6f6))
                  else if (_currentCondition.contains('Drizzle'))
                    _buildDrizzleIcon()
                  else
                    Icon(Icons.wb_cloudy, size: 100, color: Colors.white70),
                ],
              ),

              SizedBox(height: 16),

              // Temperature
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$temp',
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                      height: 1,
                    ),
                  ),
                  Text(
                    '°C',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w300,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),

              SizedBox(height: 8),

              // Condition
              Text(
                _currentCondition,
                style: TextStyle(
                  fontSize: 24,
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),

              SizedBox(height: 24),

              // Weather stats row
              Wrap(
                spacing: 20,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildWeatherStat(
                    Icons.water_drop,
                    'Humidity',
                    '$humidity %',
                    Colors.blue[300]!,
                    isDarkMode,
                  ),
                  _buildWeatherStat(
                      Icons.speed,
                      'Pressure',
                      '${_historicalPressure.last.value.toInt()} hPa',
                      Colors.purple[300]!,
                      isDarkMode),
                  _buildWeatherStat(
                      Icons.air,
                      'Wind',
                      '${_historicalWind.last.value.toStringAsFixed(2)} m/s',
                      Colors.teal[300]!,
                      isDarkMode),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Custom drizzle icon - sun behind cloud with drops below
  Widget _buildDrizzleIcon() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          // Sun in the back
          Positioned(
            top: 10,
            right: 15,
            child: Icon(
              Icons.wb_sunny,
              size: 45,
              color: Color(0xFFFFD700),
            ),
          ),
          // Cloud in front
          Positioned(
            top: 15,
            left: 10,
            child: Icon(
              Icons.cloud,
              size: 70,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          // Small water drops below cloud
          Positioned(
            bottom: 15,
            left: 20,
            child: Icon(
              Icons.water_drop,
              size: 12,
              color: Color(0xFF64B5F6),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 35,
            child: Icon(
              Icons.water_drop,
              size: 10,
              color: Color(0xFF64B5F6),
            ),
          ),
          Positioned(
            bottom: 18,
            left: 48,
            child: Icon(
              Icons.water_drop,
              size: 11,
              color: Color(0xFF64B5F6),
            ),
          ),
        ],
      ),
    );
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
                      Color(0xFF87CEEB),
                      Color(0xFFB0E0E6),
                    ]
                  : [
                      Color(0xFF191970),
                      Color(0xFF483D8B),
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
                Color(0xFF9DB4C0),
                Color(0xFFB8C5D0),
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
                Color(0xFF6C7A89),
                Color(0xFF95A5A6),
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
                Color(0xFFB0C4DE),
                Color(0xFFD3D3D3),
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
                Color(0xFF2C3E50),
                Color(0xFF34495E),
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
            return SizedBox.shrink();
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
                Color(0xFFCCCCCC),
                Color(0xFFE0E0E0),
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
    return CustomPaint(
      painter: LandscapePainter(
          isDay: isDay, isRainy: isRainy, isDrizzle: isDrizzle),
      size: Size.infinite,
    );
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
                        initialVisibleMinimum:
                            DateTime.now().subtract(const Duration(hours: 24)),
                        initialVisibleMaximum:
                            DateTime.now().add(const Duration(hours: 4)),
                        interval: 2,
                        intervalType: DateTimeIntervalType.hours,
                        majorGridLines: MajorGridLines(
                            width: 0.5, color: Colors.grey.withOpacity(0.3)),
                        minorGridLines: MinorGridLines(width: 0),
                        majorTickLines: MajorTickLines(size: 0),
                        minorTickLines: MinorTickLines(size: 0),
                      ),
                      primaryYAxis: NumericAxis(
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
                    _buildTableCell('${data.value.toInt()} $unit', isDarkMode),
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
      case 'Rainfall':
        return _historicalRain;
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
      case 'Rainfall':
        return _forecastRain;
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
      case 'Rainfall':
        return 'mm';
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
