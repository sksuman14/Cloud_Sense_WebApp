import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';

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
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Validation Error',
          message: 'User email is not available.',
          isError: true,
        );
      }
      return false;
    }

    if (!isValidDeviceId(deviceId)) {
      if (context.mounted) {
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Invalid Device',
          message: 'Invalid Device ID format or prefix.',
          isError: true,
        );
      }
      return false;
    }

    // --- 2. Check if device is already registered (only if allDevices is provided) ---
    if (allDevices != null &&
        allDevices.any((d) => d['DeviceId'] == deviceId)) {
      if (context.mounted) {
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Already Registered',
          message: 'Device $deviceId is already registered in the system.',
          isError: true,
        );
      }
      return false;
    }

    // --- 3. Make the API Call ---
    final String apiUrl =
        "https://ymfmk699j5.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_add_devices?email_id=$email&device_id=$deviceId";

    // Show non-dismissible loading spinner so user knows add is in progress
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF10B981)),
                  SizedBox(height: 16),
                  Text(
                    'Adding device...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Please wait',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));

      // Close spinner
      if (context.mounted) Navigator.pop(context);
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

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: success ? 'Device Added Successfully' : 'Failed to Add Device',
            message: message,
            isError: !success,
          );
        }
        return success;
      } else {
        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'API Error',
            message: 'Failed to add device (Status ${response.statusCode})',
            isError: true,
          );
        }
        return false;
      }
    } catch (e) {
      // Close spinner on error too
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Error',
          message: 'An error occurred: $e',
          isError: true,
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

    // ── Handle SOBHA-NNN, WS_SHOBHA_NNN, WS_SOBHA_NNN ────────────────────────
    if (input.startsWith('SOBHA-') ||
        input.startsWith('SOBHA_') ||
        input.startsWith('WS_SHOBHA_') ||
        input.startsWith('WS_SOBHA_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['SH${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-PB-NNN (Punjab stations display name) ───────────────────
    if (input.startsWith('ANNAM-PB-') ||
        input.startsWith('ANNAM_PB_') ||
        input.startsWith('ANNAM/PUNJAB/') ||
        input.startsWith('WS_PUNJAB_') ||
        input.startsWith('PJWS_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        final pad = cleanDigits.length == 1 ? cleanDigits.padLeft(2, '0') : cleanDigits;
        return ['PJ$pad'];
      }
      return [];
    }

    // ── Handle ANNAM-KL-NNN (Kerala stations display name) ───────────────────
    if (input.startsWith('ANNAM-KL-') ||
        input.startsWith('ANNAM_KL_') ||
        input.startsWith('ANNAM/KERALA/') ||
        input.startsWith('ANNAM6')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        final pad = cleanDigits.length == 1 ? cleanDigits.padLeft(2, '0') : cleanDigits;
        return ['KR$pad'];
      }
      return [];
    }

    // ── Handle ANNAM-0126-NNN (WJ sensors display name) ──────────────────────
    if (input.startsWith('ANNAM-0126-') ||
        input.startsWith('ANNAM0126_') ||
        input.startsWith('ANNAM0126-')) {
      final suffix = input.substring(input.lastIndexOf(RegExp(r'[-_]')) + 1);
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['WJ${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-0226-NNN (WF sensors display name) ──────────────────────
    if (input.startsWith('ANNAM-0226-') ||
        input.startsWith('ANNAM0226_') ||
        input.startsWith('ANNAM0226-')) {
      final suffix = input.substring(input.lastIndexOf(RegExp(r'[-_]')) + 1);
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['WF${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-0426-NNN (WA sensors display name) ──────────────────────
    if (input.startsWith('ANNAM-0426-') ||
        input.startsWith('ANNAM0426_') ||
        input.startsWith('ANNAM0426-')) {
      final suffix = input.substring(input.lastIndexOf(RegExp(r'[-_]')) + 1);
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['WA${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle TS-0526-NNN or ANNAM-0526-NNN (WM sensors display name) ───────
    if (input.startsWith('TS-0526-') ||
        input.startsWith('TS0526_') ||
        input.startsWith('TS0526-') ||
        input.startsWith('ANNAM-0526-') ||
        input.startsWith('ANNAM0526_')) {
      final suffix = input.substring(input.lastIndexOf(RegExp(r'[-_]')) + 1);
      final cleanDigits = suffix.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['WM${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-CPS-NNN or ANNAM/CPS_ format (CPS sensors display name) ──
    if (input.startsWith('ANNAM-CPS-') ||
        input.startsWith('ANNAM-CPS') ||
        input.startsWith('ANNAM/CPS_') ||
        input.startsWith('ANNAM/CPS') ||
        input.startsWith('CPS-') ||
        input.startsWith('CPS_') ||
        input.startsWith('CPS')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['PS${cleanDigits.padLeft(2, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-CP-NNN or ANNAM_CP format (AM sensors display name) ──────
    if (!input.startsWith('ANNAM-CPS') &&
        !input.startsWith('ANNAM/CPS') &&
        (input.startsWith('ANNAM-CP-') ||
         input.startsWith('ANNAM_CP') ||
         input.startsWith('ANNAM-CP'))) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['AM${cleanDigits.padLeft(2, '0')}'];
      }
      return [];
    }

    // ── Handle AWS-TESTING-NNN format ────────────────────────────────────────
    if (input.startsWith('AWS-TESTING-') || input.startsWith('AWS_TESTING_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['AT${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle AWS-NNN or AWS_NNN format ─────────────────────────────────────
    if (input.startsWith('AWS-') || input.startsWith('AWS_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['AW${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle WINDS-NNN or WINDS_NNN format ─────────────────────────────────
    if (input.startsWith('WINDS-') || input.startsWith('WINDS_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['WN${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle JIO-WINDS-NNN or JIO_WINDS_NNN format ─────────────────────────
    if (input.startsWith('JIO-WINDS-') ||
        input.startsWith('JIO_WINDS_') ||
        input.startsWith('JW-') ||
        input.startsWith('JW_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['JW${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-PC-NNN or ANNAM/PC_NNN format ───────────────────────────
    if (input.startsWith('ANNAM-PC-') ||
        input.startsWith('ANNAM/PC_') ||
        input.startsWith('ANNAM4')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['PC${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle ANNAM-GPC-NNN or ANNAM/GPC_NNN format ─────────────────────────
    if (input.startsWith('ANNAM-GPC-') ||
        input.startsWith('ANNAM/GPC_') ||
        input.startsWith('ANNAM5')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['GP${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle TESTING-NNN or TS-NNN format (Testing group display name) ───────────
    if (input.startsWith('TESTING-') ||
        input.startsWith('TESTING_') ||
        input.startsWith('TESTING') ||
        input.startsWith('TS-') ||
        input.startsWith('TS_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        final paddedDigits = cleanDigits.padLeft(3, '0');
        return ['WM$paddedDigits', 'WT$paddedDigits', 'CP$paddedDigits'];
      }
      return [];
    }

    // ── Handle DM-NNN or DM_NNN format (Demo sensors display name) ───────────
    if (input.startsWith('DM-') || input.startsWith('DM_')) {
      final cleanDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanDigits.isNotEmpty) {
        return ['DM${cleanDigits.padLeft(3, '0')}'];
      }
      return [];
    }

    // ── Handle standard [PREFIX]-[DIGITS] or [PREFIX]_[DIGITS] ───────────────
    final standardMatch = RegExp(r'^([A-Z]{2})[-_]?(\d+)$').firstMatch(input);
    if (standardMatch != null) {
      final p = standardMatch.group(1)!;
      final d = standardMatch.group(2)!;
      if (validPrefixes.contains(p)) {
        return ['$p${d.padLeft(3, '0')}'];
      }
    }

    // ── Extract trailing digits for legacy ANNAM formats ─────────────────────
    final digitsMatch = RegExp(r'\d+$').firstMatch(input);
    if (digitsMatch == null) return [];
    final digits = digitsMatch.group(0)!;
    final paddedDigits = digits.padLeft(3, '0');
    final idInt = int.tryParse(digits) ?? 0;

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
    } else if (input.startsWith('ANNAM')) {
      // ANNAM standard prefixes (WJ, WA, WF, PJ, KR, AW, plus special cases)
      final pad2 = digits.length == 1 ? digits.padLeft(2, '0') : digits;
      if (idInt == 1) return ['CP001', 'PJ01', 'KR01', 'AW001'];
      if (idInt == 2) return ['CF002', 'PJ02', 'KR02', 'AW002'];
      if (idInt == 7) return ['WA007', 'SW007', 'PJ07', 'KR07', 'AW007'];
      if (idInt == 13) return ['SW013', 'PJ13', 'KR13', 'AW013'];
      return [
        'WJ$paddedDigits',
        'WA$paddedDigits',
        'WF$paddedDigits',
        'PJ$pad2',
        'KR$pad2',
        'AW$paddedDigits',
      ];
    }
    return [];
  }

  // ── NEW: UI helper to show a choice dialog for ambiguous prefixes ────────
  static Future<String?> showPrefixChoiceDialog(
    BuildContext context,
    List<String> candidates,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Icon(
                Icons.alt_route,
                size: 20,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Text(
                "Select Device Topic",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final id = candidates[index];
                final displayId = toDisplayId(id);
                final topic = DevicePrefixUtils.buildTopicFromSensorName(id).split('#').last;

                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.pop(context, id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.alt_route,
                            size: 18,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayId,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Topic: $topic",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ],
                    ),
                  ),
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
