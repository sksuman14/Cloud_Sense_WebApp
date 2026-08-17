import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

enum GuardRequirement {
  superAdmin,
  authenticatedUser,
}

class RouteGuard extends StatefulWidget {
  final Widget child;
  final GuardRequirement requirement;

  // Memory Cache for authentication status to eliminate repeated async checks
  static String? _cachedEmail;
  static bool? _cachedIsAuthenticated;

  const RouteGuard({
    Key? key,
    required this.child,
    this.requirement = GuardRequirement.superAdmin,
  }) : super(key: key);

  /// Clear memory cache upon user logout or session termination
  static void clearCache() {
    _cachedEmail = null;
    _cachedIsAuthenticated = null;
  }

  /// Mark session as authenticated in memory (e.g. after successful login)
  static void setAuthenticatedUser(String email) {
    _cachedEmail = email.trim().toLowerCase();
    _cachedIsAuthenticated = true;
  }

  @override
  State<RouteGuard> createState() => _RouteGuardState();
}

class _RouteGuardState extends State<RouteGuard> {
  bool _isChecking = true;
  bool _isAuthorized = false;
  String? _currentUserEmail;
  String _denialReason = '';

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    // 1. Check in-memory cache first for instant validation without network delay
    if (RouteGuard._cachedIsAuthenticated == true &&
        RouteGuard._cachedEmail != null &&
        RouteGuard._cachedEmail!.isNotEmpty) {
      final cachedEmail = RouteGuard._cachedEmail!;
      if (widget.requirement == GuardRequirement.superAdmin) {
        final isSuper = DeviceUtils.isSuperAdmin(cachedEmail);
        if (mounted) {
          setState(() {
            _currentUserEmail = cachedEmail;
            _isChecking = false;
            _isAuthorized = isSuper;
            _denialReason = isSuper ? '' : 'not_admin';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _currentUserEmail = cachedEmail;
            _isChecking = false;
            _isAuthorized = true;
          });
        }
      }
      return;
    }

    // 2. Cache miss -> perform async check with AWS Amplify Auth
    String? email;
    bool isAmplifyAuthenticated = false;

    // First check active AWS Amplify Auth session
    try {
      final userAttributes = await Amplify.Auth.fetchUserAttributes();
      for (var attr in userAttributes) {
        if (attr.userAttributeKey == AuthUserAttributeKey.email) {
          email = attr.value;
          isAmplifyAuthenticated = true;
          break;
        }
      }
      if (email != null && email.isNotEmpty && mounted) {
        try {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser(email);
        } catch (_) {}
      }
    } catch (_) {
      // Amplify auth session is invalid or user is signed out
      isAmplifyAuthenticated = false;
    }

    // If Amplify Auth fails, clear stale session data
    if (!isAmplifyAuthenticated) {
      RouteGuard.clearCache();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('email');
        await prefs.remove('name');
      } catch (_) {}
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.setUser(null);
      } catch (_) {}
      email = null;
    }

    final normalizedEmail = email?.trim().toLowerCase();

    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      RouteGuard.clearCache();
      debugPrint('[RouteGuard] Access DENIED (Unauthenticated). Requirement: ${widget.requirement}');
      if (mounted) {
        setState(() {
          _isChecking = false;
          _isAuthorized = false;
          _denialReason = 'unauthenticated';
        });
      }
      return;
    }

    // Save to memory cache for fast instant access on subsequent route navigations
    RouteGuard.setAuthenticatedUser(normalizedEmail);

    if (widget.requirement == GuardRequirement.superAdmin) {
      final isSuper = DeviceUtils.isSuperAdmin(normalizedEmail);
      debugPrint('[RouteGuard] Email: $normalizedEmail, SuperAdmin: $isSuper');
      if (mounted) {
        setState(() {
          _currentUserEmail = normalizedEmail;
          _isChecking = false;
          _isAuthorized = isSuper;
          _denialReason = isSuper ? '' : 'not_admin';
        });
      }
    } else {
      // GuardRequirement.authenticatedUser
      debugPrint('[RouteGuard] Access GRANTED for authenticated user: $normalizedEmail');
      if (mounted) {
        setState(() {
          _currentUserEmail = normalizedEmail;
          _isChecking = false;
          _isAuthorized = true;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B141D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF1976D2)),
              SizedBox(height: 16),
              Text(
                'Verifying authorization...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    if (_isAuthorized) {
      return widget.child;
    }

    // Access Denied / Unauthenticated Screen
    final isUnauthenticated = _denialReason == 'unauthenticated';

    return Scaffold(
      backgroundColor: const Color(0xFF0B141D),
      appBar: AppBar(
        title: const Text('Access Restricted'),
        backgroundColor: const Color(0xFF14212B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => NavigationUtils.navigateTo(context, '/home', isReplacement: true),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF192430),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFEF4444),
                  size: 56,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isUnauthenticated ? 'Authentication Required' : 'Access Denied',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isUnauthenticated
                    ? 'You must be logged in to view this page. Please sign in with your account credentials.'
                    : 'Your account (${_currentUserEmail ?? 'User'}) does not have administrator privileges required to access this section.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: Icon(isUnauthenticated ? Icons.login : Icons.home),
                    label: Text(isUnauthenticated ? 'Go to Login' : 'Back to Home'),
                    onPressed: () {
                      if (isUnauthenticated) {
                        NavigationUtils.navigateTo(context, '/login', isReplacement: true);
                      } else {
                        NavigationUtils.navigateTo(context, '/home', isReplacement: true);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
