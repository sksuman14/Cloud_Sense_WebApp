import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Initialize Flutter Local Notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Background notification handler (when the app is in the background or terminated)
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print(
      " Background Notification: ${message.notification?.title} - ${message.notification?.body}");
  showNotification(message); // Ensure background notifications are shown
}

// Function to display local notifications
void showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;

  if (notification != null) {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'high_importance_channel', // Same ID as defined in `main.dart`
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const DarwinNotificationDetails darwinPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: darwinPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformChannelSpecifics,
      payload: message.data['ammonia_level'] ?? '',
    );
  }
}

class PushNotifications {
  final _firebaseMessaging = FirebaseMessaging.instance;

  // Initialize Firebase Cloud Messaging (FCM) notifications
  Future<void> initNotifications() async {
    // Request user permission for push notifications (iOS/Android)
    try {
      await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          print("⚠️ Notification permission request timed out");
          return const NotificationSettings(
            authorizationStatus: AuthorizationStatus.notDetermined,
            alert: AppleNotificationSetting.disabled,
            announcement: AppleNotificationSetting.disabled,
            badge: AppleNotificationSetting.disabled,
            carPlay: AppleNotificationSetting.disabled,
            criticalAlert: AppleNotificationSetting.disabled,
            sound: AppleNotificationSetting.disabled,
            lockScreen: AppleNotificationSetting.disabled,
            notificationCenter: AppleNotificationSetting.disabled,
            showPreviews: AppleShowPreviewSetting.never,
            timeSensitive: AppleNotificationSetting.disabled,
            providesAppNotificationSettings: AppleNotificationSetting.disabled,
          );
        },
      );
    } catch (e) {
      print("⚠️ Error requesting notification permission: $e");
    }

    // Get and print FCM token (with timeout so it never hangs waiting for APNs on iOS)
    try {
      final fcmToken = await _firebaseMessaging.getToken().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          print("⚠️ FCM getToken timed out (APNs token may not be ready yet)");
          return null;
        },
      );
      print("🔑 FCM Token: $fcmToken");
    } catch (e) {
      print("⚠️ Error retrieving FCM token: $e");
    }

    // Set up background notification handler
    try {
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    } catch (e) {
      print("⚠️ Error setting background message handler: $e");
    }

    // Listen for foreground notifications (when the app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print(
          " Foreground Notification: ${message.notification?.title} - ${message.notification?.body}");
      if (message.data.isNotEmpty) {
        showNotification(message); // Show notification only if SNS sends one
      }
    });

    // Listen for when the user taps a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 User tapped on notification: ${message.data}");
    });

    // Initialize Local Notifications
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      print("⚠️ Error initializing flutterLocalNotificationsPlugin: $e");
    }
  }
}
