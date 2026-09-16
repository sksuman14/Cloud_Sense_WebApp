import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QRScannerPopup extends StatefulWidget {
  final Map<String, List<String>> devices;
  final String? targetUserEmail;
  final VoidCallback? onDeviceAdded;

  QRScannerPopup({
    required this.devices,
    this.targetUserEmail,
    this.onDeviceAdded,
  });

  @override
  _QRScannerPopupState createState() => _QRScannerPopupState();
}

class _QRScannerPopupState extends State<QRScannerPopup> {
  String? scannedQRCode;
  String message = "Position the QR code inside the scanner";
  late MobileScannerController _controller;
  String? _email;
  Color messageColor = Colors.teal;
  bool _canClose = true;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
    _loadEmail();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void resetScanner() {
    setState(() {
      scannedQRCode = null;
      message = "Position the QR code inside the scanner";
      _controller.stop();
      _controller.start();
    });
  }

  Future<void> _loadEmail() async {
    if (widget.targetUserEmail != null && widget.targetUserEmail!.isNotEmpty) {
      setState(() {
        _email = widget.targetUserEmail;
      });
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? email = prefs.getString('email');
    setState(() {
      _email = email;
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF0D1F2D) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode ? Colors.white12 : Colors.black.withOpacity(0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.targetUserEmail != null
                  ? 'Scan QR for ${widget.targetUserEmail}'
                  : 'QR Scanner',
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
                fontSize: widget.targetUserEmail != null ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? const Color(0xFF1D2B38) : Colors.grey[200]!,
                  width: 4,
                ),
              ),
              child: MobileScanner(
                controller: _controller,
                onDetect: (BarcodeCapture capture) async {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    final String? code = barcode.rawValue;
                    if (code != null && code != scannedQRCode) {
                      setState(() {
                        scannedQRCode = code;
                        message = "Detected QR Code";
                      });
                      _controller.stop();

                      String inputId = code.trim().toUpperCase();
                      String? finalDeviceId;

                      final candidates = DeviceUtils.getPossibleInternalIDs(inputId);
                      if (candidates.isEmpty) {
                        finalDeviceId = inputId;
                      } else if (candidates.length == 1) {
                        finalDeviceId = candidates.first;
                      } else {
                        finalDeviceId = await DeviceUtils.showPrefixChoiceDialog(
                            context, candidates);
                      }

                      if (finalDeviceId == null) {
                        resetScanner();
                        return;
                      }

                      DeviceUtils.showConfirmationDialog(
                        context: context,
                        deviceId: finalDeviceId,
                        devices: widget.devices,
                        onConfirm: () async {
                          bool success = await DeviceUtils.addDeviceToUser(
                            context: context,
                            email: _email,
                            deviceId: finalDeviceId!,
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // close QR scan popup
                            if (widget.targetUserEmail != null) {
                              widget.onDeviceAdded?.call();
                            } else if (success) {
                              NavigationUtils.navigateTo(context, '/devicelist', isReplacement: true);
                            }
                          }
                        },
                      );
                      break;
                    }
                  }
                },
              ),
            ),
            SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(color: messageColor),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: resetScanner,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: isDarkMode ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Scan Again',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 10),
            if (_canClose)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  "Close",
                  style: TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
