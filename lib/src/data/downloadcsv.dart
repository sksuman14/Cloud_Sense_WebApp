import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_sense_webapp/src/utils/device_config.dart';
import 'package:cloud_sense_webapp/src/utils/api_keys.dart';

/// ---------------------------------------------------------------
///  CALL THIS FROM ANYWHERE
/// ---------------------------------------------------------------
void showCsvDownloadDialog(BuildContext context,
    {required String deviceName,
    String? hardwareDeviceId,
    Set<String>? visibleParameters,
    bool isAdmin = false}) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent accidental close
    builder: (_) => _CsvDownloadDialog(
        deviceName: deviceName,
        hardwareDeviceId: hardwareDeviceId,
        visibleParameters: visibleParameters,
        isAdmin: isAdmin),
  );
}

/// ---------------------------------------------------------------
///  DIALOG (the whole “page” is now a dialog)
/// ---------------------------------------------------------------
class _CsvDownloadDialog extends StatefulWidget {
  final String deviceName;
  final String? hardwareDeviceId;
  final Set<String>? visibleParameters;
  final bool isAdmin;
  const _CsvDownloadDialog(
      {required this.deviceName,
      this.hardwareDeviceId,
      this.visibleParameters,
      this.isAdmin = false});

  @override
  State<_CsvDownloadDialog> createState() => _CsvDownloadDialogState();
}

class _CsvDownloadDialogState extends State<_CsvDownloadDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  List<List<dynamic>> _csvRows = [];
  final DateFormat _formatter = DateFormat('dd-MM-yyyy HH:mm:ss');

  // Field Selection
  static const List<String> _allFields = [
    'Topic',
    'FirmwareVersion',
    'SDcardStatus',
    'CurrentTemperature',
    'CurrentHumidity',
    'LightIntensity',
    'AtmPressure',
    'WindSpeed',
    'WindDirection',
    'BatteryVoltage',
    'SignalStrength',
    'IMEINumber',
    'Latitude',
    'Longitude',
    'RainfallHourly',
    'RainfallDaily',
    'RainfallWeekly',
    'RainfallMinutly',
    'MaximumTemperature',
    'MinimumTemperature',
    'AverageTemperature',
    'MaximumHumidity',
    'MinimumHumidity',
    'AverageHumidity',
    'Visibility',
    'Radiation',
    'CurrentRelativeHumidity',
    'Rainfall',
    'RainfallCumulative',
    'AverageWindSpeed',
    'CurrentWindSpeed',
    'CurrentWindDirection',
    'MaximumWindGustSpeed',
    'MaxWindGustTime',
    'Nitrogen',
    'Phosphorus',
    'Potassium',
    'Salinity',
    'pH',
    'ElectricalConductivity',
    'TemperatureHourlyComulative',
    'HumidityHourlyComulative',
    'LuxHourlyComulative',
    'PressureHourlyComulative',
    'RainfallHourlyComulative',
    'RainfallDailyComulative',
    'RainfallWeeklyComulative',
    'RainfallMinutlyComulative',
    'CorrectedTemp',
    'CorrectedHumidity',
    'SunshineHours',
    'PAR',
    'UVRadiation',
    'SolarRadiation',
  ];

  late Set<String> _selectedFields;
  late List<String> _displayedFields;

  @override
  void initState() {
    super.initState();
    if (widget.visibleParameters != null &&
        widget.visibleParameters!.isNotEmpty) {
      final config = DeviceConfig.getConfig(widget.deviceName);
      Set<String> mappedKeys = {};

      if (config != null) {
        for (var vis in widget.visibleParameters!) {
          if (vis == 'Wind') {
            // Include all wind-related keys from this config
            for (var p in config.parameters) {
              if (p.displayName.toLowerCase().contains('wind') ||
                  p.key.toLowerCase().contains('wind')) {
                mappedKeys.add(p.key);
              }
            }
          } else {
            // Find matching parameter by exactly matching displayName
            for (var p in config.parameters) {
              if (p.displayName == vis) {
                bool isTemp = (vis.toLowerCase() == 'temperature' ||
                    vis.toLowerCase() == 'temp');
                bool isHum = (vis.toLowerCase() == 'humidity');

                if (isTemp) {
                  bool hasCorrected = widget.deviceName.startsWith('SW') ||
                      widget.deviceName.startsWith('WJ') ||
                      widget.deviceName.startsWith('WA') ||
                      widget.deviceName.startsWith('JW') ||
                      widget.deviceName.startsWith('KR') ||
                      widget.deviceName.startsWith('SH') ||
                      widget.deviceName.startsWith('WN') ||
                      widget.deviceName.startsWith('GP') ||
                      widget.deviceName.startsWith('PC');

                  if (widget.isAdmin) {
                    mappedKeys.add('CorrectedTemp');
                    mappedKeys.add(p.key); // Both for admin
                  } else {
                    if (hasCorrected) {
                      mappedKeys.add('CorrectedTemp');
                    } else {
                      mappedKeys.add(p.key); // Fallback to Current for IT, etc.
                    }
                  }
                } else if (isHum) {
                  bool hasCorrected = widget.deviceName.startsWith('SW') ||
                      widget.deviceName.startsWith('WJ') ||
                      widget.deviceName.startsWith('WA') ||
                      widget.deviceName.startsWith('JW') ||
                      widget.deviceName.startsWith('KR') ||
                      widget.deviceName.startsWith('SH') ||
                      widget.deviceName.startsWith('WN') ||
                      widget.deviceName.startsWith('GP') ||
                      widget.deviceName.startsWith('PC');

                  if (widget.isAdmin) {
                    mappedKeys.add('CorrectedHumidity');
                    mappedKeys.add(p.key);
                  } else {
                    if (hasCorrected) {
                      mappedKeys.add('CorrectedHumidity');
                    } else {
                      mappedKeys.add(p.key);
                    }
                  }
                } else {
                  mappedKeys.add(p.key);
                }
              }
            }
          }
        }

        // Display all mapped keys (avoids missing keys not hardcoded in _allFields)
        _displayedFields = mappedKeys.toList();
      } else {
        // Fallback to strict exact match if config is somehow null
        _displayedFields = _allFields.where((field) {
          final lowerField = field.toLowerCase().replaceAll(' ', '');
          for (var vis in widget.visibleParameters!) {
            if (lowerField == vis.toLowerCase().replaceAll(' ', '')) {
              return true;
            }
          }
          return false;
        }).toList();
      }
    } else {
      _displayedFields = List.from(_allFields);
    }
    _selectedFields = Set.from(_displayedFields);
  }

  bool get _supportsFieldSelection {
    final name = widget.deviceName;
    return name.startsWith('SW') ||
        name.startsWith('WJ') ||
        name.startsWith('WA') ||
        name.startsWith('PC') ||
        name.startsWith('GP') ||
        name.startsWith('CF') ||
        name.startsWith('VD') ||
        name.startsWith('SV') ||
        name.startsWith('KD') ||
        name.startsWith('NA') ||
        (name == 'CP001' || name == 'CP003') ||
        name.startsWith('IT') ||
        name.startsWith('WN') ||
        name.startsWith('JW') ||
        name.startsWith('SH') ||
        name.startsWith('KR');
        
  }

  // Download status
  bool _isDownloading = false;
  bool _isDownloaded = false;
  String? _downloadedFileName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: SizedBox(
        width: 360, // Slightly wider for checkboxes
        child: _isDownloaded
            ? _buildSuccessUI()
            : _isDownloading
                ? _buildDownloadingUI()
                : _buildDatePickerUI(),
      ),
    );
  }

  // -----------------------------------------------------------------
  // UI: Date Picker
  // -----------------------------------------------------------------
  Widget _buildDatePickerUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Select Date Range',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ListTile(
          title: Text(
            'Start Date: ${_startDate != null ? DateFormat('dd-MM-yyyy').format(_startDate!) : 'Select a start date'}',
            style: const TextStyle(fontSize: 14),
          ),
          trailing: const Icon(Icons.calendar_today, size: 20),
          onTap: () => _pickDate(isStart: true),
        ),
        ListTile(
          title: Text(
            'End Date: ${_endDate != null ? DateFormat('dd-MM-yyyy').format(_endDate!) : 'Select a end date'}',
            style: const TextStyle(fontSize: 14),
          ),
          trailing: const Icon(Icons.calendar_today, size: 20),
          onTap: () => _pickDate(isStart: false),
        ),
        if (_supportsFieldSelection) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Select Parameters',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => _selectedFields.clear()),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child: const Text('Clear', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton(
                    onPressed: () => setState(
                        () => _selectedFields.addAll(_displayedFields)),
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact),
                    child: const Text('All', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _displayedFields.length,
              itemBuilder: (context, index) {
                final field = _displayedFields[index];
                return CheckboxListTile(
                  title: Text(field, style: const TextStyle(fontSize: 12)),
                  value: _selectedFields.contains(field),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedFields.add(field);
                      } else {
                        _selectedFields.remove(field);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (_startDate != null && _endDate != null)
                  ? () {
                      setState(() => _isDownloading = true);
                      _downloadCsv();
                    }
                  : null,
              child: const Text('Download'),
            ),
          ],
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // UI: Downloading
  // -----------------------------------------------------------------
  Widget _buildDownloadingUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Downloading CSV...',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Preparing file...', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  // -----------------------------------------------------------------
  // UI: Success
  // -----------------------------------------------------------------
  Widget _buildSuccessUI() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 64),
        const SizedBox(height: 16),
        const Text(
          'Successfully Downloaded!',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _downloadedFileName ?? '',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // DATE PICKER
  // -----------------------------------------------------------------
  Future<void> _pickDate({required bool isStart}) async {
    final initialDate =
        isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final firstDate = isStart ? DateTime(2020) : (_startDate ?? DateTime(2020));
    final lastDate = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null; // Reset end if invalid
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // -----------------------------------------------------------------
  // MAIN DOWNLOAD LOGIC
  // -----------------------------------------------------------------
  Future<void> _downloadCsv() async {
    if (_startDate == null || _endDate == null) {
      _showSnack('Please select both dates');
      _finishDownload(success: false);
      return;
    }

    _csvRows.clear();

    final dateFmt = DateFormat('dd-MM-yyyy');
    final startdate = dateFmt.format(_startDate!);
    final enddate = dateFmt.format(_endDate!);

    final smFmt = DateFormat('yyyyMMdd');
    final smStart = smFmt.format(_startDate!);
    final smEnd = smFmt.format(_endDate!);

    String extractedId = widget.deviceName;
    if (widget.deviceName.startsWith('AWS_')) {
      extractedId = widget.deviceName.substring(4);
    } else if (RegExp(r'^[A-Za-z]{2}').hasMatch(widget.deviceName)) {
      extractedId = widget.deviceName.substring(2);
    }
    if (widget.deviceName.startsWith('KR')) {
      final numericId = int.tryParse(extractedId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      extractedId = numericId.toString();
    } else if (RegExp(r'^\d+$').hasMatch(extractedId)) {
      extractedId = int.parse(extractedId).toString();
    }
    final parsedDeviceIdStr = extractedId;

    final deviceId =
        (widget.hardwareDeviceId != null && widget.hardwareDeviceId!.isNotEmpty)
            ? widget.hardwareDeviceId!
            : parsedDeviceIdStr;

    String apiUrl = '';
    if (widget.deviceName.startsWith('SM')) {
      apiUrl =
          'https://n42fiw7l89.execute-api.us-east-1.amazonaws.com/default/SSMet_API_Func?device_id=$deviceId&start_date=$startdate&end_date=$enddate';
    } else if (widget.deviceName.startsWith('SW')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet1225data?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('SS')) {
      apiUrl =
          'https://yebtmt03od.execute-api.us-east-1.amazonaws.com/default/SSMet_Soil_Api_Func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('WJ')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmet0126data?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('WA')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/annam0426data?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('PC')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/polytechnicdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('GP')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/gcpdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('SI')) {
      apiUrl =
          'https://wr8ort42hi.execute-api.us-east-1.amazonaws.com/default/SSMet_Custom_API_func?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CF')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/colonelfarmdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('VD')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/vanixdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('SV')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/svpudata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('KD')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/kargildata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('NA')) {
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/ssmetnarldata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName == 'CP001' || widget.deviceName == 'CP003') {
      String cpDeviceId = widget.deviceName == 'CP001' ? '1' : '3';
      apiUrl =
          'https://gtk47vexob.execute-api.us-east-1.amazonaws.com/campusdata?deviceid=$cpDeviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('CP') &&
        widget.deviceName != 'CP001') {
      apiUrl =
          'https://i1g1n1ufu0.execute-api.us-east-1.amazonaws.com/campusdata?deviceid=$deviceId&startdate=$startdate&enddate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('WD')) {
      apiUrl =
          'https://62f4ihe2lf.execute-api.us-east-1.amazonaws.com/CloudSense_Weather_data_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('CL') ||
        widget.deviceName.startsWith('BD')) {
      apiUrl =
          'https://b0e4z6nczh.execute-api.us-east-1.amazonaws.com/CloudSense_Chloritrone_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WQ')) {
      apiUrl =
          'https://63jeajtwf8.execute-api.us-west-2.amazonaws.com/default/wqm_csv_dwnld_api?deviceId=${widget.deviceName}&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('IT')) {
      apiUrl =
          'https://7a3bcew3y2.execute-api.us-east-1.amazonaws.com/default/IIT_Bombay_API_func?deviceId=$deviceId&startDate=$startdate&endDate=$enddate&mode=download';
    } else if (widget.deviceName.startsWith('WS')) {
      apiUrl =
          'https://xjbnnqcup4.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('FS')) {
      apiUrl =
          'https://d11aiifadm1oq5.cloudfront.net/default/SSMet_Forest_API_func?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('DO')) {
      apiUrl =
          'https://br2s08as9f.execute-api.us-east-1.amazonaws.com/default/CloudSense_Water_quality_api_2_function?deviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('TH')) {
      apiUrl =
          'https://5s3pangtz0.execute-api.us-east-1.amazonaws.com/default/CloudSense_TH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('NH')) {
      apiUrl =
          'https://qgbwurafri.execute-api.us-east-1.amazonaws.com/default/CloudSense_NH_Data_Api_function?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('LU') ||
        widget.deviceName.startsWith('TE') ||
        widget.deviceName.startsWith('AC')) {
      apiUrl =
          'https://2bftil5o0c.execute-api.us-east-1.amazonaws.com/default/CloudSense_sensor_api_function?DeviceId=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('WN')) {
      apiUrl =
          'https://dwqomhli00.execute-api.us-east-1.amazonaws.com/default/Winds_WS_Data_API?deviceid=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('JW')) {
      apiUrl =
          'https://0tolwzsmde.execute-api.us-east-1.amazonaws.com/default/WS_Winds_Jio_Logger_API?annam_id=$deviceId&startdate=$startdate&enddate=$enddate';
    } else if (widget.deviceName.startsWith('SH')) {
      final shDateFmt = DateFormat('yyyy-MM-dd');
      final shStartDate = shDateFmt.format(_startDate!);
      final shEndDate = shDateFmt.format(_endDate!);
      apiUrl =
          'https://bne596pwxi.execute-api.us-east-1.amazonaws.com/default/WS_Shobha_Api?ANNAM_ID=WS_Shobha_$deviceId&startdate=$shStartDate&enddate=$shEndDate&mode=download';
    } else if (widget.deviceName.startsWith('KR')) {
      final krDateFmt = DateFormat('yyyy-MM-dd');
      final krStartDate = krDateFmt.format(_startDate!);
      final krEndDate = krDateFmt.format(_endDate!);
      apiUrl =
          'https://gj6wsq3214.execute-api.us-east-1.amazonaws.com/default/WS_Kerala_API?ANNAM_ID=WS_$deviceId&startdate=$krStartDate&enddate=$krEndDate&key=${ApiKeys.annamApiKey}&mode=download';
    } 
    
    else if (widget.deviceName.startsWith('AW')) {
      final krDateFmt = DateFormat('yyyy-MM-dd');
      final krStartDate = krDateFmt.format(_startDate!);
      final krEndDate = krDateFmt.format(_endDate!);
      apiUrl =
          'https://ag25teqhvi.execute-api.us-east-1.amazonaws.com/default/AWS_Api_Function?ANNAM_ID=AWS_$deviceId&startdate=$krStartDate&enddate=$krEndDate&mode=download';
    }

    if (_supportsFieldSelection && _selectedFields.isNotEmpty) {
      final fields = _selectedFields.join(',');
      if (apiUrl.contains('?')) {
        apiUrl += '&fields=$fields';
      } else {
        apiUrl += '?fields=$fields';
      }
    }

    if (apiUrl.isEmpty) {
      // Should not happen based on logic above
      _showSnack('Unsupported device type');
      _finishDownload(success: false);
      return;
    }

    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode != 200) {
        _showSnack('Failed to fetch data: ${response.statusCode}');
        _finishDownload(success: false);
        return;
      }

      dynamic data = json.decode(response.body);
      if (data is List) {
        data = <String, dynamic>{'items': data};
      }

      // IT & CP Sensor Special Case
      if (widget.deviceName.startsWith('IT') ||
          widget.deviceName.startsWith('CP') ||
          widget.deviceName.startsWith('CF') ||
          widget.deviceName.startsWith('VD') ||
          widget.deviceName.startsWith('NA') ||
          widget.deviceName.startsWith('SV') ||
          widget.deviceName.startsWith('KD') ||
          widget.deviceName.startsWith('PC') ||
          widget.deviceName.startsWith('GP') ||
          widget.deviceName.startsWith('WJ') ||
          widget.deviceName.startsWith('WA') ||
          widget.deviceName.startsWith('KR') ||
          widget.deviceName.startsWith('SW') ||
          widget.deviceName.startsWith('AW') ||
          widget.deviceName.startsWith('SH')) {
        final downloadUrl = data['download_url'] as String?;
        if (downloadUrl == null) {
          _showSnack(data['message']?.toString() ?? 'No data available for download');
          _finishDownload(success: false);
          return;
        }
        final fileName = '${deviceId}_${startdate}_${enddate}_RAW.csv';

        if (kIsWeb) {
          final anchor = html.AnchorElement(href: downloadUrl)
            ..setAttribute('download', fileName)
            ..click();
          await Future.delayed(const Duration(seconds: 1));
        } else {
          final csvResp = await http.get(Uri.parse(downloadUrl));
          if (csvResp.statusCode == 200) {
            await _saveCsvFile(csvResp.body, fileName);
          } else {
            _showSnack('Failed to download CSV');
            _finishDownload(success: false);
            return;
          }
        }
        _finishDownload(success: true, fileName: fileName);
        return;
      }

      // Parse other sensors
      if (widget.deviceName.startsWith('SM')) {
        _parseSMData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('SW')) {
        _parseSWData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('SS')) {
        _parseSSData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('WJ')) {
        _parseWJData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('WA')) {
        _parseWAData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('PC')) {
        _parsePCData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('GP')) {
        _parseGPData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('SI')) {
        _parseSIData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('SH')) {
        // Shobha API returns a raw JSON array
        _parseSHData(data is List ? data : (data['items'] ?? []));
      } else if (widget.deviceName.startsWith('FS')) {
        _parseFSData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('WN')) {
        _parseWNData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('JW')) {
        _parseJWData(data['items'] ?? []);
      } else if (widget.deviceName.startsWith('CL') ||
          widget.deviceName.startsWith('BD')) {
        _csvRows.add(['Timestamp', 'Chlorine']);
        (data['items'] as List)
            .forEach((i) => _csvRows.add([i['human_time'], i['chlorine']]));
      } else if (widget.deviceName.startsWith('WQ')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'TDS',
          'COD',
          'BOD',
          'pH',
          'DO',
          'EC'
        ]);
        (data as List).forEach((i) => _csvRows.add([
              i['time_stamp'],
              i['temperature'],
              i['TDS'],
              i['COD'],
              i['BOD'],
              i['pH'],
              i['DO'],
              i['EC'],
            ]));
      } else if (widget.deviceName.startsWith('WS')) {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Electrode_signal',
          'Chlorine_value',
          'Hypochlorous_value'
        ]);
        (data['items'] as List).forEach((i) => _csvRows.add([
              i['HumanTime'],
              i['temperature'],
              i['Electrode_signal'],
              i['Chlorine_value'],
              i['Hypochlorous_value'],
            ]));
      } else if (widget.deviceName.startsWith('DO')) {
        _csvRows.add(['Timestamp', 'Temperature', 'DO Value', 'DO Percentage']);
        (data['items'] as List).forEach((i) => _csvRows.add([
              i['HumanTime'],
              i['Temperature'],
              i['DO Value'],
              i['DO Percentage'],
            ]));
      } else if (widget.deviceName.startsWith('TH')) {
        _csvRows.add(['Timestamp', 'Temperature', 'Humidity']);
        (data['items'] as List).forEach((i) =>
            _csvRows.add([i['HumanTime'], i['Temperature'], i['Humidity']]));
      } else if (widget.deviceName.startsWith('NH')) {
        _csvRows.add(['Timestamp', 'Ammonia', 'Temperature', 'Humidity']);
        (data['items'] as List).forEach((i) => _csvRows.add([
              i['HumanTime'],
              i['AmmoniaPPM'],
              i['Temperature'],
              i['Humidity'],
            ]));
      } else if (widget.deviceName.startsWith('LU')) {
        _csvRows.add(['Timestamp', 'Lux']);
        (data['sensor_data_items'] as List)
            .forEach((i) => _csvRows.add([i['HumanTime'], i['Lux']]));
      } else if (widget.deviceName.startsWith('TE')) {
        _csvRows.add(['Timestamp', 'Temperature', 'Humidity']);
        (data['sensor_data_items'] as List).forEach((i) =>
            _csvRows.add([i['HumanTime'], i['Temperature'], i['Humidity']]));
      } else {
        _csvRows.add([
          'Timestamp',
          'Temperature',
          'Humidity',
          'LightIntensity',
          'SolarIrradiance'
        ]);
        (data['weather_items'] as List).forEach((i) => _csvRows.add([
              i['HumanTime'],
              i['Temperature'],
              i['Humidity'],
              i['LightIntensity'],
              i['SolarIrradiance'],
            ]));
      }

      if (_csvRows.isEmpty ||
          (_csvRows.length == 1 && _csvRows[0][0] == 'Timestamp')) {
        _csvRows = [
          ['Timestamp', 'Message'],
          ['', 'No data available for selected time range']
        ];
      }

      final fileName = _fileName();
      await _generateCsvFile(fileName);
      _finishDownload(success: true, fileName: fileName);
    } catch (e) {
      _showSnack('Error: $e');
      _finishDownload(success: false);
    }
  }

  // -----------------------------------------------------------------
  // PARSE HELPERS
  // -----------------------------------------------------------------
  void _parseSMData(List<dynamic> items) =>
      _parseGeneric(items, 'TimeStampFormatted', exclude: [
        'TimeStamp',
        'TimeStampFormatted',
        'Topic',
        'IMEINumber',
        'DeviceId'
      ]);

  void _parseSSData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseCFData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseSWData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseWJData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseWAData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parsePCData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);

  void _parseGPData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);

  void _parseSIData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseVDData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseKDData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseNARLData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);

  void _parseFSData(List<dynamic> items) => _parseGeneric(items, 'timestamp',
      exclude: ['timestamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseWNData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);
  void _parseJWData(List<dynamic> items) =>
      _parseGeneric(items, 'TimeStamp', exclude: [
        'Time_Stamp',
        'MQTT_TOPIC',
        'IMEI_Number',
        'Device_ID',
        'ANNAM_ID',
        'STATION_ID',
        'PROVIDER_ID',
        'Time_Stamp_GMT',
        'Latitude',
        'Longitude'
      ]);

  void _parseSVData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: ['TimeStamp', 'Topic', 'IMEINumber', 'DeviceId']);

  void _parseSHData(List<dynamic> items) => _parseGeneric(items, 'TimeStamp',
      exclude: [
        'TimeStamp',
        'ANNAM_ID',
        'Device_ID',
        'IMEI_Number',
        'Latitude',
        'Longitude',
      ]);

  void _parseGeneric(List<dynamic> items, String tsKey,
      {required List<String> exclude}) {
    if (items.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      return;
    }

    final sample = items.first;
    final paramKeys = sample.keys
        .where((k) => !exclude.contains(k) && sample[k] != null)
        .toList();

    if (paramKeys.isEmpty) {
      _csvRows = [
        ['Timestamp', 'Message'],
        ['', 'No data available']
      ];
      return;
    }

    _csvRows.add(['Timestamp', ...paramKeys]);
    for (final i in items) {
      final row = [i[tsKey] ?? ''];
      for (final k in paramKeys) row.add(i[k]?.toString() ?? '');
      _csvRows.add(row);
    }
  }

  // -----------------------------------------------------------------
  // CSV GENERATION & SAVE
  // -----------------------------------------------------------------
  String _fileName() {
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return 'SensorData_${widget.deviceName}_$now.csv';
  }

  Future<void> _generateCsvFile(String name) async {
    final csv = const ListToCsvConverter().convert(_csvRows);

    if (kIsWeb) {
      final blob = html.Blob([csv], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', name)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await _saveCsvFile(csv, name);
    }
  }

  Future<void> _saveCsvFile(String csv, String name) async {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        _showSnack('Downloads folder not accessible');
        return;
      }
      final file = File('${dir.path}/$name');
      await file.writeAsString(csv);
    } catch (e) {
      _showSnack('Save error: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _finishDownload({required bool success, String? fileName}) {
    if (!mounted) return;
    setState(() {
      _isDownloading = false;
      _isDownloaded = success;
      _downloadedFileName = fileName;
    });
  }
}
