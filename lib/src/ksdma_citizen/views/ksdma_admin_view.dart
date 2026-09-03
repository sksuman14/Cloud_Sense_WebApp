// ignore: deprecated_member_use
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaAdminView extends StatefulWidget {
  const KsdmaAdminView({super.key});

  @override
  State<KsdmaAdminView> createState() => _KsdmaAdminViewState();
}

class _KsdmaAdminViewState extends State<KsdmaAdminView> {
  String _selectedModerationReason = 'Outlier';
  String _selectedModerationDateRange = 'Today';
  String? _selectedObsId;

  String _pendingSearchQuery = '';
  final TextEditingController _pendingSearchTextController = TextEditingController();

  String? _selectedUploadStationId;
  String? _selectedFileName;
  String? _uploadedCsvContent;
  bool _isProcessingUpload = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<KsdmaStateService>(context, listen: false).fetchStationsIfNeeded();
    });
  }

  @override
  void dispose() {
    _pendingSearchTextController.dispose();
    super.dispose();
  }

  void _showZoomDialog(BuildContext context, String imageUrl) {
    if (imageUrl.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade900,
                    padding: const EdgeInsets.all(40),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text('Image preview unavailable', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final pending = state.pendingStations;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final activeObsCount = state.observations.where((o) => !o.isRemoved && !o.observationDate.isBefore(todayStart)).length;

    final activeStationsCount = state.stations.where((s) => s.approvalStatus == ApprovalStatus.approved).length;
    final rejectedStationsCount = state.stations.where((s) => s.approvalStatus == ApprovalStatus.rejected).length;
    final stationSubtext = rejectedStationsCount > 0 ? '$rejectedStationsCount Rejected' : '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Banner
              const Text(
                'ADMIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Color(0xFF146356),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage the network',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Approvals, bulk uploads and data quality — not data entry.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Top Metric Cards Row
              if (isMobile)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildTopStatCard('${pending.length}', 'Pending Registrations', const Color(0xFFD97706), Icons.hourglass_top, constraints.maxWidth),
                    _buildTopStatCard('$activeStationsCount', 'Active Stations', const Color(0xFF2563EB), Icons.sensors, constraints.maxWidth, sublabel: stationSubtext),
                    _buildTopStatCard('$activeObsCount', 'Today\'s Observations', const Color(0xFF059669), Icons.assignment_turned_in, constraints.maxWidth),
                    _buildTopStatCard('Good', 'Data Quality', const Color(0xFF0D9488), Icons.verified, constraints.maxWidth),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _buildTopStatCard('${pending.length}', 'Pending Registrations', const Color(0xFFD97706), Icons.hourglass_top, 0)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTopStatCard('$activeStationsCount', 'Active Stations', const Color(0xFF2563EB), Icons.sensors, 0, sublabel: stationSubtext)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTopStatCard('$activeObsCount', 'Today\'s Observations', const Color(0xFF059669), Icons.assignment_turned_in, 0)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTopStatCard('Good', 'Data Quality', const Color(0xFF0D9488), Icons.verified, 0)),
                  ],
                ),

              const SizedBox(height: 22),

              // 3. Main 2-Column Content Layout (Pending Approvals Table + Right Side Upload & Moderation Cards)
              if (isMobile) ...[
                _buildPendingRegistrationsCard(state, pending),
                const SizedBox(height: 20),
                _buildBulkUploadCard(state),
                const SizedBox(height: 20),
                _buildDataModerationCard(state),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _buildPendingRegistrationsCard(state, pending),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _buildBulkUploadCard(state),
                          const SizedBox(height: 18),
                          _buildDataModerationCard(state),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopStatCard(String value, String label, Color accentColor, IconData icon, double maxWidth, {String? sublabel}) {
    return Container(
      width: maxWidth > 0 ? (maxWidth - 52) / 2 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (sublabel != null && sublabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRegistrationsCard(KsdmaStateService state, List<KsdmaStation> pending) {
    final filteredPending = _pendingSearchQuery.isEmpty
        ? pending
        : pending.where((s) {
            final q = _pendingSearchQuery.toLowerCase();
            return s.stationId.toLowerCase().contains(q) ||
                s.ownerName.toLowerCase().contains(q) ||
                s.district.toLowerCase().contains(q) ||
                s.taluk.toLowerCase().contains(q) ||
                s.gramaPanchayat.toLowerCase().contains(q) ||
                s.instrumentType.displayName.toLowerCase().contains(q);
          }).toList();

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pending device registrations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${filteredPending.length}/${pending.length} Pending',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFD97706)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (pending.isNotEmpty) ...[
              Container(
                height: 34,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 16, color: Color(0xFF2563EB)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _pendingSearchTextController,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        decoration: const InputDecoration(
                          hintText: '🔍 Search pending registrations by ID, applicant name, location...',
                          hintStyle: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) => setState(() => _pendingSearchQuery = val.trim()),
                      ),
                    ),
                    if (_pendingSearchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _pendingSearchTextController.clear();
                          setState(() => _pendingSearchQuery = '');
                        },
                        child: const Icon(Icons.clear, size: 16, color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ],

            if (pending.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.verified, size: 42, color: Color(0xFF059669)),
                    SizedBox(height: 10),
                    Text(
                      'All station registration requests have been reviewed!',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text('New registration submissions will appear here for Admin HQ approval.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  ],
                ),
              )
            else if (filteredPending.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(
                  child: Text('No pending registration requests match search query.', style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 8,
                  headingRowHeight: 38,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(label: Text('NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('DISTRICT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('INSTRUMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('SUBMITTED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                    DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                  ],
                  rows: filteredPending.map((station) {
                    final dt = station.createdAt;
                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                    final submittedDateStr = '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]}';
                    return DataRow(
                      cells: [
                        DataCell(
                          Row(
                            children: [
                              if (station.devicePhotoUrl != null && station.devicePhotoUrl!.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _showZoomDialog(context, station.devicePhotoUrl!),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      image: DecorationImage(
                                        image: NetworkImage(station.devicePhotoUrl!),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(station.ownerName.isNotEmpty ? station.ownerName : station.stationId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                                  Text(station.stationId, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                ],
                              ),
                            ],
                          ),
                        ),
                        DataCell(Text(station.district, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)))),
                        DataCell(Text(station.instrumentType.displayName, style: const TextStyle(fontSize: 12, color: Color(0xFF334155)))),
                        DataCell(Text(submittedDateStr, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Approve Button (Green Checkmark)
                              IconButton(
                                onPressed: () async {
                                  await state.approveStation(station.stationId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('✅ Station ${station.stationId} Approved & Live on Public Map!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(28, 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                tooltip: 'Approve Station',
                              ),
                              const SizedBox(width: 6),
                              // Reject Button (Red Outline Cross)
                              IconButton(
                                onPressed: () async {
                                  final reasonCtrl = TextEditingController();
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Reject Station Registration'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Enter rejection reason:'),
                                          const SizedBox(height: 8),
                                          TextField(
                                            controller: reasonCtrl,
                                            decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'e.g. Invalid photo, inaccurate GPS'),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Reject')),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    final reason = reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Rejected by Admin HQ';
                                    await state.rejectStationWithReason(station.stationId, reason);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('🚫 Station ${station.stationId} Rejected.'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.close, size: 16, color: Color(0xFF64748B)),
                                style: IconButton.styleFrom(
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(28, 28),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                tooltip: 'Reject Station',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkUploadCard(KsdmaStateService state) {
    // 1. Filter out AWS stations & Rejected/Pending stations — only show Approved Active volunteer stations
    final volunteerStations = state.stations
        .where((s) => !s.stationId.startsWith('WS_') && s.category != StationCategory.aws && s.approvalStatus == ApprovalStatus.approved)
        .toList();

    if (_selectedUploadStationId == null || !volunteerStations.any((s) => s.stationId == _selectedUploadStationId)) {
      if (volunteerStations.isNotEmpty) {
        _selectedUploadStationId = volunteerStations.first.stationId;
      }
    }

    final targetStation = volunteerStations.firstWhere(
      (s) => s.stationId == _selectedUploadStationId,
      orElse: () => volunteerStations.isNotEmpty
          ? volunteerStations.first
          : (state.stations.isNotEmpty
              ? state.stations.first
              : KsdmaStation(
                  stationId: 'PWS_001',
                  ownerUserId: 'guest',
                  ownerName: 'Volunteer Observer',
                  ownerCategory: UserCategory.generalPublic,
                  category: StationCategory.manual,
                  instrumentType: InstrumentType.rainGauge,
                  deviceMake: 'Standard',
                  measurementLocation: 'Terrace Ground',
                  latitude: 10.5276,
                  longitude: 76.2144,
                  district: 'Thiruvananthapuram',
                  taluk: 'Thiruvananthapuram',
                  gramaPanchayat: 'Thiruvananthapuram',
                  village: 'Thiruvananthapuram',
                  approvalStatus: ApprovalStatus.approved,
                  createdAt: DateTime.now(),
                )),
    );

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.upload_file, color: Color(0xFFD97706), size: 20),
                SizedBox(width: 8),
                Text(
                  'Bulk upload (WhatsApp / Volunteer Data)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Select a registered volunteer station to import historical CSV/Excel data with strict instrument & sanity validation.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Dropdown to pick Target Volunteer Station
            const Text('Select Target Volunteer Device / Station:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF1E293B))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: volunteerStations.any((s) => s.stationId == _selectedUploadStationId) ? _selectedUploadStationId : (volunteerStations.isNotEmpty ? volunteerStations.first.stationId : null),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFD97706))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: volunteerStations.map((stn) => DropdownMenuItem(
                value: stn.stationId,
                child: Text(
                  '${stn.stationId} — ${stn.instrumentType.displayName} (${stn.district}${stn.gramaPanchayat.isNotEmpty ? ", " + stn.gramaPanchayat : ""})',
                  overflow: TextOverflow.ellipsis,
                ),
              )).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedUploadStationId = val);
              },
            ),

            const SizedBox(height: 14),

            // Dashed Drag & Drop Container
            InkWell(
              onTap: () => _pickAndReadFile(targetStation),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: _selectedFileName != null ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedFileName != null ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFileName != null ? Icons.task_alt : Icons.cloud_upload_outlined,
                      size: 34,
                      color: _selectedFileName != null ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _selectedFileName ?? 'Drop CSV/Excel file or tap to choose file',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _selectedFileName != null ? const Color(0xFF15803D) : const Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (_selectedFileName != null)
                      const Text(
                        'Tap again to change file',
                        style: TextStyle(fontSize: 10, color: Color(0xFF166534)),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton.icon(
                onPressed: _isProcessingUpload ? null : () => _processAndSubmitCsv(state, targetStation),
                icon: _isProcessingUpload
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload, size: 18),
                label: Text(
                  _isProcessingUpload ? 'Validating & Uploading...' : 'Validate & Upload Dataset',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickAndReadFile(KsdmaStation targetStation) {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = '.csv,.txt,.xlsx';
      uploadInput.click();

      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          reader.readAsText(file);
          reader.onLoadEnd.listen((e) {
            final content = reader.result as String;
            setState(() {
              _selectedFileName = file.name;
              _uploadedCsvContent = content;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('📄 File "${file.name}" loaded successfully! Ready for validation & upload.'),
                backgroundColor: const Color(0xFF2563EB),
                duration: const Duration(seconds: 3),
              ),
            );
          });
        }
      });
    } catch (e) {
      debugPrint('File picker notice: $e');
    }
  }

  Future<void> _processAndSubmitCsv(KsdmaStateService state, KsdmaStation targetStation) async {
    if (_uploadedCsvContent == null || _uploadedCsvContent!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please choose a CSV/Excel file first before tapping Upload.'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    setState(() => _isProcessingUpload = true);

    try {
      if (targetStation.approvalStatus != ApprovalStatus.approved) {
        throw Exception('Operation Blocked: Station "${targetStation.stationId}" is REJECTED or Pending. Data upload is strictly restricted to Active Approved Stations only.');
      }

      final lines = _uploadedCsvContent!.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        throw Exception('CSV file is empty!');
      }

      // 1. Identify Columns from Header
      final headerCols = lines[0].split(',').map((c) => c.trim().replaceAll('"', '').toLowerCase()).toList();

      int stnIdIdx = headerCols.indexWhere((c) => c.contains('station') || c.contains('device') || (c.contains('id') && !c.contains('date')));
      int instTypeIdx = headerCols.indexWhere((c) => c.contains('instrument') || (c.contains('type') && !c.contains('boundary')));
      int dateIdx = headerCols.indexWhere((c) => c.contains('date'));
      int timeIdx = headerCols.indexWhere((c) => c.contains('time'));
      int rainIdx = headerCols.indexWhere((c) => c.contains('rain'));
      int maxTempIdx = headerCols.indexWhere((c) => c.contains('max') || (c.contains('temp') && !c.contains('min')));
      int minTempIdx = headerCols.indexWhere((c) => c.contains('min'));
      int humIdx = headerCols.indexWhere((c) => c.contains('hum'));
      int riverIdx = headerCols.indexWhere((c) => c.contains('river') || c.contains('level'));

      // 2. Instrument Type Validation Check
      bool hasRain = rainIdx != -1;
      bool hasTemp = maxTempIdx != -1 || minTempIdx != -1;
      bool hasRiver = riverIdx != -1;

      // Check if CSV data matches target station instrument type
      if (targetStation.instrumentType == InstrumentType.rainGauge) {
        if (hasRiver || (hasTemp && !hasRain)) {
          throw Exception('Instrument Mismatch Error: Station "${targetStation.stationId}" is registered as a Rain Gauge. CSV contains River Level or Temperature columns!');
        }
      } else if (targetStation.instrumentType == InstrumentType.riverGauge) {
        if (hasRain || hasTemp) {
          throw Exception('Instrument Mismatch Error: Station "${targetStation.stationId}" is registered as a River Gauge. CSV contains Rainfall or Temperature columns!');
        }
      } else if (targetStation.instrumentType == InstrumentType.maxMinThermometer) {
        if (hasRain || hasRiver) {
          throw Exception('Instrument Mismatch Error: Station "${targetStation.stationId}" is registered as a Thermometer. CSV contains Rainfall or River Level columns!');
        }
      } else if (targetStation.instrumentType == InstrumentType.hygrometer) {
        if (hasRain || hasRiver || hasTemp) {
          throw Exception('Instrument Mismatch Error: Station "${targetStation.stationId}" is registered as a Hygrometer. CSV contains mismatched parameter data!');
        }
      }

      final Map<String, KsdmaObservation> dailyObsMap = {};
      int lineNo = 1;

      for (int i = 1; i < lines.length; i++) {
        lineNo = i + 1;
        final rawLine = lines[i].trim();
        if (rawLine.isEmpty) continue;

        final row = rawLine.split(',').map((c) => c.trim().replaceAll('"', '')).toList();

        // 1. Station ID Mismatch Check (If CSV contains Station/Device ID column)
        if (stnIdIdx != -1 && stnIdIdx < row.length) {
          final rowStnId = row[stnIdIdx].trim();
          if (rowStnId.isNotEmpty && rowStnId.toLowerCase() != targetStation.stationId.toLowerCase()) {
            throw Exception('Station Mismatch Error (Row $lineNo): CSV row contains Station ID "$rowStnId", but you selected "${targetStation.stationId}" in the dropdown! Please select the matching station or update your CSV.');
          }
        }

        // 2. Instrument Type Mismatch Check (If CSV contains Instrument Type column)
        if (instTypeIdx != -1 && instTypeIdx < row.length) {
          final rowInstType = row[instTypeIdx].trim().toLowerCase();
          if (rowInstType.isNotEmpty) {
            final targetTypeStr = targetStation.instrumentType.displayName.toLowerCase();
            if (!targetTypeStr.contains(rowInstType) && !rowInstType.contains(targetTypeStr.split(' ')[0])) {
              throw Exception('Instrument Mismatch Error (Row $lineNo): CSV row specifies Instrument "$rowInstType", but target station "${targetStation.stationId}" is registered as "${targetStation.instrumentType.displayName}"!');
            }
          }
        }

        // Extract Date
        String dateStr = dateIdx != -1 && dateIdx < row.length ? row[dateIdx] : '';
        DateTime? obsDate;
        if (dateStr.isNotEmpty) {
          try {
            obsDate = DateTime.tryParse(dateStr);
            if (obsDate == null && dateStr.contains('/')) {
              final parts = dateStr.split('/');
              if (parts.length == 3) {
                obsDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              }
            }
          } catch (_) {}
        }
        obsDate ??= DateTime.now();

        final dateKey = "${obsDate.year}-${obsDate.month.toString().padLeft(2, '0')}-${obsDate.day.toString().padLeft(2, '0')}";

        // Extract Time
        String timeStr = timeIdx != -1 && timeIdx < row.length ? row[timeIdx] : '08:00';
        TimeOfDay obsTime = const TimeOfDay(hour: 8, minute: 0);
        if (timeStr.contains(':')) {
          final tParts = timeStr.split(':');
          obsTime = TimeOfDay(hour: int.tryParse(tParts[0]) ?? 8, minute: int.tryParse(tParts[1]) ?? 0);
        }

        // Extract Parameter Values
        double? rainfall = rainIdx != -1 && rainIdx < row.length ? double.tryParse(row[rainIdx]) : null;
        double? maxTemp = maxTempIdx != -1 && maxTempIdx < row.length ? double.tryParse(row[maxTempIdx]) : null;
        double? minTemp = minTempIdx != -1 && minTempIdx < row.length ? double.tryParse(row[minTempIdx]) : null;
        double? humidity = humIdx != -1 && humIdx < row.length ? double.tryParse(row[humIdx]) : null;
        double? riverLevel = riverIdx != -1 && riverIdx < row.length ? double.tryParse(row[riverIdx]) : null;

        // Sanity Range Checks
        if (rainfall != null && (rainfall < 0.0 || rainfall > 500.0)) {
          throw Exception('Data Sanity Error (Row $lineNo): Rainfall value ($rainfall mm) is unrealistic! Allowed range: 0 to 500 mm.');
        }
        if (maxTemp != null && (maxTemp < 5.0 || maxTemp > 50.0)) {
          throw Exception('Data Sanity Error (Row $lineNo): Max Temperature ($maxTemp °C) is unrealistic! Must be between 5°C and 50°C.');
        }
        if (minTemp != null && (minTemp < 5.0 || minTemp > 50.0)) {
          throw Exception('Data Sanity Error (Row $lineNo): Min Temperature ($minTemp °C) is unrealistic! Must be between 5°C and 50°C.');
        }
        if (humidity != null && (humidity < 0.0 || humidity > 100.0)) {
          throw Exception('Data Sanity Error (Row $lineNo): Humidity ($humidity %) is invalid! Must be between 0% and 100%.');
        }
        if (riverLevel != null && (riverLevel < 0.0 || riverLevel > 100.0)) {
          throw Exception('Data Sanity Error (Row $lineNo): River Level ($riverLevel m) is unrealistic! Must be between 0 and 100 m.');
        }

        // Instrument Field Guard: Clear mismatched non-null values if present in unexpected columns
        if (targetStation.instrumentType == InstrumentType.rainGauge) {
          riverLevel = null; maxTemp = null; minTemp = null; humidity = null;
        } else if (targetStation.instrumentType == InstrumentType.riverGauge) {
          rainfall = null; maxTemp = null; minTemp = null; humidity = null;
        } else if (targetStation.instrumentType == InstrumentType.maxMinThermometer) {
          rainfall = null; riverLevel = null; humidity = null;
        } else if (targetStation.instrumentType == InstrumentType.hygrometer) {
          rainfall = null; riverLevel = null; maxTemp = null; minTemp = null;
        }

        final obs = KsdmaObservation(
          observationId: 'OBS_${targetStation.stationId}_${obsDate.year}_${obsDate.month}_${obsDate.day}',
          stationId: targetStation.stationId,
          submittedByUserId: targetStation.ownerUserId,
          observationDate: obsDate,
          observationTime: obsTime,
          submissionTimestamp: DateTime(obsDate.year, obsDate.month, obsDate.day, obsTime.hour, obsTime.minute),
          rainfallMm: rainfall,
          maxTemperatureC: maxTemp,
          minTemperatureC: minTemp,
          humidityPercent: humidity,
          riverWaterLevelM: riverLevel,
          source: 'BULK_CSV_UPLOAD',
        );

        // One Observation Per Day Check: Overwrites duplicate same-day rows with the latest valid row
        dailyObsMap[dateKey] = obs;
      }

      if (dailyObsMap.isEmpty) {
        throw Exception('No valid data rows found in CSV!');
      }

      int count = 0;
      for (var obs in dailyObsMap.values) {
        state.submitObservation(
          stationId: obs.stationId,
          rainfallMm: obs.rainfallMm,
          maxTempC: obs.maxTemperatureC,
          minTempC: obs.minTemperatureC,
          riverLevelM: obs.riverWaterLevelM,
          humidityPercent: obs.humidityPercent,
        );
        await state.apiService.submitObservation(obs);
        count++;
      }

      setState(() {
        _selectedFileName = null;
        _uploadedCsvContent = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Bulk Upload Successful! $count unique daily observation records saved to database for station ${targetStation.stationId}.'),
          backgroundColor: const Color(0xFF15803D),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      final errClean = e.toString().replaceAll('Exception:', '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errClean),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      setState(() => _isProcessingUpload = false);
    }
  }

  Widget _buildDataModerationCard(KsdmaStateService state) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yestStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));

    final activeObs = state.observations.where((o) {
      if (o.isRemoved) return false;

      // Do NOT show read-only automated WS (AWS) hardware sensors in the edit/flag dropdown
      if (o.stationId.toUpperCase().startsWith('WS') || o.source.toUpperCase().contains('AWS')) {
        return false;
      }

      if (_selectedModerationDateRange == 'Today') {
        return !o.observationDate.isBefore(todayStart);
      } else if (_selectedModerationDateRange == 'Yesterday') {
        return o.observationDate.isAfter(yestStart.subtract(const Duration(seconds: 1))) && o.observationDate.isBefore(todayStart);
      } else if (_selectedModerationDateRange == 'Past 7 Days') {
        return !o.observationDate.isBefore(sevenDaysAgo);
      }
      return true; // All Dates
    }).toList();

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Flag an observation',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            const Text('Filter by Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedModerationDateRange,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'Today', child: Text('Today\'s Observations Only')),
                DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday\'s Observations')),
                DropdownMenuItem(value: 'Past 7 Days', child: Text('Past 7 Days Observations')),
                DropdownMenuItem(value: 'All Dates', child: Text('All Historical Dates (Full DB)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedModerationDateRange = val;
                    _selectedObsId = null;
                  });
                }
              },
            ),

            const SizedBox(height: 12),

            const Text('Select Target Reading / Station', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: activeObs.any((o) => o.observationId == _selectedObsId)
                  ? _selectedObsId
                  : (activeObs.isNotEmpty ? activeObs.first.observationId : null),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: activeObs.isEmpty
                  ? [const DropdownMenuItem(value: null, child: Text('No active observations for selected date'))]
                  : activeObs.map((o) {
                      String valText = 'Observation';
                      if (o.rainfallMm != null) valText = '${o.rainfallMm} mm (Rain)';
                      else if (o.maxTemperatureC != null) valText = '${o.maxTemperatureC}°C (Temp)';
                      else if (o.humidityPercent != null) valText = '${o.humidityPercent}% (Humid)';
                      else if (o.riverWaterLevelM != null) valText = '${o.riverWaterLevelM}m (River)';
                      return DropdownMenuItem(
                        value: o.observationId,
                        child: Text('${o.stationId} • $valText', style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                      );
                    }).toList(),
              onChanged: (val) => setState(() => _selectedObsId = val),
            ),

            const SizedBox(height: 12),

            const Text('Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155))),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedModerationReason,
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF146356))),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: const [
                DropdownMenuItem(value: 'Outlier', child: Text('Outlier Reading (Unrealistic Spike)')),
                DropdownMenuItem(value: 'Duplicate', child: Text('Duplicate Entry')),
                DropdownMenuItem(value: 'Sensor Malfunction', child: Text('Sensor Malfunction')),
                DropdownMenuItem(value: 'Wrong Unit', child: Text('Wrong Unit Entered')),
              ],
              onChanged: (val) => setState(() => _selectedModerationReason = val!),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: OutlinedButton(
                onPressed: () {
                  final targetId = _selectedObsId ?? (activeObs.isNotEmpty ? activeObs.first.observationId : null);
                  if (targetId != null) {
                    state.removeObservation(targetId, _selectedModerationReason);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Flagged & Removed observation $targetId (${_selectedModerationReason})')),
                    );
                    setState(() => _selectedObsId = null);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No active observations available to flag.')),
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F172A),
                  side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Remove observation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
