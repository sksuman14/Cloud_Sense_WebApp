import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class NavigationUtils {
  /// Checks if either Control or Command (Meta) key is currently pressed.
  static bool get isCtrlPressed {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  /// Navigates to a named route. If [kIsWeb] is true and a control key is pressed,
  /// it opens the route in a new tab using [url_launcher] instead.
  static Future<void> navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
    bool isReplacement = false,
    bool removeUntil = false,
  }) async {
    if (kIsWeb && isCtrlPressed) {
      if (arguments != null && arguments is Map<String, dynamic>) {
        final prefs = await SharedPreferences.getInstance();
        if (routeName == '/devicegraph' || routeName == '/admin/devicegraph') {
          await prefs.setString('lastGraphArgs', json.encode(arguments));
        } else if (routeName == '/admin/health/quality-diagnostics') {
          await prefs.setString('lastQualityArgs', json.encode(arguments));
        } else if (routeName == '/buffalodata') {
          await prefs.setString(
              'buffaloArgs',
              json.encode({
                ...arguments,
                'startDateTime': arguments['startDateTime']?.toIso8601String(),
                'endDateTime': arguments['endDateTime']?.toIso8601String(),
              }));
        } else if (routeName == '/cowdata') {
          await prefs.setString(
              'cowArgs',
              json.encode({
                ...arguments,
                'startDateTime': arguments['startDateTime']?.toIso8601String(),
                'endDateTime': arguments['endDateTime']?.toIso8601String(),
              }));
        } else if (routeName == '/devicelist/device_details') {
          await prefs.setString('deviceDetailsArgs', json.encode(arguments));
        }
      }

      final url = Uri.base.resolve(routeName);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, webOnlyWindowName: '_blank');
      }
    } else {
      if (removeUntil) {
        Navigator.pushNamedAndRemoveUntil(context, routeName, (route) => false,
            arguments: arguments);
      } else if (isReplacement) {
        Navigator.pushReplacementNamed(context, routeName,
            arguments: arguments);
      } else {
        Navigator.pushNamed(context, routeName, arguments: arguments);
      }
    }
  }
}
