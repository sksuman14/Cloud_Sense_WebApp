import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart'; // Import utility

class AdvancedDataSendDialog extends StatefulWidget {
  final String deviceId;
  final String? displayDeviceId;
  final String apiUrl;

  const AdvancedDataSendDialog({
    Key? key,
    required this.deviceId,
    this.displayDeviceId,
    this.apiUrl =
        'https://vczv54nfdc.execute-api.us-east-1.amazonaws.com/default/Data_fetch_Btp', // CP default
  }) : super(key: key);

  static Future<void> show(BuildContext context, String deviceId,
      {String? displayDeviceId, String? apiUrl}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: AdvancedDataSendDialog(
          deviceId: deviceId,
          displayDeviceId: displayDeviceId,
          apiUrl: apiUrl ??
              'https://vczv54nfdc.execute-api.us-east-1.amazonaws.com/default/Data_fetch_Btp',
        ),
      ),
    );
  }

  @override
  State<AdvancedDataSendDialog> createState() => _AdvancedDataSendDialogState();
}

class _AdvancedDataSendDialogState extends State<AdvancedDataSendDialog> {
  bool _isLoading = false;

  bool bme = false;
  bool lux = false;
  bool gps = false;
  bool ultrasonic = false;

  int tempCoeff = 0;
  int humiCoeff = 0;

  String deviceReset = 'no';
  String rainReset = 'no';

  String? intervalType;
  int? interval;

  /// Dedicated interval controller for WT devices (plain numeric input).
  final TextEditingController _wtIntervalController = TextEditingController();

  // JW device specific controllers
  late TextEditingController _deviceIdController;
  final TextEditingController _fixLatController = TextEditingController();
  final TextEditingController _fixLongController = TextEditingController();
  final TextEditingController _stationIdController = TextEditingController();
  final TextEditingController _providerIdController = TextEditingController();
  final TextEditingController _httpLoginUsernameController = TextEditingController();
  final TextEditingController _httpLoginPasswordController = TextEditingController();
  final TextEditingController _httpLoginApiController = TextEditingController();
  final TextEditingController _httpSecretApiController = TextEditingController();
  final TextEditingController _httpUploadApiController = TextEditingController();
  bool _jwRestart = true;

  // KR / SH device specific controllers
  late TextEditingController _krDeviceIdController;
  final TextEditingController _krFixLatController = TextEditingController();
  final TextEditingController _krFixLongController = TextEditingController();
  final TextEditingController _krUploadIntervalController = TextEditingController();
  final TextEditingController _krRainGuageSizeController = TextEditingController();
  final TextEditingController _krFileUploadCounterController = TextEditingController();
  final TextEditingController _krBacklogFileCounterController = TextEditingController();
  final TextEditingController _krSimCardApnController = TextEditingController();
  bool _krResetSystemTime = true;
  bool _krRestart = true;

  final List<int> minutelyOptions = [1, 2, 5, 10, 15, 30];
  final List<int> hourlyOptions = [1, 2, 6, 12];

  late Color textColor;
  late bool isDark;
  late bool isMobile;

  /// Returns true when the device is a Weather OTA (WT) sensor.
  /// WT devices only need time-interval configuration.
  bool get _isWTDevice => widget.deviceId.toUpperCase().startsWith('WT');
  
  /// Returns true when the device is a JW sensor.
  bool get _isJWDevice => widget.deviceId.toUpperCase().startsWith('JW');

  /// Returns true when the device is a KR sensor.
  bool get _isKRDevice => widget.deviceId.toUpperCase().startsWith('KR');
  bool get _isAWDevice => widget.deviceId.toUpperCase().startsWith('AW');

  /// Returns true when the device is a SH (Shobha) sensor.
  bool get _isSHDevice => widget.deviceId.toUpperCase().startsWith('SH');

  @override
  void initState() {
    super.initState();
    String numericId = widget.deviceId.replaceAll(RegExp(r'[^0-9]'), '');
    _deviceIdController = TextEditingController(text: numericId);

    // Build the correct ANNAM_ID format for each device family.
    // Parse numeric portion and drop leading zeros (e.g. "001" → 1).
    final int numericInt = int.tryParse(numericId) ?? 0;
    String krDisplayId;
    if (_isSHDevice) {
      // Shobha API expects  WS_Shobha_N
      krDisplayId = 'WS_Shobha_$numericInt';
    } else if (_isKRDevice || _isAWDevice) {
      // Kerala / AWS API expects  WS_N
      krDisplayId = 'WS_$numericInt';
    } else {
      krDisplayId = numericId;
    }
    _krDeviceIdController = TextEditingController(text: krDisplayId);
  }

  @override
  void dispose() {
    _deviceIdController.dispose();
    _wtIntervalController.dispose();
    _fixLatController.dispose();
    _fixLongController.dispose();
    _stationIdController.dispose();
    _providerIdController.dispose();
    _httpLoginUsernameController.dispose();
    _httpLoginPasswordController.dispose();
    _httpLoginApiController.dispose();
    _httpSecretApiController.dispose();
    _httpUploadApiController.dispose();
    _krDeviceIdController.dispose();
    _krFixLatController.dispose();
    _krFixLongController.dispose();
    _krUploadIntervalController.dispose();
    _krRainGuageSizeController.dispose();
    _krFileUploadCounterController.dispose();
    _krBacklogFileCounterController.dispose();
    _krSimCardApnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    isDark = Theme.of(context).brightness == Brightness.dark;
    textColor = isDark ? Colors.black87 : Colors.white;
    final size = MediaQuery.of(context).size;
    isMobile = size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
          : const EdgeInsets.all(40),
      child: Container(
        width: isMobile ? null : 480,
        constraints: isMobile ? const BoxConstraints(maxWidth: 480) : null,
        padding: EdgeInsets.all(isMobile ? 20 : 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFFC0B9B9), const Color(0xFF7B9FAE)]
                : [const Color(0xFF7EABA6), const Color(0xFF363A3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
                Text(
                  _isJWDevice
                      ? "JW Device Configuration"
                      : _isKRDevice
                          ? "Kerala Device Configuration"
                          : _isAWDevice
                              ? "AWS Device Configuration"
                              : _isSHDevice
                                  ? "Sobha Device Configuration"
                                  : _isWTDevice
                                      ? "WT Device Configuration"
                                      : "Device Configuration",
                  style: TextStyle(
                  color: textColor,
                  fontSize: isMobile ? 22 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Device ID Field
              TextField(
                controller: TextEditingController(
                    text: widget.displayDeviceId ??
                        DevicePrefixUtils.toAnnamDisplayName(widget.deviceId))
                  ..selection = TextSelection.fromPosition(
                    TextPosition(
                        offset: (widget.displayDeviceId ??
                                DevicePrefixUtils.toAnnamDisplayName(
                                    widget.deviceId))
                            .length),
                  ),
                readOnly: true,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: "Device ID",
                  labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
                  prefixIcon: Icon(Icons.devices, color: textColor),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                      borderSide:
                          BorderSide(color: textColor.withOpacity(0.5))),
                  focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: textColor, width: 2)),
                  filled: true,
                  fillColor: textColor.withOpacity(0.1),
                ),
              ),
              const SizedBox(height: 24),

              // ── Interval Selection ──
              if (_isJWDevice) ...[
                // JW devices specific fields
                _buildTextField("Numeric Device ID", _deviceIdController, Icons.device_hub),
                const SizedBox(height: 12),
                _buildTextField("Fix Latitude", _fixLatController, Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField("Fix Longitude", _fixLongController, Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField("Station ID", _stationIdController, Icons.store),
                const SizedBox(height: 12),
                _buildTextField("Provider ID", _providerIdController, Icons.business),
                const SizedBox(height: 12),
                _buildTextField("HTTP Login Username", _httpLoginUsernameController, Icons.person),
                const SizedBox(height: 12),
                _buildTextField("HTTP Login Password", _httpLoginPasswordController, Icons.lock, obscureText: true),
                const SizedBox(height: 12),
                _buildTextField("HTTP Login API", _httpLoginApiController, Icons.api),
                const SizedBox(height: 12),
                _buildTextField("HTTP Secret API", _httpSecretApiController, Icons.security),
                const SizedBox(height: 12),
                _buildTextField("HTTP Upload API", _httpUploadApiController, Icons.cloud_upload),
                const SizedBox(height: 12),
                _buildSwitch("Restart Device", _jwRestart, (v) => setState(() => _jwRestart = v)),
              ] else if (_isKRDevice || _isAWDevice || _isSHDevice) ...[
                // KR / AW / SH devices specific fields
                _buildTextField("Device ID", _krDeviceIdController, Icons.device_hub),
                const SizedBox(height: 12),
                _buildTextField("Fix Latitude", _krFixLatController, Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField("Fix Longitude", _krFixLongController, Icons.location_on),
                const SizedBox(height: 12),
                _buildTextField("Upload Interval (min)", _krUploadIntervalController, Icons.timer, isNumber: true),
                const SizedBox(height: 12),
                _buildTextField("Rain Gauge Size", _krRainGuageSizeController, Icons.water_drop, isNumber: true),
                const SizedBox(height: 12),
                if (_isSHDevice) ...[
                  _buildTextField("File Upload Counter", _krFileUploadCounterController, Icons.upload_file, isNumber: true),
                  const SizedBox(height: 12),
                ],
                _buildTextField("Backlog File Counter", _krBacklogFileCounterController, Icons.folder_copy, isNumber: true),
                const SizedBox(height: 12),
                _buildTextField("SIM Card APN", _krSimCardApnController, Icons.sim_card),
                const SizedBox(height: 12),
                _buildSwitch("Reset System Time", _krResetSystemTime, (v) => setState(() => _krResetSystemTime = v)),
                const SizedBox(height: 12),
                _buildSwitch("Restart Device", _krRestart, (v) => setState(() => _krRestart = v)),
              ] else if (_isWTDevice)
                // WT devices: single numeric field for interval (minutes)
                TextField(
                  controller: _wtIntervalController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: textColor),
                  decoration:
                      _inputDecoration("Interval (seconds)", Icons.timer),
                  onChanged: (s) {
                    final val = int.tryParse(s);
                    setState(() => interval = val);
                  },
                )
              else if (!isMobile)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(isExpanded: true, 
                        value: intervalType,
                        hint: Text("Select Interval Type",
                            style:
                                TextStyle(color: textColor.withOpacity(0.7))),
                        decoration:
                            _inputDecoration("Interval Type", Icons.schedule),
                        dropdownColor:
                            isDark ? Colors.blueGrey[50] : Colors.blueGrey[800],
                        style: TextStyle(color: textColor),
                        items: ['Minutely', 'Hourly']
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            intervalType = v;
                            interval = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(isExpanded: true, 
                        value: interval,
                        hint: Text("Select Interval Value",
                            style:
                                TextStyle(color: textColor.withOpacity(0.7))),
                        decoration:
                            _inputDecoration("Interval Value", Icons.timer),
                        dropdownColor:
                            isDark ? Colors.blueGrey[50] : Colors.blueGrey[800],
                        style: TextStyle(color: textColor),
                        items: (intervalType == 'Minutely'
                                ? minutelyOptions
                                : hourlyOptions)
                            .map((i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                      "$i ${intervalType == 'Minutely' ? 'minute${i > 1 ? 's' : ''}' : 'hour${i > 1 ? 's' : ''}'}"),
                                ))
                            .toList(),
                        onChanged: intervalType == null
                            ? null
                            : (v) => setState(() => interval = v!),
                      ),
                    ),
                  ],
                )
              else ...[
                // Mobile: Stacked, consistent colors, shorter hints
                DropdownButtonFormField<String>(isExpanded: true, 
                  value: intervalType,
                  hint: Text("Select Interval Type",
                      style: TextStyle(
                          color: textColor.withOpacity(0.7), fontSize: 14)),
                  decoration: _inputDecoration("Interval Type", Icons.schedule)
                      .copyWith(
                    labelStyle: TextStyle(
                        color: textColor.withOpacity(0.8), fontSize: 14),
                  ),
                  dropdownColor:
                      isDark ? Colors.blueGrey[50] : Colors.blueGrey[800],
                  style: TextStyle(color: textColor, fontSize: 15),
                  items: ['Minutely', 'Hourly']
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: TextStyle(
                                  color:
                                      isDark ? Colors.black87 : Colors.white))))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      intervalType = v;
                      interval = null;
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(isExpanded: true, 
                  value: interval,
                  hint: Text("Select Interval Value",
                      style: TextStyle(
                          color: textColor.withOpacity(0.7), fontSize: 14)),
                  decoration:
                      _inputDecoration("Interval Value", Icons.timer).copyWith(
                    labelStyle: TextStyle(
                        color: textColor.withOpacity(0.8), fontSize: 14),
                  ),
                  dropdownColor:
                      isDark ? Colors.blueGrey[50] : Colors.blueGrey[800],
                  style: TextStyle(color: textColor, fontSize: 15),
                  items: (intervalType == 'Minutely'
                          ? minutelyOptions
                          : hourlyOptions)
                      .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                                "$i ${intervalType == 'Minutely' ? 'minute${i > 1 ? 's' : ''}' : 'hour${i > 1 ? 's' : ''}'}",
                                style: TextStyle(
                                    color: isDark
                                        ? Colors.black87
                                        : Colors.white)),
                          ))
                      .toList(),
                  onChanged: intervalType == null
                      ? null
                      : (v) => setState(() => interval = v!),
                ),
              ],

              const SizedBox(height: 24),

              // ── Sensors, Calibration, Resets — hidden for WT/JW/KR devices ──
              if (!_isWTDevice && !_isJWDevice && !_isKRDevice && !_isAWDevice && !_isSHDevice) ...[
                // Sensors
                _buildSectionTitle("Select Sensor"),
                _buildSwitch("BME(Temp + Humidity + Pressure)", bme,
                    (v) => setState(() => bme = v)),
                _buildSwitch("Lux Sensor", lux, (v) => setState(() => lux = v)),
                _buildSwitch("GPS Module", gps, (v) => setState(() => gps = v)),
                _buildSwitch("Ultrasonic Anemometer", ultrasonic,
                    (v) => setState(() => ultrasonic = v)),
                const SizedBox(height: 24),



                // Reset Commands
                if (!isMobile)
                  Row(
                    children: [
                      Expanded(
                          child: _buildRadio("Full Device Reset", deviceReset,
                              'yes', 'no', (v) => deviceReset = v)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _buildRadio("Reset Rain Gauge", rainReset,
                              'yes', 'no', (v) => rainReset = v)),
                    ],
                  )
                else ...[
                  _buildRadio("Full Device Reset", deviceReset, 'yes', 'no',
                      (v) => deviceReset = v),
                  const SizedBox(height: 16),
                  _buildRadio("Reset Rain Gauge", rainReset, 'yes', 'no',
                      (v) => rainReset = v),
                ],
              ],

              const SizedBox(height: 32),

              // Send Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _sendConfig,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.send_rounded),
                  label: Text(
                      _isLoading ? "Sending OTA..." : "Send Configuration"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.black54 : Colors.white,
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Close",
                    style: TextStyle(
                        color: Colors.teal[700],
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: textColor.withOpacity(0.8)),
      prefixIcon: Icon(icon, color: textColor),
      border: const OutlineInputBorder(),
      enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textColor.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textColor, width: 2)),
      filled: true,
      fillColor: textColor.withOpacity(0.1),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool obscureText = false, bool isNumber = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: TextStyle(color: textColor),
      decoration: _inputDecoration(label, icon),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildSwitch(String label, bool value, Function(bool) onChanged) {
    return Card(
      color: value ? textColor.withOpacity(0.15) : textColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: Text(label,
            style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
        value: value,
        onChanged: (v) => setState(() => onChanged(v)),
        activeColor: Colors.tealAccent,
        dense: true,
      ),
    );
  }

  Widget _buildNumberField(
      String label, int value, int min, int max, Function(int) onChanged) {
    final controller =
        TextEditingController(text: value == 0 ? "" : value.toString());
    controller.selection = TextSelection.fromPosition(
        TextPosition(offset: controller.text.length));

    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(signed: true),
      style: TextStyle(color: textColor),
      decoration: _inputDecoration(label, Icons.tune),
      onChanged: (s) {
        final val = int.tryParse(s) ?? 0;
        if (val >= min && val <= max) onChanged(val);
      },
    );
  }

  Widget _buildRadio(String label, String groupValue, String trueVal,
      String falseVal, Function(String) onChanged) {
    final Color yesColor =
        isDark ? Colors.greenAccent[400]! : Colors.green[600]!;
    final Color noColor = isDark ? Colors.redAccent[400]! : Colors.red[600]!;

    return Card(
      color: textColor.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<String>(
                  value: trueVal,
                  groupValue: groupValue,
                  onChanged: (v) => setState(() => onChanged(v!)),
                  activeColor: yesColor,
                ),
                Text("Yes",
                    style: TextStyle(
                        color: yesColor, fontWeight: FontWeight.w600)),
                const SizedBox(width: 32),
                Radio<String>(
                  value: falseVal,
                  groupValue: groupValue,
                  onChanged: (v) => setState(() => onChanged(v!)),
                  activeColor: noColor,
                ),
                Text("No",
                    style:
                        TextStyle(color: noColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPopup({required String title, required String message}) {
    final Color messageTextColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(milliseconds: 3500), () {
          if (mounted && Navigator.of(context).canPop())
            Navigator.of(context).pop();
        });

        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          title: Row(
            children: [
              Icon(title.contains("Success") ? Icons.check_circle : Icons.error,
                  color: title.contains("Success") ? Colors.green : Colors.red,
                  size: 28),
              const SizedBox(width: 12),
              Text(title,
                  style: TextStyle(
                      color:
                          title.contains("Success") ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(message,
                style: TextStyle(
                    color: messageTextColor, fontSize: 14, height: 1.4)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("OK",
                  style: TextStyle(
                      color: Colors.teal[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendConfig() async {
    setState(() => _isLoading = true);

    final url = Uri.parse(widget.apiUrl);
    final numericDeviceId =
        int.parse(widget.deviceId.replaceAll(RegExp(r'[^0-9]'), '')).toString();

    final Map<String, dynamic> payload;
    if (_isJWDevice) {
      final Map<String, dynamic> dataPayload = {};
      
      // Always include the identifier so the backend knows which device to update.
      dataPayload["ANNAM_ID"] = numericDeviceId;

      if (_deviceIdController.text.isNotEmpty) dataPayload["deviceId"] = _deviceIdController.text;
      if (_fixLatController.text.isNotEmpty) dataPayload["fixLat"] = _fixLatController.text;
      if (_fixLongController.text.isNotEmpty) dataPayload["fixLong"] = _fixLongController.text;
      if (_stationIdController.text.isNotEmpty) dataPayload["stationId"] = _stationIdController.text;
      if (_providerIdController.text.isNotEmpty) dataPayload["providerId"] = _providerIdController.text;
      if (_httpLoginUsernameController.text.isNotEmpty) dataPayload["HttpLoginUsername"] = _httpLoginUsernameController.text;
      if (_httpLoginPasswordController.text.isNotEmpty) dataPayload["HttpLoginPassword"] = _httpLoginPasswordController.text;
      if (_httpLoginApiController.text.isNotEmpty) dataPayload["HttpLoginApi"] = _httpLoginApiController.text;
      if (_httpSecretApiController.text.isNotEmpty) dataPayload["HttpSecretApi"] = _httpSecretApiController.text;
      if (_httpUploadApiController.text.isNotEmpty) dataPayload["HttpUploadApi"] = _httpUploadApiController.text;
      dataPayload["restart"] = _jwRestart;

      payload = {
        "config": true,
        "data": dataPayload
      };
    } else if (_isKRDevice || _isAWDevice) {
      final Map<String, dynamic> dataPayload = {};
      
      if (_krDeviceIdController.text.isNotEmpty) {
        dataPayload["deviceId"] = _krDeviceIdController.text;
        dataPayload["ANNAM_ID"] = _krDeviceIdController.text;
      }
      
      if (_krFixLatController.text.isNotEmpty) dataPayload["fixLat"] = _krFixLatController.text;
      if (_krFixLongController.text.isNotEmpty) dataPayload["fixLong"] = _krFixLongController.text;
      if (_krUploadIntervalController.text.isNotEmpty) dataPayload["UploadInterval"] = num.tryParse(_krUploadIntervalController.text) ?? 10;
      if (_krRainGuageSizeController.text.isNotEmpty) dataPayload["RainGuageSize"] = num.tryParse(_krRainGuageSizeController.text) ?? 0.5;
      if (_krBacklogFileCounterController.text.isNotEmpty) dataPayload["BacklogFileCounter"] = num.tryParse(_krBacklogFileCounterController.text) ?? 10;
      if (_krSimCardApnController.text.isNotEmpty) dataPayload["SetSimCardAPN"] = _krSimCardApnController.text;
      if (_krResetSystemTime) dataPayload["ResetSystemTime"] = true;
      if (_krRestart) dataPayload["restart"] = true;

      payload = {
        "config": true,
        "data": dataPayload
      };
    } else if (_isSHDevice) {
      final Map<String, dynamic> dataPayload = {};

      if (_krDeviceIdController.text.isNotEmpty) {
        dataPayload["deviceId"] = _krDeviceIdController.text;
        dataPayload["ANNAM_ID"] = _krDeviceIdController.text;
      }

      if (_krFixLatController.text.isNotEmpty) dataPayload["fixLat"] = _krFixLatController.text;
      if (_krFixLongController.text.isNotEmpty) dataPayload["fixLong"] = _krFixLongController.text;
      if (_krUploadIntervalController.text.isNotEmpty) dataPayload["UploadInterval"] = num.tryParse(_krUploadIntervalController.text) ?? 10;
      if (_krRainGuageSizeController.text.isNotEmpty) dataPayload["RainGuageSize"] = num.tryParse(_krRainGuageSizeController.text) ?? 0.5;
      if (_krFileUploadCounterController.text.isNotEmpty) dataPayload["BacklogFileCounter"] = num.tryParse(_krFileUploadCounterController.text) ?? 10;
      if (_krBacklogFileCounterController.text.isNotEmpty) dataPayload["BacklogFileCounter"] = num.tryParse(_krBacklogFileCounterController.text) ?? 10;
      if (_krSimCardApnController.text.isNotEmpty) dataPayload["SetSimCardAPN"] = _krSimCardApnController.text;
      if (_krResetSystemTime) dataPayload["ResetSystemTime"] = true;
      if (_krRestart) dataPayload["restart"] = true;

      payload = {
        "config": true,
        "data": dataPayload
      };
    } else if (_isWTDevice) {
      payload = {
        "Interval": interval,
      };
    } else {
      payload = {
        "DeviceId": numericDeviceId,
        "Interval Type": intervalType,
        "Interval": interval,
        "SensorConfig": {
          "BME": bme,
          "Lux": lux,
          "GPS": gps,
          "Ultrasonic": ultrasonic
        },
        "Calibration": {"TempCoeff": 0, "HumiCoeff": 0},
        "DeviceReset": deviceReset == 'yes',
        "RainReset": rainReset == 'yes',
      };
    }

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final displayPayload = Map<String, dynamic>.from(payload);
        displayPayload.remove('Calibration');
        final prettyPayload =
            const JsonEncoder.withIndent('  ').convert(displayPayload);

        _showPopup(
          title: "Success",
          message:
              "OTA Configuration Sent Successfully!\n\nDevice: $numericDeviceId\n\nSent Payload:\n$prettyPayload",
        );
      } else {
        _showPopup(
          title: "Failed (${response.statusCode})",
          message: result['error'] ?? response.body,
        );
      }
    } catch (e) {
      _showPopup(title: "Network Error", message: e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
