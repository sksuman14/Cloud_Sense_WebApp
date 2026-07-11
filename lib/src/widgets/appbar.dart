import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/data/datasheets_download.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/auth_utils.dart';
import 'package:cloud_sense_webapp/src/views/devices/configuration.dart';
import 'package:cloud_sense_webapp/src/views/home/home_page.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class AppBarWidget extends StatefulWidget implements PreferredSizeWidget {
  final Future<void> Function()? onRefresh;

  const AppBarWidget({super.key, this.onRefresh});

  @override
  _AppBarWidgetState createState() => _AppBarWidgetState();

  @override
  Size get preferredSize => const Size.fromHeight(56);
}

class _AppBarWidgetState extends State<AppBarWidget> {
  // State to track refresh status
  bool _isRefreshing = false;

  // Logic to handle the refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return; // Prevent multiple refreshes at once

    setState(() {
      _isRefreshing = true;
    });

    try {
      if (widget.onRefresh != null) {
        await widget.onRefresh!();
      } else {
        await Future.delayed(const Duration(seconds: 2));
      }

      if (mounted) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    await AuthUtils.handleLogout(context);
  }

  Future<void> _handleDeviceNavigation(BuildContext context) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail;
    if (email == null) {
      _showLoginPopup(context);
      return;
    }
    try {
      if (email.trim().toLowerCase() == '05agriculture.05@gmail.com') {
        NavigationUtils.navigateTo(context, '/deviceinfo');
      } else {
        await manageNotificationSubscription();
        NavigationUtils.navigateTo(context, '/devicelist');
      }
    } catch (e) {
      print('Error checking user: $e');
      NavigationUtils.navigateTo(context, '/login');
    }
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
                await NavigationUtils.navigateTo(context, '/login');
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

  void _showSensorPopup(BuildContext context, {GlobalKey? buttonKey}) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    RelativeRect position;

    if (buttonKey != null) {
      final RenderBox button =
          buttonKey.currentContext!.findRenderObject() as RenderBox;
      final buttonPosition =
          button.localToGlobal(Offset.zero, ancestor: overlay);

      position = RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        buttonPosition.dx + 200,
        0,
      );
    } else {
      position = RelativeRect.fromLTRB(
        overlay.size.width - 200,
        kToolbarHeight,
        0,
        0,
      );
    }

    bool isAtrhExpanded = false;

    final selected = await showMenu<String>(
      context: context,
      position: position,
      color: isDarkMode ? const Color(0xFF1D2B38) : Colors.white,
      items: [
        PopupMenuItem(
          value: 'data_logger',
          child: Row(
            children: [
              Icon(Icons.storage,
                  color: isDarkMode ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text('Data Logger'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'rain_gauge',
          child: Row(
            children: [
              Icon(Icons.water_drop,
                  color: isDarkMode ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text('Rain Gauge'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'wind_speed',
          child: Row(
            children: [
              Icon(Icons.air,
                  color: isDarkMode ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text('Ultrasonic Anemometer'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'atrh',
          child: Row(
            children: [
              Icon(Icons.thermostat,
                  color: isDarkMode ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text('Integrated Environmental Sensor'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'probe',
          child: Row(
            children: [
              Icon(Icons.thermostat,
                  color: isDarkMode ? Colors.white : Colors.black, size: 20),
              const SizedBox(width: 8),
              const Text('Temperature and Humidity Probe'),
            ],
          ),
        ),
      ],
    );

    if (selected != null) {
      switch (selected) {
        case 'wind_speed':
          NavigationUtils.navigateTo(context, '/windsensor');
          break;
        case 'rain_gauge':
          NavigationUtils.navigateTo(context, '/raingauge');
          break;
        case 'data_logger':
          NavigationUtils.navigateTo(context, '/datalogger');
          break;
        case 'atrh':
          NavigationUtils.navigateTo(context, '/atrh');
          break;
        case 'probe':
          NavigationUtils.navigateTo(context, '/probe');
          break;
        case 'gateway':
          NavigationUtils.navigateTo(context, '/gateway');
          break;
      }
    }
  }

  Widget _buildUserProfilePill(BuildContext context, bool isDarkMode,
      bool isTablet, GlobalKey userButtonKey) {
    final userProvider = Provider.of<UserProvider>(context);
    final email = userProvider.userEmail?.trim().toLowerCase();
    final name = userProvider.userName?.trim();

    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (email?.split('@').first ?? 'Guest');
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';

    const String specialUserEmail = '05agriculture.05@gmail.com';
    final bool isSpecialUser = email == specialUserEmail;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () async {
          final RenderBox overlay =
              Overlay.of(context).context.findRenderObject() as RenderBox;
          final RenderBox button =
              userButtonKey.currentContext!.findRenderObject() as RenderBox;
          final buttonPosition =
              button.localToGlobal(Offset.zero, ancestor: overlay);

          final selected = await showMenu<String>(
            context: context,
            position: RelativeRect.fromLTRB(
              buttonPosition.dx,
              buttonPosition.dy + button.size.height,
              buttonPosition.dx + 200,
              0,
            ),
            color: isDarkMode ? const Color(0xFF1D2B38) : Colors.white,
            items: [
              if (DeviceUtils.adminEmails.contains(email))
                PopupMenuItem(
                  value: 'data',
                  child: Row(
                    children: [
                      Icon(Icons.data_usage,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 20),
                      const SizedBox(width: 8),
                      const Text('My Data'),
                    ],
                  ),
                )
              else ...[
                PopupMenuItem(
                  value: 'devices',
                  child: Row(
                    children: [
                      Icon(Icons.devices,
                          color: isDarkMode ? Colors.white : Colors.black,
                          size: 20),
                      const SizedBox(width: 8),
                      const Text('My Devices'),
                    ],
                  ),
                ),
                if (!isSpecialUser)
                  PopupMenuItem(
                    value: 'account',
                    child: Row(
                      children: [
                        Icon(Icons.account_circle,
                            color: isDarkMode ? Colors.white : Colors.black,
                            size: 20),
                        const SizedBox(width: 8),
                        const Text('Account Info'),
                      ],
                    ),
                  ),
              ],
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: isDarkMode ? Colors.white : Colors.black,
                        size: 20),
                    const SizedBox(width: 8),
                    const Text('Logout'),
                  ],
                ),
              ),
            ],
          );

          if (selected == 'data') {
            NavigationUtils.navigateTo(context, '/admin');
          } else if (selected == 'devices') {
            if (isSpecialUser) {
              NavigationUtils.navigateTo(context, '/deviceinfo');
            } else {
              NavigationUtils.navigateTo(context, '/devicelist');
            }
          } else if (selected == 'account') {
            NavigationUtils.navigateTo(context, '/accountinfo');
          } else if (selected == 'logout') {
            _handleLogout(context);
          }
        },
        child: Container(
          key: userButtonKey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF151515) : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDarkMode ? const Color(0xFF2B2F36) : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: isDarkMode ? const Color(0xFF88A4E6) : const Color(0xFF1976D2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 100 : 160),
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isTablet ? 100 : 160),
                    child: Text(
                      email ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.arrow_drop_down,
                color: isDarkMode ? Colors.white : Colors.black87,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    final GlobalKey productsButtonKey = GlobalKey();
    final GlobalKey userButtonKey = GlobalKey();

    bool isMobile = screenWidth < 800;
    bool isTablet = screenWidth >= 800 && screenWidth <= 1024;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(
        color: Colors.white,
      ),
      backgroundColor:
          isDarkMode ? const Color(0xFF14212B) : const Color(0xFF1976D2),
      toolbarHeight: 56,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          /// LOGO + TITLE
          Padding(
            padding: EdgeInsets.only(left: screenWidth < 800 ? 6 : 20),
            child: Builder(
              builder: (context) {
                final isHome = !Navigator.of(context).canPop();

                return Tooltip(
                  message: isHome ? '' : 'Go to Home Page',
                  child: TextButton(
                    onPressed: isHome
                        ? null
                        : () {
                            NavigationUtils.navigateTo(context, '/', removeUntil: true);
                          },
                    style: ButtonStyle(
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                      foregroundColor: WidgetStateProperty.all(Colors.white),
                      textStyle: WidgetStateProperty.all(
                        TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth < 800
                              ? 20
                              : screenWidth <= 1024
                                  ? 26
                                  : 40,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud,
                          color: Colors.white,
                          size: screenWidth < 800
                              ? 20
                              : screenWidth <= 1024
                                  ? 28
                                  : 40,
                        ),
                        SizedBox(width: isMobile ? 10 : (isTablet ? 15 : 20)),
                        const Text('Cloud Sense Vis',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          /// DESKTOP/TABLET ACTIONS
          if (!isMobile)
            Padding(
              padding: EdgeInsets.only(right: screenWidth < 800 ? 8 : 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  /// Products Dropdown
                  TextButton(
                    key: productsButtonKey,
                    onPressed: () =>
                        _showSensorPopup(context, buttonKey: productsButtonKey),
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Text(
                          'Products',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 14 : 16,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.white, size: isTablet ? 18 : 20),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth <= 1024 ? 12 : 24),

                  /// Theme Toggle
                  TextButton(
                    onPressed: () {
                      themeProvider.toggleTheme();
                    },
                    child: Row(
                      children: [
                        Icon(
                          themeProvider.isDarkMode
                              ? Icons.light_mode
                              : Icons.dark_mode,
                          color: Colors.white,
                          size: isTablet ? 18 : 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Theme',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenWidth <= 1024 ? 12 : 24),

                  PopupMenuButton<String>(
                    tooltip: "Help & Manuals",
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.help,
                          color: Colors.white,
                          size: isTablet ? 20 : 22,
                        ),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.white,
                          size: isTablet ? 20 : 22,
                        ),
                      ],
                    ),
                    offset: const Offset(0, 50),
                    onSelected: (String value) {
                      if (value == 'app_manual') {
                        DownloadManager.downloadFile(
                          context: context,
                          sensorKey: "UserManual",
                          fileType: "datasheet",
                        );
                      } else if (value == 'setup_manual') {
                        DownloadManager.downloadFile(
                          context: context,
                          sensorKey: "SetupManual",
                          fileType: "datasheet",
                        );
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'app_manual',
                        child: Text('App Manual'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'setup_manual',
                        child: Text('Setup Manual'),
                      ),
                    ],
                  ),
                  SizedBox(width: screenWidth <= 1024 ? 12 : 24),

                  /// User Login / Profile
                  userProvider.userEmail != null
                      ? _buildUserProfilePill(
                          context, isDarkMode, isTablet, userButtonKey)
                      : TextButton(
                          key: userButtonKey,
                          onPressed: () => _showLoginPopup(context),
                          child: Row(
                            children: [
                              Text(
                                'Login/Signup',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isTablet ? 14 : 16,
                                ),
                              ),
                              Icon(Icons.arrow_drop_down,
                                  color: Colors.white,
                                  size: isTablet ? 18 : 20),
                            ],
                          ),
                        ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        // This logic shows the refresh button or a loading indicator, but only on mobile.
        if (isMobile)
          _isRefreshing
              ? Container(
                  width: 48, // Match IconButton width
                  height: 48, // Match IconButton height
                  padding: const EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _handleRefresh,
                ),

        // ⬇️ ADDED THIS BUILDER TO MANUALLY ADD THE DRAWER BUTTON
        if (isMobile)
          Builder(
            builder: (context) {
              // Check if the Scaffold has an endDrawer
              if (Scaffold.of(context).hasEndDrawer) {
                return IconButton(
                  icon: const Icon(Icons.menu),
                  tooltip:
                      MaterialLocalizations.of(context).openAppDrawerTooltip,
                  onPressed: () {
                    Scaffold.of(context).openEndDrawer();
                  },
                );
              }
              // If no endDrawer, return an empty container
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
