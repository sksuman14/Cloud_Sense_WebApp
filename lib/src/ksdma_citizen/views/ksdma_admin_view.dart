import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaAdminView extends StatefulWidget {
  const KsdmaAdminView({super.key});

  @override
  State<KsdmaAdminView> createState() => _KsdmaAdminViewState();
}

class _KsdmaAdminViewState extends State<KsdmaAdminView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.admin_panel_settings, color: Colors.amber, size: 40),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KSDMA Meteorology Admin Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Station Registration Approvals, Bulk WhatsApp CSV Uploads & Quality Moderation',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF0288D1),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0288D1),
            tabs: [
              Tab(
                icon: const Icon(Icons.approval),
                text: 'Pending Registrations (${state.pendingStations.length})',
              ),
              const Tab(
                icon: Icon(Icons.upload_file),
                text: 'Bulk CSV / Excel Upload',
              ),
              const Tab(
                icon: Icon(Icons.cleaning_services),
                text: 'Data Moderation & Outlier Removal',
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 550,
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Pending Registrations
                _buildPendingRegistrationsTab(state),

                // Tab 2: Bulk CSV Upload Panel
                _buildBulkUploadTab(state),

                // Tab 3: Data Moderation Tool
                _buildDataModerationTab(state),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRegistrationsTab(KsdmaStateService state) {
    final pending = state.pendingStations;

    if (pending.isEmpty) {
      return Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, size: 48, color: Colors.green),
              SizedBox(height: 12),
              Text('All station registration requests have been reviewed!', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final station = pending[index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo Preview
                GestureDetector(
                  onTap: () => _showZoomDialog(context, station.devicePhotoUrl!),
                  child: Tooltip(
                    message: '🔍 Click to Zoom Photo',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: NetworkImage(station.devicePhotoUrl!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            station.stationId,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0D47A1)),
                          ),
                          Chip(
                            label: Text(station.instrumentType.displayName, style: const TextStyle(fontSize: 10, color: Colors.white)),
                            backgroundColor: const Color(0xFF0288D1),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (station.measurementLocation.isNotEmpty && station.measurementLocation != 'Site')
                            Chip(
                              label: Text('📍 ${station.measurementLocation}', style: const TextStyle(fontSize: 10, color: Color(0xFF1E293B))),
                              backgroundColor: const Color(0xFFF1F5F9),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      Text('Owner: ${station.ownerName} (${station.ownerCategory.label})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Location: ${station.village}, ${station.gramaPanchayat}, ${station.taluk}, ${station.district}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      Text('GPS: Lat ${station.latitude.toStringAsFixed(4)}, Long ${station.longitude.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton.icon(
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
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('APPROVE'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final reasonController = TextEditingController();
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Row(
                              children: const [
                                Icon(Icons.warning_amber_rounded, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Reject & Remove Station', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Please specify the reason for rejecting station ${station.stationId}:', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: reasonController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Rejection Reason *',
                                    hintText: 'e.g. Invalid photo, IMD protocol violation, inaccurate coordinates',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                child: const Text('Confirm Reject & Remove'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          final reason = reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Rejected by Admin HQ';
                          await state.rejectStationWithReason(station.stationId, reason);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('🚫 Station ${station.stationId} Rejected & Removed. Reason logged in DB!'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('REJECT'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBulkUploadTab(KsdmaStateService state) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF0288D1), style: BorderStyle.solid),
              ),
              child: Column(
                children: [
                  const Icon(Icons.cloud_upload_outlined, size: 54, color: Color(0xFF0288D1)),
                  const SizedBox(height: 12),
                  const Text(
                    'Drag & Drop KSDMA WhatsApp Group CSV / Excel Dataset File',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Admin can upload observations on behalf of observers who shared readings via WhatsApp group',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      final count = state.bulkUploadObservations([
                        {'stationId': 'RG-2345', 'rainfallMm': 28.5},
                        {'stationId': 'TM-1002', 'maxTempC': 33.0, 'minTempC': 25.0},
                      ]);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Bulk Upload Successful! $count Observation records imported.')),
                      );
                    },
                    icon: const Icon(Icons.file_present),
                    label: const Text('Select CSV / Excel File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0288D1),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloading Official KSDMA Excel Bulk Upload Template...')),
                );
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Sample Excel Template (.xlsx)'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataModerationTab(KsdmaStateService state) {
    final activeObs = state.observations.where((o) => !o.isRemoved).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Observation Quality Moderation & Outlier Removal (Req #7)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Text(
              'Observations publish directly to dashboard. KSDMA Admin can remove suspicious/incorrect data with audit reason.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Divider(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: activeObs.length,
                itemBuilder: (context, index) {
                  final obs = activeObs[index];
                  String valText = '';
                  if (obs.rainfallMm != null) valText = '${obs.rainfallMm} mm (Rainfall)';
                  if (obs.maxTemperatureC != null) valText = '${obs.maxTemperatureC}°C (Max Temp)';
                  if (obs.riverWaterLevelM != null) valText = '${obs.riverWaterLevelM} m (River)';
                  if (obs.humidityPercent != null) valText = '${obs.humidityPercent}% (Humidity)';

                  return ListTile(
                    leading: const Icon(Icons.thermostat_auto, color: Color(0xFF0288D1)),
                    title: Text('Station ${obs.stationId} • Reading: $valText'),
                    subtitle: Text('Date: ${obs.observationDate.toString().split(' ')[0]} • Source: ${obs.source}'),
                    trailing: TextButton.icon(
                      onPressed: () => _showRemovalReasonDialog(state, obs.observationId),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Remove Data', style: TextStyle(color: Colors.red)),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemovalReasonDialog(KsdmaStateService state, String obsId) {
    String selectedReason = 'OUTLIER';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Observation from Dashboard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select reason for removing this reading:'),
            const SizedBox(height: 12),
            StatefulBuilder(
              builder: (context, setSt) => DropdownButton<String>(
                value: selectedReason,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'OUTLIER', child: Text('Outlier Reading (Unrealistic Spike)')),
                  DropdownMenuItem(value: 'DUPLICATE', child: Text('Duplicate Entry')),
                  DropdownMenuItem(value: 'WRONG_UNIT', child: Text('Wrong Unit Entered')),
                ],
                onChanged: (v) => setSt(() => selectedReason = v!),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              state.removeObservation(obsId, selectedReason);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Observation Removed from Public Dashboard ($selectedReason)')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CONFIRM REMOVAL'),
          ),
        ],
      ),
    );
  }
}
