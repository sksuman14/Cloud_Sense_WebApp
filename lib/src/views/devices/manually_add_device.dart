import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ManualEntryPopup extends StatefulWidget {
  final Map<String, List<String>> devices;

  ManualEntryPopup({required this.devices});

  @override
  _ManualEntryPopupState createState() => _ManualEntryPopupState();
}

class _ManualEntryPopupState extends State<ManualEntryPopup> {
  TextEditingController deviceIdController = TextEditingController();
  String? _email;
  String message = "";
  Color messageColor = Colors.teal;
  bool _canClose = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  @override
  void dispose() {
    deviceIdController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');

    setState(() {
      _email = email;
    });
  }

  // ✅ Unified dialog for success/failure
  Future<void> _showResultMessage(String msg, Color color) async {
    setState(() {
      message = msg;
      messageColor = color;
    });

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Text(
            message,
            style: TextStyle(
              color: messageColor,
              fontSize: 16,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close dialog
                NavigationUtils.navigateTo(context, '/devicelist', isReplacement: true);
              },
            ),
          ],
        );
      },
    );
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
    final displayId = DevicePrefixUtils.toAnnamDisplayName(targetId);

    return {
      'isValid': isValid,
      'sensorType': sensorType,
      'displayId': displayId,
      'targetId': targetId,
    };
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
      {'name': 'CPS Sensor 🌡️', 'prefix': 'ANNAM/CPS_'},
      {'name': 'April Weather 📅', 'prefix': 'ANNAM0426_'},
      {'name': 'Jan Weather ❄️', 'prefix': 'ANNAM0126_'},
      {'name': 'Feb Weather 🌧️', 'prefix': 'ANNAM0226_'},
      {'name': 'AWS Weather ⛅', 'prefix': 'AWS_'},
      {'name': 'Soil Sensor 🌱', 'prefix': 'SS'},
      {'name': 'Water Quality 💧', 'prefix': 'WQ'},
      {'name': 'Chlorine 🧪', 'prefix': 'CL'},
      {'name': 'IIT Bombay 🏛️', 'prefix': 'IT'},
      {'name': 'Shobha 🏠', 'prefix': 'WS_Shobha_'},
      {'name': 'Testing Device 🛠️', 'prefix': 'ANNAM0526_'},
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
              // Header
              Text(
                'Add Device Manually',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
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
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Input Field
              TextField(
                controller: deviceIdController,
                autofocus: true,
                onChanged: (val) {
                  setState(() {});
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
                      const SizedBox(height: 10),
                      Text(
                        'Resolved Type: ${details['sensorType']}',
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Display Name: ${details['displayId']}',
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
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
                  ElevatedButton(
                    onPressed: () async {
                      String inputId = deviceIdController.text.trim().toUpperCase();
                      if (inputId.isEmpty) {
                        await _showResultMessage(
                          "Please enter a valid device ID.",
                          Colors.red,
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
                        finalDeviceId = await DeviceUtils.showPrefixChoiceDialog(
                            context, candidates);
                      }

                      if (finalDeviceId == null) return; // User cancelled choice dialog

                      DeviceUtils.showConfirmationDialog(
                        context: context,
                        deviceId: finalDeviceId,
                        devices: widget.devices,
                        onConfirm: () async {
                          bool success = await DeviceUtils.addDeviceToUser(
                            context: context,
                            email: _email,
                            deviceId: finalDeviceId!,
                          );

                          String displayId = DeviceUtils.toDisplayId(finalDeviceId!);
                          await _showResultMessage(
                            success
                                ? "Device $displayId added successfully."
                                : "Failed to add device $displayId.",
                            success ? Colors.green : Colors.red,
                          );
                        },
                      );
                    },
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
