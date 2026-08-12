import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_portal_main.dart';

class KsdmaLoginGatePage extends StatefulWidget {
  const KsdmaLoginGatePage({super.key});

  @override
  State<KsdmaLoginGatePage> createState() => _KsdmaLoginGatePageState();
}

class _KsdmaLoginGatePageState extends State<KsdmaLoginGatePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoggedIn = false;
  int _targetInitialTab = 0;

  // ── Volunteer — New Registration ─────────────────────────────────────────
  bool _volunteerIsRegisterMode = true;
  final _volNameCtrl     = TextEditingController();
  final _volPhoneCtrl    = TextEditingController();
  final _volEmailCtrl    = TextEditingController();
  UserCategory _volCategory = UserCategory.schoolStudent;

  // ── Volunteer — Already Registered (OTP login) ───────────────────────────
  final _volLoginPhoneCtrl = TextEditingController();
  final _volOtpCtrl        = TextEditingController();
  bool _isOtpSent = false;

  // ── Officer ───────────────────────────────────────────────────────────────
  final _officerNameCtrl  = TextEditingController();
  final _officerEmailCtrl = TextEditingController();
  final _officerPassCtrl  = TextEditingController();

  // ── Admin HQ ─────────────────────────────────────────────────────────────
  final _adminNameCtrl  = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPassCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _volNameCtrl.dispose();
    _volPhoneCtrl.dispose();
    _volEmailCtrl.dispose();
    _volLoginPhoneCtrl.dispose();
    _volOtpCtrl.dispose();
    _officerNameCtrl.dispose();
    _officerEmailCtrl.dispose();
    _officerPassCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPassCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Snackbar helper ───────────────────────────────────────────────────────
  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('⚠️ $msg'),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Text field helper ─────────────────────────────────────────────────────
  Widget _field(
    String label,
    TextEditingController ctrl, {
    String hint = '',
    IconData icon = Icons.edit_outlined,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  // ── Category dropdown helper ──────────────────────────────────────────────
  Widget _categoryDropdown() {
    final categories = {
      UserCategory.schoolStudent:   '🎓 School Student',
      UserCategory.farmer:          '🌾 Farmer',
      UserCategory.fisherman:       '🐟 Fisherman',
      UserCategory.ngoVolunteer:    '🤝 NGO Volunteer',
      UserCategory.generalPublic:   '👤 General Public',
    };
    return DropdownButtonFormField<UserCategory>(
      initialValue: _volCategory,
      decoration: const InputDecoration(
        labelText: 'Category *',
        prefixIcon: Icon(Icons.category_outlined, size: 18),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: categories.entries
          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
          .toList(),
      onChanged: (v) => setState(() => _volCategory = v ?? _volCategory),
    );
  }

  // ── Info chip for branding panel ──────────────────────────────────────────
  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: Colors.blue.shade200),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => KsdmaStateService(),
      child: Consumer<KsdmaStateService>(
        builder: (context, state, _) {
          // Once logged in → show portal
          if (_isLoggedIn) {
            return KsdmaPortalMainPage(
              initialMenuIndex: _targetInitialTab,
              onLogout: () => setState(() => _isLoggedIn = false),
            );
          }

          // ── Login / Register Screen ─────────────────────────────────────
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Row(
              children: [
                // Left Branding Panel
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF1E3A8A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Center(child: Icon(Icons.shield, color: Colors.white, size: 28)),
                          ),
                          const SizedBox(width: 14),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                            Text('Kerala Citizen Weather', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('Observation Network (KSDMA)', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 12, fontWeight: FontWeight.w600)),
                          ]),
                        ]),
                        const SizedBox(height: 36),
                        const Text(
                          'Empowering Kerala Citizens for Disaster Risk Reduction & Climate Resilience',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.25),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Register once with your full details.\nLogin anytime with your mobile OTP or official credentials.',
                          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 32),
                        Row(children: [
                          _buildInfoChip('IMD Approved Protocols', Icons.verified_user_outlined),
                          const SizedBox(width: 12),
                          _buildInfoChip('Real-time Cloud Sync', Icons.cloud_sync_outlined),
                        ]),
                      ],
                    ),
                  ),
                ),

                // Right Auth Card
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        width: 440,
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('KSDMA Portal', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            const SizedBox(height: 4),
                            const Text('Register or sign in with your role', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 20),
                            TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF2563EB),
                              unselectedLabelColor: Colors.grey,
                              indicatorColor: const Color(0xFF2563EB),
                              tabs: const [
                                Tab(text: '🙋 Volunteer'),
                                Tab(text: '🛡️ Officer'),
                                Tab(text: '⚙️ Admin HQ'),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // Use IntrinsicHeight so the TabBarView grows with content
                            SizedBox(
                              height: 380,
                              child: TabBarView(
                                controller: _tabController,
                                physics: const NeverScrollableScrollPhysics(),
                                children: [
                                  _buildVolunteerForm(state),
                                  _buildOfficerForm(state),
                                  _buildAdminForm(state),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🙋 VOLUNTEER FORM — New Registration + OTP Login
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVolunteerForm(KsdmaStateService state) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle — Register / Login
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() { _volunteerIsRegisterMode = true; _isOtpSent = false; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _volunteerIsRegisterMode ? const Color(0xFF2563EB) : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                  child: Text('New Registration', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: _volunteerIsRegisterMode ? Colors.white : Colors.black54)),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() { _volunteerIsRegisterMode = false; _isOtpSent = false; }),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: !_volunteerIsRegisterMode ? const Color(0xFF2563EB) : Colors.grey.shade200,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                  child: Text('Already Registered', textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                      color: !_volunteerIsRegisterMode ? Colors.white : Colors.black54)),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),

          // ── REGISTER: collect all kusers fields ──────────────────────────
          if (_volunteerIsRegisterMode) ...[
            _field('Full Name *', _volNameCtrl,
                hint: 'e.g. Anjali Suresh', icon: Icons.person_outline),
            const SizedBox(height: 10),
            _field('Mobile Number *', _volPhoneCtrl,
                hint: 'e.g. 9876543210', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _field('Email (Optional)', _volEmailCtrl,
                hint: 'e.g. anjali@gmail.com', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _categoryDropdown(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.app_registration, color: Colors.white, size: 18),
                label: const Text('Register & Save to Database', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (_volNameCtrl.text.trim().isEmpty) { _showError('Full Name is mandatory!'); return; }
                  if (_volPhoneCtrl.text.trim().isEmpty) { _showError('Mobile Number is mandatory!'); return; }
                  final email = _volEmailCtrl.text.trim().isNotEmpty
                      ? _volEmailCtrl.text.trim()
                      : '${_volPhoneCtrl.text.trim()}@ksdma.kerala.gov.in';
                  final success = await state.registerAndLoginUser(
                    fullName: _volNameCtrl.text.trim(),
                    mobileNumber: _volPhoneCtrl.text.trim(),
                    email: email,
                    role: UserRole.volunteer,
                    category: _volCategory,
                  );
                  if (success && context.mounted) {
                    setState(() { _targetInitialTab = 0; _isLoggedIn = true; });
                  }
                },
              ),
            ),

          // ── LOGIN: phone + OTP ──────────────────────────────────────────
          ] else ...[
            _field('Registered Mobile Number *', _volLoginPhoneCtrl,
                hint: 'e.g. 9876543210', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
            if (_isOtpSent) ...[
              const SizedBox(height: 10),
              _field('4-Digit OTP *', _volOtpCtrl,
                  hint: 'Enter OTP sent to your mobile', icon: Icons.lock_outline, keyboard: TextInputType.number),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (_volLoginPhoneCtrl.text.trim().isEmpty) { _showError('Mobile Number is mandatory!'); return; }
                  if (!_isOtpSent) {
                    setState(() => _isOtpSent = true);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📱 OTP sent to your mobile!'), backgroundColor: Colors.blue),
                    );
                  } else {
                    if (_volOtpCtrl.text.trim().isEmpty) { _showError('OTP is mandatory!'); return; }
                    final success = await state.loginUserWithPhone(_volLoginPhoneCtrl.text.trim());
                    if (success && context.mounted) {
                      setState(() { _targetInitialTab = 0; _isLoggedIn = true; });
                    } else if (context.mounted) {
                      _showError('Mobile number not found. Please register first!');
                    }
                  }
                },
                child: Text(
                  _isOtpSent ? 'Verify OTP & Sign In' : 'Send OTP',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ OFFICER FORM — Collect all fields for first login
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOfficerForm(KsdmaStateService state) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Login-only banner
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Officer accounts are pre-registered by KSDMA. Enter your official credentials to sign in.',
                style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
              )),
            ]),
          ),
          _field('Govt Email Address *', _officerEmailCtrl,
              hint: 'e.g. officer@ksdma.kerala.gov.in', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _field('Password *', _officerPassCtrl,
              hint: '••••••••', icon: Icons.lock_outline, obscure: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.login, color: Colors.white, size: 18),
              label: const Text('Sign In as Officer', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (_officerEmailCtrl.text.trim().isEmpty) { _showError('Govt Email is mandatory!'); return; }
                if (_officerPassCtrl.text.trim().isEmpty)  { _showError('Password is mandatory!'); return; }
                // Verify against DB — no self-registration
                final error = await state.loginUserWithEmail(_officerEmailCtrl.text.trim(), 'OFFICER');
                if (error == null && context.mounted) {
                  setState(() { _targetInitialTab = 3; _isLoggedIn = true; });
                } else if (context.mounted) {
                  _showError(error ?? 'Login failed.');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ ADMIN HQ FORM — Collect all fields for first login
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminForm(KsdmaStateService state) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Login-only banner
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF7C3AED)),
            ),
            child: const Row(children: [
              Icon(Icons.security_outlined, color: Color(0xFF7C3AED), size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Admin accounts are created by KSDMA HQ only. Contact admin@ksdma.kerala.gov.in for access.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6D28D9)),
              )),
            ]),
          ),
          _field('HQ Admin Email ID *', _adminEmailCtrl,
              hint: 'e.g. admin@ksdma.kerala.gov.in', icon: Icons.admin_panel_settings_outlined),
          const SizedBox(height: 10),
          _field('Master Key *', _adminPassCtrl,
              hint: '••••••••', icon: Icons.key_outlined, obscure: true),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.verified_user, color: Colors.white, size: 18),
              label: const Text('Sign In as Admin HQ', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (_adminEmailCtrl.text.trim().isEmpty) { _showError('Admin Email is mandatory!'); return; }
                if (_adminPassCtrl.text.trim().isEmpty)  { _showError('Master Key is mandatory!'); return; }
                // Verify against DB — no self-registration allowed
                final error = await state.loginUserWithEmail(_adminEmailCtrl.text.trim(), 'ADMIN');
                if (error == null && context.mounted) {
                  setState(() { _targetInitialTab = 7; _isLoggedIn = true; });
                } else if (context.mounted) {
                  _showError(error ?? 'Login failed.');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

}
