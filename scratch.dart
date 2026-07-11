import 'dart:convert';
import 'dart:io';

void main() async {
  try {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];

    print("Fetching...");
    // Just fetch using HttpClient
    final client = HttpClient();
    List<dynamic> allDevices = [];
    
    for (var url in urls) {
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final data = json.decode(body);
      final devices = data['devices'] as List<dynamic>?;
      if (devices != null) {
        allDevices.addAll(devices);
      }
    }
    print("Total devices fetched: ${allDevices.length}");

    for (var device in allDevices) {
      final deviceIdTopic =
          (device['deviceid#topic'] ?? device['deviceId#topic'] ?? '')
              .toString();
      if (deviceIdTopic.isEmpty) continue;

      final parts = deviceIdTopic.split('#');
      if (parts.isEmpty) continue;

      final deviceId = parts[0];
      final topic = parts.length > 1 ? parts.sublist(1).join('#') : '';

      if (topic.startsWith('BF/') || topic.startsWith('CS/')) continue;

      // test lat/lon parsing
      double? lat;
      try {
        lat = (device['LastKnownLatitude'] ?? device['Latitude'] ?? 0).toDouble();
      } catch (e) {
        print("Error parsing Latitude for device $deviceIdTopic: $e. Value: ${device['Latitude']} (${device['Latitude'].runtimeType})");
        return; // stop and report
      }
    }
    
    print("Parsed all latitudes successfully!");
  } catch (e, st) {
    print("Error: $e");
    print(st);
  }
}
