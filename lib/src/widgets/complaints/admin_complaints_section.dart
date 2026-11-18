import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_sense_webapp/src/models/complaint_model.dart';
import 'package:cloud_sense_webapp/src/services/complaint_service.dart';
import 'package:cloud_sense_webapp/src/utils/auth_utils.dart';
import 'package:cloud_sense_webapp/src/widgets/complaints/complaint_attachments_widget.dart';

class AdminComplaintsSection extends StatefulWidget {
  final bool isDarkMode;
  final String? currentAdminEmail;
  final void Function(String deviceId)? onInspectDevice;

  const AdminComplaintsSection({
    super.key,
    required this.isDarkMode,
    this.currentAdminEmail,
    this.onInspectDevice,
  });

  @override
  State<AdminComplaintsSection> createState() => _AdminComplaintsSectionState();
}

class _AdminComplaintsSectionState extends State<AdminComplaintsSection> {
  final ComplaintService _complaintService = ComplaintService();

  bool _isLoading = true;
  List<ComplaintTicket> _allTickets = [];
  String _statusFilter = 'All';
  String _searchQuery = '';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final list = await _complaintService.getAllComplaints();

      if (mounted) {
        setState(() {
          _allTickets = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdminComplaints] Error: $e');
      if (mounted) {
        setState(() {
          _loadError = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  List<ComplaintTicket> get _filteredTickets {
    return _allTickets.where((t) {
      // Status filter
      if (_statusFilter != 'All') {
        if (_statusFilter == 'Open' &&
            !(t.status == ComplaintStatus.open ||
                t.status == ComplaintStatus.waitingForUser ||
                t.status == ComplaintStatus.reopened)) {
          return false;
        }
        if (_statusFilter == 'In Progress' &&
            t.status != ComplaintStatus.inProgress) {
          return false;
        }
        if (_statusFilter == 'Resolved' &&
            !(t.status == ComplaintStatus.resolved ||
                t.status == ComplaintStatus.closed)) {
          return false;
        }
      }

      // Search query
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final match = t.ticketId.toLowerCase().contains(q) ||
            t.deviceId.toLowerCase().contains(q) ||
            t.userEmail.toLowerCase().contains(q) ||
            t.subject.toLowerCase().contains(q) ||
            t.displayCategory.toLowerCase().contains(q);
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  void _openDetailModal(ComplaintTicket ticket) {
    showDialog(
      context: context,
      builder: (ctx) => _AdminTicketDetailDialog(
        ticket: ticket,
        isDarkMode: widget.isDarkMode,
        adminEmail: widget.currentAdminEmail ?? 'admin@cloudsense.com',
        onUpdated: () => _loadComplaints(),
        onInspectDevice: widget.onInspectDevice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;

    final cardBg = isDark ? const Color(0xFF132230) : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF0284C7).withOpacity(0.25)
        : const Color(0xFFE2E8F0);

    final totalCount = _allTickets.length;
    final openCount = _allTickets.where((t) =>
        t.status == ComplaintStatus.open ||
        t.status == ComplaintStatus.waitingForUser ||
        t.status == ComplaintStatus.reopened).length;
    final inProgressCount = _allTickets
        .where((t) => t.status == ComplaintStatus.inProgress)
        .length;
    final criticalCount = _allTickets
        .where((t) =>
            t.priority == ComplaintPriority.critical &&
            t.status != ComplaintStatus.resolved &&
            t.status != ComplaintStatus.closed)
        .length;
    final resolvedCount = _allTickets
        .where((t) =>
            t.status == ComplaintStatus.resolved ||
            t.status == ComplaintStatus.closed)
        .length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1A24) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      padding: EdgeInsets.all(isMobile ? 14 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Row ──
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Complaints & Support',
                      style: TextStyle(
                        fontFamily: 'OpenSans',
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Review customer-reported hardware anomalies, manage resolution workflows, and reply directly',
                      style: TextStyle(
                        fontSize: isMobile ? 11.5 : 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loadComplaints,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Tickets',
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Metric Summary Cards ──
          LayoutBuilder(
            builder: (context, constraints) {
              final double maxW = constraints.maxWidth;
              // Responsive column count based on available width:
              // ≥ 720px: 4 cards in 1 row (4 columns)
              // 260px - 719px: 2 cards in each row (2x2 grid for mobile)
              // < 260px: 1 card per row
              final int columns = maxW >= 720
                  ? 4
                  : (maxW >= 260 ? 2 : 1);
              final double spacing = columns == 4 ? 12.0 : 8.0;
              final double totalSpacing = spacing * (columns - 1);
              final double cardWidth =
                  ((maxW - totalSpacing) / columns).floorToDouble();
              final bool isCompact = columns != 4;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  _buildMetricCard(
                    title: 'Total Tickets',
                    value: '$totalCount',
                    subtitle: 'Lifetime received',
                    icon: Icons.confirmation_number_outlined,
                    color: const Color(0xFF0284C7),
                    width: cardWidth,
                    isDark: isDark,
                    isCompact: isCompact,
                  ),
                  _buildMetricCard(
                    title: 'Pending / Open',
                    value: '$openCount',
                    subtitle: 'Awaiting review',
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFF59E0B),
                    width: cardWidth,
                    isDark: isDark,
                    isCompact: isCompact,
                  ),
                  _buildMetricCard(
                    title: 'Critical Urgency',
                    value: '$criticalCount',
                    subtitle: 'Active emergencies',
                    icon: Icons.warning_amber_rounded,
                    color: const Color(0xFFEF4444),
                    width: cardWidth,
                    isDark: isDark,
                    isCompact: isCompact,
                  ),
                  _buildMetricCard(
                    title: 'Resolved',
                    value: '$resolvedCount',
                    subtitle: 'Successfully closed',
                    icon: Icons.check_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    width: cardWidth,
                    isDark: isDark,
                    isCompact: isCompact,
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── Filters & Search Bar ──
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 10 : 14,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search field (full width)
                      SizedBox(
                        height: 38,
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by ticket, device, user...',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F1A24)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Status Chips (horizontally scrollable without overflow)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: ['All', 'Open', 'In Progress', 'Resolved'].map((s) {
                            final isSel = _statusFilter == s;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                selected: isSel,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                label: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                selectedColor: const Color(0xFF0284C7),
                                backgroundColor: isDark
                                    ? const Color(0xFF0F1A24)
                                    : const Color(0xFFF1F5F9),
                                onSelected: (_) => setState(() => _statusFilter = s),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Search field
                      SizedBox(
                        width: 280,
                        height: 38,
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search by ticket, device, user...',
                            hintStyle: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18),
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: isDark
                                ? const Color(0xFF0F1A24)
                                : const Color(0xFFF1F5F9),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),

                      // Status Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'Open', 'In Progress', 'Resolved'].map((s) {
                            final isSel = _statusFilter == s;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                selected: isSel,
                                showCheckmark: false,
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                label: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                                    color: isSel
                                        ? Colors.white
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                                selectedColor: const Color(0xFF0284C7),
                                backgroundColor: isDark
                                    ? const Color(0xFF0F1A24)
                                    : const Color(0xFFF1F5F9),
                                onSelected: (_) => setState(() => _statusFilter = s),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 16),

          // ── Complaints List / Table ──
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_filteredTickets.isEmpty)
            _buildEmptyState(isDark)
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredTickets.length,
              itemBuilder: (context, index) {
                final ticket = _filteredTickets[index];
                return _buildTicketRow(ticket, isDark, cardBg, borderColor);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required double width,
    required bool isDark,
    bool isCompact = false,
  }) {
    return Container(
      width: width,
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 16,
        vertical: isCompact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF132230) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.35 : 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(icon, size: isCompact ? 15 : 18, color: color),
            ],
          ),
          SizedBox(height: isCompact ? 4 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 19 : 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 9.5 : 10.5,
              color: isDark ? Colors.white38 : Colors.black45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketRow(ComplaintTicket ticket, bool isDark, Color cardBg,
      Color borderColor) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ticket.priority == ComplaintPriority.critical
              ? const Color(0xFFEF4444).withOpacity(0.4)
              : borderColor,
          width: ticket.priority == ComplaintPriority.critical ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Category icon
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: ticket.category.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ticket.category.icon,
                color: ticket.category.color, size: 20),
          ),
          const SizedBox(width: 14),

          // Main Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white12
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        ticket.ticketId,
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Priority Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: ticket.priority.color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ticket.priority.icon,
                              size: 10, color: ticket.priority.color),
                          const SizedBox(width: 3),
                          Text(
                            ticket.priority.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: ticket.priority.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Custom Category Highlight
                    if (ticket.isCustomCategory) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.edit_note,
                                size: 11, color: Color(0xFF10B981)),
                            const SizedBox(width: 3),
                            Text(
                              'CUSTOM: ${ticket.displayCategory}',
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ticket.status.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: ticket.status.color.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(ticket.status.icon,
                              size: 11, color: ticket.status.color),
                          const SizedBox(width: 4),
                          Text(
                            ticket.status.label,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: ticket.status.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  ticket.subject,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.sensors_rounded,
                        size: 13,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      ticket.deviceId,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.email_outlined,
                        size: 13,
                        color: isDark ? Colors.white54 : Colors.black45),
                    const SizedBox(width: 4),
                    Text(
                      ticket.userEmail,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.access_time_rounded,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(ticket.updatedAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Action Button
          ElevatedButton.icon(
            onPressed: () => _openDetailModal(ticket),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.reply_rounded, size: 14),
            label: const Text(
              'Respond',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 42, color: Color(0xFFEF4444)),
              const SizedBox(height: 10),
              Text(
                'Failed to load tickets: $_loadError',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadComplaints,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 42, color: isDark ? Colors.white24 : Colors.black26),
            const SizedBox(height: 10),
            Text(
              'No complaints match the selected filter',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTicketDetailDialog extends StatefulWidget {
  final ComplaintTicket ticket;
  final bool isDarkMode;
  final String adminEmail;
  final VoidCallback onUpdated;
  final void Function(String deviceId)? onInspectDevice;

  const _AdminTicketDetailDialog({
    required this.ticket,
    required this.isDarkMode,
    required this.adminEmail,
    required this.onUpdated,
    this.onInspectDevice,
  });

  @override
  State<_AdminTicketDetailDialog> createState() =>
      _AdminTicketDetailDialogState();
}

class _AdminTicketDetailDialogState extends State<_AdminTicketDetailDialog> {
  final ComplaintService _complaintService = ComplaintService();
  late ComplaintTicket _ticket;
  late ComplaintStatus _selectedStatus;
  final TextEditingController _replyController = TextEditingController();
  bool _isSaving = false;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _ticket = widget.ticket;
    _selectedStatus = widget.ticket.status == ComplaintStatus.waitingForUser
        ? ComplaintStatus.open
        : widget.ticket.status;
    _loadTicketDetails();
  }

  Future<void> _loadTicketDetails() async {
    setState(() => _isLoadingDetails = true);
    try {
      final detailed =
          await _complaintService.getComplaintById(widget.ticket.ticketId);
      if (detailed != null && mounted) {
        setState(() {
          _ticket = detailed;
          _selectedStatus = detailed.status == ComplaintStatus.waitingForUser
              ? ComplaintStatus.open
              : detailed.status;
          _isLoadingDetails = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);

    try {
      final replyText = _replyController.text.trim();

      // 1. If reply is typed, add response (which can also update status)
      if (replyText.isNotEmpty) {
        await _complaintService.addAdminResponse(
          ticketId: _ticket.ticketId,
          responderName: 'CloudSense Support',
          responderEmail: widget.adminEmail,
          message: replyText,
          newStatus: _selectedStatus != _ticket.status ? _selectedStatus : null,
        );
      } else if (_selectedStatus != _ticket.status) {
        // Only status changed
        await _complaintService.updateComplaintStatus(
          ticketId: _ticket.ticketId,
          status: _selectedStatus,
          adminEmail: widget.adminEmail,
        );
      }

      widget.onUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Ticket updated and response sent!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error updating ticket: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    final bgColor = isDark ? const Color(0xFF0F1E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF162A3F) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF0284C7).withOpacity(0.25)
        : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Compact, Clean Header ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _ticket.ticketId,
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _ticket.priority.color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _ticket.priority.label.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _ticket.priority.color,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Body ──
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subject Headline
                        Text(
                          _ticket.subject,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Subtitle: user info & device
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 13,
                                color: isDark ? Colors.white54 : Colors.black45),
                            const SizedBox(width: 4),
                            Text(
                              '${_ticket.userName} (${_ticket.userEmail})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Issue Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ticket.description,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white : Colors.black87,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Divider(height: 1, color: isDark ? Colors.white10 : Colors.black12),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // Category chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: _ticket.category.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_ticket.category.icon,
                                            size: 12, color: _ticket.category.color),
                                        const SizedBox(width: 4),
                                        Text(
                                          _ticket.displayCategory,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: _ticket.category.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Device chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sensors_rounded,
                                            size: 12, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          _ticket.deviceId,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0284C7),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (widget.onInspectDevice != null) ...[
                                    InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        widget.onInspectDevice!(_ticket.deviceId);
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(Icons.analytics_outlined,
                                              size: 13, color: Color(0xFF0284C7)),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'Inspect',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0284C7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Attachments (Photos)
                        if (_ticket.attachmentUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ComplaintAttachmentsWidget(
                            attachments: _ticket.attachmentUrls,
                            isDark: isDark,
                            isCompact: true,
                          ),
                        ],

                        // Existing Conversation
                        if (_ticket.adminResponses.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text(
                            'Conversation History',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ..._ticket.adminResponses.map((r) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor.withOpacity(0.6)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        r.responderName,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        dateFormat.format(r.timestamp),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: isDark ? Colors.white38 : Colors.black38,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    r.message,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  if (r.attachments.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    ComplaintAttachmentsWidget(
                                      attachments: r.attachments
                                          .map((a) => a.url ?? '')
                                          .where((u) => u.isNotEmpty)
                                          .toList(),
                                      isDark: isDark,
                                      isCompact: true,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],

                        const SizedBox(height: 16),

                        // Update Status Control
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Update Status',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<ComplaintStatus>(
                                  value: _selectedStatus,
                                  isExpanded: true,
                                  dropdownColor: isDark ? const Color(0xFF0F1E2E) : Colors.white,
                                  items: ComplaintStatus.values
                                      .where((s) => s != ComplaintStatus.waitingForUser)
                                      .map((s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        Icon(s.icon, size: 14, color: s.color),
                                        const SizedBox(width: 8),
                                        Text(
                                          s.label,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: s.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedStatus = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Reply Field
                        Text(
                          'Reply to Customer',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _replyController,
                          maxLines: 2,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type resolution message to customer...',
                            filled: true,
                            fillColor: cardBg,
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Footer ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    border: Border(top: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 15),
                        label: const Text(
                          'Save & Update',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
