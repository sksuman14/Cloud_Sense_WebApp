import 'package:flutter/material.dart';

class KsdmaResourcesView extends StatelessWidget {
  const KsdmaResourcesView({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004D40), Color(0xFF00897B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.menu_book, color: Colors.amber, size: 48),
                SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Observer Training Resources & Manuals Hub',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Standardized IMD Observation Procedures, Video Tutorials, & Printable PDF Manuals',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section 1: Video Tutorials
          const Text('1. IMD Standard Protocol Video Tutorials', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

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

          const SizedBox(height: 28),

          // Section 2: Downloadable PDF Manuals
          const Text('2. Official Guidelines & User Manuals (PDF)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildPdfRow(
                    context,
                    title: 'KSDMA Citizen Weather Observer Handbook & Protocol Guide',
                    size: '2.4 MB • PDF',
                  ),
                  const Divider(),
                  _buildPdfRow(
                    context,
                    title: 'IMD Weather Instrument Installation & Maintenance Manual',
                    size: '4.1 MB • PDF',
                  ),
                  const Divider(),
                  _buildPdfRow(
                    context,
                    title: 'Daily Manual Observation Logsheet Printable Template',
                    size: '850 KB • PDF',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Section 3: WhatsApp Group & Support
          Card(
            color: const Color(0xFFE8F5E9),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.green)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble, color: Colors.green, size: 40),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Need Help or Facing Issues Submitting Readings?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Join the KSDMA Meteorology Team WhatsApp Observer Group to share observations or get support.', style: TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening Official KSDMA WhatsApp Observer Group...'), backgroundColor: Colors.green),
                      );
                    },
                    icon: const Icon(Icons.open_in_new, color: Colors.white),
                    label: const Text('Join WhatsApp Group'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, {required String title, required String duration, required String thumbnail}) {
    return Card(
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
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfRow(BuildContext context, {required String title, required String size}) {
    return ListTile(
      leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(size, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      trailing: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Downloading $title...')),
          );
        },
        icon: const Icon(Icons.download, size: 16),
        label: const Text('Download'),
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0288D1), foregroundColor: Colors.white),
      ),
    );
  }
}
