import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url =
      'https://5xvdaawgj3.execute-api.us-east-1.amazonaws.com/default/get_device_latest_health';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final List devices = data['devices'] ?? [];
    if (devices.isNotEmpty) {
      print('Keys in devices[0]: ${devices[0].keys.toList()}');
      print('Sample device[0]: ${devices[0]}');
    } else {
      print('No devices found in API response.');
    }
  } else {
    print('Error fetching data: ${response.statusCode}');
  }
}
