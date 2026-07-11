import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/forecast_service.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/src/views/home/home_page.dart'; // for ThemeProvider

// ─── Theme Model ──────────────────────────────────────────────────────────────
class _AppTheme extends ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  static const _darkBg = Color(0xFF0B141D);
  static const _darkCard = Color(0xFF1D2B38);
  static const _darkGradStart = Color(0xFF14212B);
  static const _darkGradEnd = Color(0xFF0B141D);
  static const _darkTextPrimary = Color(0xFFEEF2FF);
  static const _darkTextSecondary = Color(0xFF8899BB);

  static const _lightBg = Color(0xFFF0F4FF);
  static const _lightCard = Color(0xFFFFFFFF);
  static const _lightGradStart = Color(0xFFBDD8F5);
  static const _lightGradEnd = Color(0xFFF0F4FF);
  static const _lightTextPrimary = Color(0xFF0D1B2A);
  static const _lightTextSecondary = Color(0xFF5A6A85);

  static const accent = Color(0xFF4FC3F7);
  static const accentWarm = Color(0xFFFFB347);
  static const accentSensor = Color(0xFF69F0AE);

  Color get bg => _isDark ? _darkBg : _lightBg;
  Color get card => _isDark ? _darkCard : _lightCard;
  Color get gradStart => _isDark ? _darkGradStart : _lightGradStart;
  Color get gradEnd => _isDark ? _darkGradEnd : _lightGradEnd;
  Color get textPrimary => _isDark ? _darkTextPrimary : _lightTextPrimary;
  Color get textSecondary => _isDark ? _darkTextSecondary : _lightTextSecondary;
  Color get gridColor =>
      _isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.07);
  Color get cardBorder =>
      _isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.06);
  Color get highlightGrad1 =>
      _isDark ? const Color(0xFF14212B) : const Color(0xFFDCEEFD);
  Color get highlightGrad2 =>
      _isDark ? const Color(0xFF0B141D) : const Color(0xFFF5FAFF);
  Color get todayCard =>
      _isDark ? const Color(0xFF1A3040) : const Color(0xFFE8F4FD);
  Color get scaffoldShadow =>
      _isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08);
}

// ─── Sensor Data Service ──────────────────────────────────────────────────────
class SensorDataService {
  static const String _baseUrl =
      'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data';

  // Exact field names from the API:
  // {"TimeStamp":..., "CurrentTemperature":19, "Latitude":30.740307, "Longitude":76.730514, ...}
  static const String _tsField = 'TimeStamp';
  static const String _tempField = 'CurrentTemperature';

  /// Returns:
  ///   'hourly'  → List<Map> hourly-bucketed temps for the graph
  ///   'location'→ String  "City, State" from Nominatim reverse geocode
  ///   'latest'  → double? most recent CurrentTemperature (for the big card)
  Future<Map<String, dynamic>> fetchSensorDataWithLocation({
    required String deviceId,
    required String startDate,
    required String endDate,
  }) async {
    final uri = Uri.parse(
        '$_baseUrl?deviceid=$deviceId&startdate=$startDate&enddate=$endDate');

    final response =
        await http.get(uri, headers: {'Accept': 'application/json'});

    debugPrint('[SensorAPI] status=${response.statusCode}');
    if (response.body.length > 10) {
      debugPrint(
          '[SensorAPI] sample=${response.body.substring(0, math.min(300, response.body.length))}');
    }

    if (response.statusCode != 200) {
      throw Exception('Sensor API error: ${response.statusCode}');
    }

    final raw = jsonDecode(response.body);
    List<dynamic> records = _unwrap(raw);
    debugPrint('[SensorAPI] records found: ${records.length}');

    if (records.isEmpty) {
      return {
        'hourly': <Map<String, dynamic>>[],
        'location': '',
        'latest': null,
      };
    }

    if (records.first is Map) {
      debugPrint(
          '[SensorAPI] first record keys: ${(records.first as Map).keys.toList()}');
    }

    // ── Extract lat/long from first record for geocoding ─────────────────
    double? lat, lon;
    final first = records.first;
    if (first is Map) {
      for (final k in first.keys) {
        final kl = k.toString().toLowerCase();
        if (kl == 'latitude') lat = (first[k] as num?)?.toDouble();
        if (kl == 'longitude') lon = (first[k] as num?)?.toDouble();
      }
    }
    debugPrint('[SensorAPI] lat=$lat  lon=$lon');

    // ── Find the latest record by sorting on TimeStamp descending ─────────
    final sorted = List<dynamic>.from(records);
    sorted.sort((a, b) {
      if (a is! Map || b is! Map) return 0;
      final ta =
          DateTime.tryParse(a[_tsField]?.toString() ?? '') ?? DateTime(0);
      final tb =
          DateTime.tryParse(b[_tsField]?.toString() ?? '') ?? DateTime(0);
      return tb.compareTo(ta); // latest first
    });

    // Extract CurrentTemperature from the latest record
    double? latestTemp;
    final latestRecord = sorted.first;
    if (latestRecord is Map) {
      // Try exact field name first
      if (latestRecord.containsKey(_tempField) &&
          latestRecord[_tempField] != null) {
        final v = latestRecord[_tempField];
        latestTemp = v is num ? v.toDouble() : double.tryParse('$v');
      } else {
        // Case-insensitive fallback
        for (final k in latestRecord.keys) {
          final kl = k.toString().toLowerCase();
          if (kl == 'currenttemperature' ||
              kl == 'temperature' ||
              kl == 'temp') {
            final v = latestRecord[k];
            latestTemp = v is num ? v.toDouble() : double.tryParse('$v');
            break;
          }
        }
      }
    }
    debugPrint('[SensorAPI] latest CurrentTemperature: $latestTemp');

    // ── Reverse geocode ───────────────────────────────────────────────────
    String locationName = '';
    if (lat != null && lon != null) {
      locationName = await _reverseGeocode(lat, lon);
    }

    return {
      'hourly': _downsampleToHourly(records),
      'location': locationName,
      'latest': latestTemp,
    };
  }

  // ── Reverse geocode via OpenStreetMap Nominatim (no API key needed) ───────
  Future<String> _reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json');
      final res = await http.get(uri, headers: {
        'Accept': 'application/json',
        'User-Agent': 'CloudSenseApp/1.0',
      });
      if (res.statusCode != 200) return '';
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final address = json['address'] as Map<String, dynamic>?;
      if (address == null) return '';

      final city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['county'] ??
          '';
      final state = address['state'] ?? '';
      final parts = [city, state]
          .map((s) => s.toString())
          .where((s) => s.isNotEmpty)
          .toList();
      final result = parts.join(', ');
      debugPrint('[Geocode] resolved: $result');
      return result;
    } catch (e) {
      debugPrint('[Geocode] error: $e');
      return '';
    }
  }

  List<dynamic> _unwrap(dynamic raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in [
        'data',
        'items',
        'records',
        'results',
        'body',
        'payload'
      ]) {
        if (raw.containsKey(key)) {
          final val = raw[key];
          if (val is String) {
            try {
              return _unwrap(jsonDecode(val));
            } catch (_) {}
          }
          return _unwrap(val);
        }
      }
      final values = raw.values.toList();
      if (values.isNotEmpty && values.first is Map) return values;
    }
    return [];
  }

  List<Map<String, dynamic>> _downsampleToHourly(List<dynamic> records) {
    final Map<String, List<double>> buckets = {};

    for (final rec in records) {
      if (rec is! Map) continue;

      String tsRaw = '';
      if (rec.containsKey(_tsField) && rec[_tsField] != null) {
        tsRaw = rec[_tsField].toString();
      } else {
        for (final k in rec.keys) {
          final kl = k.toString().toLowerCase();
          if (kl == 'timestamp' ||
              kl == 'ts' ||
              kl == 'time' ||
              kl == 'datetime') {
            tsRaw = rec[k].toString();
            break;
          }
        }
      }

      double? tempVal;
      if (rec.containsKey(_tempField) && rec[_tempField] != null) {
        final v = rec[_tempField];
        tempVal = v is num ? v.toDouble() : double.tryParse('$v');
      } else {
        for (final k in rec.keys) {
          final kl = k.toString().toLowerCase();
          if (kl == 'currenttemperature' ||
              kl == 'temperature' ||
              kl == 'temp') {
            final v = rec[k];
            tempVal = v is num ? v.toDouble() : double.tryParse('$v');
            break;
          }
        }
      }

      if (tsRaw.isEmpty || tempVal == null) continue;
      if (tempVal < -50 || tempVal > 60) {
        debugPrint('[SensorAPI] Skipping out-of-range temp: $tempVal');
        continue;
      }

      final dt = DateTime.tryParse(tsRaw);
      if (dt == null) continue;

      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}';
      buckets.putIfAbsent(key, () => []).add(tempVal);
    }

    if (buckets.isEmpty) {
      debugPrint(
          '[SensorAPI] No buckets built — check field names in API response');
      return [];
    }

    final sortedKeys = buckets.keys.toList()..sort();
    debugPrint(
        '[SensorAPI] hourly buckets: ${sortedKeys.length}  keys=${sortedKeys.take(3)}');

    return sortedKeys.map((k) {
      final temps = buckets[k]!;
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      return {
        'timestamp': '${k.replaceAll('T', ' ')}:00:00',
        'temperature': double.parse(avg.toStringAsFixed(2)),
        'hour': int.parse(k.split('T')[1]),
      };
    }).toList();
  }
}

// ─── ForecastDashboard ────────────────────────────────────────────────────────
class ForecastDashboard extends StatefulWidget {
  final String deviceName;
  final String sequentialName;

  const ForecastDashboard({
    super.key,
    required this.deviceName,
    required this.sequentialName,
  });

  @override
  State<ForecastDashboard> createState() => _ForecastDashboardState();
}

class _ForecastDashboardState extends State<ForecastDashboard>
    with TickerProviderStateMixin {
  final ForecastService _service = ForecastService();
  final SensorDataService _sensorService = SensorDataService();
  late _AppTheme _theme;

  Map<String, dynamic>? data;
  List<Map<String, dynamic>> _sensorHourly = [];
  String _locationName = ''; // resolved from lat/long via Nominatim
  double? _sensorLatestTemp; // most recent CurrentTemperature from sensor API

  bool loading = true;
  bool _reloading = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final ScrollController _hourlyScrollController = ScrollController();
  double _scrollFraction = 0.0;
  double _totalScrollExtent = 1.0;

  static const double _cardWidth = 78;
  static const double _cardMargin = 10;
  static const double _scrollStep = (_cardWidth + _cardMargin) * 4;
  static const String _sensorDeviceId = '7';

  @override
  void initState() {
    super.initState();
    _theme = _AppTheme();
    _theme.addListener(() => setState(() {}));

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _hourlyScrollController.addListener(_onHourlyScroll);
    loadForecast();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final globalTheme = Provider.of<ThemeProvider>(context, listen: false);
    if (!mounted) return;
    if (_theme._isDark != globalTheme.isDarkMode) {
      _theme._isDark = globalTheme.isDarkMode;
      _theme.notifyListeners();
    }
  }

  void _onHourlyScroll() {
    if (!_hourlyScrollController.hasClients) return;
    final pos = _hourlyScrollController.position;
    if (pos.maxScrollExtent > 0) {
      setState(() {
        _scrollFraction = pos.pixels / pos.maxScrollExtent;
        _totalScrollExtent = pos.maxScrollExtent;
      });
    }
  }

  void _scrollLeft() {
    if (!_hourlyScrollController.hasClients) return;
    final target = (_hourlyScrollController.offset - _scrollStep)
        .clamp(0.0, _hourlyScrollController.position.maxScrollExtent);
    _hourlyScrollController.animateTo(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  void _scrollRight() {
    if (!_hourlyScrollController.hasClients) return;
    final target = (_hourlyScrollController.offset + _scrollStep)
        .clamp(0.0, _hourlyScrollController.position.maxScrollExtent);
    _hourlyScrollController.animateTo(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _theme.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _hourlyScrollController.dispose();
    super.dispose();
  }

  String _formatDateForSensorApi(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Future<void> loadForecast() async {
    setState(() {
      loading = data == null;
      _reloading = true;
    });
    _fadeController.reset();
    _slideController.reset();

    try {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final results = await Future.wait([
        _service.fetchForecast(),
        _sensorService
            .fetchSensorDataWithLocation(
          deviceId: _sensorDeviceId,
          startDate: _formatDateForSensorApi(now),
          endDate: _formatDateForSensorApi(tomorrow),
        )
            .catchError((e) {
          debugPrint('Sensor data error: $e');
          return <String, dynamic>{
            'hourly': <Map<String, dynamic>>[],
            'location': '',
            'latest': null,
          };
        }),
      ]);

      setState(() {
        data = results[0] as Map<String, dynamic>;
        final sensorResult = results[1] as Map<String, dynamic>;
        _sensorHourly = sensorResult['hourly'] as List<Map<String, dynamic>>;
        _locationName = sensorResult['location'] as String? ?? '';
        _sensorLatestTemp = sensorResult['latest'] as double?;
        loading = false;
        _reloading = false;
      });

      _fadeController.forward();
      _slideController.forward();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToNow(data!["hourly"] ?? []);
      });
    } catch (e) {
      debugPrint("Forecast error: $e");
      setState(() {
        loading = false;
        _reloading = false;
      });
    }
  }

  int _findNowIndex(List hourly) {
    final now = DateTime.now();
    for (int i = 0; i < hourly.length; i++) {
      final ts = hourly[i]["timestamp"] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      if (dt != null &&
          dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day &&
          dt.hour == now.hour) return i;
    }
    for (int i = 0; i < hourly.length; i++) {
      final ts = hourly[i]["timestamp"] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      if (dt != null && !dt.isBefore(DateTime.now())) return i;
    }
    return 0;
  }

  void _scrollToNow(List hourly) {
    final idx = _findNowIndex(hourly);
    if (idx <= 0) return;
    final screenWidth = WidgetsBinding
            .instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final offset = (idx * (_cardWidth + _cardMargin)) -
        (screenWidth / 2) +
        (_cardWidth / 2);
    if (_hourlyScrollController.hasClients) {
      _hourlyScrollController.animateTo(
        offset.clamp(0, double.infinity),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getWeatherEmoji(num temp) {
    if (temp >= 35) return '🌡';
    if (temp >= 28) return '☀️';
    if (temp >= 20) return '🌤';
    if (temp >= 12) return '⛅';
    return '🌥';
  }

  String _getDayLabel(String date) {
    final d = DateTime.tryParse(date);
    if (d == null) return date;
    final now = DateTime.now();
    final diff = d.difference(DateTime(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  List<double?> _alignSensorToForecast(List forecastHourly) {
    if (_sensorHourly.isEmpty) return List.filled(forecastHourly.length, null);
    final sensorMap = <String, double>{};
    for (final s in _sensorHourly) {
      final ts = s['timestamp'] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      if (dt == null) continue;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}';
      sensorMap[key] = (s['temperature'] as num).toDouble();
    }
    return forecastHourly.map<double?>((item) {
      final ts = item['timestamp'] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      if (dt == null) return null;
      final key =
          '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}T${dt.hour.toString().padLeft(2, '0')}';
      return sensorMap[key];
    }).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, globalTheme, _) {
        if (_theme._isDark != globalTheme.isDarkMode) {
          _theme._isDark = globalTheme.isDarkMode;
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          color: _theme.bg,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: loading
                ? _buildLoader()
                : data == null
                    ? _buildError()
                    : _buildContent(),
          ),
        );
      },
    );
  }

  Widget _buildLoader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _theme.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _AppTheme.accent, strokeWidth: 2),
            const SizedBox(height: 20),
            Text('Reading the skies...',
                style: TextStyle(
                    color: _theme.textSecondary,
                    fontSize: 14,
                    letterSpacing: 1.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: _theme.bg,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: _theme.textSecondary, size: 56),
            const SizedBox(height: 16),
            Text('Could not load forecast',
                style: TextStyle(color: _theme.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            TextButton(
                onPressed: loadForecast,
                child: Text('Try again',
                    style: TextStyle(color: _AppTheme.accent))),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final hourly = (data!["hourly"] ?? []) as List;
    final next48 = hourly.take(48).toList();
    final nowIndex = _findNowIndex(next48);
    final sensorAligned = _alignSensorToForecast(next48);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCurrentHighlight(next48, nowIndex),
                    const SizedBox(height: 32),
                    _buildSectionLabel('Temperature Graph — 48 Hours'),
                    const SizedBox(height: 14),
                    _buildTempGraph(next48, nowIndex, sensorAligned),
                    const SizedBox(height: 10),
                    _buildGraphLegend(),
                    const SizedBox(height: 32),
                    _buildSectionLabel('48-Hour Outlook'),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.swipe_rounded,
                              size: 13,
                              color: _theme.textSecondary.withOpacity(0.6)),
                          const SizedBox(width: 5),
                          Text('Swipe to see all 48 hours',
                              style: TextStyle(
                                  color: _theme.textSecondary.withOpacity(0.6),
                                  fontSize: 11,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    _buildHourlyScroll(next48, nowIndex),
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGraphLegend() {
    return Row(
      children: [
        _LegendDot(color: _AppTheme.accentSensor, label: 'Sensor (historical)'),
        const SizedBox(width: 20),
        _LegendDot(color: Colors.orange, label: 'Forecast'),
      ],
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar() {
    final String titleLabel = _locationName.isNotEmpty
        ? _locationName
        : widget.sequentialName.isNotEmpty
            ? widget.sequentialName
            : widget.deviceName.isNotEmpty
                ? widget.deviceName
                : 'Forecast';

    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 100,
      floating: false,
      pinned: true,
      // Title sits in the pinned toolbar — same row as the back arrow
      title: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_locationName.isNotEmpty) ...[
            Icon(Icons.location_on_rounded, color: _AppTheme.accent, size: 16),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              titleLabel,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  color: _theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: _reloading ? null : loadForecast,
            child: AnimatedRotation(
              turns: _reloading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 600),
              child: Icon(
                Icons.refresh_rounded,
                color: _reloading
                    ? _AppTheme.accent.withOpacity(0.4)
                    : _AppTheme.accent,
                size: 22,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_theme.gradStart, _theme.gradEnd],
            ),
          ),
        ),
      ),
    );
  }

  // ── Current Highlight ──────────────────────────────────────────────────────
  //
  // Temperature source priority:
  //   1. _sensorLatestTemp  → real CurrentTemperature from sensor API (most recent record)
  //   2. forecast hourly    → fallback if sensor data unavailable
  //
  Widget _buildCurrentHighlight(List next48, int nowIndex) {
    if (next48.isEmpty) return const SizedBox();

    final bool isFromSensor = _sensorLatestTemp != null;
    final num tempNum = isFromSensor
        ? _sensorLatestTemp!
        : (() {
            final v = (nowIndex < next48.length
                ? next48[nowIndex]
                : next48[0])["temperature"];
            return (v is num) ? v : 0;
          })();

    // Display string: sensor gives double so show 1 decimal; forecast may be int
    final String tempDisplay =
        isFromSensor ? tempNum.toStringAsFixed(1) : '$tempNum';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_theme.highlightGrad1, _theme.highlightGrad2],
        ),
        border: Border.all(color: _AppTheme.accent.withOpacity(0.15), width: 1),
        boxShadow: [
          BoxShadow(
              color: _AppTheme.accent.withOpacity(0.08),
              blurRadius: 40,
              spreadRadius: 0,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label row: title + source badge ─────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Current Temperature',
                style: TextStyle(
                    color: _AppTheme.accent.withOpacity(0.8),
                    fontSize: 26,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── Temperature value + °C + emoji all on ONE row ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _getWeatherEmoji(tempNum),
                style: const TextStyle(fontSize: 58),
              ),
              const SizedBox(width: 14),
              Text(
                tempDisplay,
                style: TextStyle(
                    color: _theme.textPrimary,
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '°C',
                  style: TextStyle(
                      color: _theme.textSecondary,
                      fontSize: 28,
                      fontWeight: FontWeight.w300),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Temperature Graph ──────────────────────────────────────────────────────

  Widget _buildTempGraph(
      List next48, int nowIndex, List<double?> sensorAligned) {
    final now = DateTime.now();

    final List<_ChartPoint> sensorPoints = [];
    for (final s in _sensorHourly) {
      final ts = s['timestamp'] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      final temp = s['temperature'];
      if (dt != null && temp != null) {
        sensorPoints.add(_ChartPoint(dt, (temp as num).toDouble()));
      }
    }
    debugPrint('[Graph] sensorPoints count: ${sensorPoints.length}');

    final List<_ChartPoint> forecastPoints = [];
    for (int i = nowIndex; i < next48.length; i++) {
      final v = next48[i]["temperature"];
      final ts = next48[i]["timestamp"] as String? ?? '';
      final dt = DateTime.tryParse(ts);
      if (dt != null) {
        forecastPoints.add(_ChartPoint(dt, (v is num) ? v.toDouble() : 0.0));
      }
    }

    final isDark = _theme.isDark;

    final xMin = sensorPoints.isNotEmpty
        ? sensorPoints.first.time
        : now.subtract(const Duration(hours: 6));
    final xMax = forecastPoints.isNotEmpty
        ? forecastPoints.last.time
        : now.add(const Duration(hours: 24));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: 280,
      decoration: BoxDecoration(
        color: _theme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _theme.cardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SfCartesianChart(
          backgroundColor: Colors.transparent,
          plotAreaBackgroundColor: Colors.transparent,
          plotAreaBorderWidth: 0,
          margin: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          primaryXAxis: DateTimeAxis(
            dateFormat: intl.DateFormat('HH:mm'),
            labelStyle: TextStyle(color: _theme.textSecondary, fontSize: 9),
            axisLine: AxisLine(width: 0),
            majorGridLines: MajorGridLines(width: 0.5, color: _theme.gridColor),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            edgeLabelPlacement: EdgeLabelPlacement.shift,
            interval: 4,
            intervalType: DateTimeIntervalType.hours,
            labelIntersectAction: AxisLabelIntersectAction.hide,
            labelRotation: 0,
            initialVisibleMinimum: xMin,
            initialVisibleMaximum: xMax,
          ),
          primaryYAxis: NumericAxis(
            labelStyle: TextStyle(color: _theme.textSecondary, fontSize: 9),
            axisLine: AxisLine(width: 0),
            majorGridLines: MajorGridLines(width: 0.5, color: _theme.gridColor),
            minorGridLines: MinorGridLines(width: 0),
            majorTickLines: MajorTickLines(size: 0),
            labelFormat: '{value}°',
          ),
          trackballBehavior: TrackballBehavior(
            enable: true,
            activationMode: ActivationMode.singleTap,
            lineType: TrackballLineType.vertical,
            lineColor: _AppTheme.accent.withOpacity(0.5),
            lineWidth: 1.2,
            markerSettings: const TrackballMarkerSettings(
              markerVisibility: TrackballVisibilityMode.visible,
              width: 8,
              height: 8,
              borderWidth: 2,
            ),
            builder: (BuildContext context, TrackballDetails details) {
              try {
                final time = details.point?.x as DateTime?;
                final value = details.point?.y as double?;
                if (time == null || value == null)
                  return const SizedBox.shrink();
                final isForecast = details.seriesIndex == 1;
                final tooltipBg =
                    isDark ? const Color(0xFF0E1829) : Colors.white;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: tooltipBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isForecast
                          ? Colors.orange.withOpacity(0.6)
                          : _AppTheme.accentSensor.withOpacity(0.6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2), blurRadius: 10),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        intl.DateFormat('MMM d  HH:mm').format(time),
                        style: TextStyle(
                            color: _theme.textSecondary, fontSize: 10),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${value.toStringAsFixed(1)} °C',
                        style: TextStyle(
                          color: isForecast
                              ? Colors.orange
                              : _AppTheme.accentSensor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isForecast ? 'Forecast' : 'Sensor',
                        style: TextStyle(
                          color: isForecast
                              ? Colors.orange
                              : _AppTheme.accentSensor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              } catch (_) {
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
          series: <CartesianSeries>[
            // Series 0: Sensor historical (green area)
            AreaSeries<_ChartPoint, DateTime>(
              name: 'Sensor',
              dataSource: sensorPoints,
              xValueMapper: (p, _) => p.time,
              yValueMapper: (p, _) => p.value,
              borderColor: _AppTheme.accentSensor,
              borderWidth: 2.8,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _AppTheme.accentSensor.withOpacity(0.35),
                  _AppTheme.accentSensor.withOpacity(0.04),
                ],
              ),
              markerSettings: const MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                width: 5,
                height: 5,
                borderWidth: 1.5,
                borderColor: _AppTheme.accentSensor,
                color: Colors.white,
              ),
            ),
            // Series 1: Forecast (dashed orange area)
            AreaSeries<_ChartPoint, DateTime>(
              name: 'Forecast',
              dataSource: forecastPoints,
              xValueMapper: (p, _) => p.time,
              yValueMapper: (p, _) => p.value,
              borderColor: Colors.orange,
              borderWidth: 2.8,
              dashArray: const <double>[6, 3],
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.orange.withOpacity(0.30),
                  Colors.orange.withOpacity(0.03),
                ],
              ),
              markerSettings: MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                width: 6,
                height: 6,
                borderWidth: 2,
                borderColor: Colors.orange[800]!,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String text) {
    return Row(
      children: [
        Container(
            width: 3,
            height: 18,
            decoration: BoxDecoration(
                color: _AppTheme.accent,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(text,
            style: TextStyle(
                color: _theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      ],
    );
  }

  // ── Hourly Scroll ──────────────────────────────────────────────────────────

  Widget _buildHourlyScroll(List next48, int nowIndex) {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: ListView.builder(
            controller: _hourlyScrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: next48.length,
            itemBuilder: (ctx, i) {
              final item = next48[i];
              final ts = item["timestamp"] as String? ?? '';
              final time = ts.length >= 16 ? ts.substring(11, 16) : '--:--';
              final temp = item["temperature"];
              final tempNum = (temp is num) ? temp : 20;
              final isNow = i == nowIndex;
              final isPast = i < nowIndex;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _cardWidth,
                margin: const EdgeInsets.only(right: _cardMargin),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                decoration: BoxDecoration(
                  color: isNow
                      ? _AppTheme.accent.withOpacity(0.18)
                      : isPast
                          ? _theme.card.withOpacity(0.4)
                          : _theme.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isNow
                        ? _AppTheme.accent.withOpacity(0.6)
                        : _theme.cardBorder,
                    width: isNow ? 1.5 : 1,
                  ),
                  boxShadow: isNow
                      ? [
                          BoxShadow(
                              color: _AppTheme.accent.withOpacity(0.22),
                              blurRadius: 14)
                        ]
                      : null,
                ),
                child: Opacity(
                  opacity: isPast ? 0.4 : 1.0,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                            color:
                                isNow ? _AppTheme.accent : _theme.textSecondary,
                            fontSize: 11,
                            fontWeight:
                                isNow ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.5),
                      ),
                      Text(_getWeatherEmoji(tempNum),
                          style: const TextStyle(fontSize: 18)),
                      Text('$temp°',
                          style: TextStyle(
                              color: _theme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildHourlyScrollbar(),
      ],
    );
  }

  Widget _buildHourlyScrollbar() {
    return LayoutBuilder(builder: (ctx, constraints) {
      const double arrowSize = 32;
      const double barH = 6.0;
      const double thumbMinW = 36.0;
      final double trackW = constraints.maxWidth - (arrowSize * 2) - 16;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ScrollArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: _scrollLeft,
            size: arrowSize,
            accent: _AppTheme.accent,
            textSecondary: _theme.textSecondary,
            isDark: _theme.isDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (!_hourlyScrollController.hasClients) return;
                final fraction = details.delta.dx / trackW;
                final newOffset = (_hourlyScrollController.offset +
                        fraction * _totalScrollExtent)
                    .clamp(
                        0.0, _hourlyScrollController.position.maxScrollExtent);
                _hourlyScrollController.jumpTo(newOffset);
              },
              onTapDown: (details) {
                if (!_hourlyScrollController.hasClients) return;
                final fraction =
                    (details.localPosition.dx - thumbMinW / 2) / trackW;
                final newOffset = (fraction * _totalScrollExtent)
                    .clamp(0.0, _totalScrollExtent);
                _hourlyScrollController.animateTo(newOffset,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
              },
              child: Container(
                height: barH + 16,
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: barH,
                      decoration: BoxDecoration(
                        color: _theme.card,
                        borderRadius: BorderRadius.circular(barH),
                        border: Border.all(color: _theme.cardBorder, width: 1),
                      ),
                    ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 50),
                      left: (_scrollFraction * (trackW - thumbMinW))
                          .clamp(0.0, trackW - thumbMinW),
                      top: 0,
                      child: Container(
                        width: thumbMinW,
                        height: barH,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _AppTheme.accent.withOpacity(0.9),
                              _AppTheme.accent.withOpacity(0.5),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(barH),
                          boxShadow: [
                            BoxShadow(
                                color: _AppTheme.accent.withOpacity(0.4),
                                blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ScrollArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: _scrollRight,
            size: arrowSize,
            accent: _AppTheme.accent,
            textSecondary: _theme.textSecondary,
            isDark: _theme.isDark,
          ),
        ],
      );
    });
  }

  // ── Daily List (kept for optional use) ────────────────────────────────────

  Widget _buildDailyList(List next7) {
    return Column(
      children: List.generate(next7.length, (i) {
        final day = next7[i];
        final label = _getDayLabel(day["date"] ?? '');
        final tMin = day["temp_min"];
        final tMax = day["temp_max"];
        final tMinNum = (tMin is num) ? tMin : 0;
        final tMaxNum = (tMax is num) ? tMax : 0;
        final isToday = i == 0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: isToday ? _theme.todayCard : _theme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isToday
                    ? _AppTheme.accentWarm.withOpacity(0.3)
                    : _theme.cardBorder,
                width: 1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(label,
                    style: TextStyle(
                        color:
                            isToday ? _AppTheme.accentWarm : _theme.textPrimary,
                        fontSize: 14,
                        fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w500)),
              ),
              Text(_getWeatherEmoji(tMaxNum),
                  style: const TextStyle(fontSize: 22)),
              const Spacer(),
              Text('$tMin°',
                  style: TextStyle(color: _theme.textSecondary, fontSize: 14)),
              const SizedBox(width: 8),
              _buildDayTempBar(tMinNum, tMaxNum),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('$tMax°',
                    style: TextStyle(
                        color: _theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDayTempBar(num tMin, num tMax) {
    return Container(
      width: 60,
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFFFFB347)],
        ),
      ),
    );
  }
}

// ─── Legend Dot ───────────────────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.85),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ─── Scroll Arrow Button ──────────────────────────────────────────────────────
class _ScrollArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color accent;
  final Color textSecondary;
  final bool isDark;

  const _ScrollArrowButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.accent,
    required this.textSecondary,
    required this.isDark,
  });

  @override
  State<_ScrollArrowButton> createState() => _ScrollArrowButtonState();
}

class _ScrollArrowButtonState extends State<_ScrollArrowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: _pressed
              ? widget.accent.withOpacity(0.25)
              : widget.isDark
                  ? const Color(0xFF1C2438)
                  : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _pressed
                ? widget.accent.withOpacity(0.6)
                : widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.08),
            width: 1,
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                      color: widget.accent.withOpacity(0.2), blurRadius: 8)
                ]
              : null,
        ),
        child: Icon(widget.icon,
            color: _pressed ? widget.accent : widget.textSecondary, size: 20),
      ),
    );
  }
}

// ─── Chart Data Point ─────────────────────────────────────────────────────────
class _ChartPoint {
  final DateTime time;
  final double value;
  const _ChartPoint(this.time, this.value);
}
