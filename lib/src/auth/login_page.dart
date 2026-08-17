import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/auth_guard.dart';
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

class SignInSignUpScreen extends StatefulWidget {
  @override
  _SignInSignUpScreenState createState() => _SignInSignUpScreenState();
}

class _SignInSignUpScreenState extends State<SignInSignUpScreen> {
  bool _isSignIn = true;

  // Sign-in: username OR email
  final TextEditingController _loginController = TextEditingController();

  // Sign-up fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // Shared
  final TextEditingController _passwordController = TextEditingController();

  String _errorMessage = '';
  bool _emailValid = true;
  bool _isLoading = false;
  String? _verificationCode;
  String? _emailToVerify;
  String? _usernameToVerify; // Cognito username used during sign-up
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  bool _isPasswordValid(String password) {
    final passwordRegex =
        RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[!@#\$&*~]).{8,}$');
    return passwordRegex.hasMatch(password);
  }

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
    // Validate email only on sign-up form
    _emailController.addListener(() {
      if (!_isSignIn) {
        setState(() {
          _emailValid = EmailValidator.validate(_emailController.text);
        });
      }
    });
  }

  Future<void> _checkCurrentUser() async {
    try {
      var currentUser = await Amplify.Auth.getCurrentUser();
      var userAttributes = await Amplify.Auth.fetchUserAttributes();
      String? email;
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
          break;
        }
      }
      if (email != null) {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(email);
        RouteGuard.setAuthenticatedUser(email);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        await prefs.setString('email', email);
        String? token = await FirebaseMessaging.instance.getToken();

        // ✅ FIXED: Proper if-else lagaya
        if (DeviceUtils.isSuperAdmin(email.trim().toLowerCase())) {
          NavigationUtils.navigateTo(context, '/', isReplacement: true); // Admin stays on home
        } else if (email.trim().toLowerCase() == "05agriculture.05@gmail.com") {
          print("Subscribing $email to GPS SNS topic in _checkCurrentUser.");
          await subscribeToGpsSnsTopic(token!);
          await prefs.setBool('isGpsTokenSubscribed', true);
          NavigationUtils.navigateTo(context, '/deviceinfo', isReplacement: true);
        } else {
          // ✅ Baaki SABHI users ke liye yahan aayega
          bool? wasGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
          if (wasGpsSubscribed == true) {
            await unsubscribeFromGpsSnsTopic(token!);
            await prefs.remove('isGpsTokenSubscribed');
          }
          NavigationUtils.navigateTo(context, '/', isReplacement: true); // Stay on home page
        }
      }
    } catch (_) {
      // Not signed in — stay on SignInSignUpScreen
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      // Ensure any previous session is cleared before signing in
      try {
        await Amplify.Auth.signOut();
      } catch (e) {
        print("Ignoring sign-out error before sign-in: $e");
      }

      // Attempt to sign in with username or email
      SignInResult res = await Amplify.Auth.signIn(
        username: _loginController.text.trim(),
        password: _passwordController.text,
      );

      if (res.isSignedIn) {
        // Fetch actual email attribute from Cognito
        var userAttributes = await Amplify.Auth.fetchUserAttributes();
        String? fetchedEmail;
        for (var attr in userAttributes) {
          if (attr.userAttributeKey == AuthUserAttributeKey.email) {
            fetchedEmail = attr.value;
            break;
          }
        }
        SharedPreferences prefs = await SharedPreferences.getInstance();
        String email =
            (fetchedEmail ?? _loginController.text).trim().toLowerCase();
        await prefs.setString('email', email);
        await prefs.setString('loginMethod', 'normal');

        // Update UserProvider
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(email);

        print("✅ User logged in: $email");

        // 🔹 Get FCM Token and subscribe to appropriate SNS topic
        try {
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            if (email == "05agriculture.05@gmail.com") {
              print("Subscribing $email to GPS SNS topic.");
              await subscribeToGpsSnsTopic(token);
              await prefs.setBool('isGpsTokenSubscribed', true);

              bool? wasGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
              if (wasGpsSubscribed == true) {
                await unsubscribeFromGpsSnsTopic(token);
                await prefs.remove('isGpsTokenSubscribed');
              }
            } else {
              bool? wasGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
              if (wasGpsSubscribed == true) {
                await unsubscribeFromGpsSnsTopic(token);
                await prefs.remove('isGpsTokenSubscribed');
              }
            }
          }
        } catch (fcmError) {
          print(
              "FCM Token error during login (possibly blocked by browser): $fcmError");
        }
        print("✅ Subscription handling completed after login.");
        // ✅ Navigate based on specific user
        if (DeviceUtils.isSuperAdmin(email.trim().toLowerCase())) {
          print("Navigating to / (Home) for admin $email");
          NavigationUtils.navigateTo(context, '/', removeUntil: true);
        } else if (email.trim().toLowerCase() == "05agriculture.05@gmail.com") {
          print("Navigating to /deviceinfo for $email");
          NavigationUtils.navigateTo(context, '/deviceinfo', removeUntil: true);
        } else {
          print("Navigating to / (Home) for $email");
          NavigationUtils.navigateTo(context, '/', removeUntil: true);
        }
      } else {
        _showSnackbar('Sign-in failed');
      }
    } on UserNotFoundException catch (_) {
      // User not in new pool — likely an existing user from the old pool
      final loginText = _loginController.text.trim();
      final isEmail = EmailValidator.validate(loginText);
      setState(() => _isLoading = false);

      if (isEmail) {
        _showMigrationDialog(
          prefilledEmail: loginText,
          prefilledPassword: _passwordController.text,
        );
      } else {
        _showSnackbar(
            'User not found. If you have an old account, please sign in with your email to set a username.');
      }
      return;
    } on AuthException catch (e) {
      print("AuthException during sign-in: ${e.message}");
      _showSnackbar(e.message);
    } catch (e) {
      print("Unexpected error during sign-in: $e");
      _showSnackbar('An unexpected error occurred');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await Amplify.Auth.signInWithWebUI(
        provider: AuthProvider.google,
        options: const SignInWithWebUIOptions(
          pluginOptions: CognitoSignInWithWebUIPluginOptions(
            isPreferPrivateSession: false,
          ),
        ),
      );
      safePrint('Google sign-in result: ${res.isSignedIn} | nextStep: ${res.nextStep}');
      if (res.isSignedIn) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        var userAttributes = await Amplify.Auth.fetchUserAttributes();
        String? email;
        for (var attr in userAttributes) {
          if (attr.userAttributeKey == AuthUserAttributeKey.email) {
            email = attr.value;
            break;
          }
        }
        if (email != null) {
          await prefs.setString('email', email.trim().toLowerCase());
          await prefs.setString('loginMethod', 'google');
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(email);
        }
        NavigationUtils.navigateTo(context, '/', removeUntil: true);
      } else {
        safePrint('Google sign-in not complete. Next step: ${res.nextStep}');
        _showSnackbar('Sign-in was not completed. Please try again.');
      }
    } on UserCancelledException {
      // User cancelled — do nothing, just stop loading
      safePrint('Google sign-in cancelled by user.');
    } on AuthException catch (e) {
      safePrint('AuthException during Google sign-in: ${e.message}');
      _showSnackbar(e.message);
    } catch (e) {
      safePrint('Unexpected error during Google sign-in: $e');
      _showSnackbar('An unexpected error occurred. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackbar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _forgotPassword() async {
    String? email = await _showEmailInputDialog();
    if (email != null && EmailValidator.validate(email)) {
      try {
        await Amplify.Auth.resetPassword(username: email);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('A password reset code has been sent to your email.'),
          ),
        );
        _showPasswordResetCodeDialog(email);
      } on AuthException catch (e) {
        setState(() {
          _errorMessage = e.message;
        });
      }
    } else {
      _showSnackbar('Please enter a valid email address.');
    }
  }

  Future<void> _showPasswordResetCodeDialog(String email) async {
    String? resetCode;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController resetCodeController = TextEditingController();

        return AlertDialog(
          title: Text('Enter Reset Code'),
          content: TextField(
            controller: resetCodeController,
            decoration: InputDecoration(labelText: 'Reset Code'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                resetCode = resetCodeController.text;
                Navigator.of(context).pop();
                if (resetCode != null && resetCode!.isNotEmpty) {
                  _showNewPasswordDialog(email, resetCode!);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNewPasswordDialog(String email, String resetCode) async {
    String? newPassword;
    String? confirmPassword;
    bool passwordsMatch = true;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController newPasswordController = TextEditingController();
        TextEditingController confirmPasswordController =
            TextEditingController();

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Enter New Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  if (!passwordsMatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Passwords do not match',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text('Submit'),
                  onPressed: () async {
                    newPassword = newPasswordController.text;
                    confirmPassword = confirmPasswordController.text;

                    if (newPassword == confirmPassword) {
                      Navigator.of(context).pop();
                      await _confirmResetPassword(
                          email, resetCode, newPassword!);
                    } else {
                      setState(() {
                        passwordsMatch = false;
                      });
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmResetPassword(
      String email, String resetCode, String newPassword) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: resetCode,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Password has been reset. Please log in with your new password.')),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    }
  }

  Future<String?> _showEmailInputDialog() async {
    String? email;
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController emailController = TextEditingController();
        return AlertDialog(
          title: Text('Reset Password'),
          content: TextField(
            controller: emailController,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Submit'),
              onPressed: () {
                email = emailController.text;
                Navigator.of(context).pop(email);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _signUp() async {
    setState(() {
      _isLoading = true; // Show loading indicator during sign-up
    });

    // Manual password check BEFORE sign-up attempt
    final password = _passwordController.text;
    if (!_isPasswordValid(password)) {
      setState(() {
        _isLoading = false;
      });

      // Show snackbar directly without setting _errorMessage
      _showSnackbar(
        'Password must be at least 8 characters long and include:a number,a special character, a letter',
      );
      return;
    }

    // Validate username
    final username = _usernameController.text.trim();
    if (username.isEmpty || username.length < 3) {
      setState(() => _isLoading = false);
      _showSnackbar('Username must be at least 3 characters.');
      return;
    }

    try {
      // Sign up with username as Cognito username + email + name attributes
      final res = await Amplify.Auth.signUp(
        username: username,
        password: _passwordController.text,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: _emailController.text.trim(),
            CognitoUserAttributeKey.name: _nameController.text,
            CognitoUserAttributeKey.preferredUsername: username,
          },
        ),
      );

      // ✅ Here we check if sign-up is complete
      if (res.isSignUpComplete) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign-up successful! Please sign in.')),
        );
        setState(() {
          _isSignIn = true; // Switch to sign-in mode
        });
      } else {
        // ⚠ Verification required
        _emailToVerify = _emailController.text.trim();
        _usernameToVerify = username;
        _showVerificationDialog();
      }
    } on UsernameExistsException {
      // Resend code if user already exists but hasn't verified
      try {
        await Amplify.Auth.resendSignUpCode(username: username);
        _emailToVerify = _emailController.text.trim();
        _usernameToVerify = username;
        _showVerificationDialog();
      } on AuthException catch (e) {
        _showSnackbar(e.message); // 🔴 Snackbar only for error
      }
    } on AuthException catch (e) {
      _showSnackbar(e.message); // 🔴 Snackbar only for error
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resendVerificationCode() async {
    if (_emailToVerify == null) {
      _showSnackbar(
          'Please provide your email to resend the verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Use the Cognito username (preferred_username), not email
      await Amplify.Auth.resendSignUpCode(
          username: _usernameToVerify ?? _emailToVerify!);
      _showSnackbar('Verification code has been resent to your email.');
    } on AuthException catch (e) {
      _showSnackbar(e.message);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmSignUp() async {
    if (_verificationCode == null || _emailToVerify == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await Amplify.Auth.confirmSignUp(
        username: _usernameToVerify ?? _emailToVerify!,
        confirmationCode: _verificationCode!,
      );

      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.setUser(_emailToVerify!);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('email', _emailToVerify!);
      String? token = await FirebaseMessaging.instance.getToken();
      // if (adminEmails.contains(_emailToVerify!.trim().toLowerCase())) {
      //   print(
      //       "Subscribing $_emailToVerify to anomaly SNS topic after sign-up.");
      //   await subscribeToSnsTopic(token!);
      //   await prefs.setBool('isAnomalyTokenSubscribed', true);
      // }
      bool? wasGpsSubscribed = prefs.getBool('isGpsTokenSubscribed');
      if (wasGpsSubscribed == true) {
        await unsubscribeFromGpsSnsTopic(token!);
        await prefs.remove('isGpsTokenSubscribed');
      }

      setState(() {
        _isSignIn = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-up successful! Please sign in.')),
      );
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bg = isDark
        ? [const Color(0xFF0B141D), const Color(0xFF14212B)]
        : [const Color(0xFFF0F4F8), const Color(0xFFFFFFFF)];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 20),
          onPressed: () => NavigationUtils.navigateTo(
              context, '/', removeUntil: true),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: bg,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: _isSignIn
                    ? _buildSignInCard(isDark)
                    : _buildSignUpCard(isDark),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInCard(bool isDark) {
    final card = isDark ? const Color(0xFF0D1F2D) : Colors.white;
    final strong = isDark ? const Color(0xFFE8F4F0) : const Color(0xFF1A1A1A);
    final subtle = isDark ? const Color(0x73E8F4F0) : const Color(0x991A1A1A);
    final accent = isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);

    return Container(
      key: const ValueKey('SignIn'),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Row(
            children: [
              if (isWide)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Welcome Back!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'To keep connected with us please login with your personal info.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: subtle,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Image.asset(
                          'assets/images/signin.png',
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.login,
                              size: 80, color: accent.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: strong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please enter your credentials',
                        style: TextStyle(color: subtle, fontSize: 14),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _loginController,
                        label: 'Username or Email',
                        icon: Icons.person_outline,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        isDark: isDark,
                        isPassword: true,
                        obscure: !_isPasswordVisible,
                        onToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                                color: accent, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : const Text('Sign In',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR',
                                style: TextStyle(color: subtle, fontSize: 14)),
                          ),
                          Expanded(
                              child: Divider(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithGoogle,
                          icon: Image.asset(
                            'assets/images/google.png',
                            height: 24,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.login, color: Colors.black87),
                          ),
                          label: const Text('Sign in with Google',
                              style: TextStyle(
                                  color: Colors.black87, fontSize: 16)),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: Colors.black87),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?",
                              style: TextStyle(color: subtle)),
                          TextButton(
                            onPressed: () => setState(() => _isSignIn = false),
                            child: Text('Sign Up',
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSignUpCard(bool isDark) {
    final card = isDark ? const Color(0xFF0D1F2D) : Colors.white;
    final strong = isDark ? const Color(0xFFE8F4F0) : const Color(0xFF1A1A1A);
    final subtle = isDark ? const Color(0x73E8F4F0) : const Color(0x991A1A1A);
    final accent = isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);

    return Container(
      key: const ValueKey('SignUp'),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Row(
            children: [
              if (isWide)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(48),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.05),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Join Us!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Enter your personal details and start your journey with us.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: subtle,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Image.asset(
                          'assets/images/signin.png',
                          height: 200,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                              Icons.person_add_outlined,
                              size: 80,
                              color: accent.withOpacity(0.5)),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: strong,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Username',
                        icon: Icons.badge_outlined,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _nameController,
                        label: 'Name',
                        icon: Icons.person_outline,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        isDark: isDark,
                        error: _emailValid ? null : 'Invalid email format',
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        isDark: isDark,
                        isPassword: true,
                        obscure: !_isPasswordVisible,
                        onToggle: () => setState(
                            () => _isPasswordVisible = !_isPasswordVisible),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : const Text('Sign Up',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Already have an account?",
                              style: TextStyle(color: subtle)),
                          TextButton(
                            onPressed: () => setState(() => _isSignIn = true),
                            child: Text('Sign In',
                                style: TextStyle(
                                    color: accent,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? error,
  }) {
    final strong = isDark ? const Color(0xFFE8F4F0) : const Color(0xFF1A1A1A);
    final subtle = isDark ? const Color(0x73E8F4F0) : const Color(0x991A1A1A);
    final accent = isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: strong),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: subtle),
            prefixIcon: Icon(icon, color: subtle, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: subtle,
                        size: 20),
                    onPressed: onToggle,
                  )
                : null,
            filled: true,
            fillColor: isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.white12 : Colors.black.withOpacity(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 1.5),
            ),
            errorText: error,
            errorStyle: const TextStyle(height: 0),
          ),
        ),
      ],
    );
  }

  void _showVerificationDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Verify Your Email',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'A verification code has been sent to your email. Please enter the code below:'),
              const SizedBox(height: 20),
              TextField(
                onChanged: (value) => _verificationCode = value,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _resendVerificationCode,
              child: Text('Resend Code', style: TextStyle(color: accent)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _confirmSignUp();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMigrationDialog({
    String? prefilledEmail,
    String? prefilledPassword,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? const Color(0xFF1FCB8A) : const Color(0xFF0D47A1);
    final migEmailCtrl = TextEditingController(text: prefilledEmail ?? '');
    final migUsernameCtrl = TextEditingController();
    final migPasswordCtrl =
        TextEditingController(text: prefilledPassword ?? '');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_add_alt_1_outlined,
                      color: accent, size: 32),
                  const SizedBox(height: 8),
                  const Text('Set Your Username',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "We've upgraded our system! Please set a username to continue. Your email and password stay the same.",
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 20),
                    if (prefilledEmail == null)
                      ...([
                        TextField(
                          controller: migEmailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: accent, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ]),
                    TextField(
                      controller: migUsernameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Choose a Username',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        hintText: 'e.g. john_doe',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accent, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: migPasswordCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password (confirm)',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: accent, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final email = prefilledEmail ?? migEmailCtrl.text.trim();
                    final username = migUsernameCtrl.text.trim();
                    final password = migPasswordCtrl.text;

                    if (email.isEmpty || !EmailValidator.validate(email)) {
                      _showSnackbar('Please enter a valid email address.');
                      return;
                    }
                    if (username.isEmpty || username.length < 3) {
                      _showSnackbar('Username must be at least 3 characters.');
                      return;
                    }
                    if (password.isEmpty) {
                      _showSnackbar('Please enter your password.');
                      return;
                    }
                    Navigator.of(ctx).pop();
                    await _migrateUser(
                      email: email,
                      username: username,
                      password: password,
                    );
                  },
                  child: const Text('Continue',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _migrateUser({
    required String email,
    required String username,
    required String password,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: SignUpOptions(
          userAttributes: {
            CognitoUserAttributeKey.email: email,
            CognitoUserAttributeKey.preferredUsername: username,
            CognitoUserAttributeKey.name: username,
          },
        ),
      );

      if (res.isSignUpComplete) {
        // Auto sign-in after migration
        final signInRes = await Amplify.Auth.signIn(
          username: username,
          password: password,
        );
        if (signInRes.isSignedIn) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('email', email);
          final userProvider =
              Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(email);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Account migrated! Welcome to the new system.'),
              backgroundColor: Colors.green,
            ),
          );
          NavigationUtils.navigateTo(context, '/', removeUntil: true);
        }
      } else {
        // Email verification required
        _emailToVerify = email;
        _usernameToVerify = username;
        _showVerificationDialog();
      }
    } on UsernameExistsException {
      _showSnackbar('That username is already taken. Please choose another.');
      _showMigrationDialog(prefilledEmail: email, prefilledPassword: password);
    } on AuthException catch (e) {
      _showSnackbar(e.message);
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
