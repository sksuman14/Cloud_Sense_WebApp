import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// ==========================================
// DATA MODELS
// ==========================================

class DeviceSpecification {
  final String deviceId;
  final String deviceIdTopic;
  final String partnershipName;
  final String atrhSensor;
  final String rainSensor;
  final String ultrasonicBaudrate;
  final String simProvider;
  final String lastSyncedAt;

  DeviceSpecification({
    required this.deviceId,
    required this.deviceIdTopic,
    required this.partnershipName,
    required this.atrhSensor,
    required this.rainSensor,
    required this.ultrasonicBaudrate,
    required this.simProvider,
    required this.lastSyncedAt,
  });

  factory DeviceSpecification.fromJson(Map<String, dynamic> json) {
    return DeviceSpecification(
      deviceId: json['deviceId']?.toString() ?? '',
      deviceIdTopic: json['deviceid#topic']?.toString() ?? '',
      partnershipName: json['partnershipName']?.toString() ?? '',
      atrhSensor: json['atrhSensor']?.toString() ?? '',
      rainSensor: json['rainSensor']?.toString() ?? '',
      ultrasonicBaudrate: json['ultrasonicBaudrate']?.toString() ?? '',
      simProvider: json['simProvider']?.toString() ?? '',
      lastSyncedAt: json['lastSyncedAt']?.toString() ?? '',
    );
  }
}

class DeviceMetadata {
  final String deviceIdTopic;
  final dynamic elevationM;
  final String climateZone;
  final String landCover;
  final dynamic distToCoastKm;
  final dynamic distToRiverKm;
  final dynamic distToLakeKm;
  final dynamic slopeDeg;
  final dynamic aspectDeg;
  final String lat;
  final String lon;

  DeviceMetadata({
    required this.deviceIdTopic,
    required this.elevationM,
    required this.climateZone,
    required this.landCover,
    required this.distToCoastKm,
    required this.distToRiverKm,
    required this.distToLakeKm,
    required this.slopeDeg,
    required this.aspectDeg,
    required this.lat,
    required this.lon,
  });

  factory DeviceMetadata.fromJson(Map<String, dynamic> json) {
    return DeviceMetadata(
      deviceIdTopic: json['deviceId_topic']?.toString() ?? '',
      elevationM: json['Elevation (m)'],
      climateZone: json['Climate_Zone']?.toString() ?? '',
      landCover: json['Land_Cover']?.toString() ?? '',
      distToCoastKm: json['Dist_to_Coast (km)'],
      distToRiverKm: json['Dist_to_River (km)'],
      distToLakeKm: json['Dist_to_Lake (km)'],
      slopeDeg: json['Slope (deg)'],
      aspectDeg: json['Aspect (deg)'],
      lat: json['lat']?.toString() ?? '',
      lon: json['lon']?.toString() ?? '',
    );
  }
}

// ==========================================
// SERVICE WITH IN-MEMORY CACHING
// ==========================================

class DeviceSpecMetaService {
  static const String specApiUrl =
      'https://unmmxp97zb.execute-api.us-east-1.amazonaws.com/default/WS_Device_Specification_API';
  static const String metadataApiUrl =
      'https://fi7pafq7hc.execute-api.us-east-1.amazonaws.com/default/WS_Metadata_API';

  static List<DeviceSpecification>? _cachedSpecs;
  static DateTime? _specsTimestamp;

  static List<DeviceMetadata>? _cachedMetadata;
  static DateTime? _metadataTimestamp;

  /// Fetch all specifications (cached for 10 minutes)
  static Future<List<DeviceSpecification>> fetchSpecifications({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedSpecs != null &&
        _specsTimestamp != null &&
        DateTime.now().difference(_specsTimestamp!).inMinutes < 10) {
      return _cachedSpecs!;
    }

    final response = await http.get(Uri.parse(specApiUrl));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List list = decoded['specifications'] ?? [];
      _cachedSpecs = list.map((e) => DeviceSpecification.fromJson(e)).toList();
      _specsTimestamp = DateTime.now();
      return _cachedSpecs!;
    } else {
      throw Exception('Failed to load specifications (${response.statusCode})');
    }
  }

  /// Fetch all metadata (cached for 10 minutes)
  static Future<List<DeviceMetadata>> fetchMetadata({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedMetadata != null &&
        _metadataTimestamp != null &&
        DateTime.now().difference(_metadataTimestamp!).inMinutes < 10) {
      return _cachedMetadata!;
    }

    final response = await http.get(Uri.parse(metadataApiUrl));
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final List list = decoded['data'] ?? [];
      _cachedMetadata = list.map((e) => DeviceMetadata.fromJson(e)).toList();
      _metadataTimestamp = DateTime.now();
      return _cachedMetadata!;
    } else {
      throw Exception('Failed to load metadata (${response.statusCode})');
    }
  }

  /// Helper to normalize topics: removes leading/trailing hashes, spaces, and resolves sub-topic
  static String _normalizeTopic(String t) {
    var clean = t.trim();
    if (clean.contains('#')) {
      clean = clean.split('#').last.trim();
    }
    while (clean.startsWith('/')) clean = clean.substring(1);
    while (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    return clean.toLowerCase();
  }

  /// Helper to clean device identifier
  static String _cleanId(String id) {
    var c = id.trim();
    if (c.contains('#')) {
      c = c.split('#').first.trim();
    }
    return c.toLowerCase();
  }

  /// Match device in specifications
  static DeviceSpecification? findSpecification(
    List<DeviceSpecification> list, {
    required String deviceId,
    required String topic,
    String? sensorName,
    String? displayName,
  }) {
    final cleanT = _normalizeTopic(topic);
    final cleanDevId = _cleanId(deviceId);
    final cleanSn = sensorName != null ? _cleanId(sensorName) : cleanDevId;
    final cleanDn = displayName != null ? _cleanId(displayName) : cleanDevId;

    // 1. Direct match on topic in deviceid#topic
    for (final item in list) {
      final itemTopic = _normalizeTopic(item.deviceIdTopic);
      if (cleanT.isNotEmpty && itemTopic.isNotEmpty && itemTopic == cleanT) {
        return item;
      }
    }

    // 2. Direct match on deviceid#topic
    final targetCombined = '$cleanDevId#$cleanT';
    for (final item in list) {
      if (item.deviceIdTopic.toLowerCase().trim() == targetCombined) {
        return item;
      }
    }

    // 3. Match on deviceId
    for (final item in list) {
      final id = item.deviceId.toLowerCase().trim();
      if (id.isNotEmpty && (id == cleanDevId || id == cleanSn || id == cleanDn)) {
        return item;
      }
    }

    // 4. Match numeric suffix if topic ends with number
    final numMatch = RegExp(r'\d+$').firstMatch(cleanT)?.group(0);
    if (numMatch != null && numMatch.isNotEmpty) {
      for (final item in list) {
        final itemTopic = _normalizeTopic(item.deviceIdTopic);
        final itemNum = RegExp(r'\d+$').firstMatch(itemTopic)?.group(0);
        if (itemNum == numMatch) {
          // Check prefix similarity
          if (cleanT.contains('kerala') && itemTopic.contains('kerala')) return item;
          if (cleanT.contains('annam') && itemTopic.contains('annam')) return item;
          if (cleanT.contains('ssmet') && itemTopic.contains('ssmet')) return item;
          if (cleanT.contains('punjab') && itemTopic.contains('punjab')) return item;
        }
      }
    }

    return null;
  }

  /// Match device in metadata
  static DeviceMetadata? findMetadata(
    List<DeviceMetadata> list, {
    required String deviceId,
    required String topic,
    String? sensorName,
    String? displayName,
  }) {
    final cleanT = _normalizeTopic(topic);
    final cleanDevId = _cleanId(deviceId);
    final cleanSn = sensorName != null ? _cleanId(sensorName) : cleanDevId;
    final cleanDn = displayName != null ? _cleanId(displayName) : cleanDevId;

    // 1. Match by topic segment in deviceId_topic
    for (final item in list) {
      final itemTopic = _normalizeTopic(item.deviceIdTopic);
      if (cleanT.isNotEmpty && itemTopic.isNotEmpty && itemTopic == cleanT) {
        return item;
      }
    }

    // 2. Exact match on combined deviceId_topic
    final targetCombined = '$cleanDevId#$cleanT';
    for (final item in list) {
      if (item.deviceIdTopic.toLowerCase().trim() == targetCombined) {
        return item;
      }
    }

    // 3. Match on device ID prefix before #
    for (final item in list) {
      final id = _cleanId(item.deviceIdTopic);
      if (id.isNotEmpty && (id == cleanDevId || id == cleanSn || id == cleanDn)) {
        return item;
      }
    }

    // 4. Match numeric suffix with matching region
    final numMatch = RegExp(r'\d+$').firstMatch(cleanT)?.group(0);
    if (numMatch != null && numMatch.isNotEmpty) {
      for (final item in list) {
        final itemTopic = _normalizeTopic(item.deviceIdTopic);
        final itemNum = RegExp(r'\d+$').firstMatch(itemTopic)?.group(0);
        if (itemNum == numMatch) {
          if (cleanT.contains('kerala') && itemTopic.contains('kerala')) return item;
          if (cleanT.contains('annam') && itemTopic.contains('annam')) return item;
          if (cleanT.contains('ssmet') && itemTopic.contains('ssmet')) return item;
          if (cleanT.contains('punjab') && itemTopic.contains('punjab')) return item;
        }
      }
    }

    return null;
  }
}

// ==========================================
// SPECIFICATION DIALOG
// ==========================================

void showDeviceSpecificationDialog({
  required BuildContext context,
  required String deviceId,
  required String topic,
  String? sensorName,
  String? displayName,
  required bool isDark,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _DeviceSpecificationDialogWidget(
      deviceId: deviceId,
      topic: topic,
      sensorName: sensorName,
      displayName: displayName,
      isDark: isDark,
    ),
  );
}

class _DeviceSpecificationDialogWidget extends StatefulWidget {
  final String deviceId;
  final String topic;
  final String? sensorName;
  final String? displayName;
  final bool isDark;

  const _DeviceSpecificationDialogWidget({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.sensorName,
    this.displayName,
    required this.isDark,
  }) : super(key: key);

  @override
  State<_DeviceSpecificationDialogWidget> createState() =>
      _DeviceSpecificationDialogWidgetState();
}

class _DeviceSpecificationDialogWidgetState
    extends State<_DeviceSpecificationDialogWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DeviceSpecification> _allSpecs = [];
  DeviceSpecification? _selectedSpec;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final specs = await DeviceSpecMetaService.fetchSpecifications(
          forceRefresh: forceRefresh);
      final matched = DeviceSpecMetaService.findSpecification(
        specs,
        deviceId: widget.deviceId,
        topic: widget.topic,
        sensorName: widget.sensorName,
        displayName: widget.displayName,
      );

      if (mounted) {
        setState(() {
          _allSpecs = specs;
          _selectedSpec = matched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyAllDetails() {
    if (_selectedSpec == null) return;
    final spec = _selectedSpec!;
    final buffer = StringBuffer();
    buffer.writeln('=== Device Specification ===');
    buffer.writeln('Device ID: ${spec.deviceId}');
    buffer.writeln('Topic: ${spec.deviceIdTopic}');
    buffer.writeln('Partnership: ${spec.partnershipName}');
    buffer.writeln('AT/RH Sensor: ${spec.atrhSensor}');
    buffer.writeln('Rain Sensor: ${spec.rainSensor}');
    buffer.writeln('Ultrasonic Baudrate: ${spec.ultrasonicBaudrate}');
    buffer.writeln('SIM Provider: ${spec.simProvider}');
    buffer.writeln('Last Synced At: ${spec.lastSyncedAt}');
    _copyToClipboard(buffer.toString(), 'All Specifications');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW <= 650;
    final dialogW = isMobile ? screenW - 32 : 620.0;

    final primaryBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final strongText = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtleText = isDark ? Colors.white70 : const Color(0xFF64748B);

    final cleanTopic = widget.topic.contains('#')
        ? widget.topic.split('#').last
        : widget.topic;
    final effectiveName = widget.displayName ??
        widget.sensorName ??
        widget.deviceId;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        backgroundColor: primaryBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32, vertical: 24),
        child: Container(
          width: dialogW,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF1F5F9).withOpacity(0.5),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tune_rounded,
                          color: Colors.cyan, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Device Specification',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: strongText,
                                ),
                              ),
                             
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$effectiveName • $cleanTopic',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: subtleText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: subtleText, size: 20),
                      tooltip: 'Refresh',
                      onPressed: () => _loadData(forceRefresh: true),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subtleText, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // BODY
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.cyan),
                              SizedBox(height: 16),
                              Text('Fetching device specifications...'),
                            ],
                          ),
                        ),
                      )
                    : _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.redAccent, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Error loading specifications',
                                    style: TextStyle(
                                        color: strongText,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_errorMessage!,
                                      style: TextStyle(
                                          color: subtleText, fontSize: 12),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _loadData(forceRefresh: true),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedSpec == null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline,
                                            color: Colors.amber, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'No matching specification found for $cleanTopic ($widget.deviceId). You can search from all available records below.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.amber.shade200
                                                    : Colors.amber.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSearchBar(isDark, cardBg, borderColor,
                                      strongText, subtleText),
                                  const SizedBox(height: 12),
                                  _buildSpecPicker(isDark, cardBg, borderColor,
                                      strongText, subtleText),
                                ] else ...[
                                  // Selected device details
                                  _buildSpecCard(
                                    _selectedSpec!,
                                    isDark,
                                    cardBg,
                                    borderColor,
                                    strongText,
                                    subtleText,
                                    isMobile,
                                  ),
                                  const SizedBox(height: 16),

                                  // Search or switch device
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.swap_horiz,
                                          size: 18, color: Colors.cyan),
                                      title: Text(
                                        'View other devices (${_allSpecs.length} total)',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.cyanAccent
                                                : Colors.cyan.shade800),
                                      ),
                                      children: [
                                        _buildSearchBar(
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            strongText,
                                            subtleText),
                                        const SizedBox(height: 10),
                                        _buildSpecPicker(
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            strongText,
                                            subtleText),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),

              // FOOTER
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_selectedSpec != null)
                      TextButton.icon(
                        onPressed: _copyAllDetails,
                        icon: const Icon(Icons.copy_all, size: 16),
                        label: const Text('Copy All',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.cyanAccent : Colors.cyan.shade800,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecCard(
    DeviceSpecification spec,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color strongText,
    Color subtleText,
    bool isMobile,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.cyan.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.router, color: Colors.cyan, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Topic / Device Key',
                        style: TextStyle(fontSize: 10.5, color: subtleText)),
                    SelectableText(
                      spec.deviceIdTopic.isNotEmpty
                          ? spec.deviceIdTopic
                          : spec.deviceId,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.cyan,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 15, color: Colors.cyan),
                tooltip: 'Copy Topic',
                onPressed: () => _copyToClipboard(
                    spec.deviceIdTopic, 'Topic'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Grid of Specs
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final double itemW = isNarrow
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFieldCard(
                width: itemW,
                label: 'Device ID',
                value: spec.deviceId,
                icon: Icons.tag,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Partnership Name',
                value: spec.partnershipName,
                icon: Icons.handshake_outlined,
                badgeColor: Colors.blueAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'AT/RH Sensor Type',
                value: spec.atrhSensor,
                icon: Icons.thermostat,
                badgeColor: Colors.teal,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Rain Sensor Type',
                value: spec.rainSensor,
                icon: Icons.water_drop_outlined,
                badgeColor: Colors.indigoAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Ultrasonic Baudrate',
                value: spec.ultrasonicBaudrate,
                icon: Icons.speed,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'SIM Provider',
                value: spec.simProvider,
                icon: Icons.sim_card_outlined,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: constraints.maxWidth,
                label: 'Last Synced At',
                value: spec.lastSyncedAt,
                icon: Icons.sync,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildFieldCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    Color? badgeColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color strongText,
    required Color subtleText,
  }) {
    final displayValue = value.trim().isEmpty ? 'N/A' : value.trim();

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: badgeColor ?? Colors.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: subtleText)),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: strongText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (displayValue != 'N/A')
            InkWell(
              onTap: () => _copyToClipboard(displayValue, label),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.copy, size: 14, color: subtleText.withOpacity(0.6)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardBg, Color borderColor,
      Color strongText, Color subtleText) {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 12.5, color: strongText),
      decoration: InputDecoration(
        hintText: 'Search by Device ID, Topic or Partnership...',
        hintStyle: TextStyle(fontSize: 12, color: subtleText),
        prefixIcon: Icon(Icons.search, size: 18, color: subtleText),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
    );
  }

  Widget _buildSpecPicker(bool isDark, Color cardBg, Color borderColor,
      Color strongText, Color subtleText) {
    final filtered = _allSpecs.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.deviceId.toLowerCase().contains(_searchQuery) ||
          s.deviceIdTopic.toLowerCase().contains(_searchQuery) ||
          s.partnershipName.toLowerCase().contains(_searchQuery);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: filtered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No devices match "$_searchQuery"',
                    style: TextStyle(fontSize: 12, color: subtleText)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                final isCurrent = _selectedSpec == item;
                return ListTile(
                  dense: true,
                  title: Text(
                    item.deviceIdTopic.isNotEmpty
                        ? item.deviceIdTopic
                        : item.deviceId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? Colors.cyan : strongText,
                    ),
                  ),
                  subtitle: Text(
                    'Partner: ${item.partnershipName.isEmpty ? 'N/A' : item.partnershipName} • Sensor: ${item.atrhSensor}',
                    style: TextStyle(fontSize: 10.5, color: subtleText),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, size: 16, color: Colors.cyan)
                      : const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    setState(() => _selectedSpec = item);
                  },
                );
              },
            ),
    );
  }
}

// ==========================================
// METADATA DIALOG
// ==========================================

void showDeviceMetadataDialog({
  required BuildContext context,
  required String deviceId,
  required String topic,
  String? sensorName,
  String? displayName,
  required bool isDark,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _DeviceMetadataDialogWidget(
      deviceId: deviceId,
      topic: topic,
      sensorName: sensorName,
      displayName: displayName,
      isDark: isDark,
    ),
  );
}

class _DeviceMetadataDialogWidget extends StatefulWidget {
  final String deviceId;
  final String topic;
  final String? sensorName;
  final String? displayName;
  final bool isDark;

  const _DeviceMetadataDialogWidget({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.sensorName,
    this.displayName,
    required this.isDark,
  }) : super(key: key);

  @override
  State<_DeviceMetadataDialogWidget> createState() =>
      _DeviceMetadataDialogWidgetState();
}

class _DeviceMetadataDialogWidgetState
    extends State<_DeviceMetadataDialogWidget> {
  bool _isLoading = true;
  String? _errorMessage;
  List<DeviceMetadata> _allMetadata = [];
  DeviceMetadata? _selectedMetadata;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final metaList = await DeviceSpecMetaService.fetchMetadata(
          forceRefresh: forceRefresh);
      final matched = DeviceSpecMetaService.findMetadata(
        metaList,
        deviceId: widget.deviceId,
        topic: widget.topic,
        sensorName: widget.sensorName,
        displayName: widget.displayName,
      );

      if (mounted) {
        setState(() {
          _allMetadata = metaList;
          _selectedMetadata = matched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openGoogleMaps(String lat, String lon) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lon');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _copyToClipboard('$lat, $lon', 'Coordinates');
    }
  }

  void _copyAllMetadata() {
    if (_selectedMetadata == null) return;
    final m = _selectedMetadata!;
    final buffer = StringBuffer();
    buffer.writeln('=== Device Metadata ===');
    buffer.writeln('Device Topic: ${m.deviceIdTopic}');
    buffer.writeln('Elevation: ${m.elevationM ?? 'N/A'} m');
    buffer.writeln('Climate Zone: ${m.climateZone}');
    buffer.writeln('Land Cover: ${m.landCover}');
    buffer.writeln('Dist to Coast: ${m.distToCoastKm ?? 'N/A'} km');
    buffer.writeln('Dist to River: ${m.distToRiverKm ?? 'N/A'} km');
    buffer.writeln('Dist to Lake: ${m.distToLakeKm ?? 'N/A'} km');
    buffer.writeln('Slope: ${m.slopeDeg ?? 'N/A'}°');
    buffer.writeln('Aspect: ${m.aspectDeg ?? 'N/A'}°');
    buffer.writeln('Coordinates: ${m.lat}, ${m.lon}');
    _copyToClipboard(buffer.toString(), 'All Metadata');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW <= 650;
    final dialogW = isMobile ? screenW - 32 : 620.0;

    final primaryBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final strongText = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtleText = isDark ? Colors.white70 : const Color(0xFF64748B);

    final cleanTopic = widget.topic.contains('#')
        ? widget.topic.split('#').last
        : widget.topic;
    final effectiveName = widget.displayName ??
        widget.sensorName ??
        widget.deviceId;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        backgroundColor: primaryBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 32, vertical: 24),
        child: Container(
          width: dialogW,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF1F5F9).withOpacity(0.5),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.travel_explore_rounded,
                          color: Colors.amber, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sensor Metadata',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: strongText,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Geospatial Data',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amberAccent : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$effectiveName • $cleanTopic',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: subtleText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh, color: subtleText, size: 20),
                      tooltip: 'Refresh',
                      onPressed: () => _loadData(forceRefresh: true),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subtleText, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // BODY
              Flexible(
                child: _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(color: Colors.amber),
                              SizedBox(height: 16),
                              Text('Fetching sensor metadata...'),
                            ],
                          ),
                        ),
                      )
                    : _errorMessage != null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.error_outline,
                                      color: Colors.redAccent, size: 40),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Error loading metadata',
                                    style: TextStyle(
                                        color: strongText,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(_errorMessage!,
                                      style: TextStyle(
                                          color: subtleText, fontSize: 12),
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () => _loadData(forceRefresh: true),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_selectedMetadata == null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.amber.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.info_outline,
                                            color: Colors.amber, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'No matching metadata found for $cleanTopic ($widget.deviceId). You can search from all available sensor records below.',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? Colors.amber.shade200
                                                    : Colors.amber.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSearchBar(isDark, cardBg, borderColor,
                                      strongText, subtleText),
                                  const SizedBox(height: 12),
                                  _buildMetaPicker(isDark, cardBg, borderColor,
                                      strongText, subtleText),
                                ] else ...[
                                  // Selected device details
                                  _buildMetadataCard(
                                    _selectedMetadata!,
                                    isDark,
                                    cardBg,
                                    borderColor,
                                    strongText,
                                    subtleText,
                                    isMobile,
                                  ),
                                  const SizedBox(height: 16),

                                  // Search or switch sensor
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      tilePadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.swap_horiz,
                                          size: 18, color: Colors.amber),
                                      title: Text(
                                        'View other sensors (${_allMetadata.length} total)',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.amberAccent
                                                : Colors.amber.shade800),
                                      ),
                                      children: [
                                        _buildSearchBar(
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            strongText,
                                            subtleText),
                                        const SizedBox(height: 10),
                                        _buildMetaPicker(
                                            isDark,
                                            cardBg,
                                            borderColor,
                                            strongText,
                                            subtleText),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
              ),

              // FOOTER
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_selectedMetadata != null)
                      TextButton.icon(
                        onPressed: _copyAllMetadata,
                        icon: const Icon(Icons.copy_all, size: 16),
                        label: const Text('Copy All',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.amberAccent : Colors.amber.shade900,
                        ),
                      )
                    else
                      const SizedBox.shrink(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.shade800,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetadataCard(
    DeviceMetadata m,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color strongText,
    Color subtleText,
    bool isMobile,
  ) {
    final hasCoords = m.lat.isNotEmpty && m.lon.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Topic Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, color: Colors.amber, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Device Topic Identifier',
                        style: TextStyle(fontSize: 10.5, color: subtleText)),
                    SelectableText(
                      m.deviceIdTopic,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 15, color: Colors.amber),
                tooltip: 'Copy Topic',
                onPressed: () => _copyToClipboard(
                    m.deviceIdTopic, 'Device Topic'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Grid of Metadata
        LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 500;
          final double itemW = isNarrow
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildFieldCard(
                width: itemW,
                label: 'Elevation',
                value: m.elevationM != null ? '${m.elevationM} m' : 'N/A',
                icon: Icons.landscape_outlined,
                badgeColor: Colors.deepOrangeAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Climate Zone',
                value: m.climateZone,
                icon: Icons.wb_sunny_outlined,
                badgeColor: Colors.orange,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Land Cover',
                value: m.landCover,
                icon: Icons.grass_outlined,
                badgeColor: Colors.green,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Distance to Coast',
                value: m.distToCoastKm != null ? '${m.distToCoastKm} km' : 'N/A',
                icon: Icons.waves_outlined,
                badgeColor: Colors.blue,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Distance to River',
                value: m.distToRiverKm != null ? '${m.distToRiverKm} km' : 'N/A',
                icon: Icons.water,
                badgeColor: Colors.lightBlue,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Distance to Lake',
                value: m.distToLakeKm != null ? '${m.distToLakeKm} km' : 'N/A',
                icon: Icons.pool_outlined,
                badgeColor: Colors.teal,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Slope',
                value: m.slopeDeg != null ? '${m.slopeDeg}°' : 'N/A',
                icon: Icons.show_chart,
                badgeColor: Colors.purpleAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Aspect',
                value: m.aspectDeg != null ? '${m.aspectDeg}°' : 'N/A',
                icon: Icons.explore_outlined,
                badgeColor: Colors.indigoAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
              ),
              // Coordinates Card with Map button
              Container(
                width: constraints.maxWidth,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: Colors.redAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Coordinates (Lat / Lon)',
                              style: TextStyle(fontSize: 10.5, color: subtleText)),
                          const SizedBox(height: 2),
                          SelectableText(
                            hasCoords ? '${m.lat}, ${m.lon}' : 'Not available',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: strongText,
                              fontFamily: hasCoords ? 'monospace' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasCoords) ...[
                      OutlinedButton.icon(
                        onPressed: () => _openGoogleMaps(m.lat, m.lon),
                        icon: const Icon(Icons.map, size: 14),
                        label: const Text('View Map', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.amberAccent : Colors.amber.shade900,
                          side: BorderSide(
                              color: isDark ? Colors.amberAccent : Colors.amber.shade900),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.copy, size: 15, color: subtleText),
                        tooltip: 'Copy Coordinates',
                        onPressed: () => _copyToClipboard(
                            '${m.lat}, ${m.lon}', 'Coordinates'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildFieldCard({
    required double width,
    required String label,
    required String value,
    required IconData icon,
    Color? badgeColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color strongText,
    required Color subtleText,
  }) {
    final displayValue = value.trim().isEmpty ? 'N/A' : value.trim();

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: badgeColor ?? Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: subtleText)),
                const SizedBox(height: 2),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: strongText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (displayValue != 'N/A')
            InkWell(
              onTap: () => _copyToClipboard(displayValue, label),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Icon(Icons.copy, size: 14, color: subtleText.withOpacity(0.6)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardBg, Color borderColor,
      Color strongText, Color subtleText) {
    return TextField(
      controller: _searchController,
      style: TextStyle(fontSize: 12.5, color: strongText),
      decoration: InputDecoration(
        hintText: 'Search by Device ID, Topic or Region...',
        hintStyle: TextStyle(fontSize: 12, color: subtleText),
        prefixIcon: Icon(Icons.search, size: 18, color: subtleText),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
    );
  }

  Widget _buildMetaPicker(bool isDark, Color cardBg, Color borderColor,
      Color strongText, Color subtleText) {
    final filtered = _allMetadata.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.deviceIdTopic.toLowerCase().contains(_searchQuery) ||
          m.climateZone.toLowerCase().contains(_searchQuery) ||
          m.landCover.toLowerCase().contains(_searchQuery);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: filtered.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('No sensors match "$_searchQuery"',
                    style: TextStyle(fontSize: 12, color: subtleText)),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
              itemBuilder: (context, idx) {
                final item = filtered[idx];
                final isCurrent = _selectedMetadata == item;
                return ListTile(
                  dense: true,
                  title: Text(
                    item.deviceIdTopic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? Colors.amber : strongText,
                    ),
                  ),
                  subtitle: Text(
                    'Climate: ${item.climateZone} • Elev: ${item.elevationM ?? 'N/A'}m • Land: ${item.landCover}',
                    style: TextStyle(fontSize: 10.5, color: subtleText),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, size: 16, color: Colors.amber)
                      : const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    setState(() => _selectedMetadata = item);
                  },
                );
              },
            ),
    );
  }
}
