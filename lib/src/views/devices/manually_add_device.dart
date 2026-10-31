import 'dart:async';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/widgets/interactive_tour/interactive_app_tour.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualEntryPopup extends StatefulWidget {
  final Map<String, List<String>> devices;
  final String? targetUserEmail;
  final VoidCallback? onDeviceAdded;

  ManualEntryPopup({
    Key? key,
    required this.devices,
    this.targetUserEmail,
    this.onDeviceAdded,
  }) : super(key: key);

  @override
  _ManualEntryPopupState createState() => _ManualEntryPopupState();
}

class _ManualEntryPopupState extends State<ManualEntryPopup> {
  TextEditingController deviceIdController = TextEditingController();
  String? _email;
  String message = "";
  Color messageColor = Colors.teal;
  bool _canClose = true;
  Timer? _tourDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadEmail();
    AppTourGuide.onAutoFillDeviceId = (id) {
      if (mounted) {
        final currentText = deviceIdController.text.trim();
        // NEVER overwrite if user has typed their own ID (e.g. 23 or ANNAM-23)
        final bool isUnfilled = currentText.isEmpty ||
            currentText == 'ANNAM-' ||
            currentText == 'SOBHA-' ||
            currentText == 'ANNAM-CP-' ||
            currentText == 'ANNAM-CPS-' ||
            currentText == 'SS-' ||
            currentText == 'WQ-' ||
            currentText == 'CL-' ||
            currentText == 'IT-' ||
            currentText == 'TESTING-';

        if (isUnfilled) {
          setState(() {
            deviceIdController.text = id;
            deviceIdController.selection = TextSelection.fromPosition(
              TextPosition(offset: deviceIdController.text.length),
            );
          });
        }
      }
    };
    AppTourGuide.onTriggerConfirmAdd = () {
      _handleConfirmAdd();
    };
  }

  @override
  void dispose() {
    _tourDebounceTimer?.cancel();
    AppTourGuide.onAutoFillDeviceId = null;
    AppTourGuide.onTriggerConfirmAdd = null;
    deviceIdController.dispose();
    super.dispose();
  }

  void _checkTourAutoAdvance() {
    if (!AppTourGuide.isTourActive || AppTourGuide.currentStep != 5) return;
    _tourDebounceTimer?.cancel();
    _tourDebounceTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted && AppTourGuide.isTourActive && AppTourGuide.currentStep == 5) {
        final text = deviceIdController.text.trim();
        if (text.length >= 2) {
          AppTourGuide.nextStep(context);
        }
      }
    });
  }

  Future<void> _loadEmail() async {
    if (widget.targetUserEmail != null && widget.targetUserEmail!.isNotEmpty) {
      setState(() {
        _email = widget.targetUserEmail;
      });
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');

    setState(() {
      _email = email;
    });
  }


  // Resolve prefix details and validate in real-time as the user types
  Map<String, dynamic> _resolveInputDetails(String text) {
    final cleanInput = text.trim().toUpperCase();
    if (cleanInput.isEmpty) return {'isValid': false};

    // Get candidate IDs
    final candidates = DeviceUtils.getPossibleInternalIDs(cleanInput);
    String targetId = cleanInput;
    if (candidates.isNotEmpty) {
      targetId = candidates.first;
    }

    final isValid = DevicePrefixUtils.isValidDeviceId(targetId);
    final sensorType = DevicePrefixUtils.getSensorType(targetId);
    final displayId = DevicePrefixUtils.toAnnamDisplayName(cleanInput.isNotEmpty ? cleanInput : targetId);

    return {
      'isValid': isValid,
      'sensorType': sensorType,
      'displayId': displayId,
      'targetId': targetId,
      'candidateCount': candidates.length,
    };
  }

  Future<void> _handleConfirmAdd() async {
    String inputId = deviceIdController.text.trim().toUpperCase();
    if (inputId.isEmpty) {
      DeleteDeviceUtils.showToastNotification(
        context: context,
        title: 'Validation Error',
        message: 'Please enter a valid device ID.',
        isError: true,
      );
      return;
    }

    String? finalDeviceId;
    final candidates = DeviceUtils.getPossibleInternalIDs(inputId);
    if (candidates.isEmpty) {
      finalDeviceId = inputId;
    } else if (candidates.length == 1) {
      finalDeviceId = candidates.first;
    } else {
      if (AppTourGuide.isTourActive && AppTourGuide.currentStep == 6) {
        AppTourGuide.goToStep(context, 7);
      }
      finalDeviceId = await DeviceUtils.showPrefixChoiceDialog(
          context, candidates);
    }

    if (finalDeviceId == null) return; // User cancelled choice dialog
    final confirmedId = finalDeviceId;

    // Store the newly confirmed device ID in the tour so it highlights this specific card!
    if (AppTourGuide.isTourActive) {
      AppTourGuide.lastAddedDeviceId = confirmedId;
      AppTourGuide.lastAddedDeviceSequentialName = DevicePrefixUtils.getSensorType(confirmedId) ?? 'ANNAM Sensor';
      AppTourGuide.goToStep(context, 8);
    }

    DeviceUtils.showConfirmationDialog(
      context: context,
      deviceId: confirmedId,
      devices: widget.devices,
      onConfirm: () async {
        bool success = await DeviceUtils.addDeviceToUser(
          context: context,
          email: _email,
          deviceId: confirmedId,
        );

        if (context.mounted) {
          Navigator.pop(context); // close manual entry popup
          if (widget.targetUserEmail != null) {
            widget.onDeviceAdded?.call();
          } else if (success) {
            NavigationUtils.navigateTo(context, '/devicelist', isReplacement: true);
          }
          // After addition is confirmed & dialog closes, advance to Step 9: Tap Device Card for THIS newly added station!
          if (AppTourGuide.isTourActive) {
            AppTourGuide.lastAddedDeviceId = confirmedId;
            AppTourGuide.lastAddedDeviceSequentialName = DevicePrefixUtils.getSensorType(confirmedId) ?? 'ANNAM Sensor';
            AppTourGuide.goToStep(context, 9);
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final primaryColor = isDarkMode ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);
    final surfaceColor = isDarkMode ? const Color(0xFF0D1F2D) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white70 : Colors.black54;
    final cardBg = isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02);

    final details = _resolveInputDetails(deviceIdController.text);
    final hasInput = deviceIdController.text.trim().isNotEmpty;

    final List<Map<String, String>> templates = [
      {'name': 'ANNAM Weather ⛅', 'prefix': 'ANNAM-'},
      {'name': 'Sobha Sensor 🏠', 'prefix': 'SOBHA-'},
      {'name': 'Annam CP Sensor 📡', 'prefix': 'ANNAM-CP-'},
      {'name': 'CPS Sensor 🌡️', 'prefix': 'ANNAM-CPS-'},
      {'name': 'Soil Sensor 🌱', 'prefix': 'SS-'},
      {'name': 'Water Quality 💧', 'prefix': 'WQ-'},
      {'name': 'Chlorine 🧪', 'prefix': 'CL-'},
      {'name': 'IIT Bombay 🏛️', 'prefix': 'IT-'},
      {'name': 'Testing Device 🛠️', 'prefix': 'TESTING-'},
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title & Help Guide
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.targetUserEmail != null
                        ? 'Add Device to ${widget.targetUserEmail}'
                        : 'Add Device Manually',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  /*
                  IconButton(
                    icon: const Icon(Icons.help_outline, color: Color(0xFF0284C7), size: 20),
                    tooltip: 'Step-by-Step Guide for Adding Device',
                    onPressed: () {
                      AppTourGuide.startTour(context, initialStep: 4);
                    },
                  ),
                  */
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Choose a template category below or type your custom ID directly.',
                style: TextStyle(
                  color: subtitleColor,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),

              // Interactive template chips
              TourTarget(
                targetId: 'template_chips',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DEVICE TEMPLATES',
                      style: TextStyle(
                        color: primaryColor.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: templates.map((t) {
                        return ActionChip(
                          label: Text(
                            t['name']!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          backgroundColor: cardBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.06),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          onPressed: () {
                            setState(() {
                              deviceIdController.text = t['prefix']!;
                              deviceIdController.selection = TextSelection.fromPosition(
                                TextPosition(offset: deviceIdController.text.length),
                              );
                            });
                            if (AppTourGuide.isTourActive && AppTourGuide.currentStep == 4) {
                              AppTourGuide.nextStep(context);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Input Field
              TourTarget(
                targetId: 'device_id_input',
                child: TextField(
                  controller: deviceIdController,
                  autofocus: true,
                  onChanged: (val) {
                    setState(() {});
                    _checkTourAutoAdvance();
                  },
                  onSubmitted: (val) {
                    if (AppTourGuide.isTourActive && AppTourGuide.currentStep == 5 && val.trim().isNotEmpty) {
                      _tourDebounceTimer?.cancel();
                      AppTourGuide.nextStep(context);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Enter Device ID',
                    labelStyle: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    prefixIcon: Icon(
                      Icons.developer_board,
                      color: primaryColor.withOpacity(0.7),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Real-Time Validator Console
              if (hasInput) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black26 : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: details['isValid'] == true
                          ? Colors.green.withOpacity(0.2)
                          : Colors.orange.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            details['isValid'] == true
                                ? Icons.check_circle
                                : Icons.info_outline,
                            size: 16,
                            color: details['isValid'] == true ? Colors.green : Colors.orange,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            details['isValid'] == true ? 'Valid ID Format' : 'Awaiting Numeric ID...',
                            style: TextStyle(
                              color: details['isValid'] == true ? Colors.green : Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (details['isValid'] == true) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Display Name: ${details['displayId']}',
                          style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        if (details['candidateCount'] != null && details['candidateCount'] > 1)
                          Row(
                            children: [
                              Icon(
                                Icons.alt_route,
                                size: 13,
                                color: isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Topic will be chosen on confirm (${details['candidateCount']} options)',
                                  style: TextStyle(
                                    color: isDarkMode ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (details['sensorType'] != null &&
                                 details['sensorType'] != 'Rain Sensors' &&
                                 details['sensorType'] != 'ANNAM Sensors')
                          Text(
                            'Type: ${details['sensorType']}',
                            style: TextStyle(color: subtitleColor, fontSize: 12),
                          ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Text(
                          'Please enter the numeric ID to complete (e.g. 01, 101)',
                          style: TextStyle(color: subtitleColor, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_canClose)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(width: 12),
                  TourTarget(
                    targetId: 'confirm_add_btn',
                    child: ElevatedButton(
                      onPressed: _handleConfirmAdd,
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Confirm & Add',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
