  Widget _buildDeviceTable(bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final cardBg = isDark ? Colors.black.withOpacity(0.15) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.1);

    if (_filteredDevices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: strong.withOpacity(0.2)),
              const SizedBox(height: 16),
              Text(
                'No devices found',
                style: TextStyle(color: strong.withOpacity(0.4), fontSize: 18),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adjusted minWidth after removing Location column
          return Scrollbar(
            controller: _mainHorizontalController,
            thumbVisibility: true,
            thickness: 4,
            child: SingleChildScrollView(
              controller: _mainHorizontalController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width:
                    constraints.maxWidth > 1320 ? constraints.maxWidth : 1320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTableHeader(true, isDark),
                    ..._filteredDevices.asMap().entries.take(_visibleCount).map(
                        (entry) => _buildTableRow(
                            entry.value, entry.key, true, isDark)),
                    if (_visibleCount < _filteredDevices.length || _hasMore)
                      _buildLoadMoreButton(isDark),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? CircularProgressIndicator(color: strong, strokeWidth: 2)
            : ElevatedButton.icon(
                onPressed: _loadMoreDevices,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Load More Devices'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
              ),
      ),
    );
  }

  Future<void> _onDeviceTap(DeviceHealthData device, bool isDark) async {
    if (device.isDetailed) {
      _showHealthDetailsDialog(device, isDark);
      return;
    }

    // Show loading overlay or dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.blueAccent),
      ),
    );

    final detailedDevice = await _fetchDetailedDeviceData(device.deviceIdTopic);

    // Close loading indicator
    if (mounted) Navigator.pop(context);

    if (detailedDevice != null && mounted) {
      // Update the device in _allDevices if it exists
      setState(() {
        final index = _allDevices
            .indexWhere((d) => d.deviceIdTopic == device.deviceIdTopic);
        if (index != -1) {
          _allDevices[index] = detailedDevice.copyWith(
            city: device.city,
            district: device.district,
            state: device.state,
          );
          _applyFilters();
        }
      });
      _showHealthDetailsDialog(detailedDevice, isDark);
    } else if (mounted) {
      // Fallback: show what we have but maybe warn?
      _showHealthDetailsDialog(device, isDark);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load detailed diagnostics.')),
      );
    }
  }

  void _onQualityCheckTap(DeviceHealthData device, bool isDark) {
    NavigationUtils.navigateTo(
      context,
      '/admin/health/quality-diagnostics',
      arguments: {
        'deviceId': device.deviceId,
        'deviceIdTopic': device.deviceIdTopic,
        'displayName': device.displayName,
        'isDark': isDark,
      },
    );
  }

  Widget _buildTableHeader(bool isExpanded, bool isDark) {
    final cardHeaderBg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.02);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1);

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: cardHeaderBg,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16), topRight: Radius.circular(16)),
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.stretch, // Ensure dividers reach top/bottom
          children: [
            _HeaderCell(
                label: '#',
                width: 60,
                flex: 0,
                isExpanded: false,
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'DEVICE ID & LOCATION',
                width: 280,
                flex: 4,
                isExpanded: false, // Fixed width
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'OVERALL',
                width: 100,
                flex: 1,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _overallFilter,
                filterOptions: const [
                  'All',
                  'OK',
                  'Warning',
                  'Critical',
                  'Offline'
                ],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _overallFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'BATTERY',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _batteryFilter,
                filterOptions: const ['All', 'OK', 'Warning', 'Critical'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _batteryFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'SD CARD',
                width: 130,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _sdCardFilter,
                filterOptions: const ['All', 'Mounted', 'Not Mounted'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _sdCardFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'SIGNAL',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true,
                filterValue: _signalFilter,
                filterOptions: const ['All', 'OK', 'Warning', 'Critical'],
                onFilterChanged: (val) {
                  if (val != null) {
                    setState(() => _signalFilter = val);
                    _saveFilters();
                    _applyFilters();
                  }
                }),
            _HeaderCell(
                label: 'AVG COMPLETENESS',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: true),
            _HeaderCell(
                label: 'LAST ACTIVE',
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                isDark: isDark,
                showBorder: false),

            // No border for last cell
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(
      DeviceHealthData device, int index, bool isExpanded, bool isDark) {
    final strong = isDark ? Colors.white : Colors.black;
    final subtle = isDark ? Colors.white70 : Colors.black54;
    final hint =
        isDark ? Colors.white.withOpacity(0.6) : Colors.black.withOpacity(0.6);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.05);

    final alternateColor =
        isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8FAFC);

    return IntrinsicHeight(
      child: Container(
        decoration: BoxDecoration(
          color: index % 2 == 1 ? alternateColor : Colors.transparent,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: InkWell(
          onTap: () => _onDeviceTap(device, isDark),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DataCell(
                width: 60,
                flex: 0,
                isExpanded: false,
                showBorder: true,
                isDark: isDark,
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                        color: subtle,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _DataCell(
                width: 280,
                flex: 4,
                isExpanded: false, // Fixed width
                showBorder: true,
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // Centered
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      device.displayName,
                      textAlign: TextAlign.center, // Centered
                      style: TextStyle(
                          color: strong,
                          fontWeight: FontWeight.bold,
                          fontSize: isExpanded ? 13 : 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.location,
                      textAlign: TextAlign.center, // Centered
                      style:
                          TextStyle(color: hint, fontSize: isExpanded ? 11 : 9),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 100,
                flex: 1,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _onDeviceTap(device, isDark),
                      borderRadius: BorderRadius.circular(6),
                      child: _buildStatusBadge(device.healthStatus,
                          isSmall: !isExpanded),
                    ),
                    if (device.healthStatus == 'ok' ||
                        device.healthStatus == 'warning') ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _onQualityCheckTap(device, isDark),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.8), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.1),
                                blurRadius: 4,
                                spreadRadius: 1,
                              )
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: const Text(
                              'Quality Check',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                            DevicePrefixUtils.getBatteryIcon(
                                _voltageToPercentage(device.batteryVoltage)
                                    .toInt()),
                            color: _getBatteryColor(device.batteryVoltage),
                            size: isExpanded ? 16 : 14),
                        const SizedBox(width: 6),
                        Text(
                            '${device.batteryVoltage.toStringAsFixed(2)} V (${_voltageToPercentage(device.batteryVoltage).toStringAsFixed(2)}%)',
                            style: TextStyle(
                                color: subtle, fontSize: isExpanded ? 12 : 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.batteryStatus.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(device.batteryStatus),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 130,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      device.sdCardMounted ? 'Mounted' : 'Not Mounted',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: device.sdCardMounted
                            ? Colors.greenAccent
                            : Colors.redAccent,
                        fontSize: isExpanded ? 12 : 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.sdCardStatus.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(device.sdCardStatus),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getSignalIcon(device.signalDbm),
                            color: _getSignalColor(device.signalDbm),
                            size: isExpanded ? 16 : 14),
                        const SizedBox(width: 6),
                        Text('${device.signalDbm} dBm',
                            style: TextStyle(
                                color: subtle, fontSize: isExpanded ? 12 : 10)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.signalStatus.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(device.signalStatus),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: true,
                isDark: isDark,
                child: Text(
                  '${device.avgCompleteness7d.toStringAsFixed(2)}%',
                  style: TextStyle(
                      color: subtle,
                      fontSize: isExpanded ? 12 : 10,
                      fontWeight: FontWeight.bold),
                ),
              ),
              _DataCell(
                width: 120,
                flex: 2,
                isExpanded: isExpanded,
                showBorder: false, // No border for last cell
                isDark: isDark,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatLastActive(device.lastActiveMinsAgo),
                      textAlign: TextAlign.center, // Centered
                      style: TextStyle(
                          color: subtle, fontSize: isExpanded ? 12 : 10),
                    ),
                    if (device.missingParameters.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Tooltip(
                        message: device.missingParameters.join(", "),
                        child: Text(
                          'Missing: ${device.missingParameters.length}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }

  Color _getStatusColor(String status) {
    status = status.toLowerCase().trim();
    if (status == 'ok' || status == 'online' || status == 'mounted') {
      return const Color(0xFF10B981); // Emerald / Online
    }
    if (status == 'warning') {
      return const Color(0xFFF59E0B); // Amber / Warning
    }
    if (status == 'critical' || status == 'fail' || status == 'low') {
      return const Color(0xFFF43F5E); // Rose / Critical
    }
    if (status == 'offline') {
      return const Color(0xFF94A3B8); // Slate / Offline
    }
    return Colors.grey;
  }

