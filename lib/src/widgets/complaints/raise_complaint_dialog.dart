import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/models/complaint_model.dart';
import 'package:cloud_sense_webapp/src/services/complaint_service.dart';
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';

/// Clean, simple, and user-friendly issue reporting dialog for CloudSense WebApp.
class RaiseComplaintDialog extends StatefulWidget {
  final String? initialDeviceId;
  final String? initialDeviceTopic;
  final String? initialLocation;
  final List<String> availableDevices;
  final Map<String, dynamic>? initialTelemetry;
  final Function(ComplaintTicket)? onSubmitted;

  const RaiseComplaintDialog({
    super.key,
    this.initialDeviceId,
    this.initialDeviceTopic,
    this.initialLocation,
    this.availableDevices = const [],
    this.initialTelemetry,
    this.onSubmitted,
  });

  static Future<ComplaintTicket?> show(
    BuildContext context, {
    String? initialDeviceId,
    String? initialDeviceTopic,
    String? initialLocation,
    List<String> availableDevices = const [],
    Map<String, dynamic>? initialTelemetry,
  }) {
    return showDialog<ComplaintTicket>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RaiseComplaintDialog(
        initialDeviceId: initialDeviceId,
        initialDeviceTopic: initialDeviceTopic,
        initialLocation: initialLocation,
        availableDevices: availableDevices,
        initialTelemetry: initialTelemetry,
      ),
    );
  }

  @override
  State<RaiseComplaintDialog> createState() => _RaiseComplaintDialogState();
}

class _RaiseComplaintDialogState extends State<RaiseComplaintDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedDeviceId;
  ComplaintCategory _selectedCategory = ComplaintCategory.rainGaugeIssue;
  final TextEditingController _customCategoryController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isUrgent = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  final List<PlatformFile> _attachedFiles = [];

  String _toDisplayName(String raw) {
    if (raw.isEmpty || raw == 'General / All Devices') return raw;
    final display = DevicePrefixUtils.toAnnamDisplayName(raw);
    return display.isNotEmpty ? display : raw;
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialDeviceId != null && widget.initialDeviceId!.isNotEmpty) {
      _selectedDeviceId = _toDisplayName(widget.initialDeviceId!);
    } else if (widget.availableDevices.isNotEmpty) {
      _selectedDeviceId = _toDisplayName(widget.availableDevices.first);
    } else {
      _selectedDeviceId = 'General / All Devices';
    }
  }

  @override
  void dispose() {
    _customCategoryController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _attachedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Could not open photos: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _attachedFiles.removeAt(index);
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == ComplaintCategory.other &&
        _customCategoryController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Please specify the issue';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final email = userProvider.userEmail ?? 'user@cloudsense.com';
      final name = userProvider.userName ?? email.split('@').first;

      // Smart Subject Generation (fallback if user left blank, else user entered subject)
      String generatedSubject;
      if (_subjectController.text.trim().isNotEmpty) {
        generatedSubject = _subjectController.text.trim();
      } else if (_selectedCategory == ComplaintCategory.other &&
          _customCategoryController.text.trim().isNotEmpty) {
        generatedSubject = _customCategoryController.text.trim();
      } else if (_selectedCategory == ComplaintCategory.rainGaugeIssue) {
        generatedSubject = 'Rain Gauge Issue on $_selectedDeviceId';
      } else {
        generatedSubject = '${_selectedCategory.label} on $_selectedDeviceId';
      }

      // Convert attached files to upload payloads for S3 presigned upload
      final uploadPayloads = _attachedFiles
          .map((f) => AttachmentUploadPayload.fromPlatformFile(f))
          .toList();

      final ticket = await ComplaintService().submitComplaint(
        userEmail: email,
        userName: name,
        deviceId: _selectedDeviceId,
        deviceTopic: widget.initialDeviceTopic,
        location: widget.initialLocation,
        category: _selectedCategory,
        isCustomCategory: _selectedCategory == ComplaintCategory.other,
        customCategoryText: _selectedCategory == ComplaintCategory.other
            ? _customCategoryController.text.trim()
            : null,
        priority: _isUrgent ? ComplaintPriority.critical : ComplaintPriority.medium,
        subject: generatedSubject,
        description: _descriptionController.text.trim(),
        files: uploadPayloads,
      );

      if (mounted) {
        widget.onSubmitted?.call(ticket);
        Navigator.of(context).pop(ticket);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Issue submitted! Ticket #${ticket.ticketId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final bgColor = isDark ? const Color(0xFF0F1E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF162A3F) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF0284C7).withOpacity(0.25)
        : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenHeight * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.report_problem_rounded,
                          color: Color(0xFF0284C7),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report an Issue',
                              style: TextStyle(
                                fontFamily: 'OpenSans',
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              'Tell us what is wrong and our team will check it',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // ── Body ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(0xFFEF4444).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFEF4444), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // 1. Device Dropdown
                          _buildSimpleLabel('Select Device', isDark),
                          const SizedBox(height: 5),
                          _buildDeviceDropdown(isDark),

                          const SizedBox(height: 14),

                          // 2. Issue Category Dropdown
                          _buildSimpleLabel('What is the issue?', isDark),
                          const SizedBox(height: 5),
                          _buildCategoryDropdown(isDark),

                          // 3. Dynamic "Other" Field
                          if (_selectedCategory == ComplaintCategory.other) ...[
                            const SizedBox(height: 12),
                            _buildSimpleLabel('Specify the issue *', isDark),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _customCategoryController,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: _inputDecoration(
                                hint: 'e.g. Wire cut by animal, display not turning on',
                                isDark: isDark,
                              ),
                              validator: (val) {
                                if (_selectedCategory == ComplaintCategory.other &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Please write your issue';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 4. Subject Textfield
                          _buildSimpleLabel('Subject *', isDark),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _subjectController,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: _inputDecoration(
                              hint: 'e.g. Rain gauge not recording precipitation, Sensor offline',
                              isDark: isDark,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please enter a subject';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // 5. Description
                          _buildSimpleLabel('Describe what happened *', isDark),
                          const SizedBox(height: 5),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 3,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: _inputDecoration(
                              hint: 'Explain what you noticed, when it started...',
                              isDark: isDark,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Please describe the issue';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          // 5. Photos (Optional)
                          _buildPhotosRow(isDark),

                          const SizedBox(height: 12),

                          // 6. Urgent Checkbox
                          InkWell(
                            onTap: () => setState(() => _isUrgent = !_isUrgent),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: Checkbox(
                                      value: _isUrgent,
                                      activeColor: const Color(0xFFEF4444),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      onChanged: (val) =>
                                          setState(() => _isUrgent = val ?? false),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mark as Urgent',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _isUrgent
                                          ? const Color(0xFFEF4444)
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '(station completely down or critical)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white38 : Colors.black38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Footer ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 15),
                        label: Text(
                          _isSubmitting ? 'Sending...' : 'Submit Report',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      ),
    );
  }

  Widget _buildDeviceDropdown(bool isDark) {
    final rawDevices = <String>{
      _selectedDeviceId,
      ...widget.availableDevices,
      if (widget.initialDeviceId != null) widget.initialDeviceId!,
    }.where((d) => d.trim().isNotEmpty).toList();

    // Deduplicate and format to user-facing ANNAM display names
    final formattedSet = <String>{};
    for (final d in rawDevices) {
      formattedSet.add(_toDisplayName(d));
    }

    final devices = formattedSet.toList();
    devices.sort((a, b) {
      if (a == 'General / All Devices') return -1;
      if (b == 'General / All Devices') return 1;
      final regExp = RegExp(r'(\d+|\D+)');
      final matchesA = regExp.allMatches(a).map((m) => m.group(0)!).toList();
      final matchesB = regExp.allMatches(b).map((m) => m.group(0)!).toList();
      final len = matchesA.length < matchesB.length ? matchesA.length : matchesB.length;
      for (int i = 0; i < len; i++) {
        final partA = matchesA[i];
        final partB = matchesB[i];
        final numA = int.tryParse(partA);
        final numB = int.tryParse(partB);
        if (numA != null && numB != null) {
          final cmp = numA.compareTo(numB);
          if (cmp != 0) return cmp;
        } else {
          final cmp = partA.compareTo(partB);
          if (cmp != 0) return cmp;
        }
      }
      return matchesA.length.compareTo(matchesB.length);
    });

    if (!devices.contains(_selectedDeviceId) && devices.isNotEmpty) {
      _selectedDeviceId = devices.first;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A3F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDeviceId,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF0F1E2E) : Colors.white,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: isDark ? Colors.white60 : Colors.black54),
          items: devices.map((d) {
            return DropdownMenuItem<String>(
              value: d,
              child: Row(
                children: [
                  const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      d,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _selectedDeviceId = val);
          },
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    final options = [
      (ComplaintCategory.rainGaugeIssue, 'Rain Gauge Issue (funnel clog, zero rainfall)', Icons.water_drop_rounded, const Color(0xFF0EA5E9)),
      (ComplaintCategory.connectivityOffline, 'Device Offline / No Data Updating', Icons.wifi_off_rounded, const Color(0xFFEF4444)),
      (ComplaintCategory.sensorInaccuracy, 'Inaccurate / Strange Sensor Readings', Icons.speed_rounded, const Color(0xFF0284C7)),
      (ComplaintCategory.powerBattery, 'Battery or Solar Charging Issue', Icons.battery_alert_rounded, const Color(0xFFF59E0B)),
      (ComplaintCategory.hardwareDamage, 'Physical Damage / Broken Mount', Icons.build_circle_outlined, const Color(0xFF8B5CF6)),
      (ComplaintCategory.other, 'Other Issue (Write your own)', Icons.edit_note_rounded, const Color(0xFF10B981)),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162A3F) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ComplaintCategory>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF0F1E2E) : Colors.white,
          icon: Icon(Icons.arrow_drop_down_rounded,
              color: isDark ? Colors.white60 : Colors.black54),
          items: options.map((opt) {
            return DropdownMenuItem<ComplaintCategory>(
              value: opt.$1,
              child: Row(
                children: [
                  Icon(opt.$3, size: 16, color: opt.$4),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      opt.$2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (cat) {
            if (cat != null) {
              setState(() {
                _selectedCategory = cat;
                if (cat != ComplaintCategory.other) {
                  _customCategoryController.clear();
                }
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildPhotosRow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickPhotos,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                side: BorderSide(color: const Color(0xFF0284C7).withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 15, color: Color(0xFF0284C7)),
              label: const Text(
                'Attach Photo',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _attachedFiles.isEmpty
                  ? 'Optional (device, rain gauge, etc.)'
                  : '${_attachedFiles.length} photo(s) attached',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),

        // Thumbnails
        if (_attachedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _attachedFiles.asMap().entries.map((entry) {
              final idx = entry.key;
              final file = entry.value;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162A3F) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: file.bytes != null
                        ? Image.memory(file.bytes!, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 22),
                  ),
                  Positioned(
                    top: -5,
                    right: -5,
                    child: GestureDetector(
                      onTap: () => _removePhoto(idx),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({required String hint, required bool isDark}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white38 : Colors.black38,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF162A3F) : const Color(0xFFF1F5F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
      ),
    );
  }
}
