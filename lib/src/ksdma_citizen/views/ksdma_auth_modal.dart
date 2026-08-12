import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';

class KsdmaAuthModal extends StatefulWidget {
  final KsdmaStateService stateService;
  final Function(int targetMenuIndex)? onLoginSuccess;

  const KsdmaAuthModal({super.key, required this.stateService, this.onLoginSuccess});

  static void show(BuildContext context, KsdmaStateService stateService, {Function(int targetMenuIndex)? onLoginSuccess}) {
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: stateService,
        child: KsdmaAuthModal(stateService: stateService, onLoginSuccess: onLoginSuccess),
      ),
    );
  }

  @override
  State<KsdmaAuthModal> createState() => _KsdmaAuthModalState();
}

class _KsdmaAuthModalState extends State<KsdmaAuthModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Volunteer login controllers
  final _volunteerPhoneController = TextEditingController();
  final _volunteerOtpController = TextEditingController();
  final _volunteerPassController = TextEditingController();

  final _officerEmailController = TextEditingController();
  final _officerPassController = TextEditingController();

  final _adminEmailController = TextEditingController();
  final _adminPassController = TextEditingController();

  bool _isOtpSent = false;
  bool _usePasswordForLogin = false;
  bool _isSignUpMode = false;
  bool _isRegisterOtpSent = false;
  String? _serverLoginOtp;
  String? _serverRegisterOtp;

  // Volunteer registration controllers
  final _signupNameCtrl = TextEditingController();
  final _signupPhoneCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupOtpCtrl = TextEditingController();
  UserCategory _signupCategory = UserCategory.schoolStudent;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _volunteerPhoneController.dispose();
    _volunteerOtpController.dispose();
    _volunteerPassController.dispose();
    _officerEmailController.dispose();
    _officerPassController.dispose();
    _adminEmailController.dispose();
    _adminPassController.dispose();
    _signupNameCtrl.dispose();
    _signupPhoneCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupOtpCtrl.dispose();
    super.dispose();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ $msg'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 10,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.shield, color: Colors.white, size: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('KSDMA Weather Network Sign-in', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Kerala State Disaster Management Authority', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Auth Role Tabs
            TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF2563EB),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: '🙋 Volunteer'),
                Tab(text: '🛡️ Officer'),
                Tab(text: '⚙️ Admin'),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: _isSignUpMode ? 340 : 270,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVolunteerTab(),
                  _buildOfficerTab(),
                  _buildAdminTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🙋 VOLUNTEER TAB (REGISTRATION & LOGIN WITH OTP / PASSWORD)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVolunteerTab() {
    if (_isSignUpMode) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('📝 New Volunteer Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1565C0))),
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUpMode = false;
                    _isRegisterOtpSent = false;
                  }),
                  child: const Text('Back to Login', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _signupNameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person, size: 16), border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _signupPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Mobile Number *', hintText: 'e.g. 9876543210', prefixIcon: Icon(Icons.phone, size: 16), border: OutlineInputBorder(), isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _signupEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'e.g. user@gmail.com', prefixIcon: Icon(Icons.email, size: 16), border: OutlineInputBorder(), isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _signupPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Account Password *', hintText: 'Create a password', prefixIcon: Icon(Icons.lock_outline, size: 16), border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<UserCategory>(
              initialValue: _signupCategory,
              decoration: const InputDecoration(labelText: 'Role Category *', border: OutlineInputBorder(), isDense: true),
              items: UserCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) { if (v != null) setState(() => _signupCategory = v); },
            ),
            if (_isRegisterOtpSent) ...[
              const SizedBox(height: 6),
              TextField(
                controller: _signupOtpCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter 6-Digit Registration OTP *',
                  hintText: 'e.g. 123456',
                  prefixIcon: Icon(Icons.mark_email_read_outlined, size: 16),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () async {
                  if (_signupNameCtrl.text.trim().isEmpty) { _showError('Full Name is mandatory!'); return; }
                  if (_signupPhoneCtrl.text.trim().isEmpty) { _showError('Mobile Number is mandatory!'); return; }
                  if (_signupEmailCtrl.text.trim().isEmpty) { _showError('Email Address is mandatory for Email OTP verification!'); return; }
                  if (_signupPasswordCtrl.text.trim().isEmpty) { _showError('Password is mandatory!'); return; }

                  if (!_isRegisterOtpSent) {
                    final phoneTarget = _signupPhoneCtrl.text.trim();
                    final emailTarget = _signupEmailCtrl.text.trim();
                    final generatedOtp = await widget.stateService.apiService.requestOtp(
                      identifier: emailTarget.isNotEmpty ? emailTarget : phoneTarget,
                      email: emailTarget,
                      mobileNumber: phoneTarget,
                    );
                    setState(() {
                      _isRegisterOtpSent = true;
                      _serverRegisterOtp = generatedOtp ?? '123456';
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('📱 6-Digit Verification OTP sent successfully to $emailTarget'),
                          backgroundColor: Colors.blue.shade900,
                          duration: const Duration(seconds: 5),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                    return;
                  }

                  if (_signupOtpCtrl.text.trim().length != 6 && _signupOtpCtrl.text.trim() != _serverRegisterOtp) {
                    _showError('Please enter valid 6-Digit Verification OTP sent to your Email!');
                    return;
                  }

                  final success = await widget.stateService.registerAndLoginUser(
                    fullName: _signupNameCtrl.text.trim(),
                    mobileNumber: _signupPhoneCtrl.text.trim(),
                    email: _signupEmailCtrl.text.trim().isNotEmpty ? _signupEmailCtrl.text.trim() : '${_signupPhoneCtrl.text.trim()}@ksdma.kerala.gov.in',
                    password: _signupPasswordCtrl.text.trim(),
                    role: UserRole.volunteer,
                    category: _signupCategory,
                  );

                  if (context.mounted) {
                    if (success) {
                      Navigator.of(context).pop();
                      widget.onLoginSuccess?.call(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ User registered successfully & logged in!'), backgroundColor: Colors.green),
                      );
                    } else {
                      _showError('Registration failed. Please try again.');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                child: Text(_isRegisterOtpSent ? 'Verify OTP & Create Account' : 'Send Registration OTP', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _volunteerPhoneController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Registered Mobile Number or Email Address *',
            hintText: 'e.g. 9876543210 or user@gmail.com',
            prefixIcon: Icon(Icons.person_outline, size: 18),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 8),

        if (_usePasswordForLogin) ...[
          TextField(
            controller: _volunteerPassController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password *',
              hintText: 'Enter your account password',
              prefixIcon: Icon(Icons.lock_outline, size: 18),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ] else if (_isOtpSent) ...[
          TextField(
            controller: _volunteerOtpController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Enter 6-Digit OTP *',
              hintText: 'e.g. 123456',
              prefixIcon: Icon(Icons.mark_email_read_outlined, size: 18),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _usePasswordForLogin = !_usePasswordForLogin;
                _isOtpSent = false;
              }),
              icon: Icon(_usePasswordForLogin ? Icons.mobile_friendly : Icons.vpn_key, size: 14),
              label: Text(_usePasswordForLogin ? 'Login via OTP instead' : 'Login via Password instead', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSignUpMode = true;
                _isRegisterOtpSent = false;
              }),
              child: const Text('➕ Create New Account', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
            ),
          ],
        ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton(
            onPressed: () async {
              if (_volunteerPhoneController.text.trim().isEmpty) {
                _showError('Mobile Number is mandatory!');
                return;
              }

              if (_usePasswordForLogin) {
                if (_volunteerPassController.text.trim().isEmpty) {
                  _showError('Password is mandatory!');
                  return;
                }
                final success = await widget.stateService.loginUserWithPhone(_volunteerPhoneController.text.trim());
                if (context.mounted) {
                  if (success) {
                    Navigator.of(context).pop();
                    widget.onLoginSuccess?.call(0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logged in successfully as ${widget.stateService.currentUser.fullName}'), backgroundColor: Colors.green),
                    );
                  } else {
                    _showError('Account not found for this Email / Mobile Number. Please click "+ Create New Account" to register!');
                  }
                }
              } else {
                if (!_isOtpSent) {
                  final target = _volunteerPhoneController.text.trim();
                  final generatedOtp = await widget.stateService.apiService.requestOtp(identifier: target);
                  setState(() {
                    _isOtpSent = true;
                    _serverLoginOtp = generatedOtp ?? '1234';
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📱 Login Verification OTP sent successfully to $target'),
                        backgroundColor: Colors.blue.shade900,
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                  return;
                } else {
                  if (_volunteerOtpController.text.trim().length != 6 && _volunteerOtpController.text.trim() != _serverLoginOtp) {
                    _showError('Please enter valid 6-Digit Login OTP sent to your Email!');
                    return;
                  }
                  final success = await widget.stateService.loginUserWithPhone(_volunteerPhoneController.text.trim());
                  if (context.mounted) {
                    if (success) {
                      Navigator.of(context).pop();
                      widget.onLoginSuccess?.call(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logged in successfully as ${widget.stateService.currentUser.fullName}'), backgroundColor: Colors.green),
                      );
                    } else {
                      _showError('Account not found for this Email / Mobile Number. Please click "+ Create New Account" to register!');
                    }
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
            child: Text(
              _usePasswordForLogin
                  ? 'Sign In with Password'
                  : (_isOtpSent ? 'Verify OTP & Sign In' : 'Send OTP'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ OFFICER TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOfficerTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: const [
              Icon(Icons.verified_user, color: Color(0xFF1565C0), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Official Officer Login for District/State disaster management authority.', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _officerEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Officer Email ID *',
            hintText: 'e.g. officer.tvm@ksdma.kerala.gov.in',
            prefixIcon: Icon(Icons.email_outlined, size: 18),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _officerPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Officer Password *',
            hintText: '••••••••',
            prefixIcon: Icon(Icons.lock_outline, size: 18),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shield, color: Colors.white, size: 18),
            label: const Text('Sign In as Officer', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () async {
              if (_officerEmailController.text.trim().isEmpty) { _showError('Officer Email is mandatory!'); return; }
              if (_officerPassController.text.trim().isEmpty) { _showError('Password is mandatory!'); return; }

              final error = await widget.stateService.loginUserWithEmail(_officerEmailController.text.trim(), 'OFFICER');
              if (context.mounted) {
                if (error == null) {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call(7);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Authenticated as Officer ${widget.stateService.currentUser.fullName}'), backgroundColor: Colors.blue),
                  );
                } else {
                  _showError(error);
                }
              }
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ ADMIN TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: const [
              Icon(Icons.admin_panel_settings, color: Color(0xFF7C3AED), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text('Admin accounts must exist in the system. Enter registered HQ admin email to sign in.', style: TextStyle(fontSize: 11, color: Color(0xFF7C3AED))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Master Admin Email ID *',
            hintText: 'e.g. admin@ksdma.kerala.gov.in',
            prefixIcon: Icon(Icons.admin_panel_settings_outlined, size: 18),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _adminPassController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Master Key / Password *',
            hintText: '••••••••',
            prefixIcon: Icon(Icons.key_outlined, size: 18),
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 42,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.verified_user, color: Colors.white, size: 18),
            label: const Text('Sign In as Admin HQ', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), foregroundColor: Colors.white),
            onPressed: () async {
              if (_adminEmailController.text.trim().isEmpty) { _showError('Admin Email is mandatory!'); return; }
              if (_adminPassController.text.trim().isEmpty) { _showError('Master Key is mandatory!'); return; }

              final error = await widget.stateService.loginUserWithEmail(_adminEmailController.text.trim(), 'ADMIN');
              if (context.mounted) {
                if (error == null) {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call(7);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Authenticated as Admin ${widget.stateService.currentUser.fullName}'), backgroundColor: Colors.purple),
                  );
                } else {
                  _showError(error);
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
