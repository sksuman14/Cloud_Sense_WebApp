import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/services/device_image_service.dart';

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
  final String hardwareVersion;
  final String firmwareVersion;

  DeviceSpecification({
    required this.deviceId,
    required this.deviceIdTopic,
    required this.partnershipName,
    required this.atrhSensor,
    required this.rainSensor,
    required this.ultrasonicBaudrate,
    required this.simProvider,
    required this.lastSyncedAt,
    this.hardwareVersion = '',
    this.firmwareVersion = '',
  });

  factory DeviceSpecification.fromJson(Map<String, dynamic> json) {
    return DeviceSpecification(
      deviceId: (json['deviceid'] ?? json['deviceId'])?.toString() ?? '',
      deviceIdTopic: json['deviceid#topic']?.toString() ??
          json['deviceId_topic']?.toString() ??
          json['deviceIdTopic']?.toString() ??
          '',
      partnershipName: json['partnershipName']?.toString() ?? '',
      atrhSensor: json['atrhSensor']?.toString() ?? '',
      rainSensor: json['rainSensor']?.toString() ?? '',
      ultrasonicBaudrate: (json['ultrasonicBaudrate'] ??
              json['baudRate'] ??
              json['baudrate'])
          ?.toString() ??
          '',
      simProvider: json['simProvider']?.toString() ?? '',
      lastSyncedAt: json['lastSyncedAt']?.toString() ?? '',
      hardwareVersion: (json['hardwareVersion'] ??
              json['hardware_version'] ??
              json['hardware'])
          ?.toString() ??
          '',
      firmwareVersion: (json['firmwareVersion'] ??
              json['firmware_version'] ??
              json['firmware'])
          ?.toString() ??
          '',
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

  /// Invalidate specifications cache so fresh data is retrieved on next fetch
  static void invalidateSpecsCache() {
    _cachedSpecs = null;
    _specsTimestamp = null;
  }

  /// Create or update device specification via POST API
  static Future<Map<String, dynamic>> saveSpecification({
    required String deviceId,
    required String topic,
    String? deviceIdTopic,
    String? hardwareVersion,
    String? firmwareVersion,
    String? baudRate,
    String? partnershipName,
    String? simProvider,
    String? atrhSensor,
    String? rainSensor,
    String? lastSyncedAt,
  }) async {
    final cleanDevId = deviceId.trim().contains('#')
        ? deviceId.trim().split('#').first.trim()
        : deviceId.trim();
    var cleanT = topic.trim();
    if (cleanT.contains('#')) cleanT = cleanT.split('#').last.trim();
    while (cleanT.startsWith('/')) cleanT = cleanT.substring(1);
    while (cleanT.endsWith('/')) cleanT = cleanT.substring(0, cleanT.length - 1);

    if (cleanT.isEmpty) {
      if (deviceIdTopic != null && deviceIdTopic.contains('#')) {
        cleanT = deviceIdTopic.split('#').last.trim();
      } else if (deviceId.contains('#')) {
        cleanT = deviceId.split('#').last.trim();
      }
    }

    final compositeKey = (deviceIdTopic != null &&
            deviceIdTopic.trim().isNotEmpty &&
            deviceIdTopic.contains('#'))
        ? deviceIdTopic.trim()
        : '$cleanDevId#$cleanT';

    final now = DateTime.now();
    final syncTime =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final payload = <String, dynamic>{
      'deviceid#topic': compositeKey,
      'deviceid': cleanDevId,
      'topic': cleanT,
      'hardwareVersion': hardwareVersion?.trim() ?? '',
      'firmwareVersion': firmwareVersion?.trim() ?? '',
      'ultrasonicBaudrate': baudRate?.trim() ?? '',
      'partnershipName': partnershipName?.trim() ?? '',
      'simProvider': simProvider?.trim() ?? '',
      'atrhSensor': atrhSensor?.trim() ?? '',
      'rainSensor': rainSensor?.trim() ?? '',
      'lastSyncedAt': syncTime,
    };

    final response = await http.post(
      Uri.parse(specApiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(payload),
    );

    invalidateSpecsCache();

    if (response.statusCode == 200 || response.statusCode == 201) {
      try {
        return json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        return {'success': true, 'message': 'Device specification saved successfully'};
      }
    } else {
      String errorMessage = 'Failed with status ${response.statusCode}';
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map && decoded['error'] != null) {
          errorMessage = decoded['error'].toString();
        } else if (decoded is Map && decoded['message'] != null) {
          errorMessage = decoded['message'].toString();
        }
      } catch (_) {
        errorMessage = response.body;
      }
      throw Exception(errorMessage);
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

    // Flexible helper: matches 'aws_216' with 'aws-216', 'aws 216', or '216'
    bool looseMatch(String a, String b) {
      if (a.isEmpty || b.isEmpty) return false;
      if (a == b) return true;
      final normA = a.replaceAll('-', '_').replaceAll(' ', '_');
      final normB = b.replaceAll('-', '_').replaceAll(' ', '_');
      if (normA == normB) return true;
      final alphaA = a.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final alphaB = b.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      if (alphaA.isNotEmpty && alphaA == alphaB) return true;
      return false;
    }

    // 1. Direct match on topic in deviceid#topic
    for (final item in list) {
      final itemTopic = _normalizeTopic(item.deviceIdTopic);
      if (cleanT.isNotEmpty &&
          itemTopic.isNotEmpty &&
          (itemTopic == cleanT || looseMatch(itemTopic, cleanT))) {
        return item;
      }
    }

    // 2. Direct match on deviceid#topic
    final targetCombined = '$cleanDevId#$cleanT';
    for (final item in list) {
      final combined = item.deviceIdTopic.toLowerCase().trim();
      if (combined == targetCombined || looseMatch(combined, targetCombined)) {
        return item;
      }
    }

    // 3. Match on deviceId
    for (final item in list) {
      final id = item.deviceId.toLowerCase().trim();
      if (id.isNotEmpty &&
          (id == cleanDevId ||
              id == cleanSn ||
              id == cleanDn ||
              looseMatch(id, cleanDevId) ||
              looseMatch(id, cleanSn) ||
              looseMatch(id, cleanDn))) {
        return item;
      }
    }

    // 4. Match numeric suffix if topic or deviceId ends with number
    final numMatch = RegExp(r'\d+$').firstMatch(cleanT)?.group(0) ??
        RegExp(r'\d+$').firstMatch(cleanDevId)?.group(0);
    if (numMatch != null && numMatch.isNotEmpty) {
      for (final item in list) {
        final itemTopic = _normalizeTopic(item.deviceIdTopic);
        final itemDevId = item.deviceId.toLowerCase().trim();
        final itemNum = RegExp(r'\d+$').firstMatch(itemTopic)?.group(0) ??
            RegExp(r'\d+$').firstMatch(itemDevId)?.group(0);
        if (itemNum == numMatch) {
          // Check prefix similarity
          if (cleanT.contains('kerala') && (itemTopic.contains('kerala') || itemDevId.contains('kerala'))) return item;
          if (cleanT.contains('annam') && (itemTopic.contains('annam') || itemDevId.contains('annam'))) return item;
          if (cleanT.contains('ssmet') && (itemTopic.contains('ssmet') || itemDevId.contains('ssmet') || item.partnershipName.toLowerCase().contains('ss-met') || item.partnershipName.toLowerCase().contains('ssmet'))) return item;
          if (cleanT.contains('punjab') && (itemTopic.contains('punjab') || itemDevId.contains('punjab'))) return item;
          if (cleanT.contains('aws') && (itemTopic.contains('aws') || itemDevId.contains('aws'))) return item;
          return item;
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
  bool isAdmin = false,
}) {
  showDialog(
    context: context,
    builder: (ctx) => _DeviceSpecificationDialogWidget(
      deviceId: deviceId,
      topic: topic,
      sensorName: sensorName,
      displayName: displayName,
      isDark: isDark,
      isAdmin: isAdmin,
    ),
  );
}

class _DeviceSpecificationDialogWidget extends StatefulWidget {
  final String deviceId;
  final String topic;
  final String? sensorName;
  final String? displayName;
  final bool isDark;
  final bool isAdmin;

  const _DeviceSpecificationDialogWidget({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.sensorName,
    this.displayName,
    required this.isDark,
    this.isAdmin = false,
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

  DeviceImageResult? _deviceImages;
  bool _isLoadingImages = true;
  int _selectedImageSlot = 1;

  bool get _isEffectiveAdmin {
    if (widget.isAdmin) return true;
    try {
      final email = Provider.of<UserProvider>(context, listen: false).userEmail;
      return DeviceUtils.isSuperAdmin(email);
    } catch (_) {
      return false;
    }
  }

  String _resolveTopicForImage(DeviceSpecification? currentSpec) {
    // If widget.topic is present, it is the user's actual station topic (e.g. WS/SSMet_0126/280)
    var t = DeviceImageService.cleanTopic(widget.topic);
    if (t.isNotEmpty && t.toLowerCase() != 'unknown') return t;
    if (currentSpec != null && currentSpec.deviceIdTopic.isNotEmpty) {
      return DeviceImageService.cleanTopic(currentSpec.deviceIdTopic);
    }
    return t;
  }

  String _resolveDeviceIdForImage(DeviceSpecification? currentSpec, String resolvedTopic) {
    // If currentSpec has deviceIdTopic containing '#', the part before '#' is the exact DynamoDB partition key
    if (currentSpec != null && currentSpec.deviceIdTopic.contains('#')) {
      final keyBeforeHash = currentSpec.deviceIdTopic.split('#').first.trim();
      if (keyBeforeHash.isNotEmpty && keyBeforeHash.toLowerCase() != 'unknown') {
        return DeviceImageService.cleanDeviceId(keyBeforeHash, topic: resolvedTopic);
      }
    }
    if (currentSpec != null && currentSpec.deviceId.isNotEmpty && currentSpec.deviceId.toLowerCase() != 'unknown') {
      return DeviceImageService.cleanDeviceId(currentSpec.deviceId, topic: resolvedTopic);
    }
    String rawDev = widget.deviceId.trim();
    if (rawDev.isEmpty || rawDev.toLowerCase() == 'unknown') {
      rawDev = widget.sensorName ?? '';
    }
    return DeviceImageService.cleanDeviceId(rawDev, topic: resolvedTopic);
  }

  Future<void> _loadImagesForSpec(DeviceSpecification? spec, {bool forceRefresh = false}) async {
    final top = _resolveTopicForImage(spec);
    final devId = _resolveDeviceIdForImage(spec, top);

    setState(() {
      _isLoadingImages = true;
    });

    try {
      final imgResult = await DeviceImageService.fetchImages(
        deviceId: devId,
        topic: top,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _deviceImages = imgResult;
          _isLoadingImages = false;
          if (imgResult != null && imgResult.images.isNotEmpty) {
            _selectedImageSlot = imgResult.images.first.slot;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }

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
        _loadImagesForSpec(matched, forceRefresh: forceRefresh);
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
    buffer.writeln('Partnership: ${spec.partnershipName.isNotEmpty ? spec.partnershipName : "N/A"}');
    buffer.writeln('Hardware Specification: ${spec.hardwareVersion.isNotEmpty ? spec.hardwareVersion : "N/A"}');
    buffer.writeln('Firmware Specification: ${spec.firmwareVersion.isNotEmpty ? spec.firmwareVersion : "N/A"}');
    buffer.writeln('Baud Rate: ${spec.ultrasonicBaudrate.isNotEmpty ? spec.ultrasonicBaudrate : "N/A"}');
    buffer.writeln('SIM Provider: ${spec.simProvider.isNotEmpty ? spec.simProvider : "N/A"}');
    buffer.writeln('ATRH Sensor: ${spec.atrhSensor.isNotEmpty ? spec.atrhSensor : "N/A"}');
    buffer.writeln('Rain Sensor: ${spec.rainSensor.isNotEmpty ? spec.rainSensor : "N/A"}');
    buffer.writeln('Last Synced At: ${spec.lastSyncedAt.isNotEmpty ? spec.lastSyncedAt : "N/A"}');
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
                    if (_isEffectiveAdmin) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_note_rounded, color: Colors.cyan, size: 22),
                        tooltip: _selectedSpec != null ? 'Edit Specifications' : 'Add Specifications',
                        onPressed: () => _showEditSpecificationDialog(currentSpec: _selectedSpec),
                      ),
                    ],
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
                                  if (_isEffectiveAdmin) ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () => _showEditSpecificationDialog(currentSpec: null),
                                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                                        label: const Text('Enter Device Specifications', style: TextStyle(fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.cyan.shade700,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                    ),
                                  ],
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
              if (_isEffectiveAdmin) ...[
                Tooltip(
                  message: 'Edit Specifications',
                  child: InkWell(
                    onTap: () => _showEditSpecificationDialog(currentSpec: spec),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.edit_outlined, size: 13, color: Colors.cyan),
                          SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.cyan),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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

        // Device Photo Section (from AWS S3 via GET API)
        _buildDeviceImageSection(spec, isDark, cardBg, borderColor, strongText, subtleText),
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
                badgeColor: Colors.cyan,
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
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'partnership') : null,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Hardware Specification',
                value: spec.hardwareVersion,
                icon: Icons.memory_rounded,
                badgeColor: Colors.deepPurpleAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'hardware') : null,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Firmware Specification',
                value: spec.firmwareVersion,
                icon: Icons.system_update_alt_rounded,
                badgeColor: Colors.orangeAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'firmware') : null,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'Baud Rate',
                value: spec.ultrasonicBaudrate,
                icon: Icons.speed_rounded,
                badgeColor: Colors.cyan,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'baudrate') : null,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'SIM Provider',
                value: spec.simProvider,
                icon: Icons.sim_card_outlined,
                badgeColor: Colors.pinkAccent,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'sim') : null,
              ),
              _buildFieldCard(
                width: itemW,
                label: 'ATRH Sensor Type',
                value: spec.atrhSensor,
                icon: Icons.thermostat,
                badgeColor: Colors.teal,
                isDark: isDark,
                cardBg: cardBg,
                borderColor: borderColor,
                strongText: strongText,
                subtleText: subtleText,
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'atrh') : null,
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
                onEdit: _isEffectiveAdmin ? () => _showEditSpecificationDialog(currentSpec: spec, focusField: 'rain') : null,
              ),
              _buildFieldCard(
                width: constraints.maxWidth,
                label: 'Last Synced At',
                value: spec.lastSyncedAt,
                icon: Icons.sync,
                badgeColor: Colors.greenAccent,
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

  Widget _buildDeviceImageSection(
    DeviceSpecification spec,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color strongText,
    Color subtleText,
  ) {
    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW <= 650;
    final top = _resolveTopicForImage(spec);
    final devId = _resolveDeviceIdForImage(spec, top);
    final bool canUpload = _isEffectiveAdmin;

    if (_isLoadingImages) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyan),
            ),
            const SizedBox(width: 10),
            Text(
              'Checking device installation photos from S3...',
              style: TextStyle(fontSize: 11.5, color: subtleText),
            ),
          ],
        ),
      );
    }

    if (_deviceImages != null && _deviceImages!.images.isNotEmpty) {
      final images = _deviceImages!.images;
      final currentImg = images.firstWhere(
        (img) => img.slot == _selectedImageSlot,
        orElse: () => images.first,
      );

      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_camera_back_outlined,
                          size: 16, color: Colors.cyan),
                      const SizedBox(width: 8),
                      Text(
                        'Installation Photo',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: strongText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.green.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.check_circle_rounded, size: 11, color: Colors.greenAccent),
                            SizedBox(width: 4),
                            Text(
                              'First Slot Image Uploaded',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (images.length > 1) ...[
                        const SizedBox(width: 10),
                        ...images.map((img) {
                          final isSelected = img.slot == _selectedImageSlot;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setState(() => _selectedImageSlot = img.slot),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.cyan.withOpacity(0.2)
                                      : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? Colors.cyan : borderColor,
                                  ),
                                ),
                                child: Text(
                                  'Slot ' + img.slot.toString(),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.cyan : subtleText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Reload Photo Button
                      InkWell(
                        onTap: () => _loadImagesForSpec(spec, forceRefresh: true),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.refresh_rounded, size: 14, color: Colors.cyan),
                              SizedBox(width: 4),
                              Text(
                                'Reload',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyan,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (canUpload && !images.any((img) => img.slot == 2)) ...[
                        const SizedBox(width: 8),
                        // Upload Secondary Slot (Slot 2) Button
                        InkWell(
                          onTap: () {
                            showUploadDeviceImageDialog(
                              context: context,
                              deviceId: devId,
                              topic: top,
                              sensorName: widget.sensorName,
                              displayName: widget.displayName,
                              initialSlot: 2,
                              isDark: isDark,
                              onUploadSuccess: () => _loadImagesForSpec(spec, forceRefresh: true),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.add_photo_alternate_outlined, size: 14, color: Colors.indigoAccent),
                                SizedBox(width: 4),
                                Text(
                                  '+ Slot 2',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.indigoAccent,
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

            // Image display with tap to preview (Contain fit so full photo & GPS stamps are completely visible)
            InkWell(
              onTap: () {
                showDeviceImageLightboxDialog(
                  context: context,
                  imageUrl: currentImg.imageUrl,
                  title: '${widget.displayName ?? spec.deviceId} (Slot ${currentImg.slot})',
                  subtitle: _deviceImages!.locationSummary.isNotEmpty
                      ? _deviceImages!.locationSummary
                      : spec.deviceIdTopic,
                  isDark: isDark,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 250,
                      width: double.infinity,
                      color: isDark ? const Color(0xFF090D16) : const Color(0xFF0F172A),
                      child: DeviceImageView(
                        imageUrl: currentImg.imageUrl,
                        height: 250,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Separate bar below the photo so no part of the image or stamps are obscured
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withOpacity(0.6) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (_deviceImages!.locationSummary.isNotEmpty)
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_on, size: 13, color: Colors.amberAccent),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _deviceImages!.locationSummary,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: strongText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.fullscreen, size: 15, color: Colors.cyan),
                            SizedBox(width: 4),
                            Text(
                              'Click to view full size',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.cyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No image available
    if (canUpload) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.indigoAccent.withOpacity(0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigoAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_a_photo_outlined,
                      size: 18, color: Colors.indigoAccent),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isMobile ? (screenW - 140).clamp(180.0, 320.0) : 320),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No installation photo uploaded yet',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: strongText,
                        ),
                      ),
                      Text(
                        'As an admin, you can upload GPS-tagged photos to S3.',
                        style: TextStyle(fontSize: 10.5, color: subtleText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _loadImagesForSpec(spec, forceRefresh: true),
                  icon: const Icon(Icons.refresh, size: 13),
                  label: const Text('Reload', style: TextStyle(fontSize: 11)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyan,
                    side: const BorderSide(color: Colors.cyan, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showUploadDeviceImageDialog(
                      context: context,
                      deviceId: devId,
                      topic: top,
                      sensorName: widget.sensorName,
                      displayName: widget.displayName,
                      isDark: isDark,
                      onUploadSuccess: () => _loadImagesForSpec(spec, forceRefresh: true),
                    );
                  },
                  icon: const Icon(Icons.upload, size: 13),
                  label: const Text('Upload Photo', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigoAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
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
    VoidCallback? onEdit,
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
                Text(
                  label,
                  style: TextStyle(fontSize: 10.5, color: subtleText),
                  overflow: TextOverflow.ellipsis,
                ),
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
          if (onEdit != null) ...[
            Tooltip(
              message: 'Edit $label',
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: const Icon(Icons.edit, size: 14, color: Colors.cyan),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          if (displayValue != 'N/A')
            Tooltip(
              message: 'Copy $label',
              child: InkWell(
                onTap: () => _copyToClipboard(displayValue, label),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(Icons.copy, size: 14, color: subtleText.withOpacity(0.6)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEditSpecificationDialog({
    DeviceSpecification? currentSpec,
    String? focusField,
  }) {
    final cleanTopic = widget.topic.contains('#') ? widget.topic.split('#').last.trim() : widget.topic.trim();
    final devId = (currentSpec != null && currentSpec.deviceId.isNotEmpty)
        ? currentSpec.deviceId
        : (widget.deviceId.isNotEmpty ? widget.deviceId : (widget.sensorName ?? ''));
    final top = (currentSpec != null && currentSpec.deviceIdTopic.contains('#'))
        ? currentSpec.deviceIdTopic.split('#').last.trim()
        : (cleanTopic.isNotEmpty ? cleanTopic : widget.topic);

    showDialog(
      context: context,
      builder: (ctx) => _EditDeviceSpecificationDialog(
        deviceId: devId,
        topic: top,
        currentSpec: currentSpec,
        focusField: focusField,
        isDark: widget.isDark,
        onSaved: (updatedSpec, result) {
          if (mounted) {
            setState(() {
              _selectedSpec = updatedSpec;
              _allSpecs.removeWhere((s) => s.deviceId == devId || s.deviceIdTopic == '$devId#$top');
              _allSpecs.insert(0, updatedSpec);
            });
            _loadImagesForSpec(updatedSpec);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(result['message']?.toString() ?? 'Device specification saved to DB successfully!'),
                  ),
                ],
              ),
              backgroundColor: Colors.teal.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
            ),
          );
        },
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
          s.partnershipName.toLowerCase().contains(_searchQuery) ||
          s.hardwareVersion.toLowerCase().contains(_searchQuery) ||
          s.firmwareVersion.toLowerCase().contains(_searchQuery) ||
          s.ultrasonicBaudrate.toLowerCase().contains(_searchQuery);
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
                    'Partner: ${item.partnershipName.isEmpty ? 'N/A' : item.partnershipName} • HW: ${item.hardwareVersion.isEmpty ? 'N/A' : item.hardwareVersion} • FW: ${item.firmwareVersion.isEmpty ? 'N/A' : item.firmwareVersion} • Baud: ${item.ultrasonicBaudrate.isEmpty ? 'N/A' : item.ultrasonicBaudrate}',
                    style: TextStyle(fontSize: 10.5, color: subtleText),
                  ),
                  trailing: isCurrent
                      ? const Icon(Icons.check_circle, size: 16, color: Colors.cyan)
                      : const Icon(Icons.chevron_right, size: 16),
                  onTap: () {
                    setState(() => _selectedSpec = item);
                    _loadImagesForSpec(item);
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

// ==========================================
// EDIT / ADD SPECIFICATION DIALOG
// ==========================================

class _EditDeviceSpecificationDialog extends StatefulWidget {
  final String deviceId;
  final String topic;
  final DeviceSpecification? currentSpec;
  final String? focusField;
  final bool isDark;
  final Function(DeviceSpecification updatedSpec, Map<String, dynamic> result) onSaved;

  const _EditDeviceSpecificationDialog({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.currentSpec,
    this.focusField,
    required this.isDark,
    required this.onSaved,
  }) : super(key: key);

  @override
  State<_EditDeviceSpecificationDialog> createState() =>
      _EditDeviceSpecificationDialogState();
}

class _EditDeviceSpecificationDialogState
    extends State<_EditDeviceSpecificationDialog> {
  late final TextEditingController _hwCtrl;
  late final TextEditingController _fwCtrl;
  late final TextEditingController _baudCtrl;
  late final TextEditingController _partnerCtrl;
  late final TextEditingController _simCtrl;
  late final TextEditingController _atrhCtrl;
  late final TextEditingController _rainCtrl;

  final FocusNode _hwFocus = FocusNode();
  final FocusNode _fwFocus = FocusNode();
  final FocusNode _baudFocus = FocusNode();
  final FocusNode _partnerFocus = FocusNode();
  final FocusNode _simFocus = FocusNode();
  final FocusNode _atrhFocus = FocusNode();
  final FocusNode _rainFocus = FocusNode();

  bool _isSaving = false;

  static const List<String> _commonBaudRates = [
    '9600',
    '19200',
    '38400',
    '57600',
    '115200',
    'RS232(9600)',
    'RS485(9600)',
  ];

  @override
  void initState() {
    super.initState();
    _hwCtrl = TextEditingController(text: widget.currentSpec?.hardwareVersion ?? '');
    _fwCtrl = TextEditingController(text: widget.currentSpec?.firmwareVersion ?? '');
    _baudCtrl = TextEditingController(text: widget.currentSpec?.ultrasonicBaudrate ?? '');
    _partnerCtrl = TextEditingController(text: widget.currentSpec?.partnershipName ?? '');
    _simCtrl = TextEditingController(text: widget.currentSpec?.simProvider ?? '');
    _atrhCtrl = TextEditingController(text: widget.currentSpec?.atrhSensor ?? '');
    _rainCtrl = TextEditingController(text: widget.currentSpec?.rainSensor ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.focusField == 'hardware') {
        _hwFocus.requestFocus();
      } else if (widget.focusField == 'firmware') {
        _fwFocus.requestFocus();
      } else if (widget.focusField == 'partnership') {
        _partnerFocus.requestFocus();
      } else if (widget.focusField == 'sim') {
        _simFocus.requestFocus();
      } else if (widget.focusField == 'atrh') {
        _atrhFocus.requestFocus();
      } else if (widget.focusField == 'rain') {
        _rainFocus.requestFocus();
      } else {
        _baudFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _hwCtrl.dispose();
    _fwCtrl.dispose();
    _baudCtrl.dispose();
    _partnerCtrl.dispose();
    _simCtrl.dispose();
    _atrhCtrl.dispose();
    _rainCtrl.dispose();

    _hwFocus.dispose();
    _fwFocus.dispose();
    _baudFocus.dispose();
    _partnerFocus.dispose();
    _simFocus.dispose();
    _atrhFocus.dispose();
    _rainFocus.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final result = await DeviceSpecMetaService.saveSpecification(
        deviceId: widget.deviceId,
        topic: widget.topic,
        deviceIdTopic: widget.currentSpec?.deviceIdTopic,
        hardwareVersion: _hwCtrl.text,
        firmwareVersion: _fwCtrl.text,
        baudRate: _baudCtrl.text,
        partnershipName: _partnerCtrl.text,
        simProvider: _simCtrl.text,
        atrhSensor: _atrhCtrl.text,
        rainSensor: _rainCtrl.text,
      );

      final updated = DeviceSpecification(
        deviceId: widget.deviceId,
        deviceIdTopic: '${widget.deviceId}#${widget.topic}',
        partnershipName: _partnerCtrl.text.trim(),
        hardwareVersion: _hwCtrl.text.trim(),
        firmwareVersion: _fwCtrl.text.trim(),
        ultrasonicBaudrate: _baudCtrl.text.trim(),
        simProvider: _simCtrl.text.trim(),
        atrhSensor: _atrhCtrl.text.trim(),
        rainSensor: _rainCtrl.text.trim(),
        lastSyncedAt: DateTime.now().toString().split('.').first,
      );

      if (mounted) {
        widget.onSaved(updated, result);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error saving specification: $errorMsg'),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildFieldInput({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    required String hint,
    required Color strongText,
    required Color subtleText,
    required Color cardBg,
    required Color borderColor,
    Widget? helperWidget,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.cyan),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: strongText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          focusNode: focusNode,
          style: TextStyle(fontSize: 13, color: strongText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: subtleText.withOpacity(0.55)),
            isDense: true,
            filled: true,
            fillColor: cardBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.cyan, width: 1.5),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 14),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (helperWidget != null) ...[
          const SizedBox(height: 6),
          helperWidget,
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final isMobile = screenW <= 650;
    final editDialogW = isMobile ? screenW - 24 : 540.0;

    final primaryBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final strongText = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtleText = isDark ? Colors.white70 : const Color(0xFF64748B);

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        backgroundColor: primaryBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: 24,
        ),
        child: Container(
          width: editDialogW,
          constraints: BoxConstraints(maxHeight: screenH * 0.88),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF1F5F9).withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Colors.cyan, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.currentSpec != null ? 'Edit Device Specification' : 'Add Device Specification',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: strongText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.deviceId} • ${widget.topic}',
                            style: TextStyle(fontSize: 11, color: subtleText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: subtleText, size: 18),
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Form Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.cyan.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 16, color: Colors.cyan),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Saving specifications via POST API to database for ${widget.deviceId} (${widget.topic}).',
                                style: TextStyle(fontSize: 11, color: strongText),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Baud Rate with quick selection chips
                      _buildFieldInput(
                        label: 'Baud Rate (Ultrasonic)',
                        controller: _baudCtrl,
                        focusNode: _baudFocus,
                        icon: Icons.speed_rounded,
                        hint: 'e.g. 9600, 115200, RS232(9600)',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                        helperWidget: Wrap(
                          spacing: 6,
                          runSpacing: 5,
                          children: _commonBaudRates.map((rate) {
                            final isSelected = _baudCtrl.text.trim() == rate;
                            return InkWell(
                              onTap: () {
                                _baudCtrl.text = rate;
                                setState(() {});
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.cyan.withOpacity(0.22)
                                      : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? Colors.cyan : borderColor,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  rate,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    color: isSelected ? Colors.cyan : subtleText,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      // Hardware Specification
                      _buildFieldInput(
                        label: 'Hardware Specification',
                        controller: _hwCtrl,
                        focusNode: _hwFocus,
                        icon: Icons.memory_rounded,
                        hint: 'e.g. 1.2, v2.0, Rev B',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // Firmware Specification
                      _buildFieldInput(
                        label: 'Firmware Specification',
                        controller: _fwCtrl,
                        focusNode: _fwFocus,
                        icon: Icons.system_update_alt_rounded,
                        hint: 'e.g. AWS 2.2, FW_1.0.4',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // Partnership Name
                      _buildFieldInput(
                        label: 'Partnership Name',
                        controller: _partnerCtrl,
                        focusNode: _partnerFocus,
                        icon: Icons.handshake_outlined,
                        hint: 'e.g. SS-MET, Annam, KSDMA',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // SIM Provider
                      _buildFieldInput(
                        label: 'SIM Provider',
                        controller: _simCtrl,
                        focusNode: _simFocus,
                        icon: Icons.sim_card_outlined,
                        hint: 'e.g. Airtel, Jio, BSNL, NA',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // ATRH Sensor
                      _buildFieldInput(
                        label: 'ATRH Sensor Type',
                        controller: _atrhCtrl,
                        focusNode: _atrhFocus,
                        icon: Icons.thermostat,
                        hint: 'e.g. I2C, SHT30, RS485',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),

                      // Rain Sensor
                      _buildFieldInput(
                        label: 'Rain Sensor Type',
                        controller: _rainCtrl,
                        focusNode: _rainFocus,
                        icon: Icons.water_drop_outlined,
                        hint: 'e.g. ADC, Pulse, Tipping Bucket',
                        strongText: strongText,
                        subtleText: subtleText,
                        cardBg: cardBg,
                        borderColor: borderColor,
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Actions
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: subtleText, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save to DB',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
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
}
