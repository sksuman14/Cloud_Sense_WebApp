import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_list.dart';
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0D1F2D) : Colors.white,
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
          children: [
            Text(
              'Add Device Manually',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            TextField(
              controller: deviceIdController,
              decoration: InputDecoration(
                labelText: 'Enter Device ID',
                labelStyle: TextStyle(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
                border: const OutlineInputBorder(),
                helperText:
                    'e.g., ANNAM001, ANNAM0126_001, TS0526_001, TS_001',
                helperStyle: TextStyle(
                  color: isDarkMode ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            SizedBox(height: 20),
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

                if (finalDeviceId == null)
                  return; // User cancelled choice dialog

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

                    // Unified dialog for both success/failure
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
                backgroundColor: isDarkMode
                    ? const Color(0xFF1FCB8A)
                    : const Color(0xFF0D47A1),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Add Device',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
            if (_canClose)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
