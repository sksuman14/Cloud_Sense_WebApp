import 'dart:convert';

import 'package:cloud_sense_webapp/src/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;

class DeleteDeviceUtils {
  static bool isValidDeviceId(String deviceId) {
    final regex = RegExp(r'^[A-Z]{2}\d{3}$');
    return regex.hasMatch(deviceId);
  }

static Future<void> deleteAccount(
  BuildContext context,
  String emailToDelete,
  String? currentUserEmail,
) async {
  if (emailToDelete.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Please enter an email ID to delete."),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }

  bool? confirmed = await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account'),
      content: Text(
          'Are you sure you want to delete the account associated with $emailToDelete? This action cannot be undone.'),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context, false),
        ),
        TextButton(
          child: const Text(
            'Delete',
            style: TextStyle(color: Colors.red),
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    ),
  );

  if (confirmed == true) {

    final url =
        'https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function?email_id=$emailToDelete&action=delete_user&confirm_delete=yes';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200 ||
          response.statusCode == 404 ||
          response.body.toLowerCase().contains("user not found")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account deleted successfully."),
            backgroundColor: Colors.green,
          ),
        );

        if (emailToDelete == currentUserEmail) {
          try {
            await Amplify.Auth.deleteUser();
          } catch (e) {
            print("Error deleting user from Cognito: $e");
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.remove('email');

         Navigator.pushNamedAndRemoveUntil(
  context,
  '/login',
  (Route<dynamic> route) => false,
);

        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to delete account. ${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error occurred while deleting account."),
          backgroundColor: Colors.red,
        ),
      );
      print('Error deleting account: $error');
    }
  }
}



  static Future<void> deleteDevices(
    BuildContext context,
    String userEmail,
    Map<String, List<String>> deviceCategories,
    Function(Map<String, List<String>>) onDevicesUpdated,
  ) async {
    if (deviceCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No devices available to delete."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Map<String, List<bool>> selectedDevices = {
      for (var key in deviceCategories.keys)
        key: List<bool>.filled(deviceCategories[key]!.length, false),
    };

    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Delete Devices'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: deviceCategories.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sensor: ${entry.key}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...List.generate(entry.value.length, (index) {
                        return CheckboxListTile(
                          title: Text('Device ID - ${entry.value[index]}'),
                          value: selectedDevices[entry.key]![index],
                          onChanged: (value) {
                            setState(() {
                              selectedDevices[entry.key]![index] =
                                  value ?? false;
                            });
                          },
                        );
                      }),
                    ],
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Delete'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true) {
      List<String> devicesToDelete = [];
      selectedDevices.forEach((sensor, selections) {
        for (int i = 0; i < selections.length; i++) {
          if (selections[i]) {
            devicesToDelete.add(deviceCategories[sensor]![i]);
          }
        }
      });

      if (devicesToDelete.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No devices selected for deletion."),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      try {
        for (var deviceId in devicesToDelete) {
          final url =
              'https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function?email_id=$userEmail&action=delete_devices&device_id=$deviceId';

          final response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            print('Response: $data');

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(data['message']),
                backgroundColor: Colors.green,
              ),
            );

            // Update local state
            final updatedCategories =
                Map<String, List<String>>.from(deviceCategories);
            updatedCategories.forEach((sensor, devices) {
              devices.remove(deviceId);
            });
            updatedCategories.removeWhere((key, value) => value.isEmpty);
            onDevicesUpdated(updatedCategories);
          } else {
            print('Response Status Code: ${response.statusCode}');
            print('Response Body: ${response.body}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to delete device ID $deviceId."),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (error) {
        print('Exception occurred: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error occurred while deleting devices."),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}