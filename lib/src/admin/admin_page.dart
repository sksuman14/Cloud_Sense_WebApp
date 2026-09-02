import 'dart:async';
import 'dart:convert';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/device_activity.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/GPS.dart';
import 'package:cloud_sense_webapp/src/views/devices/device_map.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/views/dashboard/device_graph.dart';
import 'package:cloud_sense_webapp/src/views/devices/AdvancedDataSendDialog.dart';
import 'package:cloud_sense_webapp/src/views/devices/configuration.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/admin/device_health_status.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:ui' as ui;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';

// ── Using DevicePrefixUtils for consistent ANNAM/TS prefix mapping ──

String _toAnnamDisplayName(String internalSensorName) =>
    DevicePrefixUtils.toAnnamDisplayName(internalSensorName);

bool _isAnnamSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamCoreSensor(internalSensorName);

bool _isAnnamTestingSensor(String internalSensorName) =>
    DevicePrefixUtils.isAnnamTestingSensor(internalSensorName);

// Partnership: all other sensors (formerly ANNAM1, ANNAM3, ANNAM4, ANNAM0)
bool _isPartnershipSensor(String internalSensorName) {
  return !_isAnnamSensor(internalSensorName) &&
      !_isAnnamTestingSensor(internalSensorName);
}

// ── Internal Helpers for prefixing ──
// (Unused helpers removed. Logic now handled via RegExp in _toAnnamDisplayName)

class AdminPage extends StatefulWidget {
  final String? adminEmail;
  const AdminPage({Key? key, this.adminEmail}) : super(key: key);
  @override
  State<AdminPage> createState() => _AdminPageState();
}

double getResponsiveFontSize(
    BuildContext context, double mobileSize, double desktopSize) {
  final width = MediaQuery.of(context).size.width;
  return width <= 600 ? mobileSize : desktopSize;
}

class _AdminPageState extends State<AdminPage> {
  final DeviceService _deviceService = DeviceService();
  final String userApiUrl =
      "https://25e5bsdhwd.execute-api.us-east-1.amazonaws.com/default/CloudSense_users_delete_function";
  final String userDevicesApiUrl =
      "https://ln8b1r7ld9.execute-api.us-east-1.amazonaws.com/default/Cloudsense_user_devices";
  bool isLoading = true;
  List<Map<String, dynamic>> allDevices = [];
  int totalActive = 0;
  int totalInactive = 0;
  String filter = "All";
  String searchQuery = "";
  String alertSearchQuery = "";
  String healthAlertSearchQuery = "";
  List<Map<String, String>> users = [];
  bool isUsersLoading = true;
  Map<String, Map<String, String>> latestAnomalies = {};
  List<Map<String, String>> notifications = [];
  List<Map<String, String>> dismissedNotifications = [];
  Timer? _anomalyTimer;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _devicesSectionKey = GlobalKey();
  final GlobalKey _usersSectionKey = GlobalKey();
  int devicesToShow = 12;
  int usersToShow = 10;
  String? selectedCategory;
  String selectedBrand = "All"; // ← Default to All initially
  Map<String, DateTime> _timestampMap = {};
  Map<String, String> _locationMap = {};
  Map<String, String> locationMap = {};
  Map<String, List<String>> _parameterNamesMap = {};
  Map<String, String> _apiIntervalMap = {};
  bool _isRestrictedAdmin = false;
  String? _currentUserEmail;
  List<Map<String, dynamic>> _erroneousDevices = [];
  List<Map<String, dynamic>> _suspectDevices = [];
  List<Map<String, dynamic>> _correctedDevices = [];
  List<Map<String, dynamic>> _offlineDevices = [];
  List<Map<String, dynamic>> _criticalDevices = [];
  bool _isQualityLoading = false;
  bool _isHealthLoading = false;

  bool get _hideSensitiveSections {
    if (_currentUserEmail == null) return false;
    final email = _currentUserEmail!.trim().toLowerCase();
    return const [
      'sejalsankhyan2001@gmail.com',
      'pallavikrishnan01@gmail.com',
      'officeharsh25@gmail.com',
      'info@ssmicroelectronics.co.in',
      'ahashivam2001@gmail.com',
      'annam.aicloud@gmail.com',
    ].contains(email);
  }

  String? _getLocationForSensor(String sensorName) {
    final hardcoded = _hardcodedLocationMap[sensorName] ?? _hardcodedLocationMap[DevicePrefixUtils.getSensorNameFromTopic(sensorName) ?? ''];
    if (hardcoded != null) return hardcoded;

    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    final apiLocation = _locationMap[topic];
    if (apiLocation != null && apiLocation.isNotEmpty) return apiLocation;

    // Fallback for TS (Testing) sensors: Rupnagar, Punjab
    if (DevicePrefixUtils.isAnnamTestingSensor(sensorName)) {
      return 'Rupnagar, Punjab';
    }
    return null;
  }

  String _getStateForSensor(String sensorName) {
    final location = _getLocationForSensor(sensorName);
    if (location != null && location.isNotEmpty) {
      final parts = location.split(',');
      return parts.last.trim();
    }
    return 'Unknown';
  }

  void _showParametersDialog({
    required BuildContext context,
    required bool isDark,
    required String? updateInterval,
    required List<String> displayParamNames,
    required Map<String, String> parameterDisplayNames,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: AlertDialog(
            title: Text(
              "Parameters",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (updateInterval != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF3B6A7F).withOpacity(0.3)
                            : const Color(0xFF5BAA9D).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF3B6A7F)
                                : const Color(0xFF5BAA9D),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 16,
                              color: isDark
                                  ? const Color(0xFF5BAA9D)
                                  : const Color(0xFF3B6A7F)),
                          const SizedBox(width: 8),
                          Text('Data Interval: ',
                              style: TextStyle(
                                  fontSize: getResponsiveFontSize(
                                      context, 13, 14),
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontWeight: FontWeight.w500)),
                          Text(updateInterval,
                              style: TextStyle(
                                  fontSize: getResponsiveFontSize(
                                      context, 13, 14),
                                  color: isDark ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: isDark ? Colors.white12 : Colors.black12),
                    const SizedBox(height: 8),
                  ],
                  displayParamNames.isEmpty
                      ? Text('No parameters available yet.',
                          style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize:
                                  getResponsiveFontSize(context, 13, 14)))
                      : ListBody(
                          children: displayParamNames.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final param = entry.value;
                            final displayName =
                                parameterDisplayNames[param] ?? param;
                            return Padding(
                              padding: EdgeInsets.symmetric(
                                  vertical: getResponsiveFontSize(
                                      context, 6, 8)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                      width: 40,
                                      child: Text('${idx + 1}.',
                                          style: TextStyle(
                                              fontSize: getResponsiveFontSize(
                                                  context, 14, 16),
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87),
                                          textAlign: TextAlign.right)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: Text(displayName,
                                          style: TextStyle(
                                              fontSize: getResponsiveFontSize(
                                                  context, 14, 16),
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black87))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ],
              ),
            ),
            backgroundColor: isDark
                ? const Color(0xFF2C3E50).withOpacity(0.85)
                : Colors.white.withOpacity(0.85),
            actions: [
              TextButton(
                child: Text("Close",
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceCard({
    required BuildContext context,
    required int idx,
    required Map<String, dynamic> d,
    required bool isDark,
    required Color strong,
    required Color subtle,
  }) {
    final deviceId = (d['DeviceId'] ?? "Unknown").toString();
    final topic = (d['Topic'] ?? "Unknown").toString();
    final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);
    final sensorName = DevicePrefixUtils.resolveSensorName(deviceId, topic);
    final displaySensorName = _toAnnamDisplayName(sensorName);
    final updateInterval = _getUpdateInterval(sensorName);
    final paramNames = getParamNamesForSensor(sensorName);
    final displayParamNames = paramNames;
    final loc = _getLocationForSensor(sensorName);
    final isActive = d['isActive'] == true;
    final statusColor = _isRestrictedAdmin
        ? Colors.grey
        : (isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF192430) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3.5,
              color: statusColor,
            ),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    NavigationUtils.navigateTo(
                      context,
                      '/admin/devicegraph',
                      arguments: {
                        'deviceName': sensorName,
                        'sequentialName': mapped.category,
                        'backgroundImagePath': 'assets/backgroundd.jpg',
                      },
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              '${idx + 1}. ',
                              style: TextStyle(
                                color: strong,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                displaySensorName,
                                style: TextStyle(
                                  color: strong,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.more_vert,
                                color: isDark ? Colors.white54 : Colors.black54,
                                size: 16,
                              ),
                              tooltip: 'Actions',
                              onSelected: (String value) {
                                switch (value) {
                                  case 'graph':
                                    NavigationUtils.navigateTo(
                                      context,
                                      '/admin/devicegraph',
                                      arguments: {
                                        'deviceName': sensorName,
                                        'sequentialName': mapped.category,
                                        'backgroundImagePath': 'assets/backgroundd.jpg',
                                      },
                                    );
                                    break;
                                  case 'ota':
                                    final bool isAnnamCp01 = sensorName == 'ANNAM_CP01' ||
                                        sensorName == 'CP001' ||
                                        displaySensorName == 'ANNAM_CP01' ||
                                        sensorName.toUpperCase().contains('ANNAM_CP01') ||
                                        sensorName.toUpperCase().contains('CP01');
                                    if (['CP','CF','WF','WJ','WM','WN','IT','WA','WT','JW','KR','SH','AM','AW'].contains(mapped.prefix) || isAnnamCp01) {
                                      AdvancedDataSendDialog.show(
                                        context,
                                        sensorName,
                                        displayDeviceId: displaySensorName,
                                        apiUrl: _getOtaApiUrl(mapped.prefix, sensorName: sensorName) ??
                                            'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/annamcpdata',
                                      );
                                    } else if (mapped.category == 'SSMet Soil sensor') {
                                      _navigateToOTA(sensorName, updateInterval);
                                    }
                                    break;
                                  case 'parameters':
                                    _showParametersDialog(
                                      context: context,
                                      isDark: isDark,
                                      updateInterval: updateInterval,
                                      displayParamNames: displayParamNames,
                                      parameterDisplayNames: parameterDisplayNames,
                                    );
                                    break;
                                  case 'health':
                                    showDeviceHealthDetailDialog(
                                      context,
                                      "$deviceId#$topic",
                                      isDark,
                                    );
                                    break;
                                  case 'quality':
                                    NavigationUtils.navigateTo(
                                      context,
                                      '/admin/health/quality-diagnostics',
                                      arguments: {
                                        'deviceId': deviceId,
                                        'deviceIdTopic': "$deviceId#$topic",
                                        'displayName': displaySensorName,
                                         'isDark': isDark,
                                         'fromAdminPage': true,
                                      },
                                    );
                                    break;
                                }
                              },
                              itemBuilder: (BuildContext context) {
                                final String providerEmail = Provider.of<UserProvider>(context, listen: false).userEmail ?? "";
                                final String email = (_currentUserEmail ?? widget.adminEmail ?? providerEmail).trim().toLowerCase();
                                final bool isSkusuman = email.contains('sksuman');
                                final bool isAnnamCp01 = sensorName == 'ANNAM_CP01' ||
                                    sensorName == 'CP001' ||
                                    displaySensorName == 'ANNAM_CP01' ||
                                    sensorName.toUpperCase().contains('ANNAM_CP01') ||
                                    sensorName.toUpperCase().contains('CP01');
                                final bool hasOtaSupport = ['CP','CF','WF','WJ','WM','WN','IT','WA','WT','JW','KR','SH','AM','AW'].contains(mapped.prefix) ||
                                    mapped.category == 'SSMet Soil sensor' ||
                                    _getOtaApiUrl(mapped.prefix, sensorName: sensorName) != null ||
                                    isAnnamCp01;
                                final bool showOtaOption = (isSkusuman || isAnnamCp01) && !_hideSensitiveSections && hasOtaSupport;
                                return <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'graph',
                                    child: Row(children: [
                                      Icon(Icons.bar_chart, color: Colors.blue, size: 18),
                                      SizedBox(width: 10),
                                      Text('Graph', style: TextStyle(fontSize: 13)),
                                    ]),
                                  ),
                                  if (showOtaOption)
                                    const PopupMenuItem<String>(
                                      value: 'ota',
                                      child: Row(children: [
                                        Icon(Icons.settings_remote, color: Colors.orangeAccent, size: 18),
                                        SizedBox(width: 10),
                                        Text('OTA Update', style: TextStyle(fontSize: 13)),
                                      ]),
                                    ),
                                  const PopupMenuItem<String>(
                                    value: 'parameters',
                                    child: Row(children: [
                                      Icon(Icons.info_outline, color: Colors.teal, size: 18),
                                      SizedBox(width: 10),
                                      Text('Parameters', style: TextStyle(fontSize: 13)),
                                    ]),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'health',
                                    child: Row(children: [
                                      Icon(Icons.health_and_safety_outlined, color: Colors.green, size: 18),
                                      SizedBox(width: 10),
                                      Text('Health Status', style: TextStyle(fontSize: 13)),
                                    ]),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'quality',
                                    child: Row(children: [
                                      Icon(Icons.science_outlined, color: Colors.purple, size: 18),
                                      SizedBox(width: 10),
                                      Text('Quality Diagnostics', style: TextStyle(fontSize: 13)),
                                    ]),
                                  ),
                                ];
                              },
                            ),
                          ],
                        ),
                        if (loc != null && loc.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 11, color: subtle),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  loc,
                                  style: TextStyle(color: subtle, fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildAlertsDashboardSection(
      Color strong, Color subtle, Color cardColor, bool isDark) {
    List<Map<String, dynamic>> allQualityAlerts = [
      ..._erroneousDevices,
      ..._suspectDevices,
      ..._correctedDevices,
    ];
    List<Map<String, dynamic>> allHealthAlerts = [
      ..._offlineDevices,
      ..._criticalDevices
    ];
    allHealthAlerts.sort((a, b) {
      final minsA = (a['last_active_mins_ago'] as num?)?.toDouble() ?? double.infinity;
      final minsB = (b['last_active_mins_ago'] as num?)?.toDouble() ?? double.infinity;
      return minsA.compareTo(minsB);
    });


    if (alertSearchQuery.isNotEmpty) {
      final q = alertSearchQuery.toLowerCase();
      allQualityAlerts = allQualityAlerts.where((device) {
        final deviceId = (device['deviceId'] ?? device['DeviceId'])
                ?.toString()
                .toLowerCase() ??
            '';
        final topic =
            (device['topic'] ?? device['Topic'])?.toString().toLowerCase() ??
                '';
        final flaggedFields =
            Map<String, dynamic>.from(device['flagged_fields'] ?? {});
        final params = flaggedFields.keys
            .map((k) => _getDisplayName(k).toLowerCase())
            .join(' ');

        String displayName = deviceId;
        try {
          final fullTopic =
              "${device['deviceId'] ?? device['DeviceId']}#${device['topic'] ?? device['Topic']}";
          String? sensorName =
              DevicePrefixUtils.getSensorNameFromTopic(fullTopic);
          if (sensorName != null) {
            displayName =
                DevicePrefixUtils.toAnnamDisplayName(sensorName).toLowerCase();
          }
        } catch (_) {}

        return deviceId.contains(q) ||
            topic.contains(q) ||
            displayName.contains(q) ||
            params.contains(q);
      }).toList();
    }

    if (healthAlertSearchQuery.isNotEmpty) {
      final q = healthAlertSearchQuery.toLowerCase();
      allHealthAlerts = allHealthAlerts.where((device) {
        final deviceId = (device['deviceId'] ?? device['DeviceId'])
                ?.toString()
                .toLowerCase() ??
            '';
        final topic = (device['deviceId_topic'] ??
                    device['deviceid#topic'] ??
                    device['Topic'])
                ?.toString()
                .toLowerCase() ??
            '';

        String displayName = deviceId;
        try {
          String? sensorName = DevicePrefixUtils.getSensorNameFromTopic(
              device['deviceId_topic'] ??
                  device['deviceid#topic'] ??
                  device['Topic'] ??
                  '');
          if (sensorName != null) {
            displayName =
                DevicePrefixUtils.toAnnamDisplayName(sensorName).toLowerCase();
          }
        } catch (_) {}

        return deviceId.contains(q) ||
            topic.contains(q) ||
            displayName.contains(q);
      }).toList();
    }

    if (allQualityAlerts.isEmpty &&
        allHealthAlerts.isEmpty &&
        alertSearchQuery.isEmpty &&
        healthAlertSearchQuery.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(builder: (context, constraints) {
      final bool isLargeScreen = constraints.maxWidth > 900;
      final bool hasQualityAlerts = _erroneousDevices.isNotEmpty ||
          _suspectDevices.isNotEmpty ||
          _correctedDevices.isNotEmpty;
      final bool hasHealthAlerts =
          _offlineDevices.isNotEmpty || _criticalDevices.isNotEmpty;

      Widget buildSubCard(Widget content, Color color) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.15), width: 1.5),
          ),
          child: content,
        );
      }

      Widget qualitySection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQualityListHeader("Quality Alerts", Colors.redAccent,
                  strong, allQualityAlerts.length),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: constraints.maxWidth < 450
                    ? (alertSearchQuery.isEmpty ? 50 : 140)
                    : 220,
                height: 32,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      alertSearchQuery = val;
                    });
                  },
                  style: TextStyle(color: strong, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: constraints.maxWidth < 450
                        ? ""
                        : "Search ID or parameter...",
                    hintStyle: TextStyle(color: subtle, fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 16, color: subtle),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: strong.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allQualityAlerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("No matching alerts found.",
                  style: TextStyle(color: subtle, fontSize: 12)),
            )
          else
            _buildHorizontalQualityList(
                allQualityAlerts, strong, subtle, cardColor, isDark),
        ],
      );

      Widget healthSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQualityListHeader("Health Alerts", Colors.orange, strong,
                  allHealthAlerts.length),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                width: constraints.maxWidth < 450
                    ? (healthAlertSearchQuery.isEmpty ? 50 : 140)
                    : 200,
                height: 32,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      healthAlertSearchQuery = val;
                    });
                  },
                  style: TextStyle(color: strong, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: constraints.maxWidth < 450 ? "" : "Search ID...",
                    hintStyle: TextStyle(color: subtle, fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 16, color: subtle),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: strong.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          BorderSide(color: Colors.orange.withOpacity(0.5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allHealthAlerts.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text("No matching alerts found.",
                  style: TextStyle(color: subtle, fontSize: 12)),
            )
          else
            _buildHorizontalHealthList(
                allHealthAlerts, strong, subtle, cardColor, isDark),
        ],
      );

      return _SectionCard(
        title: "Device Alerts (Current)",
        cardColor: cardColor,
        strong: strong,
        subtle: subtle,
        child: isLargeScreen
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasQualityAlerts)
                    Expanded(
                      child: buildSubCard(qualitySection, Colors.redAccent),
                    )
                  else
                    const SizedBox.shrink(),
                  if (hasQualityAlerts && hasHealthAlerts)
                    const SizedBox(width: 20),
                  if (hasHealthAlerts)
                    Expanded(
                      child: buildSubCard(healthSection, Colors.orange),
                    )
                  else
                    const SizedBox.shrink(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasQualityAlerts) ...[
                    buildSubCard(qualitySection, Colors.redAccent),
                    if (hasHealthAlerts) const SizedBox(height: 20),
                  ],
                  if (hasHealthAlerts)
                    buildSubCard(healthSection, Colors.orange),
                ],
              ),
      );
    });
  }

  Widget _buildHorizontalHealthList(List<Map<String, dynamic>> devices,
      Color strong, Color subtle, Color cardColor, bool isDark) {
    return SizedBox(
      height: 110,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final deviceId =
                (device['deviceId'] ?? device['DeviceId'])?.toString() ??
                    'Unknown';
            final topic = (device['deviceId_topic'] ??
                        device['deviceid#topic'] ??
                        device['Topic'])
                    ?.toString() ??
                '';
            final timestamp =
                (device['last_seen_ist'] ?? device['TimeStamp_IST'])
                        ?.toString() ??
                    '';
            final status = (device['health_status']?.toString() ?? 'OFFLINE')
                .toUpperCase();
            final color = status == 'OFFLINE' ? Colors.grey : Colors.redAccent;

            String displayName = deviceId;
            try {
              String? sensorName =
                  DevicePrefixUtils.getSensorNameFromTopic(topic);
              if (sensorName != null) {
                displayName = DevicePrefixUtils.toAnnamDisplayName(sensorName);
              }
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () {
                  showDeviceHealthDetailDialog(context, topic, isDark);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: displayName,
                              child: Text(
                                displayName,
                                style: TextStyle(
                                    color: strong,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.history, size: 10, color: subtle),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _getRelativeTime(device),
                              style: TextStyle(color: subtle, fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _getRelativeTime(Map<String, dynamic> device) {
    final mins = (device['last_active_mins_ago'] as num?)?.toInt();
    if (mins == null) return device['last_seen_ist']?.toString() ?? 'Unknown';

    if (mins < 60) {
      return '${mins}m ago';
    } else if (mins < 1440) {
      final hours = mins / 60.0;
      return '${hours.toStringAsFixed(hours >= 10 ? 0 : 1)}h ago';
    } else {
      final days = mins / 1440.0;
      return '${days.toStringAsFixed(days >= 10 ? 0 : 1)}d ago';
    }
  }

  Widget _buildQualityListHeader(String title, Color color, Color strong,
      [int? count]) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: strong,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHorizontalQualityList(List<Map<String, dynamic>> devices,
      Color strong, Color subtle, Color cardColor, bool isDark) {
    return SizedBox(
      height: 110,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            ui.PointerDeviceKind.touch,
            ui.PointerDeviceKind.mouse,
            ui.PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final deviceId =
                (device['deviceId'] ?? device['DeviceId'])?.toString() ??
                    'Unknown';
            final topic =
                (device['topic'] ?? device['Topic'])?.toString() ?? '';
            final timestamp =
                (device['timestamp'] ?? device['TimeStamp_IST'])?.toString() ??
                    '';
            final status =
                (device['latest_flag']?.toString() ?? 'SUSPECT').toUpperCase();
            final color = status == 'ERRONEOUS'
                ? Colors.redAccent
                : status == 'CORRECTED'
                    ? Colors.blueAccent
                    : Colors.orangeAccent;

            final flaggedFields =
                Map<String, dynamic>.from(device['flagged_fields'] ?? {});

            // Extract parameter names that are not 'GOOD'
            final flaggedParams = flaggedFields.entries
                .where((e) =>
                    e.value.toString().toUpperCase() != 'GOOD' &&
                    !e.key.toLowerCase().contains('spatial'))
                .map((e) => _getDisplayName(e.key))
                .join(', ');

            String displayName = deviceId;
            String? sensorName;
            try {
              final fullTopic = "$deviceId#$topic";
              sensorName =
                  DevicePrefixUtils.getSensorNameFromTopic(fullTopic);
              if (sensorName != null) {
                displayName = DevicePrefixUtils.toAnnamDisplayName(sensorName);
              }
            } catch (_) {}

            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: InkWell(
                onTap: () {
                  NavigationUtils.navigateTo(
                    context,
                    '/admin/health/quality-diagnostics',
                    arguments: {
                      'deviceId': deviceId,
                      'deviceIdTopic': "$deviceId#$topic",
                      'displayName': displayName,
                      'isDark': isDark,
                      'fromAdminPage': true,
                    },
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration( 
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: displayName,
                              child: Text(
                                displayName,
                                style: TextStyle(
                                    color: strong,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                  color: color,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      if (flaggedParams.isNotEmpty)
                        Text(
                          "Issues: $flaggedParams",
                          style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: subtle),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              timestamp,
                              style: TextStyle(color: subtle, fontSize: 9),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initAdmin();
    _loadDeviceData();
    fetchUsers();
    _loadTimestampMapFromApi();
    _fetchQualitySummary();
    _fetchHealthSummary();
  }

  Future<void> _fetchHealthSummary() async {
    if (mounted) setState(() => _isHealthLoading = true);
    try {
      final response = await http.get(Uri.parse(
          'https://4p8k77fw8b.execute-api.us-east-1.amazonaws.com/default/IoT_Health_API?limit=300'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> devices = data['devices'] ?? [];

        final offline = devices
            .where((d) =>
                d['health_status']?.toString().toLowerCase() == 'offline')
            .map((d) => Map<String, dynamic>.from(d))
            .toList();
        final critical = devices
            .where((d) =>
                d['health_status']?.toString().toLowerCase() == 'critical')
            .map((d) => Map<String, dynamic>.from(d))
            .toList();

        if (mounted) {
          setState(() {
            _offlineDevices = offline;
            _criticalDevices = critical;
            _isHealthLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isHealthLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isHealthLoading = false);
      debugPrint("Error fetching health summary: $e");
    }
  }

  Future<void> _fetchQualitySummary() async {
    if (mounted) setState(() => _isQualityLoading = true);
    try {
      final listResponse = await http.get(Uri.parse(
          'https://xj0wfbsjyi.execute-api.us-east-1.amazonaws.com/default/IoT_QC_Api_Func?limit=300'));

      if (listResponse.statusCode != 200) {
        if (mounted) setState(() => _isQualityLoading = false);
        return;
      }

      final listData = json.decode(listResponse.body);
      final List<dynamic> allDevicesList = listData['devices'] ?? [];

      // Time range: last 24 hours
      final now = DateTime.now();
      final cutoff = now.subtract(const Duration(minutes: 15));
      final startTs = DateFormat("yyyy-MM-dd HH:mm:ss").format(cutoff);
      final endTs = DateFormat("yyyy-MM-dd HH:mm:ss").format(now);

      // Combined map: deviceId → best alert in last 24h
      // ERRONEOUS > SUSPECT
      final Map<String, Map<String, dynamic>> alertMap = {};

      int _flagPriority(String flag) {
        if (flag == 'ERRONEOUS') return 2;
        if (flag == 'SUSPECT') return 1;
        if (flag == 'CORRECTED') return 0;
        return -1;
      }

      // Step 2: Batch processing to avoid UI jank and API timeouts
      const batchSize = 8;
      for (int i = 0; i < allDevicesList.length; i += batchSize) {
        final batch = allDevicesList.skip(i).take(batchSize).toList();

        await Future.wait(batch.map((device) async {
          final deviceId = device['deviceId']?.toString() ?? '';
          final topic = device['topic']?.toString() ?? '';
          if (deviceId.isEmpty || topic.isEmpty) return;

          try {
            final histUrl =
                'https://xj0wfbsjyi.execute-api.us-east-1.amazonaws.com/default/IoT_QC_Api_Func'
                '?device_id=${Uri.encodeComponent(deviceId)}'
                '&topic=${Uri.encodeComponent(topic)}'
                '&history=true'
                '&start_ts=${Uri.encodeComponent(startTs)}'
                '&end_ts=${Uri.encodeComponent(endTs)}'
                '&limit=50';

            final histResponse = await http
                .get(Uri.parse(histUrl))
                .timeout(const Duration(seconds: 8));

            if (histResponse.statusCode != 200) return;

            final histData = json.decode(histResponse.body);
            final List<dynamic> records = histData['records'] ?? [];

            for (final record in records) {
              final flag =
                  record['overall_flag']?.toString().toUpperCase() ?? '';
              if (flag != 'ERRONEOUS' &&
                  flag != 'SUSPECT' &&
                  flag != 'CORRECTED') continue;

              final existing = alertMap[deviceId];
              final existingPriority = existing != null
                  ? _flagPriority(existing['latest_flag'])
                  : -1;
              final currentPriority = _flagPriority(flag);

              // Replace if higher priority, or same priority but newer timestamp
              if (currentPriority > existingPriority) {
                alertMap[deviceId] = {
                  'deviceId': deviceId,
                  'topic': topic,
                  'latest_flag': flag,
                  'timestamp': record['timestamp'],
                  'flagged_fields': record['flagged_fields'] ?? {},
                };
              }
            }
          } catch (e) {
            debugPrint('History fetch error for $deviceId: $e');
          }
        }));

        // Intermediate UI update after each batch
        if (mounted) {
          final erroneous = alertMap.values
              .where((d) => d['latest_flag'] == 'ERRONEOUS')
              .toList();
          final suspect = alertMap.values
              .where((d) => d['latest_flag'] == 'SUSPECT')
              .toList();
          final corrected = alertMap.values
              .where((d) => d['latest_flag'] == 'CORRECTED')
              .toList();
          setState(() {
            _erroneousDevices = erroneous;
            _suspectDevices = suspect;
            _correctedDevices = corrected;
          });
        }
      }

      if (mounted) {
        setState(() {
          _erroneousDevices = alertMap.values
              .where((d) => d['latest_flag'] == 'ERRONEOUS')
              .toList();
          _suspectDevices = alertMap.values
              .where((d) => d['latest_flag'] == 'SUSPECT')
              .toList();
          _correctedDevices = alertMap.values
              .where((d) => d['latest_flag'] == 'CORRECTED')
              .toList();
          _isQualityLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isQualityLoading = false);
      debugPrint("Error fetching quality summary: $e");
    }
  }

  Future<void> _initAdmin() async {
    String? resolvedEmail = widget.adminEmail;
    if (resolvedEmail == null || resolvedEmail.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      resolvedEmail = prefs.getString('email');
    }

    final isSuper = DeviceUtils.isSuperAdmin(resolvedEmail);

    if (mounted) {
      setState(() {
        _currentUserEmail = resolvedEmail;
        _isRestrictedAdmin = !isSuper;
      });
    }
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  static const Map<String, String> parameterDisplayNames = {
    "MaximumTemperature": "Maximum Temperature",
    "HumidityHourlyComulative": "Humidity Hourly Comulative",
    "AtmPressure": "Pressure",
    "AverageTemperature": "Average Temperature",
    "MaximumHumidity": "Maximum Humidity",
    "MinimumTemperature": "Minimum Temperature",
    "PressureHourlyComulative": "Pressure Hourly Comulative",
    "LightIntensity": "Light Intensity",
    "RainfallMinutly": "Rainfall Minutly",
    "CurrentTemperature": "Temperature",
    "WindDirection": "Wind Direction",
    "WindSpeed": "Wind Speed",
    "RainfallWeekly": "Rainfall Weekly",
    "RainfallDaily": "Rainfall Daily",
    "AverageHumidity": "Average Humidity",
    "BatteryVoltage": "Battery Voltage",
    "MinimumHumidity": "Minimum Humidity",
    "CurrentHumidity": "Humidity",
    "RainfallHourly": "Rainfall Hourly",
    "LuxHourlyComulative": "Lux Hourly Comulative",
    "TemperatureHourlyComulative": "Temperature Hourly Comulative",
    "SunshineHours": "Sunshine Hours",
    "PAR": "PAR",
    "UVRadiation": "UV Radiation",
    "SolarRadiation": "Solar Radiation",
  };

  String _getDisplayName(String key) {
    if (parameterDisplayNames.containsKey(key)) {
      return parameterDisplayNames[key]!;
    }
    final lowerKey = key.toLowerCase();
    for (var entry in parameterDisplayNames.entries) {
      if (entry.key.toLowerCase() == lowerKey) {
        return entry.value;
      }
    }
    return key;
  }

  static const Map<String, String> _hardcodedLocationMap = {
    'WJ214': 'Dinanagar, Punjab',
    'ANNAM0126_214': 'Dinanagar, Punjab',
    'WJ240': 'Ghanauli, Rupnagar, Punjab',
    'WJ247': 'Kala Afgana, Gurdaspur, Punjab',
    'WJ276': 'Qadian, Gurdaspur, Punjab',
    'WA013': 'Gajansu Madh, Jammu and Kashmir',
    'WA027': 'Nandpur, Sambha, Jammu and Kashmir',
    'WJ224': 'Tarn Taran, Punjab',
    'WJ466': 'Dasuya, Hoshairpur, Punjab',
    'WJ080': 'Jaito, Faridkot, Punjab',
    'WJ231': 'Adampur, Jalandhar, Punjab',
    'WJ398': 'District Administration Complex, Sector 76, Mohali, Punjab',
    'IT100': 'IIT Bombay, Maharashtra',
    'SM003': 'Cachar, Assam',
    'SW003': 'Bhubaneswar (M.Corp.) P.S., Khordha district, Odisha',
    'GPS': 'Rupnagar, Punjab',
    'gps': 'Rupnagar, Punjab',
    'WJ221': 'Zira tehsil, Firozpur district, Punjab',
    'NA013': 'Hyderabad, Musheerabad mandal, Telangana',
    'WJ267': 'Sardulgarh tehsil, Mansa district, Punjab',
    'WA016': 'Hiranagar, Kathua, Jammu and Kashmir',
  };

  Future<void> _loadDeviceData() async {
    setState(() => isLoading = true);
    final summary = await _deviceService.fetchDeviceActivity();
    if (mounted) {
      if (summary != null) {
        setState(() {
          allDevices = summary.allDevices;
          totalActive = summary.totalActive;
          totalInactive = summary.totalInactive;
        });
      } else {
        _toast("Failed to fetch device data.");
      }
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _anomalyTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, String>> filteredUsers = [];
  String userSearchQuery = "";

  void _filterUsers(String query) {
    userSearchQuery = query;
    List<Map<String, String>> tempFilteredList = [];
    if (query.isEmpty) {
      tempFilteredList = users;
    } else {
      tempFilteredList = users.where((user) {
        final emailLower = user['email']?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();
        return emailLower.contains(queryLower);
      }).toList();
    }
    setState(() {
      filteredUsers = tempFilteredList;
    });
  }

  Future<void> fetchUsers() async {
    if (!mounted) return;
    setState(() => isUsersLoading = true);
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final response = await http
            .get(Uri.parse("$userApiUrl?action=list"))
            .timeout(const Duration(seconds: 10));
        if (mounted) {
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            List<Map<String, String>> userList = [];
            if (data is Map &&
                data.containsKey('users') &&
                data['users'] is List) {
              userList =
                  (data['users'] as List).map<Map<String, String>>((email) {
                return {"email": email.toString(), "role": "User"};
              }).toList();
            }
            setState(() {
              users = userList;
              filteredUsers = userList;
              isUsersLoading = false;
            });
            if (users.isEmpty) {
              _toast("No valid user data received");
            }
            return;
          } else {
            if (attempt == 3) {
              setState(() => isUsersLoading = false);
              _toast("User API error: ${response.statusCode}");
              return;
            }
          }
        }
      } catch (e) {
        if (attempt == 3 && mounted) {
          setState(() => isUsersLoading = false);
          _toast("User fetch failed: $e");
        }
      }
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _showUserDevices(String email) async {
    Map<String, List<String>> deviceCategories = {};
    bool isLoadingDevices = true;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, dialogSetState) {
          Future<void> _refreshDevices() async {
            dialogSetState(() => isLoadingDevices = true);
            try {
              final response = await http
                  .get(Uri.parse("$userDevicesApiUrl?email_id=$email"));
              if (dialogContext.mounted) {
                if (response.statusCode == 200) {
                  final result = json.decode(response.body);
                  dialogSetState(() {
                    deviceCategories = {
                      for (var key in result.keys)
                        if (key != 'device_id' && key != 'email_id')
                          key: List<String>.from(result[key] ?? [])
                    };
                  });
                } else {
                  _toast(
                      "Failed to load devices: Status ${response.statusCode}");
                }
              }
            } catch (e) {
              _toast("Error fetching devices: $e");
            }
            if (dialogContext.mounted) {
              dialogSetState(() => isLoadingDevices = false);
            }
          }

          if (isLoadingDevices) {
            _refreshDevices();
          }
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final subtle = isDark ? Colors.white70 : Colors.black54;
          final strong = isDark ? Colors.white : Colors.black87;
          final bgColor = isDark ? const Color(0xFF161A22) : Colors.white;

          return Dialog(
            backgroundColor: bgColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          "Devices for $email",
                          style: TextStyle(
                              color: strong,
                              fontSize: 18,
                              fontWeight: FontWeight.w900),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.redAccent),
                            onPressed: () async {
                              await DeleteDeviceUtils.deleteDevices(
                                dialogContext,
                                email,
                                deviceCategories,
                                (updatedCategories) {
                                  dialogSetState(() {
                                    deviceCategories = updatedCategories;
                                  });
                                },
                              );
                            },
                            tooltip: 'Delete Devices',
                          ),
                          IconButton(
                            icon: Icon(Icons.refresh,
                                color: const Color(0xFF1976D2)),
                            onPressed: _refreshDevices,
                            tooltip: 'Refresh',
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: subtle),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Expanded(
                    child: isLoadingDevices
                        ? const Center(child: CircularProgressIndicator())
                        : deviceCategories.isEmpty
                            ? Center(
                                child: Text("No devices found",
                                    style: TextStyle(
                                        color: subtle,
                                        fontWeight: FontWeight.w500)))
                            : ListView.builder(
                                itemCount: deviceCategories.keys.length,
                                itemBuilder: (ctx, index) {
                                  final category =
                                      deviceCategories.keys.elementAt(index);
                                  final devices = deviceCategories[category]!;
                                  return ExpansionTile(
                                    iconColor: const Color(0xFF1976D2),
                                    collapsedIconColor: subtle,
                                    title: Text(
                                      category.trim(),
                                      style: TextStyle(
                                        color: strong,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    children: devices.map((device) {
                                      return ListTile(
                                        leading: const Icon(Icons.device_hub,
                                            color: Color(0xFF1976D2), size: 18),
                                        title: Text(
                                          device,
                                          style: TextStyle(
                                              color: strong,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addDeviceToUser(String email, String deviceId) async {
    await DeviceUtils.addDeviceToUser(
      context: context,
      email: email,
      deviceId: deviceId,
      allDevices: allDevices,
    );
    await _loadDeviceData();
  }

  void _showAddDeviceDialog(String email) {
    final TextEditingController deviceIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final strong = isDark ? Colors.white : Colors.black87;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Add Device to $email",
                style: TextStyle(color: strong, fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: deviceIdController,
                  style: TextStyle(color: strong),
                  decoration: InputDecoration(
                    labelText: "Enter Device ID (e.g., CP001)",
                    labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF1976D2), width: 1.5),
                    ),
                    helperText: "Use 2 uppercase letters + 3 digits",
                    helperStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: deviceIdController.text.trim().isEmpty
                    ? null
                    : () {
                        final deviceId =
                            deviceIdController.text.trim().toUpperCase();
                        Navigator.pop(context);
                        _addDeviceToUser(email, deviceId);
                      },
                child: const Text("Add"),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? parseDate(String? dateStr) => DevicePrefixUtils.parseDate(dateStr);

  // ── Helpers to resolve sensorName from a device map entry ──────────────────
  String _resolveSensorName(Map<String, dynamic> device) {
    final deviceId = (device['DeviceId'] ?? '').toString();
    final topic = (device['Topic'] ?? '').toString();
    return DevicePrefixUtils.resolveSensorName(deviceId, topic);
  }

  // ── Counts for the three top-level stat cards ──────────────────────────────
  int get annamCount =>
      allDevices.where((d) => _isAnnamSensor(_resolveSensorName(d))).length;

  int get annamTestingCount => allDevices
      .where((d) => _isAnnamTestingSensor(_resolveSensorName(d)))
      .length;

  int get partnershipCount => allDevices
      .where((d) => _isPartnershipSensor(_resolveSensorName(d)))
      .length;

  // ── NEW: Active/Inactive counts scoped to the selected brand ───────────────
  Map<String, int> get brandFilteredCounts {
    Iterable<Map<String, dynamic>> base = selectedBrand == "All"
        ? allDevices
        : allDevices.where((d) {
            final sn = _resolveSensorName(d);
            if (selectedBrand == "ANNAM") return _isAnnamSensor(sn);
            if (selectedBrand == "Partnership") return _isPartnershipSensor(sn);
            if (selectedBrand == "Testing") return _isAnnamTestingSensor(sn);
            return true;
          });

    if (selectedCategory != null && selectedCategory != 'All Categories') {
      base = base.where((d) {
        final sn = _resolveSensorName(d);
        final state = _getStateForSensor(sn);
        return state == selectedCategory;
      });
    }

    final list = base.toList();
    return {
      "All": list.length,
      "Active": list.where((d) => d['isActive'] == true).length,
      "Inactive": list.where((d) => d['isActive'] == false).length,
    };
  }

  // ── State → device count ────────────────────────────────────────────────────
  Map<String, int> get stateCountsForCard {
    final counts = <String, int>{};
    for (var device in allDevices) {
      final sensorName = _resolveSensorName(device);
      final state = _getStateForSensor(sensorName);
      counts[state] = (counts[state] ?? 0) + 1;
    }
    return counts;
  }

  // ── State counts scoped to each brand group ────────────────────────────────
  Map<String, int> _stateCountsFor(bool Function(String) predicate) {
    final counts = <String, int>{};
    for (var device in allDevices) {
      final sensorName = _resolveSensorName(device);
      if (!predicate(sensorName)) continue;
      final state = _getStateForSensor(sensorName);
      counts[state] = (counts[state] ?? 0) + 1;
    }
    return counts;
  }

  Map<String, int> get annamStateCounts => _stateCountsFor(_isAnnamSensor);
  Map<String, int> get annamTestingStateCounts =>
      _stateCountsFor(_isAnnamTestingSensor);
  Map<String, int> get partnershipStateCounts =>
      _stateCountsFor(_isPartnershipSensor);

  List<Map<String, String>> get uniqueCategories {
    final stateCounts = <String, int>{};

    // ── Only count devices that belong to the selected brand ─────────────────
    final brandFiltered = selectedBrand == "All"
        ? allDevices
        : allDevices.where((d) {
            final sn = _resolveSensorName(d);
            if (selectedBrand == "ANNAM") return _isAnnamSensor(sn);
            if (selectedBrand == "Partnership") return _isPartnershipSensor(sn);
            if (selectedBrand == "Testing") return _isAnnamTestingSensor(sn);
            return true;
          }).toList();

    for (var device in brandFiltered) {
      final sensorName = _resolveSensorName(device);
      final state = _getStateForSensor(sensorName);
      stateCounts[state] = (stateCounts[state] ?? 0) + 1;
    }

    final categories = stateCounts.keys.map((state) {
      return {
        'name': state,
        'display': '$state (${stateCounts[state]})',
      };
    }).toList();

    categories.sort((a, b) => a['name']!.compareTo(b['name']!));

    return [
      {'name': 'All Categories', 'display': 'All Categories'},
      ...categories,
    ];
  }

  List<Map<String, dynamic>> get filteredDevices {
    Iterable<Map<String, dynamic>> list = allDevices;

    // ── NEW: Brand filter ──────────────────────────────────────────────────
    if (selectedBrand != "All") {
      list = list.where((d) {
        final sn = _resolveSensorName(d);
        if (selectedBrand == "ANNAM") return _isAnnamSensor(sn);
        if (selectedBrand == "Partnership") return _isPartnershipSensor(sn);
        if (selectedBrand == "Testing") return _isAnnamTestingSensor(sn);
        return true;
      });
    }

    if (!_isRestrictedAdmin) {
      if (filter == "Active") {
        list = list.where((d) => d['isActive'] == true);
      } else if (filter == "Inactive") {
        list = list.where((d) => d['isActive'] == false);
      }
    }
    if (selectedCategory != null && selectedCategory != 'All Categories') {
      list = list.where((d) {
        final sensorName = _resolveSensorName(d);
        final state = _getStateForSensor(sensorName);
        return state == selectedCategory;
      });
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      list = list.where((d) {
        final deviceId = d['DeviceId']?.toString() ?? "";
        final topic = d['Topic']?.toString() ?? "";
        final group = d['group']?.toString() ?? "";
        final internalName =
            DevicePrefixUtils.resolveSensorName(deviceId, topic);
        final displayName = _toAnnamDisplayName(internalName);
        final location =
            _getLocationForSensor(internalName)?.toLowerCase() ?? "";

        return deviceId.toLowerCase().contains(q) ||
            group.toLowerCase().contains(q) ||
            topic.toLowerCase().contains(q) ||
            internalName.toLowerCase().contains(q) ||
            displayName.toLowerCase().contains(q) ||
            location.contains(q);
      });
    }
    // Exclude TS_018 and ANNAM001
    list = list.where((d) {
      final deviceId = (d['DeviceId'] ?? "").toString();
      final topic = (d['Topic'] ?? "").toString();
      final sn = DevicePrefixUtils.resolveSensorName(deviceId, topic).toUpperCase();
      final dn = _toAnnamDisplayName(sn).toUpperCase();
      final rawDevId = deviceId.toUpperCase();

      if (sn == 'TS018' || sn == 'TS_018' || dn == 'TS_018' || dn == 'TS018' || rawDevId == 'TS018' || rawDevId == 'TS_018') {
        return false;
      }
      if (sn == 'ANNAM001' || dn == 'ANNAM001' || rawDevId == 'ANNAM001') {
        return false;
      }
      return true;
    });

    int getSortRank(Map<String, dynamic> d) {
      final deviceId = (d['DeviceId'] ?? "").toString();
      final topic = (d['Topic'] ?? "").toString();
      final sn = DevicePrefixUtils.resolveSensorName(deviceId, topic);
      final dn = _toAnnamDisplayName(sn);
      final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);

      if (sn == 'CP001' || dn == 'ANNAM_CP01' || sn.contains('CP01') || dn.contains('ANNAM_CP01')) {
        return 0;
      }
      if (mapped.prefix == 'KR' || mapped.prefix == 'PJ' || sn.startsWith('KR') || sn.startsWith('PJ') || topic.toLowerCase().contains('kerala') || topic.toLowerCase().contains('punjab')) {
        return 1;
      }
      return 2;
    }

    final sorted = list.toList()
      ..sort((a, b) {
        final rankA = getSortRank(a);
        final rankB = getSortRank(b);
        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }
        if (a['isActive'] == b['isActive']) {
          return a['DeviceId'].toString().compareTo(b['DeviceId'].toString());
        }
        return (a['isActive'] as bool) ? -1 : 1;
      });
    return sorted;
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  ({String category, String prefix}) _mapCategoryAndPrefix(String topic) =>
      DevicePrefixUtils.mapCategoryAndPrefix(topic);

  Future<void> _deleteUser(String email) async {
    await DeleteDeviceUtils.deleteAccount(context, email, null);
    await fetchUsers();
  }

  List<String> getParamNamesForSensor(String sensorName) {
    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    return _parameterNamesMap[topic] ?? [];
  }

  String buildTopicFromSensorName(String sensorName) =>
      DevicePrefixUtils.buildTopicFromSensorName(sensorName);

  Future<void> _loadTimestampMapFromApi() async {
    final urls = [
      'https://d1b09mxwt0ho4j.cloudfront.net/default/WS_Device_Activity',
      'https://whnmva5pb4.execute-api.us-east-1.amazonaws.com/default/WS_Latest_Api',
    ];
    final excludedParams = {
      'Longitude',
      'Latitude',
      'IMEINumber',
      'SignalStrength',
      'ExpiresAt',
      'Topic',
      'City',
      'State',
      'District',
      'geo_status',
      'Interval',
      'epoch_ts'
    };
    try {
      final responses = await Future.wait(
        urls.map(
          (url) => http.get(Uri.parse(url)).catchError((e) {
            debugPrint("Error fetching timestamps $url: $e");
            return http.Response('{"devices":[]}', 500);
          }),
        ),
      );
      Map<String, DateTime> tempMap = {};
      Map<String, List<String>> paramNamesMap = {};
      Map<String, String> tempIntervalMap = {};
      for (var response in responses) {
        if (response.statusCode != 200) continue;
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final List<dynamic> devices = jsonResponse['devices'] ?? [];
        for (var item in devices) {
          final rawTopic =
              (item['deviceid#topic'] ?? item['deviceId#topic'] ?? '')
                  .toString();
          if (rawTopic.isEmpty) continue;
          String ts = (item['TimeStamp_IST'] ?? '').toString();
          if (rawTopic.toLowerCase().contains('jio_logger') ||
              rawTopic.toLowerCase().contains('/jw')) {
            final mqttTime = item['MQTT_TopicTime'] ?? item['mqtt_topic_time'];
            if (mqttTime != null && mqttTime.toString().isNotEmpty) {
              ts = mqttTime.toString();
            }
          }
          if (ts.isEmpty) continue;
          final timestamp = parseDate(ts);
          if (timestamp != null) {
            final key = rawTopic.toLowerCase();
            if (tempMap.containsKey(key)) {
              if (timestamp.isAfter(tempMap[key]!)) {
                tempMap[key] = timestamp;
                paramNamesMap[key] = [];
                final city = (item['City'] ?? '').toString().trim();
                final district = (item['District'] ?? '').toString().trim();
                final state = (item['State'] ?? '').toString().trim();

                // Normalize: remove "district" suffix and fix typos
                String norm(String s) {
                  String n = s.trim();
                  if (n.toLowerCase() == 'chandigarh') return 'Chandigarh';
                  n = n.replaceFirst(
                      RegExp(r'\s+district$', caseSensitive: false), '');
                  return n;
                }

                final parts = {
                  if (city.isNotEmpty) norm(city),
                  if (district.isNotEmpty) norm(district),
                  if (state.isNotEmpty) norm(state)
                }.toList();
                if (parts.isNotEmpty) {
                  final locationStr = parts.join(', ');
                  locationMap[key] = locationStr;
                  // Also store under ANNAM_ID-based key for devices like WS_69
                  final annamId = (item['ANNAM_ID'] ?? '').toString().trim();
                  final topicPart = rawTopic.contains('#') ? rawTopic.split('#').last : '';
                  if (annamId.isNotEmpty && topicPart.isNotEmpty) {
                    locationMap['${annamId.toLowerCase()}#${topicPart.toLowerCase()}'] = locationStr;
                  }
                }
                final interval = (item['Interval'] ?? '').toString().trim();
                if (interval.isNotEmpty) {
                  tempIntervalMap[key] = interval;
                }
                item.forEach((k, v) {
                  if (v != null &&
                      k != 'deviceid#topic' &&
                      k != 'TimeStamp_IST' &&
                      !excludedParams.contains(k)) {
                    paramNamesMap[key]!.add(k);
                  }
                });
              }
            } else {
              tempMap[key] = timestamp;
              paramNamesMap[key] = [];
              final city = (item['City'] ?? '').toString().trim();
              final district = (item['District'] ?? '').toString().trim();
              final state = (item['State'] ?? '').toString().trim();

              // Normalize: remove "district" suffix and fix typos
              String norm(String s) {
                String n = s.trim();
                if (n.toLowerCase() == 'chandigarh') return 'Chandigarh';
                n = n.replaceFirst(
                    RegExp(r'\s+district$', caseSensitive: false), '');
                return n;
              }

              final parts = {
                if (city.isNotEmpty) norm(city),
                if (district.isNotEmpty) norm(district),
                if (state.isNotEmpty) norm(state)
              }.toList();
              if (parts.isNotEmpty) {
                final locationStr = parts.join(', ');
                locationMap[key] = locationStr;
                // Also store under ANNAM_ID-based key for devices like WS_69
                final annamId = (item['ANNAM_ID'] ?? '').toString().trim();
                final topicPart = rawTopic.contains('#') ? rawTopic.split('#').last : '';
                if (annamId.isNotEmpty && topicPart.isNotEmpty) {
                  locationMap['${annamId.toLowerCase()}#${topicPart.toLowerCase()}'] = locationStr;
                }
              }
              final interval = (item['Interval'] ?? '').toString().trim();
              if (interval.isNotEmpty) {
                tempIntervalMap[key] = interval;
              }
              item.forEach((k, v) {
                if (v != null &&
                    k != 'deviceid#topic' &&
                    k != 'TimeStamp_IST' &&
                    !excludedParams.contains(k)) {
                  paramNamesMap[key]!.add(k);
                }
              });
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _timestampMap = tempMap;
          _parameterNamesMap = paramNamesMap;
          _locationMap = locationMap;
          _apiIntervalMap = tempIntervalMap;
        });
      }
    } catch (e) {
      print('Error loading timestamps: $e');
    }
  }

  String? _getUpdateInterval(String sensorName) {
    final topic = buildTopicFromSensorName(sensorName).toLowerCase();
    if (_apiIntervalMap.containsKey(topic)) {
      return _apiIntervalMap[topic];
    }
    return DevicePrefixUtils.getExpectedInterval(sensorName);
  }

  String? _getOtaApiUrl(String prefix, {String sensorName = ''}) =>
      DevicePrefixUtils.getOtaApiUrl(prefix, sensorName: sensorName);

  void _navigateToOTA(String sensorName, String? updateInterval) {
    String? intervalType;
    int? intervalValue;
    if (updateInterval != null) {
      final parts = updateInterval.split(' ');
      if (parts.length == 2) {
        intervalValue = int.tryParse(parts[0]);
        intervalType = parts[1] == 'min' ? 'Minutely' : 'Hourly';
      }
    }
    final displayDeviceId = _toAnnamDisplayName(sensorName);
    DataSendDialog.show(
      context,
      initialDeviceId: sensorName,
      displayDeviceId: displayDeviceId,
      initialIntervalType: intervalType,
      initialInterval: intervalValue,
    );
  }

  void _showIntervalPopup(String updateInterval) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF161A22) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Device Data Interval",
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            "Device Data Interval: $updateInterval",
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: getResponsiveFontSize(context, 14, 16),
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
              ),
              child: const Text(
                "Close",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Professional Light Mode Palette
    final bgColor = isDark
        ? const Color(0xFF0B141D) // Deep Midnight background
        : const Color(0xFFF5F7FA); // Clean whitish/blue-grey background

    final appBarColor = isDark
        ? const Color(0xFF14212B)
        : const Color(0xFF1976D2); // Corporate Blue

    final card = isDark ? const Color(0xFF1D2B38) : Colors.white;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final strong =
        isDark ? Colors.white : Colors.black87; // Darker for high contrast
    final borderColor = isDark ? Colors.white24 : Colors.black12;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? strong : Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Admin Dashboard',
          style: TextStyle(
            color: isDark ? strong : Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            fontSize: getResponsiveFontSize(context, 18, 26),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Device Health Status',
            icon: Icon(Icons.health_and_safety_outlined,
                color: isDark ? strong : Colors.white),
            onPressed: () =>
                NavigationUtils.navigateTo(context, '/admin/health'),
          ),
          IconButton(
            tooltip: 'Refresh devices',
            padding: const EdgeInsets.only(left: 4, right: 12),
            constraints: const BoxConstraints(),
            onPressed: () {
              _loadDeviceData();
              _loadTimestampMapFromApi();
              _fetchQualitySummary();
              _fetchHealthSummary();
            },
            icon: Icon(Icons.refresh, color: isDark ? strong : Colors.white),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth <= 600;
          final padding = isMobile ? 10.0 : 15.0;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                // ── Top Stat Cards ───────────────────────────────────────────
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth <= 600;

                    final brandCards = <Widget>[
                      _StatCard(
                        onTap: () {
                          setState(() {
                            selectedBrand = "All";
                            selectedCategory = null;
                            devicesToShow = 12;
                          });
                          _scrollToSection(_devicesSectionKey);
                        },
                        title: "Total Sensors",
                        value: "${allDevices.length}",
                        icon: Icons.dashboard_customize_outlined,
                        iconBg: Colors.blueGrey,
                        cardColor: card,
                        strong: strong,
                        subtle: subtle,
                        isSelected: selectedBrand == "All",
                      ),
                      _StatCard(
                        onTap: () {
                          setState(() {
                            selectedBrand = "ANNAM";
                            selectedCategory = null;
                            devicesToShow = 12;
                          });
                          _scrollToSection(_devicesSectionKey);
                        },
                        title: "ANNAM Sensors",
                        value: "$annamCount",
                        icon: Icons.sensors,
                        iconBg: Colors.teal,
                        cardColor: card,
                        strong: strong,
                        subtle: subtle,
                        isSelected: selectedBrand == "ANNAM",
                      ),
                      _StatCard(
                        onTap: () {
                          setState(() {
                            selectedBrand = "Partnership";
                            selectedCategory = null;
                            devicesToShow = 12;
                          });
                          _scrollToSection(_devicesSectionKey);
                        },
                        title: "Partnership Sensors",
                        value: "$partnershipCount",
                        icon: Icons.handshake_outlined,
                        iconBg: Colors.blue,
                        cardColor: card,
                        strong: strong,
                        subtle: subtle,
                        isSelected: selectedBrand == "Partnership",
                      ),
                      _StatCard(
                        onTap: () {
                          setState(() {
                            selectedBrand = "Testing";
                            selectedCategory = null;
                            devicesToShow = 12;
                          });
                          _scrollToSection(_devicesSectionKey);
                        },
                        title: "Testing Sensors",
                        value: "$annamTestingCount",
                        icon: Icons.science_outlined,
                        iconBg: Colors.orange,
                        cardColor: card,
                        strong: strong,
                        subtle: subtle,
                        isSelected: selectedBrand == "Testing",
                      ),
                    ];

                    // ── Restricted admin layout ─────────────────────────────
                    if (_isRestrictedAdmin) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          isMobile
                              ? GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1.6,
                                  children: brandCards,
                                )
                              : Row(
                                  children: brandCards
                                      .map((c) => Expanded(child: c))
                                      .toList(),
                                ),
                          const SizedBox(height: 12),
                          isMobile
                              ? GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio:
                                      1.0, // Taller cards for list of states
                                  children: [
                                    _BrandStatesCard(
                                      title: 'ANNAM – States',
                                      iconBg: Colors.teal,
                                      icon: Icons.sensors,
                                      cardColor: card,
                                      strong: strong,
                                      subtle: subtle,
                                      stateCounts: annamStateCounts,
                                    ),
                                    _BrandStatesCard(
                                      title: 'Partnership – States',
                                      iconBg: Colors.blue,
                                      icon: Icons.handshake_outlined,
                                      cardColor: card,
                                      strong: strong,
                                      subtle: subtle,
                                      stateCounts: partnershipStateCounts,
                                    ),
                                    _BrandStatesCard(
                                      title: 'Testing – States',
                                      iconBg: Colors.orange,
                                      icon: Icons.science_outlined,
                                      cardColor: card,
                                      strong: strong,
                                      subtle: subtle,
                                      stateCounts: annamTestingStateCounts,
                                    ),
                                    _ParametersCard(
                                      cardColor: card,
                                      strong: strong,
                                      subtle: subtle,
                                    ),
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _BrandStatesCard(
                                        title: 'ANNAM – States',
                                        iconBg: Colors.teal,
                                        icon: Icons.sensors,
                                        cardColor: card,
                                        strong: strong,
                                        subtle: subtle,
                                        stateCounts: annamStateCounts,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _BrandStatesCard(
                                        title: 'Partnership – States',
                                        iconBg: Colors.blue,
                                        icon: Icons.handshake_outlined,
                                        cardColor: card,
                                        strong: strong,
                                        subtle: subtle,
                                        stateCounts: partnershipStateCounts,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _BrandStatesCard(
                                        title: 'Testing – States',
                                        iconBg: Colors.orange,
                                        icon: Icons.science_outlined,
                                        cardColor: card,
                                        strong: strong,
                                        subtle: subtle,
                                        stateCounts: annamTestingStateCounts,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _ParametersCard(
                                        cardColor: card,
                                        strong: strong,
                                        subtle: subtle,
                                      ),
                                    ),
                                  ],
                                ),
                        ],
                      );
                    }

                    // ── Normal admin layout ──────────────────────────────────
                    final crossAxisCount = constraints.maxWidth < 600
                        ? 2
                        : (constraints.maxWidth / 280).floor().clamp(1, 4);
                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: constraints.maxWidth < 600 ? 1.4 : 2.5,
                      children: brandCards,
                    );
                  },
                ),

                const SizedBox(height: 18),

                Column(
                  children: [
                    if (!_isRestrictedAdmin)
                      _buildAlertsDashboardSection(
                          strong, subtle, card, isDark),
                    const SizedBox(height: 18),
                    // ── Devices Section ──────────────────────────────────────
                    _SectionCard(
                      key: _devicesSectionKey,
                      title: "Devices",
                      cardColor: card,
                      strong: strong,
                      subtle: subtle,
                      child: isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SearchField(
                                      hint:
                                          "Search Device ID, Group, Location...",
                                      strong: strong,
                                      subtle: subtle,
                                      isDark: isDark,
                                      onChanged: (value) {
                                        setState(() {
                                          searchQuery = value.trim();
                                          devicesToShow = 12;
                                        });
                                      },
                                    ),

                                    const SizedBox(height: 10),

                                    // ── Brand filter chips ─────────────────
                                    // ── Brand filter: dropdown on mobile, chips on desktop ──
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final brands = [
                                          "All",
                                          "ANNAM",
                                          "Partnership",
                                          "Testing"
                                        ];

                                        String brandLabel(String brand) {
                                          switch (brand) {
                                            case "All":
                                              return "All (${allDevices.length})";
                                            case "ANNAM":
                                              return "ANNAM ($annamCount)";
                                            case "Partnership":
                                              return "Partnership ($partnershipCount)";
                                            case "Testing":
                                              return "Testing ($annamTestingCount)";
                                            default:
                                              return brand;
                                          }
                                        }

                                        Color brandColor(String brand) {
                                          switch (brand) {
                                            case "ANNAM":
                                              return Colors.teal;
                                            case "Partnership":
                                              return Colors.blue;
                                            case "Testing":
                                              return Colors.orange;
                                            default:
                                              return Colors.grey.shade700;
                                          }
                                        }

                                        if (constraints.maxWidth < 600) {
                                          // ── Mobile: single dropdown ──────────────────────────────────────────
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? const Color(0xFF1D2B38)
                                                  : Colors.black12
                                                      .withOpacity(0.06),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                isExpanded: true,
                                                value: selectedBrand,
                                                icon: Icon(
                                                    Icons.keyboard_arrow_down,
                                                    size: 18,
                                                    color: subtle),
                                                dropdownColor: isDark
                                                    ? const Color(0xFF1D2B38)
                                                    : Colors.white,
                                                items: brands.map((brand) {
                                                  return DropdownMenuItem<
                                                      String>(
                                                    value: brand,
                                                    child: Text(
                                                      brandLabel(brand),
                                                      style: TextStyle(
                                                        color: selectedBrand ==
                                                                brand
                                                            ? brandColor(brand)
                                                            : strong,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontSize:
                                                            getResponsiveFontSize(
                                                                context,
                                                                12,
                                                                13),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      selectedBrand = val;
                                                      selectedCategory = null;
                                                      devicesToShow = 12;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        }

                                        // ── Desktop: chips ───────────────────────────────────────────────────
                                        return Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          children: brands.map((brand) {
                                            final selected =
                                                selectedBrand == brand;
                                            final color = brandColor(brand);
                                            return ChoiceChip(
                                              label: Text(
                                                brandLabel(brand),
                                                style: TextStyle(
                                                  color: selected
                                                      ? Colors.white
                                                      : strong,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize:
                                                      getResponsiveFontSize(
                                                          context, 11, 13),
                                                ),
                                              ),
                                              selected: selected,
                                              selectedColor: isDark
                                                  ? color
                                                  : const Color(0xFF1976D2),
                                              backgroundColor: isDark
                                                  ? const Color(0xFF1D2B38)
                                                  : Colors.black
                                                      .withOpacity(0.03),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                side: BorderSide(
                                                  color: selected
                                                      ? Colors.transparent
                                                      : borderColor,
                                                ),
                                              ),
                                              onSelected: (_) {
                                                setState(() {
                                                  selectedBrand = brand;
                                                  selectedCategory = null;
                                                  devicesToShow = 12;
                                                });
                                              },
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),

                                    const SizedBox(height: 10),

                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        if (constraints.maxWidth < 600) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              // Row 1: Status + Category (same size)
                                              if (!_isRestrictedAdmin)
                                                IntrinsicHeight(
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      // Status dropdown
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF1D2B38)
                                                                : Colors.black12
                                                                    .withOpacity(
                                                                        0.05),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: subtle
                                                                    .withOpacity(
                                                                        0.15)),
                                                          ),
                                                          child:
                                                              DropdownButtonHideUnderline(
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              isExpanded: true,
                                                              value: filter,
                                                              icon: Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down,
                                                                  size: 18,
                                                                  color:
                                                                      subtle),
                                                              items: [
                                                                "All",
                                                                "Active",
                                                                "Inactive"
                                                              ].map((opt) {
                                                                final count =
                                                                    brandFilteredCounts[
                                                                        opt];
                                                                return DropdownMenuItem<
                                                                    String>(
                                                                  value: opt,
                                                                  child: Text(
                                                                    "$opt ($count)",
                                                                    style:
                                                                        TextStyle(
                                                                      color:
                                                                          strong,
                                                                      fontSize: getResponsiveFontSize(
                                                                          context,
                                                                          11,
                                                                          13),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                );
                                                              }).toList(),
                                                              onChanged: (val) {
                                                                if (val !=
                                                                    null) {
                                                                  setState(() =>
                                                                      filter =
                                                                          val);
                                                                }
                                                              },
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Category dropdown
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF1D2B38)
                                                                : Colors.black12
                                                                    .withOpacity(
                                                                        0.05),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: subtle
                                                                    .withOpacity(
                                                                        0.15)),
                                                          ),
                                                          child:
                                                              DropdownButtonHideUnderline(
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              isExpanded: true,
                                                              value: selectedCategory ??
                                                                  'All Categories',
                                                              icon: Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down,
                                                                  size: 18,
                                                                  color:
                                                                      subtle),
                                                              dropdownColor: isDark
                                                                  ? const Color(
                                                                      0xFF161A22)
                                                                  : Colors
                                                                      .white,
                                                              items: isLoading
                                                                  ? [
                                                                      DropdownMenuItem(
                                                                        value:
                                                                            'All Categories',
                                                                        child: Text(
                                                                            'All Categories',
                                                                            overflow:
                                                                                TextOverflow.ellipsis),
                                                                      )
                                                                    ]
                                                                  : uniqueCategories
                                                                      .map((e) =>
                                                                          DropdownMenuItem(
                                                                            value:
                                                                                e['name'],
                                                                            child:
                                                                                Text(e['display']!, overflow: TextOverflow.ellipsis),
                                                                          ))
                                                                      .toList(),
                                                              onChanged:
                                                                  isLoading
                                                                      ? null
                                                                      : (v) {
                                                                          if (v !=
                                                                              null) {
                                                                            setState(() {
                                                                              selectedCategory = v;
                                                                              devicesToShow = 12;
                                                                            });
                                                                          }
                                                                        },
                                                              hint: Text(
                                                                  "Category",
                                                                  style: TextStyle(
                                                                      color:
                                                                          subtle)),
                                                              style: TextStyle(
                                                                  color: strong,
                                                                  fontSize:
                                                                      getResponsiveFontSize(
                                                                          context,
                                                                          12,
                                                                          14)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      // Refresh icon (same height as dropdowns)
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (isDark
                                                                  ? Colors
                                                                      .white10
                                                                  : Colors
                                                                      .black12)
                                                              .withOpacity(
                                                                  0.05),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                              color: subtle
                                                                  .withOpacity(
                                                                      0.15)),
                                                        ),
                                                        child: IconButton(
                                                          tooltip: "Refresh",
                                                          onPressed: () {
                                                            _loadDeviceData();
                                                            _fetchQualitySummary();
                                                            _fetchHealthSummary();
                                                          },
                                                          icon: Icon(
                                                              Icons.refresh,
                                                              color: strong),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      8),
                                                          constraints:
                                                              const BoxConstraints(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                // Restricted admin: only category + refresh
                                                IntrinsicHeight(
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      Expanded(
                                                        child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      10,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isDark
                                                                ? const Color(
                                                                    0xFF1D2B38)
                                                                : Colors.black12
                                                                    .withOpacity(
                                                                        0.05),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8),
                                                            border: Border.all(
                                                                color: subtle
                                                                    .withOpacity(
                                                                        0.15)),
                                                          ),
                                                          child:
                                                              DropdownButtonHideUnderline(
                                                            child:
                                                                DropdownButton<
                                                                    String>(
                                                              isExpanded: true,
                                                              value: selectedCategory ??
                                                                  'All Categories',
                                                              icon: Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down,
                                                                  size: 18,
                                                                  color:
                                                                      subtle),
                                                              dropdownColor: isDark
                                                                  ? const Color(
                                                                      0xFF2C3E50)
                                                                  : Colors
                                                                      .white,
                                                              items: isLoading
                                                                  ? [
                                                                      DropdownMenuItem(
                                                                        value:
                                                                            'All Categories',
                                                                        child: Text(
                                                                            'All Categories',
                                                                            overflow:
                                                                                TextOverflow.ellipsis),
                                                                      )
                                                                    ]
                                                                  : uniqueCategories
                                                                      .map((e) =>
                                                                          DropdownMenuItem(
                                                                            value:
                                                                                e['name'],
                                                                            child:
                                                                                Text(e['display']!, overflow: TextOverflow.ellipsis),
                                                                          ))
                                                                      .toList(),
                                                              onChanged:
                                                                  isLoading
                                                                      ? null
                                                                      : (v) {
                                                                          if (v !=
                                                                              null) {
                                                                            setState(() {
                                                                              selectedCategory = v;
                                                                              devicesToShow = 12;
                                                                            });
                                                                          }
                                                                        },
                                                              hint: Text(
                                                                  "Category",
                                                                  style: TextStyle(
                                                                      color:
                                                                          subtle)),
                                                              style: TextStyle(
                                                                  color: strong,
                                                                  fontSize:
                                                                      getResponsiveFontSize(
                                                                          context,
                                                                          12,
                                                                          14)),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: (isDark
                                                                  ? Colors
                                                                      .white10
                                                                  : Colors
                                                                      .black12)
                                                              .withOpacity(
                                                                  0.05),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8),
                                                          border: Border.all(
                                                              color: subtle
                                                                  .withOpacity(
                                                                      0.15)),
                                                        ),
                                                        child: IconButton(
                                                          tooltip: "Refresh",
                                                          onPressed: () {
                                                            _loadDeviceData();
                                                            _loadTimestampMapFromApi();
                                                            _fetchQualitySummary();
                                                            _fetchHealthSummary();
                                                          },
                                                          icon: Icon(
                                                              Icons.refresh,
                                                              color: strong),
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  horizontal:
                                                                      8),
                                                          constraints:
                                                              const BoxConstraints(),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          );
                                        } else {
                                          // Desktop layout
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              if (!_isRestrictedAdmin)
                                                // ── Active/Inactive with brand-scoped counts (desktop) ──
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  children: [
                                                    "All",
                                                    "Active",
                                                    "Inactive"
                                                  ].map((opt) {
                                                    final selected =
                                                        filter == opt;
                                                    final count =
                                                        brandFilteredCounts[
                                                                opt] ??
                                                            0;
                                                    Color optColor =
                                                        const Color(0xFF1976D2);
                                                    if (opt == "Active")
                                                      optColor = Colors.green;
                                                    if (opt == "Inactive")
                                                      optColor = Colors.red;

                                                    return ChoiceChip(
                                                      label: Text(
                                                        "$opt ($count)",
                                                        style: TextStyle(
                                                          color: selected
                                                              ? Colors.white
                                                              : strong,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize:
                                                              getResponsiveFontSize(
                                                                  context,
                                                                  11,
                                                                  13),
                                                        ),
                                                      ),
                                                      selected: selected,
                                                      selectedColor: optColor,
                                                      backgroundColor: isDark
                                                          ? Colors.white
                                                              .withOpacity(0.05)
                                                          : Colors.black
                                                              .withOpacity(
                                                                  0.03),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        side: BorderSide(
                                                          color: selected
                                                              ? Colors
                                                                  .transparent
                                                              : borderColor,
                                                        ),
                                                      ),
                                                      onSelected: (_) =>
                                                          setState(() =>
                                                              filter = opt),
                                                    );
                                                  }).toList(),
                                                ),
                                              DropdownButton<String>(
                                                value: selectedCategory ??
                                                    'All Categories',
                                                items: isLoading
                                                    ? [
                                                        DropdownMenuItem(
                                                          value:
                                                              'All Categories',
                                                          child: Text(
                                                              'All Categories'),
                                                        )
                                                      ]
                                                    : uniqueCategories
                                                        .map((e) =>
                                                            DropdownMenuItem(
                                                              value: e['name'],
                                                              child: Text(e[
                                                                  'display']!),
                                                            ))
                                                        .toList(),
                                                onChanged: isLoading
                                                    ? null
                                                    : (v) {
                                                        if (v != null) {
                                                          setState(() {
                                                            selectedCategory =
                                                                v;
                                                            devicesToShow = 12;
                                                          });
                                                        }
                                                      },
                                                hint: Text("Select Category",
                                                    style: TextStyle(
                                                        color: subtle)),
                                                style: TextStyle(
                                                    color: strong,
                                                    fontSize:
                                                        getResponsiveFontSize(
                                                            context, 12, 14)),
                                                dropdownColor: isDark
                                                    ? const Color(0xFF2C3E50)
                                                    : Colors.white,
                                              ),
                                              IconButton(
                                                tooltip: "Refresh",
                                                onPressed: () {
                                                  _loadDeviceData();
                                                  _loadTimestampMapFromApi();
                                                },
                                                icon: Icon(Icons.refresh,
                                                    color: strong),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                if (filteredDevices.isEmpty &&
                                    searchQuery.isEmpty)
                                  Center(
                                    child: Text("No devices found",
                                        style: TextStyle(color: subtle)),
                                  )
                                else
                                  Column(
                                    children: [
                                       if (filteredDevices.isNotEmpty)
                                         LayoutBuilder(
                                           builder: (context, constraints) {
                                             final width = constraints.maxWidth;
                                             int crossAxisCount = 1;
                                             if (width > 1100) {
                                               crossAxisCount = 3;
                                             } else if (width > 650) {
                                               crossAxisCount = 2;
                                             }

                                             final visibleDevices = filteredDevices.asMap().entries.take(devicesToShow).toList();

                                             if (crossAxisCount > 1) {
                                               return GridView.builder(
                                                 shrinkWrap: true,
                                                 physics: const NeverScrollableScrollPhysics(),
                                                 gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                   crossAxisCount: crossAxisCount,
                                                   mainAxisExtent: 76,
                                                   crossAxisSpacing: 14,
                                                   mainAxisSpacing: 14,
                                                 ),
                                                 itemCount: visibleDevices.length,
                                                 itemBuilder: (context, i) {
                                                   final entry = visibleDevices[i];
                                                   return _buildDeviceCard(
                                                     context: context,
                                                     idx: entry.key,
                                                     d: entry.value,
                                                     isDark: isDark,
                                                     strong: strong,
                                                     subtle: subtle,
                                                   );
                                                 },
                                               );
                                             }

                                             return Column(
                                               children: visibleDevices
                                                   .map((entry) => Padding(
                                                         padding: const EdgeInsets.only(bottom: 12),
                                                         child: _buildDeviceCard(
                                                           context: context,
                                                           idx: entry.key,
                                                           d: entry.value,
                                                           isDark: isDark,
                                                           strong: strong,
                                                           subtle: subtle,
                                                         ),
                                                       ))
                                                   .toList(),
                                             );
                                           },
                                         ),
                                      if (devicesToShow <
                                          filteredDevices.length)
                                        TextButton(
                                          onPressed: () => setState(() {
                                            devicesToShow = (devicesToShow + 12)
                                                .clamp(
                                                    0, filteredDevices.length);
                                          }),
                                          child: const Text("Show More"),
                                        )
                                      else if (filteredDevices.length > 12)
                                        TextButton(
                                          onPressed: () => setState(
                                              () => devicesToShow = 10),
                                          child: const Text("Show Less"),
                                        ),

                                      // GPS Sensors tile (moved to end, only show for ANNAM when expanded)
                                      if (selectedBrand == "Testing" &&
                                          (selectedCategory == null ||
                                              selectedCategory ==
                                                  'All Categories') &&
                                          devicesToShow >=
                                              filteredDevices.length) ...[
                                        // Divider(
                                        //     color: subtle.withOpacity(0.12)),
                                        InkWell(
                                          hoverColor: isDark
                                              ? const Color(0xFF2C3E50)
                                                  .withOpacity(0.6)
                                              : const Color(0xFF5BAA9D)
                                                  .withOpacity(0.9),
                                          onTap: () {
                                            NavigationUtils.navigateTo(
                                                context, '/deviceinfo');
                                          },
                                          child: ListTile(
                                            leading: _StatusDot(
                                              color: _isRestrictedAdmin
                                                  ? Colors.grey
                                                  : Colors.red,
                                            ),
                                            title: Text(
                                              "GPS Sensors",
                                              style: TextStyle(
                                                color: strong,
                                                fontWeight: FontWeight.w700,
                                                fontSize: getResponsiveFontSize(
                                                    context, 12, 14),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Rupnagar, Punjab",
                                                  style: TextStyle(
                                                    color: subtle,
                                                    fontSize:
                                                        getResponsiveFontSize(
                                                            context, 10, 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                    ),
                    if (!_hideSensitiveSections) ...[
                      const SizedBox(height: 18),

                      // ── Users Section ────────────────────────────────────────
                      _SectionCard(
                        key: _usersSectionKey,
                        title: "User Accounts",
                        cardColor: card,
                        strong: strong,
                        subtle: subtle,
                        child: isUsersLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : Column(
                                children: [
                                  _SearchField(
                                    hint: "Search user by email...",
                                    onChanged: _filterUsers,
                                    strong: strong,
                                    subtle: subtle,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 12),
                                  filteredUsers.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 24.0),
                                            child: Text(
                                              userSearchQuery.isNotEmpty
                                                  ? "No users found for '$userSearchQuery'"
                                                  : "No users available",
                                              style: TextStyle(color: subtle),
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: Text(
                                                "Total ${filteredUsers.length}",
                                                style: TextStyle(color: subtle),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            const Divider(height: 1),
                                            const SizedBox(height: 8),
                                            Column(
                                              children: [
                                                ...filteredUsers
                                                    .take(usersToShow)
                                                    .map((u) => Column(
                                                          children: [
                                                            InkWell(
                                                              hoverColor: isDark
                                                                  ? const Color(
                                                                          0xFF2C3E50)
                                                                      .withOpacity(
                                                                          0.6)
                                                                  : const Color(
                                                                          0xFF1976D2)
                                                                      .withOpacity(
                                                                          0.08),
                                                              onTap: () =>
                                                                  _showUserDevices(
                                                                      u["email"]!),
                                                              child: ListTile(
                                                                contentPadding:
                                                                    EdgeInsets
                                                                        .symmetric(
                                                                  horizontal:
                                                                      getResponsiveFontSize(
                                                                          context,
                                                                          8,
                                                                          16),
                                                                ),
                                                                leading:
                                                                    CircleAvatar(
                                                                  radius:
                                                                      getResponsiveFontSize(
                                                                          context,
                                                                          12,
                                                                          22),
                                                                  backgroundColor: Colors
                                                                      .blue
                                                                      .withOpacity(
                                                                          0.12),
                                                                  child: Icon(
                                                                    Icons
                                                                        .person,
                                                                    color: Colors
                                                                        .blue,
                                                                    size: getResponsiveFontSize(
                                                                        context,
                                                                        14,
                                                                        24),
                                                                  ),
                                                                ),
                                                                title: Text(
                                                                  u["email"] ??
                                                                      "",
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        strong,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    fontSize:
                                                                        getResponsiveFontSize(
                                                                            context,
                                                                            12,
                                                                            14),
                                                                  ),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  maxLines: 2,
                                                                ),
                                                                trailing: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    IconButton(
                                                                      tooltip:
                                                                          "Add Device",
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      constraints:
                                                                          const BoxConstraints(),
                                                                      iconSize: getResponsiveFontSize(
                                                                          context,
                                                                          14,
                                                                          28),
                                                                      onPressed:
                                                                          () =>
                                                                              _showAddDeviceDialog(u["email"]!),
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .add,
                                                                          color:
                                                                              Colors.blue),
                                                                    ),
                                                                    SizedBox(
                                                                        width: getResponsiveFontSize(
                                                                            context,
                                                                            2,
                                                                            12)),
                                                                    IconButton(
                                                                      tooltip:
                                                                          "Delete",
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      constraints:
                                                                          const BoxConstraints(),
                                                                      iconSize: getResponsiveFontSize(
                                                                          context,
                                                                          14,
                                                                          28),
                                                                      onPressed:
                                                                          () =>
                                                                              _deleteUser(u["email"]!),
                                                                      icon: const Icon(
                                                                          Icons
                                                                              .delete,
                                                                          color:
                                                                              Colors.red),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                            Divider(
                                                                color: subtle
                                                                    .withOpacity(
                                                                        0.12)),
                                                          ],
                                                        )),
                                                if (usersToShow <
                                                    filteredUsers.length)
                                                  TextButton(
                                                    onPressed: () =>
                                                        setState(() {
                                                      usersToShow =
                                                          (usersToShow + 10)
                                                              .clamp(
                                                                  0,
                                                                  filteredUsers
                                                                      .length);
                                                    }),
                                                    child:
                                                        const Text("Show More"),
                                                  )
                                                else if (filteredUsers.length >
                                                    10)
                                                  TextButton(
                                                    onPressed: () => setState(
                                                        () => usersToShow = 10),
                                                    child:
                                                        const Text("Show Less"),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Brand-scoped state breakdown card ─────────────────────────────────────────
class _BrandStatesCard extends StatelessWidget {
  final String title;
  final Color iconBg;
  final IconData icon;
  final Color cardColor;
  final Color strong;
  final Color subtle;
  final Map<String, int> stateCounts;

  const _BrandStatesCard({
    required this.title,
    required this.iconBg,
    required this.icon,
    required this.cardColor,
    required this.strong,
    required this.subtle,
    required this.stateCounts,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = stateCounts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : a.key.compareTo(b.key);
      });

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 160;
      final titleFontSize = isSmall ? 11.0 : 13.0;
      final iconSize = isSmall ? 18.0 : 22.0;
      final badgeFontSize = isSmall ? 9.0 : 11.0;

      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strong.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: isSmall ? 32 : 40,
                    height: isSmall ? 32 : 40,
                    decoration: BoxDecoration(
                      color: iconBg.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
                    ),
                    child: Icon(icon, color: iconBg, size: iconSize),
                  ),
                  SizedBox(width: isSmall ? 6 : 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: strong,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: iconBg.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${sorted.length}',
                      style: TextStyle(
                        color: iconBg,
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 8 : 12),
              sorted.isEmpty
                  ? Text('No data…',
                      style:
                          TextStyle(color: subtle, fontSize: isSmall ? 10 : 12))
                  : SizedBox(
                      height: isSmall ? 60 : 72,
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: isSmall ? 4 : 8,
                          runSpacing: isSmall ? 4 : 8,
                          children: sorted.map((entry) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: isSmall ? 6 : 10,
                                  vertical: isSmall ? 4 : 6),
                              decoration: BoxDecoration(
                                color: iconBg.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: iconBg.withOpacity(0.2), width: 1),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${entry.key} ',
                                      style: TextStyle(
                                        color: subtle,
                                        fontSize: isSmall ? 9 : 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '${entry.value}',
                                      style: TextStyle(
                                        color: iconBg,
                                        fontSize: isSmall ? 10 : 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      );
    });
  }
}

class _ParametersCard extends StatelessWidget {
  final Color cardColor;
  final Color strong;
  final Color subtle;

  const _ParametersCard({
    required this.cardColor,
    required this.strong,
    required this.subtle,
  });

  static const List<Map<String, dynamic>> _parameters = [
    {'label': 'Temperature', 'icon': Icons.thermostat, 'color': Colors.orange},
    {'label': 'Pressure', 'icon': Icons.compress, 'color': Colors.blue},
    {'label': 'Humidity', 'icon': Icons.water_drop, 'color': Colors.cyan},
    {
      'label': 'Light Intensity',
      'icon': Icons.wb_sunny,
      'color': Colors.yellow
    },
    {'label': 'Wind Speed', 'icon': Icons.air, 'color': Colors.teal},
    {'label': 'Wind Direction', 'icon': Icons.explore, 'color': Colors.green},
    {'label': 'Rainfall', 'icon': Icons.grain, 'color': Colors.indigo},
    {
      'label': 'Sunshine Hours',
      'icon': Icons.wb_sunny_outlined,
      'color': Colors.amber
    },
    {'label': 'PAR', 'icon': Icons.lightbulb_outline, 'color': Colors.lime},
    {
      'label': 'UV Radiation',
      'icon': Icons.brightness_high,
      'color': Colors.deepPurple
    },
    {
      'label': 'Solar Radiation',
      'icon': Icons.solar_power,
      'color': Colors.deepOrange
    },
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 160;
      final titleFontSize = isSmall ? 12.0 : 14.0;
      final iconSize = isSmall ? 20.0 : 26.0;
      final badgeFontSize = isSmall ? 9.0 : 11.0;

      return Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: strong.withOpacity(0.08), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmall ? 8 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: isSmall ? 36 : 44,
                    height: isSmall ? 36 : 44,
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
                    ),
                    child: Icon(Icons.analytics_outlined,
                        color: Colors.purple, size: iconSize),
                  ),
                  SizedBox(width: isSmall ? 8 : 12),
                  Expanded(
                    child: Text(
                      'Parameters',
                      style: TextStyle(
                        color: strong,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: isSmall ? 4 : 8),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: isSmall ? 6 : 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_parameters.length}',
                      style: TextStyle(
                        color: Colors.purple,
                        fontSize: badgeFontSize,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 8 : 12),
              SizedBox(
                height: isSmall ? 60 : 80,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: isSmall ? 4 : 8,
                    runSpacing: isSmall ? 4 : 8,
                    children: _parameters.map((param) {
                      final color = param['color'] as Color;
                      return Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 6 : 10,
                            vertical: isSmall ? 4 : 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withOpacity(0.2), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(param['icon'] as IconData,
                                color: color, size: isSmall ? 10 : 14),
                            SizedBox(width: isSmall ? 3 : 5),
                            Text(
                              param['label'] as String,
                              style: TextStyle(
                                color: strong,
                                fontSize: isSmall ? 8 : 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconBg;
  final Color cardColor;
  final Color strong;
  final Color subtle;
  final VoidCallback? onTap;
  final bool isSelected; // ← NEW: highlight when brand is active

  const _StatCard({
    Key? key,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.cardColor,
    required this.strong,
    required this.subtle,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? iconBg.withOpacity(0.12) : cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? iconBg : strong.withOpacity(0.08),
              width: isSelected ? 2 : 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isSelected ? 0.08 : 0.04),
              blurRadius: isSelected ? 12 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Container(height: 3, width: double.infinity, color: iconBg),
              Expanded(
                child: LayoutBuilder(builder: (context, cardConstraints) {
                  final isSmallCard = cardConstraints.maxWidth < 160;
                  return Padding(
                    padding: EdgeInsets.all(isSmallCard ? 8 : 14),
                    child: Row(
                      children: [
                        Container(
                          width: isSmallCard ? 30 : 48,
                          height: isSmallCard ? 30 : 48,
                          decoration: BoxDecoration(
                            color: iconBg.withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(isSmallCard ? 8 : 14),
                          ),
                          child: Icon(icon,
                              color: iconBg, size: isSmallCard ? 16 : 28),
                        ),
                        SizedBox(width: isSmallCard ? 6 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  value.isNotEmpty ? value : "N/A",
                                  style: TextStyle(
                                    color: strong,
                                    fontSize: isSmallCard ? 14 : 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                title.isNotEmpty ? title : "Unknown",
                                style: TextStyle(
                                  color: subtle,
                                  fontSize: isSmallCard ? 9 : 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.visible,
                                maxLines: 2,
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color cardColor;
  final Color strong;
  final Color subtle;
  const _SectionCard({
    Key? key,
    required this.title,
    required this.child,
    required this.cardColor,
    required this.strong,
    required this.subtle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: strong.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: strong,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final String hint;
  final void Function(String) onChanged;
  final Color strong;
  final Color subtle;
  final bool isDark;
  const _SearchField({
    required this.hint,
    required this.onChanged,
    required this.strong,
    required this.subtle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: TextStyle(color: strong, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(Icons.search, color: subtle, size: 20),
        hintText: hint,
        hintStyle: TextStyle(color: subtle, fontSize: 14),
        filled: true,
        fillColor:
            (isDark ? const Color(0xFF1D2B38) : Colors.black.withOpacity(0.03)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: strong.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: strong.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: const Color(0xFF1976D2), width: 1.5),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.35), blurRadius: 8, spreadRadius: 1)
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendDot({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
