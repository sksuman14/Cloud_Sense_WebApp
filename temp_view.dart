Future<void> _updateNativeWidget() async {
    // Widget always independently finds the nearest device via GPS + API
    // It does NOT depend on the home screen's nearestDevice variable
    Map<String, dynamic>? widgetDeviceData;

    try {
      // Step 1: Get user's GPS location
      double userLat = 0, userLon = 0;

      if (kIsWeb) {
        final completer = Completer<Position>();
        html.window.navigator.geolocation.getCurrentPosition().then((pos) {
          final coords = pos.coords;
          completer.complete(Position(
            latitude: coords?.latitude?.toDouble() ?? 0,
            longitude: coords?.longitude?.toDouble() ?? 0,
            timestamp: DateTime.now(),
            accuracy: 0, altitude: 0, heading: 0, speed: 0,
            speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
          ));
        }).catchError((e) => completer.completeError("Location blocked"));
        final position = await completer.future;
        userLat = position.latitude;
        userLon = position.longitude;
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            debugPrint("Location permission denied for widget");
          }
        }
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        userLat = position.latitude;
        userLon = position.longitude;
      }

      // Step 2: Fetch devices from API
      final urls = [
        "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity",
        "https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api",
      ];
      final responses = await Future.wait(
        urls.map((url) => http.get(Uri.parse(url)).catchError((e) {
          debugPrint("Widget API error for $url: $e");
          return http.Response('{"devices":[]}', 500);
        })),
      );

      List<Map<String, dynamic>> allDevices = [];
      for (final response in responses) {
        if (response.statusCode != 200) continue;
        final data = json.decode(response.body);
        final List<dynamic>? devicesList = data["devices"];
        if (devicesList == null || devicesList.isEmpty) continue;
        allDevices.addAll(devicesList.cast<Map<String, dynamic>>());
      }

      // Step 3: Filter to today's devices
      DateTime today = DateTime.now();
      DateTime todayStart = DateTime(today.year, today.month, today.day);
      DateTime todayEnd = todayStart.add(const Duration(days: 1));

      List<Map<String, dynamic>> todaysDevices = [];
      for (var device in allDevices) {
        String ts = device["TimeStamp_IST"]?.toString().trim() ?? "";
        if (ts.isEmpty) continue;
        final formats = ["yyyy-MM-dd HH:mm:ss", "dd-MM-yyyy HH:mm:ss", "dd/MM/yyyy HH:mm:ss"];
        for (var fmt in formats) {
          try {
            DateTime parsedDate = DateFormat(fmt).parse(ts, false).toLocal();
            if (parsedDate.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                parsedDate.isBefore(todayEnd)) {
              todaysDevices.add(Map<String, dynamic>.from(device));
              break;
            }
          } catch (_) {}
        }
      }

      List<Map<String, dynamic>> candidates =
          todaysDevices.isNotEmpty ? todaysDevices : allDevices;

      // Step 4: Find nearest device by distance
      Map<String, dynamic>? nearest;
      double minDist = double.infinity;
      for (var device in candidates) {
        double lat = double.tryParse(device["Latitude"]?.toString() ?? "") ?? 0;
        double lon = double.tryParse(device["Longitude"]?.toString() ?? "") ?? 0;
        if (lat == 0 && lon == 0) continue;
        double dist = HomeUtils.calculateDistance(userLat, userLon, lat, lon);
        if (dist < minDist) {
          minDist = dist;
          nearest = Map<String, dynamic>.from(device);
        }
      }

      // Step 5: Use nearest device (or fallback to first available)
      widgetDeviceData = nearest ?? (allDevices.isNotEmpty ? allDevices.first : null);
      if (widgetDeviceData == null) return;

      // ─── Extract parameters ───────────────────────────────────────────
      final deviceId = HomeUtils.getDeviceIdFromTopic(widgetDeviceData["deviceid#topic"]?.toString()).isNotEmpty
          ? HomeUtils.getDeviceIdFromTopic(widgetDeviceData["deviceid#topic"]?.toString())
          : 'ANNAM001';

      double? temp;
      if (widgetDeviceData["CorrectedTemp"] != null && widgetDeviceData["CorrectedTemp"].toString().toLowerCase() != 'null') {
        temp = double.tryParse(widgetDeviceData["CorrectedTemp"].toString());
      } else if (widgetDeviceData["correctedtemp"] != null && widgetDeviceData["correctedtemp"].toString().toLowerCase() != 'null') {
        temp = double.tryParse(widgetDeviceData["correctedtemp"].toString());
      } else if (widgetDeviceData["CurrentTemperature"] != null && widgetDeviceData["CurrentTemperature"].toString().toLowerCase() != 'null') {
        temp = double.tryParse(widgetDeviceData["CurrentTemperature"].toString());
      } else if (widgetDeviceData["currenttemperature"] != null && widgetDeviceData["currenttemperature"].toString().toLowerCase() != 'null') {
        temp = double.tryParse(widgetDeviceData["currenttemperature"].toString());
      }

      double? windSpeed;
      if (widgetDeviceData["WindSpeed"] != null && widgetDeviceData["WindSpeed"].toString().toLowerCase() != 'null') {
        windSpeed = double.tryParse(widgetDeviceData["WindSpeed"].toString());
      } else if (widgetDeviceData["windspeed"] != null && widgetDeviceData["windspeed"].toString().toLowerCase() != 'null') {
        windSpeed = double.tryParse(widgetDeviceData["windspeed"].toString());
      }

      double? rainfall;
      if (widgetDeviceData["RainfallHourly"] != null && widgetDeviceData["RainfallHourly"].toString().toLowerCase() != 'null') {
        rainfall = double.tryParse(widgetDeviceData["RainfallHourly"].toString());
      } else if (widgetDeviceData["rainfallhourly"] != null && widgetDeviceData["rainfallhourly"].toString().toLowerCase() != 'null') {
        rainfall = double.tryParse(widgetDeviceData["rainfallhourly"].toString());
      } else if (widgetDeviceData["RainfallHourlyComulative"] != null && widgetDeviceData["RainfallHourlyComulative"].toString().toLowerCase() != 'null') {
        rainfall = double.tryParse(widgetDeviceData["RainfallHourlyComulative"].toString());
      }

      final isOnline = (widgetDeviceData['HealthStatus']?.toString().toLowerCase() ?? 'online') == 'online';
      final updatedTime = _formatUpdatedTime(widgetDeviceData?['TimeStamp_IST']?.toString());
      final location = HomeUtils.getFormattedLocation(widgetDeviceData);

      // ─── Send to native widget ──────────────────────────────────────────
      await _widgetChannel.invokeMethod('updateWidgetData', {
        'deviceId': deviceId,
        'temperature': temp != null ? temp : -999.0,
        'isOnline': isOnline,
        'updatedTime': updatedTime,
        'windSpeed': windSpeed != null ? windSpeed : -999.0,
        'rainfall': rainfall != null ? rainfall : -999.0,
        'location': location,
      });
      debugPrint("Widget updated (nearest independent): \$deviceId, temp=\${temp ?? 'N/A'}, wind=\${windSpeed ?? 'N/A'}, rain=\${rainfall ?? 'N/A'}, loc=\$location");
    } catch (e) {
      debugPrint("Error updating native widget: \$e");
    }
  }

  // ─── Premium Stats Banner (image-style) ──────────────────────────────────
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}