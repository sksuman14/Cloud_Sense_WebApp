import 'package:flutter/material.dart';

class KsdmaResourcesView extends StatelessWidget {
  const KsdmaResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
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
              const Text('1. IMD Standard Protocol Video Tutorials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 12),

              if (isMobile) ...[
                _buildVideoCard(
                  context,
                  title: 'Standard Rain Gauge Reading (8:00 AM Protocol)',
                  duration: '4:15 min',
                  thumbnail: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                ),
                const SizedBox(height: 12),
                _buildVideoCard(
                  context,
                  title: 'Max-Min Thermometer (Sixes) Reading Guide',
                  duration: '5:30 min',
                  thumbnail: 'https://images.unsplash.com/photo-1584267385494-9fdd9a71ad75?auto=format&fit=crop&w=400&q=80',
                ),
                const SizedBox(height: 12),
                _buildVideoCard(
                  context,
                  title: 'River Staff Gauge Water Level Measurement',
                  duration: '3:45 min',
                  thumbnail: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=400&q=80',
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        title: 'Standard Rain Gauge Reading (8:00 AM Protocol)',
                        duration: '4:15 min',
                        thumbnail: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        title: 'Max-Min Thermometer (Sixes) Reading Guide',
                        duration: '5:30 min',
                        thumbnail: 'https://images.unsplash.com/photo-1584267385494-9fdd9a71ad75?auto=format&fit=crop&w=400&q=80',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildVideoCard(
                        context,
                        title: 'River Staff Gauge Water Level Measurement',
                        duration: '3:45 min',
                        thumbnail: 'https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=400&q=80',
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

  Widget _buildVideoCard(BuildContext context, {required String title, required String duration, required String thumbnail}) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 140,
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
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading $title...'), backgroundColor: const Color(0xFF2563EB)),
              );
            },
            tooltip: 'Download PDF',
          ),
        ],
      ),
    );
  }
}
