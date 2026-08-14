import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/ksdma_theme.dart';
import '../services/ksdma_state_service.dart';
import '../models/ksdma_models.dart';
import 'ksdma_public_dashboard_view.dart';
import 'ksdma_registration_view.dart';
import 'ksdma_volunteer_view.dart';
import 'ksdma_observation_entry_view.dart';
import 'ksdma_officer_view.dart';
import 'ksdma_admin_view.dart';
import 'ksdma_champions_view.dart';
import 'ksdma_map_views.dart';
import 'ksdma_resources_view.dart';
import 'ksdma_auth_modal.dart';

class KsdmaPortalMainPage extends StatefulWidget {
  final int initialMenuIndex;
  final VoidCallback? onLogout;

  const KsdmaPortalMainPage({super.key, this.initialMenuIndex = 0, this.onLogout});

  @override
  State<KsdmaPortalMainPage> createState() => _KsdmaPortalMainPageState();
}

class _KsdmaPortalMainPageState extends State<KsdmaPortalMainPage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _activeMenuIndex;
  bool _isMapViewExpanded = true;
  String? _targetObservationStationId;

  @override
  void initState() {
    super.initState();
    _activeMenuIndex = widget.initialMenuIndex;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<KsdmaStateService>(
      create: (_) => KsdmaStateService(),
      child: Consumer<KsdmaStateService>(
        builder: (context, state, _) {
          final userRole = state.currentUser.role;
          final userCategory = state.currentUser.category;
          final isAdmin = userRole == UserRole.admin || userCategory == UserCategory.adminHq || state.currentUser.fullName.contains('Admin');
          final isOfficer = userRole == UserRole.officer || userCategory == UserCategory.districtOfficer || state.currentUser.fullName.contains('Officer');
          final isVolunteer = !isAdmin && !isOfficer;

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 950;

              final sidebarContent = _buildSidebarContent(state, isVolunteer, isOfficer, isAdmin, isMobile);

              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: KsdmaColors.bg,
                drawer: isMobile
                    ? Drawer(
                        width: 270,
                        backgroundColor: KsdmaColors.primaryDark,
                        child: sidebarContent,
                      )
                    : null,
                body: Row(
                  children: [
                    // Desktop Sidebar
                    if (!isMobile)
                      Container(
                        width: 250,
                        color: KsdmaColors.primaryDark,
                        child: sidebarContent,
                      ),

                    // Main Content Area + Top Bar
                    Expanded(
                      child: Column(
                        children: [
                          // Top Header Ribbon
                          Container(
                            height: 56,
                            padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
                            decoration: const BoxDecoration(
                              color: KsdmaColors.primaryDark,
                              border: Border(bottom: BorderSide(color: Colors.white12)),
                            ),
                            child: Row(
                              children: [
                                if (isMobile) ...[
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                    icon: const Icon(Icons.menu, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 4),
                                ],

                                Container(
                                  width: isMobile ? 24 : 28,
                                  height: isMobile ? 24 : 28,
                                  decoration: BoxDecoration(
                                    color: KsdmaColors.gold,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.water_drop, color: KsdmaColors.primaryDark, size: isMobile ? 14 : 16),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 4 : 10),
                                Builder(
                                  builder: (context) {
                                    final now = DateTime.now();
                                    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                                    final dayStr = now.day.toString().padLeft(2, '0');
                                    final monthStr = months[now.month - 1];
                                    final yearStr = now.year.toString();
                                    final hour = now.hour == 0 ? 12 : (now.hour > 12 ? now.hour - 12 : now.hour);
                                    final hourStr = hour.toString().padLeft(2, '0');
                                    final minStr = now.minute.toString().padLeft(2, '0');
                                    final amPm = now.hour >= 12 ? 'PM' : 'AM';
                                    final dateFormatted = isMobile
                                        ? '$dayStr $monthStr, $hourStr:$minStr $amPm'
                                        : '$dayStr $monthStr $yearStr, $hourStr:$minStr $amPm';

                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            dateFormatted,
                                            style: TextStyle(fontSize: isMobile ? 9.5 : 11, color: const Color(0xFFCFE2DC), fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        if (!isMobile) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: KsdmaColors.leafTint,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              children: [
                                                Icon(Icons.sensors, size: 12, color: KsdmaColors.leaf),
                                                SizedBox(width: 4),
                                                Text('Live Sync', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: KsdmaColors.leaf)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),

                                const Spacer(),

                                if (!state.isLoggedIn) ...[
                                  ElevatedButton.icon(
                                    onPressed: () => KsdmaAuthModal.show(
                                      context,
                                      state,
                                      onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx),
                                    ),
                                    icon: const Icon(Icons.login, size: 14),
                                    label: Text(isMobile ? 'Sign In' : 'Sign In / Register', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: KsdmaColors.gold,
                                      foregroundColor: KsdmaColors.primaryDark,
                                      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      elevation: 0,
                                    ),
                                  ),
                                ] else ...[
                                  Flexible(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: KsdmaColors.goldTint,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: KsdmaColors.gold),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(isAdmin ? Icons.security : isOfficer ? Icons.verified_user : Icons.person, size: 10, color: KsdmaColors.goldDark),
                                              const SizedBox(width: 3),
                                              Text(
                                                isAdmin
                                                    ? 'HQ Admin'
                                                    : isOfficer
                                                        ? 'Officer'
                                                        : 'Volunteer',
                                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: KsdmaColors.goldDark),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (state.currentUser.fullName.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            state.currentUser.fullName.split(' ').first,
                                            style: TextStyle(fontSize: isMobile ? 10 : 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          // Scrollable Dynamic Content View
                          Expanded(
                            child: _buildMainView(state),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSidebarContent(KsdmaStateService state, bool isVolunteer, bool isOfficer, bool isAdmin, bool isMobile) {
    return Column(
      children: [
        // KSDMA Emblem Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  color: KsdmaColors.primary,
                ),
                child: const Center(
                  child: Icon(Icons.shield, color: KsdmaColors.gold, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Kerala Citizen Weather',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    Text(
                      'Observation Network',
                      style: TextStyle(color: Color(0xFFB7CFC7), fontSize: 10),
                    ),
                    Text(
                      'Kerala State Disaster Management Authority',
                      style: TextStyle(color: Colors.grey, fontSize: 8),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Navigation Menu List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            children: [
              _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined, isMobile: isMobile),
              
              if (isVolunteer)
                _buildNavItem(1, 'My Observations', Icons.assignment_outlined, isMobile: isMobile),

              _buildNavItem(
                2,
                'Map View',
                Icons.map_outlined,
                hasChildren: true,
                isExpanded: _isMapViewExpanded,
                onExpandToggle: () => setState(() => _isMapViewExpanded = !_isMapViewExpanded),
                isMobile: isMobile,
              ),

              if (_isMapViewExpanded) ...[
                _buildSubNavItem(10, 'State View', isActive: _activeMenuIndex == 10, isMobile: isMobile),
                _buildSubNavItem(11, 'District View', isActive: _activeMenuIndex == 11, isMobile: isMobile),
                _buildSubNavItem(12, 'Taluk View', isActive: _activeMenuIndex == 12, isMobile: isMobile),
                _buildSubNavItem(2, 'Grama Panchayat View', isActive: _activeMenuIndex == 2, isMobile: isMobile),
                _buildSubNavItem(13, 'Station View', isActive: _activeMenuIndex == 13, isMobile: isMobile),
              ],

              if (isOfficer && !isAdmin)
                _buildNavItem(3, 'Officer Reports', Icons.bar_chart_outlined, isMobile: isMobile),

              _buildNavItem(4, 'Weather Champions', Icons.emoji_events_outlined, isMobile: isMobile),
              _buildNavItem(5, 'Tutorials & Manuals', Icons.book_outlined, isMobile: isMobile),
              
              if (!isAdmin && !isOfficer)
                _buildNavItem(6, 'Register Instrument', Icons.add_circle_outline, isMobile: isMobile),

              if (isAdmin)
                _buildNavItem(7, 'Admin Dashboard', Icons.admin_panel_settings_outlined, isMobile: isMobile),
            ],
          ),
        ),

        // Bottom Logout / Auth Box
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF142B27),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: const [
                  Icon(Icons.groups, color: KsdmaColors.gold, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Citizen Science Kerala',
                      style: TextStyle(color: Color(0xFFCFE2DC), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              if (state.isLoggedIn) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (isMobile) Navigator.pop(context);
                      _handleSignOut(state);
                    },
                    icon: const Icon(Icons.logout, size: 12, color: KsdmaColors.danger),
                    label: const Text('Sign Out', style: TextStyle(color: KsdmaColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: KsdmaColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (isMobile) Navigator.pop(context);
                      KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx));
                    },
                    icon: const Icon(Icons.login, size: 12),
                    label: const Text('Sign In / Register', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KsdmaColors.gold,
                      foregroundColor: KsdmaColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {bool hasChildren = false, bool isExpanded = false, VoidCallback? onExpandToggle, bool isMobile = false}) {
    final isSelected = _activeMenuIndex == index;
    return InkWell(
      onTap: () {
        if (hasChildren && onExpandToggle != null) {
          onExpandToggle();
        } else {
          if (isMobile && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
            _scaffoldKey.currentState?.closeDrawer();
          }
          setState(() {
            _activeMenuIndex = index;
            _targetObservationStationId = null;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? KsdmaColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? KsdmaColors.gold : Colors.white24,
              ),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 17),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFFCFE2DC),
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
            if (hasChildren)
              Icon(
                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                color: Colors.white54,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubNavItem(int index, String title, {bool isActive = false, bool isMobile = false}) {
    return InkWell(
      onTap: () {
        if (isMobile && (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
          _scaffoldKey.currentState?.closeDrawer();
        }
        setState(() {
          _activeMenuIndex = index;
          _targetObservationStationId = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 28, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _handleSignOut(KsdmaStateService state) {
    state.logout();
    widget.onLogout?.call();
    setState(() {
      _activeMenuIndex = 0;
      _targetObservationStationId = null;
    });
  }

  Widget _buildMainView(KsdmaStateService state) {
    if (_targetObservationStationId != null) {
      return KsdmaObservationEntryView(
        stationId: _targetObservationStationId!,
        onSubmitted: () {
          setState(() {
            _targetObservationStationId = null;
            _activeMenuIndex = 1;
          });
        },
      );
    }

    final isAdmin = state.isLoggedIn &&
        (state.currentUser.role == UserRole.admin ||
            state.currentUser.category == UserCategory.adminHq ||
            state.currentUser.fullName.contains('Admin'));

    if (!isAdmin && (_activeMenuIndex == 7 || _activeMenuIndex == 9)) {
      return KsdmaPublicDashboardView(
        onNavigate: (tabIdx) => setState(() => _activeMenuIndex = tabIdx),
      );
    }

    if (isAdmin && _activeMenuIndex == 6) {
      return const KsdmaAdminView();
    }

    switch (_activeMenuIndex) {
      case 0:
        return KsdmaPublicDashboardView(
          onNavigate: (tabIdx) => setState(() => _activeMenuIndex = tabIdx),
        );
      case 1:
        return KsdmaVolunteerView(
          onEnterObservation: (stationId) {
            setState(() => _targetObservationStationId = stationId);
          },
          onRegisterNewDevice: () => setState(() => _activeMenuIndex = 6),
        );
      case 10:
        return const KsdmaMultiMapView(key: ValueKey(MapViewLevel.state), level: MapViewLevel.state);
      case 11:
        return const KsdmaMultiMapView(key: ValueKey(MapViewLevel.district), level: MapViewLevel.district);
      case 12:
        return const KsdmaMultiMapView(key: ValueKey(MapViewLevel.taluk), level: MapViewLevel.taluk);
      case 2:
        return const KsdmaMultiMapView(key: ValueKey(MapViewLevel.panchayat), level: MapViewLevel.panchayat);
      case 13:
        return const KsdmaMultiMapView(key: ValueKey(MapViewLevel.station), level: MapViewLevel.station);
      case 3:
        return const KsdmaOfficerView();
      case 4:
        return const KsdmaChampionsView();
      case 5:
        return const KsdmaResourcesView();
      case 6:
        return KsdmaRegistrationView(
          onSuccess: () => setState(() => _activeMenuIndex = 1),
        );
      case 7:
        return const KsdmaAdminView();
      default:
        return const KsdmaPublicDashboardView();
    }
  }
}
