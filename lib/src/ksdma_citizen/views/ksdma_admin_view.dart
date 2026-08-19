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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<KsdmaStateService>(context, listen: false).fetchStationsIfNeeded();
    });
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
                    _buildTopStatCard('${state.stations.length}', 'Total Stations', const Color(0xFF2563EB), Icons.sensors, constraints.maxWidth),
                    _buildTopStatCard('$activeObsCount', 'Today\'s Observations', const Color(0xFF059669), Icons.assignment_turned_in, constraints.maxWidth),
                    _buildTopStatCard('Good', 'Data Quality', const Color(0xFF0D9488), Icons.verified, constraints.maxWidth),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: _buildTopStatCard('${pending.length}', 'Pending Registrations', const Color(0xFFD97706), Icons.hourglass_top, 0)),
                    const SizedBox(width: 14),
                    Expanded(child: _buildTopStatCard('${state.stations.length}', 'Total Stations', const Color(0xFF2563EB), Icons.sensors, 0)),
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

  Widget _buildTopStatCard(String value, String label, Color accentColor, IconData icon, double maxWidth) {
    return Container(
      width: maxWidth > 0 ? (maxWidth - 52) / 2 : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRegistrationsCard(KsdmaStateService state, List<KsdmaStation> pending) {
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
            const Text(
              'Pending device registrations',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),

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
                  rows: pending.map((station) {
                    final submittedDateStr = '07 Aug';
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
              'Bulk upload (WhatsApp readings)',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),

            // Dashed Drag & Drop Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
              ),
              child: const Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF64748B)),
                  SizedBox(height: 8),
                  Text(
                    'Drop Excel/CSV or tap to choose file',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () {
                  final count = state.bulkUploadObservations([
                    {'stationId': 'RG-2345', 'rainfallMm': 28.5},
                    {'stationId': 'TM-1002', 'maxTempC': 33.0, 'minTempC': 25.0},
                  ]);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Bulk Upload Successful! $count Observation records imported.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Upload', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataModerationCard(KsdmaStateService state) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yestStart = todayStart.subtract(const Duration(days: 1));
    final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));

    final activeObs = state.observations.where((o) {
      if (o.isRemoved) return false;

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
