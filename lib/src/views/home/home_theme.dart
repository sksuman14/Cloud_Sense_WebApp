import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
  }

  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }
}

// Helper function to determine a GRADIENT based on temperature
Gradient getTemperatureGradient(dynamic tempValue) {
  // Default gradient for null or invalid values
  const defaultGradient = LinearGradient(
    colors: [Color(0xFF868F96), Color(0xFF596164)], // A nice grey gradient
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  if (tempValue == null) {
    return defaultGradient;
  }

  final double? temp = double.tryParse(tempValue.toString());

  if (temp == null) {
    return defaultGradient;
  }

  // Define gradients inspired by weather visuals 🌡️
  if (temp > 35) {
    // Very Hot: Deep red to a fiery orange
    return const LinearGradient(
      colors: [Color(0xffc1121f), Color(0xfffca311)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 30) {
    // Hot: Reddish to a warm orange
    return const LinearGradient(
      colors: [Color(0xffe63946), Color(0xfff77f00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 20) {
    // Warm: Sunny orange to a bright yellow
    return const LinearGradient(
      colors: [Color(0xffffa62b), Color(0xffffd700)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (temp > 10) {
    // Mild: Light green to a soft yellow
    return const LinearGradient(
      colors: [Color(0xffa7c957), Color(0xfff2e8cf)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    // Cool: Sky blue to a gentle cyan
    return const LinearGradient(
      colors: [Color(0xff72ddf7), Color(0xffa2d2ff)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
