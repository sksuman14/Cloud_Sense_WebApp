import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Pagination
  int _rowsPerPage = 50;
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
        // Prefer Punjab or Kerala if present, else first state
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
      // 1. Load districts
      List<String> districts = [];
      try {
        districts = await WsMaintenanceApiService.fetchDistricts(state);
      } catch (_) {
        districts = [];
      }

      // 2. Load sensors for state
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
          content: Text(
            '✓ $message${inventory != '' ? ' ($inventory sensors, $statesCount states)' : ''}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      // Refresh current sensor list
      if (_selectedState != null) {
        await _loadDistrictsAndSensors(_selectedState!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
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
      final detectedIssues = (s['Detected Issues'] ?? '').toString().toLowerCase();
      final resolvedParams = (s['Resolved Parameters'] ?? '').toString().toLowerCase();
      final resolvedBy = (s['Resolved By'] ?? '').toString().toLowerCase();
      final verificationStatus = (s['Verification Status'] ?? '').toString().trim().toLowerCase();

      // Search query check
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = sensorId.contains(q) ||
            city.contains(q) ||
            district.contains(q) ||
            detectedIssues.contains(q) ||
            resolvedParams.contains(q) ||
            resolvedBy.contains(q);
        if (!matches) return false;
      }

      // Filter check
      switch (_issueFilter) {
        case 'Has Issues':
          return detectedIssues.trim().isNotEmpty;
        case 'Pending Verification':
          return resolvedParams.trim().isNotEmpty && verificationStatus != 'yes';
        case 'Verified':
          return verificationStatus == 'yes';
        case 'No Issues':
          return detectedIssues.trim().isEmpty;
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
    // Headers
    buffer.writeln(
      'Sensor ID,City,District,State,Detected Issues,Resolved Parameters,Verification Status,Last Resolution Date,Resolved By',
    );

    for (final s in list) {
      final sensorId = _escapeCsv(s['Sensor ID']);
      final city = _escapeCsv(s['City']);
      final district = _escapeCsv(s['District']);
      final state = _escapeCsv(s['State']);
      final issues = _escapeCsv(s['Detected Issues']);
      final resolved = _escapeCsv(s['Resolved Parameters']);
      final status = _escapeCsv(s['Verification Status']);
      final lastDate = _escapeCsv(s['Last Resolution Date']);
      final resolvedBy = _escapeCsv(s['Resolved By']);

      buffer.writeln('$sensorId,$city,$district,$state,$issues,$resolved,$status,$lastDate,$resolvedBy');
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

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    try {
      final themeProvider = Provider.of<ThemeProvider>(context);
      isDark = themeProvider.isDarkMode;
    } catch (_) {}

    final bgColor = isDark ? const Color(0xFF0D1520) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF162232) : Colors.white;
    final borderColor = isDark ? const Color(0xFF26394E) : const Color(0xFFE2E8F0);
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final primaryColor = const Color(0xFF0284C7);

    final filtered = _filteredSensors;
    final totalCount = _allSensors.length;
    final issuesCount = _allSensors.where((s) => (s['Detected Issues'] ?? '').toString().trim().isNotEmpty).length;
    final pendingCount = _allSensors.where((s) {
      final hasResolved = (s['Resolved Parameters'] ?? '').toString().trim().isNotEmpty;
      final isVerified = (s['Verification Status'] ?? '').toString().trim().toLowerCase() == 'yes';
      return hasResolved && !isVerified;
    }).length;
    final verifiedCount = _allSensors.where((s) => (s['Verification Status'] ?? '').toString().trim().toLowerCase() == 'yes').length;

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
        backgroundColor: isDark ? const Color(0xFF132230) : const Color(0xFF0284C7),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          tooltip: 'Back to Admin Dashboard',
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.table_chart_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Master Maintenance Sheet',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Weather Station Hardware & Sensor QC Maintenance',
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
          // Audit Log Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.history_edu_rounded, size: 18),
            label: const Text('Audit History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: () => _openHistoryDialog(),
          ),
          const SizedBox(width: 8),

          // Export CSV
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withOpacity(0.15),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Export CSV', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            onPressed: _exportCsv,
          ),
          const SizedBox(width: 8),

          // Sync Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync_rounded, size: 18),
            label: Text(
              _isSyncing ? 'Syncing...' : 'Sync Now',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: _isSyncing ? null : _handleSync,
          ),
          const SizedBox(width: 8),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Current Sensors',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              if (_selectedState != null) {
                _loadDistrictsAndSensors(_selectedState!);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Controls & Stats
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Column(
                children: [
                  // Row 1: State / District / Search Bar
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // State Dropdown
                          SizedBox(
                            width: 200,
                            child: DropdownButtonFormField<String>(
                              value: _selectedState,
                              decoration: InputDecoration(
                                labelText: 'State',
                                labelStyle: TextStyle(color: textSubtle, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                              ),
                              dropdownColor: isDark ? const Color(0xFF162232) : Colors.white,
                              items: _states.map((st) {
                                return DropdownMenuItem<String>(
                                  value: st,
                                  child: Text(
                                    st.replaceAll('_', ' '),
                                    style: TextStyle(color: textStrong, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: _onStateChanged,
                            ),
                          ),

                          // District Dropdown
                          SizedBox(
                            width: 230,
                            child: DropdownButtonFormField<String>(
                              value: _selectedDistrict,
                              decoration: InputDecoration(
                                labelText: 'District',
                                labelStyle: TextStyle(color: textSubtle, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                              ),
                              dropdownColor: isDark ? const Color(0xFF162232) : Colors.white,
                              items: [
                                const DropdownMenuItem<String>(
                                  value: 'All Districts',
                                  child: Text('All Districts (Statewide)', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                ..._districts.map((d) {
                                  return DropdownMenuItem<String>(
                                    value: d,
                                    child: Text(
                                      d.replaceAll('_', ' '),
                                      style: TextStyle(color: textStrong, fontSize: 13),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: _onDistrictChanged,
                            ),
                          ),

                          // Search Box
                          SizedBox(
                            width: isWide ? 300 : double.infinity,
                            child: TextField(
                              controller: _searchController,
                              style: TextStyle(color: textStrong, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search by ID, city, district, issue...',
                                hintStyle: TextStyle(color: textSubtle, fontSize: 12),
                                prefixIcon: Icon(Icons.search, size: 18, color: textSubtle),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val.trim();
                                  _currentPage = 0;
                                });
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Row 2: KPI Stats & Quick Filter Chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildFilterChip('All', 'All ($totalCount)', isDark),
                      _buildFilterChip('Has Issues', '⚠ Issues Detected ($issuesCount)', isDark, color: const Color(0xFFEF4444)),
                      _buildFilterChip('Pending Verification', '⏳ Pending Verification ($pendingCount)', isDark, color: const Color(0xFFF59E0B)),
                      _buildFilterChip('Verified', '✓ Fully Verified ($verifiedCount)', isDark, color: const Color(0xFF10B981)),
                      _buildFilterChip('No Issues', '✓ Clean / No Issues', isDark, color: const Color(0xFF38BDF8)),
                    ],
                  ),
                ],
              ),
            ),

            // Main Content Table Area
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading sensor maintenance records...'),
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
                                const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: TextStyle(color: textStrong, fontSize: 15),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => _loadDistrictsAndSensors(_selectedState ?? 'Punjab'),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No sensor records found for the current filters.',
                                style: TextStyle(color: textSubtle, fontSize: 14),
                              ),
                            )
                          : _buildExcelDataTable(
                              items: pageItems,
                              startIndex: startIndex,
                              isDark: isDark,
                              cardBg: cardBg,
                              borderColor: borderColor,
                              textStrong: textStrong,
                              textSubtle: textSubtle,
                            ),
            ),

            // Pagination Footer Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.isEmpty ? 0 : startIndex + 1} to $endIndex of ${filtered.length} entries',
                    style: TextStyle(color: textSubtle, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Text('Rows per page: ', style: TextStyle(color: textSubtle, fontSize: 12)),
                      DropdownButton<int>(
                        value: _rowsPerPage,
                        underline: const SizedBox(),
                        style: TextStyle(color: textStrong, fontSize: 12),
                        dropdownColor: cardBg,
                        items: const [
                          DropdownMenuItem(value: 25, child: Text('25')),
                          DropdownMenuItem(value: 50, child: Text('50')),
                          DropdownMenuItem(value: 100, child: Text('100')),
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
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                      ),
                      Text(
                        'Page ${effectivePage + 1} of $totalPages',
                        style: TextStyle(color: textStrong, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, bool isDark, {Color? color}) {
    final isSelected = _issueFilter == filterKey;
    final activeColor = color ?? const Color(0xFF0284C7);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
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
              ? activeColor.withOpacity(isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF0F1722) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : (isDark ? const Color(0xFF26394E) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildExcelDataTable({
    required List<Map<String, dynamic>> items,
    required int startIndex,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textStrong,
    required Color textSubtle,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 1200),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              isDark ? const Color(0xFF1E2E42) : const Color(0xFFE2E8F0),
            ),
            headingTextStyle: TextStyle(
              color: textStrong,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            dataRowColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return isDark ? const Color(0xFF1B2C3F) : const Color(0xFFF1F5F9);
              }
              return isDark ? const Color(0xFF162232) : Colors.white;
            }),
            dataTextStyle: TextStyle(
              color: textStrong,
              fontSize: 12,
            ),
            horizontalMargin: 12,
            columnSpacing: 16,
            columns: [
              const DataColumn(label: Text('#')),
              DataColumn(
                label: const Text('Sensor ID'),
                onSort: (_, __) => _onSort('Sensor ID'),
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
                label: const Text('Verification'),
                onSort: (_, __) => _onSort('Verification Status'),
              ),
              DataColumn(
                label: const Text('Last Resolution'),
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
                  DataCell(Text('${startIndex + index + 1}')),

                  // Sensor ID (with copy)
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          sensorId,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            fontSize: 11.5,
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
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // City
                  DataCell(Text(city.isEmpty ? '-' : city)),

                  // District
                  DataCell(Text(district.isEmpty ? '-' : district)),

                  // State
                  DataCell(Text(state.isEmpty ? '-' : state)),

                  // Detected Issues Chips
                  DataCell(
                    issuesList.isEmpty
                        ? Text('None', style: TextStyle(color: textSubtle, fontStyle: FontStyle.italic))
                        : Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: issuesList.map((issue) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                                ),
                                child: Text(
                                  issue,
                                  style: const TextStyle(
                                    color: Color(0xFFF87171),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                                ),
                                child: Text(
                                  param,
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  // Verification Status Badge
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                            size: 12,
                            color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isVerified ? 'Verified' : 'Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Last Resolution Date
                  DataCell(Text(lastDate.isEmpty ? '-' : lastDate)),

                  // Resolved By
                  DataCell(Text(resolvedBy.isEmpty ? '-' : resolvedBy)),

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
                          icon: const Icon(Icons.history_rounded, size: 16),
                          tooltip: 'View History for this sensor',
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

class _UpdateMaintenanceDialogState extends State<_UpdateMaintenanceDialog> {
  late final TextEditingController _fixedByController;
  final Set<String> _selectedFixParams = {};
  final Set<String> _selectedVerifyParams = {};
  bool _isSubmitting = false;
  String? _dialogError;

  @override
  void initState() {
    super.initState();
    _fixedByController = TextEditingController(text: widget.adminEmail ?? 'Admin');

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
    super.dispose();
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
    final cardBg = isDark ? const Color(0xFF162232) : Colors.white;
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF26394E) : const Color(0xFFE2E8F0);

    final sensorId = (widget.sensor['Sensor ID'] ?? '').toString();
    final city = (widget.sensor['City'] ?? '').toString();
    final district = (widget.sensor['District'] ?? '').toString();
    final state = (widget.sensor['State'] ?? widget.selectedState).toString();
    final issuesStr = (widget.sensor['Detected Issues'] ?? '').toString();
    final resolvedStr = (widget.sensor['Resolved Parameters'] ?? '').toString();
    final status = (widget.sensor['Verification Status'] ?? 'No').toString().trim();
    final isVerified = status.toLowerCase() == 'yes';

    final issuesList = issuesStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final resolvedList = resolvedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.build_circle_outlined, color: Color(0xFF0284C7), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Update Maintenance Record',
                            style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '$city, $district ($state)',
                            style: TextStyle(color: textSubtle, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Error Banner if any
              if (_dialogError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _dialogError!,
                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sensor ID block
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Sensor ID: ', style: TextStyle(color: textSubtle, fontSize: 12)),
                                Expanded(
                                  child: SelectableText(
                                    sensorId,
                                    style: TextStyle(
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'monospace',
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('Verification Status: ', style: TextStyle(color: textSubtle, fontSize: 12)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isVerified
                                        ? const Color(0xFF10B981).withOpacity(0.2)
                                        : const Color(0xFFF59E0B).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isVerified ? 'Fully Verified (Yes)' : 'Not Verified (No)',
                                    style: TextStyle(
                                      color: isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fixed / Performed By input
                      TextField(
                        controller: _fixedByController,
                        style: TextStyle(color: textStrong, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Action Performed By (Required)',
                          labelStyle: TextStyle(color: textSubtle, fontSize: 12),
                          hintText: 'Enter admin email or name',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0F1722) : const Color(0xFFF8FAFC),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Section 1: Record FIX
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1C1917) : const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF97316).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.build_rounded, size: 16, color: Color(0xFFF97316)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Action: Record FIX',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF97316), fontSize: 14),
                                ),
                                const Spacer(),
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
                                      _selectedFixParams.length == issuesList.length ? 'Deselect All' : 'Select All',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            const Text(
                              'Fixing parameters moves them into Resolved Parameters and sets Verification Status to No.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            if (issuesList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No detected issues to fix.', style: TextStyle(fontStyle: FontStyle.italic)),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
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
                                    selectedColor: const Color(0xFFF97316).withOpacity(0.3),
                                    checkmarkColor: const Color(0xFFF97316),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF97316),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Record FIX Action'),
                                onPressed: (_isSubmitting || issuesList.isEmpty) ? null : () => _submitAction('FIX'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Action Section 2: Record VERIFY
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF062D24) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                const Text(
                                  'Action: Record VERIFY',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 14),
                                ),
                                const Spacer(),
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
                                      _selectedVerifyParams.length == resolvedList.length ? 'Deselect All' : 'Select All',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                            const Text(
                              'VERIFY is accepted only for parameters already in Resolved Parameters. To mark Verification Status as YES, verify all current issues.',
                              style: TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                            const SizedBox(height: 10),
                            if (resolvedList.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No resolved parameters available to verify yet.', style: TextStyle(fontStyle: FontStyle.italic)),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
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
                                    selectedColor: const Color(0xFF10B981).withOpacity(0.3),
                                    checkmarkColor: const Color(0xFF10B981),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                icon: const Icon(Icons.verified, size: 16),
                                label: const Text('Record VERIFY Action'),
                                onPressed: (_isSubmitting || resolvedList.isEmpty) ? null : () => _submitAction('VERIFY'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Cancel Button
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Close'),
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
    final cardBg = isDark ? const Color(0xFF162232) : Colors.white;
    final textStrong = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSubtle = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        widget.sensorId != null
                            ? 'Maintenance History (${widget.sensorId})'
                            : 'Maintenance History (${widget.state})',
                        style: TextStyle(color: textStrong, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444))))
                        : _reports.isEmpty
                            ? Center(
                                child: Text(
                                  'No maintenance history records found.',
                                  style: TextStyle(color: textSubtle, fontSize: 13),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _reports.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final r = _reports[idx];
                                  final sid = (r['Sensor ID'] ?? '').toString();
                                  final param = (r['Affected Parameter'] ?? '').toString();
                                  final action = (r['Action'] ?? '').toString().toUpperCase();
                                  final by = (r['Performed By'] ?? '').toString();
                                  final timestamp = (r['Action Timestamp'] ?? '').toString();
                                  final isFix = action == 'FIX';

                                  return ListTile(
                                    dense: true,
                                    leading: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: (isFix ? const Color(0xFFF97316) : const Color(0xFF10B981)).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
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
              const SizedBox(height: 12),
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
}
