import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaOfficerView extends StatefulWidget {
  const KsdmaOfficerView({super.key});

  @override
  State<KsdmaOfficerView> createState() => _KsdmaOfficerViewState();
}

class _KsdmaOfficerViewState extends State<KsdmaOfficerView> {
  String _exportParameter = 'Rainfall';
  String _exportDistrict = 'All Districts';
  String _exportFormat = 'CSV';

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield, color: Colors.amber, size: 40),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Officer Decision Support Dashboard',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'State-level Disaster Management Overview & High-Density Rain Spotters',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top 20 Highest Rainfall Table
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              'Top High-Intensity Rainfall Stations Today',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Icon(Icons.water_drop, color: Color(0xFF1565C0)),
                          ],
                        ),
                        const Divider(height: 20),

                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Station ID', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('District', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Today (mm)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Yesterday (mm)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Change (Δ)', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('5-Day Total', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: state.approvedStations.map((s) {
                              final todayObs = state.getTodayObservation(s.stationId);
                              final yestObs = state.getYesterdayObservation(s.stationId);

                              double todayVal = todayObs?.rainfallMm ?? 0.0;
                              double yestVal = yestObs?.rainfallMm ?? 0.0;
                              double delta = todayVal - yestVal;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        Icon(
                                          s.category == StationCategory.aws ? Icons.cell_tower : Icons.person_pin,
                                          size: 16,
                                          color: s.category == StationCategory.aws ? Colors.purple : Colors.blue,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(s.stationId, style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(s.district)),
                                  DataCell(Text(todayVal > 0 ? '$todayVal mm' : '0.0 mm', style: TextStyle(fontWeight: FontWeight.bold, color: todayVal > 0 ? const Color(0xFF1565C0) : Colors.grey))),
                                  DataCell(Text(yestVal > 0 ? '$yestVal mm' : '0.0 mm')),
                                  DataCell(
                                    Text(
                                      '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)} mm',
                                      style: TextStyle(color: delta > 0 ? Colors.red : delta < 0 ? Colors.green : Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(Text('${(todayVal + yestVal).toStringAsFixed(1)} mm')),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // CSV / Excel Dataset Download Panel
              Expanded(
                flex: 2,
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.download_for_offline, color: Color(0xFF0288D1)),
                            SizedBox(width: 8),
                            Text(
                              'Download Official Dataset',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 20),

                        const Text('Select Parameter:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _exportParameter,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Rainfall', child: Text('Rainfall Observations')),
                            DropdownMenuItem(value: 'Temperature', child: Text('Temperature Readings')),
                            DropdownMenuItem(value: 'RiverLevel', child: Text('River Water Levels')),
                            DropdownMenuItem(value: 'Humidity', child: Text('Humidity Logs')),
                          ],
                          onChanged: (val) => setState(() => _exportParameter = val!),
                        ),

                        const SizedBox(height: 14),

                        const Text('Select Geographical Region:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _exportDistrict,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'All Districts', child: Text('All 14 Districts (Statewide)')),
                            DropdownMenuItem(value: 'Kannur', child: Text('Kannur District')),
                            DropdownMenuItem(value: 'Kozhikode', child: Text('Kozhikode District')),
                            DropdownMenuItem(value: 'Wayanad', child: Text('Wayanad District')),
                            DropdownMenuItem(value: 'Ernakulam', child: Text('Ernakulam District')),
                          ],
                          onChanged: (val) => setState(() => _exportDistrict = val!),
                        ),

                        const SizedBox(height: 14),

                        const Text('Format:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('CSV Format'),
                                selected: _exportFormat == 'CSV',
                                onSelected: (sel) => setState(() => _exportFormat = 'CSV'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ChoiceChip(
                                label: const Text('Excel (.xlsx)'),
                                selected: _exportFormat == 'Excel',
                                onSelected: (sel) => setState(() => _exportFormat = 'Excel'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Generating $_exportFormat Dataset for $_exportParameter ($_exportDistrict)...'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            icon: const Icon(Icons.file_download, color: Colors.white),
                            label: Text(
                              'GENERATE & DOWNLOAD $_exportFormat',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
