import 'dart:convert';
import 'dart:ui';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/src/views/home/home_theme.dart';

// ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──

String _toAnnamDisplayName(String internalSensorName) =>
    DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

bool _isAnnamSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamCoreSensor(internalSensorName);

bool _isAnnamTestingSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamTestingSensor(internalSensorName);

bool _isPartnershipSensor(String internalSensorName) =>
    !_isAnnamSensor(internalSensorName) &&
    !_isAnnamTestingSensor(internalSensorName);

double _getResponsiveFontSize(
    BuildContext context, double mobileSize, double desktopSize) {
  final width = MediaQuery.of(context).size.width;
  return width <= 600 ? mobileSize : desktopSize;
}

class AccountInfoPage extends StatefulWidget {
  @override
  _AccountInfoPageState createState() => _AccountInfoPageState();
}

class _AccountInfoPageState extends State<AccountInfoPage> {
  String? userId;
  String? userEmail;
  String? device_id;
  bool _isLoading = true;
  Map<String, List<String>> deviceCategories = {};
  Map<String, String> _locationMap =
      {}; // New: For storing deviceId -> Location string
  TextEditingController _emailController =
      TextEditingController(); // Controller for email input

  Future<void> _fetchDeviceLocations() async {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];
    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching locations $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );
      Map<String, String> newLocMap = {};

      for (var response in responses) {
        if (response.statusCode != 200) continue;
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> devices = jsonResponse['devices'] ?? [];
        for (var item in devices) {
          final rawTopic =
              (item['deviceid#topic'] ?? item['deviceId#topic'] ?? '')
                  .toString();
          if (rawTopic.isEmpty) continue;

          final parts = rawTopic.split('#');
          if (parts.isEmpty) continue;
          final deviceId = parts[0].toUpperCase();

          final city = (item['City'] ?? item['Place'] ?? '').toString().trim();
          final district = (item['District'] ?? '').toString().trim();
          final state = (item['State'] ?? '').toString().trim();

          final locParts = {
            if (city.isNotEmpty) city,
            if (district.isNotEmpty) district,
            if (state.isNotEmpty) state
          }.toList();

          if (locParts.isNotEmpty) {
            newLocMap[deviceId] = locParts.join(', ');
          }
        }
      }
      setState(() {
        _locationMap = newLocMap;
      });
    } catch (e) {
      print('Error loading device locations: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      userEmail = prefs.getString('email') ?? 'Unknown';
      _emailController.text =
          userEmail ?? ''; // Pre-fill email field with the stored email

      await _fetchData(); // Fetch device data after loading user data

      setState(() {});
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _fetchData() async {
    final email = _emailController.text.trim(); // Get the entered email
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Please enter a valid email."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      deviceCategories.clear(); // Clear old data
    });

    await _fetchDeviceLocations(); // Load locations in parallel

    final url =
        'https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices?email_id=$email';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);

        setState(() {
          deviceCategories = {
            for (var key in result.keys)
              if (key != 'device_id' && key != 'email_id')
                key: List<String>.from(result[key] ?? [])
          };
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load devices. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
        print('Failed to load devices. Status Code: ${response.statusCode}');
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error fetching data."),
          backgroundColor: Colors.red,
        ),
      );
      print('Error fetching data: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAccount() async {
    String emailToDelete = _emailController.text.trim();
    if (emailToDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter an email ID to delete."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strong = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white70 : Colors.black54;

    // Confirmation dialog
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: Colors.redAccent, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                'Delete Account',
                style: TextStyle(
                    color: strong, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete the account associated with $emailToDelete? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtle, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: subtle,
                        side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text('Delete',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final url =
          'https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function?email_id=$emailToDelete&action=delete_user&confirm_delete=yes';

      try {
        // Use GET because API is designed that way
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

          // If deleting currently logged-in user
          if (emailToDelete == userEmail) {
            try {
              await Amplify.Auth.deleteUser();
            } catch (e) {
              print("Error deleting user from Cognito: $e");
            }

            // Remove from SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.remove('email');

            // Navigate to SignInSignUpScreen
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => SignInSignUpScreen()),
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
          print(
              'Failed to delete account. Status Code: ${response.statusCode}');
          print('Response Body: ${response.body}');
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

  Future<void> _deleteDevices() async {
    if (deviceCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("No devices available to delete."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strong = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white70 : Colors.black54;

    // Create a map to track selected devices
    Map<String, List<bool>> selectedDevices = {
      for (var key in deviceCategories.keys)
        key: List<bool>.filled(deviceCategories[key]!.length, false),
    };

    // Show dialog for device selection
    bool? confirmed = await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Delete Devices',
                        style: TextStyle(
                            color: strong,
                            fontWeight: FontWeight.w900,
                            fontSize: 20),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: subtle),
                        onPressed: () => Navigator.pop(context, false),
                      ),
                    ],
                  ),
                  Divider(color: isDark ? Colors.white12 : Colors.black12),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: deviceCategories.entries.map((entry) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 12, bottom: 4),
                                child: Text(
                                  'Sensor: ${entry.key}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1976D2),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ...List.generate(entry.value.length, (index) {
                                return CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  activeColor: const Color(0xFF1976D2),
                                  title: Text(
                                    'Device ID - ${_toAnnamDisplayName(entry.value[index])}',
                                    style: TextStyle(
                                        color: strong,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
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
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: subtle,
                            side: BorderSide(
                                color:
                                    isDark ? Colors.white24 : Colors.black12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Delete Selected',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      // Collect selected device IDs
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

      // Prepare the API call
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

            setState(() {
              // Remove deleted devices from local state
              deviceCategories.forEach((sensor, devices) {
                devices.remove(deviceId);
              });
              deviceCategories.removeWhere((key, value) => value.isEmpty);
            });
            // IMPORTANT: Trigger notification subscription management
            // This will check if the user still has ammonia sensors and update token accordingly
            await checkAndUpdateNotificationSubscription();
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

  // ── Flatten all devices into a single list for display ──
  List<Map<String, String>> get _flatDeviceList {
    final list = <Map<String, String>>[];
    for (var entry in deviceCategories.entries) {
      for (var device in entry.value) {
        list.add({
          'sensor': entry.key,
          'deviceId': device,
          'displayName': _toAnnamDisplayName(device),
          'location': _locationMap[device.toUpperCase()] ?? '',
        });
      }
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    // Theme-aware palette matching Admin & Health pages
    ThemeProvider? themeProvider;
    try {
      themeProvider = Provider.of<ThemeProvider>(context);
    } catch (_) {}

    final isDark = themeProvider?.isDarkMode ??
        Theme.of(context).brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0B141D) : const Color(0xFFF5F7FA);
    final appBarColor =
        isDark ? const Color(0xFF14212B) : const Color(0xFF1976D2);
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;
    final strong = isDark ? Colors.white : Colors.black87;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);
    const primaryBlue = Color(0xFF1976D2);

    final isMobile = MediaQuery.of(context).size.width <= 600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Info',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: _getResponsiveFontSize(context, 18, 22),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _fetchData,
            tooltip: 'Refresh Data',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: bgColor,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchData,
            color: primaryBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Email Input Section ──
                  _buildEmailSection(
                      isDark, strong, subtle, borderColor, primaryBlue),
                  const SizedBox(height: 24),

                  // ── Device Table ──
                  _isLoading
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(60),
                            child: CircularProgressIndicator(
                                color: strong, strokeWidth: 2),
                          ),
                        )
                      : deviceCategories.isNotEmpty
                          ? _buildCategorizedDeviceTable(isDark, strong, subtle,
                              borderColor, primaryBlue, cardColor)
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  children: [
                                    Icon(Icons.devices_other,
                                        size: 64,
                                        color: strong.withOpacity(0.2)),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No devices found',
                                      style: TextStyle(
                                          color: strong.withOpacity(0.4),
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                  const SizedBox(height: 32),

                  // ── Action Buttons ──
                  _buildActionButtons(isDark, strong, subtle, borderColor),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailSection(bool isDark, Color strong, Color subtle,
      Color borderColor, Color primaryBlue) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'User Email',
            style: TextStyle(
              color: strong,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the email associated with the account to view devices.',
            style: TextStyle(
              color: subtle,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: TextField(
                    controller: _emailController,
                    style: TextStyle(
                        color: strong,
                        fontWeight: FontWeight.w600,
                        fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'example@email.com',
                      hintStyle: TextStyle(color: strong.withOpacity(0.3)),
                      prefixIcon:
                          Icon(Icons.email_outlined, color: subtle, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _fetchData,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: Text(
                  'Fetch',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: _getResponsiveFontSize(context, 12, 14),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedDeviceTable(bool isDark, Color strong, Color subtle,
      Color borderColor, Color primaryBlue, Color cardColor) {
    final flatList = _flatDeviceList;
    final Map<String, List<Map<String, String>>> categorized = {
      'ANNAM': flatList.where((d) => _isAnnamSensor(d['deviceId']!)).toList(),
      'TESTING':
          flatList.where((d) => _isAnnamTestingSensor(d['deviceId']!)).toList(),
      'PARTNERSHIP':
          flatList.where((d) => _isPartnershipSensor(d['deviceId']!)).toList(),
    };

    // Keep only non-empty categories
    categorized.removeWhere((key, value) => value.isEmpty);

    final cardBg = isDark ? Colors.black.withOpacity(0.15) : Colors.white;

    // Find max length for table display
    int maxRows = 0;
    categorized.forEach((_, list) {
      if (list.length > maxRows) maxRows = list.length;
    });

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Categorized Table Header ──
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.02),
              border: Border(
                  bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.black.withOpacity(0.1))),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                const SizedBox(width: 20),
                ...categorized.keys.map((catName) => Expanded(
                      child: Text(catName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: catName == 'TESTING'
                                  ? Colors.orangeAccent
                                  : (catName == 'ANNAM'
                                      ? const Color(0xFF14B8A6)
                                      : primaryBlue),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.2)),
                    )),
                const SizedBox(width: 20),
              ],
            ),
          ),
          // ── Categorized Table Rows ──
          ...List.generate(maxRows, (rowIndex) {
            final alternateColor = isDark
                ? Colors.white.withOpacity(0.02)
                : const Color(0xFFF8FAFC);

            return Container(
              decoration: BoxDecoration(
                color: rowIndex % 2 == 1 ? alternateColor : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  const SizedBox(width: 20),
                  ...categorized.keys.map((catKey) {
                    final list = categorized[catKey]!;
                    final device =
                        rowIndex < list.length ? list[rowIndex] : null;
                    return Expanded(
                      child: Text(
                        device?['displayName'] ?? '',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: strong,
                            fontWeight: FontWeight.w700,
                            fontSize: 13),
                      ),
                    );
                  }),
                  const SizedBox(width: 20),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      bool isDark, Color strong, Color subtle, Color borderColor) {
    return Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: _deleteDevices,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete Devices',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark
                  ? Colors.redAccent.withOpacity(0.15)
                  : const Color(0xFFFEE2E2),
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.redAccent.withOpacity(0.3)),
              ),
              elevation: 0,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _deleteAccount,
            icon: const Icon(Icons.person_remove_outlined, size: 18),
            label: const Text('Delete Account',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}
