import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaObservationEntryView extends StatefulWidget {
  final String stationId;
  final VoidCallback onSubmitted;

  const KsdmaObservationEntryView({
    super.key,
    required this.stationId,
    required this.onSubmitted,
  });

  @override
  State<KsdmaObservationEntryView> createState() => _KsdmaObservationEntryViewState();
}

class _KsdmaObservationEntryViewState extends State<KsdmaObservationEntryView> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _rainfallCtrl = TextEditingController();
  final TextEditingController _maxTempCtrl = TextEditingController();
  final TextEditingController _minTempCtrl = TextEditingController();
  final TextEditingController _riverLevelCtrl = TextEditingController();
  final TextEditingController _humidityCtrl = TextEditingController();

  TimeOfDay _observationTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    final state = Provider.of<KsdmaStateService>(context, listen: false);
    final todayObs = state.getTodayObservation(widget.stationId);
    if (todayObs != null) {
      if (todayObs.rainfallMm != null) _rainfallCtrl.text = todayObs.rainfallMm.toString();
      if (todayObs.maxTemperatureC != null) _maxTempCtrl.text = todayObs.maxTemperatureC.toString();
      if (todayObs.minTemperatureC != null) _minTempCtrl.text = todayObs.minTemperatureC.toString();
      if (todayObs.riverWaterLevelM != null) _riverLevelCtrl.text = todayObs.riverWaterLevelM.toString();
      if (todayObs.humidityPercent != null) _humidityCtrl.text = todayObs.humidityPercent.toString();
      _observationTime = todayObs.observationTime;
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      final state = Provider.of<KsdmaStateService>(context, listen: false);
      final station = state.stations.firstWhere((s) => s.stationId == widget.stationId);

      if (station.approvalStatus != ApprovalStatus.approved) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔒 Station Pending Approval - You cannot enter observation data until KSDMA Admin HQ approves this instrument.'),
            backgroundColor: Colors.amber,
          ),
        );
        return;
      }

      // Mandatory validation check
      if (station.instrumentType == InstrumentType.rainGauge && _rainfallCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Rainfall (mm) reading is mandatory! Please enter the observed value.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      if (station.instrumentType == InstrumentType.maxMinThermometer && (_maxTempCtrl.text.trim().isEmpty || _minTempCtrl.text.trim().isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Maximum & Minimum Temperature (°C) values are mandatory!'), backgroundColor: Colors.redAccent),
        );
        return;
      }
      if (station.instrumentType == InstrumentType.riverGauge && _riverLevelCtrl.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ River Water Level (m) is mandatory! Please enter the observed stage.'), backgroundColor: Colors.redAccent),
        );
        return;
      }

      double? rainfall = station.instrumentType == InstrumentType.rainGauge ? double.tryParse(_rainfallCtrl.text) : null;
      double? maxTemp = station.instrumentType == InstrumentType.maxMinThermometer ? double.tryParse(_maxTempCtrl.text) : null;
      double? minTemp = station.instrumentType == InstrumentType.maxMinThermometer ? double.tryParse(_minTempCtrl.text) : null;
      double? riverLevel = station.instrumentType == InstrumentType.riverGauge ? double.tryParse(_riverLevelCtrl.text) : null;
      double? humidity = (station.instrumentType == InstrumentType.hygrometer || _humidityCtrl.text.isNotEmpty) ? double.tryParse(_humidityCtrl.text) : null;

      try {
        state.submitObservation(
          stationId: widget.stationId,
          rainfallMm: rainfall,
          maxTempC: maxTemp,
          minTempC: minTemp,
          riverLevelM: riverLevel,
          humidityPercent: humidity,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Observation Data Submitted Successfully & Published Live on Dashboard!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSubmitted();
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: const [
                Icon(Icons.lock_clock, color: Colors.red),
                SizedBox(width: 8),
                Text('Edit Window Closed'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);
    final station = state.stations.firstWhere(
      (s) => s.stationId == widget.stationId,
      orElse: () => state.stations.first,
    );

    final isRainfall = station.instrumentType == InstrumentType.rainGauge;
    final isEditWindowOpen = state.isRainfallEditWindowOpen();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          padding: const EdgeInsets.all(28.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Data Entry Screen - ${station.instrumentType.displayName}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Station ID: ${station.stationId} • Location: ${station.district}, ${station.gramaPanchayat}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onSubmitted,
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Strict 8 AM - 9 AM Time Window Notice for Rainfall
                if (isRainfall)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isEditWindowOpen ? Colors.green.shade50 : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isEditWindowOpen ? Colors.green : Colors.amber),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isEditWindowOpen ? Icons.access_time_filled : Icons.error_outline,
                          color: isEditWindowOpen ? Colors.green.shade800 : Colors.amber.shade900,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditWindowOpen
                                    ? 'Rainfall Observation Edit Window OPEN (8:00 AM - 9:00 AM IST)'
                                    : 'Rainfall Edit Window (8:00 AM - 9:00 AM IST Rule)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isEditWindowOpen ? Colors.green.shade900 : Colors.amber.shade900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isEditWindowOpen
                                    ? 'You can record or update today\'s rainfall observation.'
                                    : 'As per IMD protocol, rainfall editing is permitted between 8:00 AM and 9:00 AM. After 9:00 AM, data for today is locked.',
                                style: const TextStyle(fontSize: 11, color: Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Time of Observation Selector
                Row(
                  children: [
                    const Icon(Icons.schedule, color: Color(0xFF0288D1)),
                    const SizedBox(width: 10),
                    const Text('Standard Observation Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Chip(
                      avatar: const Icon(Icons.access_time, size: 14),
                      label: Text(_observationTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: const Color(0xFFE3F2FD),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dynamic Parameter Form Fields based on Instrument Type
                const Text(
                  'Weather Parameter Input Fields:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0288D1)),
                ),
                const SizedBox(height: 12),

                if (station.instrumentType == InstrumentType.rainGauge) ...[
                  TextFormField(
                    controller: _rainfallCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Rainfall Amount (in mm) *',
                      suffixText: 'mm',
                      prefixIcon: Icon(Icons.water_drop, color: Color(0xFF1E88E5)),
                      border: OutlineInputBorder(),
                      helperText: 'Fixed Unit: millimeters (mm)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < 0 || val > 1000) return 'Enter valid rainfall (0 - 1000 mm)';
                      return null;
                    },
                  ),
                ] else if (station.instrumentType == InstrumentType.maxMinThermometer) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _maxTempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Maximum Temp (°C) *',
                            suffixText: '°C',
                            prefixIcon: Icon(Icons.thermostat, color: Colors.red),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final val = double.tryParse(v);
                            if (val == null || val < 10 || val > 55) return 'Invalid °C';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _minTempCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Minimum Temp (°C) *',
                            suffixText: '°C',
                            prefixIcon: Icon(Icons.ac_unit, color: Colors.blue),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final val = double.tryParse(v);
                            if (val == null || val < 0 || val > 40) return 'Invalid °C';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ] else if (station.instrumentType == InstrumentType.riverGauge) ...[
                  TextFormField(
                    controller: _riverLevelCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'River Water Level (in metres) *',
                      suffixText: 'metres',
                      prefixIcon: Icon(Icons.waves, color: Color(0xFF00ACC1)),
                      border: OutlineInputBorder(),
                      helperText: 'Fixed Unit: metres (m)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < -5 || val > 50) return 'Enter valid level (-5 to 50 m)';
                      return null;
                    },
                  ),
                ] else if (station.instrumentType == InstrumentType.hygrometer) ...[
                  TextFormField(
                    controller: _humidityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Relative Humidity (%) *',
                      suffixText: '%',
                      prefixIcon: Icon(Icons.opacity, color: Color(0xFF8E24AA)),
                      border: OutlineInputBorder(),
                      helperText: 'Fixed Unit: percentage (%)',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      final val = double.tryParse(v);
                      if (val == null || val < 0 || val > 100) return 'Enter valid humidity (0 - 100%)';
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _submitData,
                    icon: const Icon(Icons.cloud_upload, color: Colors.white),
                    label: const Text(
                      'SUBMIT OBSERVATION DATA',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
    );
  }
}
