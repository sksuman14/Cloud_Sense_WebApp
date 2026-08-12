import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/ksdma_models.dart';
import '../services/ksdma_state_service.dart';
import 'ksdma_auth_modal.dart';

class KsdmaRegistrationView extends StatefulWidget {
  final VoidCallback? onSuccess;

  const KsdmaRegistrationView({super.key, this.onSuccess});

  @override
  State<KsdmaRegistrationView> createState() => _KsdmaRegistrationViewState();
}

class _KsdmaRegistrationViewState extends State<KsdmaRegistrationView> {
  int _currentStep = 1; // 1: Instrument, 2: Location, 3: Upload, 4: Submit

  InstrumentType _selectedType = InstrumentType.rainGauge;
  late final TextEditingController _nicknameController;
  late final TextEditingController _makeModelController;
  late final TextEditingController _dateController;
  String _ownershipType = 'Personal';
  late final TextEditingController _mobileController;
  late final TextEditingController _emailController;
  bool _confirmedImdProtocol = false;

  // Location Fields (Step 2)
  late final TextEditingController _districtController;
  late final TextEditingController _talukController;
  late final TextEditingController _gpController;
  late final TextEditingController _villageController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;
  final TextEditingController _photoUrlController = TextEditingController(
    text: 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
  );

  String _maskPhone(String phone) {
    final clean = phone.trim();
    if (clean.length > 5) {
      return '${clean.substring(0, clean.length - 4)}XXXX';
    }
    return clean;
  }

  @override
  void initState() {
    super.initState();
    final state = Provider.of<KsdmaStateService>(context, listen: false);
    _nicknameController = TextEditingController();
    _makeModelController = TextEditingController();
    final now = DateTime.now();
    _dateController = TextEditingController(
      text: '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
    );
    final phone = state.currentUser.mobileNumber;
    _mobileController = TextEditingController(text: phone.isNotEmpty ? _maskPhone(phone) : '');
    _emailController = TextEditingController(text: state.currentUser.email);

    _districtController = TextEditingController(text: state.currentUser.district.isNotEmpty ? state.currentUser.district : '');
    _talukController = TextEditingController(text: state.currentUser.taluk.isNotEmpty ? state.currentUser.taluk : '');
    _gpController = TextEditingController(text: state.currentUser.gramaPanchayat.isNotEmpty ? state.currentUser.gramaPanchayat : '');
    _villageController = TextEditingController(text: state.currentUser.village.isNotEmpty ? state.currentUser.village : '');

    _latController = TextEditingController(text: '10.8505');
    _lngController = TextEditingController(text: '76.2711');
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _makeModelController.dispose();
    _dateController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _districtController.dispose();
    _talukController.dispose();
    _gpController.dispose();
    _villageController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _photoUrlController.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<KsdmaStateService>(context);

    // If user is not signed in → prompt for login/registration
    if (!state.isLoggedIn) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF2563EB), size: 32),
              ),
              const SizedBox(height: 20),
              const Text('🙋 Register as Volunteer First', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 10),
              Text(
                'To register a weather instrument station and submit observations, please sign in or register as a Volunteer.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => KsdmaAuthModal.show(context, state),
                  icon: const Icon(Icons.app_registration, color: Colors.white, size: 18),
                  label: const Text('Sign In / Register as Volunteer', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Breadcrumb Header
          Row(
            children: const [
              Text('Home > My Observations > ', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('Enter Observation', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          const Text('Register New Instrument', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 16),

          // 4-Step Wizard Stepper Ribbon (Exact Screenshot 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.black12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepItem(1, 'Instrument Details', _currentStep == 1, _currentStep > 1),
                const Expanded(child: Divider(indent: 10, endIndent: 10)),
                _buildStepItem(2, 'Location Details', _currentStep == 2, _currentStep > 2),
                const Expanded(child: Divider(indent: 10, endIndent: 10)),
                _buildStepItem(3, 'Upload & Review', _currentStep == 3, _currentStep > 3),
                const Expanded(child: Divider(indent: 10, endIndent: 10)),
                _buildStepItem(4, 'Submit', _currentStep == 4, false),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Step 1 Body Form
          if (_currentStep == 1) _buildStep1Form(),
          if (_currentStep == 2) _buildStep2Form(),
          if (_currentStep >= 3) _buildReviewSubmitForm(),
        ],
      ),
    );
  }

  Widget _buildStepItem(int number, String label, bool isActive, bool isDone) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isDone ? const Color(0xFF2563EB) : Colors.grey.shade200,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text('$number', style: TextStyle(color: isActive || isDone ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF1E293B) : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1Form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Instrument Type *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B))),
        const SizedBox(height: 12),

        // 4 Selection Cards Grid (Exact Screenshot 1 Layout)
        Row(
          children: [
            Expanded(child: _buildInstrumentCard(InstrumentType.rainGauge, 'Rain Gauge', Icons.thunderstorm_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildInstrumentCard(InstrumentType.maxMinThermometer, 'Maximum-Minimum Thermometer', Icons.thermostat_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildInstrumentCard(InstrumentType.hygrometer, 'Wet & Dry Bulb Thermometer\n(Psychrometer)', Icons.water_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _buildInstrumentCard(InstrumentType.riverGauge, 'River Level Gauge', Icons.waves_outlined)),
          ],
        ),

        const SizedBox(height: 16),

        // Info Alert Banner (Dynamic according to selected instrument)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_getInstrumentName(_selectedType), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0369A1))),
                    const SizedBox(height: 2),
                    Text(
                      _getInstrumentDesc(_selectedType),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0C4A6E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Form Fields Row 1
        Row(
          children: [
            Expanded(
              child: _buildTextField('Instrument Name / Nickname *', _nicknameController, hint: 'e.g. Terrace Rain Gauge'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('Make / Model ⓘ', _makeModelController, hint: 'e.g. Standard IMD Type'),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Form Fields Row 2
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Installation Date ⓘ',
                _dateController,
                suffixIcon: Icons.calendar_today_outlined,
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      _dateController.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ownership Type ⓘ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: DropdownButton<String>(
                      value: _ownershipType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: ['Personal', 'School / Institution', 'Panchayat', 'NGO'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => _ownershipType = v!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Form Fields Row 3
        Row(
          children: [
            Expanded(
              child: _buildTextField('Mobile Number *', _mobileController, hint: 'e.g. 9876543210'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField('Email (Optional)', _emailController, hint: 'e.g. user@domain.com'),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Checkbox Confirm
        Row(
          children: [
            Checkbox(
              value: _confirmedImdProtocol,
              onChanged: (v) => setState(() => _confirmedImdProtocol = v!),
              activeColor: const Color(0xFF2563EB),
            ),
            const Expanded(
              child: Text('I confirm that I will take observations as per IMD standard methods. *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Full Width Action Button (Next to Step 2 with validation)
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: () {
              if (_nicknameController.text.trim().isEmpty) {
                _showError('⚠️ Instrument Name / Nickname is mandatory!');
                return;
              }
              if (_mobileController.text.trim().isEmpty) {
                _showError('⚠️ Mobile Number is mandatory!');
                return;
              }
              if (!_confirmedImdProtocol) {
                _showError('⚠️ Please check the box to confirm observation protocol!');
                return;
              }
              setState(() => _currentStep = 2);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Next: Location Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Form() {
    final state = Provider.of<KsdmaStateService>(context);
    final districtOptions = state.districtNames;

    if (_districtController.text.isEmpty && districtOptions.isNotEmpty) {
      _districtController.text = districtOptions.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Geographic Location Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('District *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.black26),
                    ),
                    child: DropdownButton<String>(
                      value: districtOptions.contains(_districtController.text) ? _districtController.text : (districtOptions.isNotEmpty ? districtOptions.first : null),
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: districtOptions.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _districtController.text = v);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Taluk *', _talukController, hint: 'Enter Taluk')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField('Grama Panchayat *', _gpController, hint: 'Enter Grama Panchayat')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Village *', _villageController, hint: 'Enter Village')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTextField('Latitude (°N)', _latController, hint: 'e.g. 11.2588')),
            const SizedBox(width: 16),
            Expanded(child: _buildTextField('Longitude (°E)', _lngController, hint: 'e.g. 75.7804')),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_districtController.text.trim().isEmpty) {
                    _showError('⚠️ District is mandatory!');
                    return;
                  }
                  if (_talukController.text.trim().isEmpty) {
                    _showError('⚠️ Taluk is mandatory!');
                    return;
                  }
                  if (_gpController.text.trim().isEmpty) {
                    _showError('⚠️ Grama Panchayat is mandatory!');
                    return;
                  }
                  if (_villageController.text.trim().isEmpty) {
                    _showError('⚠️ Village is mandatory!');
                    return;
                  }
                  setState(() => _currentStep = 3);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: const Text('Next: Upload Photo & Review', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDevicePhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final base64Str = base64Encode(file.bytes!);
          final ext = (file.extension ?? 'jpg').toLowerCase();
          final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
          final dataUrl = 'data:$mime;base64,$base64Str';
          setState(() {
            _photoUrlController.text = dataUrl;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📸 Device photo selected from your device successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      _showError('Error selecting photo from device: $e');
    }
  }

  void _showZoomDialog(String imageUrl) {
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

  Widget _buildReviewSubmitForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Upload Instrument Photo & Final Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        // Photo Upload Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      final url = _photoUrlController.text.trim().isNotEmpty
                          ? _photoUrlController.text.trim()
                          : 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80';
                      _showZoomDialog(url);
                    },
                    child: Tooltip(
                      message: '🔍 Click to Zoom Photo',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _photoUrlController.text.trim().isNotEmpty
                                    ? _photoUrlController.text.trim()
                                    : 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Upload Device Site Photo *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        const Text('Select an actual photo of your weather instrument taken from your Mobile camera or Gallery.', style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: _pickDevicePhoto,
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('📁 Select Photo from Mobile / Computer', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _photoUrlController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Photo URL / Data Link',
                            hintText: 'https://... or selected file data',
                            prefixIcon: Icon(Icons.link, size: 16),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Checkbox confirmation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade300)),
          child: CheckboxListTile(
            value: _confirmedImdProtocol,
            onChanged: (v) => setState(() => _confirmedImdProtocol = v ?? false),
            activeColor: const Color(0xFF16A34A),
            title: const Text(
              'I confirm this weather instrument is installed according to KSDMA/IMD guidelines (open ground, 1.5m height, away from trees/buildings).',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ),
        const SizedBox(height: 20),

        Row(
          children: [
            OutlinedButton(
              onPressed: () => setState(() => _currentStep = 2),
              child: const Text('Back'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  if (_nicknameController.text.trim().isEmpty) {
                    _showError('⚠️ Instrument Name / Nickname is mandatory!');
                    return;
                  }
                  if (_mobileController.text.trim().isEmpty) {
                    _showError('⚠️ Mobile Number is mandatory!');
                    return;
                  }
                  if (_districtController.text.trim().isEmpty || _talukController.text.trim().isEmpty || _gpController.text.trim().isEmpty || _villageController.text.trim().isEmpty) {
                    _showError('⚠️ Geographic Location details (District, Taluk, Panchayat, Village) are mandatory!');
                    return;
                  }
                  if (!_confirmedImdProtocol) {
                    _showError('⚠️ Please check the confirmation box to confirm observation protocol!');
                    return;
                  }

                  final state = Provider.of<KsdmaStateService>(context, listen: false);
                  final prefix = _selectedType == InstrumentType.rainGauge
                      ? 'RG'
                      : _selectedType == InstrumentType.maxMinThermometer
                          ? 'TM'
                          : _selectedType == InstrumentType.riverGauge
                              ? 'RL'
                              : 'WT';
                  final stationId = '$prefix-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

                  final photoUrl = _photoUrlController.text.trim().isNotEmpty
                      ? _photoUrlController.text.trim()
                      : 'https://images.unsplash.com/photo-1590055531615-f16d36ffe8ec?auto=format&fit=crop&w=400&q=80';

                  final newStation = KsdmaStation(
                    stationId: stationId,
                    ownerUserId: state.currentUser.userId.isEmpty ? 'usr_admin_hq' : state.currentUser.userId,
                    ownerName: state.currentUser.fullName,
                    ownerCategory: state.currentUser.category,
                    category: StationCategory.manual,
                    instrumentType: _selectedType,
                    deviceMake: _makeModelController.text.isNotEmpty ? _makeModelController.text : _selectedType.displayName,
                    measurementLocation: _nicknameController.text.isNotEmpty ? _nicknameController.text : 'Main Site',
                    devicePhotoUrl: photoUrl,
                    latitude: double.tryParse(_latController.text) ?? 10.8505,
                    longitude: double.tryParse(_lngController.text) ?? 76.2711,
                    district: _districtController.text.trim(),
                    taluk: _talukController.text.trim(),
                    gramaPanchayat: _gpController.text.trim(),
                    village: _villageController.text.trim(),
                    approvalStatus: ApprovalStatus.pending,
                    createdAt: DateTime.now(),
                  );

                  await state.registerStation(newStation);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Instrument $stationId registered! Saved to Cloud & Queued for Admin Approval.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    widget.onSuccess?.call();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Submit & Send for Admin Approval', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInstrumentCard(InstrumentType type, String title, IconData icon) {
    final sel = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: Container(
        height: 110,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: sel ? const Color(0xFF16A34A) : Colors.black12, width: sel ? 2 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: sel ? const Color(0xFF16A34A) : Colors.black54, size: 28),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, fontWeight: sel ? FontWeight.bold : FontWeight.w500, color: sel ? const Color(0xFF15803D) : Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstrumentName(InstrumentType type) {
    switch (type) {
      case InstrumentType.rainGauge:
        return 'Standard Rain Gauge';
      case InstrumentType.maxMinThermometer:
        return 'Maximum-Minimum Thermometer';
      case InstrumentType.riverGauge:
        return 'River Level Gauge';
      case InstrumentType.hygrometer:
      default:
        return 'Wet & Dry Bulb Thermometer (Psychrometer)';
    }
  }

  String _getInstrumentDesc(InstrumentType type) {
    switch (type) {
      case InstrumentType.rainGauge:
        return 'Measure daily accumulated rainfall (mm) at 08:30 AM IST standard IMD time.';
      case InstrumentType.maxMinThermometer:
        return 'Measure Maximum and Minimum daily air temperatures (°C).';
      case InstrumentType.riverGauge:
        return 'Measure river water stage level (m) above reference datum gauge.';
      case InstrumentType.hygrometer:
      default:
        return 'Measure Dry Bulb Temperature and Wet Bulb Temperature. Relative Humidity (%) will be calculated automatically.';
    }
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    String? hint,
    IconData? suffixIcon,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: TextField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              hintText: hint,
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, size: 16),
                      onPressed: onTap,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Colors.black26)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF2563EB))),
            ),
          ),
        ),
      ],
    );
  }
}
