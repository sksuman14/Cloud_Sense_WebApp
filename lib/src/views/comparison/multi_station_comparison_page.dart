import 'package:cloud_sense_webapp/src/utils/prefix_mapping.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:cloud_sense_webapp/src/views/home/home_theme.dart';
import 'package:cloud_sense_webapp/src/services/station_comparison_service.dart';
import 'package:cloud_sense_webapp/src/utils/file_download_helper.dart';
import 'package:cloud_sense_webapp/src/utils/DeleteDevice.dart';
import 'package:cloud_sense_webapp/src/widgets/appbar.dart';
import 'package:cloud_sense_webapp/src/widgets/drawer.dart';
import 'package:cloud_sense_webapp/src/widgets/footer.dart';

/// Multi-Station Comparison Playground
/// Allows users to compare 2 weather stations anywhere across India in real-time.
/// Includes dual-series timeline, correlation scatter plot, microclimate analytics,
/// and instant CSV dataset export.
class MultiStationComparisonPage extends StatefulWidget {
  final String? initialStationA;
  final String? initialStationB;

  const MultiStationComparisonPage({
    super.key,
    this.initialStationA,
    this.initialStationB,
  });

  @override
  State<MultiStationComparisonPage> createState() =>
      _MultiStationComparisonPageState();
}

class _MultiStationComparisonPageState
    extends State<MultiStationComparisonPage> {
  // Station catalog
  List<StationCandidate> _allStations = [];
  bool _isLoadingStations = true;
  String? _stationCatalogError;

  // Selected state
  StationCandidate? _stationA;
  StationCandidate? _stationB;
  ComparisonParam _selectedParam = ComparisonParam.temperature;
  int _selectedDays = 1; // 1 = 24h, 7 = 7d, 30 = 30d
  bool _isScatterMode = false;

  // History & aligned data
  bool _isLoadingHistory = false;
  String? _historyError;
  List<ComparisonPoint> _pointsA = [];
  List<ComparisonPoint> _pointsB = [];
  List<AlignedComparisonRow> _alignedRows = [];
  ComparisonStats? _stats;

  // UI state
  bool _isTableExpanded = false;
  final ScrollController _metricScrollController = ScrollController();
  late TrackballBehavior _trackballBehavior;
  late ZoomPanBehavior _zoomPanBehavior;

  // Colors
  static const Color _colorA = Color(0xFF00B0FF); // Electric Cyan / Blue
  static const Color _colorB = Color(0xFF00E676); // Emerald Green
  static const Color _colorDelta = Color(0xFFFF9100); // Amber

  @override
  @override
  void dispose() {
    _metricScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _trackballBehavior = TrackballBehavior(
      enable: true,
      activationMode: ActivationMode.singleTap,
      tooltipDisplayMode: TrackballDisplayMode.groupAllPoints,
      lineType: TrackballLineType.vertical,
      lineWidth: 1.5,
      lineColor: Colors.white54,
    );
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enablePanning: true,
      enableDoubleTapZooming: true,
      zoomMode: ZoomMode.x,
    );

    _loadStationCatalog();
  }

  /// Initial catalog loading
  Future<void> _loadStationCatalog() async {
    setState(() {
      _isLoadingStations = true;
      _stationCatalogError = null;
    });

    try {
      final list = await StationComparisonService.fetchAllStations();
      if (!mounted) return;

      if (list.isEmpty) {
        setState(() {
          _isLoadingStations = false;
          _stationCatalogError =
              "No telemetry stations currently reporting. Please check network.";
        });
        return;
      }

      // Pick default initial stations or defaults
      StationCandidate? a;
      StationCandidate? b;

      if (widget.initialStationA != null) {
        a = list.firstWhere(
          (s) =>
              s.sensorName.toUpperCase() ==
                  widget.initialStationA!.toUpperCase() ||
              s.displayName.toUpperCase() ==
                  widget.initialStationA!.toUpperCase(),
          orElse: () => list.first,
        );
      }
      if (widget.initialStationB != null) {
        b = list.firstWhere(
          (s) =>
              s.sensorName.toUpperCase() ==
                  widget.initialStationB!.toUpperCase() ||
              s.displayName.toUpperCase() ==
                  widget.initialStationB!.toUpperCase(),
          orElse: () => list.length > 1 ? list[1] : list.first,
        );
      }

      // If no initial params provided, pick an interesting contrast (e.g. Punjab vs Kerala)
      if (a == null || b == null) {
        final punjabCandidates = list.where((s) =>
            s.state.toLowerCase().contains('punjab') ||
            s.sensorName.startsWith('PJ') ||
            s.location.toLowerCase().contains('punjab'));
        final keralaCandidates = list.where((s) =>
            s.state.toLowerCase().contains('kerala') ||
            s.sensorName.startsWith('KR') ||
            s.location.toLowerCase().contains('kerala'));

        a = punjabCandidates.isNotEmpty ? punjabCandidates.first : list.first;
        b = keralaCandidates.isNotEmpty
            ? keralaCandidates.first
            : (list.length > 1 ? list[1] : list.first);

        // Avoid identical selection if multiple stations exist
        if (a.sensorName == b.sensorName && list.length > 1) {
          b = list.firstWhere((s) => s.sensorName != a!.sensorName,
              orElse: () => list[1]);
        }
      }

      setState(() {
        _allStations = list;
        _stationA = a;
        _stationB = b;
        _isLoadingStations = false;
      });

      // Automatically fetch historical data for selected stations
      _fetchHistoricalData();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStations = false;
          _stationCatalogError = "Error loading stations: $e";
        });
      }
    }
  }

  /// Fetch telemetry history for both stations and align them
  Future<void> _fetchHistoricalData() async {
    if (_stationA == null || _stationB == null) return;

    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });

    try {
      final rangeStr = _selectedDays == 7
          ? '7days'
          : (_selectedDays == 30 ? '30days' : '1day');

      final results = await Future.wait<List<Map<String, dynamic>>>([
        StationComparisonService.fetchStationHistory(
          sensorName: _stationA!.sensorName,
          range: rangeStr,
        ),
        StationComparisonService.fetchStationHistory(
          sensorName: _stationB!.sensorName,
          range: rangeStr,
        ),
      ]);

      final rawA = results[0];
      final rawB = results[1];

      final ptsA =
          StationComparisonService.extractPoints(rawA, _selectedParam);
      final ptsB =
          StationComparisonService.extractPoints(rawB, _selectedParam);

      // Bucket size based on day range (30 min for 1d, 60 min for 7d, 120 min for 30d)
      final bucketMins =
          _selectedDays == 1 ? 30 : (_selectedDays == 7 ? 60 : 120);
      final aligned = StationComparisonService.alignSeries(
        seriesA: ptsA,
        seriesB: ptsB,
        bucketSize: Duration(minutes: bucketMins),
      );

      final stats = StationComparisonService.computeStats(
        alignedRows: aligned,
        nameA: _stationA!.displayName,
        nameB: _stationB!.displayName,
        param: _selectedParam,
      );

      if (mounted) {
        setState(() {
          _pointsA = ptsA;
          _pointsB = ptsB;
          _alignedRows = aligned;
          _stats = stats;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
          _historyError = "Failed to load telemetry series: $e";
        });
      }
    }
  }

  /// Swap Station A and Station B
  void _swapStations() {
    if (_stationA == null || _stationB == null) return;
    setState(() {
      final temp = _stationA;
      _stationA = _stationB;
      _stationB = temp;
    });
    _fetchHistoricalData();
  }

  /// Open Station Picker Modal
  void _openStationPicker(bool isStationA) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StationPickerModal(
        stations: _allStations,
        currentSelected: isStationA ? _stationA : _stationB,
        isDark: isDark,
        title: isStationA
            ? "Select Station A (Primary)"
            : "Select Station B (Comparison)",
        accentColor: isStationA ? _colorA : _colorB,
        onSelect: (selected) {
          Navigator.pop(ctx);
          setState(() {
            if (isStationA) {
              _stationA = selected;
            } else {
              _stationB = selected;
            }
          });
          _fetchHistoricalData();
        },
      ),
    );
  }

  /// Preset Comparison Handlers
  void _applyPreset(String presetType) {
    if (_allStations.isEmpty) return;

    StationCandidate? a;
    StationCandidate? b;

    switch (presetType) {
      case 'punjab_kerala':
        a = _allStations.firstWhere(
          (s) =>
              s.sensorName.startsWith('PJ') ||
              s.state.toLowerCase().contains('punjab'),
          orElse: () => _allStations.first,
        );
        b = _allStations.firstWhere(
          (s) =>
              s.sensorName.startsWith('KR') ||
              s.state.toLowerCase().contains('kerala'),
          orElse: () => _allStations.last,
        );
        break;

      case 'campus_farm':
        a = _allStations.firstWhere(
          (s) =>
              s.sensorName.startsWith('CP') ||
              s.category.toLowerCase().contains('campus') ||
              s.displayName.contains('CP'),
          orElse: () => _allStations.first,
        );
        b = _allStations.firstWhere(
          (s) =>
              s.sensorName.startsWith('PJ') ||
              s.category.toLowerCase().contains('agri') ||
              s.sensorName.startsWith('WJ'),
          orElse: () => _allStations.last,
        );
        break;

      case 'same_cluster':
        final pjGroup =
            _allStations.where((s) => s.sensorName.startsWith('PJ')).toList();
        if (pjGroup.length >= 2) {
          a = pjGroup[0];
          b = pjGroup[1];
        } else {
          final krGroup =
              _allStations.where((s) => s.sensorName.startsWith('KR')).toList();
          if (krGroup.length >= 2) {
            a = krGroup[0];
            b = krGroup[1];
          }
        }
        break;
    }

    if (a != null && b != null) {
      setState(() {
        _stationA = a;
        _stationB = b;
      });
      _fetchHistoricalData();
    }
  }

  /// CSV Export Handler
  Future<void> _exportCsv() async {
    if (_stationA == null || _stationB == null || _alignedRows.isEmpty) {
      DeleteDeviceUtils.showToastNotification(
        context: context,
        title: "Export Notice",
        message: "No aligned telemetry points available to export.",
        isError: true,
      );
      return;
    }

    final csvContent = StationComparisonService.generateCsv(
      rows: _alignedRows,
      nameA: _stationA!.displayName,
      nameB: _stationB!.displayName,
      param: _selectedParam,
    );

    final cleanA = _stationA!.displayName.replaceAll(RegExp(r'\s+'), '_');
    final cleanB = _stationB!.displayName.replaceAll(RegExp(r'\s+'), '_');
    final paramName = _selectedParam.label.replaceAll(RegExp(r'\s+'), '_');
    final fileName =
        'CloudSense_Compare_${cleanA}_vs_${cleanB}_${paramName}_${_selectedDays}d.csv';

    await FileDownloadHelper.saveAndShareFile(
      context: context,
      fileName: fileName,
      fileContent: csvContent,
      mimeType: 'text/csv',
      shareSubject:
          'CloudSense Multi-Station Weather Comparison ($_selectedDays Days)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    final bgColor = isDark ? const Color(0xFF0B141D) : const Color(0xFFF4F7FB);
    final cardBg = isDark ? const Color(0xFF14212B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const AppBarWidget(),
      endDrawer: const EndDrawerWidget(),
      body: _isLoadingStations
          ? _buildLoadingState(isDark, "Loading nationwide weather stations...")
          : _stationCatalogError != null
              ? _buildErrorState(
                  isDark,
                  _stationCatalogError!,
                  onRetry: _loadStationCatalog,
                )
              : RefreshIndicator(
                  onRefresh: _fetchHistoricalData,
                  color: _colorA,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Preset Scenarios Quick Bar
                        _buildPresetScenariosBar(isDark),

                        // 3. Station Selector Contrast Cards
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 32.0,
                            vertical: 12.0,
                          ),
                          child: _buildStationSelectorCards(
                            isDark,
                            isMobile,
                            cardBg,
                            borderColor,
                            textColor,
                            subtextColor,
                          ),
                        ),

                        // 4. Metric Selector Chips (Temperature, Humidity, etc.)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 32.0,
                            vertical: 6.0,
                          ),
                          child: _buildMetricSelectorChips(isDark, cardBg),
                        ),

                        // 5. Controls: Time Range (24h, 7d, 30d) + View Mode (Timeline vs Scatter)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 32.0,
                            vertical: 8.0,
                          ),
                          child: _buildControlsBar(
                            isDark,
                            isMobile,
                            cardBg,
                            borderColor,
                          ),
                        ),



                        // 7. Interactive Chart Canvas (SfCartesianChart)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 32.0,
                            vertical: 12.0,
                          ),
                          child: _buildChartCard(
                            isDark,
                            isMobile,
                            cardBg,
                            borderColor,
                            textColor,
                          ),
                        ),

                        // 8. Aligned Data Table (Collapsible Preview & Export)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 12.0 : 32.0,
                            vertical: 12.0,
                          ),
                          child: _buildDataTableCard(
                            isDark,
                            isMobile,
                            cardBg,
                            borderColor,
                            textColor,
                            subtextColor,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // 9. Standard Footer
                        const Footer(),
                      ],
                    ),
                  ),
                ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hero Banner
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPresetScenariosBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isDark ? const Color(0xFF0E1A24) : const Color(0xFFE2E8F0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              "QUICK CONTRASTS:",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.blueGrey.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 12),
            _presetChip(
              label: "🌾 Punjab Plains vs Coastal Kerala",
              onTap: () => _applyPreset('punjab_kerala'),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _presetChip(
              label: "🏫 Campus Hub vs Agricultural Field",
              onTap: () => _applyPreset('campus_farm'),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _presetChip(
              label: "🔬 Same Cluster Micro-Deviance",
              onTap: () => _applyPreset('same_cluster'),
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _presetChip({
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: isDark ? const Color(0xFF1E2E3D) : Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.cyanAccent : const Color(0xFF0D47A1),
      ),
      elevation: 0,
      side: BorderSide(
        color: isDark ? Colors.white12 : Colors.grey.shade300,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Station Selector Contrast Cards
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildStationSelectorCards(
    bool isDark,
    bool isMobile,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    if (isMobile) {
      return Column(
        children: [
          _buildStationCard(
            station: _stationA,
            label: "STATION A (PRIMARY)",
            accentColor: _colorA,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isStationA: true,
            onTap: () => _openStationPicker(true),
          ),
          const SizedBox(height: 8),
          Center(
            child: Tooltip(
              message: "Swap Stations",
              child: IconButton.filled(
                onPressed: _swapStations,
                icon: const Icon(Icons.swap_vert_rounded),
                style: IconButton.styleFrom(
                  backgroundColor:
                      isDark ? const Color(0xFF263238) : Colors.white,
                  foregroundColor: textColor,
                  elevation: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildStationCard(
            station: _stationB,
            label: "STATION B (COMPARISON)",
            accentColor: _colorB,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isStationA: false,
            onTap: () => _openStationPicker(false),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _buildStationCard(
            station: _stationA,
            label: "STATION A (PRIMARY)",
            accentColor: _colorA,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isStationA: true,
            onTap: () => _openStationPicker(true),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Tooltip(
            message: "Swap Stations A & B",
            child: InkWell(
              onTap: _swapStations,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E2D3B) : Colors.white,
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFF00B0FF),
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _buildStationCard(
            station: _stationB,
            label: "STATION B (COMPARISON)",
            accentColor: _colorB,
            isDark: isDark,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            subtextColor: subtextColor,
            isStationA: false,
            onTap: () => _openStationPicker(false),
          ),
        ),
      ],
    );
  }

  Widget _buildStationCard({
    required StationCandidate? station,
    required String label,
    required Color accentColor,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    required VoidCallback onTap,
    required bool isStationA,
  }) {
    double? liveVal = station != null
        ? StationComparisonService.extractParamValue(
            station.raw, _selectedParam)
        : null;

    if (liveVal == null) {
      final pts = isStationA ? _pointsA : _pointsB;
      if (pts.isNotEmpty) {
        liveVal = pts.last.value;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withOpacity(isDark ? 0.45 : 0.6),
            width: 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag & change button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Change",
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: accentColor),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Station Name & ID
            if (station != null) ...[
              Text(
                station.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: subtextColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      station.location.isNotEmpty
                          ? station.location
                          : (station.state.isNotEmpty
                              ? station.state
                              : "Active Weather Node"),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: subtextColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Live Reading Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "LIVE ${_selectedParam.label.toUpperCase()}",
                        style: TextStyle(
                          color: subtextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        liveVal != null
                            ? "${liveVal.toStringAsFixed(1)} ${_selectedParam.unit}"
                            : "Updating...",
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: station.isActive
                          ? (isDark
                              ? const Color(0xFF00E676).withOpacity(0.15)
                              : Colors.green.shade50)
                          : (isDark
                              ? Colors.grey.withOpacity(0.2)
                              : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: station.isActive
                              ? const Color(0xFF00E676)
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          station.isActive ? "ONLINE" : "OFFLINE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: station.isActive
                                ? (isDark
                                    ? const Color(0xFF00E676)
                                    : Colors.green.shade800)
                                : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                "Click to choose station",
                style: TextStyle(color: subtextColor, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Metric Selector Chips
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildMetricSelectorChips(bool isDark, Color cardBg) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
          color: isDark ? Colors.white70 : Colors.black87,
          tooltip: "Slide Left",
          onPressed: () {
            if (_metricScrollController.hasClients) {
              _metricScrollController.animateTo(
                (_metricScrollController.offset - 200).clamp(0.0, _metricScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          },
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                ui.PointerDeviceKind.touch,
                ui.PointerDeviceKind.mouse,
                ui.PointerDeviceKind.trackpad,
              },
            ),
            child: SingleChildScrollView(
              controller: _metricScrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: ComparisonParam.values.map((param) {
          final isSelected = _selectedParam == param;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() {
                    _selectedParam = param;
                  });
                  _fetchHistoricalData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0D47A1)
                        : (isDark ? cardBg : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF00B0FF)
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF00B0FF).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(param.iconSymbol, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text(
                        param.label,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 12,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white : const Color(0xFF334155)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${param.unit})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isSelected
                              ? Colors.white.withOpacity(0.85)
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 26, minHeight: 36),
          color: isDark ? Colors.white70 : Colors.black87,
          tooltip: "Slide Right",
          onPressed: () {
            if (_metricScrollController.hasClients) {
              _metricScrollController.animateTo(
                (_metricScrollController.offset + 200).clamp(0.0, _metricScrollController.position.maxScrollExtent),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            }
          },
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Controls Bar (Time Range & View Mode)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildControlsBar(
    bool isDark,
    bool isMobile,
    Color cardBg,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          // Time range segmented tabs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "TIME RANGE:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 10),
              _rangeButton(label: "24 Hours", days: 1, isDark: isDark),
              const SizedBox(width: 6),
              _rangeButton(label: "7 Days", days: 7, isDark: isDark),
              const SizedBox(width: 6),
              _rangeButton(label: "30 Days", days: 30, isDark: isDark),
            ],
          ),

          // View mode toggle: Timeline vs Scatter
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "MODE:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (_isScatterMode) setState(() => _isScatterMode = false);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: !_isScatterMode
                          ? const Color(0xFF00B0FF).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: !_isScatterMode
                            ? const Color(0xFF00B0FF)
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart,
                          size: 16,
                          color: !_isScatterMode
                              ? const Color(0xFF00B0FF)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Timeline",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: !_isScatterMode
                                ? const Color(0xFF00B0FF)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    if (!_isScatterMode) setState(() => _isScatterMode = true);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isScatterMode
                          ? const Color(0xFF00E676).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isScatterMode
                            ? const Color(0xFF00E676)
                            : (isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bubble_chart_outlined,
                          size: 16,
                          color: _isScatterMode
                              ? const Color(0xFF00E676)
                              : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Scatter Correlation",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _isScatterMode
                                ? const Color(0xFF00E676)
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Export Combined CSV
          ElevatedButton.icon(
            onPressed: _exportCsv,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text("Export CSV"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E3A5F) : const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rangeButton({
    required String label,
    required int days,
    required bool isDark,
  }) {
    final isSelected = _selectedDays == days;
    return InkWell(
      onTap: () {
        if (!isSelected) {
          setState(() => _selectedDays = days);
          _fetchHistoricalData();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0D47A1)
              : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.grey.shade800),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Interactive Chart Canvas (SfCartesianChart)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildChartCard(
    bool isDark,
    bool isMobile,
    Color cardBg,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      height: isMobile ? 380 : 460,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart Header & Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isScatterMode
                    ? "Correlation Scatter: ${_stationA?.displayName ?? 'Station A'} (X) vs ${_stationB?.displayName ?? 'Station B'} (Y)"
                    : "Synchronized Time-Series: ${_selectedParam.label} (${_selectedParam.unit})",
                style: TextStyle(
                  color: textColor,
                  fontSize: isMobile ? 13 : 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!_isScatterMode)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _legendPill(
                        _stationA?.displayName ?? 'Station A', _colorA),
                    const SizedBox(width: 8),
                    _legendPill(
                        _stationB?.displayName ?? 'Station B', _colorB),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Chart Body / Loading Indicator
          Expanded(
            child: _isLoadingHistory
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: _colorA),
                        SizedBox(height: 12),
                        Text(
                          "Aligning telemetry streams...",
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : _historyError != null
                    ? Center(
                        child: Text(
                          _historyError!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : (_pointsA.isEmpty && _pointsB.isEmpty)
                        ? const Center(
                            child: Text(
                              "No historical telemetry points found for this range.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : _isScatterMode
                            ? _buildScatterChart(isDark, textColor)
                            : _buildTimelineChart(isDark, textColor),
          ),
        ],
      ),
    );
  }

  Widget _legendPill(String name, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          name,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Timeline Overlaid Line / Spline Series
  Widget _buildTimelineChart(bool isDark, Color textColor) {
    final dateFormat = _selectedDays == 1
        ? DateFormat('HH:mm')
        : (_selectedDays == 7 ? DateFormat('MM/dd HH:mm') : DateFormat('MM/dd'));

    return SfCartesianChart(
      plotAreaBackgroundColor: Colors.transparent,
      trackballBehavior: _trackballBehavior,
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: DateTimeAxis(
        dateFormat: dateFormat,
        title: AxisTitle(
          text: 'Timestamp (IST)',
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 10,
        ),
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text: '${_selectedParam.label} (${_selectedParam.unit})',
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 10,
        ),
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      series: <CartesianSeries<dynamic, dynamic>>[
        // Station A Spline Series
        SplineSeries<ComparisonPoint, DateTime>(
          dataSource: _pointsA,
          name: _stationA?.displayName ?? 'Station A',
          xValueMapper: (ComparisonPoint pt, _) => pt.timestamp,
          yValueMapper: (ComparisonPoint pt, _) => pt.value,
          color: _colorA,
          width: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: false,
            shape: DataMarkerType.circle,
            width: 4,
            height: 4,
          ),
        ),

        // Station B Spline Series
        SplineSeries<ComparisonPoint, DateTime>(
          dataSource: _pointsB,
          name: _stationB?.displayName ?? 'Station B',
          xValueMapper: (ComparisonPoint pt, _) => pt.timestamp,
          yValueMapper: (ComparisonPoint pt, _) => pt.value,
          color: _colorB,
          width: 2.5,
          markerSettings: const MarkerSettings(
            isVisible: false,
            shape: DataMarkerType.circle,
            width: 4,
            height: 4,
          ),
        ),
      ],
    );
  }

  /// Correlation Scatter Plot
  Widget _buildScatterChart(bool isDark, Color textColor) {
    // Extract valid paired points
    final paired = _alignedRows
        .where((r) => r.valA != null && r.valB != null)
        .toList();

    return SfCartesianChart(
      plotAreaBackgroundColor: Colors.transparent,
      tooltipBehavior: TooltipBehavior(enable: true),
      zoomPanBehavior: _zoomPanBehavior,
      primaryXAxis: NumericAxis(
        title: AxisTitle(
          text:
              '${_stationA?.displayName ?? 'Station A'} [${_selectedParam.unit}]',
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 10,
        ),
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      primaryYAxis: NumericAxis(
        title: AxisTitle(
          text:
              '${_stationB?.displayName ?? 'Station B'} [${_selectedParam.unit}]',
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        labelStyle: TextStyle(
          color: isDark ? Colors.white70 : Colors.black87,
          fontSize: 10,
        ),
        majorGridLines: MajorGridLines(
          color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
        ),
      ),
      series: <CartesianSeries<dynamic, dynamic>>[
        ScatterSeries<AlignedComparisonRow, num>(
          dataSource: paired,
          xValueMapper: (AlignedComparisonRow row, _) => row.valA!,
          yValueMapper: (AlignedComparisonRow row, _) => row.valB!,
          color: const Color(0xFF00E5FF),
          markerSettings: const MarkerSettings(
            shape: DataMarkerType.circle,
            width: 7,
            height: 7,
            borderColor: Colors.white,
            borderWidth: 1,
          ),
          name: 'Synchronized Observation',
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Aligned Data Table (Collapsible Preview & Export)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildDataTableCard(
    bool isDark,
    bool isMobile,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color subtextColor,
  ) {
    final validRows = _alignedRows.reversed.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(
                "Synchronized Data Table (${_alignedRows.length} time buckets)",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                "Inspect paired telemetry values aligned in 30-min intervals",
                style: TextStyle(color: subtextColor, fontSize: 12),
              ),
              trailing: IconButton(
                icon: Icon(
                  _isTableExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: textColor,
                ),
                onPressed: () {
                  setState(() => _isTableExpanded = !_isTableExpanded);
                },
              ),
              onTap: () {
                setState(() => _isTableExpanded = !_isTableExpanded);
              },
            ),
          ),
          if (_isTableExpanded) ...[
            const Divider(height: 1),
            if (validRows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  "No aligned telemetry points to display.",
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: isMobile ? 18 : 36,
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? Colors.white.withOpacity(0.04)
                        : Colors.grey.shade100,
                  ),
                  columns: [
                    const DataColumn(label: Text('Timestamp (IST)')),
                    DataColumn(
                        label: Text(_stationA?.displayName ?? 'Station A')),
                    DataColumn(
                        label: Text(_stationB?.displayName ?? 'Station B')),
                    const DataColumn(label: Text('Delta (Δ)')),
                  ],
                  rows: validRows.map((r) {
                    final d = r.deltaAB;
                    final dStr = d != null
                        ? "${d > 0 ? '+' : ''}${d.toStringAsFixed(2)} ${_selectedParam.unit}"
                        : "--";
                    return DataRow(
                      cells: [
                        DataCell(Text(
                          DateFormat('dd MMM HH:mm').format(r.timestamp),
                          style: TextStyle(color: textColor, fontSize: 12),
                        )),
                        DataCell(Text(
                          r.valA != null
                              ? "${r.valA!.toStringAsFixed(1)} ${_selectedParam.unit}"
                              : "--",
                          style: const TextStyle(
                              color: _colorA,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        )),
                        DataCell(Text(
                          r.valB != null
                              ? "${r.valB!.toStringAsFixed(1)} ${_selectedParam.unit}"
                              : "--",
                          style: const TextStyle(
                              color: _colorB,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        )),
                        DataCell(Text(
                          dStr,
                          style: TextStyle(
                            color: d != null && d > 0
                                ? _colorDelta
                                : Colors.blueGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text("Download Full Aligned CSV"),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00B0FF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Loading & Error States
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _colorA),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark, String error, {VoidCallback? onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 54, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              "Unable to load stations",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            if (onRetry != null)
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Connection"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colorA,
                  foregroundColor: Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Searchable Station Picker Modal Sheet
// ────────────────────────────────────────────────────────────────────────────
class _StationPickerModal extends StatefulWidget {
  final List<StationCandidate> stations;
  final StationCandidate? currentSelected;
  final bool isDark;
  final String title;
  final Color accentColor;
  final ValueChanged<StationCandidate> onSelect;

  const _StationPickerModal({
    required this.stations,
    required this.currentSelected,
    required this.isDark,
    required this.title,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  State<_StationPickerModal> createState() => _StationPickerModalState();
}

class _StationPickerModalState extends State<_StationPickerModal> {
  String _searchQuery = "";
  String _selectedCategory = "All";

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final modalBg = isDark ? const Color(0xFF14212B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    // Compute Admin-style category counts matching Admin Page
    int annamCount = 0;
    int partnershipCount = 0;
    int testingCount = 0;

    for (final s in widget.stations) {
      if (DevicePrefixUtils.isAnnamTestingSensor(s.sensorName)) {
        testingCount++;
      } else if (DevicePrefixUtils.isAnnamCoreSensor(s.sensorName)) {
        annamCount++;
      } else {
        partnershipCount++;
      }
    }

    final brands = ["All", "ANNAM", "Partnership", "Testing"];

    String getBrandLabel(String brand) {
      switch (brand) {
        case "All":
          return "All (${widget.stations.length})";
        case "ANNAM":
          return "ANNAM ($annamCount)";
        case "Partnership":
          return "Partnership ($partnershipCount)";
        case "Testing":
          return "Testing ($testingCount)";
        default:
          return brand;
      }
    }

    bool matchesBrand(StationCandidate s, String brand) {
      if (brand == "All") return true;
      if (brand == "Testing") {
        return DevicePrefixUtils.isAnnamTestingSensor(s.sensorName);
      }
      if (brand == "ANNAM") {
        return DevicePrefixUtils.isAnnamCoreSensor(s.sensorName) &&
            !DevicePrefixUtils.isAnnamTestingSensor(s.sensorName);
      }
      if (brand == "Partnership") {
        return !DevicePrefixUtils.isAnnamCoreSensor(s.sensorName) &&
            !DevicePrefixUtils.isAnnamTestingSensor(s.sensorName);
      }
      return true;
    }

    // Filter list
    final filtered = widget.stations.where((s) {
      final matchesCategory = matchesBrand(s, _selectedCategory);

      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          s.displayName.toLowerCase().contains(q) ||
          s.sensorName.toLowerCase().contains(q) ||
          s.location.toLowerCase().contains(q) ||
          s.state.toLowerCase().contains(q);

      return matchesCategory && matchesSearch;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: modalBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                color: textColor,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search Bar
          TextField(
            autofocus: false,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: "Search by station name, ID, or district...",
              hintStyle: TextStyle(color: subtextColor, fontSize: 13),
              prefixIcon: Icon(Icons.search, color: widget.accentColor),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) {
              setState(() => _searchQuery = val);
            },
          ),
          const SizedBox(height: 12),

          // Category Chips matching Admin Page [All (count)] [ANNAM (count)] [Partnership (count)] [Testing (count)]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: brands.map((brand) {
                final isSelected = _selectedCategory == brand;
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() => _selectedCategory = brand);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF555F6D)
                                  : const Color(0xFF334155))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.black26),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              getBrandLabel(brand),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24),

          // Station List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      "No matching stations found.",
                      style: TextStyle(color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final s = filtered[idx];
                      final isSelected =
                          widget.currentSelected?.sensorName == s.sensorName;

                      return ListTile(
                        onTap: () => widget.onSelect(s),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        selected: isSelected,
                        selectedTileColor: widget.accentColor.withOpacity(0.12),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: s.isActive
                                ? const Color(0xFF00E676).withOpacity(0.15)
                                : Colors.grey.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sensors_rounded,
                            color: s.isActive
                                ? const Color(0xFF00E676)
                                : Colors.grey,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          s.displayName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          "${s.category.isNotEmpty ? s.category : 'Weather Node'}  •  ${s.location.isNotEmpty ? s.location : s.state}",
                          style: TextStyle(color: subtextColor, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle,
                                color: widget.accentColor, size: 20)
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
