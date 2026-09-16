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
    if (context.mounted) {
      showToastNotification(
        context: context,
        title: 'Validation Error',
        message: 'Please enter an email ID to delete.',
        isError: true,
      );
    }
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
        if (context.mounted) {
          showToastNotification(
            context: context,
            title: 'Account Deleted Successfully',
            message: 'User account $emailToDelete has been deleted.',
          );
        }

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
        if (context.mounted) {
          showToastNotification(
            context: context,
            title: 'Account Deletion Failed',
            message: 'Failed to delete account. ${response.body}',
            isError: true,
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        showToastNotification(
          context: context,
          title: 'Error Deleting Account',
          message: '$error',
          isError: true,
        );
      }
      print('Error deleting account: $error');
    }
  }
}

  /// Helper to get the delete confirmation message
  static String getDeleteConfirmationMessage({
    required String displayDeviceId,
    required String userEmail,
    String? adminEmail,
  }) {
    final bool isAdminDeleting = adminEmail != null && adminEmail.isNotEmpty;
    final String targetAccount = isAdminDeleting ? userEmail : 'your account';
    return 'Are you sure you want to remove device "$displayDeviceId" from $targetAccount? This action cannot be undone.';
  }

  /// Displays high-visibility feedback via top floating banner only (highest Z-index above all dialogs)
  static void showToastNotification({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
  }) {
    // Dismiss any existing bottom snackbar so only the top banner is visible
    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    } catch (_) {}

    // High-priority Top Overlay Banner (renders directly above any open dialog and modal barrier)
    try {
      final overlay = Overlay.maybeOf(context);
      if (overlay != null) {
        late OverlayEntry entry;
        entry = OverlayEntry(
          builder: (ctx) => Positioned(
            top: 24,
            left: 24,
            right: 24,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: isError
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isError
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () {
                          if (entry.mounted) {
                            entry.remove();
                          }
                        },
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        overlay.insert(entry);
        Future.delayed(const Duration(seconds: 4), () {
          if (entry.mounted) {
            entry.remove();
          }
        });
      }
    } catch (_) {}
  }

  static Future<void> deleteSingleDevice({
    required BuildContext context,
    required String userEmail,
    required String deviceId,
    required String displayDeviceId,
    required VoidCallback onSuccess,
    String? adminEmail,
  }) async {
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final strong = isDarkMode ? Colors.white : Colors.black87;
        final subtle = isDarkMode ? Colors.white70 : Colors.black54;

        final confirmationMessage = getDeleteConfirmationMessage(
          displayDeviceId: displayDeviceId,
          userEmail: userEmail,
          adminEmail: adminEmail,
        );

        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              Text('Delete Device', style: TextStyle(color: strong, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Text(
            confirmationMessage,
            style: TextStyle(color: subtle, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: subtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
      );

      try {
        final url =
            'https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function?email_id=$userEmail&action=delete_devices&device_id=$deviceId';
        final response = await http.get(Uri.parse(url));

        if (context.mounted) Navigator.pop(context); // close spinner

        if (response.statusCode == 200) {
          final bool isAdminDeleting =
              adminEmail != null && adminEmail.isNotEmpty;
          final String successMsg = isAdminDeleting
              ? 'Device "$displayDeviceId" was deleted from $userEmail.'
              : 'Device "$displayDeviceId" was deleted from your account.';

          if (context.mounted) {
            showToastNotification(
              context: context,
              title: 'Device Deleted Successfully',
              message: successMsg,
            );
          }
          onSuccess();
        } else {
          if (context.mounted) {
            showToastNotification(
              context: context,
              title: 'Deletion Failed',
              message: 'Failed to delete device "$displayDeviceId".',
              isError: true,
            );
          }
        }
      } catch (error) {
        if (context.mounted) {
          Navigator.pop(context); // close spinner on error
          showToastNotification(
            context: context,
            title: 'Error Deleting Device',
            message: '$error',
            isError: true,
          );
        }
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
      if (context.mounted) {
        showToastNotification(
          context: context,
          title: 'Notice',
          message: 'No devices available to delete.',
          isError: true,
        );
      }
      return;
    }

    // Confirmation dialog
    int totalDeviceCount = 0;
    for (var list in deviceCategories.values) {
      totalDeviceCount += list.length;
    }

    bool? confirmed = await showDialog(
      context: context,
      builder: (ctx) {
        final isDarkMode = Theme.of(ctx).brightness == Brightness.dark;
        final strong = isDarkMode ? Colors.white : Colors.black87;
        final subtle = isDarkMode ? Colors.white70 : Colors.black54;

        return AlertDialog(
          backgroundColor:
              isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete $totalDeviceCount Device${totalDeviceCount > 1 ? 's' : ''}',
                  style: TextStyle(
                      color: strong,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to remove $totalDeviceCount selected device${totalDeviceCount > 1 ? 's' : ''} from ${userEmail.isNotEmpty ? userEmail : 'this account'}? This action cannot be undone.',
            style: TextStyle(color: subtle, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: subtle)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      List<String> devicesToDelete = [];
      for (var list in deviceCategories.values) {
        devicesToDelete.addAll(list);
      }

      if (devicesToDelete.isEmpty) {
        if (context.mounted) {
          showToastNotification(
            context: context,
            title: 'Notice',
            message: 'No devices selected for deletion.',
            isError: true,
          );
        }
        return;
      }

      // Show non-dismissible loading spinner so user can't navigate away
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      'Deleting ${devicesToDelete.length} device${devicesToDelete.length > 1 ? 's' : ''}...',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
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

      int successCount = 0;
      List<String> failedIds = [];
      // Start from full deviceCategories so we return the remaining full list
      Map<String, List<String>> updatedCategories =
          Map<String, List<String>>.from(
              deviceCategories.map((k, v) => MapEntry(k, List<String>.from(v))));

      try {
        for (var deviceId in devicesToDelete) {
          final url =
              'https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function?email_id=$userEmail&action=delete_devices&device_id=$deviceId';

          final response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            successCount++;
            updatedCategories.forEach((_, devices) => devices.remove(deviceId));
          } else {
            failedIds.add(deviceId);
          }
        }
      } catch (error) {
        print('Exception occurred: $error');
      }

      // Close spinner
      if (context.mounted) Navigator.pop(context);

      updatedCategories.removeWhere((_, v) => v.isEmpty);
      onDevicesUpdated(updatedCategories);

      // Summary toast
      if (context.mounted) {
        if (successCount > 0) {
          showToastNotification(
            context: context,
            title: 'Devices Deleted',
            message:
                '$successCount device${successCount > 1 ? 's' : ''} deleted successfully.',
          );
        }
        if (failedIds.isNotEmpty) {
          showToastNotification(
            context: context,
            title: 'Some Deletions Failed',
            message: 'Failed to delete: ${failedIds.length} device${failedIds.length > 1 ? 's' : ''}.',
            isError: true,
          );
        }
      }
    }
  }
}