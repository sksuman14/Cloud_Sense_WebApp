import 'dart:convert';
import 'package:cloud_sense_webapp/config/amplifyconfiguration.dart';
import 'package:cloud_sense_webapp/src/admin/admin_page.dart';
import 'package:cloud_sense_webapp/src/admin/device_health_status.dart';
import 'package:cloud_sense_webapp/src/admin/quality_diagnostics_page.dart';

import 'package:cloud_sense_webapp/src/auth/login_page.dart';
import 'package:cloud_sense_webapp/src/services/push_notifications.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/GPS.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/buffalodata.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/cowdata.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/device_graph.dart';
import 'package:cloud_sense_webapp/src/views/devices/AccountInfo.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_list.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_map.dart';
import 'package:cloud_sense_webapp/src/views/home/home_page.dart';
import 'package:cloud_sense_webapp/src/views/home/privacy_policy_page.dart';
import 'package:cloud_sense_webapp/src/views/home/terms_of_service_page.dart';
import 'package:cloud_sense_webapp/src/views/products/product_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_sense_webapp/src/views/dashboard/Weather_Nowcasting.dart';
import 'package:cloud_sense_webapp/src/ksdma_citizen/views/ksdma_portal_main.dart';


// Initialize Flutter local notifications plugin
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ✅ RouteObserver to track last visited route
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
  if (message.data.isNotEmpty) {
    await showNotification(message);
  }
}

// Function to show local notifications
Future<void> showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;
  AndroidNotification? android = message.notification?.android;

  if (notification != null && android != null) {
    String? title = notification.title ?? "Notification";
    String? body = notification.body;
    String? payload =
        message.data['ammonia_level'] ?? message.data['gps_movement'] ?? '';

    if (message.data.containsKey('gps_movement')) {
      title = "GPS Device Movement";
      body =
          "Device ${message.data['device_id']} has moved: ${message.data['gps_movement']}";
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}

Future<void> handleLoginAndSubscribe(String userEmail, String fcmToken) async {
  print("User logged in: $userEmail");

  if (userEmail == '05agriculture.05@gmail.com' ||
      DeviceUtils.isSuperAdmin(userEmail)) {
    print("Matched user: $userEmail - triggering GPS topic subscription.");
    await subscribeToGpsSnsTopic(fcmToken);
  } else {
    print("User $userEmail is not configured for auto-subscription.");
  }
}

Future<void> subscribeToGpsSnsTopic(String fcmToken) async {
  print("Subscribing device to GPS SNS topic with token: $fcmToken");

  const String snsTopicArn =
      'arn:aws:sns:us-east-1:396608808412:GPS_Notification';
  const String apiGatewayUrl =
      'https://cpkutjaqel.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'subscribe',
      'snsTopicArn': snsTopicArn,
      'fcmToken': fcmToken,
    });

    print("POST request sent to subscribe GPS: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    print(
        "Subscribe GPS API response: ${response.statusCode} - ${response.body}");

    if (response.statusCode == 200) {
      print("Device subscribed to GPS SNS topic successfully.");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isGpsTokenSubscribed', true);
    } else {
      print("Failed to subscribe to GPS SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error subscribing to GPS SNS topic: $e");
  }
}

Future<void> unsubscribeFromGpsSnsTopic(String fcmToken) async {
  print("Unsubscribing device from GPS SNS topic with token: $fcmToken");
  const String apiGatewayUrl =
      'https://cpkutjaqel.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'unsubscribe',
      'fcmToken': fcmToken,
    });
    print("Sending POST request to unsubscribe GPS: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    print(
        "Unsubscribe GPS API response: ${response.statusCode} - ${response.body}");
    if (response.statusCode == 200) {
      print("Device unsubscribed from GPS SNS topic successfully.");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove('isGpsTokenSubscribed');
    } else {
      print("Failed to unsubscribe from GPS SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error unsubscribing from GPS SNS topic: $e");
  }
}

Future<void> manageNotificationSubscription() async {
  print("Starting manageNotificationSubscription...");

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  if (email == null) {
    print("No user logged in. Skipping notification subscriptions.");
    return;
  }

  try {
    String? token = await messaging.getToken();
    if (token == null) {
      print("Failed to retrieve FCM token.");
      return;
    }

    print("User logged in: $email");
    print("FCM Token: $token");

    if (email == "05agriculture.05@gmail.com" ||
        DeviceUtils.isSuperAdmin(email)) {
      print("GPS notifications allowed for this user.");
      bool? isGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
      if (isGpsSubscribed != true) {
        await subscribeToGpsSnsTopic(token);
        await prefs.setBool('isGpsTokenSubscribed', true);
      } else {
        print("Already subscribed to GPS SNS topic.");
      }
      bool? wasAmmoniaSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
      if (wasAmmoniaSubscribed == true) {
        await unsubscribeFromSnsTopic(token);
        await prefs.remove('isAmmoniaTokenSubscribed');
      }
    } else {
      bool hasAmmoniaSensor = await userHasAmmoniaSensor(email);
      if (hasAmmoniaSensor) {
        print(
            "NH sensor found for user. Subscribing to ammonia notifications.");
        bool? isAmmoniaSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
        if (isAmmoniaSubscribed != true) {
          await subscribeToSnsTopic(token);
          await prefs.setBool('isAmmoniaTokenSubscribed', true);
        } else {
          print("Already subscribed to ammonia SNS topic.");
        }
      } else {
        print("No NH sensor found. Unsubscribing if previously subscribed.");
        bool? wasSubscribed = prefs.getBool('isAmmoniaTokenSubscribed');
        if (wasSubscribed == true) {
          await unsubscribeFromSnsTopic(token);
          await prefs.remove('isAmmoniaTokenSubscribed');
        }
      }
      bool? isGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
      if (isGpsSubscribed == true) {
        await unsubscribeFromGpsSnsTopic(token);
        await prefs.remove('isGpsTokenSubscribed');
      }
    }
  } catch (e) {
    print("Error managing notification subscriptions: $e");
  }

  print("manageNotificationSubscription completed.");
}

Future<void> checkAndUpdateNotificationSubscription() async {
  await manageNotificationSubscription();
}

Future<bool> userHasAmmoniaSensor(String email) async {
  final String apiUrl =
      'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$email';

  try {
    var response = await http.get(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
    );
    print("Checking NH sensor for user: $email");

    if (response.statusCode == 200) {
      try {
        var data = jsonDecode(response.body);
        if (data.containsKey("NH") && (data["NH"] as List).isNotEmpty) {
          print("Ammonia sensor found!");
          return true;
        } else {
          print("No ammonia sensor found.");
        }
      } catch (e) {
        print("Invalid JSON response from device API: ${response.body}");
        return false;
      }
    } else {
      print("Failed to fetch devices. Status Code: ${response.statusCode}");
    }
  } catch (e) {
    print("Error fetching device list: $e");
  }

  return false;
}

Future<void> subscribeToSnsTopic(String fcmToken) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? email = prefs.getString('email');

  if (email == null) {
    print("User is not logged in. Skipping ammonia SNS subscription.");
    return;
  }

  bool hasAmmoniaSensor = await userHasAmmoniaSensor(email);
  if (!hasAmmoniaSensor) {
    print("No NH sensor found in account. Skipping subscription.");
    return;
  }

  print("Subscribing device to ammonia SNS topic with token: $fcmToken");
  const String snsTopicArn =
      'arn:aws:sns:us-east-1:975048338421:CloudSense_Notification_NH';
  const String apiGatewayUrl =
      'https://2u9vg092x5.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'subscribe',
      'snsTopicArn': snsTopicArn,
      'fcmToken': fcmToken,
    });
    print("Sending POST request to subscribe Ammonia: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode == 200) {
      print("Device subscribed to ammonia SNS topic successfully.");
      await prefs.setBool('isAmmoniaTokenSubscribed', true);
    } else {
      print("Failed to subscribe to ammonia SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error subscribing to ammonia SNS topic: $e");
  }
}

Future<void> unsubscribeFromSnsTopic(String fcmToken) async {
  const String apiGatewayUrl =
      'https://2u9vg092x5.execute-api.us-east-1.amazonaws.com/default/sns_api_fcm_updation';

  try {
    var requestBody = jsonEncode({
      'action': 'unsubscribe',
      'fcmToken': fcmToken,
    });
    print("Sending POST request to unsubscribe Ammonia: $requestBody");

    var response = await http.post(
      Uri.parse(apiGatewayUrl),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );
    print("Unsubscribe ammonia API Response: ${response.body}");

    if (response.statusCode == 200) {
      print("Device unsubscribed from ammonia SNS topic successfully.");
    } else {
      print(
          "Failed to unsubscribe from ammonia SNS topic: ${response.statusCode}");
    }
  } catch (e) {
    print("Error unsubscribing from ammonia SNS topic: $e");
  }
}

Future<void> setupNotifications() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const InitializationSettings initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );

  await flutterLocalNotificationsPlugin.initialize(initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
    print("User tapped on notification: ${details.payload}");
  });
}

class UserProvider extends ChangeNotifier {
  String? _userEmail;
  String? _userName;

  String? get userEmail => _userEmail;
  String? get userName => _userName;

  UserProvider() {
    _loadUser();
    refreshAttributes();
  }

  void setUser(String? email, {String? name}) {
    _userEmail = email;
    if (name != null) _userName = name;
    if (email == null) _userName = null; // Clear name on logout
    notifyListeners();
    _saveUser();
    if (email != null && name == null) {
      refreshAttributes();
    }
  }

  void _loadUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userEmail = prefs.getString('email');
    _userName = prefs.getString('name');
    notifyListeners();
  }

  void _saveUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    if (_userEmail != null) {
      await prefs.setString('email', _userEmail!);
    } else {
      await prefs.remove('email');
    }
    if (_userName != null) {
      await prefs.setString('name', _userName!);
    } else {
      await prefs.remove('name');
    }
  }

  Future<void> refreshAttributes() async {
    try {
      var userAttributes = await Amplify.Auth.fetchUserAttributes();
      String? email;
      String? name;
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
        }
        if (attr.userAttributeKey.key == 'name') {
          name = attr.value;
        } else if (attr.userAttributeKey.key == 'preferred_username' && name == null) {
          name = attr.value;
        }
      }
      if (email != null) _userEmail = email;
      if (name != null) _userName = name;
      if (email != null || name != null) {
        notifyListeners();
        _saveUser();
      }
    } catch (_) {}
  }
}

Map<String, dynamic>? _globalGraphArgs;

Future<void> saveGraphArgs(Map<String, dynamic> args) async {
  _globalGraphArgs = args;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastGraphArgs', jsonEncode(args));
    print("Saved graph args: $args");
  } catch (e) {
    print("Error saving graph args: $e");
  }
}

Future<Map<String, dynamic>?> loadGraphArgs() async {
  if (_globalGraphArgs != null) return _globalGraphArgs;
  try {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('lastGraphArgs');
    if (data != null) {
      print("Loaded graph args: $data");
      _globalGraphArgs = jsonDecode(data);
      return _globalGraphArgs;
    }
  } catch (e) {
    print("Error loading graph args: $e");
  }
  return null;
}

Map<String, dynamic>? _globalQualityArgs;

Future<void> saveQualityArgs(Map<String, dynamic> args) async {
  _globalQualityArgs = args;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastQualityArgs', jsonEncode(args));
    print("Saved quality args: $args");
  } catch (e) {
    print("Error saving quality args: $e");
  }
}

Future<Map<String, dynamic>?> loadQualityArgs() async {
  if (_globalQualityArgs != null) return _globalQualityArgs;
  try {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('lastQualityArgs');
    if (data != null) {
      print("Loaded quality args: $data");
      _globalQualityArgs = jsonDecode(data);
      return _globalQualityArgs;
    }
  } catch (e) {
    print("Error loading quality args: $e");
  }
  return null;
}

Map<String, dynamic>? _globalNowcastingArgs;

Future<void> saveNowcastingArgs(Map<String, dynamic> args) async {
  _globalNowcastingArgs = args;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastNowcastingArgs', jsonEncode(args));
  } catch (_) {}
}

Future<Map<String, dynamic>?> loadNowcastingArgs() async {
  if (_globalNowcastingArgs != null) return _globalNowcastingArgs;
  try {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('lastNowcastingArgs');
    if (data != null) {
      _globalNowcastingArgs = jsonDecode(data);
      return _globalNowcastingArgs;
    }
  } catch (_) {}
  return null;
}


Future<Map<String, dynamic>?> loadBuffaloArgs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('buffaloArgs');
    if (data != null) return jsonDecode(data);
  } catch (e) {}
  return null;
}

Future<Map<String, dynamic>?> loadCowArgs() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cowArgs');
    if (data != null) return jsonDecode(data);
  } catch (e) {}
  return null;
}

Future<String> determineInitialRoute() async {
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastRoute = prefs.getString('lastRoute');

    // ← ADD: verify user is still logged in before trusting lastRoute
    try {
      var userAttributes = await Amplify.Auth.fetchUserAttributes();
      String? email;
      String? name;
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
        }
        if (attr.userAttributeKey.key == 'name') {
          name = attr.value;
        } else if (attr.userAttributeKey.key == 'preferred_username' && name == null) {
          name = attr.value;
        }
      }
      if (email != null) {
        await prefs.setString('email', email); // always refresh email on app start
      }
      if (name != null) {
        await prefs.setString('name', name);
      }
    } catch (_) {}

    if (lastRoute != null && lastRoute.isNotEmpty) {
      if (lastRoute == '/login') return '/ksdma';
      return lastRoute;
    }
    return '/ksdma';
  } catch (e) {
    print('Defaulting to KSDMA portal: $e');
    return '/ksdma';
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setPathUrlStrategy();

  await setupNotifications();

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyC8VgXQxru1bzlbLTUvOc4o490gxDc_MDQ",
        authDomain: "cloudsense-cba8a.firebaseapp.com",
        projectId: "cloudsense-cba8a",
        storageBucket: "cloudsense-cba8a.firebasestorage.app",
        messagingSenderId: "209940213885",
        appId: "1:209940213885:web:1b68309df786c4c30fc114",
        measurementId: "G-HMXS0HV32J",
      ),
    );
  } else {
    await Firebase.initializeApp();
    await PushNotifications().initNotifications();
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: false,
    badge: false,
    sound: false,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  try {
    await Amplify.addPlugin(AmplifyAuthCognito());
    await Amplify.configure(amplifyconfig);
  } catch (e) {
    print('Could not configure Amplify: $e');
  }

  await manageNotificationSubscription();

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print("FCM token refreshed: $newToken");
    await manageNotificationSubscription();
  });

  String initialRoute = await determineInitialRoute();

  // ── Boost image cache: prevents repeated decode after navigation ──────────
  PaintingBinding.instance.imageCache.maximumSize = 1000;            // images
  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 << 20;  // 200 MB

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MyApp(initialRoute: initialRoute),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Cloud Sense Vis',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.isDarkMode
          ? ThemeData.dark().copyWith(
              textTheme: ThemeData.dark().textTheme.apply(
                    fontFamily: 'OpenSans',
                  ),
            )
          : ThemeData.light().copyWith(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D47A1),
                surface: Colors.white,
                background: const Color(0xFFF8F9FA),
                onSurface: const Color(0xFF1A1A1A),
                onBackground: const Color(0xFF1A1A1A),
              ),
              textTheme: ThemeData.light().textTheme.apply(
                    fontFamily: 'OpenSans',
                    bodyColor: const Color(0xFF1A1A1A),
                    displayColor: const Color(0xFF1A1A1A),
                  ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                elevation: 3,
              ),
              cardTheme: CardThemeData(
                color: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
      initialRoute: initialRoute,
      onGenerateRoute: (settings) {
        Widget pageContent;

        switch (settings.name) {
          case '/':
          case '/ksdma':
          case '/citizen-weather':
          case '/kerala-weather':
            pageContent = const KsdmaPortalMainPage();
            break;
          case '/login':
            pageContent = SignInSignUpScreen();
            break;
          case '/privacy':
            pageContent = const PrivacyPolicyPage();
            break;
          case '/terms':
            pageContent = const TermsOfServicePage();
            break;
          case '/accountinfo':
            pageContent = AccountInfoPage();
            break;
          case '/deviceinfo':
            pageContent = MapPage();
            break;


          case '/nowcasting':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null && (args['deviceName'] ?? '').toString().isNotEmpty) {
              saveNowcastingArgs(args);
              pageContent = WeatherNowcastingPage(
                deviceName: args['deviceName'] ?? 'ANNAM_CP02',
                sequentialName: args['sequentialName'] ?? 'Annam Weather Sensor',
              );
            } else {
              pageContent = FutureBuilder<Map<String, dynamic>?>(
                future: loadNowcastingArgs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final lastArgs = snapshot.data;
                  final devName = (lastArgs?['deviceName'] ?? '').toString().isNotEmpty
                      ? lastArgs!['deviceName'].toString()
                      : 'ANNAM_CP02';
                  final seqName = (lastArgs?['sequentialName'] ?? '').toString().isNotEmpty
                      ? lastArgs!['sequentialName'].toString()
                      : 'Annam Weather Sensor';

                  return WeatherNowcastingPage(
                    deviceName: devName,
                    sequentialName: seqName,
                  );
                },
              );
            }
            break;

          case "/probe":
            pageContent = const ProductPage(sensorIndex: 4);
            break;
          case "/atrh":
            pageContent = const ProductPage(sensorIndex: 3);
            break;
          case "/windsensor":
            pageContent = const ProductPage(sensorIndex: 2);
            break;
          case "/raingauge":
            pageContent = const ProductPage(sensorIndex: 1);
            break;
          case "/datalogger":
            pageContent = const ProductPage(sensorIndex: 0);
            break;
          // case "/gateway":
          //   pageContent = const ProductPage(sensorIndex: 5);

          //   break;
          // case "/soilspectra":
          //   pageContent = const ProductPage(sensorIndex: 6);
          //   break;

          case '/admin':
            // Read from prefs-backed provider OR fall back to saved pref
            final userProvider =
                Provider.of<UserProvider>(context, listen: false);
            // UserProvider._loadUser() is async — email may be null on first frame
            // So pass it; AdminPage should also check SharedPreferences itself
            pageContent = AdminPage(adminEmail: userProvider.userEmail);
            break;
          case '/admin/health':
            pageContent = const DeviceHealthStatusPage();
            break;
          case '/admin/health/quality-diagnostics':
            final args = settings.arguments as Map<String, dynamic>?;
            final isDark = themeProvider.isDarkMode;

            if (args != null) {
              saveQualityArgs(args);
              pageContent = QualityDiagnosticsPage(
                deviceId: args['deviceId'] ?? '',
                deviceIdTopic: args['deviceIdTopic'] ?? '',
                displayName: args['displayName'] ?? '',
                isDark: args['isDark'] ?? isDark,
                fromAdminPage: args['fromAdminPage'] == true,
              );
            } else {
              pageContent = FutureBuilder<Map<String, dynamic>?>(
                future: loadQualityArgs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  final finalArgs = snapshot.data;
                  if (finalArgs == null ||
                      (finalArgs['deviceId'] ?? '').isEmpty) {
                    return Scaffold(
                      appBar: AppBar(title: const Text("Quality Diagnostics")),
                      body: const Center(child: Text("No diagnostic data found")),
                    );
                  }
                  return QualityDiagnosticsPage(
                    deviceId: finalArgs['deviceId'] ?? '',
                    deviceIdTopic: finalArgs['deviceIdTopic'] ?? '',
                    displayName: finalArgs['displayName'] ?? '',
                    isDark: finalArgs['isDark'] ?? isDark,
                  );
                },
              );
            }
            break;

          case '/devicelist':
            pageContent = DataDisplayPage();
            break;
          case '/devicemapinfo':
            pageContent = DeviceMapScreen();
            break;
          case '/devicegraph':
          case '/admin/devicegraph':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              saveGraphArgs(args);
              pageContent = DeviceGraphPage(
                deviceName: args['deviceName'] ?? '',
                sequentialName: args['sequentialName'],
                selectedDate: args['selectedDate'],
                period: args['period'],
                anomalyName: args['anomalyName'],
                backgroundImagePath: args['backgroundImagePath'] ??
                    'assets/backgroundd.jpg',
              );
            } else {
              pageContent = FutureBuilder<Map<String, dynamic>?>(
                future: loadGraphArgs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  final finalArgs = snapshot.data;
                  if (finalArgs == null ||
                      (finalArgs['deviceName'] ?? '').isEmpty) {
                    return Scaffold(
                      appBar: AppBar(title: const Text("Device Graph")),
                      body: const Center(child: Text("No device data found")),
                    );
                  }
                  return DeviceGraphPage(
                    deviceName: finalArgs['deviceName'] ?? '',
                    sequentialName: finalArgs['sequentialName'],
                    selectedDate: finalArgs['selectedDate'],
                    period: finalArgs['period'],
                    anomalyName: finalArgs['anomalyName'],
                    backgroundImagePath: finalArgs['backgroundImagePath'] ??
                        'assets/backgroundd.jpg',
                  );
                },
              );
            }
            break;
          case '/buffalodata':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              pageContent = BuffaloData(
                startDateTime: args['startDateTime'] ?? DateTime.now(),
                endDateTime: args['endDateTime'] ?? DateTime.now().add(const Duration(days: 1)),
                nodeId: args['nodeId'] ?? '',
              );
            } else {
              pageContent = FutureBuilder<Map<String, dynamic>?>(
                future: loadBuffaloArgs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  final finalArgs = snapshot.data;
                  if (finalArgs == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text("Buffalo Data")),
                      body: const Center(child: Text("No data found")),
                    );
                  }
                  return BuffaloData(
                    startDateTime: finalArgs['startDateTime'] != null ? DateTime.parse(finalArgs['startDateTime']) : DateTime.now(),
                    endDateTime: finalArgs['endDateTime'] != null ? DateTime.parse(finalArgs['endDateTime']) : DateTime.now().add(const Duration(days: 1)),
                    nodeId: finalArgs['nodeId'] ?? '',
                  );
                },
              );
            }
            break;
          case '/cowdata':
            final args = settings.arguments as Map<String, dynamic>?;
            if (args != null) {
              pageContent = CowData(
                startDateTime: args['startDateTime'] ?? DateTime.now(),
                endDateTime: args['endDateTime'] ?? DateTime.now().add(const Duration(days: 1)),
                nodeId: args['nodeId'] ?? '',
              );
            } else {
              pageContent = FutureBuilder<Map<String, dynamic>?>(
                future: loadCowArgs(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  final finalArgs = snapshot.data;
                  if (finalArgs == null) {
                    return Scaffold(
                      appBar: AppBar(title: const Text("Cow Data")),
                      body: const Center(child: Text("No data found")),
                    );
                  }
                  return CowData(
                    startDateTime: finalArgs['startDateTime'] != null ? DateTime.parse(finalArgs['startDateTime']) : DateTime.now(),
                    endDateTime: finalArgs['endDateTime'] != null ? DateTime.parse(finalArgs['endDateTime']) : DateTime.now().add(const Duration(days: 1)),
                    nodeId: finalArgs['nodeId'] ?? '',
                  );
                },
              );
            }
            break;



          default:
            pageContent = HomePage();
        }

        return MaterialPageRoute(
          builder: (context) => SelectionArea(child: pageContent),
          settings: settings,
        );
      },
      navigatorObservers: [routeObserver, LastRouteObserver()],
    );
  }
}

class LastRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  void _saveLastRoute(Route<dynamic> route) async {
    if (route.settings.name != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('lastRoute', route.settings.name!);
      print("Saved last route: ${route.settings.name}");
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _saveLastRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _saveLastRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _saveLastRoute(previousRoute);
  }
}
