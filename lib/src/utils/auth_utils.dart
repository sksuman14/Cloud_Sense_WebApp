import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthUtils {
  /// Returns true if the currently signed-in user authenticated via Google.
  /// Checks the Cognito 'identities' attribute — set only for federated logins.
  static Future<bool> _isGoogleUser() async {
    try {
      final attributes = await Amplify.Auth.fetchUserAttributes();
      for (final attr in attributes) {
        if (attr.userAttributeKey.key == 'identities') {
          if (attr.value.toLowerCase().contains('google')) return true;
        }
      }
    } catch (e) {
      print('Could not detect login method: $e');
    }
    return false;
  }

  static Future<void> handleLogout(BuildContext context) async {
    // Detect login method BEFORE signing out — session is still active here.
    final isGoogle = await _isGoogleUser();
    print('DEBUG: isGoogleUser = $isGoogle');

    try {
      await Amplify.Auth.signOut();
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      try {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await unsubscribeFromGpsSnsTopic(fcmToken);
          // await unsubscribeFromSnsTopic(fcmToken);
        }
      } catch (fcmError) {
        print('FCM unsubscribe error (possibly blocked by browser): $fcmError');
      }

      userProvider.setUser(null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out successfully')),
      );

      // For Google sign-in, Cognito performs a full-page browser redirect
      // to the configured SignOutRedirectURI (/home) automatically.
      // We must NOT push /login here or it will flash before Cognito overrides.
      if (!isGoogle) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('Error during logout: $e');
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logged out with some errors')),
      );

      if (!isGoogle) {
        Navigator.of(context, rootNavigator: true)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }
}
