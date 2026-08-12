import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    return Theme(
      data: ThemeData.light().copyWith(
        primaryColor: const Color(0xFF2563EB),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
      ),
      child: ChangeNotifierProvider(
        create: (_) => KsdmaStateService(),
        child: Consumer<KsdmaStateService>(
          builder: (context, state, _) {
            final userRole = state.currentUser.role;
            final userCategory = state.currentUser.category;
            final isAdmin = userRole == UserRole.admin || userCategory == UserCategory.adminHq || state.currentUser.fullName.contains('Admin');
            final isOfficer = userRole == UserRole.officer || userCategory == UserCategory.districtOfficer || state.currentUser.fullName.contains('Officer');
            final isVolunteer = !isAdmin && !isOfficer;

            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Row(
                children: [
                  // 1. Dark Blue Navigation Sidebar
                  Container(
                    width: 250,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                    ),
                    child: Column(
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
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.red,
                                ),
                                child: const Center(
                                  child: Icon(Icons.shield, color: Colors.white, size: 20),
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
                                      style: TextStyle(color: Colors.white70, fontSize: 10),
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

                        // Role Filtered Navigation Menu List
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            children: [
                              _buildNavItem(0, 'Dashboard', Icons.dashboard_outlined),
                              
                              // Volunteer Only: Observations Portal
                              if (isVolunteer)
                                _buildNavItem(1, 'My Observations', Icons.assignment_outlined),

                              // Map Views Dropdown (Visible to all)
                              _buildNavItem(
                                2,
                                'Map View',
                                Icons.map_outlined,
                                hasChildren: true,
                                isExpanded: _isMapViewExpanded,
                                onExpandToggle: () => setState(() => _isMapViewExpanded = !_isMapViewExpanded),
                              ),

                              if (_isMapViewExpanded) ...[
                                _buildSubNavItem(10, 'State View', isActive: _activeMenuIndex == 10),
                                _buildSubNavItem(11, 'District View', isActive: _activeMenuIndex == 11),
                                _buildSubNavItem(12, 'Taluk View', isActive: _activeMenuIndex == 12),
                                _buildSubNavItem(2, 'Grama Panchayat View', isActive: _activeMenuIndex == 2),
                                _buildSubNavItem(13, 'Station View', isActive: _activeMenuIndex == 13),
                              ],

                              // Officer & Admin Only: Reports
                              if (isOfficer || isAdmin)
                                _buildNavItem(3, 'Officer Reports', Icons.bar_chart_outlined),

                              _buildNavItem(4, 'Weather Champions', Icons.emoji_events_outlined),
                              _buildNavItem(5, 'Tutorials & Manuals', Icons.book_outlined),
                              
                              if (!isAdmin)
                                _buildNavItem(6, 'Register Instrument', Icons.add_circle_outline),

                              // Admin Only: Admin Dashboard
                              if (isAdmin)
                                _buildNavItem(7, 'Admin Dashboard', Icons.admin_panel_settings_outlined),
                            ],
                          ),
                        ),

                        // Bottom Logout & Slogan Box
                        Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.groups, color: Colors.lightBlueAccent, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Citizen Science Kerala',
                                      style: TextStyle(color: Colors.blue.shade100, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (state.isLoggedIn) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () => _handleSignOut(state),
                                    icon: const Icon(Icons.logout, size: 12, color: Colors.redAccent),
                                    label: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Colors.redAccent),
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx)),
                                    icon: const Icon(Icons.login, size: 12),
                                    label: const Text('Sign In / Register', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Main Content Area + Top Bar
                  Expanded(
                    child: Column(
                      children: [
                        // Top Header Ribbon
                        Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(bottom: BorderSide(color: Colors.black12)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.cloud_queue, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
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
                                  final dateFormatted = '$dayStr $monthStr $yearStr, $hourStr:$minStr $amPm';

                                  return Row(
                                    children: [
                                      Text('$dateFormatted  ', style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: Row(
                                          children: const [
                                            Icon(Icons.sensors, size: 12, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text('Live Sync', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                                          ],
                                        ),
                                      ),
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
                                  icon: const Icon(Icons.login, size: 16),
                                  label: const Text('Sign In / Register', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    elevation: 2,
                                  ),
                                ),
                              ] else ...[
                                // Active Role Indicator Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? Colors.purple.shade50 : isOfficer ? Colors.green.shade50 : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isAdmin ? Colors.purple : isOfficer ? Colors.green : Colors.blue),
                                  ),
                                  child: Text(
                                    isAdmin ? '⚙️ ADMIN HQ' : isOfficer ? '🛡️ OFFICER' : '🙋 VOLUNTEER',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAdmin ? Colors.purple : isOfficer ? Colors.green : Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                InkWell(
                                  onTap: () => KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx)),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: Colors.blue.shade100,
                                          child: Text(
                                            state.currentUser.fullName.isNotEmpty ? state.currentUser.fullName[0].toUpperCase() : 'U',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              state.currentUser.fullName.isNotEmpty ? state.currentUser.fullName : 'Registered User',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                            const Text('Account / Role ▾', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 10),
                                IconButton(
                                  icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 20),
                                  tooltip: 'Sign Out',
                                  onPressed: () => _handleSignOut(state),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Body View
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _buildMainView(state),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {bool hasChildren = false, bool isExpanded = false, VoidCallback? onExpandToggle}) {
    final isSelected = _activeMenuIndex == index;
    return InkWell(
      onTap: () {
        if (hasChildren && onExpandToggle != null) {
          onExpandToggle();
        } else {
          setState(() {
            _activeMenuIndex = index;
            _targetObservationStationId = null;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.white70, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  Widget _buildSubNavItem(int index, String title, {bool isActive = false}) {
    return InkWell(
      onTap: () {
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

    // Auth guard: If not logged in as Admin, don't show Admin view
    if (!isAdmin && (_activeMenuIndex == 7 || _activeMenuIndex == 9)) {
      return KsdmaPublicDashboardView(
        onNavigate: (tabIdx) => setState(() => _activeMenuIndex = tabIdx),
      );
    }

    // Admin should not view Register Instrument (6), redirect to Admin Dashboard
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
