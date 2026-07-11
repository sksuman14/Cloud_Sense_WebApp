import 'dart:async';
import 'dart:convert';
import 'package:cloud_sense_webapp/src/views/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

enum MapType { defaultMap, satellite, terrain }

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  _MapPageState createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  LatLng centerCoordinates = LatLng(0, 0);
  double zoomLevel = 5.0;
  late MapController mapController;
  bool isLoading = false;
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  List<Map<String, dynamic>> deviceLocations = [];
  TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  List<Map<String, dynamic>> filteredDevices = [];
  List<Map<String, dynamic>> suggestions = [];
  Marker? searchPin;
  String? selectedDeviceIdr;
  DateTime? startDater;
  DateTime? endDater;
  bool isLoadingr = false;
  bool showCard = false;
  List<dynamic> filteredData = [];
  List<String> deviceIds = [];
  List<String> allDeviceIds = [];
  String? selectedDeviceId;
  DateTime? startDate;
  DateTime? endDate;
  DateTime? selectedDate;
  final DateFormat dateFormatter = DateFormat('dd-MM-yyyy');

  Map<String, Map<String, dynamic>> previousPositions = {};
  final double displacementThreshold = 100.0;
  final Distance distance = Distance();
  final int stationaryTimeThreshold = 10 * 60 * 1000;

  static const String POSITIONS_KEY = 'device_previous_positions';
  // -----  add near the other constants (around line 70) -----
  static const int NO_DATA_DAYS_THRESHOLD = 2; // >2 days → dark-red

  MapType currentMapType = MapType.defaultMap;

  // Timer? _autoReloadTimer;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _loadPreviousPositions();
    // Start auto-reload timer to refresh every 60 seconds
    // _startAutoReload();
  }

  // void _startAutoReload() {
  //   _autoReloadTimer = Timer.periodic(Duration(seconds: 60), (timer) {
  //     if (mounted) {
  //       _fetchDeviceLocations();
  //     }
  //   });
  // }

  @override
  void dispose() {
    // Cancel the auto-reload timer to prevent memory leaks
    // _autoReloadTimer?.cancel();
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

// -----  add a new private method (anywhere in the class) -----
  Color _markerColorForDevice(Map<String, dynamic> device) {
    final bool hasMoved = device['has_moved'] == true;
    final String lastActiveStr = device['last_active'] ?? '';

    // 1. No timestamp → treat as “no data”
    if (lastActiveStr.isEmpty) return Colors.red;

    try {
      // The API returns timestamps in UTC (e.g. "2025-11-04T12:34:56Z")
      final DateTime lastActiveUtc = DateTime.parse(lastActiveStr).toUtc();
      final DateTime nowUtc = DateTime.now().toUtc();

      final int daysSinceLast = nowUtc.difference(lastActiveUtc).inDays;

      // 2. >2 days without data → dark-red
      if (daysSinceLast > NO_DATA_DAYS_THRESHOLD) {
        return Colors.red; // dark-red
      }
    } catch (e) {
      // parsing failed → fall back to dark-red to be safe
      return Colors.red;
    }

    // 3. Normal movement logic
    return hasMoved ? Colors.blue : Colors.green;
  }

  Future<void> _loadPreviousPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? storedData = prefs.getString(POSITIONS_KEY);

      if (storedData != null) {
        final Map<String, dynamic> decodedData = json.decode(storedData);
        previousPositions = decodedData.map((key, value) => MapEntry(
              key,
              Map<String, dynamic>.from(value),
            ));
        print(
            'Loaded ${previousPositions.length} previous positions from storage');
        // Initialize allDeviceIds with all devices from previousPositions
        allDeviceIds = previousPositions.keys.toList()..sort();
        if (!allDeviceIds.contains('None')) {
          allDeviceIds.insert(0, 'None');
        }
      }
    } catch (e) {
      print('Error loading previous positions: $e');
      previousPositions = {};
      allDeviceIds = ['None'];
    }

    _fetchDeviceLocations();
  }

  Future<void> _savePreviousPositions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = json.encode(previousPositions);
      await prefs.setString(POSITIONS_KEY, encodedData);
      print('Saved ${previousPositions.length} positions to storage');
    } catch (e) {
      print('Error saving previous positions: $e');
    }
  }

  Future<void> _fetchDeviceLocations(
      {String? deviceId, DateTime? selectedDate}) async {
    setState(() {
      isLoading = true;
      searchPin = null;
    });

    try {
      String url = 'https://d20y38p47doyqp.cloudfront.net/GPS_API_Data_func';
      if (deviceId != null && deviceId != 'None' && selectedDate != null) {
        final String dateStr = dateFormatter.format(selectedDate);
        url += '?Device_id=$deviceId&startdate=$dateStr&enddate=$dateStr';
      }
      print('Fetching device locations from URL: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('API Response: $data');

        Map<String, Map<String, dynamic>> latestDevices = {};
        List<Map<String, dynamic>> fetchedDevices = [];
        bool positionsUpdated = false;

        // Process API response
        for (var device in data) {
          String devId = device['Device_id'].toString();
          // Only process the selected device if deviceId is specified and not 'None'
          if (deviceId != null && deviceId != 'None' && devId != deviceId) {
            continue;
          }

          String timestamp = device['Timestamp'].toString();
          bool hasNote =
              device.containsKey('Note') && device['Note'].isNotEmpty;

          if (!latestDevices.containsKey(devId)) {
            latestDevices[devId] = device;
            print('Added device $devId to latestDevices');
          } else {
            String existingTimestamp = latestDevices[devId]!['Timestamp'];
            bool existingHasNote = latestDevices[devId]!.containsKey('Note') &&
                latestDevices[devId]!['Note'].isNotEmpty;

            DateTime currentTime = DateTime.parse(timestamp);
            DateTime existingTime = DateTime.parse(existingTimestamp);

            if (currentTime.isAfter(existingTime)) {
              latestDevices[devId] = device;
            } else if (currentTime.isAtSameMomentAs(existingTime)) {
              if (hasNote && !existingHasNote) {
                latestDevices[devId] = device;
                print(
                    'Updated device $devId with note at same timestamp: $timestamp');
              }
            }
          }
        }

        // Update allDeviceIds with devices from the API response
        if (deviceId == null || deviceId == 'None') {
          allDeviceIds = latestDevices.keys.toList()..sort();
          if (!allDeviceIds.contains('None')) {
            allDeviceIds.insert(0, 'None');
          }
          print('Updated allDeviceIds: $allDeviceIds');
        }

        // Process devices from the API response or previous positions
        for (var devId in latestDevices.keys) {
          var device = latestDevices[devId]!;
          double lat = device['Latitude'] is String
              ? double.parse(device['Latitude'])
              : device['Latitude'].toDouble();
          double lon = device['Longitude'] is String
              ? double.parse(device['Longitude'])
              : device['Longitude'].toDouble();
          LatLng currentPosition = LatLng(lat, lon);
          String currentTimestamp = device['Timestamp'].toString();
          bool hasMoved = false;
          String? initialMovedTimestamp;

          if (previousPositions.containsKey(devId)) {
            final prevData = previousPositions[devId]!;
            final LatLng prevPosition =
                LatLng(prevData['latitude'], prevData['longitude']);
            final String prevTimestamp = prevData['timestamp'];
            initialMovedTimestamp = prevData['initial_moved_timestamp'];

            if (currentTimestamp == prevTimestamp) {
              fetchedDevices.add({
                'name': 'Device: $devId',
                'latitude': lat,
                'longitude': lon,
                'place': prevData['place'] ?? 'Unknown',
                'state': prevData['state'] ?? 'Unknown',
                'country': prevData['country'] ?? 'Unknown',
                'last_active': currentTimestamp,
                'has_moved': prevData['has_moved'] ?? false,
                'note': device['Note'] ?? '',
              });
              continue;
            }

            double dist =
                distance.as(LengthUnit.Meter, prevPosition, currentPosition);

            if (dist >= displacementThreshold) {
              hasMoved = true;
              initialMovedTimestamp = currentTimestamp;
            } else {
              hasMoved = prevData['has_moved'] ?? false;
            }
          } else {
            hasMoved = false;
            initialMovedTimestamp = currentTimestamp;
          }

          final geoData = await _reverseGeocode(lat, lon);
          previousPositions[devId] = {
            'latitude': lat,
            'longitude': lon,
            'timestamp': currentTimestamp,
            'initial_moved_timestamp':
                initialMovedTimestamp ?? currentTimestamp,
            'has_moved': hasMoved,
            'place': geoData['place'],
            'state': geoData['state'],
            'country': geoData['country'],
          };
          positionsUpdated = true;

          fetchedDevices.add({
            'name': 'Device: $devId',
            'latitude': lat,
            'longitude': lon,
            'place': geoData['place'] ?? 'Unknown',
            'state': geoData['state'] ?? 'Unknown',
            'country': geoData['country'] ?? 'Unknown',
            'last_active': currentTimestamp,
            'has_moved': hasMoved,
            'note': device['Note'] ?? '',
          });
        }

        // Only add devices from previousPositions if no specific deviceId is selected
        if (deviceId == null || deviceId == 'None') {
          for (var devId in previousPositions.keys) {
            if (!latestDevices.containsKey(devId)) {
              final prevData = previousPositions[devId]!;
              fetchedDevices.add({
                'name': 'Device: $devId',
                'latitude': prevData['latitude'],
                'longitude': prevData['longitude'],
                'place': prevData['place'] ?? 'Unknown',
                'state': prevData['state'] ?? 'Unknown',
                'country': prevData['country'] ?? 'Unknown',
                'last_active': prevData['timestamp'],
                'has_moved': prevData['has_moved'] ?? false,
                'note': '',
              });
            }
          }
        }

        if (positionsUpdated) {
          await _savePreviousPositions();
        }

        // Update deviceIds for display purposes
        deviceIds = fetchedDevices
            .map((device) =>
                device['name'].replaceFirst('Device: ', '') as String)
            .toSet()
            .toList();
        deviceIds.sort();
        if (!deviceIds.contains('None')) {
          deviceIds.insert(0, 'None');
        }
        print('Updated deviceIds: $deviceIds');

        setState(() {
          deviceLocations = fetchedDevices;
          filteredDevices = fetchedDevices;
          print(
              'Updated deviceLocations with ${deviceLocations.length} devices');
          _updateDeviceStatusesForInactivity();
          if (fetchedDevices.isNotEmpty) {
            centerCoordinates = LatLng(
                fetchedDevices[0]['latitude'], fetchedDevices[0]['longitude']);
            zoomLevel = 12.0;
            mapController.move(centerCoordinates, zoomLevel);
          } else {
            centerCoordinates = LatLng(0, 0);
            zoomLevel = 5.0;
            mapController.move(centerCoordinates, zoomLevel);
          }
        });
      } else if (response.statusCode == 404) {
        // Handle 404 as "No data found" and show SnackBar
        print('No data found for the selected device and date');
        setState(() {
          deviceLocations = [];
          filteredDevices = [];
          deviceIds = ['None'];
          centerCoordinates = LatLng(0, 0);
          zoomLevel = 5.0;
          mapController.move(centerCoordinates, zoomLevel);
        });
        if (deviceId != null && deviceId != 'None' && selectedDate != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No data found'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        print('Failed to fetch devices: HTTP Status ${response.statusCode}');
        _showError('Failed to fetch devices: ${response.statusCode}');

        List<Map<String, dynamic>> fetchedDevices = [];
        if (deviceId == null || deviceId == 'None') {
          for (var devId in previousPositions.keys) {
            final prevData = previousPositions[devId]!;
            fetchedDevices.add({
              'name': 'Device: $devId',
              'latitude': prevData['latitude'],
              'longitude': prevData['longitude'],
              'place': prevData['place'] ?? 'Unknown',
              'state': prevData['state'] ?? 'Unknown',
              'country': prevData['country'] ?? 'Unknown',
              'last_active': prevData['timestamp'],
              'has_moved': prevData['has_moved'] ?? false,
              'note': '',
            });
          }
        } else if (previousPositions.containsKey(deviceId)) {
          final prevData = previousPositions[deviceId]!;
          fetchedDevices.add({
            'name': 'Device: $deviceId',
            'latitude': prevData['latitude'],
            'longitude': prevData['longitude'],
            'place': prevData['place'] ?? 'Unknown',
            'state': prevData['state'] ?? 'Unknown',
            'country': prevData['country'] ?? 'Unknown',
            'last_active': prevData['timestamp'],
            'has_moved': prevData['has_moved'] ?? false,
            'note': '',
          });
        }

        deviceIds = fetchedDevices
            .map((device) =>
                device['name'].replaceFirst('Device: ', '') as String)
            .toSet()
            .toList();
        deviceIds.sort();
        if (!deviceIds.contains('None')) {
          deviceIds.insert(0, 'None');
        }

        setState(() {
          deviceLocations = fetchedDevices;
          filteredDevices = fetchedDevices;
          print(
              'Updated deviceLocations with ${deviceLocations.length} devices');
          _updateDeviceStatusesForInactivity();
          if (fetchedDevices.isNotEmpty) {
            centerCoordinates = LatLng(
                fetchedDevices[0]['latitude'], fetchedDevices[0]['longitude']);
            zoomLevel = 12.0;
            mapController.move(centerCoordinates, zoomLevel);
          } else {
            centerCoordinates = LatLng(0, 0);
            zoomLevel = 5.0;
            mapController.move(centerCoordinates, zoomLevel);
          }
        });
      }
    } catch (e) {
      _showError('Error fetching devices: $e');
      List<Map<String, dynamic>> fetchedDevices = [];
      if (deviceId == null || deviceId == 'None') {
        for (var devId in previousPositions.keys) {
          final prevData = previousPositions[devId]!;
          fetchedDevices.add({
            'name': 'Device: $devId',
            'latitude': prevData['latitude'],
            'longitude': prevData['longitude'],
            'place': prevData['place'] ?? 'Unknown',
            'state': prevData['state'] ?? 'Unknown',
            'country': prevData['country'] ?? 'Unknown',
            'last_active': prevData['timestamp'],
            'has_moved': prevData['has_moved'] ?? false,
            'note': '',
          });
        }
      } else if (previousPositions.containsKey(deviceId)) {
        final prevData = previousPositions[deviceId]!;
        fetchedDevices.add({
          'name': 'Device: $deviceId',
          'latitude': prevData['latitude'],
          'longitude': prevData['longitude'],
          'place': prevData['place'] ?? 'Unknown',
          'state': prevData['state'] ?? 'Unknown',
          'country': prevData['country'] ?? 'Unknown',
          'last_active': prevData['timestamp'],
          'has_moved': prevData['has_moved'] ?? false,
          'note': '',
        });
      }

      deviceIds = fetchedDevices
          .map(
              (device) => device['name'].replaceFirst('Device: ', '') as String)
          .toSet()
          .toList();
      deviceIds.sort();
      if (!deviceIds.contains('None')) {
        deviceIds.insert(0, 'None');
      }

      setState(() {
        deviceLocations = fetchedDevices;
        filteredDevices = fetchedDevices;
        print('Updated deviceLocations with ${deviceLocations.length} devices');
        _updateDeviceStatusesForInactivity();
        if (fetchedDevices.isNotEmpty) {
          centerCoordinates = LatLng(
              fetchedDevices[0]['latitude'], fetchedDevices[0]['longitude']);
          zoomLevel = 12.0;
          mapController.move(centerCoordinates, zoomLevel);
        } else {
          centerCoordinates = LatLng(0, 0);
          zoomLevel = 5.0;
          mapController.move(centerCoordinates, zoomLevel);
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _updateDeviceStatusesForInactivity() {
    // final currentTime = DateTime.now();
    // final istOffset = Duration(hours: 5, minutes: 30);
    final currentTimeUtc = DateTime.now().toUtc();
    print('Checking device inactivity statuses at UTC time: $currentTimeUtc');

    setState(() {
      for (var device in deviceLocations) {
        String deviceId = device['name'].replaceFirst('Device: ', '');
        if (!previousPositions.containsKey(deviceId)) continue;

        final prevData = previousPositions[deviceId]!;
        final String? initialMovedTimestamp =
            prevData['initial_moved_timestamp'];

        if (initialMovedTimestamp == null) {
          device['has_moved'] = false;
          prevData['has_moved'] = false;
          print(
              'No initial moved timestamp for device $deviceId, setting to green');
          continue;
        }

        try {
          DateTime initialMovedTime = DateTime.parse(initialMovedTimestamp);
          final timeSinceInitialMove =
              currentTimeUtc.difference(initialMovedTime).inMilliseconds;

          print(
              'Device $deviceId: Time since last significant movement = ${timeSinceInitialMove / 1000} seconds, Initial Moved Timestamp: $initialMovedTimestamp');

          if (timeSinceInitialMove >= stationaryTimeThreshold &&
              device['has_moved'] == true) {
            print(
                'Device $deviceId: Stationary for >= 10 minutes (${timeSinceInitialMove / 1000} seconds), changing color to green');
            device['has_moved'] = false;
            prevData['has_moved'] = false;
            prevData['initial_moved_timestamp'] = currentTimeUtc.toString();
          } else {
            print(
                'Device $deviceId: Retaining color (has_moved: ${device['has_moved']}) ${device['has_moved'] == false ? 'as device is already stationary' : 'as time since last movement (${timeSinceInitialMove / 1000} seconds) is less than 10 minutes'}');
          }
        } catch (e) {
          print(
              'Error parsing initial moved timestamp for device $deviceId: $e');
        }
      }
      filteredDevices = List.from(deviceLocations);
    });
    _savePreviousPositions();
  }

  Future<Map<String, String>> _reverseGeocode(double lat, double lon) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&zoom=18&addressdetails=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        String place = address['amenity'] ??
            address['building'] ??
            address['shop'] ??
            address['office'] ??
            address['tourism'] ??
            address['leisure'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['hamlet'] ??
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            data['display_name']?.split(',')[0] ??
            'Unknown';
        return {
          'place': place,
          'state': address['state'] ?? 'Unknown',
          'country': address['country'] ?? 'Unknown',
        };
      } else {
        print('Reverse geocoding failed: ${response.statusCode}');
        return {'place': 'Unknown', 'state': 'Unknown', 'country': 'Unknown'};
      }
    } catch (e) {
      print('Error during reverse geocoding: $e');
      return {'place': 'Unknown', 'state': 'Unknown', 'country': 'Unknown'};
    }
  }

  Future<void> _geocode(String query) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CloudSenseApp/1.0 (contact@example.com)'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty &&
            data[0]['lat'] != null &&
            data[0]['lon'] != null) {
          double lat = double.parse(data[0]['lat']);
          double lon = double.parse(data[0]['lon']);
          LatLng searchCoordinates = LatLng(lat, lon);
          setState(() {
            centerCoordinates = searchCoordinates;
            zoomLevel = 12.0;
            searchPin = Marker(
              width: 80.0,
              height: 80.0,
              point: searchCoordinates,
              child: Icon(
                Icons.location_pin,
                size: 40,
                color: Colors.blue,
              ),
            );
          });
          mapController.move(searchCoordinates, zoomLevel);
        } else {
          _showError("No results found for '$query'.");
        }
      } else {
        _showError("Failed to fetch location: ${response.statusCode}");
      }
    } catch (e) {
      _showError('Error during geocoding: $e');
    }
  }

  void _searchDevices(String query) async {
    setState(() {
      searchQuery = query.toLowerCase();
      filteredDevices = deviceLocations.where((device) {
        return device['place']?.toLowerCase().contains(searchQuery) == true ||
            device['state']?.toLowerCase().contains(searchQuery) == true ||
            device['country']?.toLowerCase().contains(searchQuery) == true ||
            device['name']?.toLowerCase().contains(searchQuery) == true;
      }).toList();
      if (query.isEmpty) {
        searchPin = null;
      }
    });

    if (filteredDevices.isEmpty && query.isNotEmpty) {
      await _geocode(query);
    } else if (filteredDevices.isNotEmpty) {
      final device = filteredDevices.first;
      setState(() {
        centerCoordinates = LatLng(device['latitude'], device['longitude']);
        zoomLevel = 12.0;
        searchPin = null;
      });
      mapController.move(centerCoordinates, zoomLevel);
    }
  }

  void _updateSuggestions(String query) {
    if (query.isEmpty) {
      setState(() {
        suggestions = [];
        searchPin = null;
      });
      return;
    }

    setState(() {
      suggestions = deviceLocations
          .where((device) =>
              device['name'].toLowerCase().contains(query.toLowerCase()) ||
              device['place'].toLowerCase().contains(query.toLowerCase()) ||
              device['state'].toLowerCase().contains(query.toLowerCase()) ||
              device['country'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    searchController.text = suggestion['place'];
    _searchDevices(suggestion['place']);
    setState(() {
      suggestions = [];
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _statusTextForDevice(Map<String, dynamic> device) {
    final String lastActiveStr = device['last_active'] ?? '';
    if (lastActiveStr.isEmpty) return 'No data received';

    try {
      final DateTime lastActiveUtc = DateTime.parse(lastActiveStr).toUtc();
      final int daysSinceLast =
          DateTime.now().toUtc().difference(lastActiveUtc).inDays;

      if (daysSinceLast > NO_DATA_DAYS_THRESHOLD) {
        return 'No data for $daysSinceLast days';
      }
    } catch (_) {}

    final bool hasMoved = device['has_moved'] == true;
    return hasMoved ? "Moved (>100 m)" : "Stationary (<100 m or >10 min)";
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
        if (selectedDeviceId != null && selectedDate != null) {
          _fetchDeviceLocations(
              deviceId: selectedDeviceId, selectedDate: selectedDate);
        }
      });
    }
  }

  Future<void> fetchDistanceData() async {
    if (startDater == null || endDater == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select start and end dates")),
      );
      return;
    }

    if (selectedDeviceIdr == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a device from the map")),
      );
      return;
    }

    setState(() {
      isLoadingr = true;
      filteredData = [];
    });

    final formattedStart =
        "${startDater!.day.toString().padLeft(2, '0')}-${startDater!.month.toString().padLeft(2, '0')}-${startDater!.year}";
    final formattedEnd =
        "${endDater!.day.toString().padLeft(2, '0')}-${endDater!.month.toString().padLeft(2, '0')}-${endDater!.year}";

    // remove "Device: " prefix if exists
    final cleanDeviceId =
        selectedDeviceIdr!.replaceFirst("Device: ", "").trim();

    final url =
        "https://d20y38p47doyqp.cloudfront.net/GPS_API_Data_func?Device_id=$cleanDeviceId&startdate=$formattedStart&enddate=$formattedEnd";

    try {
      print("API URL: $url");
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        final filtered = data.where((item) {
          final dist = (item["Distance_Meters"] ?? 0).toDouble();
          return dist > 100;
        }).toList();

        setState(() {
          filteredData = filtered;
        });
      } else {
        setState(() {
          filteredData = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.statusCode}")),
        );
      }
    } catch (e) {
      setState(() {
        filteredData = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoadingr = false);
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDate: startDater ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        startDater = picked;
        startController.text = formatDate(picked);
      });
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDate: endDater ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        endDater = picked;
        endController.text = formatDate(picked);
      });
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}";
  }

  Widget buildDateField(
      String label, TextEditingController controller, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
        ),
      ),
    );
  }

  Widget buildMovementsList() {
    if (filteredData.isEmpty) {
      return const Text("No movements > 100m found");
    }
    return ListView.builder(
      itemCount: filteredData.length,
      itemBuilder: (context, index) {
        final item = filteredData[index];
        final distance = (item["Distance_Meters"] ?? 0).toDouble();
        final timestamp = item["Timestamp"];
        return Card(
          child: ListTile(
            title: Text(
              "Moved ${distance.toStringAsFixed(2)}m",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("at $timestamp"),
          ),
        );
      },
    );
  }

  Widget buildMovementCard() {
    return Center(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 350,
              maxHeight: 450,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Check Movements",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                buildDateField("Start Date", startController, pickStartDate),
                const SizedBox(height: 10),
                buildDateField("End Date", endController, pickEndDate),
                ElevatedButton(
                  onPressed: isLoadingr ? null : fetchDistanceData,
                  child: isLoadingr
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Check Data"),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SizedBox(
                    height: 200,
                    child: buildMovementsList(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        showCard = false;
                        startDater = null;
                        endDater = null;
                        startController.clear();
                        endController.clear();
                        filteredData = [];
                        isLoadingr = false;
                      });
                    },
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeviceInfoDialog(
    BuildContext context,
    String name,
    double latitude,
    double longitude,
    String place,
    String state,
    String country,
    String lastActive,
    bool hasMoved, [
    String? note,
  ]) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Provider.of<ThemeProvider>(context).isDarkMode;
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: EdgeInsets.all(16),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 300,
              maxHeight: 400,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Latitude: ${latitude.toStringAsFixed(3)}'),
                  Text('Longitude: ${longitude.toStringAsFixed(3)}'),
                  Text('Place: $place'),
                  Text('State: $state'),
                  Text('Country: $country'),
                  Text('Last Active: $lastActive'),
                  Text(
                    'Status: ${hasMoved ? "Moved (>100m)" : "Stationary (<100m or >10 min)"}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: hasMoved ? Colors.red : Colors.green,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    SizedBox(height: 12),
                    Text(
                      "Note: $note",
                      style: TextStyle(
                        color: Colors.orange,
                        fontStyle: FontStyle.italic,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  showCard = true;
                });
              },
              child: const Text("Check Movements"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  TileLayer _getTileLayer() {
    String urlTemplate;
    switch (currentMapType) {
      case MapType.defaultMap:
        urlTemplate =
            'https://tile.openstreetmap.org/{z}/{x}/{y}.png'; // Same for both themes
        break;
      case MapType.satellite:
        urlTemplate =
            'https://tiles.stadiamaps.com/tiles/alidade_satellite/{z}/{x}/{y}{r}.png';
        break;
      case MapType.terrain:
        urlTemplate =
            'https://tiles.stadiamaps.com/tiles/stamen_terrain/{z}/{x}/{y}{r}.png';
        break;
    }

    return TileLayer(
      urlTemplate: urlTemplate,
      subdomains: [], // No subdomains
      maxZoom: 19.0,
      minZoom: 2.0,
      userAgentPackageName: 'com.CloudSenseVis', // Your app's package name
      tileProvider: NetworkTileProvider(
        headers: {
          'User-Agent': 'CloudSenseVis/1.0 (ihubawadh@gmail.com)',
        },
      ),
      errorTileCallback: (tile, error, stackTrace) {
        print('Stack trace: $stackTrace');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        color: isDarkMode ? const Color(0xFF1A2A44) : Colors.lightBlue[100],
        child: Stack(
          children: [
            FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: centerCoordinates,
                initialZoom: zoomLevel,
                minZoom: 2.0,
                maxZoom: 19.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                keepAlive: true,
                cameraConstraint: CameraConstraint.contain(
                  bounds: LatLngBounds(
                    LatLng(-85.05112878, -180),
                    LatLng(85.05112878, 180),
                  ),
                ),
              ),
              children: [
                _getTileLayer(),
                MarkerLayer(
                  markers: [
                    if (searchPin != null) searchPin!,
                    ...deviceLocations.map((device) {
                      return Marker(
                        point: LatLng(
                          device['latitude'],
                          device['longitude'],
                        ),
                        width: 80.0,
                        height: 80.0,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              selectedDeviceIdr = device['name'];
                            });
                            _showDeviceInfoDialog(
                              context,
                              device['name'],
                              device['latitude'],
                              device['longitude'],
                              device['place'],
                              device['state'],
                              device['country'],
                              device['last_active'],
                              device['has_moved'] == true,
                              device['note'],
                            );
                          },
                          child: Icon(
                            Icons.location_pin,
                            size: 40,
                            // NEW: colour logic
                            color: _markerColorForDevice(device),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    color: Colors.transparent,
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                          ),
                          color: Colors.black,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        // Text(
                        //   'Device Map',
                        //   style: TextStyle(
                        //     fontSize: 18,
                        //     fontWeight: FontWeight.bold,
                        //     color:  Colors.black,
                        //   ),
                        // ),
                        Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: isLoading
                              ? CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black),
                                )
                              : IconButton(
                                  icon:
                                      Icon(Icons.refresh, color: Colors.black),
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedDeviceId = null;
                                            selectedDate = null;
                                          });
                                          _fetchDeviceLocations();
                                        },
                                  tooltip: 'Reload Map',
                                ),
                        ),
                        SizedBox(width: 10),
                        // Container(
                        //   decoration: BoxDecoration(
                        //     color: Colors.white,
                        //     shape: BoxShape.circle,
                        //   ),
                        //   child: IconButton(
                        //     icon: Icon(Icons.logout, color: Colors.black),
                        //     onPressed: _handleLogout,
                        //     tooltip: 'Logout',
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isLargeScreen = constraints.maxWidth >= 600;
                        return isLargeScreen
                            ? Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: searchController,
                                      onChanged: _updateSuggestions,
                                      onSubmitted: _searchDevices,
                                      decoration: InputDecoration(
                                        hintText: 'Search Location',
                                        hintStyle: TextStyle(
                                          color: Colors.white,
                                        ),
                                        prefixIcon: Icon(Icons.search,
                                            color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        filled: true,
                                        fillColor:
                                            Colors.black.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: selectedDeviceId,
                                      hint: Text(
                                        'Select Device ID',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                      items: allDeviceIds.map((String id) {
                                        return DropdownMenuItem<String>(
                                          value: id,
                                          child: Text(id),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          selectedDeviceId = newValue;
                                          if (selectedDeviceId != null &&
                                              selectedDeviceId != 'None' &&
                                              selectedDate != null) {
                                            _fetchDeviceLocations(
                                                deviceId: selectedDeviceId,
                                                selectedDate: selectedDate);
                                          } else if (selectedDeviceId ==
                                              'None') {
                                            _fetchDeviceLocations();
                                          }
                                        });
                                      },
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.gps_fixed,
                                            color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        filled: true,
                                        fillColor:
                                            Colors.black.withOpacity(0.4),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      readOnly: true,
                                      onTap: () => _selectDate(context),
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        prefixIcon: Icon(Icons.calendar_today,
                                            color: Colors.white),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        filled: true,
                                        fillColor:
                                            Colors.black.withOpacity(0.4),
                                        hintText: selectedDate == null
                                            ? 'Select Date'
                                            : dateFormatter
                                                .format(selectedDate!),
                                        hintStyle: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  TextField(
                                    controller: searchController,
                                    onChanged: _updateSuggestions,
                                    onSubmitted: _searchDevices,
                                    decoration: InputDecoration(
                                      hintText: 'Search Location',
                                      hintStyle: TextStyle(
                                        color: Colors.white,
                                      ),
                                      prefixIcon: Icon(Icons.search,
                                          color: Colors.white),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.4),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: selectedDeviceId,
                                    hint: Text(
                                      'Select Device ID',
                                      style: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    items: allDeviceIds.map((String id) {
                                      return DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(id),
                                      );
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      setState(() {
                                        selectedDeviceId = newValue;
                                        if (selectedDeviceId != null &&
                                            selectedDeviceId != 'None' &&
                                            selectedDate != null) {
                                          _fetchDeviceLocations(
                                              deviceId: selectedDeviceId,
                                              selectedDate: selectedDate);
                                        } else if (selectedDeviceId == 'None') {
                                          _fetchDeviceLocations();
                                        }
                                      });
                                    },
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.gps_fixed,
                                          color: Colors.white),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.4),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  TextField(
                                    readOnly: true,
                                    onTap: () => _selectDate(context),
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                    decoration: InputDecoration(
                                      prefixIcon: Icon(Icons.calendar_today,
                                          color: Colors.white),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.4),
                                      hintText: selectedDate == null
                                          ? 'Select Date'
                                          : dateFormatter.format(selectedDate!),
                                      hintStyle: TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                      },
                    ),
                  ),
                  SizedBox(height: 10),
                  if (suggestions.isNotEmpty)
                    Container(
                      color: Colors.grey[850],
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: suggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = suggestions[index];
                          return ListTile(
                            title: Text(suggestion['place']),
                            subtitle: Text(
                                '${suggestion['state']}, ${suggestion['country']} - ${suggestion['name']}'),
                            onTap: () => _selectSuggestion(suggestion),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            if (showCard) buildMovementCard(),
          ],
        ),
      ),
    );
  }
}
