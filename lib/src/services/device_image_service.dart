import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_sense_webapp/src/widgets/device_image_view.dart';
export 'package:cloud_sense_webapp/src/widgets/device_image_view.dart';

// ==========================================
// MODELS
// ==========================================

class DeviceImageItem {
  final int slot;
  final String filename;
  final String s3Key;
  final String imageUrl;
  final int expiresIn;

  DeviceImageItem({
    required this.slot,
    required this.filename,
    required this.s3Key,
    required this.imageUrl,
    required this.expiresIn,
  });

  factory DeviceImageItem.fromJson(Map<String, dynamic> json) {
    return DeviceImageItem(
      slot: int.tryParse(json['slot']?.toString() ?? '1') ?? 1,
      filename: json['filename']?.toString() ?? '',
      s3Key: json['s3_key']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '3600') ?? 3600,
    );
  }
}

class DeviceImageResult {
  final bool success;
  final String message;
  final String deviceId;
  final String topic;
  final String? state;
  final String? district;
  final String? city;
  final List<DeviceImageItem> images;

  DeviceImageResult({
    required this.success,
    required this.message,
    required this.deviceId,
    required this.topic,
    this.state,
    this.district,
    this.city,
    required this.images,
  });

  factory DeviceImageResult.fromJson(Map<String, dynamic> json) {
    final List imgList = json['images'] is List ? json['images'] : [];
    return DeviceImageResult(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      deviceId: json['deviceid']?.toString() ?? json['deviceId']?.toString() ?? '',
      topic: json['topic']?.toString() ?? '',
      state: json['state']?.toString(),
      district: json['district']?.toString(),
      city: json['city']?.toString(),
      images: imgList.map((e) => DeviceImageItem.fromJson(e)).toList(),
    );
  }

  String get locationSummary {
    final parts = [city, district, state]
        .where((s) => s != null && s.trim().isNotEmpty && s != 'NA' && s != 'null')
        .map((s) => s!.trim())
        .toList();
    return parts.join(', ');
  }
}

class DeviceImageUploadResponse {
  final bool success;
  final String message;
  final dynamic rawData;

  DeviceImageUploadResponse({
    required this.success,
    required this.message,
    this.rawData,
  });
}

// ==========================================
// SERVICE WITH IN-MEMORY CACHE
// ==========================================

class DeviceImageService {
  static const String uploadApiUrl =
      'https://4ibd5wpyt3.execute-api.us-east-1.amazonaws.com/default/WS_Image_Upload_API';
  static const String getImagesBaseUrl =
      'https://4ibd5wpyt3.execute-api.us-east-1.amazonaws.com/default/images';

  static final Map<String, _CachedResult> _cache = {};

  static String cleanTopic(String rawTopic) {
    var t = rawTopic.trim();
    if (t.contains('#')) t = t.split('#').last.trim();
    while (t.startsWith('/')) t = t.substring(1);
    while (t.endsWith('/')) t = t.substring(0, t.length - 1);
    return t;
  }

  static String cleanDeviceId(String rawId, {String? topic}) {
    var d = rawId.trim();
    if (d.contains('#')) d = d.split('#').first.trim();
    if (d.contains('/')) d = d.split('/').last.trim();

    // If topic is provided and ends with a number (e.g. WS/SSMet_0126/280)
    if (topic != null && topic.trim().isNotEmpty) {
      final cleanT = cleanTopic(topic);
      final lastSegment = cleanT.split('/').last.trim();
      final numInTopic = RegExp(r'\d+$').firstMatch(lastSegment)?.group(0);
      if (numInTopic != null && numInTopic.isNotEmpty) {
        // If rawId ends with or contains this exact number (e.g. AWS_280 or JW_280 or 280),
        // the canonical ID in the image API is the number itself!
        if (d.endsWith(numInTopic) || d.replaceAll(RegExp(r'\D'), '') == numInTopic) {
          return numInTopic;
        }
      }
    }

    // Strip common hardware prefixes (AWS_, AWS-, JW_, JW-, SSMET_, SSMet_)
    final u = d.toUpperCase();
    if (u.startsWith('AWS_') || u.startsWith('AWS-')) {
      d = d.substring(4).trim();
    } else if (u.startsWith('JW_') || u.startsWith('JW-')) {
      d = d.substring(3).trim();
    } else if (u.startsWith('JW') && d.length > 2 && RegExp(r'^\d+$').hasMatch(d.substring(2))) {
      d = d.substring(2).trim();
    } else if (u.startsWith('SSMET_') || u.startsWith('SSMET-')) {
      d = d.substring(6).trim();
    }

    return d;
  }

  static String _cacheKey(String devId, String topic) =>
      '${cleanDeviceId(devId, topic: topic).toLowerCase()}#${cleanTopic(topic).toLowerCase()}';

  static Future<DeviceImageResult?> _fetchFromApi(String devId, String top) async {
    try {
      final uri = Uri.parse(
          '$getImagesBaseUrl?deviceid=${Uri.encodeComponent(devId)}&topic=${Uri.encodeComponent(top)}');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic> && decoded['success'] == true) {
          return DeviceImageResult.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('Error in _fetchFromApi($devId, $top): $e');
    }
    return null;
  }

  /// Fetch device image(s) from S3 via GET API with multi-stage resolution
  static Future<DeviceImageResult?> fetchImages({
    required String deviceId,
    required String topic,
    bool forceRefresh = false,
  }) async {
    final cTopic = cleanTopic(topic);
    final cDev = cleanDeviceId(deviceId, topic: cTopic);
    if (cDev.isEmpty && cTopic.isEmpty) return null;

    final key = _cacheKey(cDev, cTopic);
    if (!forceRefresh && _cache.containsKey(key)) {
      final cached = _cache[key]!;
      if (DateTime.now().difference(cached.timestamp).inMinutes < 15) {
        return cached.result;
      }
    }

    // Try 1: with cleaned cDev (e.g. "280") and cTopic (e.g. "WS/SSMet_0126/280")
    var result = await _fetchFromApi(cDev, cTopic);
    if (result != null) {
      _cache[key] = _CachedResult(result, DateTime.now());
      return result;
    }

    // Try 2: If cDev was modified from raw deviceId (e.g. raw was "AWS_280" or "JW_280"), try raw
    var rawClean = deviceId.trim();
    if (rawClean.contains('#')) rawClean = rawClean.split('#').first.trim();
    if (rawClean.isNotEmpty && rawClean != cDev) {
      result = await _fetchFromApi(rawClean, cTopic);
      if (result != null) {
        _cache[key] = _CachedResult(result, DateTime.now());
        return result;
      }
    }

    // Try 3: If topic has a numeric suffix (e.g. topic ends with /280) and differs from cDev
    final numInTopic = RegExp(r'\d+$').firstMatch(cTopic)?.group(0);
    if (numInTopic != null && numInTopic != cDev && numInTopic != rawClean) {
      result = await _fetchFromApi(numInTopic, cTopic);
      if (result != null) {
        _cache[key] = _CachedResult(result, DateTime.now());
        return result;
      }
    }

    return null;
  }

  /// Upload device image to S3 via POST API
  static Future<DeviceImageUploadResponse> uploadImage({
    required String deviceId,
    required String topic,
    required int slot,
    required Uint8List imageBytes,
    String? fileName,
  }) async {
    final cTopic = cleanTopic(topic);
    final cDev = cleanDeviceId(deviceId, topic: cTopic);

    if (cDev.isEmpty) {
      return DeviceImageUploadResponse(
        success: false,
        message: 'Device ID cannot be empty.',
      );
    }
    if (cTopic.isEmpty) {
      return DeviceImageUploadResponse(
        success: false,
        message: 'Topic cannot be empty.',
      );
    }

    try {
      final base64Str = base64Encode(imageBytes);

      final payload = {
        'action': 'upload',
        'deviceid': cDev,
        'topic': cTopic,
        'images': [
          {
            'slot': slot,
            'image': base64Str,
          }
        ],
      };

      final response = await http.post(
        Uri.parse(uploadApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final decoded = json.decode(response.body);
      final isSuccess = (response.statusCode == 200) && (decoded['success'] == true);
      final message = decoded['message']?.toString() ??
          (isSuccess ? 'Image uploaded successfully' : 'Upload failed (${response.statusCode})');

      if (isSuccess) {
        // Clear cache for this device
        _cache.remove(_cacheKey(cDev, cTopic));
        final numOnly = RegExp(r'\d+$').firstMatch(cDev)?.group(0);
        if (numOnly != null) _cache.remove(_cacheKey(numOnly, cTopic));
      }

      return DeviceImageUploadResponse(
        success: isSuccess,
        message: message,
        rawData: decoded,
      );
    } catch (e) {
      return DeviceImageUploadResponse(
        success: false,
        message: 'Network or server error during upload: $e',
      );
    }
  }
}

class _CachedResult {
  final DeviceImageResult result;
  final DateTime timestamp;
  _CachedResult(this.result, this.timestamp);
}

// ==========================================
// UPLOAD DIALOG (FOR ADMINS)
// ==========================================

void showUploadDeviceImageDialog({
  required BuildContext context,
  required String deviceId,
  required String topic,
  String? sensorName,
  String? displayName,
  required bool isDark,
  VoidCallback? onUploadSuccess,
}) {
  showDialog(
    context: context,
    builder: (ctx) => DeviceImageUploadDialog(
      deviceId: deviceId,
      topic: topic,
      sensorName: sensorName,
      displayName: displayName,
      isDark: isDark,
      onUploadSuccess: onUploadSuccess,
    ),
  );
}

class DeviceImageUploadDialog extends StatefulWidget {
  final String deviceId;
  final String topic;
  final String? sensorName;
  final String? displayName;
  final bool isDark;
  final VoidCallback? onUploadSuccess;

  const DeviceImageUploadDialog({
    Key? key,
    required this.deviceId,
    required this.topic,
    this.sensorName,
    this.displayName,
    required this.isDark,
    this.onUploadSuccess,
  }) : super(key: key);

  @override
  State<DeviceImageUploadDialog> createState() => _DeviceImageUploadDialogState();
}

class _DeviceImageUploadDialogState extends State<DeviceImageUploadDialog> {
  late TextEditingController _deviceIdController;
  late TextEditingController _topicController;

  int _selectedSlot = 1;
  Uint8List? _selectedImageBytes;
  String? _selectedFileName;
  int? _selectedFileSize;

  bool _isUploading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    final cTopic = DeviceImageService.cleanTopic(widget.topic);
    final cDev = DeviceImageService.cleanDeviceId(widget.deviceId, topic: cTopic);
    _deviceIdController = TextEditingController(text: cDev);
    _topicController = TextEditingController(text: cTopic);
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _selectedImageBytes = file.bytes;
            _selectedFileName = file.name;
            _selectedFileSize = file.size;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error selecting image: $e';
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedImageBytes == null) {
      setState(() {
        _errorMessage = 'Please select an image file to upload.';
      });
      return;
    }

    final devId = _deviceIdController.text.trim();
    final top = _topicController.text.trim();

    if (devId.isEmpty || top.isEmpty) {
      setState(() {
        _errorMessage = 'Device ID and Topic cannot be empty.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final res = await DeviceImageService.uploadImage(
      deviceId: devId,
      topic: top,
      slot: _selectedSlot,
      imageBytes: _selectedImageBytes!,
      fileName: _selectedFileName,
    );

    if (!mounted) return;

    if (res.success) {
      setState(() {
        _isUploading = false;
        _successMessage = res.message.isNotEmpty
            ? res.message
            : 'Image successfully uploaded to S3!';
      });
      widget.onUploadSuccess?.call();

      Future.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) {
          Navigator.pop(context, true);
        }
      });
    } else {
      setState(() {
        _isUploading = false;
        _errorMessage = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final primaryBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);
    final strongText = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtleText = isDark ? Colors.white70 : const Color(0xFF64748B);

    final screenW = MediaQuery.of(context).size.width;
    final isMobile = screenW <= 650;
    final dialogW = isMobile ? screenW - 24 : 540.0;

    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
      child: Dialog(
        backgroundColor: primaryBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: borderColor),
        ),
        insetPadding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 32, vertical: 24),
        child: Container(
          width: dialogW,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
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
                        color: Colors.indigoAccent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_a_photo_rounded,
                          color: Colors.indigoAccent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Upload Device Image',
                            style: TextStyle(
                              fontSize: isMobile ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: strongText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Admin Portal • Store in AWS S3',
                            style: TextStyle(
                              fontSize: 11,
                              color: subtleText,
                            ),
                          ),
                        ],
                      ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Alert/Notice Banner about Lat/Long Requirement
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.amber, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Note: Ensure the uploaded photo has GPS coordinates (Latitude & Longitude) visibly stamped, such as from a GPS Map Camera app.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.amber.shade200
                                      : Colors.amber.shade900,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Device ID & Topic Inputs
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Device ID',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: subtleText)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _deviceIdController,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: strongText,
                                      fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBg,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Topic',
                                    style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: subtleText)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _topicController,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: strongText,
                                      fontWeight: FontWeight.w600),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBg,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: borderColor),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Slot Selection (Slot 1 vs Slot 2)
                      Text('Image Slot',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: subtleText)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedSlot = 1),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _selectedSlot == 1
                                      ? Colors.indigoAccent.withOpacity(0.15)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedSlot == 1
                                        ? Colors.indigoAccent
                                        : borderColor,
                                    width: _selectedSlot == 1 ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedSlot == 1
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 16,
                                      color: _selectedSlot == 1
                                          ? Colors.indigoAccent
                                          : subtleText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Slot 1 (Primary)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _selectedSlot == 1
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _selectedSlot == 1
                                            ? (_selectedSlot == 1 && isDark
                                                ? Colors.white
                                                : Colors.indigo.shade900)
                                            : strongText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _selectedSlot = 2),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _selectedSlot == 2
                                      ? Colors.indigoAccent.withOpacity(0.15)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _selectedSlot == 2
                                        ? Colors.indigoAccent
                                        : borderColor,
                                    width: _selectedSlot == 2 ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _selectedSlot == 2
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 16,
                                      color: _selectedSlot == 2
                                          ? Colors.indigoAccent
                                          : subtleText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Slot 2 (Secondary)',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _selectedSlot == 2
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        color: _selectedSlot == 2
                                            ? (_selectedSlot == 2 && isDark
                                                ? Colors.white
                                                : Colors.indigo.shade900)
                                            : strongText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Image Selector Box / Preview
                      Text('Device Photo',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: subtleText)),
                      const SizedBox(height: 6),
                      if (_selectedImageBytes != null) ...[
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(12)),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxHeight: 220),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.image,
                                        size: 16, color: Colors.indigoAccent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedFileName ?? 'image.jpg',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: strongText),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (_selectedFileSize != null)
                                            Text(
                                              '${(_selectedFileSize! / 1024).toStringAsFixed(1)} KB',
                                              style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: subtleText),
                                            ),
                                        ],
                                      ),
                                    ),
                                    TextButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(Icons.refresh, size: 14),
                                      label: const Text('Change',
                                          style: TextStyle(fontSize: 11.5)),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.indigoAccent,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: _pickImage,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                vertical: 28, horizontal: 16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.indigoAccent.withOpacity(0.4),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.indigoAccent.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.cloud_upload_outlined,
                                      size: 32, color: Colors.indigoAccent),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Click to select device photo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: strongText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Supports JPEG, JPG, PNG (Max 10MB)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: subtleText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Error or Success Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.redAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.redAccent, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_successMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline,
                                  color: Colors.green, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _successMessage!,
                                  style: const TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),

              // FOOTER
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                  color: isDark
                      ? const Color(0xFF0F172A).withOpacity(0.5)
                      : const Color(0xFFF8FAFC),
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed:
                          _isUploading ? null : () => Navigator.pop(context),
                      child: Text('Cancel',
                          style: TextStyle(color: subtleText, fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _handleUpload,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_upload_rounded, size: 16),
                      label: Text(
                        _isUploading ? 'Uploading to S3...' : 'Upload Image',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigoAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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

// ==========================================
// LIGHTBOX FULL PREVIEW DIALOG
// ==========================================

void showDeviceImageLightboxDialog({
  required BuildContext context,
  required String imageUrl,
  required String title,
  String? subtitle,
  required bool isDark,
}) {
  showDialog(
    context: context,
    builder: (ctx) => BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
      child: Dialog(
        backgroundColor: Colors.black.withOpacity(0.92),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 750),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.photo_size_select_actual_outlined,
                        color: Colors.white70, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subtitle != null && subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_new,
                          color: Colors.white70, size: 18),
                      tooltip: 'Open in new tab',
                      onPressed: () async {
                        final uri = Uri.parse(imageUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),

              // Image with InteractiveViewer zoom (CORS-safe on web)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: DeviceImageView(
                        imageUrl: imageUrl,
                        height: 480,
                        fit: BoxFit.contain,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
