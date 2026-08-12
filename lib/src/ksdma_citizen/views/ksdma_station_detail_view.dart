import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaStationDetailView extends StatefulWidget {
  final String? stationId;

  const KsdmaStationDetailView({super.key, this.stationId});

  @override
  State<KsdmaStationDetailView> createState() => _KsdmaStationDetailViewState();
}

class _KsdmaStationDetailViewState extends State<KsdmaStationDetailView> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final KsdmaStation? targetStation = state.stations.firstWhere(
      (s) => s.stationId == widget.stationId,
      orElse: () => state.approvedStations.isNotEmpty
          ? state.approvedStations.first
          : state.stations.isNotEmpty
              ? state.stations.first
              : KsdmaStation(
                  stationId: 'NO_STATION',
                  ownerUserId: 'N/A',
                  ownerName: 'No Active Station',
                  ownerCategory: UserCategory.schoolStudent,
                  category: StationCategory.manual,
                  instrumentType: InstrumentType.rainGauge,
                  deviceMake: 'Standard Instrument',
                  measurementLocation: 'Site',
                  devicePhotoUrl: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                  latitude: 10.8505,
                  longitude: 76.2711,
                  district: 'Kozhikode',
                  taluk: 'Koyilandy',
                  gramaPanchayat: 'Kunnamangalam',
                  village: 'Kunnamangalam',
                  approvalStatus: ApprovalStatus.approved,
                  createdAt: DateTime.now(),
                ),
    );

    final stationObs = state.observations.where((o) => o.stationId == targetStation?.stationId && !o.isRemoved).toList();
    final latestObs = stationObs.isNotEmpty ? stationObs.last : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumbs
          Row(
            children: [
              const Text('Home > Stations > ', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(targetStation!.stationId, style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),

          // Top Hero Card (100% Dynamic from DB)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Image
                    GestureDetector(
                      onTap: () {
                        if (targetStation.devicePhotoUrl == null || targetStation.devicePhotoUrl!.isEmpty) return;
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
                                      targetStation.devicePhotoUrl!,
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
                      },
                      child: Tooltip(
                        message: '🔍 Click to Zoom Photo',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 140,
                                height: 160,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  image: DecorationImage(
                                    image: NetworkImage(targetStation.devicePhotoUrl!),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                child: const Icon(Icons.zoom_in, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 16),

                  // Device Information Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              targetStation.stationId,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: targetStation.approvalStatus == ApprovalStatus.approved ? const Color(0xFFDCFCE7) : Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                targetStation.approvalStatus == ApprovalStatus.approved ? 'Active' : 'Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: targetStation.approvalStatus == ApprovalStatus.approved ? const Color(0xFF15803D) : Colors.amber.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${targetStation.instrumentType.displayName} (${targetStation.deviceMake})',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.place_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${targetStation.district}, ${targetStation.gramaPanchayat}, Kerala', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.explore_outlined, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text('${targetStation.latitude}° N, ${targetStation.longitude}° E', style: const TextStyle(fontSize: 11, color: Colors.black87)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildInfoPair('Owner', targetStation.ownerName),
                        _buildInfoPair('Installed On', '${targetStation.createdAt.day}/${targetStation.createdAt.month}/${targetStation.createdAt.year}'),
                        _buildInfoPair('Location', targetStation.measurementLocation),
                      ],
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Today's Observation Card (Right Side)
                  Container(
                    width: 160,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Latest Observation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF1E293B))),
                        const SizedBox(height: 10),
                        _buildReadingVal(latestObs != null ? '${latestObs.rainfallMm ?? 0.0} mm' : '0.0 mm', 'Rainfall'),
                        const SizedBox(height: 8),
                        _buildReadingVal(latestObs != null ? '${latestObs.maxTemperatureC ?? 0.0} °C' : '0.0 °C', 'Max Temp'),
                        const SizedBox(height: 8),
                        _buildReadingVal(latestObs != null ? '${latestObs.humidityPercent ?? 0.0} %' : '0 %', 'Humidity', color: const Color(0xFF16A34A)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Daily Data Table Card
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Observation History (${stationObs.length} Records)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const Divider(height: 16),

                  if (stationObs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20.0),
                      child: Center(child: Text('No daily observation entries recorded for this station yet.', style: TextStyle(fontSize: 12, color: Colors.grey))),
                    )
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2),
                        1: FlexColumnWidth(2),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF8FAFC)),
                          children: [
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Date ↕', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Rainfall (mm)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Max Temp (°C)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                            Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Humidity (%)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF64748B)))),
                          ],
                        ),
                        ...stationObs.map((o) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${o.observationDate.year}-${o.observationDate.month.toString().padLeft(2, '0')}-${o.observationDate.day.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${o.rainfallMm ?? 0.0} mm', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${o.maxTemperatureC ?? 0.0} °C', style: const TextStyle(fontSize: 11))),
                              Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('${o.humidityPercent ?? 0.0} %', style: const TextStyle(fontSize: 11, color: Colors.green))),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPair(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey))),
          Text(value, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildReadingVal(String val, String label, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color ?? const Color(0xFF1E293B))),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
