import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

class DataSendDialog extends StatefulWidget {
  final String? initialDeviceId;
  final String? displayDeviceId; // Added
  final String? initialIntervalType;
  final int? initialInterval;

  const DataSendDialog({
    super.key,
    this.initialDeviceId,
    this.displayDeviceId, // Added
    this.initialIntervalType,
    this.initialInterval,
  });

  // Static method to show the dialog with blur effect
  static Future<void> show(
    BuildContext context, {
    String? initialDeviceId,
    String? displayDeviceId, // Added
    String? initialIntervalType,
    int? initialInterval,
  }) {
    return showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: DataSendDialog(
          initialDeviceId: initialDeviceId,
          displayDeviceId: displayDeviceId, // Added
          initialIntervalType: initialIntervalType,
          initialInterval: initialInterval,
        ),
      ),
    );
  }

  @override
  State<DataSendDialog> createState() => _DataSendDialogState();
}

class _DataSendDialogState extends State<DataSendDialog> {
  late final TextEditingController _deviceIdController;
  String? _selectedIntervalType;
  int? _selectedInterval;
  bool _isLoading = false;
  String _responseMessage = '';
  Map<String, dynamic>? _sentBody;

  @override
  void initState() {
    super.initState();
    _deviceIdController = TextEditingController(
        text: widget.displayDeviceId ??
            DevicePrefixUtils.toAnnamDisplayName(widget.initialDeviceId ?? ""));
    _selectedIntervalType = widget.initialIntervalType;
    _selectedInterval = widget.initialInterval;
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    super.dispose();
  }

  String _getCurrentTimestamp() {
    final now = DateTime.now().toUtc();
    return now.toIso8601String().split('.').first + 'Z';
  }

  Future<void> sendData() async {
    if (_deviceIdController.text.isEmpty ||
        _selectedIntervalType == null ||
        _selectedInterval == null) {
      _showPopup(
        title: "Missing Fields",
        message:
            "Please enter Device ID and select Interval Type and Interval.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _responseMessage = '';
    });

    final url = Uri.parse(
      'https://mm3y8rm6a1.execute-api.us-east-1.amazonaws.com/default/User_Changes_API',
    );

    final body = {
      "DeviceId": _deviceIdController.text.trim(),
      "TimeStamp": _getCurrentTimestamp(),
      "Interval": _selectedInterval,
      "Interval Type": _selectedIntervalType,
    };

    _sentBody = body;

    print("Sending Request to: $url");
    print("Request Body: ${jsonEncode(body)}");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );
      print("Response Status: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        _showPopup(
          title: "Success",
          message:
              "Data saved successfully!\n\nSent Body:\n${jsonEncode(body)}",
        );
      } else {
        _showPopup(
          title: "Error ${response.statusCode}",
          message: response.body,
        );
      }
    } catch (e) {
      print("Exception occurred: $e");
      _showPopup(title: "Exception", message: e.toString());
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showPopup({required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent manual dismissal
      builder: (context) {
        // Schedule automatic dismissal after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: SingleChildScrollView(child: Text(message)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDarkMode ? Colors.black87 : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [const Color(0xFFC0B9B9), const Color(0xFF7B9FAE)]
                : [const Color(0xFF7EABA6), const Color(0xFF363A3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Device Configuration",
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              TextField(
                controller: _deviceIdController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Device ID",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor)),
                  helperText: "Enter the Device ID (e.g., WD101, CL102)",
                  helperStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.devices, color: textColor),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(isExpanded: true, 
                decoration: InputDecoration(
                  labelText: "Select Interval Type",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor)),
                  prefixIcon: Icon(Icons.schedule, color: textColor),
                ),
                value: _selectedIntervalType,
                dropdownColor:
                    isDarkMode ? Colors.blueGrey[50] : Colors.blueGrey[800],
                style: TextStyle(color: textColor),
                items: ['Hourly', 'Minutely'].map((String type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isDarkMode ? Colors.black87 : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedIntervalType = value;
                    _selectedInterval = null;
                  });
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(isExpanded: true, 
                decoration: InputDecoration(
                  labelText: "Select Interval",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.7)),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor)),
                  prefixIcon: Icon(Icons.timer, color: textColor),
                ),
                value: _selectedInterval,
                dropdownColor:
                    isDarkMode ? Colors.blueGrey[50] : Colors.blueGrey[800],
                style: TextStyle(color: textColor),
                items: _selectedIntervalType == 'Hourly'
                    ? [1, 2, 6, 12].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            "$value hour${value > 1 ? 's' : ''}",
                            style: TextStyle(
                              color: isDarkMode ? Colors.black87 : Colors.white,
                            ),
                          ),
                        );
                      }).toList()
                    : [2, 5, 10, 15, 30].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(
                            "$value minutes",
                            style: TextStyle(
                              color: isDarkMode ? Colors.black87 : Colors.white,
                            ),
                          ),
                        );
                      }).toList(),
                onChanged: _selectedIntervalType == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedInterval = value;
                        });
                      },
              ),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : sendData,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isLoading ? "Sending..." : "Send Data"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.black54 : Colors.white,
                  foregroundColor: isDarkMode ? Colors.white : Colors.black,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
              // const SizedBox(height: 20),
              // if (_sentBody != null)
              //   Container(
              //     width: double.infinity,
              //     padding: const EdgeInsets.all(16),
              //     decoration: BoxDecoration(
              //       color: isDarkMode ? Colors.grey[700] : Colors.grey.shade200,
              //       borderRadius: BorderRadius.circular(12),
              //     ),
              //     // child: Text(
              //     //   "Sent Body:\n${jsonEncode(_sentBody!)}",
              //     //   style: TextStyle(
              //     //     fontSize: 14,
              //     //     color: isDarkMode ? Colors.white : Colors.black,
              //     //   ),
              //     // ),
              //   ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Close",
                  style: TextStyle(color: Colors.teal, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
