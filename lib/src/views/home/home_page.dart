import 'dart:convert';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_map.dart';
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
import 'widgets/circular_product_carousel.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Key _statsRefreshKey = UniqueKey();
  int _totalDevices = 0;

  String _dataPointsCount = "--";
  int _statesCount = 0;
  int _districtsCount = 0;
  bool _isHoveredMyDevicesButton = false;
  bool _isPressedMyDevicesButton = false;
  // NEW: For device dropdown
  String? selectedDeviceId; // e.g., "ANNAM001", "DM001", etc.
  bool showNearestDevice = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productSectionKey = GlobalKey();
  bool _hasScrolledToProducts = false;

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
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          try {
            final uri = Uri.parse(html.window.location.href);
            bool needsUpdate = false;
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
              needsUpdate = true;
            }

            if (cleanUri.path == '/home' || cleanUri.path == '/home/') {
              cleanUri = cleanUri.replace(path: '/');
              needsUpdate = true;
            }

            if (needsUpdate) {
              html.window.history.replaceState(null, '', cleanUri.toString());
            }
          } catch (e) {
            print("Error clearing URL parameters: $e");
          }
        });
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
          NavigationUtils.navigateTo(context, '/deviceinfo', isReplacement: true);
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

      // Default to ANNAM001 if no device selected yet
      if (selectedDeviceId == null && !showNearestDevice) {
        selectedDeviceId = "ANNAM001";
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
                    HomeUtils.getDeviceByDisplayId("ANNAM001", allDevices);
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
                  HomeUtils.getDeviceByDisplayId("ANNAM001", allDevices);
              selectedDevice = defDev != null
                  ? Map<String, dynamic>.from(defDev)
                  : allDevices.first;
            }
          } else {
            final defDev =
                HomeUtils.getDeviceByDisplayId("ANNAM001", allDevices);
            selectedDevice = defDev != null
                ? Map<String, dynamic>.from(defDev)
                : allDevices.first;
          }

          if (!silent) isLoading = false;
          _statesCount = statesCount;
          _districtsCount = districtsCount;
          errorMessage = null;
        });
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
    double screenWidth = MediaQuery.of(context).size.width;
    final themeProvider = Provider.of<ThemeProvider>(context);

    Provider.of<UserProvider>(context, listen: false);

    final currentDate = DateFormat("EEEE, dd MMMM yyyy").format(DateTime.now());

    return LayoutBuilder(builder: (context, constraints) {
      final isWideScreen = screenWidth > 800;
      final isDarkMode = themeProvider.isDarkMode;

      return Scaffold(
        key: _scaffoldKey,
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
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth < 800 ? 15 : 30,
                      vertical: 15,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SafeArea(
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
                                                      isSmallScreen ? 34 : 40,
                                                  child: Container(
                                                    width: isSmallScreen
                                                        ? 100
                                                        : 150,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4),
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
                                                    child: TextField(
                                                      controller:
                                                          TextEditingController(
                                                        text:
                                                            selectedDeviceId ??
                                                                "ANNAM001",
                                                      ),
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontSize: isSmallScreen
                                                            ? 10
                                                            : 14,
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
                                                        contentPadding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                          horizontal: 4,
                                                          vertical: 8,
                                                        ),
                                                        isDense: true,
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
                                                      selectedDeviceId =
                                                          "ANNAM001";
                                                      selectedDevice = HomeUtils
                                                          .getDeviceByDisplayId(
                                                        "ANNAM001",
                                                        devices.cast<
                                                            Map<String,
                                                                dynamic>>(),
                                                      );
                                                      nearestDevice = null;
                                                      errorMessage = null;
                                                    });
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
                                                      isSmallScreen ? 34 : 40,
                                                  child: TextButton(
                                                    style: TextButton.styleFrom(
                                                      backgroundColor:
                                                          !isDarkMode
                                                              ? Colors.white
                                                              : const Color(
                                                                      0xFF0D1F2D)
                                                                  .withOpacity(
                                                                      0.5),
                                                      padding: isSmallScreen
                                                          ? const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 12,
                                                              vertical: 12)
                                                          : const EdgeInsets
                                                              .symmetric(
                                                              horizontal: 16,
                                                              vertical: 16),
                                                      minimumSize: Size.zero,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                    ),
                                                    onPressed: () async {
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
                                                    child: Text(
                                                      "Check Nearest Device",
                                                      style: TextStyle(
                                                        color: isDarkMode
                                                            ? Colors.white
                                                            : Colors.black,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: isSmallScreen
                                                            ? 9
                                                            : 12,
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
                                                  gradient: LinearGradient(
                                                    colors: isDarkMode
                                                        ? [
                                                            const Color(
                                                                    0xFF1D2B38)
                                                                .withOpacity(
                                                                    0.9),
                                                            const Color(
                                                                0xFF1D2B38)
                                                          ]
                                                        : [
                                                            Colors.white
                                                                .withOpacity(
                                                                    0.9),
                                                            const Color(
                                                                    0xFFF5F7FA)
                                                                .withOpacity(
                                                                    0.9),
                                                          ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.3),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 4))
                                                  ],
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.all(25),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
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
                                                          // Build the shared list of grid items once
                                                          List<Widget>
                                                              gridItems = [
                                                            if (!HomeUtils.isNullOrEmpty(selectedDevice?["CorrectedTemp"] ??
                                                                selectedDevice?[
                                                                    "correctedtemp"] ??
                                                                selectedDevice?[
                                                                    "CurrentTemperature"] ??
                                                                selectedDevice?[
                                                                    "currenttemperature"]))
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(4),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  gradient: getTemperatureGradient(selectedDevice?["CorrectedTemp"] ??
                                                                      selectedDevice?[
                                                                          "correctedtemp"] ??
                                                                      selectedDevice?[
                                                                          "CurrentTemperature"] ??
                                                                      selectedDevice?[
                                                                          "currenttemperature"]),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Icon(
                                                                            Icons
                                                                                .thermostat,
                                                                            color: themeProvider.isDarkMode
                                                                                ? Colors.white
                                                                                : Colors.black,
                                                                            size: 18),
                                                                        const SizedBox(
                                                                            width:
                                                                                4),
                                                                        Text(
                                                                            "Temperature",
                                                                            style:
                                                                                TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                      "${HomeUtils.formatValue(selectedDevice?["CorrectedTemp"] ?? selectedDevice?["correctedtemp"] ?? selectedDevice?["CurrentTemperature"] ?? selectedDevice?["currenttemperature"])}°C",
                                                                      style: TextStyle(
                                                                          color: themeProvider.isDarkMode
                                                                              ? Colors
                                                                                  .white70
                                                                              : Colors
                                                                                  .black87,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              16),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(selectedDevice?["CorrectedHumidity"] ??
                                                                selectedDevice?[
                                                                    "correctedhumidity"] ??
                                                                selectedDevice?[
                                                                    "CurrentHumidity"] ??
                                                                selectedDevice?[
                                                                    "currenthumidity"]))
                                                              AnimatedWaveHumidityCard(
                                                                humidity: double.tryParse((selectedDevice?["CorrectedHumidity"] ??
                                                                            selectedDevice?["correctedhumidity"] ??
                                                                            selectedDevice?["CurrentHumidity"] ??
                                                                            selectedDevice?["currenthumidity"])
                                                                        .toString()) ??
                                                                    0.0,
                                                                formattedValue: HomeUtils.formatValue(selectedDevice?["CorrectedHumidity"] ??
                                                                    selectedDevice?[
                                                                        "correctedhumidity"] ??
                                                                    selectedDevice?[
                                                                        "CurrentHumidity"] ??
                                                                    selectedDevice?[
                                                                        "currenthumidity"]),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(
                                                                selectedDevice?[
                                                                        "LightIntensity"] ??
                                                                    selectedDevice?[
                                                                        "lightintensity"]))
                                                              AnimatedLightCard(
                                                                luxValue: HomeUtils.formatValue(selectedDevice?[
                                                                        "LightIntensity"] ??
                                                                    selectedDevice?[
                                                                        "lightintensity"]),
                                                                name: HomeUtils
                                                                    .getNameForKey(
                                                                        "LightIntensity"),
                                                                unit: HomeUtils
                                                                    .getUnitForKey(
                                                                        "LightIntensity"),
                                                                color: themeProvider
                                                                        .isDarkMode
                                                                    ? Colors
                                                                        .white70
                                                                    : Colors
                                                                        .black87,
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(
                                                                    selectedDevice?[
                                                                        "CurrentPressure"]) ||
                                                                !HomeUtils.isNullOrEmpty(selectedDevice?[
                                                                        "AtmPressure"] ??
                                                                    selectedDevice?[
                                                                        "atmpressure"]))
                                                              AnimatedPressureCard(
                                                                pressure: double.tryParse((selectedDevice?["CurrentPressure"] ??
                                                                            selectedDevice?["AtmPressure"] ??
                                                                            selectedDevice?["atmpressure"])
                                                                        .toString()) ??
                                                                    0.0,
                                                                formattedValue: HomeUtils.formatValue(selectedDevice?["CurrentPressure"] ??
                                                                    selectedDevice?[
                                                                        "AtmPressure"] ??
                                                                    selectedDevice?[
                                                                        "atmpressure"]),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(
                                                                selectedDevice?[
                                                                        "WindSpeed"] ??
                                                                    selectedDevice?[
                                                                        "windspeed"]))
                                                              AnimatedWindCard(
                                                                windSpeed: double.tryParse((selectedDevice?["WindSpeed"] ??
                                                                            selectedDevice?["windspeed"])
                                                                        .toString()) ??
                                                                    0.0,
                                                                formattedValue: HomeUtils.formatValue(selectedDevice?[
                                                                        "WindSpeed"] ??
                                                                    selectedDevice?[
                                                                        "windspeed"]),
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(
                                                                selectedDevice?[
                                                                        "RainfallHourly"] ??
                                                                    selectedDevice?[
                                                                        "rainfallhourly"]))
                                                              AnimatedRainfallCard(
                                                                rainfall: double.tryParse((selectedDevice?["RainfallHourly"] ??
                                                                            selectedDevice?["rainfallhourly"])
                                                                        .toString()) ??
                                                                    0.0,
                                                                formattedValue: HomeUtils.formatValue(selectedDevice?[
                                                                        "RainfallHourly"] ??
                                                                    selectedDevice?[
                                                                        "rainfallhourly"]),
                                                                label: HomeUtils
                                                                    .getNameForKey(
                                                                        "RainfallHourly"),
                                                                intensityMultiplier:
                                                                    10.0,
                                                                enableAnimation:
                                                                    true,
                                                              ),
                                                            if (!HomeUtils.isNullOrEmpty(
                                                                selectedDevice?[
                                                                        "RainfallDaily"] ??
                                                                    selectedDevice?[
                                                                        "rainfalldaily"]))
                                                              AnimatedRainfallCard(
                                                                rainfall: double.tryParse((selectedDevice?["RainfallDaily"] ??
                                                                            selectedDevice?["rainfalldaily"])
                                                                        .toString()) ??
                                                                    0.0,
                                                                formattedValue: HomeUtils.formatValue(selectedDevice?[
                                                                        "RainfallDaily"] ??
                                                                    selectedDevice?[
                                                                        "rainfalldaily"]),
                                                                label: HomeUtils
                                                                    .getNameForKey(
                                                                        "RainfallDaily"),
                                                                intensityMultiplier:
                                                                    2.0,
                                                                enableAnimation:
                                                                    false,
                                                              ),
                                                            ...(selectedDevice ??
                                                                    {})
                                                                .entries
                                                                .where((e) =>
                                                                    !HomeUtils
                                                                        .isNullOrEmpty(e
                                                                            .value) &&
                                                                    !{
                                                                      "Latitude",
                                                                      "Longitude",
                                                                      "WindDirection",
                                                                      "winddirection",
                                                                      "TimeStamp_IST",
                                                                      "CurrentTemperature",
                                                                      "CurrentHumidity",
                                                                      "currenthumidity",
                                                                      "LightIntensity",
                                                                      "lightintensity",
                                                                      "CurrentPressure",
                                                                      "AtmPressure",
                                                                      "atmpressure",
                                                                      "WindSpeed",
                                                                      "windspeed",
                                                                      "RainfallHourly",
                                                                      "rainfallhourly",
                                                                      "RainfallDaily",
                                                                      "rainfalldaily",
                                                                      "RainfallWeekly",
                                                                      "rainfallweekly",
                                                                      "deviceid#topic",
                                                                      "ExpiresAt",
                                                                      "IMEINumber",
                                                                      "LastUpdated",
                                                                      "Topic",
                                                                      "SignalStrength",
                                                                      "BatteryVoltage",
                                                                      "AverageHumidity",
                                                                      "MinimumHumidity",
                                                                      "HumidityHourlyComulative",
                                                                      "AverageTemperature",
                                                                      "MaximumTemperature",
                                                                      "MinimumTemperature",
                                                                      "PressureHourlyComulative",
                                                                      "RainfallMinutlyComulative",
                                                                      "RainfallHourlyComulative",
                                                                      "RainfallWeeklyComulative",
                                                                      "RainfallDailyComulative",
                                                                      "MaximumHumidity",
                                                                      "TemperatureHourlyComulative",
                                                                      "State",
                                                                      "District",
                                                                      "City",
                                                                      'SDcardStatus',
                                                                      "CurrentRelativeHumidity",
                                                                      "geo_status",
                                                                      "Rainfall",
                                                                      "Interval",
                                                                      "epoch_ts",
                                                                      "HealthStatus",
                                                                      "Payload",
                                                                      "DeviceId",
                                                                      "FirmwareVersion",
                                                                      "firmwareversion",
                                                                      "CorrectedTemp",
                                                                      "correctedtemp",
                                                                      "CurrentTemperature",
                                                                      "currenttemperature",
                                                                      "CorrectedHumidity",
                                                                      "correctedhumidity",
                                                                    }.contains(
                                                                        e.key))
                                                                .map((e) {
                                                              return Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: themeProvider
                                                                          .isDarkMode
                                                                      ? Colors
                                                                          .white
                                                                          .withOpacity(
                                                                              0.1)
                                                                      : Colors
                                                                          .black
                                                                          .withOpacity(
                                                                              0.05),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                child: Column(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Icon(
                                                                            HomeUtils.getIconForKey(e
                                                                                .key),
                                                                            color: themeProvider.isDarkMode
                                                                                ? Colors.white
                                                                                : Colors.black,
                                                                            size: 18),
                                                                        const SizedBox(
                                                                            width:
                                                                                4),
                                                                        Text(
                                                                            HomeUtils.getNameForKey(e
                                                                                .key),
                                                                            style:
                                                                                TextStyle(color: themeProvider.isDarkMode ? Colors.white70 : Colors.black87, fontSize: 11)),
                                                                      ],
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                      "${HomeUtils.formatValue(e.value)} ${HomeUtils.getUnitForKey(e.key)}",
                                                                      style: TextStyle(
                                                                          color: themeProvider.isDarkMode
                                                                              ? Colors
                                                                                  .white70
                                                                              : Colors
                                                                                  .black87,
                                                                          fontWeight: FontWeight
                                                                              .bold,
                                                                          fontSize:
                                                                              16),
                                                                      textAlign:
                                                                          TextAlign
                                                                              .center,
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            }).toList(),
                                                          ];

                                                          if (!HomeUtils.isNullOrEmpty(
                                                                  selectedDevice?[
                                                                          "WindDirection"] ??
                                                                      selectedDevice?[
                                                                          "winddirection"]) &&
                                                              !HomeUtils.isNullOrEmpty(
                                                                  selectedDevice?[
                                                                          "WindSpeed"] ??
                                                                      selectedDevice?[
                                                                          "windspeed"])) {
                                                            gridItems.add(
                                                              Container(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .all(2),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  gradient:
                                                                      LinearGradient(
                                                                    colors:
                                                                        themeProvider.isDarkMode
                                                                            ? [
                                                                                Colors.lightBlue.shade700.withOpacity(0.5),
                                                                                Colors.blue.shade900.withOpacity(0.6),
                                                                              ]
                                                                            : [
                                                                                Colors.lightBlue.shade800.withOpacity(0.85),
                                                                                Colors.blue.shade900.withOpacity(0.9),
                                                                              ],
                                                                    begin: Alignment
                                                                        .topLeft,
                                                                    end: Alignment
                                                                        .bottomRight,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              8),
                                                                ),
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                child:
                                                                    FittedBox(
                                                                  fit: BoxFit
                                                                      .scaleDown,
                                                                  child: WindDial(
                                                                      direction: selectedDevice?[
                                                                              "WindDirection"] ??
                                                                          selectedDevice?[
                                                                              "winddirection"],
                                                                      speed: selectedDevice?[
                                                                              "WindSpeed"] ??
                                                                          selectedDevice?[
                                                                              "windspeed"]),
                                                                ),
                                                              ),
                                                            );
                                                          }

                                                          Widget weatherGrid =
                                                              GridView.count(
                                                            crossAxisCount:
                                                                screenWidth <
                                                                        800
                                                                    ? 2
                                                                    : 3,
                                                            crossAxisSpacing:
                                                                15,
                                                            mainAxisSpacing: 15,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(4),
                                                            shrinkWrap: true,
                                                            physics:
                                                                const NeverScrollableScrollPhysics(),
                                                            childAspectRatio:
                                                                screenWidth <
                                                                        800
                                                                    ? 1.8
                                                                    : 2.4,
                                                            children: gridItems,
                                                          );

                                                          if (!isLargeScreen) {
                                                            // ── Mobile & Small Tablet ──────────────────────────────
                                                            return Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .stretch,
                                                              children: [
                                                                StationImageCard(
                                                                  width: double
                                                                      .infinity,
                                                                  fit: BoxFit
                                                                      .fitWidth,
                                                                ),
                                                                const SizedBox(
                                                                    height: 16),
                                                                weatherGrid,
                                                              ],
                                                            );
                                                          } else {
                                                            // ── Large Tablet & Desktop ─────────────────────────────
                                                            return LayoutBuilder(
                                                              builder: (ctx,
                                                                  outerConstraints) {
                                                                const spacing =
                                                                    16.0;
                                                                final totalW =
                                                                    outerConstraints
                                                                        .maxWidth;

                                                                // Syncing with map's 7:3 ratio for desktop screens (>= 1024)
                                                                final bool
                                                                    useMapRatio =
                                                                    screenWidth >=
                                                                        1024;
                                                                final gridW = (totalW -
                                                                        spacing) *
                                                                    (useMapRatio
                                                                        ? 7
                                                                        : 5) /
                                                                    (useMapRatio
                                                                        ? 10
                                                                        : 8);
                                                                final imageW = (totalW -
                                                                        spacing) *
                                                                    (useMapRatio
                                                                        ? 3
                                                                        : 3) /
                                                                    (useMapRatio
                                                                        ? 10
                                                                        : 8);

                                                                const crossAxisSpacing =
                                                                    15.0;
                                                                const mainAxisSpacing =
                                                                    15.0;
                                                                const gridPadding =
                                                                    4.0;
                                                                const crossCount =
                                                                    3;
                                                                const childAspectRatio =
                                                                    2.4;

                                                                final itemW = (gridW -
                                                                        (crossCount -
                                                                                1) *
                                                                            crossAxisSpacing -
                                                                        gridPadding *
                                                                            2) /
                                                                    crossCount;
                                                                final itemH =
                                                                    itemW /
                                                                        childAspectRatio;

                                                                final numRows =
                                                                    (gridItems.length /
                                                                            crossCount)
                                                                        .ceil()
                                                                        .clamp(
                                                                            1,
                                                                            999);

                                                                final gridH = numRows *
                                                                        itemH +
                                                                    (numRows -
                                                                            1) *
                                                                        mainAxisSpacing +
                                                                    gridPadding *
                                                                        2;

                                                                final imageH =
                                                                    (gridH).clamp(
                                                                        200.0,
                                                                        9999.0);

                                                                return Row(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    SizedBox(
                                                                      width:
                                                                          gridW,
                                                                      child:
                                                                          Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          weatherGrid,
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            spacing),
                                                                    SizedBox(
                                                                      width:
                                                                          imageW,
                                                                      height:
                                                                          imageH,
                                                                      child:
                                                                          StationImageCard(
                                                                        width:
                                                                            imageW,
                                                                        height:
                                                                            imageH,
                                                                        fit: BoxFit
                                                                            .fill,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                );
                                                              },
                                                            );
                                                          }
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
                        const SizedBox(height: 15),
                        // ── Stats Banner ─────────────────────────────────
                        KeyedSubtree(
                          key: _statsRefreshKey,
                          child: StatsBanner(
                            totalDevices: _totalDevices,
                            dataPointsCount: _dataPointsCount,
                            statesCount: _statesCount,
                            districtsCount: _districtsCount,
                            themeProvider: themeProvider,
                            screenWidth: screenWidth,
                            onMyDevicesTap: _handleDeviceNavigation,
                            isHovered: _isHoveredMyDevicesButton,
                            isPressed: _isPressedMyDevicesButton,
                            onHoverChanged: (v) =>
                                setState(() => _isHoveredMyDevicesButton = v),
                            onPressChanged: (v) =>
                                setState(() => _isPressedMyDevicesButton = v),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
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
                        const SizedBox(height: 20),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            "Nationwide Deployments",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: screenWidth < 600 ? 24 : 30,
                              fontWeight: FontWeight.bold,
                              color: themeProvider.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth < 600 ? 0 : 30),
                          child: DeviceMapScreen(
                            isComponent: true,
                            height: 600,
                          ),
                        ),
                        const SizedBox(height: 50),
                        KeyedSubtree(
                          key: _productSectionKey,
                          child: const ProductSectionV2(),
                        ),
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
  static const _widgetChannel = MethodChannel('com.example.cloud_sense_webapp/widget');

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
