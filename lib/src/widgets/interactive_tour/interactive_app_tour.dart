import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
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

  static String? lastAddedDeviceId;
  static String? lastAddedDeviceSequentialName;

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

  // Contextual action triggers
  static VoidCallback? onTriggerAddDeviceDialog;
  static VoidCallback? onTriggerManualEntry;
  static VoidCallback? onTriggerConfirmAdd;
  static VoidCallback? onTriggerSelectTopic;
  static VoidCallback? onTriggerConfirmYes;
  static ValueChanged<String>? onAutoFillDeviceId;

  static void goToStep(BuildContext context, int stepIndex) {
    if (stepIndex >= 0 && stepIndex < steps.length) {
      _currentStepIndex = stepIndex;
      activeStepNotifier.value = _currentStepIndex;
      _overlayEntry?.markNeedsBuild();
    }
  }

  // Active step change listener
  static final ValueNotifier<int> activeStepNotifier = ValueNotifier<int>(0);

  static final List<LiveTourStepConfig> steps = [
    // Step 0: My Devices button on Home page
    LiveTourStepConfig(
      index: 0,
      stepTag: 'STEP 1 OF 11 · HOME PAGE',
      title: '1. "My Devices" Button',
      description:
          'Click this button to access your connected stations.\n\n'
          '👉 For normal users: If you are not signed in, clicking here prompts Login or Sign Up. If already signed in, it opens your Device List directly.',
      targetButtonLabel: 'My Devices',
      targetId: 'my_devices',
      nextButtonText: 'Next: Login >',
    ),

    // Step 1: Login / Sign Up prompt
    LiveTourStepConfig(
      index: 1,
      stepTag: 'STEP 2 OF 11 · AUTHENTICATION',
      title: '2. Login or Sign Up',
      description:
          'Enter your email and password to log in, or switch to "Sign Up" to register.\n\n'
          '👉 You can enter your credentials and click "Sign In" directly, or click "Next" below to preview with a demo account.',
      targetButtonLabel: 'Login / Sign Up Form',
      targetId: 'login_card',
      nextButtonText: 'Next: Device List >',
    ),

    // Step 2: Add Device button on Device List page
    LiveTourStepConfig(
      index: 2,
      stepTag: 'STEP 3 OF 11 · DEVICE FLEET',
      title: '3. "Add Device" Button',
      description:
          'Click the green "+ Add Device" button to pair and register a new weather station to your account.',
      targetButtonLabel: '+ Add Device',
      targetId: 'add_device_btn',
      nextButtonText: 'Next: Method >',
    ),

    // Step 3: Choose QR or Manual Entry in pairing dialog
    LiveTourStepConfig(
      index: 3,
      stepTag: 'STEP 4 OF 11 · PAIRING OPTIONS',
      title: '4. Choose QR or Manual Entry',
      description:
          'Choose either "Scan QR Code" (to scan the QR sticker on the device) or "Add Manually" (to enter the serial number or model ID).\n\n'
          '👉 Click "Add Manually" to enter your device serial number!',
      targetButtonLabel: 'Pairing Options',
      targetId: 'pairing_choices',
      nextButtonText: 'Next: Add Manually >',
    ),

    // Step 4: Select Device Template in manual entry dialog
    LiveTourStepConfig(
      index: 4,
      stepTag: 'STEP 5 OF 11 · DEVICE TEMPLATES',
      title: '5. Select Device Template',
      description:
          'Select a template category like "ANNAM Weather ⛅", "Sobha Sensor 🏠", or "CPS Sensor 🌡️" to auto-fill the device prefix.\n\n'
          '👉 Tap any template chip to select it, or click "Next" to type your custom Station ID directly!',
      targetButtonLabel: 'Device Templates',
      targetId: 'template_chips',
      nextButtonText: 'Next: Enter ID >',
    ),

    // Step 5: Enter Device ID in manual entry dialog
    LiveTourStepConfig(
      index: 5,
      stepTag: 'STEP 6 OF 11 · MANUAL ENTRY',
      title: '6. Enter Device ID',
      description:
          'Type or complete your Station ID (e.g. ANNAM-250, 01, 214).\n\n'
          '👉 Once you enter a Device ID, the tour automatically highlights "Confirm & Add"!',
      targetButtonLabel: 'Enter Device ID',
      targetId: 'device_id_input',
      nextButtonText: 'Next: Confirm & Add >',
    ),

    // Step 6: Confirm & Add button
    LiveTourStepConfig(
      index: 6,
      stepTag: 'STEP 7 OF 11 · CONFIRM REGISTRATION',
      title: '7. "Confirm & Add" Button',
      description:
          'Click "Confirm & Add" to register this device to your account.\n\n'
          '👉 If multiple installation topics exist for your device, you will be prompted to select your station topic next.',
      targetButtonLabel: 'Confirm & Add',
      targetId: 'confirm_add_btn',
      nextButtonText: 'Next: Select Topic >',
    ),

    // Step 7: Select Device Topic (when candidates > 1)
    LiveTourStepConfig(
      index: 7,
      stepTag: 'STEP 8 OF 11 · DEVICE TOPIC',
      title: '8. Select Device Topic',
      description:
          'Multiple installation topics were found for this device ID.\n\n'
          '👉 Tap your station\'s deployment topic (e.g. SSMet, Kerala, or Punjab) to select it and proceed to confirmation!',
      targetButtonLabel: 'Device Topics List',
      targetId: 'device_topic_choice',
      nextButtonText: 'Next: Confirm Addition >',
    ),

    // Step 8: Confirm Device Addition dialog
    LiveTourStepConfig(
      index: 8,
      stepTag: 'STEP 9 OF 11 · CONFIRMATION',
      title: '9. Confirm Device Addition',
      description:
          'Review the prompt and click "Yes" to confirm adding this station to your account.\n\n'
          '👉 Once confirmed, the station will be paired and added to your device fleet!',
      targetButtonLabel: 'Confirm "Yes"',
      targetId: 'confirm_addition_dialog',
      nextButtonText: 'Next: Confirm Yes >',
    ),

    // Step 9: Device card tap
    LiveTourStepConfig(
      index: 9,
      stepTag: 'STEP 10 OF 11 · ACCESS TELEMETRY',
      title: '10. Tap Device Card to Open Graphs',
      description:
          'Click anywhere on your device card to open its live telemetry and graphs dashboard!\n\n'
          '👉 The Device Graph page will open showing real-time temperature, humidity, rain, wind, and historical curves.',
      targetButtonLabel: 'Device Card',
      targetId: 'device_card',
      nextButtonText: 'Next: View Graphs >',
    ),

    // Step 10: Device Graph Controls & Analysis
    LiveTourStepConfig(
      index: 10,
      stepTag: 'STEP 11 OF 11 · TELEMETRY & CONTROLS',
      title: '11. Time Range & Sensor Analysis',
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

    if (initialStep == 0) {
      lastAddedDeviceId = null;
      lastAddedDeviceSequentialName = null;
    }

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
    lastAddedDeviceId = null;
    lastAddedDeviceSequentialName = null;

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
    } else if (_currentStepIndex == 2) {
      // From Add Device button -> open pairing options dialog
      _currentStepIndex = 3;
      activeStepNotifier.value = _currentStepIndex;
      onTriggerAddDeviceDialog?.call();
    } else if (_currentStepIndex == 3) {
      // From pairing options dialog -> open manual entry popup
      _currentStepIndex = 4;
      activeStepNotifier.value = _currentStepIndex;
      onTriggerManualEntry?.call();
    } else if (_currentStepIndex == 4) {
      // From select device templates -> move to enter device id
      onAutoFillDeviceId?.call('ANNAM-');
      _currentStepIndex = 5;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 5) {
      // From enter device id -> move to Confirm & Add (complete with sample ID)
      onAutoFillDeviceId?.call('ANNAM-250');
      _currentStepIndex = 6;
      activeStepNotifier.value = _currentStepIndex;
    } else if (_currentStepIndex == 6) {
      // From confirm & add -> trigger action or move to topic choice
      if (onTriggerConfirmAdd != null) {
        onTriggerConfirmAdd!();
      } else {
        _currentStepIndex = 7;
        activeStepNotifier.value = _currentStepIndex;
      }
    } else if (_currentStepIndex == 7) {
      // From select device topic -> trigger auto-select topic if modal is open
      if (onTriggerSelectTopic != null) {
        onTriggerSelectTopic!();
      } else {
        _currentStepIndex = 8;
        activeStepNotifier.value = _currentStepIndex;
      }
    } else if (_currentStepIndex == 8) {
      // From confirm addition dialog -> trigger "Yes" confirmation
      if (onTriggerConfirmYes != null) {
        onTriggerConfirmYes!();
      } else {
        _currentStepIndex = 9;
        activeStepNotifier.value = _currentStepIndex;
      }
    } else if (_currentStepIndex == 9) {
      // From device card -> open device graph for the newly added device
      _currentStepIndex = 10;
      activeStepNotifier.value = _currentStepIndex;
      final targetDev = lastAddedDeviceId ?? 'ANNAM_CP02';
      final targetSeq = lastAddedDeviceSequentialName ?? 'Annam Weather Sensor';
      NavigationUtils.navigateTo(
        context,
        '/devicegraph',
        arguments: {
          'deviceName': targetDev,
          'sequentialName': targetSeq,
          'backgroundImagePath': 'assets/backgroundd.jpg',
        },
      );
    } else if (_currentStepIndex == 10) {
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
    startTour(context, initialStep: 4);
  }

  /// Launch specifically for device graph
  static void showGraphGuide(BuildContext context) {
    startTour(context, initialStep: 10);
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
        final tooltipWidth = isMobile ? (size.width - 32).clamp(280.0, 360.0) : 400.0;

        // Position calculation: intelligently place above or below to NEVER clip off-screen
        double? topPos;
        double? bottomPos;
        bool arrowPointsUp = true;
        const estimatedTooltipHeight = 260.0;

        if (targetRect != null) {
          final spaceBelow = size.height - targetRect.bottom;
          final spaceAbove = targetRect.top;

          // If space below is not enough for the full tooltip, or if there is substantially more space above:
          if (spaceBelow < estimatedTooltipHeight + 20 && spaceAbove > spaceBelow) {
            bottomPos = (size.height - targetRect.top) + 14;
            arrowPointsUp = false;
          } else if (spaceBelow >= estimatedTooltipHeight + 20) {
            topPos = targetRect.bottom + 14;
            arrowPointsUp = true;
          } else {
            // Screen is tight: place on whichever side has more space
            if (spaceAbove >= spaceBelow) {
              bottomPos = ((size.height - targetRect.top) + 14).clamp(16.0, (size.height - estimatedTooltipHeight - 16.0).clamp(16.0, size.height));
              arrowPointsUp = false;
            } else {
              topPos = (targetRect.bottom + 14).clamp(16.0, (size.height - estimatedTooltipHeight - 16.0).clamp(16.0, size.height));
              arrowPointsUp = true;
            }
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

                      // Tooltip Card Body (Constrained with SingleChildScrollView to prevent vertical overflow)
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: (size.height - 30).clamp(200.0, 520.0),
                        ),
                        padding: const EdgeInsets.all(16),
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
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
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
                                  'Points to: ${(step.index == 9 && AppTourGuide.lastAddedDeviceId != null) ? DevicePrefixUtils.toAnnamDisplayName(AppTourGuide.lastAddedDeviceId!) : step.targetButtonLabel}',
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

                            // Navigation Action Buttons (with Wrap to eliminate all overflow risks)
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: widget.onClose,
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white54,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Skip Tour',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (stepIndex > 0)
                                        OutlinedButton(
                                          onPressed: widget.onPrev,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            side: const BorderSide(color: Colors.white24),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Back', style: TextStyle(fontSize: 12)),
                                        ),
                                      ElevatedButton.icon(
                                        onPressed: widget.onNext,
                                        icon: Icon(
                                          stepIndex == AppTourGuide.steps.length - 1
                                              ? Icons.check
                                              : Icons.arrow_forward,
                                          size: 13,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          stepIndex == AppTourGuide.steps.length - 1
                                              ? 'Finish Tour 🎉'
                                              : step.nextButtonText,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: stepIndex == AppTourGuide.steps.length - 1
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFF0284C7),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          minimumSize: Size.zero,
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          elevation: 2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          ),
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
