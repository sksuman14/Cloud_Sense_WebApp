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

  bool _isSignUpMode = false;

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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: ElevatedButton(
                onPressed: () async {
                  if (_signupNameCtrl.text.trim().isEmpty) { _showError('Full Name is mandatory!'); return; }
                  if (_signupPhoneCtrl.text.trim().isEmpty) { _showError('Mobile Number is mandatory!'); return; }
                  if (_signupEmailCtrl.text.trim().isEmpty) { _showError('Email Address is mandatory!'); return; }
                  if (_signupPasswordCtrl.text.trim().isEmpty) { _showError('Password is mandatory!'); return; }

                  final result = await widget.stateService.registerAndLoginUser(
                    fullName: _signupNameCtrl.text.trim(),
                    mobileNumber: _signupPhoneCtrl.text.trim(),
                    email: _signupEmailCtrl.text.trim(),
                    password: _signupPasswordCtrl.text.trim(),
                    role: UserRole.volunteer,
                    category: _signupCategory,
                  );

                  if (context.mounted) {
                    if (result['success'] == true) {
                      Navigator.of(context).pop();
                      widget.onLoginSuccess?.call(0);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Account created & logged in successfully!'), backgroundColor: Colors.green),
                      );
                    } else {
                      _showError(result['message'] ?? 'Registration failed. Please try again.');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: btnBgColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Create Account & Sign In',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _buildVolunteerLoginForm(isDark, textStyle, btnBgColor);
  }

  void _showForgotPasswordDialog(BuildContext context, bool isDark) {
    final identifierCtrl = TextEditingController(text: _volunteerPhoneController.text);
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
              backgroundColor: isDark ? const Color(0xFF1E202E) : Colors.white,
              title: Row(
                children: [
                  const Icon(Icons.lock_reset, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
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
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      decoration: _buildInputDecoration(
                        label: 'Registered Email Address *',
                        hintText: 'e.g. user@gmail.com',
                        icon: Icons.email_outlined,
                        isDark: isDark,
                      ),
                    ),
                    if (isOtpSent) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: otpCtrl,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: _buildInputDecoration(
                          label: '6-Digit Reset OTP *',
                          hintText: 'Check Email Inbox / Spam',
                          icon: Icons.mark_email_read_outlined,
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: newPassCtrl,
                        obscureText: true,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                        decoration: _buildInputDecoration(
                          label: 'New Password *',
                          hintText: 'Enter new password',
                          icon: Icons.lock_outline,
                          isDark: isDark,
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
                          if (!identifierCtrl.text.trim().contains('@')) {
                            setDialogState(() => statusMsg = 'Please enter a valid Email Address!');
                            return;
                          }
                          if (!isOtpSent) {
                            setDialogState(() {
                              isLoading = true;
                              statusMsg = 'Sending Reset OTP to Email...';
                            });
                            final res = await widget.stateService.apiService.requestPasswordReset(identifierCtrl.text.trim());
                            setDialogState(() {
                              isLoading = false;
                              if (res['success'] == true) {
                                isOtpSent = true;
                                statusMsg = '✅ Reset OTP sent! Please check your Email Inbox.';
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
                            final res = await widget.stateService.apiService.resetPassword(
                              identifier: identifierCtrl.text.trim(),
                              otp: otpCtrl.text.trim(),
                              newPassword: newPassCtrl.text.trim(),
                            );
                            setDialogState(() => isLoading = false);
                            if (res['success'] == true) {
                              if (context.mounted) {
                                Navigator.of(dialogCtx).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ ${res['message']}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
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

  Widget _buildVolunteerLoginForm(bool isDark, TextStyle textStyle, Color btnBgColor) {
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
        const SizedBox(height: 4),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _showForgotPasswordDialog(context, isDark),
              icon: Icon(
                Icons.lock_reset,
                size: 14,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
              ),
              label: Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                ),
              ),
            ),
            TextButton(
              onPressed: () => setState(() {
                _isSignUpMode = true;
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
                _showError('Mobile Number or Email is mandatory!');
                return;
              }
              if (_volunteerPassController.text.trim().isEmpty) {
                _showError('Password is mandatory!');
                return;
              }

              final result = await widget.stateService.loginUserWithCredentials(
                identifier: _volunteerPhoneController.text.trim(),
                password: _volunteerPassController.text.trim(),
              );

              if (context.mounted) {
                if (result['success'] == true) {
                  Navigator.of(context).pop();
                  widget.onLoginSuccess?.call(0);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Logged in successfully as ${widget.stateService.currentUser.fullName}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _showError(result['message'] ?? 'Login failed. Please check your password or register.');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: btnBgColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'Sign In with Password',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

              final error = await widget.stateService.loginUserWithEmail(
                _officerEmailController.text.trim(),
                'OFFICER',
                password: _officerPassController.text.trim(),
              );
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

              final error = await widget.stateService.loginUserWithEmail(
                _adminEmailController.text.trim(),
                'ADMIN',
                password: _adminPassController.text.trim(),
              );
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
