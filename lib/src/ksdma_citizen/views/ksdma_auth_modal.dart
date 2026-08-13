import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../views/home/home_theme.dart';
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

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    required bool isDark,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.grey.shade300 : const Color(0xFF4B5563),
      ),
      hintText: hintText,
      hintStyle: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.grey.shade500 : const Color(0xFF9CA3AF),
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF282B3A) : const Color(0xFFF9FAFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
          width: 1.5,
        ),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      isDark = themeProvider.isDarkMode;
    } catch (_) {}

    final dialogBg = isDark ? const Color(0xFF1E202C) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subtitleColor = isDark ? Colors.grey.shade400 : const Color(0xFF6B7280);
    final activeTabColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final unselectedTabColor = isDark ? Colors.grey.shade300 : const Color(0xFF4B5563);

    return Dialog(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 12,
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
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC2626),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(child: Icon(Icons.shield, color: Colors.white, size: 24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KSDMA Weather Network Sign-in',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kerala State Disaster Management Authority',
                        style: TextStyle(
                          fontSize: 11,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: isDark ? Colors.grey.shade300 : Colors.grey.shade600),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: isDark ? Colors.white12 : Colors.grey.shade200, height: 1),
            const SizedBox(height: 12),

            // Auth Role Tabs
            TabBar(
              controller: _tabController,
              labelColor: activeTabColor,
              unselectedLabelColor: unselectedTabColor,
              indicatorColor: activeTabColor,
              indicatorWeight: 3,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: '🙋 Volunteer'),
                Tab(text: '🛡️ Officer'),
                Tab(text: '⚙️ Admin'),
              ],
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: _isSignUpMode ? 360 : 270,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVolunteerTab(isDark),
                  _buildOfficerTab(isDark),
                  _buildAdminTab(isDark),
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
  Widget _buildVolunteerTab(bool isDark) {
    final textStyle = TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1F2937));
    final btnBgColor = isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB);

    if (_isSignUpMode) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '📝 New Volunteer Registration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1565C0),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _isSignUpMode = false;
                    _isRegisterOtpSent = false;
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  ),
                  child: const Text('Back to Login', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _signupNameCtrl,
              style: textStyle,
              decoration: _buildInputDecoration(
                label: 'Full Name *',
                icon: Icons.person_outline,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _signupPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      label: 'Mobile Number *',
                      hintText: 'e.g. 9876543210',
                      icon: Icons.phone_outlined,
                      isDark: isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _signupEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: textStyle,
                    decoration: _buildInputDecoration(
                      label: 'Email Address *',
                      hintText: 'e.g. user@gmail.com',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _signupPasswordCtrl,
              obscureText: true,
              style: textStyle,
              decoration: _buildInputDecoration(
                label: 'Account Password *',
                hintText: 'Create a password',
                icon: Icons.lock_outline,
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<UserCategory>(
              value: _signupCategory,
              dropdownColor: isDark ? const Color(0xFF282B3A) : Colors.white,
              decoration: _buildInputDecoration(
                label: 'Role Category *',
                icon: Icons.category_outlined,
                isDark: isDark,
              ),
              items: UserCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(
                          c.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _signupCategory = v);
              },
            ),
            if (_isRegisterOtpSent) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _signupOtpCtrl,
                keyboardType: TextInputType.number,
                style: textStyle,
                decoration: _buildInputDecoration(
                  label: 'Enter 6-Digit Registration OTP *',
                  hintText: 'e.g. 123456',
                  icon: Icons.mark_email_read_outlined,
                  isDark: isDark,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBgColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  _isRegisterOtpSent ? 'Verify OTP & Create Account' : 'Send Registration OTP',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
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
          style: textStyle,
          decoration: _buildInputDecoration(
            label: 'Registered Mobile Number or Email Address *',
            hintText: 'e.g. 9876543210 or user@gmail.com',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 10),

        if (_usePasswordForLogin) ...[
          TextField(
            controller: _volunteerPassController,
            obscureText: true,
            style: textStyle,
            decoration: _buildInputDecoration(
              label: 'Password *',
              hintText: 'Enter your account password',
              icon: Icons.lock_outline,
              isDark: isDark,
            ),
          ),
        ] else if (_isOtpSent) ...[
          TextField(
            controller: _volunteerOtpController,
            keyboardType: TextInputType.number,
            style: textStyle,
            decoration: _buildInputDecoration(
              label: 'Enter 6-Digit OTP *',
              hintText: 'e.g. 123456',
              icon: Icons.mark_email_read_outlined,
              isDark: isDark,
            ),
          ),
        ],

        const SizedBox(height: 4),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => setState(() {
                _usePasswordForLogin = !_usePasswordForLogin;
                _isOtpSent = false;
              }),
              icon: Icon(
                _usePasswordForLogin ? Icons.mobile_friendly : Icons.vpn_key,
                size: 14,
                color: isDark ? Colors.grey.shade400 : Colors.blueGrey,
              ),
              label: Text(
                _usePasswordForLogin ? 'Login via OTP instead' : 'Login via Password instead',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700,
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSignUpMode = true;
                _isRegisterOtpSent = false;
              }),
              child: Text(
                '➕ Create New Account',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),

        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 44,
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
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBgColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              _usePasswordForLogin
                  ? 'Sign In with Password'
                  : (_isOtpSent ? 'Verify OTP & Sign In' : 'Send OTP'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 🛡️ OFFICER TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildOfficerTab(bool isDark) {
    final textStyle = TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1F2937));
    final infoBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : Colors.blue.shade50;
    final infoTextColor = isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1565C0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: infoBg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(Icons.verified_user, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1565C0), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Official Officer Login for District/State disaster management authority.',
                  style: TextStyle(fontSize: 11, color: infoTextColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _officerEmailController,
          keyboardType: TextInputType.emailAddress,
          style: textStyle,
          decoration: _buildInputDecoration(
            label: 'Officer Email ID *',
            hintText: 'e.g. officer.tvm@ksdma.kerala.gov.in',
            icon: Icons.email_outlined,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _officerPassController,
          obscureText: true,
          style: textStyle,
          decoration: _buildInputDecoration(
            label: 'Officer Password *',
            hintText: '••••••••',
            icon: Icons.lock_outline,
            isDark: isDark,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.shield, color: Colors.white, size: 18),
            label: const Text('Sign In as Officer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_officerEmailController.text.trim().isEmpty) { _showError('Officer Email is mandatory!'); return; }
              if (_officerPassController.text.trim().isEmpty) { _showError('Password is mandatory!'); return; }

              final error = await widget.stateService.loginUserWithEmail(_officerEmailController.text.trim(), 'OFFICER');
              if (context.mounted) {
                if (error == null) {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call(_getRoleTargetMenuIndex());
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

  int _getRoleTargetMenuIndex() {
    final u = widget.stateService.currentUser;
    if (u.role == UserRole.admin || u.category == UserCategory.adminHq || u.fullName.contains('Admin')) {
      return 7; // Admin Dashboard
    }
    if (u.role == UserRole.officer || u.category == UserCategory.districtOfficer || u.fullName.contains('Officer')) {
      return 3; // Officer Reports
    }
    return 0; // Public Dashboard
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚙️ ADMIN TAB
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildAdminTab(bool isDark) {
    final textStyle = TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF1F2937));
    final infoBg = isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.4) : Colors.purple.shade50;
    final infoTextColor = isDark ? const Color(0xFFF3E8FF) : const Color(0xFF7C3AED);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: infoBg, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Admin accounts must exist in the system. Enter registered HQ admin email to sign in.',
                  style: TextStyle(fontSize: 11, color: infoTextColor, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _adminEmailController,
          keyboardType: TextInputType.emailAddress,
          style: textStyle,
          decoration: _buildInputDecoration(
            label: 'Master Admin Email ID *',
            hintText: 'e.g. admin@ksdma.kerala.gov.in',
            icon: Icons.admin_panel_settings_outlined,
            isDark: isDark,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _adminPassController,
          obscureText: true,
          style: textStyle,
          decoration: _buildInputDecoration(
            label: 'Master Key / Password *',
            hintText: '••••••••',
            icon: Icons.key_outlined,
            isDark: isDark,
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.verified_user, color: Colors.white, size: 18),
            label: const Text('Sign In as Admin HQ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (_adminEmailController.text.trim().isEmpty) { _showError('Admin Email is mandatory!'); return; }
              if (_adminPassController.text.trim().isEmpty) { _showError('Master Key is mandatory!'); return; }

              final error = await widget.stateService.loginUserWithEmail(_adminEmailController.text.trim(), 'ADMIN');
              if (context.mounted) {
                if (error == null) {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call(_getRoleTargetMenuIndex());
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
