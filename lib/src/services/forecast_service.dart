import 'dart:convert';
import 'package:http/http.dart' as http;

class ForecastService {
  static const String _baseUrl =
      'https://5jsrn9r97j.execute-api.us-east-1.amazonaws.com/live-forecast';

  /// Fetches the 48-hour forecast and returns a map with:
  ///   - "hourly": List of hourly items, each with "timestamp" and "temperature"
  ///   - "daily":  List of daily summaries, each with "date", "temp_min", "temp_max"
  Future<Map<String, dynamic>> fetchForecast() async {
    final response = await http
        .get(Uri.parse(_baseUrl))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw Exception(
          'Forecast API error: ${response.statusCode} ${response.body}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['status'] != 'success') {
      throw Exception('Forecast API returned non-success status: $json');
    }

    final rawList = (json['forecast'] as List<dynamic>);

    // ── Build hourly list ────────────────────────────────────────────────────
    final hourly = rawList.map<Map<String, dynamic>>((item) {
      return {
        // "DateTime": "2026-03-06 04:00:00"  →  ISO-8601 for DateTime.tryParse
        'timestamp': (item['DateTime'] as String).replaceFirst(' ', 'T'),
        'temperature': (item['Corrected_Temp'] as num).toDouble(),
      };
    }).toList();

    // ── Build daily summaries from the hourly data ───────────────────────────
    final Map<String, List<double>> byDay = {};
    for (final h in hourly) {
      final dayKey =
          (h['timestamp'] as String).substring(0, 10); // "2026-03-06"
      byDay.putIfAbsent(dayKey, () => []);
      byDay[dayKey]!.add(h['temperature'] as double);
    }

    final daily = byDay.entries.map<Map<String, dynamic>>((e) {
      final temps = e.value;
      final tMin = temps.reduce((a, b) => a < b ? a : b);
      final tMax = temps.reduce((a, b) => a > b ? a : b);
      return {
        'date': e.key,
        'temp_min': double.parse(tMin.toStringAsFixed(1)),
        'temp_max': double.parse(tMax.toStringAsFixed(1)),
      };
    }).toList()
      ..sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    return {
      'hourly': hourly,
      'daily': daily,
    };
  }
}
