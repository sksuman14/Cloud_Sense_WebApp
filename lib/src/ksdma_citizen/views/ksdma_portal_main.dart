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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _activeMenuIndex;
  String? _targetObservationStationId;
  bool _hasInitializedInitialMenu = false;

  @override
  void initState() {
    super.initState();
    _activeMenuIndex = widget.initialMenuIndex;
    if (widget.initialMenuIndex != 0) {
      _hasInitializedInitialMenu = true;
    }
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

          if (!_hasInitializedInitialMenu && state.isLoggedIn) {
            _hasInitializedInitialMenu = true;
            if (widget.initialMenuIndex == 0) {
              if (isAdmin) {
                _activeMenuIndex = 7;
              } else if (isOfficer) {
                _activeMenuIndex = 3;
              }
            }
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final bool isMobile = constraints.maxWidth < 950;

              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: const Color(0xFFF8FAFC),
                drawer: isMobile ? Drawer(child: _buildMobileDrawer(state, isAdmin, isOfficer)) : null,
                body: Column(
                  children: [
                    // Clean White Top Header Bar (No Dark Green Sidebar or Bar)
                    _buildTopHeaderBar(context, state, isMobile, isAdmin, isOfficer),

                    // Scrollable Page Content Area
                    Expanded(
                      child: _buildMainView(state),
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

  Widget _buildTopHeaderBar(BuildContext context, KsdmaStateService state, bool isMobile, bool isAdmin, bool isOfficer) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} IST';

    return Container(
      height: 60,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Color(0x08000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF0F172A)),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: 4),
          ],

          // Logo & Title
          InkWell(
            onTap: () => setState(() {
              _activeMenuIndex = 0;
              _targetObservationStationId = null;
            }),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(Icons.cloud_sync, color: Color(0xFF2563EB), size: 22),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Kerala Citizen Weather Platform',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'KSDMA Weather Cloud • Community Network',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // Desktop Nav Pills
          if (!isMobile) ...[
            _buildNavPill('Dashboard', isSelected: _activeMenuIndex == 0, onTap: () {
              setState(() {
                _activeMenuIndex = 0;
                _targetObservationStationId = null;
              });
            }),
            const SizedBox(width: 4),
            _buildNavPill('My Observations', isSelected: _activeMenuIndex == 1, onTap: () {
              if (state.isLoggedIn) {
                setState(() {
                  _activeMenuIndex = 1;
                  _targetObservationStationId = null;
                });
              } else {
                KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx));
              }
            }),
            const SizedBox(width: 4),

            // Map Views Dropdown Button with 3 Options
            _buildMapViewsDropdown(isSelected: [2, 10, 11, 12].contains(_activeMenuIndex)),
            const SizedBox(width: 4),

            _buildNavPill('Tutorials', isSelected: _activeMenuIndex == 5, onTap: () {
              setState(() {
                _activeMenuIndex = 5;
                _targetObservationStationId = null;
              });
            }),
            const SizedBox(width: 4),
            _buildNavPill('Register Instrument', isSelected: _activeMenuIndex == 6, onTap: () {
              if (state.isLoggedIn) {
                setState(() {
                  _activeMenuIndex = 6;
                  _targetObservationStationId = null;
                });
              } else {
                KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx));
              }
            }),

            if (isOfficer && !isAdmin) ...[
              const SizedBox(width: 4),
              _buildNavPill('Officer Reports', isSelected: _activeMenuIndex == 3, onTap: () {
                setState(() {
                  _activeMenuIndex = 3;
                  _targetObservationStationId = null;
                });
              }),
            ],
            if (isAdmin) ...[
              const SizedBox(width: 4),
              _buildNavPill('Admin HQ', isSelected: _activeMenuIndex == 7, onTap: () {
                setState(() {
                  _activeMenuIndex = 7;
                  _targetObservationStationId = null;
                });
              }),
            ],
          ],

          const Spacer(),

          // Live Sync Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF86EFAC)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text('Live Sync $timeStr', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Sign In / Profile Dropdown
          if (!state.isLoggedIn)
            ElevatedButton.icon(
              onPressed: () => KsdmaAuthModal.show(
                context,
                state,
                onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx),
              ),
              icon: const Icon(Icons.login, size: 14),
              label: Text(isMobile ? 'Sign In' : 'Sign In / Register', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            )
          else
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'logout') {
                  _handleSignOut(state);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.currentUser.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A))),
                      Text(isAdmin ? 'HQ Admin' : isOfficer ? 'District Officer' : 'Volunteer', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Sign Out', style: TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, color: Color(0xFF2563EB), size: 18),
                    const SizedBox(width: 6),
                    Text(
                      state.currentUser.fullName.split(' ').first,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB), size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Header Nav Pill Helper
  Widget _buildNavPill(String label, {bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  // Map Views Header Dropdown with 3 Options
  Widget _buildMapViewsDropdown({required bool isSelected}) {
    return PopupMenuButton<int>(
      onSelected: (int menuIndex) {
        setState(() {
          _activeMenuIndex = menuIndex;
          _targetObservationStationId = null;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
        const PopupMenuItem<int>(
          value: 10,
          child: Row(
            children: [
              Icon(Icons.map, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('1. State View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuItem<int>(
          value: 11,
          child: Row(
            children: [
              Icon(Icons.location_city, size: 16, color: Color(0xFF7C3AED)),
              SizedBox(width: 8),
              Text('2. District View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuItem<int>(
          value: 2,
          child: Row(
            children: [
              Icon(Icons.pin_drop, size: 16, color: Color(0xFF0D9488)),
              SizedBox(width: 8),
              Text('3. Taluk & Panchayat View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Map Views',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 3),
            Icon(
              Icons.keyboard_arrow_down,
              size: 14,
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile Drawer Navigation
  Widget _buildMobileDrawer(KsdmaStateService state, bool isAdmin, bool isOfficer) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: const BoxDecoration(color: Color(0xFF2563EB)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud_sync, color: Colors.white, size: 32),
              SizedBox(height: 8),
              Text('Kerala Citizen Weather', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              Text('KSDMA Observation Network', style: TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.dashboard_outlined),
          title: const Text('Dashboard'),
          selected: _activeMenuIndex == 0,
          onTap: () {
            Navigator.pop(context);
            setState(() => _activeMenuIndex = 0);
          },
        ),
        ListTile(
          leading: const Icon(Icons.assignment_outlined),
          title: const Text('My Observations'),
          selected: _activeMenuIndex == 1,
          onTap: () {
            Navigator.pop(context);
            if (state.isLoggedIn) {
              setState(() => _activeMenuIndex = 1);
            } else {
              KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx));
            }
          },
        ),
        const Divider(),
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
          child: Text('MAP VIEWS (3 OPTIONS)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        ListTile(
          leading: const Icon(Icons.map, color: Color(0xFF2563EB)),
          title: const Text('1. State View'),
          selected: _activeMenuIndex == 10,
          onTap: () {
            Navigator.pop(context);
            setState(() => _activeMenuIndex = 10);
          },
        ),
        ListTile(
          leading: const Icon(Icons.location_city, color: Color(0xFF7C3AED)),
          title: const Text('2. District View'),
          selected: _activeMenuIndex == 11,
          onTap: () {
            Navigator.pop(context);
            setState(() => _activeMenuIndex = 11);
          },
        ),
        ListTile(
          leading: const Icon(Icons.pin_drop, color: Color(0xFF0D9488)),
          title: const Text('3. Taluk & Panchayat View'),
          selected: _activeMenuIndex == 2,
          onTap: () {
            Navigator.pop(context);
            setState(() => _activeMenuIndex = 2);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.book_outlined),
          title: const Text('Tutorials'),
          selected: _activeMenuIndex == 5,
          onTap: () {
            Navigator.pop(context);
            setState(() => _activeMenuIndex = 5);
          },
        ),
        ListTile(
          leading: const Icon(Icons.add_circle_outline),
          title: const Text('Register Instrument'),
          selected: _activeMenuIndex == 6,
          onTap: () {
            Navigator.pop(context);
            if (state.isLoggedIn) {
              setState(() => _activeMenuIndex = 6);
            } else {
              KsdmaAuthModal.show(context, state, onLoginSuccess: (idx) => setState(() => _activeMenuIndex = idx));
            }
          },
        ),
      ],
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
        onGoToTutorials: () {
          setState(() {
            _targetObservationStationId = null;
            _activeMenuIndex = 5;
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
