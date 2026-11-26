import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/views/home/home_theme.dart';
import 'package:cloud_sense_webapp/src/services/ws_maintenance_api_service.dart';
import 'package:cloud_sense_webapp/src/utils/file_download_helper.dart';

class MasterMaintenanceSheetPage extends StatefulWidget {
  final String? adminEmail;
  final bool isDarkMode;

  const MasterMaintenanceSheetPage({
    super.key,
    this.adminEmail,
    required this.isDarkMode,
  });

  @override
  State<MasterMaintenanceSheetPage> createState() => _MasterMaintenanceSheetPageState();
}

class _MasterMaintenanceSheetPageState extends State<MasterMaintenanceSheetPage> {
  // State & District selection
  List<String> _states = [];
  String? _selectedState;
  List<String> _districts = [];
  String _selectedDistrict = 'All Districts';

  // Sensor data
  List<Map<String, dynamic>> _allSensors = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Search & Filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _issueFilter = 'All'; // 'All', 'Has Issues', 'Pending Verification', 'Verified', 'No Issues'

  // View Mode: 'table' or 'cards'
  bool? _isTableView; // null = auto-detect by screen width

  // Table Scroll Controllers
  final ScrollController _tableVerticalController = ScrollController();
  final ScrollController _tableHorizontalController = ScrollController();

  // Pagination
  int _rowsPerPage = 100;
  int _currentPage = 0;

  // Sort
  String _sortColumn = 'Sensor ID';
  bool _sortAscending = true;

  // Syncing state
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableVerticalController.dispose();
    _tableHorizontalController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final states = await WsMaintenanceApiService.fetchStates();
      if (!mounted) return;

      setState(() {
        _states = states;
        if (_states.contains('Punjab')) {
          _selectedState = 'Punjab';
        } else if (_states.contains('Kerala')) {
          _selectedState = 'Kerala';
        } else if (_states.isNotEmpty) {
          _selectedState = _states.first;
        }
      });

      if (_selectedState != null) {
        await _loadDistrictsAndSensors(_selectedState!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load states: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDistrictsAndSensors(String state) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<String> districts = [];
      try {
        districts = await WsMaintenanceApiService.fetchDistricts(state);
      } catch (_) {
        districts = [];
      }

      final sensors = await WsMaintenanceApiService.fetchSensors(
        state: state,
        district: _selectedDistrict == 'All Districts' ? null : _selectedDistrict,
      );

      if (!mounted) return;
      setState(() {
        _districts = districts;
        _allSensors = sensors;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load sensors: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _onStateChanged(String? newState) async {
    if (newState == null || newState == _selectedState) return;
    setState(() {
      _selectedState = newState;
      _selectedDistrict = 'All Districts';
    });
    await _loadDistrictsAndSensors(newState);
  }

  Future<void> _onDistrictChanged(String? newDistrict) async {
    if (newDistrict == null || newDistrict == _selectedDistrict) return;
    setState(() {
      _selectedDistrict = newDistrict;
      _isLoading = true;
    });

    try {
      final sensors = await WsMaintenanceApiService.fetchSensors(
        state: _selectedState!,
        district: newDistrict == 'All Districts' ? null : newDistrict,
      );
      if (!mounted) return;
      setState(() {
        _allSensors = sensors;
        _isLoading = false;
        _currentPage = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load district sensors: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSync() async {
    setState(() => _isSyncing = true);
    try {
      final result = await WsMaintenanceApiService.syncSensors();
      if (!mounted) return;

      final message = result['message'] ?? 'Synchronization completed successfully';
      final inventory = result['inventory_records'] ?? result['sensors_in_portal'] ?? '';
      final statesCount = result['states_processed'] ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✓ $message${inventory != '' ? ' ($inventory sensors, $statesCount states)' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      if (_selectedState != null) {
        await _loadDistrictsAndSensors(_selectedState!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('Sync failed: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  List<Map<String, dynamic>> get _filteredSensors {
    return _allSensors.where((s) {
      final sensorId = (s['Sensor ID'] ?? '').toString().toLowerCase();
      final city = (s['City'] ?? '').toString().toLowerCase();
      final district = (s['District'] ?? '').toString().toLowerCase();
      final state = (s['State'] ?? '').toString().toLowerCase();
      final detectedIssues = (s['Detected Issues'] ?? '').toString().toLowerCase();
      final resolvedParams = (s['Resolved Parameters'] ?? '').toString().toLowerCase();
      final resolvedBy = (s['Resolved By'] ?? '').toString().toLowerCase();
      final verificationStatus = (s['Verification Status'] ?? '').toString().trim().toLowerCase();
      final connectivity = (s['Connectivity Status'] ?? '').toString().toLowerCase();
      final deploymentDate = (s['Deployment Date'] ?? '').toString().toLowerCase();
      final qualityStatus = (s['Data Quality Status'] ?? '').toString().toLowerCase();

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = sensorId.contains(q) ||
            city.contains(q) ||
            district.contains(q) ||
            state.contains(q) ||
            detectedIssues.contains(q) ||
            resolvedParams.contains(q) ||
            resolvedBy.contains(q) ||
            verificationStatus.contains(q) ||
            connectivity.contains(q) ||
            deploymentDate.contains(q) ||
            qualityStatus.contains(q);
        if (!matches) return false;
      }

      switch (_issueFilter) {
        case 'Has Issues':
          return detectedIssues.trim().isNotEmpty;
        case 'Pending Verification':
          return resolvedParams.trim().isNotEmpty && verificationStatus != 'yes';
        case 'Verified':
          return verificationStatus == 'yes';
        case 'No Issues':
          return detectedIssues.trim().isEmpty;
        case 'Online':
          return connectivity == 'online';
        case 'Offline':
          return connectivity == 'offline';
        case 'Deployed':
          return deploymentDate.trim().isNotEmpty;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        final valA = (a[_sortColumn] ?? '').toString();
        final valB = (b[_sortColumn] ?? '').toString();
        final comp = valA.compareTo(valB);
        return _sortAscending ? comp : -comp;
      });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  void _exportCsv() {
    final list = _filteredSensors;
    if (list.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data available to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln(
      'Sensor ID,City,District,State,Connectivity Status,Deployment Date,Data Quality Status,Detected Issues,Resolved Parameters,Verification Status,Last Resolution Date,Resolved By',
    );

    for (final s in list) {
      final sensorId = _escapeCsv(s['Sensor ID']);
      final city = _escapeCsv(s['City']);
      final district = _escapeCsv(s['District']);
      final state = _escapeCsv(s['State']);
      final connectivity = _escapeCsv(s['Connectivity Status']);
      final deploymentDate = _escapeCsv(s['Deployment Date']);
      final qualityStatus = _escapeCsv(s['Data Quality Status']);
      final issues = _escapeCsv(s['Detected Issues']);
      final resolved = _escapeCsv(s['Resolved Parameters']);
      final status = _escapeCsv(s['Verification Status']);
      final lastDate = _escapeCsv(s['Last Resolution Date']);
      final resolvedBy = _escapeCsv(s['Resolved By']);

      buffer.writeln(
        '$sensorId,$city,$district,$state,$connectivity,$deploymentDate,$qualityStatus,$issues,$resolved,$status,$lastDate,$resolvedBy',
      );
    }

    final filename = 'Maintenance_Records_${_selectedState ?? "All"}_${DateTime.now().millisecondsSinceEpoch}.csv';
    FileDownloadHelper.saveAndShareFile(
      context: context,
      fileName: filename,
      fileContent: buffer.toString(),
      mimeType: 'text/csv',
    );
  }

  String _escapeCsv(dynamic val) {
    if (val == null) return '""';
    final str = val.toString().replaceAll('"', '""');
    return '"$str"';
  }

  void _openUpdateDialog(Map<String, dynamic> sensor) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UpdateMaintenanceDialog(
        sensor: sensor,
        selectedState: _selectedState ?? 'Punjab',
        adminEmail: widget.adminEmail,
        isDarkMode: widget.isDarkMode,
        onSuccess: () {
          _loadDistrictsAndSensors(_selectedState!);
        },
      ),
    );
  }

  void _openHistoryDialog({String? sensorId}) {
    showDialog(
      context: context,
      builder: (ctx) => _MaintenanceHistoryDialog(
        state: _selectedState ?? 'Punjab',
        sensorId: sensorId,
        isDarkMode: widget.isDarkMode,
      ),
    );
  }

  String _formatDateTime(String raw) {
    if (raw.isEmpty || raw == '-' || raw == 'null') return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      try {
        final clean = raw.replaceAll('T', ' ').split('+')[0];
        final dt = DateTime.parse(clean);
        return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
      } catch (_) {
        return raw;
      }
    }
  }

  /// Opens an interactive dialog to pick or clear a sensor's Deployment Date.
  Future<void> _showDeploymentDateDialog(Map<String, dynamic> sensor) async {
    final sensorId = (sensor['Sensor ID'] ?? '').toString();
    final district = (sensor['District'] ?? '').toString();
    final state = (sensor['State'] ?? _selectedState ?? 'Punjab').toString();
    final currentDateStr = (sensor['Deployment Date'] ?? '').toString().trim();

    DateTime initialDate = DateTime.now();
    if (currentDateStr.isNotEmpty) {
      try {
        initialDate = DateTime.parse(currentDateStr);
      } catch (_) {}
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF162332) : Colors.white;
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    DateTime? selectedDate = currentDateStr.isNotEmpty ? initialDate : null;

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final formattedDate = selectedDate != null
                ? '${selectedDate!.year.toString().padLeft(4, '0')}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}'
                : '';

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_available_rounded, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Deployment Date', style: TextStyle(color: textStrong, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(sensorId, style: TextStyle(color: textSubtle, fontSize: 11.5, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set or update the field deployment date for this weather station.',
                    style: TextStyle(color: textSubtle, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF0284C7)),
                            const SizedBox(width: 10),
                            Text(
                              formattedDate.isNotEmpty ? formattedDate : 'Not Deployed / Not Set',
                              style: TextStyle(
                                color: formattedDate.isNotEmpty ? textStrong : textSubtle,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (selectedDate != null)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFFEF4444)),
                                tooltip: 'Clear Date',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  setDialogState(() => selectedDate = null);
                                },
                              ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0284C7),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                              label: const Text('Pick Date', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: ctx,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDate = picked);
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Cancel', style: TextStyle(color: textSubtle)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx, formattedDate);
                  },
                  child: const Text('Save Date', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      await WsMaintenanceApiService.updateDeploymentDate(
        state: state,
        district: district,
        sensorId: sensorId,
        deploymentDate: result,
      );

      setState(() {
        sensor['Deployment Date'] = result;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            result.isNotEmpty
                ? '✓ Deployment date updated to $result for $sensorId'
                : '✓ Deployment date cleared for $sensorId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('Failed to update deployment date: ${e.toString().replaceAll("Exception: ", "")}'),
        ),
      );
    }
  }

  /// Builds a modern badge for Connectivity Status (Online / Offline / Unknown).
  static Widget buildConnectivityBadge(String? status, bool isDark) {
    final s = (status ?? '').trim().toLowerCase();
    final isOnline = s == 'online';
    final isOffline = s == 'offline';

    final Color color;
    final Color bgColor;
    final String label;

    if (isOnline) {
      color = const Color(0xFF10B981);
      bgColor = const Color(0xFF10B981).withOpacity(0.16);
      label = 'Online';
    } else if (isOffline) {
      color = const Color(0xFFEF4444);
      bgColor = const Color(0xFFEF4444).withOpacity(0.16);
      label = 'Offline';
    } else {
      color = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
      bgColor = color.withOpacity(0.14);
      label = status != null && status.isNotEmpty ? status : 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectivityBadge(String? status, bool isDark) => buildConnectivityBadge(status, isDark);

  /// Builds a modern badge for Data Quality Status (Good / Corrected / blank).
  static Widget buildDataQualityBadge(String? quality, bool isDark) {
    final q = (quality ?? '').trim().toLowerCase();
    if (q.isEmpty) {
      return Text('-', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11));
    }

    final isGood = q == 'good';
    final isCorrected = q == 'corrected';

    final Color color = isGood
        ? const Color(0xFF059669)
        : (isCorrected ? const Color(0xFFD97706) : const Color(0xFF64748B));
    final Color bgColor = color.withOpacity(0.15);
    final String label = isGood ? '✓ Good' : (isCorrected ? '⟳ Corrected' : quality!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDataQualityBadge(String? quality, bool isDark) => buildDataQualityBadge(quality, isDark);

  /// Builds an interactive Deployment Date table cell with 1-click date picker.
  Widget _buildDeploymentDateCell(Map<String, dynamic> sensor, bool isDark, Color textStrong, Color textSubtle) {
    final dateStr = (sensor['Deployment Date'] ?? '').toString().trim();
    if (dateStr.isNotEmpty) {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showDeploymentDateDialog(sensor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.event_available_rounded, size: 14, color: Color(0xFF0284C7)),
              const SizedBox(width: 5),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_calendar_rounded, size: 13, color: textSubtle),
            ],
          ),
        ),
      );
    } else {
      return InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showDeploymentDateDialog(sensor),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0284C7).withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3), style: BorderStyle.solid),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF0284C7)),
              SizedBox(width: 4),
              Text(
                'Set Date',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context);
      isDark = themeProvider.isDarkMode;
    } catch (_) {}

    final bgColor = isDark ? const Color(0xFF0A1017) : const Color(0xFFF4F6F9);
    final cardBg = isDark ? const Color(0xFF131D28) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF182433) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0);
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryColor = const Color(0xFF0284C7);

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isSmallScreen = screenWidth < 900;
    final isTablet = screenWidth >= 768 && screenWidth < 1100;
    // For smaller screens (<900px), always enforce responsive Card View
    final effectiveIsTableView = isSmallScreen ? false : (_isTableView ?? true);

    final filtered = _filteredSensors;
    final totalCount = _allSensors.length;
    final issuesCount = _allSensors.where((s) => (s['Detected Issues'] ?? '').toString().trim().isNotEmpty).length;
    final pendingCount = _allSensors.where((s) {
      final hasResolved = (s['Resolved Parameters'] ?? '').toString().trim().isNotEmpty;
      final isVerified = (s['Verification Status'] ?? '').toString().trim().toLowerCase() == 'yes';
      return hasResolved && !isVerified;
    }).length;
    final verifiedCount = _allSensors.where((s) => (s['Verification Status'] ?? '').toString().trim().toLowerCase() == 'yes').length;
    final onlineCount = _allSensors.where((s) => (s['Connectivity Status'] ?? '').toString().toLowerCase() == 'online').length;
    final offlineCount = _allSensors.where((s) => (s['Connectivity Status'] ?? '').toString().toLowerCase() == 'offline').length;
    final deployedCount = _allSensors.where((s) => (s['Deployment Date'] ?? '').toString().trim().isNotEmpty).length;

    // Pagination calculations
    final totalPages = (_rowsPerPage == 0 || filtered.isEmpty) ? 1 : (filtered.length / _rowsPerPage).ceil();
    final effectivePage = _currentPage.clamp(0, totalPages - 1);
    final startIndex = effectivePage * _rowsPerPage;
    final endIndex = (_rowsPerPage == 0) ? filtered.length : (startIndex + _rowsPerPage).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty ? <Map<String, dynamic>>[] : filtered.sublist(startIndex, endIndex);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? const Color(0xFF101B26) : const Color(0xFF0284C7),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          tooltip: 'Back to Admin Dashboard',
          onPressed: () => Navigator.pop(context),
        ),
        title: isMobile
            ? const Text(
                'Master Sheet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: Colors.white.withOpacity(0.25)),
                    ),
                    child: const Icon(
                      Icons.table_chart_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Master Maintenance Sheet',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          fontSize: 19,
                        ),
                      ),
                      const Text(
                        'Weather Station Hardware QC, Issue Resolution & Verification',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          // Table / Card view toggle (Desktop only, smaller screens strictly use Card view)
          if (!isSmallScreen)
            IconButton(
              tooltip: effectiveIsTableView ? 'Switch to Card View' : 'Switch to Table View',
              icon: Icon(
                effectiveIsTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isTableView = !effectiveIsTableView;
                });
              },
            ),

          if (isMobile) ...[
            // Compact mobile action set
            IconButton(
              tooltip: 'Sync Now',
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, color: Colors.white),
              onPressed: _isSyncing ? null : _handleSync,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              color: cardBg,
              onSelected: (val) {
                if (val == 'history') _openHistoryDialog();
                if (val == 'export') _exportCsv();
                if (val == 'refresh' && _selectedState != null) _loadDistrictsAndSensors(_selectedState!);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'history',
                  child: Row(
                    children: [
                      Icon(Icons.history_edu_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Audit History Logs'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.file_download_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Export CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Refresh Sensors'),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            // Desktop action set
            IconButton(
              tooltip: 'Audit History Logs',
              icon: const Icon(Icons.history_edu_rounded, color: Colors.white),
              onPressed: () => _openHistoryDialog(),
            ),
            IconButton(
              tooltip: 'Export CSV',
              icon: const Icon(Icons.file_download_outlined, color: Colors.white),
              onPressed: _exportCsv,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  _isSyncing ? 'Syncing' : 'Sync Now',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                onPressed: _isSyncing ? null : _handleSync,
              ),
            ),
            IconButton(
              tooltip: 'Refresh Current Sensors',
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () {
                if (_selectedState != null) {
                  _loadDistrictsAndSensors(_selectedState!);
                }
              },
            ),
          ],
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 20,
            vertical: isMobile ? 8 : 14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Controls & Stats Card
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Metric Cards Row
                  _buildKpiCardsRow(
                    totalCount: totalCount,
                    issuesCount: issuesCount,
                    pendingCount: pendingCount,
                    verifiedCount: verifiedCount,
                    isDark: isDark,
                    isMobile: isMobile,
                    surfaceBg: surfaceBg,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 14),

                  // Search & Dropdown Filter Bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      if (width >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 190,
                              child: _buildStateDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 220,
                              child: _buildDistrictDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildSearchField(surfaceBg, borderColor, textStrong, textSubtle),
                            ),
                          ],
                        );
                      } else if (width >= 550) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStateDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildDistrictDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSearchField(surfaceBg, borderColor, textStrong, textSubtle),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildStateDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                            const SizedBox(height: 8),
                            _buildDistrictDropdown(surfaceBg, borderColor, cardBg, textStrong, textSubtle),
                            const SizedBox(height: 8),
                            _buildSearchField(surfaceBg, borderColor, textStrong, textSubtle),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),

                  // Quick Filter Chips Row (Scrollable horizontally)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('All', 'All ($totalCount)', Icons.apps_rounded, isDark),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Has Issues',
                          'Issues ($issuesCount)',
                          Icons.warning_amber_rounded,
                          isDark,
                          accentColor: const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Pending Verification',
                          'Pending Verify ($pendingCount)',
                          Icons.hourglass_top_rounded,
                          isDark,
                          accentColor: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Verified',
                          'Verified ($verifiedCount)',
                          Icons.check_circle_rounded,
                          isDark,
                          accentColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'No Issues',
                          'Clean / Healthy',
                          Icons.verified_outlined,
                          isDark,
                          accentColor: const Color(0xFF06B6D4),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Online',
                          'Online ($onlineCount)',
                          Icons.wifi_rounded,
                          isDark,
                          accentColor: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Offline',
                          'Offline ($offlineCount)',
                          Icons.wifi_off_rounded,
                          isDark,
                          accentColor: const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        _buildFilterPill(
                          'Deployed',
                          'Deployed ($deployedCount)',
                          Icons.event_available_rounded,
                          isDark,
                          accentColor: const Color(0xFF8B5CF6),
                        ),
                        if (_searchQuery.isNotEmpty || _issueFilter != 'All') ...[
                          const SizedBox(width: 10),
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _issueFilter = 'All';
                                _currentPage = 0;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.close, size: 13, color: Color(0xFFEF4444)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Clear filters',
                                    style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
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

            const SizedBox(height: 14),

            // 2. Main Data Section Card (Table/Cards with integrated header and footer)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Sub-Header Bar
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 16,
                          vertical: isMobile ? 10 : 12,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14202D) : const Color(0xFFF8FAFC),
                          border: Border(bottom: BorderSide(color: borderColor)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.table_chart_rounded, size: 16, color: Color(0xFF0284C7)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Stations Master Directory',
                              style: TextStyle(
                                color: textStrong,
                                fontSize: isMobile ? 13 : 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1C2B3C) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${filtered.length} Stations',
                                style: TextStyle(
                                  color: textSubtle,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (effectiveIsTableView) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Scroll table to start (Sensor ID)',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    if (_tableHorizontalController.hasClients) {
                                      _tableHorizontalController.animateTo(
                                        0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.arrow_back_rounded, size: 13, color: textSubtle),
                                        const SizedBox(width: 3),
                                        Text('Start', style: TextStyle(color: textSubtle, fontSize: 11, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Tooltip(
                                message: 'Scroll table right to Actions column',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    if (_tableHorizontalController.hasClients) {
                                      _tableHorizontalController.animateTo(
                                        _tableHorizontalController.position.maxScrollExtent,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('Actions', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold)),
                                        SizedBox(width: 3),
                                        Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0284C7)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (!isMobile) ...[
                              Text('Rows: ', style: TextStyle(color: textSubtle, fontSize: 12)),
                              const SizedBox(width: 4),
                              Container(
                                height: 28,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: surfaceBg,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _rowsPerPage,
                                    isDense: true,
                                    dropdownColor: cardBg,
                                    style: TextStyle(color: textStrong, fontSize: 12, fontWeight: FontWeight.bold),
                                    items: [
                                      const DropdownMenuItem(value: 25, child: Text('25')),
                                      const DropdownMenuItem(value: 50, child: Text('50')),
                                      const DropdownMenuItem(value: 100, child: Text('100')),
                                      const DropdownMenuItem(value: 200, child: Text('200')),
                                      DropdownMenuItem(value: 0, child: Text('All (${filtered.length})')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _rowsPerPage = val;
                                          _currentPage = 0;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            if (!isSmallScreen)
                              IconButton(
                                tooltip: effectiveIsTableView ? 'Switch to Card View' : 'Switch to Table View',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  effectiveIsTableView ? Icons.grid_view_rounded : Icons.table_rows_rounded,
                                  size: 18,
                                  color: textSubtle,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isTableView = !effectiveIsTableView;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),

                      // Main Content Area
                      Expanded(
                        child: _isLoading
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(strokeWidth: 3),
                                    SizedBox(height: 16),
                                    Text('Loading sensor maintenance records...', style: TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            : _errorMessage != null
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444).withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.cloud_off_rounded, size: 40, color: Color(0xFFEF4444)),
                                          ),
                                          const SizedBox(height: 14),
                                          Text(
                                            _errorMessage!,
                                            style: TextStyle(color: textStrong, fontSize: 14, fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF0284C7),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _loadDistrictsAndSensors(_selectedState ?? 'Punjab'),
                                            icon: const Icon(Icons.refresh_rounded, size: 18),
                                            label: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : filtered.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.filter_alt_off_rounded, size: 48, color: textSubtle.withOpacity(0.5)),
                                            const SizedBox(height: 12),
                                            Text(
                                              'No sensor records match your filter criteria.',
                                              style: TextStyle(color: textSubtle, fontSize: 14, fontWeight: FontWeight.w500),
                                            ),
                                            if (_searchQuery.isNotEmpty || _issueFilter != 'All') ...[
                                              const SizedBox(height: 10),
                                              TextButton(
                                                onPressed: () {
                                                  setState(() {
                                                    _searchController.clear();
                                                    _searchQuery = '';
                                                    _issueFilter = 'All';
                                                  });
                                                },
                                                child: const Text('Reset All Filters'),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )
                                    : effectiveIsTableView
                                        ? _buildExcelDataTable(
                                            items: pageItems,
                                            startIndex: startIndex,
                                            isDark: isDark,
                                            cardBg: cardBg,
                                            borderColor: borderColor,
                                            textStrong: textStrong,
                                            textSubtle: textSubtle,
                                          )
                                        : _buildCardsView(
                                            items: pageItems,
                                            startIndex: startIndex,
                                            isDark: isDark,
                                            cardBg: cardBg,
                                            surfaceBg: surfaceBg,
                                            borderColor: borderColor,
                                            textStrong: textStrong,
                                            textSubtle: textSubtle,
                                          ),
                      ),

                      // Integrated Footer Pagination Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF14202D) : const Color(0xFFF8FAFC),
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: isMobile
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${filtered.isEmpty ? 0 : startIndex + 1}–$endIndex / ${filtered.length}',
                                    style: TextStyle(color: textSubtle, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left_rounded, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '${effectivePage + 1}/$totalPages',
                                          style: TextStyle(color: textStrong, fontSize: 11.5, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right_rounded, size: 20),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Showing ${filtered.isEmpty ? 0 : startIndex + 1}–$endIndex of ${filtered.length} records',
                                    style: TextStyle(color: textSubtle, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.first_page_rounded, size: 20),
                                        tooltip: 'First Page',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                                        tooltip: 'Previous Page',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          'Page ${effectivePage + 1} of $totalPages',
                                          style: TextStyle(color: textStrong, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                                        tooltip: 'Next Page',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        icon: const Icon(Icons.last_page_rounded, size: 20),
                                        tooltip: 'Last Page',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
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
            ),
          ],
        ),
      ),
    ),
  );
}

  /// Builds the 4 KPI stat cards at the top of the page.
  Widget _buildKpiCardsRow({
    required int totalCount,
    required int issuesCount,
    required int pendingCount,
    required int verifiedCount,
    required bool isDark,
    required bool isMobile,
    required Color surfaceBg,
    required Color borderColor,
  }) {
    final cards = [
      _KpiStatCard(
        label: 'Total Stations',
        value: '$totalCount',
        icon: Icons.sensors_rounded,
        color: const Color(0xFF0284C7),
        isSelected: _issueFilter == 'All',
        onTap: () => setState(() => _issueFilter = 'All'),
        isDark: isDark,
      ),
      _KpiStatCard(
        label: 'Issues Detected',
        value: '$issuesCount',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFEF4444),
        isSelected: _issueFilter == 'Has Issues',
        onTap: () => setState(() => _issueFilter = 'Has Issues'),
        isDark: isDark,
      ),
      _KpiStatCard(
        label: 'Pending Verify',
        value: '$pendingCount',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF59E0B),
        isSelected: _issueFilter == 'Pending Verification',
        onTap: () => setState(() => _issueFilter = 'Pending Verification'),
        isDark: isDark,
      ),
      _KpiStatCard(
        label: 'Fully Verified',
        value: '$verifiedCount',
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF10B981),
        isSelected: _issueFilter == 'Verified',
        onTap: () => setState(() => _issueFilter = 'Verified'),
        isDark: isDark,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= 780) {
          return Row(
            children: cards
                .map((c) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: c,
                      ),
                    ))
                .toList(),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 8),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStateDropdown(Color surfaceBg, Color borderColor, Color cardBg, Color textStrong, Color textSubtle) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedState,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFF0284C7)),
        labelText: 'State',
        labelStyle: TextStyle(color: textSubtle, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        filled: true,
        fillColor: surfaceBg,
      ),
      dropdownColor: cardBg,
      items: _states.map((st) {
        return DropdownMenuItem<String>(
          value: st,
          child: Text(
            st.replaceAll('_', ' '),
            style: TextStyle(color: textStrong, fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }).toList(),
      onChanged: _onStateChanged,
    );
  }

  Widget _buildDistrictDropdown(Color surfaceBg, Color borderColor, Color cardBg, Color textStrong, Color textSubtle) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: _selectedDistrict,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_city_rounded, size: 16, color: Color(0xFF0284C7)),
        labelText: 'District',
        labelStyle: TextStyle(color: textSubtle, fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        filled: true,
        fillColor: surfaceBg,
      ),
      dropdownColor: cardBg,
      items: [
        const DropdownMenuItem<String>(
          value: 'All Districts',
          child: Text(
            'All Districts (Statewide)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        ..._districts.map((d) {
          return DropdownMenuItem<String>(
            value: d,
            child: Text(
              d.replaceAll('_', ' '),
              style: TextStyle(color: textStrong, fontSize: 12),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          );
        }),
      ],
      onChanged: _onDistrictChanged,
    );
  }

  Widget _buildSearchField(Color surfaceBg, Color borderColor, Color textStrong, Color textSubtle) {
    return TextField(
      controller: _searchController,
      style: TextStyle(color: textStrong, fontSize: 12.5),
      decoration: InputDecoration(
        hintText: 'Search by ID, city, district, issues, or admin...',
        hintStyle: TextStyle(color: textSubtle, fontSize: 11.5),
        prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSubtle),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 15),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide(color: borderColor),
        ),
        filled: true,
        fillColor: surfaceBg,
      ),
      onChanged: (val) {
        setState(() {
          _searchQuery = val.trim();
          _currentPage = 0;
        });
      },
    );
  }

  Widget _buildFilterPill(String filterKey, String label, IconData icon, bool isDark, {Color? accentColor}) {
    final isSelected = _issueFilter == filterKey;
    final color = accentColor ?? const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _issueFilter = filterKey;
          _currentPage = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.22 : 0.14)
              : (isDark ? const Color(0xFF131D28) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? color : (isDark ? Colors.white60 : Colors.black54)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Modern Touch-Friendly Card View for Mobile/Tablet Screens.
  Widget _buildCardsView({
    required List<Map<String, dynamic>> items,
    required int startIndex,
    required bool isDark,
    required Color cardBg,
    required Color surfaceBg,
    required Color borderColor,
    required Color textStrong,
    required Color textSubtle,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final s = items[index];
        final sensorId = (s['Sensor ID'] ?? '').toString();
        final city = (s['City'] ?? '').toString();
        final district = (s['District'] ?? '').toString();
        final state = (s['State'] ?? '').toString();
        final issuesStr = (s['Detected Issues'] ?? '').toString();
        final resolvedStr = (s['Resolved Parameters'] ?? '').toString();
        final status = (s['Verification Status'] ?? 'No').toString().trim();
        final isVerified = status.toLowerCase() == 'yes';
        final lastDate = (s['Last Resolution Date'] ?? '').toString();
        final resolvedBy = (s['Resolved By'] ?? '').toString();
        final connectivity = (s['Connectivity Status'] ?? '').toString();
        final deploymentDate = (s['Deployment Date'] ?? '').toString().trim();
        final qualityStatus = (s['Data Quality Status'] ?? '').toString();

        final issuesList = issuesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final resolvedList = resolvedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isVerified
                  ? const Color(0xFF10B981).withOpacity(0.3)
                  : (issuesList.isNotEmpty ? const Color(0xFFEF4444).withOpacity(0.3) : borderColor),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Header: Index, Sensor ID & Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF162332) : const Color(0xFFF1F5F9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${startIndex + index + 1}',
                        style: TextStyle(color: textSubtle, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        sensorId,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Copy Sensor ID',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: sensorId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Copied $sensorId'), duration: const Duration(seconds: 1)),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0xFF10B981).withOpacity(0.2)
                            : const Color(0xFFF59E0B).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
                            size: 11,
                            color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Card Sub-Header: Connectivity & Data Quality Pills + Deployment Date
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF131D28) : const Color(0xFFF8FAFC),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    _buildConnectivityBadge(connectivity, isDark),
                    if (qualityStatus.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildDataQualityBadge(qualityStatus, isDark),
                    ],
                    const Spacer(),
                    _buildDeploymentDateCell(s, isDark, textStrong, textSubtle),
                  ],
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF0284C7)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '$city, $district ($state)',
                            style: TextStyle(color: textStrong, fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Detected Issues
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Issues: ', style: TextStyle(color: textSubtle, fontSize: 11.5, fontWeight: FontWeight.w600)),
                        Expanded(
                          child: issuesList.isEmpty
                              ? const Text('None (Clean)', style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold))
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: issuesList.map((issue) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        issue,
                                        style: const TextStyle(
                                          color: Color(0xFFF87171),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Resolved Parameters
                    if (resolvedList.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Resolved: ', style: TextStyle(color: textSubtle, fontSize: 11.5, fontWeight: FontWeight.w600)),
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: resolvedList.map((param) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    param,
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Resolution Meta (Date & By)
                    if (lastDate.isNotEmpty || resolvedBy.isNotEmpty) ...[
                      Text(
                        'Last Action: ${lastDate.isNotEmpty ? _formatDateTime(lastDate) : '-'} ${resolvedBy.isNotEmpty ? "by $resolvedBy" : ""}',
                        style: TextStyle(color: textSubtle, fontSize: 10.5, fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 8),
                    ],

                    const Divider(height: 16),

                    // Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.event_available_rounded, size: 14),
                          label: const Text('Deploy Date', style: TextStyle(fontSize: 11)),
                          onPressed: () => _showDeploymentDateDialog(s),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          icon: const Icon(Icons.history_rounded, size: 14),
                          label: const Text('History', style: TextStyle(fontSize: 11)),
                          onPressed: () => _openHistoryDialog(sensorId: sensorId),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.build_circle_outlined, size: 14),
                          label: const Text('Update', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          onPressed: () => _openUpdateDialog(s),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Modern Desktop Excel Data Table with Sticky Headers & Sorting.
  Widget _buildExcelDataTable({
    required List<Map<String, dynamic>> items,
    required int startIndex,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textStrong,
    required Color textSubtle,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableMinWidth = math.max(constraints.maxWidth, 1750.0);
        return ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.unknown,
            },
            scrollbars: true,
          ),
          child: Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                if (pointerSignal.scrollDelta.dy != 0 && _tableVerticalController.hasClients) {
                  final newOffset = (_tableVerticalController.offset + pointerSignal.scrollDelta.dy)
                      .clamp(0.0, _tableVerticalController.position.maxScrollExtent);
                  _tableVerticalController.jumpTo(newOffset);
                }
                if (pointerSignal.scrollDelta.dx != 0 && _tableHorizontalController.hasClients) {
                  final newOffset = (_tableHorizontalController.offset + pointerSignal.scrollDelta.dx)
                      .clamp(0.0, _tableHorizontalController.position.maxScrollExtent);
                  _tableHorizontalController.jumpTo(newOffset);
                }
              }
            },
            child: Scrollbar(
              controller: _tableHorizontalController,
              thumbVisibility: true,
              trackVisibility: true,
              notificationPredicate: (notif) => notif.metrics.axis == Axis.horizontal,
              child: Scrollbar(
                controller: _tableVerticalController,
                thumbVisibility: true,
                trackVisibility: true,
                notificationPredicate: (notif) => notif.metrics.axis == Axis.vertical,
                child: SingleChildScrollView(
                  controller: _tableHorizontalController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: tableMinWidth,
                      minHeight: constraints.maxHeight,
                    ),
                    child: SingleChildScrollView(
                      controller: _tableVerticalController,
                      scrollDirection: Axis.vertical,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: DataTable(
                  headingRowHeight: 46,
                  dataRowMinHeight: 52,
                  dataRowMaxHeight: 64,
                  headingRowColor: WidgetStateProperty.all(
                    isDark ? const Color(0xFF14202D) : const Color(0xFFE2E8F0),
                  ),
                  headingTextStyle: TextStyle(
                    color: textStrong,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    fontSize: 12.5,
                  ),
                  dataRowColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.hovered)) {
                      return isDark ? const Color(0xFF1C2B3C) : const Color(0xFFF1F5F9);
                    }
                    return isDark ? const Color(0xFF111A24) : Colors.white;
                  }),
                  dataTextStyle: TextStyle(
                    color: textStrong,
                    fontSize: 12,
                  ),
                  horizontalMargin: 16,
                  columnSpacing: 18,
                  columns: [
                    const DataColumn(label: Text('#')),
                    DataColumn(
                      label: const Text('Sensor ID'),
                      onSort: (_, __) => _onSort('Sensor ID'),
                    ),
                    DataColumn(
                      label: const Text('Connectivity'),
                      onSort: (_, __) => _onSort('Connectivity Status'),
                    ),
                    DataColumn(
                      label: const Text('Deployment Date'),
                      onSort: (_, __) => _onSort('Deployment Date'),
                    ),
                    DataColumn(
                      label: const Text('Data Quality'),
                      onSort: (_, __) => _onSort('Data Quality Status'),
                    ),
                    DataColumn(
                      label: const Text('City'),
                      onSort: (_, __) => _onSort('City'),
                    ),
                    DataColumn(
                      label: const Text('District'),
                      onSort: (_, __) => _onSort('District'),
                    ),
                    DataColumn(
                      label: const Text('State'),
                      onSort: (_, __) => _onSort('State'),
                    ),
                    const DataColumn(label: Text('Detected Issues')),
                    const DataColumn(label: Text('Resolved Parameters')),
                    DataColumn(
                      label: const Text('Status'),
                      onSort: (_, __) => _onSort('Verification Status'),
                    ),
                    DataColumn(
                      label: const Text('Last Date'),
                      onSort: (_, __) => _onSort('Last Resolution Date'),
                    ),
                    const DataColumn(label: Text('Resolved By')),
                    const DataColumn(label: Text('Actions')),
                  ],
                  rows: List.generate(items.length, (index) {
                    final s = items[index];
                    final sensorId = (s['Sensor ID'] ?? '').toString();
                    final city = (s['City'] ?? '').toString();
                    final district = (s['District'] ?? '').toString();
                    final state = (s['State'] ?? '').toString();
                    final connectivity = (s['Connectivity Status'] ?? '').toString();
                    final qualityStatus = (s['Data Quality Status'] ?? '').toString();
                    final issuesStr = (s['Detected Issues'] ?? '').toString();
                    final resolvedStr = (s['Resolved Parameters'] ?? '').toString();
                    final status = (s['Verification Status'] ?? 'No').toString().trim();
                    final isVerified = status.toLowerCase() == 'yes';
                    final lastDate = (s['Last Resolution Date'] ?? '').toString();
                    final resolvedBy = (s['Resolved By'] ?? '').toString();

                    final issuesList = issuesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                    final resolvedList = resolvedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

                    return DataRow(
                      cells: [
                        // #
                        DataCell(
                          Text(
                            '${startIndex + index + 1}',
                            style: TextStyle(color: textSubtle, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ),

                        // Sensor ID (with 1-click copy)
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SelectableText(
                                sensorId,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                tooltip: 'Copy Sensor ID',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: sensorId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Copied $sensorId'),
                                      duration: const Duration(seconds: 1),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                        // Connectivity Status Badge
                        DataCell(_buildConnectivityBadge(connectivity, isDark)),

                        // Deployment Date (with interactive 1-click update)
                        DataCell(_buildDeploymentDateCell(s, isDark, textStrong, textSubtle)),

                        // Data Quality Status Badge
                        DataCell(_buildDataQualityBadge(qualityStatus, isDark)),

                        // City
                        DataCell(Text(city.isEmpty ? '-' : city, overflow: TextOverflow.ellipsis)),

                        // District
                        DataCell(Text(district.isEmpty ? '-' : district, overflow: TextOverflow.ellipsis)),

                        // State
                        DataCell(Text(state.isEmpty ? '-' : state)),

                        // Detected Issues Chips
                        DataCell(
                          issuesList.isEmpty
                              ? const Text('None', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11.5))
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: issuesList.map((issue) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        issue,
                                        style: const TextStyle(
                                          color: Color(0xFFF87171),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),

                        // Resolved Parameters Chips
                        DataCell(
                          resolvedList.isEmpty
                              ? Text('-', style: TextStyle(color: textSubtle))
                              : Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: resolvedList.map((param) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                      ),
                                      child: Text(
                                        param,
                                        style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ),

                        // Verification Status Badge
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                  : const Color(0xFFF59E0B).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
                                  size: 11,
                                  color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isVerified ? 'Verified' : 'Pending',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Last Resolution Date
                        DataCell(
                          Text(
                            _formatDateTime(lastDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: textSubtle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        // Resolved By
                        DataCell(Text(resolvedBy.isEmpty ? '-' : resolvedBy, overflow: TextOverflow.ellipsis)),

                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.build_circle_outlined, size: 14),
                                label: const Text('Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                onPressed: () => _openUpdateDialog(s),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.event_available_rounded, size: 16),
                                tooltip: 'Set Deployment Date',
                                onPressed: () => _showDeploymentDateDialog(s),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.history_rounded, size: 16),
                                tooltip: 'History',
                                onPressed: () => _openHistoryDialog(sensorId: sensorId),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  },
);
  }
}

/// A single interactive KPI card at the top of the Master Maintenance Sheet.
class _KpiStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _KpiStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(isDark ? 0.22 : 0.12)
              : (isDark ? const Color(0xFF162332) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.6 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog allowing admin to record FIX or VERIFY action on a sensor.
class _UpdateMaintenanceDialog extends StatefulWidget {
  final Map<String, dynamic> sensor;
  final String selectedState;
  final String? adminEmail;
  final bool isDarkMode;
  final VoidCallback onSuccess;

  const _UpdateMaintenanceDialog({
    required this.sensor,
    required this.selectedState,
    this.adminEmail,
    required this.isDarkMode,
    required this.onSuccess,
  });

  @override
  State<_UpdateMaintenanceDialog> createState() => _UpdateMaintenanceDialogState();
}

class _UpdateMaintenanceDialogState extends State<_UpdateMaintenanceDialog> with SingleTickerProviderStateMixin {
  late final TextEditingController _fixedByController;
  final Set<String> _selectedFixParams = {};
  final Set<String> _selectedVerifyParams = {};
  bool _isSubmitting = false;
  String? _dialogError;
  late TabController _tabController;

  String? _currentDeploymentDate;
  bool _isUpdatingDate = false;

  @override
  void initState() {
    super.initState();
    _fixedByController = TextEditingController(text: widget.adminEmail ?? 'Admin');
    _tabController = TabController(length: 2, vsync: this);

    final rawDate = (widget.sensor['Deployment Date'] ?? '').toString().trim();
    _currentDeploymentDate = rawDate.isNotEmpty ? rawDate : null;

    // Pre-select all detected issues by default for convenience
    final issuesStr = (widget.sensor['Detected Issues'] ?? '').toString();
    final issues = issuesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    _selectedFixParams.addAll(issues);

    // Pre-select all resolved parameters for verification
    final resolvedStr = (widget.sensor['Resolved Parameters'] ?? '').toString();
    final resolved = resolvedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty);
    _selectedVerifyParams.addAll(resolved);
  }

  @override
  void dispose() {
    _fixedByController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _updateDeploymentDate(String? newDate) async {
    setState(() => _isUpdatingDate = true);
    try {
      final sensorId = (widget.sensor['Sensor ID'] ?? '').toString();
      final district = (widget.sensor['District'] ?? '').toString();
      final state = (widget.sensor['State'] ?? widget.selectedState).toString();
      final dateToSubmit = newDate ?? '';

      await WsMaintenanceApiService.updateDeploymentDate(
        state: state,
        district: district,
        sensorId: sensorId,
        deploymentDate: dateToSubmit,
      );

      setState(() {
        _currentDeploymentDate = dateToSubmit.isEmpty ? null : dateToSubmit;
        widget.sensor['Deployment Date'] = dateToSubmit;
      });

      widget.onSuccess();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(dateToSubmit.isEmpty
              ? 'Deployment date cleared for $sensorId'
              : 'Deployment date set to $dateToSubmit'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Failed to update deployment date: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingDate = false);
    }
  }

  Future<void> _submitAction(String action) async {
    final fixedBy = _fixedByController.text.trim();
    if (fixedBy.isEmpty) {
      setState(() => _dialogError = 'Please provide the name or email of the person performing this action.');
      return;
    }

    final params = action == 'FIX' ? _selectedFixParams.toList() : _selectedVerifyParams.toList();
    if (params.isEmpty) {
      setState(() => _dialogError = 'Please select at least one parameter for $action action.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    try {
      final sensorId = (widget.sensor['Sensor ID'] ?? '').toString();
      final district = (widget.sensor['District'] ?? '').toString();
      final state = (widget.sensor['State'] ?? widget.selectedState).toString();

      await WsMaintenanceApiService.recordMaintenance(
        state: state,
        district: district,
        sensorId: sensorId,
        parameters: params,
        action: action,
        fixedBy: fixedBy,
      );

      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text('✓ Successfully recorded $action for $sensorId'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dialogError = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF162332) : Colors.white;
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF24364A) : const Color(0xFFE2E8F0);

    final sensorId = (widget.sensor['Sensor ID'] ?? '').toString();
    final city = (widget.sensor['City'] ?? '').toString();
    final district = (widget.sensor['District'] ?? '').toString();
    final state = (widget.sensor['State'] ?? widget.selectedState).toString();
    final connectivity = (widget.sensor['Connectivity Status'] ?? '').toString();
    final qualityStatus = (widget.sensor['Data Quality Status'] ?? '').toString();
    final issuesStr = (widget.sensor['Detected Issues'] ?? '').toString();
    final resolvedStr = (widget.sensor['Resolved Parameters'] ?? '').toString();
    final status = (widget.sensor['Verification Status'] ?? 'No').toString().trim();
    final isVerified = status.toLowerCase() == 'yes';

    final issuesList = issuesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final resolvedList = resolvedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle_outlined, color: Color(0xFF0284C7), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Update Maintenance Record',
                          style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '$city, $district ($state)',
                          style: TextStyle(color: textSubtle, fontSize: 11.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Error Banner if any
              if (_dialogError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dialogError!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Sensor Identification & Verification Status Banner
              LayoutBuilder(
                builder: (context, bannerConstraints) {
                  final isDialogNarrow = bannerConstraints.maxWidth < 460;
                  final sensorIdWidget = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SENSOR ID', style: TextStyle(color: textSubtle, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      SelectableText(
                        sensorId,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  );

                  final badgesWidget = Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MasterMaintenanceSheetPageState.buildConnectivityBadge(connectivity, isDark),
                      if (qualityStatus.isNotEmpty)
                        _MasterMaintenanceSheetPageState.buildDataQualityBadge(qualityStatus, isDark),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isVerified
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isVerified ? Icons.check_circle_rounded : Icons.pending_rounded,
                              size: 12,
                              color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVerified ? 'Fully Verified' : 'Not Verified',
                              style: TextStyle(
                                color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: isDialogNarrow
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              sensorIdWidget,
                              const SizedBox(height: 8),
                              badgesWidget,
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(child: sensorIdWidget),
                              badgesWidget,
                            ],
                          ),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Interactive Deployment Date Panel
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0B131D) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor.withOpacity(0.7)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event_available_rounded,
                          size: 16,
                          color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Deployment Date: ',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: textSubtle),
                        ),
                        Text(
                          _currentDeploymentDate != null && _currentDeploymentDate!.isNotEmpty
                              ? _currentDeploymentDate!
                              : 'Not Deployed Yet',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _currentDeploymentDate != null && _currentDeploymentDate!.isNotEmpty
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                : textSubtle,
                          ),
                        ),
                      ],
                    ),
                    if (_isUpdatingDate)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentDeploymentDate != null && _currentDeploymentDate!.isNotEmpty)
                            TextButton(
                              onPressed: () => _updateDeploymentDate(null),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Clear', style: TextStyle(fontSize: 11)),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              DateTime initial = DateTime.now();
                              if (_currentDeploymentDate != null && _currentDeploymentDate!.isNotEmpty) {
                                try {
                                  initial = DateTime.parse(_currentDeploymentDate!);
                                } catch (_) {}
                              }
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initial,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                final yyyy = picked.year.toString().padLeft(4, '0');
                                final mm = picked.month.toString().padLeft(2, '0');
                                final dd = picked.day.toString().padLeft(2, '0');
                                await _updateDeploymentDate('$yyyy-$mm-$dd');
                              }
                            },
                            icon: const Icon(Icons.edit_calendar_rounded, size: 13),
                            label: Text(
                              _currentDeploymentDate != null && _currentDeploymentDate!.isNotEmpty
                                  ? 'Change'
                                  : 'Set Date',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action Tabs (FIX vs VERIFY)
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF0284C7),
                indicatorWeight: 2.5,
                labelColor: textStrong,
                unselectedLabelColor: textSubtle,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.build_rounded, size: 16), text: '1. Record FIX'),
                  Tab(icon: Icon(Icons.verified_rounded, size: 16), text: '2. Record VERIFY'),
                ],
              ),
              const SizedBox(height: 12),

              // Performed By Input Field
              TextField(
                controller: _fixedByController,
                style: TextStyle(color: textStrong, fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Action Performed By (Required)',
                  labelStyle: TextStyle(color: textSubtle, fontSize: 11.5),
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 17),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 10),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: FIX
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Detected Issues to Fix:',
                                style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (issuesList.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedFixParams.length == issuesList.length) {
                                        _selectedFixParams.clear();
                                      } else {
                                        _selectedFixParams.addAll(issuesList);
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedFixParams.length == issuesList.length ? 'Clear Selection' : 'Select All',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const Text(
                            'Marking issues as fixed will add them to Resolved Parameters and set status to Not Verified pending review.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          if (issuesList.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    'No active detected issues for this station.',
                                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: issuesList.map((issue) {
                                final isChecked = _selectedFixParams.contains(issue);
                                return FilterChip(
                                  label: Text(issue),
                                  selected: isChecked,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedFixParams.add(issue);
                                      } else {
                                        _selectedFixParams.remove(issue);
                                      }
                                    });
                                  },
                                  selectedColor: const Color(0xFFF97316).withOpacity(0.25),
                                  checkmarkColor: const Color(0xFFF97316),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.build_rounded, size: 16),
                              label: const Text('Record FIX Action', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: (_isSubmitting || issuesList.isEmpty) ? null : () => _submitAction('FIX'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tab 2: VERIFY
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Resolved Parameters to Verify:',
                                style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (resolvedList.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedVerifyParams.length == resolvedList.length) {
                                        _selectedVerifyParams.clear();
                                      } else {
                                        _selectedVerifyParams.addAll(resolvedList);
                                      }
                                    });
                                  },
                                  child: Text(
                                    _selectedVerifyParams.length == resolvedList.length ? 'Clear Selection' : 'Select All',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                          const Text(
                            'To set status to Verified (Yes), verify all current detected issues in one request.',
                            style: TextStyle(color: Colors.grey, fontSize: 11),
                          ),
                          const SizedBox(height: 10),
                          if (resolvedList.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B), size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No resolved parameters available to verify. First record a FIX.',
                                      style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: resolvedList.map((param) {
                                final isChecked = _selectedVerifyParams.contains(param);
                                return FilterChip(
                                  label: Text(param),
                                  selected: isChecked,
                                  onSelected: (val) {
                                    setState(() {
                                      if (val) {
                                        _selectedVerifyParams.add(param);
                                      } else {
                                        _selectedVerifyParams.remove(param);
                                      }
                                    });
                                  },
                                  selectedColor: const Color(0xFF10B981).withOpacity(0.25),
                                  checkmarkColor: const Color(0xFF10B981),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              icon: _isSubmitting
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.verified_rounded, size: 16),
                              label: const Text('Record VERIFY Action', style: TextStyle(fontWeight: FontWeight.bold)),
                              onPressed: (_isSubmitting || resolvedList.isEmpty) ? null : () => _submitAction('VERIFY'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Close Button
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog displaying maintenance audit history reports from /{State}/report.csv.
class _MaintenanceHistoryDialog extends StatefulWidget {
  final String state;
  final String? sensorId;
  final bool isDarkMode;

  const _MaintenanceHistoryDialog({
    required this.state,
    this.sensorId,
    required this.isDarkMode,
  });

  @override
  State<_MaintenanceHistoryDialog> createState() => _MaintenanceHistoryDialogState();
}

class _MaintenanceHistoryDialogState extends State<_MaintenanceHistoryDialog> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = [];
  String? _error;
  String _historyFilter = 'ALL'; // 'ALL', 'FIX', 'VERIFY'

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final reports = await WsMaintenanceApiService.fetchReports(
        state: widget.state,
        sensorId: widget.sensorId,
      );
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final cardBg = isDark ? const Color(0xFF162332) : Colors.white;
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final filteredReports = _reports.where((r) {
      if (_historyFilter == 'ALL') return true;
      final a = (r['Action'] ?? '').toString().toUpperCase();
      return a == _historyFilter;
    }).toList();

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_edu_rounded, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.sensorId != null
                            ? 'History: ${widget.sensorId}'
                            : 'Maintenance History (${widget.state})',
                        style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Tabs (All / FIX / VERIFY)
              Row(
                children: [
                  _buildTabPill('ALL', 'All (${_reports.length})', isDark),
                  const SizedBox(width: 6),
                  _buildTabPill('FIX', 'FIX Actions', isDark, color: const Color(0xFFF97316)),
                  const SizedBox(width: 6),
                  _buildTabPill('VERIFY', 'VERIFY Actions', isDark, color: const Color(0xFF10B981)),
                ],
              ),
              const Divider(height: 20),

              // List of reports
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                        : filteredReports.isEmpty
                            ? Center(
                                child: Text(
                                  'No maintenance history records found.',
                                  style: TextStyle(color: textSubtle, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredReports.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final r = filteredReports[idx];
                                  final sid = (r['Sensor ID'] ?? '').toString();
                                  final param = (r['Affected Parameter'] ?? '').toString();
                                  final action = (r['Action'] ?? '').toString().toUpperCase();
                                  final by = (r['Performed By'] ?? '').toString();
                                  final timestamp = (r['Action Timestamp'] ?? '').toString();
                                  final isFix = action == 'FIX';

                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    leading: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: (isFix ? const Color(0xFFF97316) : const Color(0xFF10B981)).withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        isFix ? Icons.build_rounded : Icons.verified_rounded,
                                        size: 16,
                                        color: isFix ? const Color(0xFFF97316) : const Color(0xFF10B981),
                                      ),
                                    ),
                                    title: Text(
                                      '$action: $param',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isFix ? const Color(0xFFF97316) : const Color(0xFF10B981),
                                        fontSize: 13,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Sensor: $sid • By: $by',
                                      style: TextStyle(color: textSubtle, fontSize: 11),
                                    ),
                                    trailing: Text(
                                      timestamp,
                                      style: TextStyle(color: textSubtle, fontSize: 11),
                                    ),
                                  );
                                },
                              ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill(String key, String title, bool isDark, {Color? color}) {
    final isSelected = _historyFilter == key;
    final activeColor = color ?? const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _historyFilter = key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF0F1722) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
