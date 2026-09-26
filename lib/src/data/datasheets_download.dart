import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/utils/file_download_helper.dart';

class DownloadManager {
  static final Map<String, Map<String, String>> sensorFiles = {
    "WindSensor": {
      "datasheet": "assets/pdfs/ULTRASONIC_DATASHEET.pdf",
    },
    "ARTH": {
      "datasheet": "assets/pdfs/RADIATION_SHIELD_DATASHEET.pdf",
    },
    "RainGauge": {
      "datasheet": "assets/pdfs/RAIN_GAUGE_DATASHEET.pdf",
    },
    "Gateway": {
      "datasheet": "assets/pdfs/BLE_GATEWAY_Datasheet.pdf",
    },
    "TempHumidityProbe": {
      "datasheet": "assets/pdfs/PROBE_DATASHEET.pdf",
    },
    "DataLogger": {
      "datasheet": "assets/pdfs/Data_logger_datasheet.pdf",
    },
    "Soil": {
      "datasheet": "assets/pdfs/SOIL_SPECTRA_DATASHEET.pdf",
    },
    "UserManual": {
      "datasheet": "assets/pdfs/User_Manual.pdf",
    },
    // ✅ ADD THIS ENTIRE BLOCK
    "SetupManual": {
      "datasheet": "assets/pdfs/Setup_Manual.pdf",
    }
  };

  static Future<void> downloadFile({
    required BuildContext context,
    required String sensorKey,
    required String fileType,
  }) async {
    final filePath = sensorFiles[sensorKey]?[fileType];
    if (filePath == null) {
      _toast(context, "File not found");
      return;
    }

    if (kIsWeb) {
      final webPath = filePath.startsWith("assets/")
          ? filePath.replaceFirst("assets/", "assets/assets/")
          : filePath;
      final fullUrl = Uri.base.resolve(webPath).toString();

      if (await canLaunchUrl(Uri.parse(fullUrl))) {
        await launchUrl(Uri.parse(fullUrl));
      } else {
        _toast(context, "Could not open file in browser");
      }
      return;
    }

    try {
      final byteData = await rootBundle.load(filePath);
      final bytes = byteData.buffer.asUint8List();
      final fileName = '${sensorKey}_$fileType.pdf';

      await FileDownloadHelper.saveAndShareBytes(
        context: context,
        fileName: fileName,
        bytes: bytes,
        mimeType: 'application/pdf',
        shareSubject: 'Datasheet - $sensorKey',
      );
    } catch (e) {
      _toast(context, "Error: $e", isError: true);
    }
  }

  static void _toast(BuildContext context, String msg, {bool isError = false}) {
    DeleteDeviceUtils.showToastNotification(
      context: context,
      title: isError ? 'Alert' : 'Notice',
      message: msg,
      isError: isError,
    );
  }
}
