import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import '../models/ksdma_models.dart';

class KsdmaCertificateService {
  static Future<void> generateAndDownloadCertificate({
    required KsdmaUser user,
    KsdmaStation? station,
  }) async {
    final pdf = pw.Document();

    final dateStr = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    final userMobile = user.mobileNumber.isNotEmpty ? user.mobileNumber : '2026';
    final certId = 'KSDMA-VOL-$userMobile-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final stationId = station?.stationId ?? 'KSDMA-PWS-01';
    final district = (station?.district.isNotEmpty == true) ? station!.district : (user.district.isNotEmpty ? user.district : 'Kerala');
    final taluk = (station?.taluk.isNotEmpty == true) ? station!.taluk : user.taluk;
    final panchayat = (station?.gramaPanchayat.isNotEmpty == true) ? station!.gramaPanchayat : user.gramaPanchayat;
    final instType = station?.instrumentType.displayName ?? 'Meteorological Sensor';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromHex('#1B365D'), width: 4),
            ),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#D4AF37'), width: 2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  // Top Header
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'KERALA STATE DISASTER MANAGEMENT AUTHORITY',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1B365D'),
                          letterSpacing: 1.5,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Government of Kerala • Disaster Management Center',
                        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'ANNAM AI Citizen Weather Network',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#008080'),
                        ),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Divider(color: PdfColor.fromHex('#D4AF37'), thickness: 1.5),
                    ],
                  ),

                  // Title & Body
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'CERTIFICATE OF APPRECIATION',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#B8860B'),
                          letterSpacing: 2,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'This Certificate is Proudly Presented To',
                        style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey800),
                      ),
                      pw.SizedBox(height: 12),
                      pw.Text(
                        user.fullName.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 26,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromHex('#1B365D'),
                        ),
                      ),
                      pw.Container(width: 250, height: 1.5, color: PdfColor.fromHex('#1B365D')),
                      pw.SizedBox(height: 14),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 40),
                        child: pw.Text(
                          'For outstanding public service and dedication as an official Weather Station Volunteer & Citizen Observer for Station $stationId ($instType) at $panchayat Panchayat, $taluk Taluk, $district District. Your valuable daily meteorological observations contribute directly to Kerala’s Climate Resilience and Disaster Preparedness.',
                          textAlign: pw.TextAlign.center,
                          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey900),
                        ),
                      ),
                    ],
                  ),

                  // Footer & Signatures
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Certificate ID: $certId', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                          pw.Text('Date of Issue: $dateStr', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.SizedBox(height: 16),
                          pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('XYZ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Programme Manager, ANNAM AI', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Container(
                        width: 60,
                        height: 60,
                        decoration: pw.BoxDecoration(
                          shape: pw.BoxShape.circle,
                          border: pw.Border.all(color: PdfColor.fromHex('#D4AF37'), width: 2),
                          color: PdfColor.fromHex('#FFFDF0'),
                        ),
                        child: pw.Center(
                          child: pw.Text(
                            'KSDMA\nVERIFIED\nVOLUNTEER',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#B8860B')),
                          ),
                        ),
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.SizedBox(height: 16),
                          pw.Container(width: 140, height: 1, color: PdfColors.grey600),
                          pw.SizedBox(height: 4),
                          pw.Text('XYZ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Authorized Authority, KSDMA', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();

    if (kIsWeb) {
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'KSDMA_Volunteer_Certificate_${user.fullName.replaceAll(' ', '_')}.pdf')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'KSDMA_Volunteer_Certificate_${user.fullName.replaceAll(' ', '_')}.pdf',
      );
    }
  }
}
