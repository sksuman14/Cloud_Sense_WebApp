import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_sense_webapp/main.dart';
import 'package:cloud_sense_webapp/src/models/complaint_model.dart';
import 'package:cloud_sense_webapp/src/services/complaint_service.dart';
import 'package:cloud_sense_webapp/src/widgets/complaints/raise_complaint_dialog.dart';
import 'package:cloud_sense_webapp/src/widgets/complaints/complaint_attachments_widget.dart';

class UserComplaintsSheet extends StatefulWidget {
  final List<String> availableDevices;

  const UserComplaintsSheet({
    super.key,
    this.availableDevices = const [],
  });

  static void show(BuildContext context, {List<String> availableDevices = const []}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UserComplaintsSheet(availableDevices: availableDevices),
    );
  }

  @override
  State<UserComplaintsSheet> createState() => _UserComplaintsSheetState();
}

class _UserComplaintsSheetState extends State<UserComplaintsSheet> {
  final ComplaintService _complaintService = ComplaintService();
  bool _isLoading = true;
  List<ComplaintTicket> _tickets = [];
  String _statusFilter = 'All';

  final Map<String, TextEditingController> _replyControllers = {};

  @override
  void initState() {
    super.initState();
    _loadUserTickets();
  }

  @override
  void dispose() {
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserTickets() async {
    setState(() => _isLoading = true);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail ?? '';

    // If no email, fallback to sample user so preview works
    final tickets = email.isNotEmpty
        ? await _complaintService.getComplaintsForUser(email)
        : await _complaintService.getAllComplaints();

    if (mounted) {
      setState(() {
        _tickets = tickets;
        _isLoading = false;
      });
      // Fetch details for initial active tickets in background
      for (final t in tickets.take(3)) {
        _fetchTicketDetails(t.ticketId);
      }
    }
  }

  Future<void> _fetchTicketDetails(String ticketId) async {
    try {
      final detailed = await _complaintService.getComplaintById(ticketId);
      if (detailed != null && mounted) {
        setState(() {
          final idx = _tickets.indexWhere((t) => t.ticketId == ticketId);
          if (idx != -1) {
            _tickets[idx] = detailed;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _sendFollowUp(ComplaintTicket ticket) async {
    final controller = _replyControllers[ticket.ticketId];
    if (controller == null || controller.text.trim().isEmpty) return;

    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final email = userProvider.userEmail ?? 'user@cloudsense.com';
    final name = userProvider.userName ?? email.split('@').first;

    try {
      await _complaintService.addUserFollowUp(
        ticketId: ticket.ticketId,
        userEmail: email,
        userName: name,
        message: controller.text.trim(),
      );

      controller.clear();
      await _loadUserTickets();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Follow-up message sent to support team!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to send reply: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showReopenDialog(ComplaintTicket ticket) async {
    final reasonController = TextEditingController();
    bool isSubmitting = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF132230) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.replay_rounded,
                      color: Color(0xFFEC4899),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Reopen Ticket',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Please provide a reason or additional details for reopening this ticket:',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 4,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. Issue persists, device stopped updating again...',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F1E2E)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFEC4899),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final reason = reasonController.text.trim();
                          if (reason.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a reason for reopening this ticket'),
                                backgroundColor: Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          final userProvider = Provider.of<UserProvider>(context, listen: false);
                          final email = userProvider.userEmail ?? 'user@cloudsense.com';
                          final name = userProvider.userName ?? email.split('@').first;

                          try {
                            await _complaintService.reopenComplaint(
                              ticketId: ticket.ticketId,
                              userEmail: email,
                              userName: name,
                              reason: reason,
                            );

                            if (mounted) {
                              Navigator.of(dialogCtx).pop();
                              setState(() {
                                ticket.status = ComplaintStatus.reopened;
                              });
                              await _loadUserTickets();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: Color(0xFF10B981),
                                  content: Text('Ticket has been successfully reopened!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: const Color(0xFFEF4444),
                                  content: Text('Failed to reopen ticket: $e'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEC4899),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Reopen Ticket',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 650;

    final bgColor = isDark ? const Color(0xFF0F1E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF162A3F) : const Color(0xFFF8FAFC);
    final borderColor = isDark
        ? const Color(0xFF0284C7).withOpacity(0.25)
        : const Color(0xFFE2E8F0);

    final filteredTickets = _tickets.where((t) {
      if (_statusFilter == 'All') return true;
      if (_statusFilter == 'Open') {
        return t.status == ComplaintStatus.open ||
            t.status == ComplaintStatus.waitingForUser ||
            t.status == ComplaintStatus.inProgress ||
            t.status == ComplaintStatus.reopened;
      }
      if (_statusFilter == 'Resolved') {
        return t.status == ComplaintStatus.resolved ||
            t.status == ComplaintStatus.closed;
      }
      return true;
    }).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.88,
        maxWidth: 800,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Grab Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_late_outlined,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Support Tickets',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track reported issues and replies from our team',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final newTicket = await RaiseComplaintDialog.show(
                      context,
                      availableDevices: widget.availableDevices,
                    );
                    if (newTicket != null) {
                      _loadUserTickets();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Report Issue',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Filter bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                _buildFilterChip('All', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Open', isDark),
                const SizedBox(width: 8),
                _buildFilterChip('Resolved', isDark),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  tooltip: 'Refresh Tickets',
                  onPressed: _loadUserTickets,
                ),
              ],
            ),
          ),

          const Divider(height: 16),

          // Body List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredTickets.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        itemCount: filteredTickets.length,
                        itemBuilder: (context, index) {
                          final ticket = filteredTickets[index];
                          return _buildTicketCard(ticket, isDark, cardBg);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isDark) {
    final isSelected = _statusFilter == label;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selectedColor: const Color(0xFF0284C7),
      backgroundColor:
          isDark ? const Color(0xFF162A3F) : const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      onSelected: (_) => setState(() => _statusFilter = label),
    );
  }

  Widget _buildTicketCard(
      ComplaintTicket ticket, bool isDark, Color cardBg) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final hasReplies = ticket.adminResponses.isNotEmpty;
    final isResolved = ticket.status == ComplaintStatus.resolved ||
        ticket.status == ComplaintStatus.closed;
    final resolvedTime = ticket.resolvedAt ?? ticket.updatedAt;
    final expirationTime = resolvedTime.add(const Duration(days: 7));
    final now = DateTime.now();
    final canReopen = isResolved && now.isBefore(expirationTime);
    final remainingDays = (expirationTime.difference(now).inDays + 1).clamp(1, 7);

    _replyControllers.putIfAbsent(
        ticket.ticketId, () => TextEditingController());
    final replyController = _replyControllers[ticket.ticketId]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ticket.status.color.withOpacity(isDark ? 0.35 : 0.25),
          width: 1.2,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: ticket.status == ComplaintStatus.open ||
              ticket.status == ComplaintStatus.inProgress,
          onExpansionChanged: (expanded) {
            if (expanded) {
              _fetchTicketDetails(ticket.ticketId);
            }
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          childrenPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ticket.category.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(ticket.category.icon,
                color: ticket.category.color, size: 20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.06),
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
              Expanded(
                child: Text(
                  ticket.subject,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                // Device badge
                Icon(Icons.sensors_rounded,
                    size: 13,
                    color: isDark ? Colors.white54 : Colors.black45),
                const SizedBox(width: 3),
                Text(
                  ticket.deviceId,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
                const SizedBox(width: 8),
                // Category badge (highlights custom issue if manual)
                if (ticket.isCustomCategory) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFF10B981).withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_note,
                            size: 11, color: Color(0xFF10B981)),
                        const SizedBox(width: 3),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            ticket.displayCategory,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    ticket.category.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
                const Spacer(),
                // Status pill
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ticket.status.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          children: [
            // Full description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F1E2E).withOpacity(0.6)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Issue Description:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket.description,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 11,
                          color: isDark ? Colors.white38 : Colors.black38),
                      const SizedBox(width: 4),
                      Text(
                        'Submitted: ${dateFormat.format(ticket.createdAt)}',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                      if (ticket.location != null) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: isDark ? Colors.white38 : Colors.black38),
                        const SizedBox(width: 3),
                        Text(
                          ticket.location!,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Photos & Attachments
            if (ticket.attachmentUrls.isNotEmpty) ...[
              ComplaintAttachmentsWidget(
                attachments: ticket.attachmentUrls,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
            ],

            // Support Responses Timeline
            if (hasReplies) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Engineering & Support Conversation:',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...ticket.adminResponses.map((r) {
                final isUserMsg = r.id.startsWith('USER-');
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUserMsg
                        ? (isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9))
                        : (isDark
                            ? const Color(0xFF0C2A44)
                            : const Color(0xFFE0F2FE)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isUserMsg
                          ? (isDark ? Colors.white12 : Colors.black12)
                          : const Color(0xFF0284C7).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isUserMsg
                                ? Icons.person_rounded
                                : Icons.support_agent_rounded,
                            size: 14,
                            color: isUserMsg
                                ? (isDark ? Colors.white70 : Colors.black54)
                                : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            r.responderName,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: isUserMsg
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : const Color(0xFF0284C7),
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
                      const SizedBox(height: 4),
                      Text(
                        r.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white : Colors.black87,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ] else ...[
              if (!isResolved)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.hourglass_top_rounded,
                          size: 14,
                          color: isDark ? Colors.white54 : Colors.black45),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your complaint has been received and is being reviewed by our team. Responses will appear here.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 10),

            if (isResolved) ...[
              // Reopening option within 7 days of resolution
              if (canReopen)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1E2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.35),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ticket Resolved (${remainingDays > 1 ? "$remainingDays days left" : "Last day"} to reopen)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This ticket was marked as resolved on ${dateFormat.format(resolvedTime)}. If the issue persists or was not solved, you can reopen it within 7 days.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white60 : Colors.black54,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showReopenDialog(ticket),
                          icon: const Icon(Icons.replay_rounded, size: 16),
                          label: const Text(
                            'Reopen Ticket',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEC4899),
                            side: const BorderSide(color: Color(0xFFEC4899), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                // Exceeded 7 days: Ticket is permanently closed
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F1E2E) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_clock_outlined,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black45,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ticket Closed Permanently',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'This ticket was resolved on ${dateFormat.format(resolvedTime)}. The 7-day reopening period has expired. If you need assistance with an issue, please raise a new ticket.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black45,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final newTicket = await RaiseComplaintDialog.show(
                            context,
                            availableDevices: widget.availableDevices,
                          );
                          if (newTicket != null) {
                            _loadUserTickets();
                          }
                        },
                        icon: const Icon(Icons.add_rounded, size: 15),
                        label: const Text(
                          'Raise New Ticket',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else ...[
              // Active ticket reply input bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: replyController,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Add follow-up notes or update for support...',
                        hintStyle: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F1E2E)
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _sendFollowUp(ticket),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.send_rounded, size: 14),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(
              'No complaints found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You have no active complaints matching the filter.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
