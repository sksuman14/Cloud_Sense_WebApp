import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/data/datasheets_download.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/auth_utils.dart';
import 'package:cloud_sense_webapp/src/views/devices/configuration.dart';
import 'package:cloud_sense_webapp/src/views/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class EndDrawerWidget extends StatefulWidget {
  const EndDrawerWidget({super.key});

  @override
  State<EndDrawerWidget> createState() => _EndDrawerWidgetState();
}

class _EndDrawerWidgetState extends State<EndDrawerWidget> {
  bool _isProductsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final email = userProvider.userEmail?.trim().toLowerCase();

    const String specialUserEmail = '05agriculture.05@gmail.com';
    final bool isSpecialUser = email == specialUserEmail;

    final drawerBackgroundColor =
        isDarkMode ? const Color(0xFF0B141D) : Colors.grey[200]!;

    return Drawer(
      backgroundColor: drawerBackgroundColor,
      child: Container(
        color: drawerBackgroundColor, // Ensure ListView background matches
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // 🔹 Drawer Header
              DrawerHeader(
                decoration: BoxDecoration(
                  color:
                      isDarkMode ? const Color(0xFF14212B) : Colors.grey[200],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildUserIcon(context),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (userProvider.userName != null && userProvider.userName!.isNotEmpty)
                                    ? userProvider.userName!
                                    : (userProvider.userEmail?.split('@').first ?? 'Guest User'),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (userProvider.userEmail != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  userProvider.userEmail!,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isDarkMode ? Colors.white70 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      userProvider.userEmail != null
                          ? 'Welcome back!'
                          : 'Please login to access all features',
                      style: TextStyle(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // 🔹 Logged-in user options
              if (userProvider.userEmail != null) ...[
                if (DeviceUtils.adminEmails.contains(email)) ...[
                  ListTile(
                    leading: Icon(Icons.data_usage,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('My Data'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 200));
                      Navigator.of(context, rootNavigator: true)
                          .pushNamed('/admin');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                        isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('Theme'),
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                  ListTile(
                    leading: Icon(Icons.share,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('Share'),
                    onTap: () async {
                      Share.share(
                        'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                        subject: 'Download Our App',
                      );
                      Navigator.pop(context);
                    },
                  ),
                ] else ...[
                  ListTile(
                    leading: Icon(Icons.devices,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('My Devices'),
                    onTap: () async {
                      Navigator.pop(context);
                      await Future.delayed(const Duration(milliseconds: 200));

                      if (isSpecialUser) {
                        Navigator.of(context, rootNavigator: true)
                            .pushNamed('/deviceinfo');
                      } else {
                        Navigator.of(context, rootNavigator: true)
                            .pushNamed('/devicelist');
                      }
                    },
                  ),
                  // ✨ CHANGE: Only show 'Account Info' if the user is NOT the special user.
                  if (!isSpecialUser)
                    ListTile(
                      leading: Icon(Icons.account_circle,
                          color: isDarkMode ? Colors.white : Colors.black),
                      title: const Text('Account Info'),
                      onTap: () async {
                        Navigator.pop(context);
                        await Future.delayed(const Duration(milliseconds: 200));
                        Navigator.of(context, rootNavigator: true)
                            .pushNamed('/accountinfo');
                      },
                    ),
                  ListTile(
                    leading: Icon(
                        isDarkMode ? Icons.light_mode : Icons.dark_mode,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('Theme'),
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                  ListTile(
                    leading: Icon(Icons.share,
                        color: isDarkMode ? Colors.white : Colors.black),
                    title: const Text('Share'),
                    onTap: () async {
                      Share.share(
                        'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                        subject: 'Download Our App',
                      );
                      Navigator.pop(context);
                    },
                  ),
                ],
                ListTile(
                  leading: Icon(Icons.logout,
                      color: isDarkMode ? Colors.white : Colors.black),
                  title: const Text('Logout'),
                  onTap: () async {
                    Navigator.pop(context);
                    await Future.delayed(const Duration(milliseconds: 250));
                    final rootCtx =
                        Navigator.of(context, rootNavigator: true).context;
                    await _handleLogout(rootCtx);
                  },
                ),
                const Divider(),
              ],

              // 🔹 Guest user options
              if (userProvider.userEmail == null) ...[
                ListTile(
                  leading:
                      Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
                  title: const Text('Theme'),
                  onTap: () => themeProvider.toggleTheme(),
                ),
                ListTile(
                  leading: const Icon(Icons.share),
                  title: const Text('Share'),
                  onTap: () async {
                    Share.share(
                      'Check out our app on Google Play Store: https://play.google.com/store/apps/details?id=com.CloudSenseVis',
                      subject: 'Download Our App',
                    );
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.login),
                  title: const Text('Login/Signup'),
                  onTap: () => _showLoginPopup(context),
                ),
              ],

              ExpansionTile(
                leading: Icon(Icons.help,
                    color: isDarkMode ? Colors.white : Colors.black),
                title: const Text('Help & Manuals'),

                // This controls the color of the expand/collapse arrow
                iconColor: isDarkMode ? Colors.white : Colors.black,
                collapsedIconColor: isDarkMode ? Colors.white : Colors.black,

                // These are the options that appear when you tap the tile
                children: <Widget>[
                  // ListTile for the App Manual
                  ListTile(
                    // Indent the title a bit for a cleaner look
                    contentPadding: const EdgeInsets.only(left: 30.0),
                    title: const Text('App Manual'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      DownloadManager.downloadFile(
                        context: context,
                        sensorKey: "UserManual",
                        fileType: "datasheet",
                      );
                    },
                  ),
                  // ListTile for the Setup Manual
                  ListTile(
                    contentPadding: const EdgeInsets.only(left: 30.0),
                    title: const Text('Setup Manual'),
                    onTap: () {
                      Navigator.pop(context); // Close the drawer
                      DownloadManager.downloadFile(
                        context: context,
                        sensorKey: "SetupManual",
                        fileType: "datasheet",
                      );
                    },
                  ),
                ],
              ),

              // 🔹 Products expandable section
              ListTile(
                leading: Icon(Icons.inventory,
                    color: isDarkMode ? Colors.white : Colors.black),
                title: const Text('Products'),
                trailing: Icon(
                  _isProductsExpanded
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                onTap: () {
                  setState(() {
                    _isProductsExpanded = !_isProductsExpanded;
                  });
                },
              ),
              if (_isProductsExpanded) _buildProductsList(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserIcon(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userProvider = Provider.of<UserProvider>(context);
    final userEmail = userProvider.userEmail;
    final userName = userProvider.userName?.trim();

    final displayName = (userName != null && userName.isNotEmpty)
        ? userName
        : (userEmail?.split('@').first ?? 'Guest');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    if (userEmail == null || userEmail.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white : Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.person,
          color: isDarkMode ? Colors.black : Colors.white,
          size: 24,
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2B2F36) : const Color(0xFFE0E5ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: isDarkMode ? const Color(0xFF88A4E6) : const Color(0xFF1976D2),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthUtils.handleLogout(context);
  }

  void _showLoginPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Login Required'),
          content:
              const Text('Please log in or sign up to access your devices.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await Navigator.of(context, rootNavigator: true)
                    .pushNamed('/login');
              },
              child: const Text('Login/Signup'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProductsList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.storage, size: 20),
            title: const Text('Data Logger', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/datalogger');
            },
          ),
          ListTile(
            leading: const Icon(Icons.water_drop, size: 20),
            title: const Text('Rain Gauge', style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/raingauge');
            },
          ),
          ListTile(
            leading: const Icon(Icons.air, size: 20),
            title: const Text('Ultrasonic Anemometer',
                style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true)
                  .pushNamed('/windsensor');
            },
          ),
          ListTile(
            leading: const Icon(Icons.thermostat, size: 20),
            title: const Text('Integrated Environmental Sensor',
                style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true).pushNamed('/atrh');
            },
          ),
          ListTile(
            leading: const Icon(Icons.thermostat, size: 20),
            title: const Text('Temperature and Humidity Probe',
                style: TextStyle(fontSize: 14)),
            onTap: () async {
              Navigator.pop(context);
              await Future.delayed(const Duration(milliseconds: 200));
              Navigator.of(context, rootNavigator: true).pushNamed('/probe');
            },
          ),
        ],
      ),
    );
  }
}
