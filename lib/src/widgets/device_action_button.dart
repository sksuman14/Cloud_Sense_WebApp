import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/admin/device_health_status.dart';
import 'package:cloud_sense_webapp/src/views/devices/AdvancedDataSendDialog.dart';
import 'package:cloud_sense_webapp/src/widgets/device_spec_meta_dialogs.dart';

const Map<String, String> defaultParameterDisplayNames = {
  'temperature': 'Temperature',
  'humidity': 'Humidity',
  'pressure': 'Pressure',
  'wind_speed': 'Wind Speed',
  'wind_direction': 'Wind Direction',
  'rain': 'Rain',
  'rainfall': 'Rainfall',
  'light_intensity': 'Light Intensity',
  'soil_moisture': 'Soil Moisture',
  'soil_temperature': 'Soil Temperature',
  'battery_voltage': 'Battery Voltage',
  'solar_voltage': 'Solar Voltage',
  'co2': 'CO2',
  'tvoc': 'TVOC',
  'pm2_5': 'PM 2.5',
  'pm10': 'PM 10',
};

/// Displays the standardized Parameters Dialog with blurred backdrop,
/// topic chip, data interval (if available), and numbered parameters.
void showDeviceParametersDialog({
  required BuildContext context,
  required bool isDark,
  required String? updateInterval,
  required List<String> displayParamNames,
  Map<String, String>? parameterDisplayNames,
  String? topic,
  String? deviceName,
}) {
  final cleanTopic = (topic != null && topic.isNotEmpty && topic != "Unknown")
      ? (topic.contains('#') ? topic.split('#').last : topic)
      : null;
  final paramMap = parameterDisplayNames ?? defaultParameterDisplayNames;

  double getResponsiveFontSize(BuildContext ctx, double mobile, double desktop) {
    return MediaQuery.of(ctx).size.width <= 600 ? mobile : desktop;
  }

  showDialog(
    context: context,
    builder: (context) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Parameters",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (cleanTopic != null && cleanTopic.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withOpacity(0.35)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alt_route,
                        size: 15,
                        color: isDark
                            ? const Color(0xFF38BDF8)
                            : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Topic: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Expanded(
                        child: SelectableText(
                          cleanTopic,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: isDark
                                ? const Color(0xFF38BDF8)
                                : const Color(0xFF0369A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
                              paramMap[param] ?? param;
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

/// A unified device action button (PopupMenuButton) that works seamlessly
/// across both Admin Page and User Device List views.
class DeviceActionButton extends StatelessWidget {
  final String deviceId;
  final String topic;
  final String? sensorName;
  final String? displaySensorName;
  final String? sequentialName;
  final String? updateInterval;
  final List<String> displayParamNames;
  final Map<String, String>? parameterDisplayNames;
  final String? userEmail;
  final bool isAdmin;
  final bool isDark;
  final bool hideSensitiveSections;
  final VoidCallback? onDeleteSuccess;
  final void Function(String sensorName, String? updateInterval)? onNavigateToOTA;
  final Map<String, String>? healthTopicLookupMap;
  final Widget? child;
  final double? iconSize;
  final Color? iconColor;

  const DeviceActionButton({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.sensorName,
    this.displaySensorName,
    this.sequentialName,
    this.updateInterval,
    this.displayParamNames = const [],
    this.parameterDisplayNames,
    this.userEmail,
    this.isAdmin = false,
    this.isDark = true,
    this.hideSensitiveSections = false,
    this.onDeleteSuccess,
    this.onNavigateToOTA,
    this.healthTopicLookupMap,
    this.child,
    this.iconSize,
    this.iconColor,
  }) : super(key: key);

  String get _resolvedSensorName {
    if (sensorName != null && sensorName!.isNotEmpty) return sensorName!;
    return DevicePrefixUtils.resolveSensorName(deviceId, topic);
  }

  String get _resolvedDisplayName {
    if (displaySensorName != null && displaySensorName!.isNotEmpty) {
      return displaySensorName!;
    }
    return DevicePrefixUtils.toAnnamDisplayName(_resolvedSensorName);
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      tooltip: 'Actions',
      child: child ??
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Icon(
              Icons.more_vert,
              size: iconSize ?? 18,
              color: iconColor ?? (isDark ? Colors.white54 : Colors.black54),
            ),
          ),
      onSelected: (String value) {
        final sn = _resolvedSensorName;
        final dn = _resolvedDisplayName;
        final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);

        switch (value) {
          case 'graph':
            if (sn.startsWith('BF')) {
              String numericNodeId = sn.replaceAll(RegExp(r'\D'), '');
              NavigationUtils.navigateTo(
                context,
                '/buffalodata',
                arguments: {
                  'startDateTime': DateTime.now(),
                  'endDateTime': DateTime.now().add(const Duration(days: 1)),
                  'nodeId': numericNodeId,
                },
              );
            } else if (sn.startsWith('CS')) {
              String numericNodeId = sn.replaceAll(RegExp(r'\D'), '');
              NavigationUtils.navigateTo(
                context,
                '/cowdata',
                arguments: {
                  'startDateTime': DateTime.now(),
                  'endDateTime': DateTime.now().add(const Duration(days: 1)),
                  'nodeId': numericNodeId,
                },
              );
            } else {
              final category = sequentialName ?? mapped.category;
              NavigationUtils.navigateTo(
                context,
                isAdmin ? '/admin/devicegraph' : '/devicegraph',
                arguments: {
                  'deviceName': sn,
                  'sequentialName': category,
                  'backgroundImagePath': 'assets/backgroundd.jpg',
                },
              );
            }
            break;

          case 'ota':
            final isAnnamCp01 = sn == 'ANNAM_CP01' ||
                sn == 'CP001' ||
                dn == 'ANNAM_CP01' ||
                sn.toUpperCase().contains('ANNAM_CP01') ||
                sn.toUpperCase().contains('CP01');

            if (mapped.category == 'SSMet Soil sensor' && onNavigateToOTA != null) {
              onNavigateToOTA!(sn, updateInterval);
            } else {
              final prefix = mapped.prefix.isNotEmpty ? mapped.prefix : 'WJ';
              final apiUrl = DevicePrefixUtils.getOtaApiUrl(prefix, sensorName: sn) ??
                  (isAnnamCp01
                      ? 'https://ae0i1o0fo4.execute-api.us-east-1.amazonaws.com/annamcpdata'
                      : 'https://2jajsh64sd.execute-api.us-east-1.amazonaws.com/default/Data_Fetch_SSMet0126');
              AdvancedDataSendDialog.show(
                context,
                sn,
                displayDeviceId: dn,
                apiUrl: apiUrl,
              );
            }
            break;

          case 'parameters':
            final effectiveTopic = (topic.isNotEmpty && topic != "Unknown")
                ? (topic.contains('#') ? topic.split('#').last : topic)
                : DevicePrefixUtils.buildTopicFromSensorName(sn).split('#').last;
            showDeviceParametersDialog(
              context: context,
              isDark: isDark,
              updateInterval: updateInterval,
              displayParamNames: displayParamNames,
              parameterDisplayNames: parameterDisplayNames,
              topic: effectiveTopic,
              deviceName: dn,
            );
            break;

          case 'health':
            String? resolvedTopic;
            if (healthTopicLookupMap != null) {
              final devIdDigits = RegExp(r'\d+$').firstMatch(sn)?.group(0) ?? '';
              resolvedTopic = healthTopicLookupMap![sn] ??
                  healthTopicLookupMap![dn] ??
                  (devIdDigits.isNotEmpty ? healthTopicLookupMap![devIdDigits] : null);

              if (resolvedTopic == null &&
                  (sn.toUpperCase().startsWith('SH') ||
                   sn.toUpperCase().contains('SHOBHA') ||
                   sn.toUpperCase().contains('SOBHA'))) {
                final digits = int.tryParse(devIdDigits)?.toString() ?? '1';
                resolvedTopic = "WS_Shobha_$digits#WS/Shobha/$digits";
              } else if (resolvedTopic == null && topic.contains('#')) {
                final parts = topic.split('#');
                if (parts.length > 1) {
                  resolvedTopic = "$sn#${parts.sublist(1).join('#')}";
                }
              }
            }

            final deviceIdTopic = resolvedTopic ??
                (topic.contains('#')
                    ? topic
                    : (topic.isNotEmpty ? "$deviceId#$topic" : "$sn#"));

            showDeviceHealthDetailDialog(
              context,
              deviceIdTopic,
              isDark,
            );
            break;

          case 'specification':
            showDeviceSpecificationDialog(
              context: context,
              deviceId: deviceId,
              topic: topic,
              sensorName: sn,
              displayName: dn,
              isDark: isDark,
            );
            break;

          case 'metadata':
            showDeviceMetadataDialog(
              context: context,
              deviceId: deviceId,
              topic: topic,
              sensorName: sn,
              displayName: dn,
              isDark: isDark,
            );
            break;

          case 'quality':
            NavigationUtils.navigateTo(
              context,
              '/admin/health/quality-diagnostics',
              arguments: {
                'deviceId': deviceId,
                'deviceIdTopic': "$deviceId#$topic",
                'displayName': (topic.isNotEmpty && topic != "Unknown")
                    ? "$dn ($topic)"
                    : dn,
                'isDark': isDark,
                'fromAdminPage': true,
              },
            );
            break;

          case 'delete':
            final providerEmail = Provider.of<UserProvider>(context, listen: false).userEmail ?? '';
            final currentEmail = (userEmail ?? providerEmail).trim();
            DeleteDeviceUtils.deleteSingleDevice(
              context: context,
              userEmail: currentEmail,
              deviceId: sn,
              displayDeviceId: dn,
              adminEmail: isAdmin ? (providerEmail.isNotEmpty ? providerEmail : 'admin') : null,
              onSuccess: () {
                onDeleteSuccess?.call();
              },
            );
            break;
        }
      },
      itemBuilder: (BuildContext context) {
        final providerEmail = Provider.of<UserProvider>(context, listen: false).userEmail ?? "";
        final currentEmail = (userEmail ?? providerEmail).trim().toLowerCase();
        final bool isSkusuman = currentEmail.contains('sksuman');
        final allowedEmails = [
          'dev@navariti.com',
          'hello@navariti.com',
          'dejy91971@gmail.com',
          'krishnanpallavi63@gmail.com',
        ];
        final bool isOtaAllowedUser = isSkusuman ||
            allowedEmails.any((e) => currentEmail.contains(e.toLowerCase())) ||
            DeviceUtils.isSuperAdmin(currentEmail);

        final mapped = DevicePrefixUtils.mapCategoryAndPrefix(topic);
        final sn = _resolvedSensorName;
        final dn = _resolvedDisplayName;
        final bool isAnnamCp01 = sn == 'ANNAM_CP01' ||
            sn == 'CP001' ||
            dn == 'ANNAM_CP01' ||
            sn.toUpperCase().contains('ANNAM_CP01') ||
            sn.toUpperCase().contains('CP01');
        final bool hasOtaSupport = ['CP','CF','WF','WJ','WM','WN','IT','WA','WT','JW','KR','SH','AM','AW'].contains(mapped.prefix) ||
            mapped.category == 'SSMet Soil sensor' ||
            DevicePrefixUtils.getOtaApiUrl(mapped.prefix, sensorName: sn) != null ||
            isAnnamCp01;

        final bool showOtaOption = (isOtaAllowedUser || isAnnamCp01) && !hideSensitiveSections && hasOtaSupport;

        return <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'graph',
            child: Row(children: [
              Icon(Icons.bar_chart, color: Colors.blue, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Graph', style: TextStyle(fontSize: 13))),
            ]),
          ),
          if (showOtaOption)
            const PopupMenuItem<String>(
              value: 'ota',
              child: Row(children: [
                Icon(Icons.settings_remote, color: Colors.orangeAccent, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text('OTA Update', style: TextStyle(fontSize: 13))),
              ]),
            ),
          const PopupMenuItem<String>(
            value: 'parameters',
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.teal, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Parameters', style: TextStyle(fontSize: 13))),
            ]),
          ),
          const PopupMenuItem<String>(
            value: 'health',
            child: Row(children: [
              Icon(Icons.health_and_safety_outlined, color: Colors.green, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Health Status', style: TextStyle(fontSize: 13))),
            ]),
          ),
          const PopupMenuItem<String>(
            value: 'specification',
            child: Row(children: [
              Icon(Icons.tune_rounded, color: Colors.cyan, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Specification', style: TextStyle(fontSize: 13))),
            ]),
          ),
          const PopupMenuItem<String>(
            value: 'metadata',
            child: Row(children: [
              Icon(Icons.travel_explore_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 10),
              Expanded(child: Text('Metadata', style: TextStyle(fontSize: 13))),
            ]),
          ),
          if (isAdmin)
            const PopupMenuItem<String>(
              value: 'quality',
              child: Row(children: [
                Icon(Icons.science_outlined, color: Colors.purple, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Quality Diagnostics',
                    style: TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          if (onDeleteSuccess != null && !isAdmin) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(children: [
                Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Delete Device',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ];
      },
    );
  }
}
