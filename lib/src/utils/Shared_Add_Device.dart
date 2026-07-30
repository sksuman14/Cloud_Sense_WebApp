import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

class DeviceUtils {
  static const List<String> rawAdminEmails = [
    'sejalsankhyan2001@gmail.com',
    'pallavikrishnan01@gmail.com',
    'officeharsh25@gmail.com',
    'info@ssmicroelectronics.co.in',
    'sksuman14@gmail.com',
    'annam.aicloud@gmail.com',
    'ahashivam2001@gmail.com'
  ];

  static final List<String> adminEmails =
      rawAdminEmails.map((e) => e.trim().toLowerCase()).toList();

  static bool isSuperAdmin(String? currentUserEmail) {
    return currentUserEmail != null &&
        adminEmails.contains(currentUserEmail.trim().toLowerCase());
  }

  // ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──
  static String toDisplayId(String internalSensorName) =>
      DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

  static bool _isAnnamSensor(String internalSensorName) =>
      DevicePrefixUtils.isAnnamCoreSensor(internalSensorName);

  // ✅ NEW: The centralized function to add a device via API call
  static Future<bool> addDeviceToUser({
    required BuildContext context,
    required String? email,
    required String deviceId,
    List<Map<String, dynamic>>? allDevices, // now optional
  }) async {
    // --- 1. Validate Inputs ---
    if (email == null || email.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("User email is not available."),
              backgroundColor: Colors.orange),
        );
      }
      return false;
    }

    if (!isValidDeviceId(deviceId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Device ID format or prefix.")),
        );
      }
      return false;
    }

    // --- 2. Check if device is already registered (only if allDevices is provided) ---
    if (allDevices != null &&
        allDevices.any((d) => d['DeviceId'] == deviceId)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "Device $deviceId is already registered in the system.")),
        );
      }
      return false;
    }

    // --- 3. Make the API Call ---
    final String apiUrl =
        "https://ymfmk699j5.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_add_devices?email_id=$email&device_id=$deviceId";

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (!context.mounted) return false;

      if (response.statusCode == 200) {
        String displayId = toDisplayId(deviceId);
        String message = "Device $displayId added successfully to $email.";
        bool success = false;
        try {
          final responseBody = json.decode(response.body);
          if (responseBody['message']
                  ?.toString()
                  .toLowerCase()
                  .contains('success') ==
              true) {
            success = true;
          } else {
            message =
                "Failed to add device: ${responseBody['message'] ?? 'Unknown error'}";
          }
        } on FormatException {
          if (response.body.toLowerCase().contains('success')) {
            success = true;
          } else {
            message = "Failed to add device: ${response.body}";
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        return success;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  "API Error: Failed to add device (Status ${response.statusCode})"),
              backgroundColor: Colors.red),
        );
        return false;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("An error occurred: $e"),
              backgroundColor: Colors.red),
        );
      }
      return false;
    }
  }

  // --- YOUR ORIGINAL FUNCTIONS (UNCHANGED) ---

  static String getSensorType(String deviceId) {
    return DevicePrefixUtils.getSensorType(deviceId);
  }

  static String getSensorPrefix(String deviceId) {
    if (deviceId.length < 2) return '';
    String prefix = deviceId.substring(0, 2);
    return validPrefixes.contains(prefix) ? prefix : 'RS';
  }

  static bool isValidDeviceId(String deviceId) {
    return DevicePrefixUtils.isValidDeviceId(deviceId);
  }

  // ── Helper to resolve ANNAM display names back to internal IDs ─────────────
  static List<String> getPossibleInternalIDs(String input) {
    input = input.trim().toUpperCase();

    // ── Handle WS_SHOBHA_NNN format (Shobha sensors display name) ─────────────
    if (input.startsWith('WS_SHOBHA_')) {
      final suffix = input.substring('WS_SHOBHA_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['SH$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM0126_NNN format (WJ sensors display name) ─────────────────
    if (input.startsWith('ANNAM0126_')) {
      final suffix = input.substring('ANNAM0126_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['WJ$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM_CP format (AM sensors display name) ───────────────────
    if (input.startsWith('ANNAM_CP')) {
      final suffix = input.substring('ANNAM_CP'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(2, '0');
        return ['AM$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM0226_NNN format (WF sensors display name) ─────────────────
    if (input.startsWith('ANNAM0226_')) {
      final suffix = input.substring('ANNAM0226_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['WF$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM/CPS_NNN format (CPS sensors display name) ────────────────
    if (input.startsWith('ANNAM/CPS_')) {
      final suffix = input.substring('ANNAM/CPS_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['PS$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM0426_NNN format (WA sensors display name) ─────────────────
    if (input.startsWith('ANNAM0426_')) {
      final suffix = input.substring('ANNAM0426_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['WA$paddedDigits'];
      }
      return [];
    }

    // ── Handle ANNAM0526_NNN or TS0526_NNN format (WM sensors display name) ───
    if (input.startsWith('ANNAM0526_') || input.startsWith('TS0526_')) {
      final prefixLen = input.startsWith('ANNAM0526_')
          ? 'ANNAM0526_'.length
          : 'TS0526_'.length;
      final suffix = input.substring(prefixLen);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['WM$paddedDigits'];
      }
      return [];
    }

    // ── Extract trailing digits for all other ANNAM formats ───────────────────
    final digitsMatch = RegExp(r'\d+$').firstMatch(input);
    if (digitsMatch == null) return [];
    final digits = digitsMatch.group(0)!;
    final paddedDigits = digits.padLeft(3, '0');
    final idInt = int.tryParse(digits) ?? 0;

    // ── Handle TS_NNN format (Testing group display name) ───────────────────
    if (input.startsWith('TS_')) {
      return ['WT$paddedDigits', 'CP$paddedDigits'];
    }

    // ── Handle DM_NNN format (Demo sensors display name) ─────────────────────
    if (input.startsWith('DM_')) {
      return ['DM$paddedDigits'];
    }

    // ── Handle AWS_TESTING_NNN format (AWS Testing sensors display name) ─────
    if (input.startsWith('AWS_TESTING_')) {
      final suffix = input.substring('AWS_TESTING_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final pd = digitsOnly.group(0)!.padLeft(3, '0');
        return ['AT$pd'];
      }
      return [];
    }

    // ── Handle Winds_NNN format (Winds sensors display name) ───────────────────
    if (input.startsWith('WINDS_')) {
      return ['WN$paddedDigits'];
    }

    // ── Handle JIO_WINDS_NNN format ───────────────────
    if (input.startsWith('JIO_WINDS_')) {
      final suffix = input.substring('JIO_WINDS_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['JW$paddedDigits'];
      }
      return [];
    }

    // ── Handle JW_NNN format ───────────────────
    if (input.startsWith('JW_')) {
      final suffix = input.substring('JW_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        final paddedDigits = digitsOnly.group(0)!.padLeft(3, '0');
        return ['JW$paddedDigits'];
      }
      return [];
    }

    // Logic based on admin_page.dart categorization
    if (input.startsWith('ANNAM1')) {
      // SSMET: NA, KJ, SM, SW (except 007, 013)
      return [
        'NA$paddedDigits',
        'KJ$paddedDigits',
        'SM$paddedDigits',
        'SW$paddedDigits',
      ];
    } else if (input.startsWith('ANNAM2')) {
      // Testing: CP (except 001), plus WT
      return ['CP$paddedDigits', 'WT$paddedDigits'];
    } else if (input.startsWith('ANNAM3')) {
      // IT
      return ['IT$paddedDigits'];
    } else if (input.startsWith('ANNAM4') || input.startsWith('ANNAM/PC_')) {
      // PC sensors (display name: ANNAM4NNN or ANNAM/PC_NNN)
      return ['PC$paddedDigits'];
    } else if (input.startsWith('ANNAM6') ||
        input.startsWith('ANNAM/KERALA/')) {
      if (input.startsWith('ANNAM/KERALA/WS_')) {
        final suffix = input.substring('ANNAM/KERALA/WS_'.length);
        final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
        if (digitsOnly != null) {
          return ['KRWS_${digitsOnly.group(0)!}'];
        }
      }
      // Fallback for ANNAM6NNN or ANNAM/KERALA/NNN
      return ['KR$paddedDigits'];
    } else if (input.startsWith('AWS_')) {
      final suffix = input.substring('AWS_'.length);
      final digitsOnly = RegExp(r'^\d+').firstMatch(suffix);
      if (digitsOnly != null) {
        return ['AW${digitsOnly.group(0)!.padLeft(3, '0')}'];
      }
      return ['AW$paddedDigits'];
    } else if (input.startsWith('ANNAM5') || input.startsWith('ANNAM/GPC_')) {
      // PC sensors (display name: ANNAM4NNN or ANNAM/PC_NNN)
      return ['GP$paddedDigits'];
    } else if (input.startsWith('ANNAM/CPS_')) {
      return ['PS$paddedDigits'];
    } else if (input.startsWith('ANNAM')) {
      // ANNAM standard prefixes (CF, WJ, plus special cases)
      if (idInt == 1) return ['CP001'];
      if (idInt == 7) return ['SW007'];
      if (idInt == 13) return ['SW013'];
      return ['CF$paddedDigits', 'WJ$paddedDigits'];
    }
    return [];
  }

  // ── NEW: UI helper to show a choice dialog for ambiguous prefixes ────────
  static Future<String?> showPrefixChoiceDialog(
    BuildContext context,
    List<String> candidates,
  ) async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Correct Prefix"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: candidates.length,
              itemBuilder: (context, index) {
                final id = candidates[index];
                String displayId = toDisplayId(id);
                return ListTile(
                  title: Text(displayId),
                  subtitle: Text("${getSensorType(id)} ($id)"),
                  onTap: () => Navigator.pop(context, id),
                );
              },
            ),
          ),
        );
      },
    );
  }

  static Future<void> showConfirmationDialog({
    required BuildContext context,
    required String deviceId,
    required Map<String, List<String>> devices,
    required Function onConfirm,
  }) async {
    if (!isValidDeviceId(deviceId)) {
      _showDialog(
        context: context,
        title: 'Invalid Device ID',
        content: 'Enter Valid Device ID.',
      );
      return;
    }
    String sensorType = getSensorType(deviceId);
    String sensorPrefix = getSensorPrefix(deviceId);

    bool deviceExists =
        devices.values.any((deviceList) => deviceList.contains(deviceId));

    if (deviceExists) {
      String displayId = toDisplayId(deviceId);
      _showDialog(
        context: context,
        title: 'Device Already Exists',
        content: 'The device $displayId is already added to your account.',
      );
    } else {
      String displayId = toDisplayId(deviceId);
      _showDialog(
        context: context,
        title: 'Confirm Device Addition',
        content: 'Do you want to add $displayId to your account?',
        actions: [
          TextButton(
            child: Text('No'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: Text('Yes'),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      );
    }
  }

  static void _showDialog({
    required BuildContext context,
    required String title,
    required String content,
    List<Widget>? actions,
  }) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: actions ??
              [
                TextButton(
                  child: Text('OK'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
        );
      },
    );
  }

  static final List<String> validPrefixes = DevicePrefixUtils.validPrefixes;
}
