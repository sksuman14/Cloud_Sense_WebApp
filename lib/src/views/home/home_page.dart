import 'dart:convert';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_map.dart';
import 'dart:ui' as ui;
import 'package:cloud_sense_webapp/src/views/home/widgets/circular_product_carousel.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/widgets/appbar.dart';
import 'package:cloud_sense_webapp/src/widgets/drawer.dart';
import 'package:cloud_sense_webapp/src/widgets/footer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math';
import 'dart:async';
import 'package:universal_html/html.dart' as html;

import 'home_theme.dart';
export 'home_theme.dart';
import 'home_utils.dart';
import 'widgets/battery_indicator.dart';
import 'widgets/pressure_card.dart';
import 'widgets/humidity_card.dart';
import 'widgets/wind_card.dart';
import 'widgets/rainfall_card.dart';
import 'widgets/light_card.dart';
import 'widgets/wind_dial.dart';
import 'widgets/station_image_card.dart';
import 'widgets/stats_banner.dart';
import 'widgets/sensor_card.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Key _statsRefreshKey = UniqueKey();
  int _totalDevices = 0;
  int _devicesReportedToday = 0;

  String _dataPointsCount = "--";
  int _statesCount = 0;
  int _districtsCount = 0;
  bool _isHoveredMyDevicesButton = false;
  bool _isPressedMyDevicesButton = false;
  // NEW: For device dropdown
  String? selectedDeviceId;
  bool showNearestDevice = false;
  final TextEditingController _deviceIdController =
      TextEditingController(text: "ANNAM_CP02");

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productSectionKey = GlobalKey();
  bool _hasScrolledToProducts = false;

  final GlobalKey _heroKey = GlobalKey();
  final GlobalKey _telemetryKey = GlobalKey();
  final GlobalKey _techKey = GlobalKey();
  final GlobalKey _insightsKey = GlobalKey();
  final GlobalKey _mapKey = GlobalKey();

  void _scrollToSection(GlobalKey key) {
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  Map<String, dynamic>? nearestDevice;
  String? errorMessage;
  bool isLoading = true;
  String locationName = "Fetching location...";
  List devices = [];
  Map<String, dynamic>? selectedDevice;
  Timer? _pollingTimer;
  StreamSubscription<AuthHubEvent>? _authSubscription;

  @override
  void initState() {
    super.initState();
    if (selectedDeviceId != null && selectedDeviceId!.isNotEmpty) {
      _deviceIdController.text = selectedDeviceId!;
    }
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final uri = Uri.base;
          if (uri.queryParameters.containsKey('code') ||
              uri.queryParameters.containsKey('state') ||
              uri.path == '/home' ||
              uri.path == '/home/') {
            var cleanUri = uri;
            if (uri.queryParameters.containsKey('code') ||
                uri.queryParameters.containsKey('state')) {
              cleanUri = Uri(
                scheme: cleanUri.scheme,
                userInfo:
                    cleanUri.userInfo.isNotEmpty ? cleanUri.userInfo : null,
                host: cleanUri.host,
                port: cleanUri.port,
                path: cleanUri.path,
                fragment: cleanUri.hasFragment ? cleanUri.fragment : null,
              );
            }
            if (cleanUri.path == '/home' || cleanUri.path == '/home/') {
              cleanUri = cleanUri.replace(path: '/');
            }
            html.window.history.replaceState(null, '', cleanUri.toString());
          }
        } catch (e) {
          debugPrint("Error clearing URL parameters: $e");
        }
      });
    }
    _checkUserSessionAndRedirect();

    _authSubscription = Amplify.Hub.listen(
      HubChannel.Auth,
      (AuthHubEvent event) {
        if (event.type == AuthHubEventType.signedIn) {
          _checkUserSessionAndRedirect();
        }
      },
    );

    fetchDevicesAndNearest();
    _fetchDataPoints();
    _pollingTimer = Timer.periodic(const Duration(seconds: 59), (timer) {
      fetchDevicesAndNearest(silent: true);
    });
  }

  Future<void> _checkUserSessionAndRedirect() async {
    print("DEBUG: _checkUserSessionAndRedirect called!");
    try {
      var userAttributes = await Amplify.Auth.fetchUserAttributes();
      print("DEBUG: User attributes fetched successfully!");
      String? email;
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
          break;
        }
      }
      print("DEBUG: Email from attributes: $email");
      if (email != null) {
        final normalizedEmail = email.trim().toLowerCase();
        print("DEBUG: Normalized email: $normalizedEmail");

        if (!mounted) {
          print("DEBUG: Widget is not mounted. Cannot navigate.");
          return;
        }

        // Update user provider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(normalizedEmail);

        if (DeviceUtils.isSuperAdmin(normalizedEmail)) {
          print("DEBUG: Admin user staying on /home");
          // Do not redirect. Admin users should stay on the home page.
        } else if (normalizedEmail == '05agriculture.05@gmail.com') {
          print("DEBUG: Redirecting to /deviceinfo");
          NavigationUtils.navigateTo(context, '/deviceinfo',
              isReplacement: true);
        } else {
          print("DEBUG: Normal user staying on /home");
          // Do not redirect. Normal users should just stay on the home page.
        }
      }
    } catch (e) {
      print("DEBUG: _checkUserSessionAndRedirect error: $e");

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('email') != null) {
        print("DEBUG: Retaining session based on SharedPreferences");
        return;
      }

      // If the user is not authenticated and has no saved session, ensure UI state is cleared!
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(null);

      try {
        await prefs.remove('email');
      } catch (_) {}

      try {
        await Amplify.Auth.signOut();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _scrollController.dispose();
    _pollingTimer?.cancel();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasScrolledToProducts) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args == 'products_section') {
        _hasScrolledToProducts = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Give it a small delay to ensure all nested layouts are ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_productSectionKey.currentContext != null) {
              Scrollable.ensureVisible(
                _productSectionKey.currentContext!,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeInOutCubic,
              );
            }
          });
        });
      }
    }
  }

  Future<void> _handleDeviceNavigation() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail;

    if (email == null) {
      _showLoginPopup(context);
      return;
    }

    try {
      print('Navigating for user: $email');
      final normalizedEmail = email.trim().toLowerCase();

      if (DeviceUtils.isSuperAdmin(normalizedEmail)) {
        print('Navigating to /admin for super admin');
        NavigationUtils.navigateTo(context, '/admin');
      } else if (normalizedEmail == '05agriculture.05@gmail.com') {
        print('Navigating to /graph for agriculture user');
        NavigationUtils.navigateTo(context, '/deviceinfo');
      } else {
        print('Navigating to /devicelist for other users');
        await manageNotificationSubscription();
        NavigationUtils.navigateTo(context, '/devicelist');
      }
    } catch (e) {
      print('Error checking user: $e');
    }
  }

  void _showLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login Required'),
          content: Text('Please log in or sign up to access your devices.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await NavigationUtils.navigateTo(context, '/login');
              },
              child: Text('Login/Signup'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchDataPoints() async {
    final urls = [
      'https://mh94cp8whl.execute-api.us-east-1.amazonaws.com/default/WS_Total_Count',
      'https://qhi2d9xq70.execute-api.us-east-1.amazonaws.com/default/WS_Total_Count'
    ];

    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching total count $url: $e");
            return http.Response('{"count":0}', 500);
          }),
        ),
      );

      int totalCount = 0;
      bool anySuccess = false;

      for (final response in responses) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final int count = data['count'] ?? 0;
          totalCount += count;
          anySuccess = true;
        }
      }

      if (anySuccess) {
        if (mounted) {
          setState(() {
            _dataPointsCount = HomeUtils.formatNumber(totalCount);
          });
        }
      } else {
        if (mounted) setState(() => _dataPointsCount = "Error");
      }
    } catch (e) {
      if (mounted) setState(() => _dataPointsCount = "Error");
    }
  }

  DateTime? lastLocationCheck;
  Duration cacheDuration = const Duration(seconds: 300);
  Map<String, dynamic>? cachedNearest;

// Modified fetchDevicesAndNearest method with Demo Device prioritization

  Future<void> fetchDevicesAndNearest({bool silent = false}) async {
    try {
      final urls = [
        "https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity",
        "https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api",
      ];

      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching home devices $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );

      List<Map<String, dynamic>> allDevices = [];

      for (final response in responses) {
        if (response.statusCode != 200) continue;

        final data = json.decode(response.body);
        final List<dynamic>? devicesList = data["devices"];
        if (devicesList == null || devicesList.isEmpty) continue;

        allDevices.addAll(devicesList.cast<Map<String, dynamic>>());
      }

      if (allDevices.isEmpty) {
        if (mounted) {
          setState(() {
            errorMessage = "No devices found.";
            isLoading = false;
          });
        }
        return;
      }

      // Only count devices that have valid non-null, non-zero coordinates
      _totalDevices = allDevices.length; // ← include all devices
      devices = allDevices;

      int reportedTodayCount = 0;
      final now = DateTime.now();
      final ymdStr = DateFormat('yyyy-MM-dd').format(now);
      final dmyStr = DateFormat('dd-MM-yyyy').format(now);
      final dmySlashStr = DateFormat('dd/MM/yyyy').format(now);
      for (var device in allDevices) {
        final lastActive = (device["TimeStamp_IST"] ??
                device["TimeStamp"] ??
                device["last_active"] ??
                device["Date"] ??
                device["date"] ??
                "")
            .toString();
        if (lastActive.contains(ymdStr) ||
            lastActive.contains(dmyStr) ||
            lastActive.contains(dmySlashStr)) {
          reportedTodayCount++;
        }
      }
      _devicesReportedToday = reportedTodayCount > 0 ? reportedTodayCount : allDevices.length;

      // Calculate unique states and districts
      final Set<String> uniqueStates = {};
      final Set<String> uniqueDistricts = {};

      for (var device in allDevices) {
        final state =
            (device["State"] ?? device["state"] ?? "").toString().trim();
        final district = (device["District"] ??
                device["district"] ??
                device["DISTRICT"] ??
                "")
            .toString()
            .trim();

        if (state.isNotEmpty && state.toLowerCase() != "null") {
          uniqueStates.add(state);
        }
        if (district.isNotEmpty && district.toLowerCase() != "null") {
          uniqueDistricts.add(district);
        }
      }

      final statesCount = uniqueStates.length;
      final districtsCount = uniqueDistricts.length;

      // Default to ANNAM_CP02 if no device selected yet
      if (selectedDeviceId == null && !showNearestDevice) {
        selectedDeviceId = "ANNAM_CP02";
      }

      if (mounted) {
        setState(() {
          if (showNearestDevice && nearestDevice != null) {
            final updated = allDevices.firstWhere(
              (d) =>
                  d["deviceid#topic"].toString() ==
                  nearestDevice?["deviceid#topic"].toString(),
              orElse: () {
                final defDev =
                    HomeUtils.getDeviceByDisplayId("ANNAM_CP02", allDevices);
                return defDev != null
                    ? Map<String, dynamic>.from(defDev)
                    : allDevices.first;
              },
            );
            selectedDevice = Map<String, dynamic>.from(updated);
          } else if (selectedDeviceId != null) {
            final device =
                HomeUtils.getDeviceByDisplayId(selectedDeviceId!, allDevices);
            if (device != null) {
              selectedDevice = Map<String, dynamic>.from(device);
            } else {
              final defDev =
                  HomeUtils.getDeviceByDisplayId("ANNAM_CP02", allDevices);
              selectedDevice = defDev != null
                  ? Map<String, dynamic>.from(defDev)
                  : allDevices.first;
            }
          } else {
            final defDev =
                HomeUtils.getDeviceByDisplayId("ANNAM_CP02", allDevices);
            selectedDevice = defDev != null
                ? Map<String, dynamic>.from(defDev)
                : allDevices.first;
          }

          if (selectedDevice != null) {
            final actualId = HomeUtils.getDeviceIdFromTopic(
                selectedDevice!["deviceid#topic"]?.toString());
            if (actualId.isNotEmpty) {
              selectedDeviceId = actualId;
            }
          }

          if (!silent) isLoading = false;
          _statesCount = statesCount;
          _districtsCount = districtsCount;
          errorMessage = null;
        });
        if (selectedDeviceId != null && selectedDeviceId!.isNotEmpty) {
          _deviceIdController.text = selectedDeviceId!;
        }
        _updateNativeWidget();
      }
    } catch (e) {
      debugPrint("Error fetching devices: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = "Error fetching devices";
        });
      }
    }
  }

// Helper to get device by display ID (e.g., "ANNAM001")
// Helper to get device by display ID (e.g., "CP001")

  Future<bool> _getUserLocationAndFindNearest() async {
    if (lastLocationCheck != null &&
        DateTime.now().difference(lastLocationCheck!) < cacheDuration &&
        cachedNearest != null) {
      if (mounted) {
        setState(() {
          nearestDevice = cachedNearest;
          selectedDevice = cachedNearest;
          showNearestDevice = true; // Add this line
          errorMessage = null;
        });
        _updateNativeWidget();
      }
      return true;
    }

    try {
      double userLat = 0, userLon = 0;

      if (kIsWeb) {
        final completer = Completer<Position>();
        try {
          html.window.navigator.geolocation?.getCurrentPosition().then((pos) {
            final coords = pos.coords;
            completer.complete(Position(
              latitude: coords?.latitude?.toDouble() ?? 0,
              longitude: coords?.longitude?.toDouble() ?? 0,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            ));
          }).catchError((e) {
            completer.completeError("Location blocked");
          });
          final position = await completer.future;
          userLat = position.latitude;
          userLon = position.longitude;
        } catch (_) {
          return false;
        }
      } else {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            return false;
          }
        }
        Position position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        userLat = position.latitude;
        userLon = position.longitude;
      }

      DateTime today = DateTime.now();
      DateTime todayStart = DateTime(today.year, today.month, today.day);
      DateTime todayEnd = todayStart.add(const Duration(days: 1));

      List<Map<String, dynamic>> todaysDevices = [];

      for (var device in devices) {
        String ts = device["TimeStamp_IST"]?.toString().trim() ?? "";
        if (ts.isEmpty) continue;

        final formats = [
          "yyyy-MM-dd HH:mm:ss",
          "dd-MM-yyyy HH:mm:ss",
          "dd/MM/yyyy HH:mm:ss",
        ];

        for (var fmt in formats) {
          try {
            DateTime parsedDate = DateFormat(fmt).parse(ts, false).toLocal();

            if (parsedDate
                    .isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                parsedDate.isBefore(todayEnd)) {
              todaysDevices.add(Map<String, dynamic>.from(device));
              break; // Add break to avoid adding same device multiple times
            }
          } catch (_) {}
        }
      }

      List<Map<String, dynamic>> candidateDevices = todaysDevices.isNotEmpty
          ? todaysDevices
          : devices.cast<Map<String, dynamic>>();

      Map<String, dynamic>? foundNearest; // Changed variable name
      double minDist = double.infinity;

      for (var device in candidateDevices) {
        double lat = double.tryParse(device["Latitude"]?.toString() ?? "") ?? 0;
        double lon =
            double.tryParse(device["Longitude"]?.toString() ?? "") ?? 0;
        if (lat == 0 && lon == 0) continue;

        double distance =
            HomeUtils.calculateDistance(userLat, userLon, lat, lon);
        if (distance < minDist) {
          minDist = distance;
          foundNearest =
              Map<String, dynamic>.from(device); // Changed variable name
        }
      }

      if (mounted && foundNearest != null) {
        // Changed variable name
        setState(() {
          nearestDevice = foundNearest; // Changed variable name
          selectedDevice = nearestDevice;
          showNearestDevice = true; // Add this line
          errorMessage = null;
        });
        _updateNativeWidget();

        lastLocationCheck = DateTime.now();
        cachedNearest = foundNearest; // Changed variable name
        _updateNativeWidget();
      }

      return true;
    } catch (e) {
      debugPrint("Error in location/nearest: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.sizeOf(context).width;
    final themeProvider = Provider.of<ThemeProvider>(context);

    Provider.of<UserProvider>(context, listen: false);

    final currentDate = DateFormat("EEEE, dd MMMM yyyy").format(DateTime.now());

    return LayoutBuilder(builder: (context, constraints) {
      final isWideScreen = screenWidth > 800;
      final isDarkMode = themeProvider.isDarkMode;

      return Scaffold(
        key: _scaffoldKey,
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        appBar: AppBarWidget(
          onRefresh: () async {
            setState(() {
              _statsRefreshKey = UniqueKey();
            });
            await _fetchDataPoints();
            await fetchDevicesAndNearest(silent: true);
          },
        ),
        endDrawer: !isWideScreen ? const EndDrawerWidget() : null,
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDarkMode
                      ? [
                          const Color(0xFF0B141D),
                          const Color(0xFF091520),
                        ]
                      : [
                          const Color(0xFFFFFFFF),
                          const Color(0xFFF1F5F9),
                          const Color(0xFFEBF4FF),
                        ],
                ),
              ),
            ),
            Positioned(
              top: -100,
              right: -50,
              child: _GlowCircle(
                size: 400,
                color: isDarkMode
                    ? const Color(0xFF0D47A1).withOpacity(0.15)
                    : const Color(0xFFE3F2FD).withOpacity(0.5),
              ),
            ),
            Positioned(
              bottom: 200,
              left: -100,
              child: _GlowCircle(
                size: 500,
                color: isDarkMode
                    ? const Color(0xFF004D40).withOpacity(0.1)
                    : const Color(0xFFE0F2F1).withOpacity(0.4),
              ),
            ),
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // ── Hero Section ──
                  HeroSection(
                    key: _heroKey,
                    isDarkMode: isDarkMode,
                    onMyDevicesTap: _handleDeviceNavigation,
                    onTelemetryTap: () => _scrollToSection(_telemetryKey),
                    onProductsTap: () => _scrollToSection(_productSectionKey),
                    onMapTap: () => _scrollToSection(_mapKey),
                  ),

                  // ── Live Weather Telemetry ──
                  KeyedSubtree(
                    key: _telemetryKey,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: screenWidth < 800 ? 15 : 30,
                        right: screenWidth < 800 ? 15 : 30,
                        top: 0,
                        bottom: 15,
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SafeArea(
                          top: false,
                          child: Center(
                            child: isLoading
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : selectedDevice == null
                                    ? const Text("No device found.",
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 18))
                                    : LayoutBuilder(
                                        builder: (context, constraints) {
                                          double screenWidth =
                                              constraints.maxWidth;
                                          bool isLargeScreen =
                                              screenWidth >= 800;
                                          bool isSmallScreen =
                                              screenWidth < 600;

                                          // --- BATTERY WIDGET LOGIC ---
                                          final batteryVoltageString =
                                              selectedDevice?['BatteryVoltage']
                                                  ?.toString();
                                          Widget batteryWidget =
                                              const SizedBox.shrink();

                                          if (!HomeUtils.isNullOrEmpty(
                                              batteryVoltageString)) {
                                            final double? voltage =
                                                double.tryParse(
                                                    batteryVoltageString!);
                                            if (voltage != null) {
                                              final double percentage = HomeUtils
                                                  .convertVoltageToPercentage(
                                                      voltage);
                                              batteryWidget = BatteryIndicator(
                                                  percentage: percentage);
                                            }
                                          }

                                          Widget deviceSelector = Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (!showNearestDevice)
                                                SizedBox(
                                                  height:
                                                      isSmallScreen ? 38 : 42,
                                                  child: Container(
                                                    width: isSmallScreen
                                                        ? 115
                                                        : 150,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8),
                                                    decoration: BoxDecoration(
                                                      color: !isDarkMode
                                                          ? Colors.white
                                                          : const Color(
                                                                  0xFF0D1F2D)
                                                              .withOpacity(0.5),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      border: Border.all(
                                                        color: isDarkMode
                                                            ? Colors.white30
                                                            : Colors.black26,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: TextField(
                                                      controller:
                                                          _deviceIdController,
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontFamily: 'OpenSans',
                                                        fontSize: isSmallScreen
                                                            ? 10
                                                            : 13,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      decoration:
                                                          InputDecoration(
                                                        hintText: "e.g., DM001",
                                                        hintStyle: TextStyle(
                                                          color: isDarkMode
                                                              ? Colors.white38
                                                              : Colors.black38,
                                                          fontSize:
                                                              isSmallScreen
                                                                  ? 9
                                                                  : 12,
                                                        ),
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      onSubmitted:
                                                          (String value) {
                                                        if (value
                                                            .trim()
                                                            .isNotEmpty) {
                                                          final deviceId = value
                                                              .trim()
                                                              .toUpperCase();
                                                          final device = HomeUtils
                                                              .getDeviceByDisplayId(
                                                            deviceId,
                                                            devices.cast<
                                                                Map<String,
                                                                    dynamic>>(),
                                                          );

                                                          if (device != null) {
                                                            setState(() {
                                                              selectedDeviceId =
                                                                  deviceId;
                                                              showNearestDevice =
                                                                  false;
                                                              selectedDevice =
                                                                  device;
                                                              errorMessage =
                                                                  null;
                                                            });
                                                            _updateNativeWidget();
                                                          } else {
                                                            setState(() {
                                                              errorMessage =
                                                                  "Device $deviceId not found. Please check the ID.";
                                                            });
                                                            Future.delayed(
                                                                const Duration(
                                                                    seconds: 3),
                                                                () {
                                                              if (mounted) {
                                                                setState(() {
                                                                  errorMessage =
                                                                      null;
                                                                });
                                                              }
                                                            });
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                )
                                              else
                                                TextButton(
                                                  style: TextButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    shadowColor:
                                                        Colors.transparent,
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    minimumSize: Size.zero,
                                                    shape: const CircleBorder(),
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      showNearestDevice = false;
                                                      final targetId =
                                                          (selectedDeviceId !=
                                                                      null &&
                                                                  selectedDeviceId !=
                                                                      "ANNAM001")
                                                              ? selectedDeviceId!
                                                              : "ANNAM_CP02";
                                                      selectedDeviceId =
                                                          targetId;
                                                      selectedDevice = HomeUtils
                                                              .getDeviceByDisplayId(
                                                                  targetId,
                                                                  devices.cast<
                                                                      Map<String,
                                                                          dynamic>>()) ??
                                                          HomeUtils.getDeviceByDisplayId(
                                                              "ANNAM_CP02",
                                                              devices.cast<
                                                                  Map<String,
                                                                      dynamic>>());
                                                      nearestDevice = null;
                                                      errorMessage = null;
                                                    });
                                                    _deviceIdController.text =
                                                        selectedDeviceId ??
                                                            'ANNAM_CP02';
                                                    _updateNativeWidget();
                                                  },
                                                  child: const Icon(
                                                    Icons.arrow_back,
                                                    size: 20,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              const SizedBox(width: 12),
                                              if (!showNearestDevice)
                                                SizedBox(
                                                  height:
                                                      isSmallScreen ? 38 : 42,
                                                  child: InkWell(
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                    onTap: () async {
                                                      bool gotLocation =
                                                          await _getUserLocationAndFindNearest();
                                                      if (!gotLocation &&
                                                          mounted) {
                                                        setState(() {
                                                          errorMessage =
                                                              "Please enable location access to find nearest device.";
                                                        });
                                                        Future.delayed(
                                                            const Duration(
                                                                seconds: 3),
                                                            () {
                                                          if (mounted) {
                                                            setState(() {
                                                              errorMessage =
                                                                  null;
                                                            });
                                                          }
                                                        });
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: EdgeInsets
                                                          .symmetric(
                                                        horizontal:
                                                            isSmallScreen
                                                                ? 12
                                                                : 16,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: !isDarkMode
                                                            ? Colors.white
                                                            : const Color(
                                                                    0xFF0D1F2D)
                                                                .withOpacity(
                                                                    0.5),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: isDarkMode
                                                              ? Colors.white30
                                                              : Colors
                                                                  .black26,
                                                          width: 1,
                                                        ),
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: Text(
                                                        "Check Nearest Device",
                                                        style: TextStyle(
                                                          color: isDarkMode
                                                              ? Colors.white
                                                              : Colors.black,
                                                          fontFamily:
                                                              'OpenSans',
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize:
                                                              isSmallScreen
                                                                  ? 10
                                                                  : 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );

                                          return Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal:
                                                  screenWidth < 1024 ? 10 : 40,
                                              vertical: 10,
                                            ),
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                          maxWidth: screenWidth < 1024
                                                      ? 1400
                                                      : double.infinity),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  color: Colors.transparent,
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.only(top: 20, bottom: 20, left: 16, right: 16),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      // ── Live Data Section Heading ──
                                                      Center(
                                                        child: Text(
                                                          "Live Data",
                                                          style: TextStyle(
                                                            fontFamily: 'OpenSans',
                                                            fontSize: screenWidth < 600 ? 26 : 34,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: -0.5,
                                                            color: isDarkMode
                                                                ? Colors.white
                                                                : const Color(0xFF0D1B1E),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 32),

                                                      // --- START OF LAYOUT CHANGES ---

                                                      // --- CORRECTED HEADER SECTION ---
                                                      if (isSmallScreen) ...[
                                                        // Layout for Narrow Screens (Mobile)
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .end,
                                                          children: [
                                                            deviceSelector
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Flexible(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // Add Device ID display
                                                                  if (HomeUtils.getDeviceIdFromTopic(
                                                                          selectedDevice?["deviceid#topic"]
                                                                              ?.toString())
                                                                      .isNotEmpty)
                                                                    Text(
                                                                      "Device ID: ${HomeUtils.getDeviceIdFromTopic(selectedDevice?["deviceid#topic"]?.toString())}",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: isDarkMode
                                                                            ? Colors.white
                                                                            : Colors.black,
                                                                      ),
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                      maxLines:
                                                                          1,
                                                                    ),
                                                                  if (HomeUtils.getDeviceIdFromTopic(
                                                                          selectedDevice?["deviceid#topic"]
                                                                              ?.toString())
                                                                      .isNotEmpty)
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                  Text(
                                                                    HomeUtils.shouldHideLocation(selectedDevice?["deviceid#topic"]
                                                                            ?.toString())
                                                                        ? ""
                                                                        : HomeUtils.getFormattedLocation(
                                                                            selectedDevice),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: isDarkMode
                                                                          ? Colors
                                                                              .white
                                                                          : Colors
                                                                              .black,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    maxLines: 1,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          2),
                                                                  Text(
                                                                    currentDate,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          10,
                                                                      color: isDarkMode
                                                                          ? Colors
                                                                              .white70
                                                                          : Colors
                                                                              .black87,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            batteryWidget, // Aligned to the right by spaceBetween
                                                          ],
                                                        ),
                                                      ] else ...[
                                                        // Layout for Wide Screens (PC and Tablet)
                                                        Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            // Left side: Location info
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  // Add Device ID display
                                                                  if (HomeUtils.getDeviceIdFromTopic(
                                                                          selectedDevice?["deviceid#topic"]
                                                                              ?.toString())
                                                                      .isNotEmpty)
                                                                    Text(
                                                                      "Device ID: ${HomeUtils.getDeviceIdFromTopic(selectedDevice?["deviceid#topic"]?.toString())}",
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize: screenWidth <
                                                                                800
                                                                            ? 15
                                                                            : 18,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: isDarkMode
                                                                            ? Colors.white
                                                                            : Colors.black,
                                                                      ),
                                                                    ),
                                                                  if (HomeUtils.getDeviceIdFromTopic(
                                                                          selectedDevice?["deviceid#topic"]
                                                                              ?.toString())
                                                                      .isNotEmpty)
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                  Text(
                                                                    HomeUtils.shouldHideLocation(selectedDevice?["deviceid#topic"]
                                                                            ?.toString())
                                                                        ? ""
                                                                        : HomeUtils.getFormattedLocation(
                                                                            selectedDevice),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize: screenWidth <
                                                                              800
                                                                          ? 13
                                                                          : 16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                      color: isDarkMode
                                                                          ? Colors
                                                                              .white
                                                                          : Colors
                                                                              .black,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          2),
                                                                  Text(
                                                                    currentDate,
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: isDarkMode
                                                                          ? Colors
                                                                              .white70
                                                                          : Colors
                                                                              .black87,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            // Right side: Battery and Button together
                                                            Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                if (!HomeUtils
                                                                    .isNullOrEmpty(
                                                                        batteryVoltageString)) ...[
                                                                  batteryWidget,
                                                                  const SizedBox(
                                                                      width:
                                                                          24),
                                                                ],
                                                                deviceSelector,
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                      // --- END OF CORRECTION ---
                                                      const SizedBox(
                                                          height: 12),
                                                      Builder(
                                                        builder: (context) {
                                                          // Resolve prioritized values for primary parameters
                                                          final tempVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "CorrectedTemp",
                                                            "correctedtemp",
                                                            "CurrentTemperature",
                                                            "currenttemperature",
                                                            "NowTemperature",
                                                            "now_temperature",
                                                            "Maximum_Temperature",
                                                            "Minimum_Temperature",
                                                            "temperature"
                                                          ]);
                                                          final humidityVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "CorrectedHumidity",
                                                            "correctedhumidity",
                                                            "CurrentHumidity",
                                                            "currenthumidity",
                                                            "NowRelativeHumidity",
                                                            "now_relative_humidity",
                                                            "Maximum_Relative_Humidity",
                                                            "Minimum_Relative_Humidity",
                                                            "humidity"
                                                          ]);
                                                          final pressureVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "CurrentPressure",
                                                            "AtmPressure",
                                                            "atmpressure",
                                                            "now_pressure",
                                                            "pressure"
                                                          ]);
                                                          final windSpeedVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "WindSpeed",
                                                            "windspeed",
                                                            "NowWindSpeed",
                                                            "now_wind_speed",
                                                            "average_wind_speed",
                                                            "wind_speed"
                                                          ]);
                                                          final rainfallVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "RainfallHourly",
                                                            "rainfallhourly",
                                                            "Rainfall",
                                                            "rainfall",
                                                            "Rain_Rate",
                                                            "rain_rate"
                                                          ]);
                                                          final rainfallDailyVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "RainfallDaily",
                                                            "rainfalldaily"
                                                          ]);
                                                          final rainfallCumulativeVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "RainfallCumulative",
                                                            "Rainfall_Cumulative",
                                                            "RainfallComulative",
                                                            "Rainfall_Comulative",
                                                            "RainfallDailyComulative",
                                                            "RainfallHourlyComulative",
                                                            "RainfallMinutlyComulative",
                                                            "rainfallcumulative",
                                                            "rainfalldailycomulative",
                                                            "rainfallhourlycomulative"
                                                          ]);
                                                          final lightIntensityVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "LightIntensity",
                                                            "lightintensity",
                                                            "now_light"
                                                          ]);
                                                          final windDirVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "WindDirection",
                                                            "winddirection",
                                                            "NowWindDirection",
                                                            "now_wind_direction",
                                                            "average_wind_direction",
                                                            "max_wind_direction_gust"
                                                          ]);
                                                          final pm25Val = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "pm25",
                                                            "PM25",
                                                            "PM2.5"
                                                          ]);
                                                          final pm10Val = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "pm10",
                                                            "PM10"
                                                          ]);
                                                          final aqiVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "aqi",
                                                            "AQI"
                                                          ]);
                                                          final uvVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "uv_index",
                                                            "UVIndex",
                                                            "uvindex"
                                                          ]);
                                                          final batteryVal = HomeUtils.getCorrectedValue(selectedDevice, [
                                                            "Battery_Percentage",
                                                            "BatteryPercentage",
                                                            "battery_percentage"
                                                          ]);

                                                          // Build the shared list of grid items once
                                                          List<Widget> gridItems = [
                                                            if (!HomeUtils.isNullOrEmpty(tempVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.thermostat,
                                                                label: "Temperature",
                                                                value: "${HomeUtils.formatValue(tempVal)}°C",
                                                                glowColor: Colors.amber,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(tempVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(humidityVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.water_drop_outlined,
                                                                label: "Humidity",
                                                                value: "${HomeUtils.formatValue(humidityVal)} %",
                                                                glowColor: Colors.cyan,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.humidity,
                                                                numericValue: double.tryParse(humidityVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(lightIntensityVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.lightbulb_outline,
                                                                label: "Light Intensity",
                                                                value: "${HomeUtils.formatValue(lightIntensityVal)} Lux",
                                                                glowColor: Colors.orangeAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.light,
                                                                numericValue: double.tryParse(lightIntensityVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(pressureVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.compress,
                                                                label: "Atm Pressure",
                                                                value: "${HomeUtils.formatValue(pressureVal)} hPa",
                                                                glowColor: Colors.purpleAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.pressure,
                                                                numericValue: double.tryParse(pressureVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(windSpeedVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.air,
                                                                label: "Wind Speed",
                                                                value: "${HomeUtils.formatValue(windSpeedVal)} m/s",
                                                                glowColor: Colors.tealAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.wind,
                                                                numericValue: double.tryParse(windSpeedVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(rainfallVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.grain,
                                                                label: "Rainfall",
                                                                value: "${HomeUtils.formatValue(rainfallVal)} mm",
                                                                glowColor: Colors.blueAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.rainfall,
                                                                numericValue: double.tryParse(rainfallVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(rainfallCumulativeVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.cloud_download_outlined,
                                                                label: "Rainfall Cumulative",
                                                                value: "${HomeUtils.formatValue(rainfallCumulativeVal)} mm",
                                                                glowColor: Colors.indigoAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.rainfall,
                                                                numericValue: double.tryParse(rainfallCumulativeVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(pm25Val))
                                                              _HoverableGlassCard(
                                                                icon: Icons.grain_outlined,
                                                                label: "PM 2.5",
                                                                value: "${HomeUtils.formatValue(pm25Val)} µg/m³",
                                                                glowColor: Colors.orange,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(pm25Val.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(pm10Val))
                                                              _HoverableGlassCard(
                                                                icon: Icons.cloud_outlined,
                                                                label: "PM 10",
                                                                value: "${HomeUtils.formatValue(pm10Val)} µg/m³",
                                                                glowColor: Colors.deepOrangeAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(pm10Val.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(aqiVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.bubble_chart_outlined,
                                                                label: "AQI",
                                                                value: "${HomeUtils.formatValue(aqiVal)}",
                                                                glowColor: Colors.lightGreenAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(aqiVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(uvVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.wb_sunny_outlined,
                                                                label: "UV Index",
                                                                value: "${HomeUtils.formatValue(uvVal)}",
                                                                glowColor: Colors.amberAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(uvVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(batteryVal))
                                                              _HoverableGlassCard(
                                                                icon: Icons.battery_charging_full,
                                                                label: "Battery",
                                                                value: "${HomeUtils.formatValue(batteryVal)} %",
                                                                glowColor: Colors.greenAccent,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                                type: SensorType.temperature,
                                                                numericValue: double.tryParse(batteryVal.toString()),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(windDirVal) &&
                                                                !HomeUtils.isNullOrEmpty(windSpeedVal))
                                                              _HoverableCompassCard(
                                                                selectedDevice: selectedDevice,
                                                                isDarkMode: themeProvider.isDarkMode,
                                                              ),
                                                          ];

                                                          Widget weatherGrid = GridView.count(
                                                            crossAxisCount: screenWidth < 700 ? 2 : (screenWidth < 1100 ? 3 : 4),
                                                            crossAxisSpacing: 12,
                                                            mainAxisSpacing: 12,
                                                            padding: const EdgeInsets.all(4),
                                                            shrinkWrap: true,
                                                            physics: const NeverScrollableScrollPhysics(),
                                                            childAspectRatio: screenWidth < 480
                                                                ? 1.22
                                                                : (screenWidth < 700
                                                                    ? 1.4
                                                                    : (screenWidth < 1000
                                                                        ? 1.65
                                                                        : (screenWidth < 1300 ? 1.85 : 2.05))),
                                                            children: gridItems,
                                                          );

                                                          return weatherGrid;
                                                        },
                                                      ),
                                                      const SizedBox(height: 5),
                                                      Text(
                                                          "Last Updated: ${HomeUtils.formatValue(selectedDevice?["TimeStamp_IST"])}",
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            color: themeProvider
                                                                    .isDarkMode
                                                                ? Colors.white70
                                                                : Colors
                                                                    .black87,
                                                          )),
                                                      if (errorMessage !=
                                                          null) ...[
                                                        const SizedBox(
                                                            height: 6),
                                                        Text(errorMessage!,
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .redAccent,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold)),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Nationwide Deployments Section ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDarkMode
                            ? [
                                const Color(0xFF14212B),
                                const Color(0xFF0B141D),
                              ]
                            : [
                                Colors.white.withOpacity(0.9),
                                const Color(0xFFE3F2FD).withOpacity(0.8),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 60),
                        Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 30),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: isDarkMode
                                            ? [const Color(0xFF40C4FF).withOpacity(0.18), const Color(0xFF00E676).withOpacity(0.18)]
                                            : [const Color(0xFFE3F2FD), const Color(0xFFE8F5E9)],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? const Color(0xFF40C4FF).withOpacity(0.35)
                                            : const Color(0xFF1565C0).withOpacity(0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.radar_rounded, size: 14, color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0)),
                                        const SizedBox(width: 6),
                                        Text(
                                          "LIVE COVERAGE & NETWORK",
                                          style: TextStyle(
                                            fontFamily: 'OpenSans',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0),
                                            letterSpacing: 2.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    "Nationwide Deployments",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'OpenSans',
                                      fontSize: screenWidth < 600 ? 28 : 38,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: themeProvider.isDarkMode
                                          ? Colors.white
                                          : const Color(0xFF0D1B1E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            KeyedSubtree(
                              key: _mapKey,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth < 600 ? 0 : 30),
                                child: DeviceMapScreen(
                                  isComponent: true,
                                  height: screenWidth < 600
                                      ? 580
                                      : (screenWidth < 1200 ? 640 : 680),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        // ── Tech Showcase Section (above Our Products) ──
                        KeyedSubtree(
                          key: _techKey,
                          child: TechShowcaseSection(isDarkMode: isDarkMode),
                        ),
                        const SizedBox(height: 48),
                        // ── Our Products Carousel ──
                        KeyedSubtree(
                          key: _productSectionKey,
                          child: const ProductSectionV2(),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),

                  Footer(),
                ],
              ),
            )
          ],
        ),
      );
    });
  }

  String _formatUpdatedTime(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return '12:26 PM';
    try {
      final parts = timestamp.split(' ');
      if (parts.length >= 2) {
        final timePart = parts[1];
        final timeSubparts = timePart.split(':');
        if (timeSubparts.length >= 2) {
          int hour = int.parse(timeSubparts[0]);
          int minute = int.parse(timeSubparts[1]);
          String ampm = hour >= 12 ? 'PM' : 'AM';
          int displayHour = hour % 12;
          if (displayHour == 0) displayHour = 12;
          String minuteStr = minute.toString().padLeft(2, '0');
          return '$displayHour:$minuteStr $ampm';
        }
      }
      return timestamp;
    } catch (_) {
      return timestamp;
    }
  }

  // ─── Native Widget Update (widget independently finds nearest device) ───
  static const _widgetChannel =
      MethodChannel('com.example.cloud_sense_webapp/widget');

  Future<void> _updateNativeWidget() async {
    if (kIsWeb) return;
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
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          ));
        }).catchError((e) => completer.completeError("Location blocked"));
        final position = await completer.future;
        userLat = position.latitude;
        userLon = position.longitude;
      } else {
        // Invalidate cache and force fresh GPS reading
        lastLocationCheck = null;
        cachedNearest = null;

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
        String ts = device["TimeStamp_IST"]?.toString().trim() ??
            device["TimeStamp"]?.toString().trim() ??
            "";
        if (ts.isEmpty) continue;
        final formats = [
          "yyyy-MM-dd HH:mm:ss",
          "dd-MM-yyyy HH:mm:ss",
          "dd/MM/yyyy HH:mm:ss"
        ];
        for (var fmt in formats) {
          try {
            DateTime parsedDate = DateFormat(fmt).parse(ts, false).toLocal();
            if (parsedDate
                    .isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
                parsedDate.isBefore(todayEnd)) {
              todaysDevices.add(Map<String, dynamic>.from(device));
              break;
            }
          } catch (_) {}
        }
      }

      List<Map<String, dynamic>> candidates =
          todaysDevices.isNotEmpty ? todaysDevices : allDevices;

      // Step 4: Filter eligible devices (must have at least 3 parameters: temp, wind, rain)
      List<Map<String, dynamic>> eligibleDevices = [];
      for (var device in candidates) {
        bool hasTemp = (device["CorrectedTemp"] != null &&
                device["CorrectedTemp"].toString().toLowerCase() != 'null') ||
            (device["correctedtemp"] != null &&
                device["correctedtemp"].toString().toLowerCase() != 'null') ||
            (device["CurrentTemperature"] != null &&
                device["CurrentTemperature"].toString().toLowerCase() != 'null') ||
            (device["now_temperature"] != null &&
                device["now_temperature"].toString().toLowerCase() != 'null') ||
            (device["Maximum_Temperature"] != null &&
                device["Maximum_Temperature"].toString().toLowerCase() != 'null');
        bool hasWind =
            (device["WindSpeed"]?.toString().toLowerCase() != 'null' &&
                    device["WindSpeed"] != null) ||
                (device["windspeed"]?.toString().toLowerCase() != 'null' &&
                    device["windspeed"] != null) ||
                (device["now_wind_speed"]?.toString().toLowerCase() != 'null' &&
                    device["now_wind_speed"] != null) ||
                (device["average_wind_speed"]?.toString().toLowerCase() != 'null' &&
                    device["average_wind_speed"] != null);
        bool hasRain =
            (device["RainfallHourly"]?.toString().toLowerCase() != 'null' &&
                    device["RainfallHourly"] != null) ||
                (device["rainfallhourly"]?.toString().toLowerCase() != 'null' &&
                    device["rainfallhourly"] != null) ||
                (device["RainfallHourlyComulative"]?.toString().toLowerCase() !=
                        'null' &&
                    device["RainfallHourlyComulative"] != null) ||
                (device["Rainfall_Cumulative"]?.toString().toLowerCase() != 'null' &&
                    device["Rainfall_Cumulative"] != null) ||
                (device["rainfall"]?.toString().toLowerCase() != 'null' &&
                    device["rainfall"] != null) ||
                (device["Rainfall"]?.toString().toLowerCase() != 'null' &&
                    device["Rainfall"] != null) ||
                (device["Rain_Rate"]?.toString().toLowerCase() != 'null' &&
                    device["Rain_Rate"] != null);

        // Device must have at least 3 parameters (temperature + wind + rain)
        if (hasTemp && hasWind && hasRain) {
          eligibleDevices.add(Map<String, dynamic>.from(device));
        }
      }

      debugPrint(
          "Widget: Found ${eligibleDevices.length} eligible devices (with temp+wind+rain) out of ${candidates.length} candidates");

      // Step 5: Find nearest device among eligible ones
      Map<String, dynamic>? nearest;
      double minDist = double.infinity;
      for (var device in eligibleDevices) {
        double lat = double.tryParse(device["Latitude"]?.toString() ?? "") ?? 0;
        double lon =
            double.tryParse(device["Longitude"]?.toString() ?? "") ?? 0;
        if (lat == 0 && lon == 0) continue;
        double dist = HomeUtils.calculateDistance(userLat, userLon, lat, lon);
        if (dist < minDist) {
          minDist = dist;
          nearest = Map<String, dynamic>.from(device);
        }
      }

      // Step 6: Use nearest eligible device (or fallback to first available)
      widgetDeviceData =
          nearest ?? (allDevices.isNotEmpty ? allDevices.first : null);
      if (widgetDeviceData == null) return;

      // ─── Extract parameters ───────────────────────────────────────────
      final deviceId = HomeUtils.getDeviceIdFromTopic(
                  widgetDeviceData["deviceid#topic"]?.toString())
              .isNotEmpty
          ? HomeUtils.getDeviceIdFromTopic(
              widgetDeviceData["deviceid#topic"]?.toString())
          : 'ANNAM001';

      // Extract temperature
      double? temp;
      final correctedTemp = widgetDeviceData["CorrectedTemp"];
      if (correctedTemp != null &&
          correctedTemp.toString().trim().isNotEmpty &&
          correctedTemp.toString().toLowerCase() != 'null') {
        temp = double.tryParse(correctedTemp.toString());
      } else {
        final rawTemp = widgetDeviceData["correctedtemp"] ??
            widgetDeviceData["CurrentTemperature"] ??
            widgetDeviceData["now_temperature"];
        if (rawTemp != null &&
            rawTemp.toString().trim().isNotEmpty &&
            rawTemp.toString().toLowerCase() != 'null') {
          temp = double.tryParse(rawTemp.toString());
        }
      }

      double? windSpeed;
      final rawWind = widgetDeviceData["WindSpeed"] ??
          widgetDeviceData["windspeed"] ??
          widgetDeviceData["now_wind_speed"] ??
          widgetDeviceData["average_wind_speed"];
      if (rawWind != null &&
          rawWind.toString().toLowerCase() != 'null') {
        windSpeed = double.tryParse(rawWind.toString());
      }

      double? rainfall;
      final rawRain = widgetDeviceData["RainfallHourly"] ??
          widgetDeviceData["rainfallhourly"] ??
          widgetDeviceData["RainfallHourlyComulative"] ??
          widgetDeviceData["Rainfall_Cumulative"] ??
          widgetDeviceData["rainfall"] ??
          widgetDeviceData["Rainfall"];
      if (rawRain != null &&
          rawRain.toString().toLowerCase() != 'null') {
        rainfall = double.tryParse(rawRain.toString());
      }

      final isOnline =
          (widgetDeviceData['HealthStatus']?.toString().toLowerCase() ??
                  'online') ==
              'online';
      final updatedTime =
          _formatUpdatedTime(widgetDeviceData?['TimeStamp_IST']?.toString());
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
      debugPrint(
          "Widget updated (nearest independent): \$deviceId, temp=\${temp ?? 'N/A'}, wind=\${windSpeed ?? 'N/A'}, rain=\${rainfall ?? 'N/A'}, loc=\$location");
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

class HeroSection extends StatefulWidget {
  final VoidCallback onMyDevicesTap;
  final VoidCallback onTelemetryTap;
  final VoidCallback onProductsTap;
  final VoidCallback onMapTap;
  final bool isDarkMode;

  const HeroSection({
    super.key,
    required this.onMyDevicesTap,
    required this.onTelemetryTap,
    required this.onProductsTap,
    required this.onMapTap,
    required this.isDarkMode,
  });

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  late PageController _pageController;
  int _currentIndex = 0;
  bool _showArrows = false;       // show nav arrows on hover
  Timer? _timer;                  // single auto-scroll timer

  final List<Map<String, String>> _slides = [
    {"path": "assets/images/site10.jpg", "location": "Udhampur"},
    {"path": "assets/images/site1.jpg", "location": "Nehon, Punjab"},
    {"path": "assets/images/site2.jpg", "location": "Machhiwara, Punjab"},
    {"path": "assets/images/site3.jpg", "location": "Abohar, Punjab"},
    {"path": "assets/images/site4.jpg", "location": "Khanna, Punjab"},
    {"path": "assets/images/site5.jpg", "location": "Bhagta Bhai Ka, Punjab"},
    {"path": "assets/images/site6.jpg", "location": "Maur, Punjab"},
    {"path": "assets/images/site8.jpg", "location": "Jandiala, Punjab"},
    {"path": "assets/images/site9.jpg", "location": "Fazilka, Punjab"},
  ];

  static const int _initialVirtualMultiplier = 1000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialVirtualMultiplier * _slides.length,
    );
    _resetAutoScrollTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Preload all hero slide images so they appear instantly
    for (final slide in _slides) {
      precacheImage(AssetImage(slide['path']!), context);
    }
  }

  void _resetAutoScrollTimer() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _autoScrollNext);
  }

  void _autoScrollNext() {
    if (!mounted || !_pageController.hasClients) return;
    final currentVirtual = _pageController.page?.round() ??
        (_initialVirtualMultiplier * _slides.length + _currentIndex);
    final nextVirtual = currentVirtual + 1;
    _pageController.animateToPage(
      nextVirtual,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
    );
  }

  // Called when user clicks arrows
  void _onManualNav(int virtualPage) {
    _timer?.cancel();
    _pageController.animateToPage(
      virtualPage,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
    _resetAutoScrollTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 800;
    bool isTablet = width >= 800 && width < 1200;
    
    // Responsive Button Styling
    double btnPaddingHorizontal = isMobile ? 16.0 : (isTablet ? 18.0 : 28.0);
    double btnPaddingVertical = isMobile ? 12.0 : (isTablet ? 14.0 : 18.0);
    double btnFontSize = isMobile ? 12.0 : (isTablet ? 13.0 : 14.0);
    double iconSize = isMobile ? 16.0 : (isTablet ? 18.0 : 20.0);

    return Container(
      width: double.infinity,
      height: isMobile ? 650 : 750,
      color: Colors.black,
      child: MouseRegion(
        onEnter: (_) => setState(() => _showArrows = true),
        onExit: (_) => setState(() => _showArrows = false),
        child: Stack(
        children: [
          // 1. Full-Screen Slideshow — physics: NeverScrollableScrollPhysics disables drag/swipe
          PageView.builder(
            physics: const NeverScrollableScrollPhysics(),
            controller: _pageController,
            onPageChanged: (virtualIdx) {
              setState(() => _currentIndex = virtualIdx % _slides.length);
              _resetAutoScrollTimer();
            },
            itemBuilder: (context, virtualIndex) {
              final slideIndex = virtualIndex % _slides.length;
              final slidePath = _slides[slideIndex]["path"]!;
              return Stack(
                children: [
                  // Background image covering full space — no frameBuilder,
                  // renders immediately so blurred bg appears instantly.
                  // Dark overlay (BackdropFilter below) hides any pop-in.
                  Positioned.fill(
                    child: Image.asset(
                      slidePath,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                  // Blurred overlay to create matching blurry space filler (lower blur sigma!)
                  Positioned.fill(
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                  // Fully uncropped contained image aligned to the right on desktop, center on mobile
                  Positioned.fill(
                    child: Align(
                      alignment: isMobile ? Alignment.center : Alignment.centerRight,
                      child: Padding(
                        padding: isMobile 
                            ? const EdgeInsets.only(bottom: 20.0, left: 16.0, right: 16.0) 
                            : const EdgeInsets.only(right: 60.0, top: 40.0, bottom: 40.0),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: const [
                                Colors.transparent,
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.08, 0.92, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: const [
                                  Colors.transparent,
                                  Colors.black,
                                  Colors.black,
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.08, 0.92, 1.0],
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.dstIn,
                            child: Image.asset(
                              slidePath,
                              fit: BoxFit.contain,
                              alignment: isMobile ? Alignment.center : Alignment.centerRight,
                              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                if (wasSynchronouslyLoaded || frame != null) return child;
                                return AnimatedOpacity(
                                  opacity: frame == null ? 0.0 : 1.0,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeIn,
                                  child: child,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          // 2. Dark Overlay Gradient for Readability — IgnorePointer so drag works through it
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.65),
                    Colors.black.withOpacity(0.3),
                    widget.isDarkMode ? const Color(0xFF0B141D) : const Color(0xFFFFFFFF),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // 3. Left-Aligned Content Overlay on Desktop (Tesla Style)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 24.0 : 64.0),
            child: Align(
              alignment: isMobile ? Alignment.center : Alignment.centerLeft,
              child: SizedBox(
                width: isMobile ? double.infinity : width * 0.5,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 140), // Spacing for glassmorphic AppBar
                    // Main Title
                    Text(
                      "WEATHER INTELLIGENCE",
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'OpenSans',
                        fontSize: isMobile ? 28 : 52,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4.0,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Subtitle
                    Text(
                      "Industrial-grade telemetry. Real-time agricultural decision intelligence.",
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: isMobile ? 14 : 18,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.5,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 5,
                          ),
                        ],
                      ),
                    ),
                    Spacer(flex: isMobile ? 3 : 1),
                    // CTA Buttons
                    Column(
                      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // Top Row: My Devices, Explore Hardware, Nationwide Map
                        Wrap(
                          spacing: isMobile ? 10 : 16,
                          runSpacing: isMobile ? 10 : 16,
                          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                          children: [
                            ElevatedButton.icon(
                              onPressed: widget.onMyDevicesTap,
                              icon: Icon(Icons.devices, color: Colors.black, size: iconSize),
                              label: const Text("My Devices"),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: btnPaddingHorizontal, vertical: btnPaddingVertical),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget.onProductsTap,
                              icon: Icon(Icons.explore_outlined, color: Colors.white, size: iconSize),
                              label: const Text("Explore Hardware"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 2),
                                padding: EdgeInsets.symmetric(horizontal: btnPaddingHorizontal, vertical: btnPaddingVertical),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: widget.onMapTap,
                              icon: Icon(Icons.map_outlined, color: Colors.white, size: iconSize),
                              label: const Text("Nationwide Map"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 2),
                                padding: EdgeInsets.symmetric(horizontal: btnPaddingHorizontal, vertical: btnPaddingVertical),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Bottom Row: Live Monitor, KSDMA Portal
                        Wrap(
                          spacing: isMobile ? 10 : 16,
                          runSpacing: isMobile ? 10 : 16,
                          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
                          children: [
                            OutlinedButton.icon(
                              onPressed: widget.onTelemetryTap,
                              icon: Icon(Icons.analytics_outlined, color: Colors.white, size: iconSize),
                              label: const Text("Live Monitor"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white, width: 2),
                                padding: EdgeInsets.symmetric(horizontal: btnPaddingHorizontal, vertical: btnPaddingVertical),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () {
                                NavigationUtils.navigateTo(context, '/ksdma');
                              },
                              icon: Icon(Icons.shield_outlined, color: Colors.white, size: iconSize),
                              label: const Text("KSDMA Portal"),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF1976D2),
                                padding: EdgeInsets.symmetric(horizontal: btnPaddingHorizontal, vertical: btnPaddingVertical),
                                textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: btnFontSize),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Spacer(flex: isMobile ? 1 : 1),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
          // 4. Location Badge Overlay at the bottom-left
          Positioned(
            bottom: 24,
            left: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _slides[_currentIndex]["location"]!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 5. Slide Indicator Dots at the bottom-right
          Positioned(
            bottom: 24,
            right: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _slides.length,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.white
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
          // 6. Navigation Arrows — LAST in Stack so clickable on top
          if (_showArrows || isMobile) ...[
            Positioned(
              left: isMobile ? 10 : 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _onManualNav((_pageController.page?.round() ?? 0) - 1),
                  child: Container(
                    width: isMobile ? 38 : 48,
                    height: isMobile ? 38 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.chevron_left, color: Colors.white, size: isMobile ? 24 : 32),
                  ),
                ),
              ),
            ),
            Positioned(
              right: isMobile ? 10 : 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => _onManualNav((_pageController.page?.round() ?? 0) + 1),
                  child: Container(
                    width: isMobile ? 38 : 48,
                    height: isMobile ? 38 : 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.chevron_right, color: Colors.white, size: isMobile ? 24 : 32),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

class TechShowcaseSection extends StatelessWidget {
  final bool isDarkMode;

  const TechShowcaseSection({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    bool isMobile = width < 800;

    final cards = [
      _TechCard(
        icon: Icons.auto_awesome_outlined,
        title: "AI Telemetry Cleanse",
        tag: "AI ENGINE",
        accentColor: const Color(0xFF40C4FF),
        desc: "Filters spikes and sensor errors automatically. Our backend cross-verifies values using grid deviance and range algorithms to ensure reliable decision data.",
        isDarkMode: isDarkMode,
      ),
      _TechCard(
        icon: Icons.solar_power_outlined,
        title: "Autonomous Hardware",
        tag: "SOLAR POWERED",
        accentColor: const Color(0xFF00E676),
        desc: "Built to survive harsh monsoons. Equipped with integrated solar charging, IP65 waterproof housing, and 30-day battery backup for zero downtime.",
        isDarkMode: isDarkMode,
      ),
      _TechCard(
        icon: Icons.cell_tower_outlined,
        title: "4G & GPS Sync",
        tag: "REAL-TIME SYNC",
        accentColor: const Color(0xFFFFB74D),
        desc: "Instant remote connectivity. Telemetry nodes automatically sync raw and corrected weather values to our interactive maps every minute.",
        isDarkMode: isDarkMode,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDarkMode
                    ? [const Color(0xFF00E676).withOpacity(0.18), const Color(0xFF40C4FF).withOpacity(0.18)]
                    : [const Color(0xFFE8F5E9), const Color(0xFFE3F2FD)],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF40C4FF).withOpacity(0.35)
                    : const Color(0xFF1565C0).withOpacity(0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Text(
                  "ADVANCED FARM TECHNOLOGY",
                  style: TextStyle(
                    fontFamily: 'OpenSans',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? const Color(0xFF40C4FF) : const Color(0xFF1565C0),
                    letterSpacing: 2.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            "Designed for reliability. Engineered for impact.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'OpenSans',
              fontSize: isMobile ? 26 : 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: isDarkMode ? Colors.white : const Color(0xFF0D1B1E),
            ),
          ),
          const SizedBox(height: 36),
          isMobile
              ? Column(
                  children: cards.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: c,
                  )).toList(),
                )
              : IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: cards.map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: c,
                      ),
                    )).toList(),
                  ),
                ),
        ],
      ),
    );
  }
}

class _TechCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String tag;
  final Color accentColor;
  final String desc;
  final bool isDarkMode;

  const _TechCard({
    required this.icon,
    required this.title,
    required this.tag,
    required this.accentColor,
    required this.desc,
    required this.isDarkMode,
  });

  @override
  State<_TechCard> createState() => _TechCardState();
}

class _TechCardState extends State<_TechCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final glowColor = widget.accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: widget.isDarkMode
              ? [
                  BoxShadow(
                    color: glowColor.withOpacity(_hovered ? 0.32 : 0.12),
                    blurRadius: _hovered ? 32 : 16,
                    spreadRadius: _hovered ? 2 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: glowColor.withOpacity(_hovered ? 0.25 : 0.10),
                    blurRadius: _hovered ? 28 : 12,
                    spreadRadius: _hovered ? 1 : 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: widget.isDarkMode
                ? const Color(0xFF0D1F2D).withOpacity(_hovered ? 0.90 : 0.75)
                : Colors.white.withOpacity(_hovered ? 0.98 : 0.88),
            gradient: widget.isDarkMode
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      glowColor.withOpacity(_hovered ? 0.18 : 0.08),
                      const Color(0xFF0D1B2A).withOpacity(_hovered ? 0.95 : 0.75),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      glowColor.withOpacity(_hovered ? 0.12 : 0.05),
                      const Color(0xFFF0F6FF).withOpacity(_hovered ? 1.0 : 0.90),
                    ],
                  ),
            border: Border.all(
              color: glowColor.withOpacity(_hovered ? 0.70 : (widget.isDarkMode ? 0.28 : 0.20)),
              width: _hovered ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: glowColor.withOpacity(widget.isDarkMode ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: glowColor.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: glowColor,
                      size: 26,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: glowColor.withOpacity(widget.isDarkMode ? 0.14 : 0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: glowColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      widget.tag,
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: glowColor,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: widget.isDarkMode ? Colors.white : const Color(0xFF0D1B1E),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 2,
                width: 32,
                decoration: BoxDecoration(
                  color: glowColor.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.desc,
                style: TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 13.5,
                  height: 1.55,
                  color: widget.isDarkMode ? Colors.white70 : const Color(0xFF4A5568),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SensorType {
  temperature,
  humidity,
  light,
  pressure,
  wind,
  rainfall,
  generic,
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double fillPercentage;

  _WavePainter({
    required this.progress,
    required this.color,
    required this.fillPercentage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final level = (1.0 - (fillPercentage / 100.0).clamp(0.0, 1.0));
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * level + sin(x / size.width * 2 * pi + progress * 2 * pi) * 8;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = color.withOpacity(0.22)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x++) {
      final y = size.height * (level + 0.03).clamp(0.0, 1.0) + sin(x / size.width * 2 * pi - progress * 2 * pi + pi / 2) * 6;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _PressureLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _PressureLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    for (int i = 0; i < 4; i++) {
      final path = Path();
      final baseHeight = size.height * (0.35 + i * 0.14);
      path.moveTo(0, baseHeight);
      for (double x = 0; x <= size.width; x++) {
        final y = baseHeight + sin(x / size.width * 3 * pi + progress * 2 * pi + i * pi / 4) * 8;
        path.lineTo(x, y);
      }
      paint.color = color.withOpacity(0.2 + 0.08 * (4 - i));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WindLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WindLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (int i = 0; i < 5; i++) {
      final path = Path();
      final startY = size.height * (0.2 + i * 0.16);
      final localProgress = (progress + i * 0.22) % 1.0;
      final startX = size.width * (localProgress - 0.2);
      final endX = startX + size.width * 0.35;
      
      path.moveTo(startX, startY);
      for (double x = startX; x <= endX; x++) {
        final y = startY + sin(x / size.width * 4 * pi + progress * 2 * pi) * 4;
        path.lineTo(x, y);
      }
      
      paint.color = color.withOpacity(0.55 * sin(localProgress * pi));
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _RainDropPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RainDropPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < 12; i++) {
      final x = size.width * (0.05 + i * 0.08);
      final localProgress = (progress + i * 0.17) % 1.0;
      final startY = size.height * (localProgress - 0.25);
      final endY = startY + 20.0;

      final opacity = 0.5 * sin(localProgress * pi);
      final paintLine = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = color.withOpacity(opacity * 0.4);

      final paintDrop = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withOpacity(opacity);

      // Draw rain droplet head
      canvas.drawCircle(Offset(x, endY), 2.0, paintDrop);

      // Draw rain droplet tail/trail
      canvas.drawLine(Offset(x, startY), Offset(x, endY - 2.0), paintLine);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HoverableGlassCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color glowColor;
  final bool isDarkMode;
  final SensorType type;
  final double? numericValue;

  const _HoverableGlassCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.glowColor,
    required this.isDarkMode,
    required this.type,
    this.numericValue,
  }) : super(key: key);

  @override
  State<_HoverableGlassCard> createState() => _HoverableGlassCardState();
}

class _HoverableGlassCardState extends State<_HoverableGlassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = [Colors.transparent, Colors.transparent];

    final cardBorder = widget.isDarkMode
        ? (_isHovered
            ? widget.glowColor.withOpacity(0.55)
            : widget.glowColor.withOpacity(0.25))
        : (_isHovered
            ? widget.glowColor.withOpacity(0.7)
            : widget.glowColor.withOpacity(0.35));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardBg,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? widget.glowColor.withOpacity(0.3)
                  : widget.glowColor.withOpacity(0.12),
              blurRadius: _isHovered ? 18 : 10,
              spreadRadius: _isHovered ? 1.5 : 0.5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // 1. Subtle Background Animation Overlay
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    if (widget.type == SensorType.temperature) {
                      final opacity = (0.1 + 0.3 * sin(_animController.value * 2 * pi).abs());
                      return Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 1.2,
                            colors: [
                              widget.glowColor.withOpacity(opacity),
                              widget.glowColor.withOpacity(opacity * 0.2),
                            ],
                          ),
                        ),
                      );
                    } else if (widget.type == SensorType.humidity) {
                      return CustomPaint(
                        painter: _WavePainter(
                          progress: _animController.value,
                          color: widget.glowColor,
                          fillPercentage: widget.numericValue ?? 0.0,
                        ),
                      );
                    } else if (widget.type == SensorType.light) {
                      final progress = _animController.value;
                      return Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(-2.0 + progress * 4.0, -1.0),
                            end: Alignment(-1.0 + progress * 4.0, 1.0),
                            colors: [
                              Colors.transparent,
                              widget.glowColor.withOpacity(0.04),
                              widget.glowColor.withOpacity(0.45),
                              widget.glowColor.withOpacity(0.04),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                          ),
                        ),
                      );
                    } else if (widget.type == SensorType.pressure) {
                      return CustomPaint(
                        painter: _PressureLinePainter(
                          progress: _animController.value,
                          color: widget.glowColor,
                        ),
                      );
                    } else if (widget.type == SensorType.wind) {
                      return CustomPaint(
                        painter: _WindLinePainter(
                          progress: _animController.value,
                          color: widget.glowColor,
                        ),
                      );
                    } else if (widget.type == SensorType.rainfall) {
                      if (widget.numericValue != null && widget.numericValue! > 0.0) {
                        return CustomPaint(
                          painter: _RainDropPainter(
                            progress: _animController.value,
                            color: widget.glowColor,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              // 2. Light leak glow in top-right (always visible, boosts on hover)
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.glowColor.withOpacity(_isHovered ? 0.25 : 0.12),
                        blurRadius: _isHovered ? 35 : 20,
                        spreadRadius: _isHovered ? 18 : 8,
                      ),
                    ],
                  ),
                ),
              ),
              // 3. Foreground metric data
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.glowColor.withOpacity(0.1),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.glowColor,
                            size: 18,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isHovered
                                ? widget.glowColor
                                : widget.glowColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.label.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                widget.value,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _HoverableCompassCard extends StatefulWidget {
  final Map<String, dynamic>? selectedDevice;
  final bool isDarkMode;

  const _HoverableCompassCard({
    Key? key,
    required this.selectedDevice,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<_HoverableCompassCard> createState() => _HoverableCompassCardState();
}

class _HoverableCompassCardState extends State<_HoverableCompassCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const glowColor = Colors.blueAccent;
    final cardBg = [Colors.transparent, Colors.transparent];

    final cardBorder = widget.isDarkMode
        ? (_isHovered
            ? glowColor.withOpacity(0.55)
            : glowColor.withOpacity(0.25))
        : (_isHovered
            ? glowColor.withOpacity(0.7)
            : glowColor.withOpacity(0.35));

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder, width: 1.2),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardBg,
          ),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? glowColor.withOpacity(0.3)
                  : glowColor.withOpacity(0.12),
              blurRadius: _isHovered ? 18 : 10,
              spreadRadius: _isHovered ? 1.5 : 0.5,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Subtle rotating radar sweep gradient
              Positioned.fill(
                child: RotationTransition(
                  turns: _rotationController,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          Colors.transparent,
                          glowColor.withOpacity(0.01),
                          glowColor.withOpacity(0.12),
                          glowColor.withOpacity(0.01),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top row: icon badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: glowColor.withOpacity(0.1),
                          ),
                          child: const Icon(
                            Icons.explore_outlined,
                            color: glowColor,
                            size: 16,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isHovered
                                ? glowColor
                                : glowColor.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    // Compass dial — compact
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: FittedBox(
                            fit: BoxFit.contain,
                            child: WindDial(
                              direction: widget.selectedDevice?["WindDirection"] ??
                                  widget.selectedDevice?["winddirection"] ??
                                  widget.selectedDevice?["NowWindDirection"],
                              speed: widget.selectedDevice?["WindSpeed"] ??
                                  widget.selectedDevice?["windspeed"] ??
                                  widget.selectedDevice?["NowWindSpeed"],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom: label + direction value
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "WIND DIRECTION",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: widget.isDarkMode ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            () {
                              final dir = widget.selectedDevice?["WindDirection"] ??
                                  widget.selectedDevice?["winddirection"] ??
                                  widget.selectedDevice?["NowWindDirection"];
                              if (dir == null) return "-- °";
                              final deg = double.tryParse(dir.toString());
                              if (deg == null) return "$dir";
                              const directions = ["N","NE","E","SE","S","SW","W","NW","N"];
                              final idx = ((deg + 22.5) / 45).floor() % 8;
                              return "${deg.toStringAsFixed(0)}° ${directions[idx]}";
                            }(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.isDarkMode ? Colors.white : Colors.black87,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
