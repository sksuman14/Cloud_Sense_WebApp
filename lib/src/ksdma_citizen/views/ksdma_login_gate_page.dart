import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_portal_main.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';

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
  final _volNameCtrl        = TextEditingController();
  final _volPhoneCtrl       = TextEditingController();
  final _volEmailCtrl       = TextEditingController();
  final _volPassCtrl        = TextEditingController();
  final _volRegisterOtpCtrl = TextEditingController();
  bool _volRegisterOtpSent  = false;
  bool _isProcessing        = false;
  UserCategory _volCategory = UserCategory.schoolStudent;

  // ── Volunteer — Already Registered (Password or OTP login) ───────────────
  final _volLoginPhoneCtrl = TextEditingController();
  final _volLoginPassCtrl  = TextEditingController();
  final _volOtpCtrl        = TextEditingController();
  bool _isOtpSent          = false;
  bool _loginWithPassMode  = true;

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
    _volPassCtrl.dispose();
    _volRegisterOtpCtrl.dispose();
    _volLoginPhoneCtrl.dispose();
    _volLoginPassCtrl.dispose();
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

  // ── Toast helper ─────────────────────────────────────────────────────────
  void _showError(String msg) {
    DeleteDeviceUtils.showToastNotification(
      context: context,
      title: 'Alert',
      message: msg,
      isError: true,
    );
  }

  void _showSuccess(String msg) {
    DeleteDeviceUtils.showToastNotification(
      context: context,
      title: 'Success',
      message: msg,
      isError: false,
    );
  }

  void _showForgotPasswordDialog(BuildContext context, KsdmaStateService state) {
    final identifierCtrl = TextEditingController(
      text: _volLoginPhoneCtrl.text.trim().isNotEmpty
          ? _volLoginPhoneCtrl.text.trim()
          : _volPhoneCtrl.text.trim(),
    );
    final otpCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool isOtpSent = false;
    bool isLoading = false;
    String statusMsg = '';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Row(
                children: [
                  Icon(Icons.lock_reset, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text(
                    'Reset Password',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (statusMsg.isNotEmpty) ...[
                      Text(
                        statusMsg,
                        style: TextStyle(
                          fontSize: 12,
                          color: statusMsg.startsWith('✅') ? Colors.green : Colors.amber.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    TextField(
                      controller: identifierCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      decoration: const InputDecoration(
                        labelText: 'Registered Email Address *',
                        hintText: 'e.g. user@gmail.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 18),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (isOtpSent) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: otpCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: '6-Digit Reset OTP *',
                          hintText: 'Enter 6-digit OTP code',
                          prefixIcon: Icon(Icons.mark_email_read_outlined, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                        decoration: const InputDecoration(
                          labelText: 'New Password *',
                          hintText: 'Enter new password',
                          prefixIcon: Icon(Icons.lock_outline, size: 18),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (identifierCtrl.text.trim().isEmpty) {
                            setDialogState(() => statusMsg = 'Please enter your Registered Email Address!');
                            return;
                          }
                          if (!isOtpSent) {
                            setDialogState(() {
                              isLoading = true;
                              statusMsg = 'Sending Reset OTP...';
                            });
                            final res = await state.apiService.sendOtp(
                              identifier: identifierCtrl.text.trim(),
                              isSignup: false,
                            );
                            setDialogState(() {
                              isLoading = false;
                              if (res['success'] == true) {
                                isOtpSent = true;
                                statusMsg = '✅ ${res['message'] ?? 'Reset OTP sent to your registered email.'}';
                              } else if (res['not_found'] == true) {
                                statusMsg = res['message'] ?? 'No account found. Please register first.';
                              } else {
                                statusMsg = res['message'] ?? 'Failed to send OTP.';
                              }
                            });
                          } else {
                            if (otpCtrl.text.trim().isEmpty || newPassCtrl.text.trim().isEmpty) {
                              setDialogState(() => statusMsg = 'OTP and New Password are required!');
                              return;
                            }
                            setDialogState(() {
                              isLoading = true;
                              statusMsg = 'Updating Password...';
                            });
                            final res = await state.apiService.resetPassword(
                              identifier: identifierCtrl.text.trim(),
                              otp: otpCtrl.text.trim(),
                              newPassword: newPassCtrl.text.trim(),
                            );
                            setDialogState(() => isLoading = false);
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.of(dialogCtx).pop();
                                _showSuccess('${res['message']}');
                              }
                            } else {
                              setDialogState(() => statusMsg = res['message'] ?? 'Failed to reset password.');
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(isOtpSent ? 'Set New Password' : 'Send Reset OTP'),
                ),
              ],
            );
          },
        );
      },
    );
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
                          'Register once with your full details.\nLogin anytime with your email OTP or password.',
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
  // 🙋 VOLUNTEER FORM — New Registration with OTP + Login with Password / OTP
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
                onTap: () => setState(() {
                  _volunteerIsRegisterMode = true;
                  _volRegisterOtpSent = false;
                  _isOtpSent = false;
                }),
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
                onTap: () => setState(() {
                  _volunteerIsRegisterMode = false;
                  _volRegisterOtpSent = false;
                  _isOtpSent = false;
                }),
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

          // ── REGISTER: collect all kusers fields + OTP verification ────────
          if (_volunteerIsRegisterMode) ...[
            _field('Full Name *', _volNameCtrl,
                hint: 'e.g. Anjali Suresh', icon: Icons.person_outline),
            const SizedBox(height: 10),
            _field('Mobile Number *', _volPhoneCtrl,
                hint: 'e.g. 9876543210', icon: Icons.phone_outlined, keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _field('Email Address (for OTP Verification) *', _volEmailCtrl,
                hint: 'e.g. anjali@gmail.com', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress),
            const SizedBox(height: 10),
            _field('Create Password *', _volPassCtrl,
                hint: 'At least 6 characters', icon: Icons.lock_outline, obscure: true),
            const SizedBox(height: 10),
            _categoryDropdown(),
            if (_volRegisterOtpSent) ...[
              const SizedBox(height: 10),
              _field('6-Digit Verification OTP *', _volRegisterOtpCtrl,
                  hint: 'Enter 6-digit code from your email', icon: Icons.mark_email_read_outlined, keyboard: TextInputType.number),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: Icon(_volRegisterOtpSent ? Icons.check_circle_outline : Icons.send_outlined, color: Colors.white, size: 18),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : (_volRegisterOtpSent ? 'Verify OTP & Complete Registration' : 'Send Verification OTP to Email'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () async {
                        if (_volNameCtrl.text.trim().isEmpty) { _showError('Full Name is mandatory!'); return; }
                        final cleanPhone = _volPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');
                        if (cleanPhone.length < 10) { _showError('Valid 10-digit Mobile Number is mandatory!'); return; }
                        final email = _volEmailCtrl.text.trim();
                        if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                          _showError('Valid Email Address is mandatory to receive OTP!');
                          return;
                        }
                        if (_volPassCtrl.text.trim().length < 6) { _showError('Password must be at least 6 characters!'); return; }

                        final phone = _volPhoneCtrl.text.trim();

                        // Step 1: Request OTP
                        if (!_volRegisterOtpSent) {
                          setState(() => _isProcessing = true);
                          final otpRes = await state.apiService.sendOtp(
                            identifier: phone,
                            email: email,
                            isSignup: true,
                          );
                          setState(() => _isProcessing = false);

                          if (!context.mounted) return;

                          if (otpRes['already_exists'] == true) {
                            _showError('An account with this Mobile Number or Email already exists.');
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: Colors.white,
                                title: const Row(children: [
                                  Icon(Icons.person_pin, color: Color(0xFF2563EB)),
                                  SizedBox(width: 8),
                                  Text('Account Already Exists', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ]),
                                content: const Text('An account with this mobile number or email is already registered.\n\nWould you like to sign in or reset your password?'),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      setState(() {
                                        _volunteerIsRegisterMode = false;
                                        _volLoginPhoneCtrl.text = phone;
                                      });
                                    },
                                    child: const Text('Sign In Instead'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      _showForgotPasswordDialog(context, state);
                                    },
                                    child: const Text('Forgot Password?'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          if (otpRes['success'] == true) {
                            setState(() {
                              _volRegisterOtpSent = true;
                            });
                            _showSuccess(otpRes['message'] ?? 'Verification OTP sent to $email. Please check your inbox and spam folder.');
                          } else {
                            _showError(otpRes['message'] ?? 'Failed to send verification OTP.');
                          }
                          return;
                        }

                        // Step 2: Complete Registration with OTP
                        if (_volRegisterOtpCtrl.text.trim().isEmpty) {
                          _showError('Please enter the 6-digit verification OTP received on your email!');
                          return;
                        }

                        setState(() => _isProcessing = true);
                        final result = await state.registerAndLoginUser(
                          fullName: _volNameCtrl.text.trim(),
                          mobileNumber: phone,
                          email: email,
                          password: _volPassCtrl.text.trim(),
                          role: UserRole.volunteer,
                          category: _volCategory,
                          otp: _volRegisterOtpCtrl.text.trim(),
                        );
                        setState(() => _isProcessing = false);

                        if (context.mounted) {
                          if (result['success'] == true) {
                            _showSuccess('Registration successful! Welcome to KSDMA.');
                            setState(() { _targetInitialTab = 0; _isLoggedIn = true; });
                          } else if (result['already_exists'] == true) {
                            _showError('Account already exists! Please switch to Already Registered.');
                          } else {
                            _showError(result['message'] ?? 'Registration failed. Check OTP.');
                          }
                        }
                      },
              ),
            ),

          // ── LOGIN: Password OR OTP ─────────────────────────────────────────
          ] else ...[
            _field(
              _loginWithPassMode ? 'Registered Mobile Number or Email *' : 'Registered Email Address *',
              _volLoginPhoneCtrl,
              hint: _loginWithPassMode ? 'e.g. 9876543210 or user@gmail.com' : 'e.g. user@gmail.com',
              icon: _loginWithPassMode ? Icons.person_outline : Icons.email_outlined,
            ),
            const SizedBox(height: 10),
            if (_loginWithPassMode) ...[
              _field('Account Password *', _volLoginPassCtrl,
                  hint: 'Enter your password', icon: Icons.lock_outline, obscure: true),
            ] else ...[
              if (_isOtpSent) ...[
                _field('6-Digit OTP *', _volOtpCtrl,
                    hint: 'Enter 6-digit OTP received on email', icon: Icons.lock_outline, keyboard: TextInputType.number),
              ],
            ],
            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _loginWithPassMode = !_loginWithPassMode;
                    _isOtpSent = false;
                  }),
                  child: Text(
                    _loginWithPassMode ? '✉️ Sign In with Email OTP instead' : '🔑 Sign In with Password instead',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showForgotPasswordDialog(context, state),
                  icon: const Icon(Icons.lock_reset, size: 13, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Forgot Password?',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () async {
                        final identifier = _volLoginPhoneCtrl.text.trim();
                        if (identifier.isEmpty) {
                          _showError(_loginWithPassMode
                              ? 'Mobile Number or Email is mandatory!'
                              : 'Registered Email is mandatory to receive OTP!');
                          return;
                        }

                        // Mode A: Password Login
                        if (_loginWithPassMode) {
                          if (_volLoginPassCtrl.text.trim().isEmpty) {
                            _showError('Password is mandatory!');
                            return;
                          }
                          setState(() => _isProcessing = true);
                          final res = await state.loginUserWithCredentials(
                            identifier: identifier,
                            password: _volLoginPassCtrl.text.trim(),
                          );
                          setState(() => _isProcessing = false);

                          if (context.mounted) {
                            if (res['success'] == true) {
                              _showSuccess('Logged in successfully!');
                              setState(() { _targetInitialTab = 0; _isLoggedIn = true; });
                            } else {
                              _showError(res['message'] ?? 'Login failed. Please check your credentials or click Forgot Password.');
                            }
                          }
                          return;
                        }

                        // Mode B: Email OTP Login
                        if (!_isOtpSent) {
                          setState(() => _isProcessing = true);
                          final res = await state.apiService.sendOtp(
                            identifier: identifier,
                            isSignup: false,
                          );
                          setState(() => _isProcessing = false);

                          if (context.mounted) {
                            if (res['success'] == true) {
                              setState(() {
                                _isOtpSent = true;
                              });
                              _showSuccess(res['message'] ?? 'OTP sent to your registered email. Please check your inbox and spam folder.');
                            } else if (res['not_found'] == true) {
                              _showError('Account not found. Please register first!');
                            } else {
                              _showError(res['message'] ?? 'Failed to send OTP.');
                            }
                          }
                        } else {
                          if (_volOtpCtrl.text.trim().isEmpty) {
                            _showError('Please enter the 6-digit OTP!');
                            return;
                          }
                          setState(() => _isProcessing = true);
                          final res = await state.loginWithEmailOtp(
                            email: identifier,
                            otp: _volOtpCtrl.text.trim(),
                          );
                          setState(() => _isProcessing = false);

                          if (context.mounted) {
                            if (res['success'] == true) {
                              _showSuccess('Logged in successfully!');
                              setState(() { _targetInitialTab = 0; _isLoggedIn = true; });
                            } else {
                              _showError(res['message'] ?? 'Invalid or expired OTP code.');
                            }
                          }
                        }
                      },
                child: Text(
                  _isProcessing
                      ? 'Processing...'
                      : (_loginWithPassMode
                          ? 'Sign In with Password'
                          : (_isOtpSent ? 'Verify OTP & Sign In' : 'Send OTP to Email')),
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
                final error = await state.loginUserWithEmail(
                  _officerEmailCtrl.text.trim(),
                  'OFFICER',
                  password: _officerPassCtrl.text.trim(),
                );
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
                final error = await state.loginUserWithEmail(
                  _adminEmailCtrl.text.trim(),
                  'ADMIN',
                  password: _adminPassCtrl.text.trim(),
                );
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
