import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_sense_webapp/src/models/complaint_model.dart';
import 'package:cloud_sense_webapp/src/services/complaint_service.dart';

/// Singleton service to manage read/unread notification counts for complaint tickets.
/// Tracks when Admin last viewed each ticket (to count unread user messages),
/// and when User last viewed each ticket (to count unread admin messages).
class ComplaintNotificationService extends ChangeNotifier {
  static final ComplaintNotificationService _instance =
      ComplaintNotificationService._internal();
  factory ComplaintNotificationService() => _instance;
  ComplaintNotificationService._internal();

  final Map<String, DateTime> _lastSeenMap = {};
  bool _isInitialized = false;

  int _cachedAdminUnreadTotal = 0;
  int _cachedUserUnreadTotal = 0;

  int get cachedAdminUnreadTotal => _cachedAdminUnreadTotal;
  int get cachedUserUnreadTotal => _cachedUserUnreadTotal;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) =>
          k.startsWith('complaint_seen_admin_') ||
          k.startsWith('complaint_seen_user_'));
      for (final k in keys) {
        final val = prefs.getString(k);
        if (val != null) {
          final dt = DateTime.tryParse(val);
          if (dt != null) {
            _lastSeenMap[k] = dt;
          }
        }
      }
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[ComplaintNotification] init error: $e');
    }
  }

  /// Mark ticket as seen by Admin
  Future<void> markAsSeenByAdmin(String ticketId) async {
    await init();
    final key = 'complaint_seen_admin_$ticketId';
    final now = DateTime.now();
    _lastSeenMap[key] = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, now.toIso8601String());
    } catch (_) {}
    notifyListeners();
  }

  /// Mark ticket as seen by User
  Future<void> markAsSeenByUser(String ticketId) async {
    await init();
    final key = 'complaint_seen_user_$ticketId';
    final now = DateTime.now();
    _lastSeenMap[key] = now;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, now.toIso8601String());
    } catch (_) {}
    notifyListeners();
  }

  /// Get unread responses count from USER for Admin
  /// (shows 1, 2, ... if user has replied, 0 if admin has seen all)
  int getUnreadCountForAdmin(ComplaintTicket ticket) {
    final key = 'complaint_seen_admin_${ticket.ticketId}';
    final lastSeen = _lastSeenMap[key];

    // If ticket has events loaded, count user messages after lastSeen
    if (ticket.events.isNotEmpty) {
      return ticket.events.where((e) {
        if (!e.isUser) return false;
        if (e.isStatusChange) return false;
        if (lastSeen == null) return true;
        return e.timestamp.isAfter(lastSeen);
      }).length;
    }

    // Fallback if events not yet loaded:
    if (lastSeen == null) {
      // Has not been seen yet by admin -> 1 initial message
      return 1;
    }
    if (ticket.updatedAt.isAfter(lastSeen.add(const Duration(seconds: 1)))) {
      return 1;
    }
    return 0;
  }

  /// Get unread responses count from ADMIN for User
  /// (shows 1, 2, ... if admin has replied, 0 if user has seen all)
  int getUnreadCountForUser(ComplaintTicket ticket) {
    final key = 'complaint_seen_user_${ticket.ticketId}';
    final lastSeen = _lastSeenMap[key];

    // If ticket has events loaded:
    if (ticket.events.isNotEmpty) {
      return ticket.events.where((e) {
        if (!e.isAdmin) return false;
        if (e.isStatusChange) return false;
        if (lastSeen == null) return true;
        return e.timestamp.isAfter(lastSeen);
      }).length;
    }

    // Check adminResponses if events empty
    if (ticket.adminResponses.isNotEmpty) {
      return ticket.adminResponses.where((r) {
        if (lastSeen == null) return true;
        return r.timestamp.isAfter(lastSeen);
      }).length;
    }

    // If no admin responses exist, user has 0 unread
    return 0;
  }

  int getTotalUnreadForAdmin(List<ComplaintTicket> tickets) {
    int total = 0;
    for (final t in tickets) {
      total += getUnreadCountForAdmin(t);
    }
    _cachedAdminUnreadTotal = total;
    return total;
  }

  int getTotalUnreadForUser(List<ComplaintTicket> tickets) {
    int total = 0;
    for (final t in tickets) {
      total += getUnreadCountForUser(t);
    }
    _cachedUserUnreadTotal = total;
    return total;
  }

  /// Refreshes user unread count by fetching user's tickets in background
  Future<int> refreshUserUnread(String userEmail) async {
    await init();
    try {
      final complaintService = ComplaintService();
      final tickets = await complaintService.getComplaintsForUser(userEmail);
      final detailedTickets = await Future.wait(tickets.map((t) async {
        try {
          final det = await complaintService.getComplaintById(t.ticketId);
          return det ?? t;
        } catch (_) {
          return t;
        }
      }));
      final total = getTotalUnreadForUser(detailedTickets);
      notifyListeners();
      return total;
    } catch (_) {
      return _cachedUserUnreadTotal;
    }
  }

  /// Refreshes admin unread count by fetching all tickets in background
  Future<int> refreshAdminUnread() async {
    await init();
    try {
      final complaintService = ComplaintService();
      final tickets = await complaintService.getAllComplaints();
      final detailedTickets = await Future.wait(tickets.map((t) async {
        try {
          final det = await complaintService.getComplaintById(t.ticketId);
          return det ?? t;
        } catch (_) {
          return t;
        }
      }));
      final total = getTotalUnreadForAdmin(detailedTickets);
      notifyListeners();
      return total;
    } catch (_) {
      return _cachedAdminUnreadTotal;
    }
  }
}
