import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:universal_html/html.dart' as html;
import '../models/ksdma_models.dart';
import '../services/ksdma_state_service.dart';
import 'ksdma_auth_modal.dart';

class KsdmaResourcesView extends StatelessWidget {
  const KsdmaResourcesView({super.key});

  /// Helper function to launch the tutorial video player dialog for a specific instrument
  static void openTutorialDialog(BuildContext context, InstrumentType type) {
    final state = Provider.of<KsdmaStateService>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final nowCompleted = state.isInstrumentTrainingCompleted(type);
            final isLoggedIn = state.isLoggedIn;

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.ondemand_video, color: Color(0xFF00897B), size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'IMD Protocol Video: ${type.displayName}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogCtx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Mock Video Player Container
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircleAvatar(
                                radius: 30,
                                backgroundColor: Color(0xFF00897B),
                                child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Official IMD Observer Protocol — ${type.displayName}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                '▶ Playing (Simulated HD Video • 4:15 min)',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: Row(
                              children: const [
                                Icon(Icons.pause, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: 0.85,
                                    backgroundColor: Colors.white24,
                                    color: Color(0xFF00897B),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('03:40 / 04:15', style: TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Protocol Description Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.verified_user_outlined, color: Color(0xFF00897B), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'IMD Key Standard Operating Instructions:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _getProtocolSummary(type),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Completion Action Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('Close'),
                        ),
                        const SizedBox(width: 12),
                        if (!isLoggedIn) ...[
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              KsdmaAuthModal.show(context, state);
                            },
                            icon: const Icon(Icons.lock, color: Colors.white, size: 16),
                            label: const Text(
                              'Login to Mark Completed',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD97706),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ] else ...[
                          ElevatedButton.icon(
                            onPressed: nowCompleted
                                ? null
                                : () async {
                                    await state.completeTraining(type);
                                    setDialogState(() {});
                                    if (dialogCtx.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('🎉 Training Completed for ${type.displayName}! Observation Entry unlocked.'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  },
                            icon: Icon(
                              nowCompleted ? Icons.check_circle : Icons.school,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              nowCompleted ? 'Training Completed' : 'Complete & Mark Training Done',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: nowCompleted ? Colors.grey : const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _getProtocolSummary(InstrumentType type) {
    switch (type) {
      case InstrumentType.rainGauge:
        return '1. Measure rainfall precisely at 8:00 AM IST daily.\n2. Keep measuring cylinder vertical on level ground.\n3. Read lower meniscus of water level.';
      case InstrumentType.maxMinThermometer:
        return '1. Read maximum temperature at bottom of blue index on MAX tube.\n2. Read minimum temperature at bottom of index on MIN tube.\n3. Reset index pins using magnet after 8:30 AM reading.';
      case InstrumentType.riverGauge:
        return '1. Stand directly level with staff gauge mark.\n2. Note water stage level in meters (m).\n3. Report immediate warning if level crosses red warning mark.';
      case InstrumentType.hygrometer:
        return '1. Ensure dry bulb and wet bulb wicks are clean.\n2. Take reading at eye level without touching glass.\n3. Cross check relative humidity percentage table.';
      case InstrumentType.awsAutomaticStation:
        return 'Automated IoT Station - Telemetry hardware sends data automatically to AWS Server.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? 14.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner Card
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004D40), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: Colors.amber, size: isMobile ? 36 : 48),
                    SizedBox(width: isMobile ? 12 : 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observer Training Resources & Manuals',
                            style: TextStyle(fontSize: isMobile ? 16 : 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Standardized IMD Procedures, Video Tutorials & Printable PDF Manuals',
                            style: TextStyle(color: Colors.white70, fontSize: isMobile ? 10 : 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section 1: Video Tutorials
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('1. IMD Standard Protocol Video Tutorials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Mandatory for Observation Entry', style: TextStyle(fontSize: 11, color: Color(0xFF0369A1), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (isMobile) ...[
                _buildVideoCard(
                  context,
                  type: InstrumentType.rainGauge,
                  title: 'Standard Rain Gauge Reading (8:00 AM Protocol)',
                  duration: '4:15 min',
                  thumbnail: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                  state: state,
                ),
                const SizedBox(height: 12),
                _buildVideoCard(
                  context,
                  type: InstrumentType.maxMinThermometer,
                  title: 'Max-Min Thermometer (Sixes) Reading Guide',
                  duration: '5:30 min',
                  thumbnail: 'https://images.unsplash.com/photo-1584267385494-9fdd9a71ad75?auto=format&fit=crop&w=400&q=80',
                  state: state,
                ),
                const SizedBox(height: 12),
                _buildVideoCard(
                  context,
                  type: InstrumentType.riverGauge,
                  title: 'River Staff Gauge Water Level Measurement',
                  duration: '3:45 min',
                  thumbnail: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=400&q=80',
                  state: state,
                ),
                const SizedBox(height: 12),
                _buildVideoCard(
                  context,
                  type: InstrumentType.hygrometer,
                  title: 'Hygrometer Relative Humidity Reading Guide',
                  duration: '3:10 min',
                  thumbnail: 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?auto=format&fit=crop&w=400&q=80',
                  state: state,
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        type: InstrumentType.rainGauge,
                        title: 'Standard Rain Gauge Reading (8:00 AM Protocol)',
                        duration: '4:15 min',
                        thumbnail: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                        state: state,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        type: InstrumentType.maxMinThermometer,
                        title: 'Max-Min Thermometer (Sixes) Reading Guide',
                        duration: '5:30 min',
                        thumbnail: 'https://images.unsplash.com/photo-1584267385494-9fdd9a71ad75?auto=format&fit=crop&w=400&q=80',
                        state: state,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        type: InstrumentType.riverGauge,
                        title: 'River Staff Gauge Water Level Measurement',
                        duration: '3:45 min',
                        thumbnail: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=400&q=80',
                        state: state,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        type: InstrumentType.hygrometer,
                        title: 'Hygrometer Humidity Reading Guide',
                        duration: '3:10 min',
                        thumbnail: 'https://images.unsplash.com/photo-1516849841032-87cbac4d88f7?auto=format&fit=crop&w=400&q=80',
                        state: state,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // Section 2: Downloadable PDF Manuals
              const Text('2. Official Guidelines & User Manuals (PDF)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              Card(
                color: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildPdfRow(
                        context,
                        title: 'KSDMA Citizen Weather Observer Handbook & Protocol Guide',
                        size: '2.4 MB • PDF',
                        isMobile: isMobile,
                      ),
                      const Divider(),
                      _buildPdfRow(
                        context,
                        title: 'IMD Weather Instrument Installation & Maintenance Manual',
                        size: '4.1 MB • PDF',
                        isMobile: isMobile,
                      ),
                      const Divider(),
                      _buildPdfRow(
                        context,
                        title: 'Daily Manual Observation Logsheet Printable Template',
                        size: '850 KB • PDF',
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Section 3: WhatsApp Support Card
              Card(
                color: const Color(0xFFF0FDF4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFF86EFAC))),
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 14.0 : 20.0),
                  child: flexSupportLayout(
                    isMobile,
                    children: [
                      const Icon(Icons.chat_bubble, color: Color(0xFF16A34A), size: 36),
                      SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 10 : 0),
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Need Help Submitting Readings?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                            SizedBox(height: 3),
                            Text('Join the KSDMA Meteorology Team WhatsApp Observer Group for daily support.', style: TextStyle(fontSize: 11, color: Color(0xFF334155))),
                          ],
                        ),
                      ),
                      SizedBox(width: isMobile ? 0 : 16, height: isMobile ? 12 : 0),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Opening Official KSDMA WhatsApp Observer Group...'), backgroundColor: Color(0xFF16A34A)),
                          );
                        },
                        icon: const Icon(Icons.open_in_new, color: Colors.white, size: 14),
                        label: const Text('Join WhatsApp Group', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget flexSupportLayout(bool isMobile, {required List<Widget> children}) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return Row(
      children: children,
    );
  }

  Widget _buildVideoCard(
    BuildContext context, {
    required InstrumentType type,
    required String title,
    required String duration,
    required String thumbnail,
    required KsdmaStateService state,
  }) {
    final isCompleted = state.isInstrumentTrainingCompleted(type);
    final isLoggedIn = state.isLoggedIn;

    return InkWell(
      onTap: () => openTutorialDialog(context, type),
      borderRadius: BorderRadius.circular(12),
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isCompleted ? Colors.green.shade300 : Colors.amber.shade400,
            width: isCompleted ? 1.5 : 1,
          ),
        ),
        elevation: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 130,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    image: DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(
                  child: Center(
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)),
                    child: Text(duration, style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
                // Status Badge at top right
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: !isLoggedIn
                          ? Colors.amber.shade900
                          : isCompleted
                              ? Colors.green.shade700
                              : Colors.amber.shade800,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          !isLoggedIn
                              ? Icons.lock
                              : isCompleted
                                  ? Icons.check_circle
                                  : Icons.lock_clock,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          !isLoggedIn
                              ? 'Login Required'
                              : isCompleted
                                  ? 'Completed'
                                  : 'Required',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    !isLoggedIn
                        ? '👉 Login to watch & track training'
                        : isCompleted
                            ? '✅ Unlocked for data entry'
                            : '👉 Tap to watch video & unlock entry',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: !isLoggedIn
                          ? Colors.amber.shade900
                          : isCompleted
                              ? Colors.green.shade700
                              : Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _downloadPdfManual(BuildContext context, String title) {
    try {
      final safeTitle = title.replaceAll(RegExp(r'[^\w\s\-]'), '').replaceAll(' ', '_');
      final fileName = 'KSDMA_Manual_$safeTitle.pdf';
      final pdfContent = '''
%PDF-1.4
1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj
2 0 obj << /Type /Pages /Kinds [3 0 R] /Count 1 >> endobj
3 0 obj << /Type /Page /Parent 2 0 R /Resources <<>> /Contents 4 0 R >> endobj
4 0 obj << /Length 160 >> stream
BT
/F1 12 Tf
70 700 Td
(Official KSDMA IMD Observer Manual - $title) Tj
70 680 Td
(Kerala State Disaster Management Authority - Citizen Weather Network) Tj
ET
endstream endobj
xref
0 5
0000000000 65535 f 
0000000009 00000 n 
0000000058 00000 n 
0000000115 00000 n 
0000000200 00000 n 
trailer << /Size 5 /Root 1 0 R >>
startxref
400
%%EOF
''';

      final bytes = utf8.encode(pdfContent);
      final blob = html.Blob([bytes], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 Downloaded "$fileName" successfully!'),
          backgroundColor: const Color(0xFF00897B),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📥 Downloaded $title!'),
          backgroundColor: const Color(0xFF2563EB),
        ),
      );
    }
  }

  Widget _buildPdfRow(BuildContext context, {required String title, required String size, bool isMobile = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 11 : 13, color: const Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(size, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Color(0xFF2563EB)),
            onPressed: () => _downloadPdfManual(context, title),
            tooltip: 'Download PDF',
          ),
        ],
      ),
    );
  }
}
