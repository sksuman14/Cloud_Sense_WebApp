import 'dart:io' show File, Directory, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';

class FileDownloadHelper {
  /// Saves and delivers a file across Web, Android, and iOS.
  /// - Web: Initiates browser download via Blob and AnchorElement.
  /// - Android: Saves to /storage/emulated/0/Download (falls back to App Documents).
  /// - iOS: Saves to App Documents and opens the native iOS Share Sheet so the
  ///        user can tap "Save to Files", "AirDrop", or share to other apps.
  static Future<bool> saveAndShareFile({
    required BuildContext context,
    required String fileName,
    required String fileContent,
    String? mimeType = 'text/csv',
    String? shareSubject,
  }) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([fileContent], mimeType ?? 'text/plain');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'Downloading',
            message: 'Downloading $fileName',
          );
        }
        return true;
      }

      // Mobile platforms
      if (Platform.isAndroid) {
        Directory downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getApplicationDocumentsDirectory();
        }

        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsString(fileContent);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'Downloaded',
            message: 'Saved to ${file.path}',
          );
        }
        return true;
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(fileContent);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'File Ready',
            message: 'Choose where to save or share your file',
          );
        }

        // Open native iOS Share sheet
        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType, name: fileName)],
          subject: shareSubject ?? fileName,
        );
        return true;
      } else {
        // Desktop / other
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(fileContent);
        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'Saved',
            message: 'File saved to ${file.path}',
          );
        }
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Error',
          message: 'Error saving file: $e',
          isError: true,
        );
      }
      return false;
    }
  }

  /// Saves binary data (e.g. PDF bytes) cross-platform
  static Future<bool> saveAndShareBytes({
    required BuildContext context,
    required String fileName,
    required List<int> bytes,
    String? mimeType = 'application/pdf',
    String? shareSubject,
  }) async {
    try {
      if (kIsWeb) {
        final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();
        html.Url.revokeObjectUrl(url);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'Downloading',
            message: 'Downloading $fileName',
          );
        }
        return true;
      }

      if (Platform.isAndroid) {
        Directory downloadDir = Directory('/storage/emulated/0/Download');
        if (!await downloadDir.exists()) {
          downloadDir = await getApplicationDocumentsDirectory();
        }

        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'Downloaded',
            message: 'Saved to ${file.path}',
          );
        }
        return true;
      } else if (Platform.isIOS) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          DeleteDeviceUtils.showToastNotification(
            context: context,
            title: 'File Ready',
            message: 'Choose where to save or share your file',
          );
        }

        await Share.shareXFiles(
          [XFile(file.path, mimeType: mimeType, name: fileName)],
          subject: shareSubject ?? fileName,
        );
        return true;
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        DeleteDeviceUtils.showToastNotification(
          context: context,
          title: 'Error',
          message: 'Error saving file: $e',
          isError: true,
        );
      }
      return false;
    }
  }
}
