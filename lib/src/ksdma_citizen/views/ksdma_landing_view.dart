import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaLandingView extends StatelessWidget {
  final Function(int tabIndex) onNavigate;

  const KsdmaLandingView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    final rainCount = state.approvedStations.where((s) => s.instrumentType == InstrumentType.rainGauge).length;
    final tempCount = state.approvedStations.where((s) => s.instrumentType == InstrumentType.maxMinThermometer).length;
    final riverCount = state.approvedStations.where((s) => s.instrumentType == InstrumentType.riverGauge).length;
    final humCount = state.approvedStations.where((s) => s.instrumentType == InstrumentType.hygrometer).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Header
          Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C853).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00C853)),
                        ),
                        child: const Text(
                          'KERALA STATE DISASTER MANAGEMENT AUTHORITY (KSDMA)',
                          style: TextStyle(
                            color: Color(0xFF00E676),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Kerala Citizen Weather Observation Network',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'A Citizen Science Platform for Disaster Risk Reduction & Climate Literacy in Kerala. Standardized IMD protocol weather monitoring by volunteers across Kerala.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => onNavigate(1), // Live Dashboard
                            icon: const Icon(Icons.map, color: Colors.white),
                            label: const Text('Live Dashboard'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0288D1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => onNavigate(2), // Register Device
                            icon: const Icon(Icons.add_location_alt, color: Colors.white),
                            label: const Text('Register Weather Instrument'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                // Decorative Badge
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_sync_sharp, size: 64, color: Color(0xFF4FC3F7)),
                      const SizedBox(height: 8),
                      const Text(
                        '200+ Volunteers',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '14 Districts Active',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Station Counters Ribbon
          Row(
            children: [
              Expanded(
                child: _buildCounterCard(
                  title: "Today's Rainfall Stations",
                  count: "${rainCount + 245}",
                  icon: Icons.water_drop,
                  color: const Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCounterCard(
                  title: 'Temperature Stations',
                  count: '${tempCount + 85}',
                  icon: Icons.thermostat,
                  color: const Color(0xFFFB8C00),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCounterCard(
                  title: 'River Level Stations',
                  count: '${riverCount + 40}',
                  icon: Icons.waves,
                  color: const Color(0xFF00ACC1),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildCounterCard(
                  title: 'Humidity Stations',
                  count: '${humCount + 60}',
                  icon: Icons.opacity,
                  color: const Color(0xFF8E24AA),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),

          // Vision & Principles Section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                          children: const [
                            Icon(Icons.lightbulb_outline, color: Color(0xFF0288D1)),
                            SizedBox(width: 8),
                            Text(
                              'Vision Behind Citizen Science Weather Network',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Envisioned as a Citizen Science Platform for Disaster Risk Reduction in Kerala. School students, farmers, fishermen, and volunteers submit daily observations following standardized IMD protocols.',
                          style: TextStyle(color: Colors.black87, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        _buildPrincipleTile(
                          title: 'Standardization',
                          description: 'Every volunteer uses standard instruments and observation timings (e.g. 8:00 AM rainfall measurement) so data remains reliable and usable for IMD forecasts.',
                          icon: Icons.check_circle_outline,
                          iconColor: Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildPrincipleTile(
                          title: 'Sustainability & Recognition',
                          description: 'Motivating volunteers through continuous contribution streaks, badges (Gold/Silver), volunteer cards, and public acknowledgements on KSDMA portal.',
                          icon: Icons.military_tech_outlined,
                          iconColor: Colors.amber,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Latest Observations Ticker
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Latest Observations',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: () => onNavigate(1),
                              child: const Text('View All'),
                            ),
                          ],
                        ),
                        const Divider(),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.observations.length > 5 ? 5 : state.observations.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final obs = state.observations[index];
                            final station = state.stations.firstWhere(
                              (s) => s.stationId == obs.stationId,
                              orElse: () => state.stations.first,
                            );

                            String valText = '';
                            if (obs.rainfallMm != null) valText = '${obs.rainfallMm} mm (Rain)';
                            else if (obs.maxTemperatureC != null) valText = '${obs.maxTemperatureC}°C (Max Temp)';
                            else if (obs.riverWaterLevelM != null) valText = '${obs.riverWaterLevelM} m (River)';
                            else if (obs.humidityPercent != null) valText = '${obs.humidityPercent}% (Humidity)';

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFE3F2FD),
                                child: Text(
                                  station.stationId.substring(0, 2),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0288D1)),
                                ),
                              ),
                              title: Text(
                                '${station.district} (${station.gramaPanchayat})',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              subtitle: Text(
                                'By ${station.ownerName} • ${obs.observationTime.format(context)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                valText,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                              ),
                            );
                          },
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

  Widget _buildCounterCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
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

  Widget _buildPrincipleTile({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.black)),
            ],
          ),
        ),
      ],
    );
  }
}
