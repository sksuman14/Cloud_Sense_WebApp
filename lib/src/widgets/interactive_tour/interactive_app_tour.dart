import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/utils/auth_guard.dart';
import 'package:cloud_sense_webapp/src/utils/navigation_utils.dart';

/// Lightweight wrapper widget that safely registers its screen coordinates
/// without using any GlobalKeys (preventing element lifecycle and assertion conflicts).
class TourTarget extends StatefulWidget {
  final String targetId;
  final Widget child;

  const TourTarget({
    Key? key,
    required this.targetId,
    required this.child,
  }) : super(key: key);

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    AppTourGuide.registerTarget(widget.targetId, context);
  }

  @override
  void didUpdateWidget(TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetId != widget.targetId) {
      AppTourGuide.unregisterTarget(oldWidget.targetId);
    }
    AppTourGuide.registerTarget(widget.targetId, context);
  }

  @override
  void dispose() {
    AppTourGuide.unregisterTarget(widget.targetId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTourGuide.registerTarget(widget.targetId, context);
    return widget.child;
  }
}

/// Metadata definition for an on-screen live tour step
class LiveTourStepConfig {
  final int index;
  final String stepTag;
  final String title;
  final String description;
  final String targetButtonLabel;
  final String targetId;
  final String nextButtonText;

  const LiveTourStepConfig({
    required this.index,
    required this.stepTag,
    required this.title,
    required this.description,
    required this.targetButtonLabel,
    required this.targetId,
    this.nextButtonText = 'Next Step >',
  });
}

/// Controller managing the on-screen spotlight walkthrough
class AppTourGuide {
  static OverlayEntry? _overlayEntry;
  static int _currentStepIndex = 0;
  static bool _isActive = false;
  static bool _wasDemoAuthSet = false;

  static final Map<String, BuildContext> _registeredTargets = {};

  static bool get isTourActive => _isActive;
  static int get currentStep => _currentStepIndex;

  static void registerTarget(String id, BuildContext context) {
    _registeredTargets[id] = context;
  }

  static void unregisterTarget(String id) {
    _registeredTargets.remove(id);
  }

  static Rect? getTargetRect(String id) {
    try {
      final ctx = _registeredTargets[id];
      if (ctx == null || !ctx.mounted) return null;
      final renderBox = ctx.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize || !renderBox.attached) return null;
      final offset = renderBox.localToGlobal(Offset.zero);
      return Rect.fromLTWH(
        offset.dx,
        offset.dy,
        renderBox.size.width,
        renderBox.size.height,
      );
    } catch (_) {
      return null;
    }
  }

  static void scrollToTarget(String id) {
    try {
      final ctx = _registeredTargets[id];
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      }
    } catch (_) {}
  }

  // Active step change listener
  static final ValueNotifier<int> activeStepNotifier = ValueNotifier<int>(0);

  static final List<LiveTourStepConfig> steps = [
    // Step 0: My Devices button on Home page
    LiveTourStepConfig(
      index: 0,
      stepTag: 'STEP 1 OF 10 · HOME PAGE',
      title: '1. "My Devices" Button',
      description:
          'Click this button to access your connected stations.\n\n'
          '👉 For normal users: If you are not signed in, clicking here prompts Login or Sign Up. If already signed in, it opens your Device List directly.',
      targetButtonLabel: 'My Devices',
      targetId: 'my_devices',
      nextButtonText: 'Next: Login / Sign Up >',
    ),

    // Step 1: Login / Sign Up prompt
    LiveTourStepConfig(
      index: 1,
      stepTag: 'STEP 2 OF 10 · AUTHENTICATION',
      title: '2. Login or Sign Up',
      description:
          'Enter your email and password to log in, or switch to "Sign Up" to register.\n\n'
          '👉 You can enter your credentials and click "Sign In" directly, or click "Next" below to preview with a demo account.',
      targetButtonLabel: 'Login / Sign Up Form',
      targetId: 'login_card',
      nextButtonText: 'Next: Device List >',
    ),

    // Step 2: Device List page
    LiveTourStepConfig(
      index: 2,
      stepTag: 'STEP 3 OF 10 · DEVICE LIST',
      title: '3. Your Device Fleet',
      description:
          'This is your devices hub. Here you see all your registered IoT stations, their status (Active Today / Inactive), and battery levels.',
      targetButtonLabel: 'Device List Overview',
      targetId: 'add_device_btn',
      nextButtonText: 'Next: Add Device >',
    ),

    // Step 3: Add Device button
    LiveTourStepConfig(
      index: 3,
      stepTag: 'STEP 4 OF 10 · PAIRING HARDWARE',
      title: '4. "Add Device" Button',
      description:
          'Click this green button whenever you want to pair a new weather station or IoT sensor to your account.',
      targetButtonLabel: 'Add Device',
      targetId: 'add_device_btn',
      nextButtonText: 'Next: Choose Add Manually >',
    ),

    // Step 4: Add Manually button inside Add New Device dialog
    LiveTourStepConfig(
      index: 4,
      stepTag: 'STEP 5 OF 10 · PAIRING OPTIONS',
      title: '5. Choose "Add Manually"',
      description:
          'In the popup, click "Add Manually" to register your station using templates and your device serial number.',
      targetButtonLabel: 'Add Manually',
      targetId: 'add_manually_btn',
      nextButtonText: 'Next: Select Device Type >',
    ),

    // Step 5: Select Device Type / Category template chips
    LiveTourStepConfig(
      index: 5,
      stepTag: 'STEP 6 OF 10 · MANUAL ENTRY',
      title: '6. Select Device Type',
      description:
          'Tap the chip matching your hardware model (e.g. ANNAM Weather ⛅, Soil Sensor 🌱, Water Quality 💧).\n\n'
          '👉 Tapping a chip automatically inserts the correct system prefix into the box for you!',
      targetButtonLabel: 'Device Templates',
      targetId: 'template_chips',
      nextButtonText: 'Next: Write Device ID >',
    ),

    // Step 6: Enter Device ID
    LiveTourStepConfig(
      index: 6,
      stepTag: 'STEP 7 OF 10 · MANUAL ENTRY',
      title: '7. Write Device ID',
      description:
          'Type your hardware serial number or numeric node ID (e.g. 01, 101, 214).\n\n'
          '👉 The real-time validator console below automatically checks the format with a green checkmark ✅.',
      targetButtonLabel: 'Enter Device ID',
      targetId: 'device_id_input',
      nextButtonText: 'Next: Confirm & Add >',
    ),

    // Step 7: Confirm & Add button
    LiveTourStepConfig(
      index: 7,
      stepTag: 'STEP 8 OF 10 · MANUAL ENTRY',
      title: '8. "Confirm & Add" Button',
      description:
          'Click "Confirm & Add" to bind the station to your account.\n\n'
          '👉 Your device will now appear on your Device List and start reporting telemetry.',
      targetButtonLabel: 'Confirm & Add',
      targetId: 'confirm_add_btn',
      nextButtonText: 'Next: Tap Device Card >',
    ),

    // Step 8: Device card tap
    LiveTourStepConfig(
      index: 8,
      stepTag: 'STEP 9 OF 10 · ACCESS TELEMETRY',
      title: '9. Tap Device Card to Open Graphs',
      description:
          'Click anywhere on your device card to open its live telemetry and graphs dashboard!\n\n'
          '👉 The Device Graph page will open showing real-time temperature, humidity, rain, wind, and historical curves.',
      targetButtonLabel: 'Device Card',
      targetId: 'device_card',
      nextButtonText: 'Next: View Graphs & Controls >',
    ),

    // Step 9: Device Graph Controls & Analysis
    LiveTourStepConfig(
      index: 9,
      stepTag: 'STEP 10 OF 10 · TELEMETRY & CONTROLS',
      title: '10. Time Range & Sensor Analysis',
      description:
          'Switch between Single Day, 7 Days, 30 Days, 3 Months, or 1 Year to analyze historical trends.\n\n'
          '👉 Scroll down to explore parameter curves (temperature, humidity, pressure, wind), toggle parameters, or download CSV data.',
      targetButtonLabel: 'Time Range Controls',
      targetId: 'graph_controls',
      nextButtonText: 'Finish Tour 🎉',
    ),
  ];

  /// Start the live on-screen tour
  static void startTour(BuildContext context, {int initialStep = 0}) {
    stopTour();

    _isActive = true;
    _currentStepIndex = initialStep.clamp(0, steps.length - 1);
    activeStepNotifier.value = _currentStepIndex;

    final overlay = Overlay.of(context, rootOverlay: true);

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _LiveTourOverlayView(
        onClose: stopTour,
        onNext: () => nextStep(context),
        onPrev: () => prevStep(context),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  /// Stop and dismiss the live tour overlay
  static void stopTour() {
    _isActive = false;
    _overlayEntry?.remove();
    _overlayEntry = null;

    if (_wasDemoAuthSet) {
      _wasDemoAuthSet = false;
      RouteGuard.clearCache();
    }
  }

  /// Move to next on-screen step with contextual actions
  static void nextStep(BuildContext context) {
    if (_currentStepIndex >= steps.length - 1) {
      stopTour();
      return;
    }

    if (_currentStepIndex == 0) {
      // Step 0: User was on My Devices on Home page -> go to login
      _currentStepIndex = 1;
      activeStepNotifier.value = _currentStepIndex;
      NavigationUtils.navigateTo(context, '/login');
    } else if (_currentStepIndex == 1) {
      // From login -> navigate to /devicelist
      bool hasRealUser = false;
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (userProvider.userEmail != null &&
            userProvider.userEmail!.isNotEmpty &&
            userProvider.userEmail != 'demo.user@cloudsense.io') {
          hasRealUser = true;
          RouteGuard.setAuthenticatedUser(userProvider.userEmail!);
        }
      } catch (_) {}

      if (!hasRealUser) {
        _wasDemoAuthSet = true;
        RouteGuard.setAuthenticatedUser('demo.user@cloudsense.io');
        try {
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          userProvider.setUser('demo.user@cloudsense.io');
        } catch (_) {}
      }

      _currentStepIndex = 2;
      activeStepNotifier.value = _currentStepIndex;
      NavigationUtils.navigateTo(context, '/devicelist');
    } else if (_currentStepIndex == 2 || _currentStepIndex == 3) {
      _currentStepIndex = 4;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 4) {
      _currentStepIndex = 5;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 5) {
      _currentStepIndex = 6;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 6) {
      _currentStepIndex = 7;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 7) {
      _currentStepIndex = 8;
      activeStepNotifier.value = _currentStepIndex;
      Navigator.of(context, rootNavigator: true).maybePop();
    } else if (_currentStepIndex == 8) {
      _currentStepIndex = 9;
      activeStepNotifier.value = _currentStepIndex;
      NavigationUtils.navigateTo(
        context,
        '/devicegraph',
        arguments: {
          'deviceName': 'ANNAM_CP02',
          'sequentialName': 'Annam Weather Sensor',
          'backgroundImagePath': 'assets/backgroundd.jpg',
        },
      );
    } else if (_currentStepIndex == 9) {
      stopTour();
    } else {
      _currentStepIndex++;
      activeStepNotifier.value = _currentStepIndex;
    }

    _overlayEntry?.markNeedsBuild();
  }

  /// Move to previous step
  static void prevStep(BuildContext context) {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      activeStepNotifier.value = _currentStepIndex;
      _overlayEntry?.markNeedsBuild();
    }
  }

  /// Launch specifically from device list page
  static void showDeviceListGuide(BuildContext context) {
    startTour(context, initialStep: 2);
  }

  /// Launch specifically for manual entry
  static void showAddDeviceGuide(BuildContext context) {
    startTour(context, initialStep: 5);
  }

  /// Launch specifically for device graph
  static void showGraphGuide(BuildContext context) {
    startTour(context, initialStep: 9);
  }
}

/// Overlay widget rendering the real-time cutout spotlight & attached popup bubble
class _LiveTourOverlayView extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _LiveTourOverlayView({
    Key? key,
    required this.onClose,
    required this.onNext,
    required this.onPrev,
  }) : super(key: key);

  @override
  _LiveTourOverlayViewState createState() => _LiveTourOverlayViewState();
}

class _LiveTourOverlayViewState extends State<_LiveTourOverlayView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  int _lastScrolledStep = -1;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _checkScrollToTarget(int stepIndex, String targetId) {
    if (_lastScrolledStep == stepIndex) return;
    _lastScrolledStep = stepIndex;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppTourGuide.scrollToTarget(targetId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppTourGuide.activeStepNotifier,
      builder: (context, stepIndex, _) {
        final step = AppTourGuide.steps[stepIndex];

        // Auto-scroll once when step changes
        _checkScrollToTarget(stepIndex, step.targetId);

        return AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, _) {
            // Safely measure target rect from registered targets map dynamically on each tick
            final targetRect = AppTourGuide.getTargetRect(step.targetId);

        final size = MediaQuery.of(context).size;
        final isMobile = size.width < 700;
        final tooltipWidth = isMobile ? size.width - 32 : 380.0;

        // Position calculation: above or below the target button
        double? topPos;
        double? bottomPos;
        bool arrowPointsUp = true;

        if (targetRect != null) {
          final spaceBelow = size.height - targetRect.bottom;
          if (spaceBelow > 230 || spaceBelow > targetRect.top) {
            topPos = targetRect.bottom + 14;
            arrowPointsUp = true;
          } else {
            bottomPos = (size.height - targetRect.top) + 14;
            arrowPointsUp = false;
          }
        } else {
          topPos = size.height * 0.35;
          arrowPointsUp = false;
        }

        // Horizontal alignment: clamp within screen margins
        double leftPos;
        if (targetRect != null) {
          final targetCenterX = targetRect.center.dx;
          leftPos = (targetCenterX - (tooltipWidth / 2))
              .clamp(16.0, size.width - tooltipWidth - 16.0);
        } else {
          leftPos = ((size.width - tooltipWidth) / 2).clamp(16.0, size.width - tooltipWidth - 16.0);
        }

        final arrowX = targetRect != null
            ? (targetRect.center.dx - leftPos).clamp(24.0, tooltipWidth - 24.0)
            : tooltipWidth / 2;

        return Stack(
          children: [
            // 1. Semi-transparent dark overlay with live cutout hole (purely visual, ignores all touches)
            IgnorePointer(
              child: CustomPaint(
                size: size,
                painter: _SpotlightHolePainter(
                  targetRect: targetRect,
                  pulse: _pulseAnimation.value,
                ),
              ),
            ),

            // 2. Click shield that blocks clicks on the dark dimmed area,
            // but lets touches INSIDE targetRect pass straight through to the underlying page!
            Positioned.fill(
              child: _SpotlightHitFilter(
                targetRect: targetRect != null ? targetRect.inflate(6) : null,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // 3. Anchored Popup Callout Tooltip pointing directly to the actual button
            Positioned(
              top: topPos,
              bottom: bottomPos,
              left: leftPos,
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(
                  width: tooltipWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Upward pointer arrow
                      if (arrowPointsUp)
                        Padding(
                          padding: EdgeInsets.only(left: arrowX - 10),
                          child: CustomPaint(
                            size: const Size(20, 10),
                            painter: _ArrowPointerPainter(isPointingUp: true),
                          ),
                        ),

                      // Tooltip Card Body
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0284C7).withOpacity(0.35),
                              blurRadius: 24,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.7),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tag Header & Close X
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    step.stepTag,
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: widget.onClose,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Icon(Icons.close, color: Colors.white70, size: 18),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Title
                            Text(
                              step.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Target badge
                            Row(
                              children: [
                                const Icon(Icons.gps_fixed, size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                Text(
                                  'Points to: ${step.targetButtonLabel}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Explanation text
                            Text(
                              step.description,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Navigation Action Buttons
                            Row(
                              children: [
                                TextButton(
                                  onPressed: widget.onClose,
                                  child: const Text(
                                    'Skip Tour',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (stepIndex > 0) ...[
                                  OutlinedButton(
                                    onPressed: widget.onPrev,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white24),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Back', style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                ElevatedButton.icon(
                                  onPressed: widget.onNext,
                                  icon: Icon(
                                    stepIndex == AppTourGuide.steps.length - 1
                                        ? Icons.check
                                        : Icons.arrow_forward,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    stepIndex == AppTourGuide.steps.length - 1
                                        ? 'Finish Tour 🎉'
                                        : step.nextButtonText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: stepIndex == AppTourGuide.steps.length - 1
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF0284C7),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Downward pointer arrow
                      if (!arrowPointsUp)
                        Padding(
                          padding: EdgeInsets.only(left: arrowX - 10),
                          child: CustomPaint(
                            size: const Size(20, 10),
                            painter: _ArrowPointerPainter(isPointingUp: false),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
          },
        );
      },
    );
  }
}

/// CustomPainter cutting out a hole in the overlay directly over the actual website button
class _SpotlightHolePainter extends CustomPainter {
  final Rect? targetRect;
  final double pulse;

  _SpotlightHolePainter({required this.targetRect, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final overlayPaint = Paint()..color = const Color(0xD9040914);

    if (targetRect == null) {
      canvas.drawRect(fullRect, overlayPaint);
      return;
    }

    // Save layer to punch out the transparent hole
    canvas.saveLayer(fullRect, Paint());
    canvas.drawRect(fullRect, overlayPaint);

    final paddedRect = targetRect!.inflate(6);
    final rrect = RRect.fromRectAndRadius(paddedRect, const Radius.circular(12));

    // Punch out the clear hole so the real button shows through with 100% clarity
    canvas.drawRRect(rrect, Paint()..blendMode = BlendMode.clear);
    canvas.restore();

    // Draw pulsating illuminated border around the real button
    final pulseExtra = 4 * pulse;
    final glowingRRect = RRect.fromRectAndRadius(
      targetRect!.inflate(6 + pulseExtra),
      const Radius.circular(14),
    );

    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8).withOpacity(0.5 + (0.5 * (1.0 - pulse)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawRRect(glowingRRect, borderPaint);
  }

  @override
  bool? hitTest(Offset position) => false;

  @override
  bool shouldRepaint(covariant _SpotlightHolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect || oldDelegate.pulse != pulse;
  }
}

/// Painter drawing the directional pointer triangle arrow on the tooltip bubble
class _ArrowPointerPainter extends CustomPainter {
  final bool isPointingUp;

  _ArrowPointerPainter({required this.isPointingUp});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    if (isPointingUp) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


/// Allows touch and pointer events inside [targetRect] (the illuminated cutout hole)
/// to pass directly through to the underlying page widgets (such as text fields, buttons, etc.),
/// while absorbing touches on the dark dimmed backdrop.
class _SpotlightHitFilter extends SingleChildRenderObjectWidget {
  final Rect? targetRect;

  const _SpotlightHitFilter({
    Key? key,
    required this.targetRect,
    required Widget child,
  }) : super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSpotlightHitFilter(targetRect);

  @override
  void updateRenderObject(
      BuildContext context, covariant _RenderSpotlightHitFilter renderObject) {
    renderObject.targetRect = targetRect;
  }
}

class _RenderSpotlightHitFilter extends RenderProxyBox {
  Rect? targetRect;

  _RenderSpotlightHitFilter(this.targetRect);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // If the pointer event is inside the illuminated cutout hole,
    // do not hit test this overlay shield. Let the event fall through to the real widgets!
    if (targetRect != null) {
      final globalPos = localToGlobal(position);
      if (targetRect!.contains(globalPos)) {
        return false;
      }
    }
    return super.hitTest(result, position: position);
  }
}
