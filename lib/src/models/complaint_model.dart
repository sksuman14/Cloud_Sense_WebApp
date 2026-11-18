import 'package:flutter/material.dart';

/// Enum representing the categories of issues reported by users.
/// Directly maps to the backend `issueType` enum in the AWS Support Ticket API.
enum ComplaintCategory {
  rainGaugeIssue,
  connectivityOffline,
  sensorInaccuracy,
  powerBattery,
  hardwareDamage,
  webAppDisplay,
  other,
}

extension ComplaintCategoryExtension on ComplaintCategory {
  String get label {
    switch (this) {
      case ComplaintCategory.rainGaugeIssue:
        return 'Rain Gauge Issue';
      case ComplaintCategory.connectivityOffline:
        return 'Connectivity / Offline';
      case ComplaintCategory.sensorInaccuracy:
        return 'Sensor Inaccuracy';
      case ComplaintCategory.powerBattery:
        return 'Power & Battery';
      case ComplaintCategory.hardwareDamage:
        return 'Physical Damage';
      case ComplaintCategory.webAppDisplay:
        return 'App / Dashboard Issue';
      case ComplaintCategory.other:
        return 'Other (Write Manually)';
    }
  }

  String get description {
    switch (this) {
      case ComplaintCategory.rainGaugeIssue:
        return 'Zero rainfall, clogged funnel, pulse switch failure, calibration';
      case ComplaintCategory.connectivityOffline:
        return 'Device stopped transmitting, packet loss, delays';
      case ComplaintCategory.sensorInaccuracy:
        return 'Erratic readings, temperature/humidity drift, anomalies';
      case ComplaintCategory.powerBattery:
        return 'Battery drain, solar panel failure, charging issues';
      case ComplaintCategory.hardwareDamage:
        return 'Broken mount, casing leakage, cut cables, water damage';
      case ComplaintCategory.webAppDisplay:
        return 'Graphs not loading, wrong timestamps or units';
      case ComplaintCategory.other:
        return 'Describe a custom problem not listed above';
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintCategory.rainGaugeIssue:
        return Icons.water_drop_rounded;
      case ComplaintCategory.connectivityOffline:
        return Icons.wifi_off_rounded;
      case ComplaintCategory.sensorInaccuracy:
        return Icons.speed_rounded;
      case ComplaintCategory.powerBattery:
        return Icons.battery_alert_rounded;
      case ComplaintCategory.hardwareDamage:
        return Icons.build_circle_outlined;
      case ComplaintCategory.webAppDisplay:
        return Icons.devices_other_rounded;
      case ComplaintCategory.other:
        return Icons.edit_note_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ComplaintCategory.rainGaugeIssue:
        return const Color(0xFF0EA5E9);
      case ComplaintCategory.connectivityOffline:
        return const Color(0xFFEF4444);
      case ComplaintCategory.sensorInaccuracy:
        return const Color(0xFF0284C7);
      case ComplaintCategory.powerBattery:
        return const Color(0xFFF59E0B);
      case ComplaintCategory.hardwareDamage:
        return const Color(0xFF8B5CF6);
      case ComplaintCategory.webAppDisplay:
        return const Color(0xFF06B6D4);
      case ComplaintCategory.other:
        return const Color(0xFF10B981);
    }
  }

  /// Maps to backend API `issueType` string
  String get apiValue {
    switch (this) {
      case ComplaintCategory.rainGaugeIssue:
        return 'RAIN_GAUGE_ISSUE';
      case ComplaintCategory.connectivityOffline:
        return 'DEVICE_OFFLINE';
      case ComplaintCategory.sensorInaccuracy:
        return 'INACCURATE_READINGS';
      case ComplaintCategory.powerBattery:
        return 'BATTERY_SOLAR_ISSUE';
      case ComplaintCategory.hardwareDamage:
        return 'PHYSICAL_DAMAGE';
      case ComplaintCategory.webAppDisplay:
      case ComplaintCategory.other:
        return 'OTHER';
    }
  }

  /// Parses from backend API string
  static ComplaintCategory fromApi(String? value) {
    switch (value?.toUpperCase()) {
      case 'RAIN_GAUGE_ISSUE':
        return ComplaintCategory.rainGaugeIssue;
      case 'DEVICE_OFFLINE':
        return ComplaintCategory.connectivityOffline;
      case 'INACCURATE_READINGS':
        return ComplaintCategory.sensorInaccuracy;
      case 'BATTERY_SOLAR_ISSUE':
        return ComplaintCategory.powerBattery;
      case 'PHYSICAL_DAMAGE':
        return ComplaintCategory.hardwareDamage;
      case 'OTHER':
      default:
        return ComplaintCategory.other;
    }
  }
}

enum ComplaintPriority {
  low,
  medium,
  high,
  critical,
}

extension ComplaintPriorityExtension on ComplaintPriority {
  String get label {
    switch (this) {
      case ComplaintPriority.low:
        return 'Low';
      case ComplaintPriority.medium:
        return 'Medium';
      case ComplaintPriority.high:
        return 'High';
      case ComplaintPriority.critical:
        return 'Critical (Urgent)';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintPriority.low:
        return const Color(0xFF64748B);
      case ComplaintPriority.medium:
        return const Color(0xFF0284C7);
      case ComplaintPriority.high:
        return const Color(0xFFF97316);
      case ComplaintPriority.critical:
        return const Color(0xFFEF4444);
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintPriority.low:
        return Icons.arrow_downward_rounded;
      case ComplaintPriority.medium:
        return Icons.remove_rounded;
      case ComplaintPriority.high:
        return Icons.arrow_upward_rounded;
      case ComplaintPriority.critical:
        return Icons.priority_high_rounded;
    }
  }
}

/// Matches the backend status values:
/// OPEN, IN_PROGRESS, WAITING_FOR_USER, RESOLVED, CLOSED, REOPENED
enum ComplaintStatus {
  open,
  inProgress,
  waitingForUser,
  resolved,
  closed,
  reopened,
}

extension ComplaintStatusExtension on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.open:
        return 'Open';
      case ComplaintStatus.inProgress:
        return 'In Progress';
      case ComplaintStatus.waitingForUser:
        return 'Waiting for User';
      case ComplaintStatus.resolved:
        return 'Resolved';
      case ComplaintStatus.closed:
        return 'Closed';
      case ComplaintStatus.reopened:
        return 'Reopened';
    }
  }

  String get apiValue {
    switch (this) {
      case ComplaintStatus.open:
        return 'OPEN';
      case ComplaintStatus.inProgress:
        return 'IN_PROGRESS';
      case ComplaintStatus.waitingForUser:
        return 'WAITING_FOR_USER';
      case ComplaintStatus.resolved:
        return 'RESOLVED';
      case ComplaintStatus.closed:
        return 'CLOSED';
      case ComplaintStatus.reopened:
        return 'REOPENED';
    }
  }

  Color get color {
    switch (this) {
      case ComplaintStatus.open:
        return const Color(0xFF0284C7);
      case ComplaintStatus.inProgress:
        return const Color(0xFF8B5CF6);
      case ComplaintStatus.waitingForUser:
        return const Color(0xFFF59E0B);
      case ComplaintStatus.resolved:
        return const Color(0xFF10B981);
      case ComplaintStatus.closed:
        return const Color(0xFF64748B);
      case ComplaintStatus.reopened:
        return const Color(0xFFEC4899);
    }
  }

  IconData get icon {
    switch (this) {
      case ComplaintStatus.open:
        return Icons.fiber_new_rounded;
      case ComplaintStatus.inProgress:
        return Icons.engineering_rounded;
      case ComplaintStatus.waitingForUser:
        return Icons.hourglass_top_rounded;
      case ComplaintStatus.resolved:
        return Icons.check_circle_rounded;
      case ComplaintStatus.closed:
        return Icons.lock_outline_rounded;
      case ComplaintStatus.reopened:
        return Icons.replay_rounded;
    }
  }

  static ComplaintStatus fromApi(String? value) {
    switch (value?.toUpperCase()) {
      case 'OPEN':
        return ComplaintStatus.open;
      case 'IN_PROGRESS':
        return ComplaintStatus.inProgress;
      case 'WAITING_FOR_USER':
        return ComplaintStatus.waitingForUser;
      case 'RESOLVED':
        return ComplaintStatus.resolved;
      case 'CLOSED':
        return ComplaintStatus.closed;
      case 'REOPENED':
        return ComplaintStatus.reopened;
      default:
        return ComplaintStatus.open;
    }
  }
}

/// Attachment model for file uploads/downloads
class TicketAttachment {
  static String? s3BucketBaseUrl = 'https://ws-support-tickets.s3.amazonaws.com';

  final String attachmentId;
  final String filename;
  final String contentType;
  final String? url;
  final String? downloadUrl;
  final String? key;
  final int? size;

  TicketAttachment({
    required this.attachmentId,
    required this.filename,
    required this.contentType,
    this.url,
    this.downloadUrl,
    this.key,
    this.size,
  });

  String get displayUrl {
    if (downloadUrl != null && downloadUrl!.trim().isNotEmpty) return downloadUrl!.trim();
    if (url != null && url!.trim().isNotEmpty) return url!.trim();
    if (key != null && key!.trim().isNotEmpty) {
      final k = key!.trim();
      if (k.startsWith('http://') || k.startsWith('https://')) return k;
      if (s3BucketBaseUrl != null && s3BucketBaseUrl!.isNotEmpty) {
        return '$s3BucketBaseUrl/$k';
      }
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'attachmentId': attachmentId,
        'filename': filename,
        'contentType': contentType,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        if (url != null) 'url': url,
        if (key != null) 'key': key,
        if (size != null) 'size': size,
      };

  Map<String, dynamic> toMessagePayload() => {
        'attachmentId': attachmentId,
        'key': key ?? '',
        'filename': filename,
        'contentType': contentType,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        if (displayUrl.isNotEmpty) 'url': displayUrl,
      };

  factory TicketAttachment.fromJson(Map<String, dynamic> json) {
    final rawDownloadUrl = json['downloadUrl'] ??
        json['download_url'] ??
        json['presignedUrl'] ??
        json['signedUrl'];
    final rawUrl = json['url'] ?? json['s3Url'] ?? json['imageUrl'];

    String? resolvedDownload = (rawDownloadUrl != null && rawDownloadUrl.toString().trim().isNotEmpty)
        ? rawDownloadUrl.toString().trim()
        : null;

    String? resolvedUrl = resolvedDownload ??
        ((rawUrl != null && rawUrl.toString().trim().isNotEmpty)
            ? rawUrl.toString().trim()
            : null);

    if ((resolvedUrl == null || resolvedUrl.isEmpty) && json['key'] != null) {
      final key = json['key'].toString();
      if (key.startsWith('http://') || key.startsWith('https://')) {
        resolvedUrl = key;
      } else if (s3BucketBaseUrl != null && s3BucketBaseUrl!.isNotEmpty) {
        resolvedUrl = '$s3BucketBaseUrl/$key';
      }
    }

    return TicketAttachment(
      attachmentId: json['attachmentId'] ?? '',
      filename: json['filename'] ?? 'file',
      contentType: json['contentType'] ?? 'application/octet-stream',
      url: resolvedUrl,
      downloadUrl: resolvedDownload,
      key: json['key'],
      size: json['size'] ?? json['maxBytes'],
    );
  }
}

/// Represents an event in the ticket's history (message, creation, status change)
class TicketEvent {
  final String ticketId;
  final String eventId;
  final String eventType; // TICKET_CREATED, MESSAGE, STATUS_CHANGED
  final String senderId;
  final String senderRole; // USER, ADMIN, SYSTEM
  final String? deviceId;
  final String? message;
  final DateTime timestamp;
  final List<TicketAttachment> attachments;
  final String? oldStatus;
  final String? newStatus;
  final String? note;

  TicketEvent({
    required this.ticketId,
    required this.eventId,
    required this.eventType,
    required this.senderId,
    required this.senderRole,
    this.deviceId,
    this.message,
    required this.timestamp,
    this.attachments = const [],
    this.oldStatus,
    this.newStatus,
    this.note,
  });

  bool get isUser => senderRole.toUpperCase() == 'USER';
  bool get isAdmin => senderRole.toUpperCase() == 'ADMIN';
  bool get isSystem => senderRole.toUpperCase() == 'SYSTEM';
  bool get isStatusChange => eventType == 'STATUS_CHANGED';

  Map<String, dynamic> toJson() => {
        'ticketId': ticketId,
        'eventId': eventId,
        'eventType': eventType,
        'senderId': senderId,
        'senderRole': senderRole,
        'deviceId': deviceId,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'oldStatus': oldStatus,
        'newStatus': newStatus,
        'note': note,
      };

  factory TicketEvent.fromJson(Map<String, dynamic> json) => TicketEvent(
        ticketId: json['ticketId'] ?? '',
        eventId: json['eventId'] ?? '',
        eventType: json['eventType'] ?? 'MESSAGE',
        senderId: json['senderId'] ?? '',
        senderRole: json['senderRole'] ?? 'USER',
        deviceId: json['deviceId'],
        message: json['message'],
        timestamp: json['timestamp'] != null
            ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
            : DateTime.now(),
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((a) => TicketAttachment.fromJson(a as Map<String, dynamic>))
            .toList(),
        oldStatus: json['oldStatus'],
        newStatus: json['newStatus'],
        note: json['note'],
      );
}

/// Admin response compatibility model (mapped from TicketEvent or used in UI)
class AdminResponse {
  final String id;
  final String responderName;
  final String responderEmail;
  final String message;
  final DateTime timestamp;
  final bool isInternal;
  final List<TicketAttachment> attachments;

  AdminResponse({
    required this.id,
    required this.responderName,
    required this.responderEmail,
    required this.message,
    required this.timestamp,
    this.isInternal = false,
    this.attachments = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'responderName': responderName,
        'responderEmail': responderEmail,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'isInternal': isInternal,
        'attachments': attachments.map((a) => a.toJson()).toList(),
      };

  factory AdminResponse.fromJson(Map<String, dynamic> json) => AdminResponse(
        id: json['id'] ?? '',
        responderName: json['responderName'] ?? 'Admin',
        responderEmail: json['responderEmail'] ?? '',
        message: json['message'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
        isInternal: json['isInternal'] ?? false,
        attachments: (json['attachments'] as List<dynamic>? ?? [])
            .map((a) => TicketAttachment.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
}

/// Support Ticket Model representing a complaint or inquiry
class ComplaintTicket {
  final String ticketId;
  final String userEmail;
  final String userName;
  final String deviceId;
  final String? deviceTopic;
  final String? location;
  final ComplaintCategory category;
  final bool isCustomCategory;
  final String? customCategoryText;
  final ComplaintPriority priority;
  final bool urgent;
  final String subject;
  final String description;
  final List<String> attachmentUrls;
  final Map<String, dynamic> telemetrySnapshot;
  ComplaintStatus status;
  String? assignedTo;
  List<AdminResponse> adminResponses;
  List<TicketEvent> events;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? resolvedAt;
  DateTime? lastMessageAt;

  ComplaintTicket({
    required this.ticketId,
    required this.userEmail,
    required this.userName,
    required this.deviceId,
    this.deviceTopic,
    this.location,
    required this.category,
    this.isCustomCategory = false,
    this.customCategoryText,
    required this.priority,
    this.urgent = false,
    required this.subject,
    required this.description,
    this.attachmentUrls = const [],
    this.telemetrySnapshot = const {},
    this.status = ComplaintStatus.open,
    this.assignedTo,
    this.adminResponses = const [],
    this.events = const [],
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.lastMessageAt,
  });

  /// Display category name (returns custom manual category if 'other' was selected)
  String get displayCategory {
    if (category == ComplaintCategory.other &&
        customCategoryText != null &&
        customCategoryText!.trim().isNotEmpty) {
      return customCategoryText!.trim();
    }
    return category.label;
  }

  Map<String, dynamic> toJson() => {
        'ticketId': ticketId,
        'userEmail': userEmail,
        'userName': userName,
        'deviceId': deviceId,
        'deviceTopic': deviceTopic,
        'location': location,
        'category': category.name,
        'isCustomCategory': isCustomCategory,
        'customCategoryText': customCategoryText,
        'priority': priority.name,
        'urgent': urgent,
        'subject': subject,
        'description': description,
        'attachmentUrls': attachmentUrls,
        'telemetrySnapshot': telemetrySnapshot,
        'status': status.apiValue,
        'assignedTo': assignedTo,
        'adminResponses': adminResponses.map((r) => r.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'lastMessageAt': lastMessageAt?.toIso8601String(),
      };

  factory ComplaintTicket.fromJson(Map<String, dynamic> json) {
    // Check both backend PascalCase keys (TicketId, DeviceId, etc.) and camelCase
    final rawTicketId = json['TicketId'] ?? json['ticketId'] ?? '';
    final rawEmail = json['Email'] ?? json['userEmail'] ?? '';
    final rawDeviceId = json['DeviceId'] ?? json['deviceId'] ?? '';
    final rawSubject = json['Subject'] ?? json['subject'] ?? '';
    final rawIssueType = json['IssueType'] ?? json['issueType'];
    final rawCustomIssue = json['CustomIssue'] ?? json['customCategoryText'];
    final rawUrgent = json['Urgent'] ?? json['urgent'] ?? false;
    final rawStatus = json['Status'] ?? json['status'];
    final rawCreatedAt = json['CreatedAt'] ?? json['createdAt'];
    final rawUpdatedAt = json['UpdatedAt'] ?? json['updatedAt'];
    final rawLastMessageAt = json['LastMessageAt'] ?? json['lastMessageAt'];

    final category = ComplaintCategoryExtension.fromApi(rawIssueType);
    final status = ComplaintStatusExtension.fromApi(rawStatus);
    final urgent = rawUrgent is bool ? rawUrgent : (rawUrgent.toString().toLowerCase() == 'true');
    final priority = urgent ? ComplaintPriority.critical : ComplaintPriority.medium;

    final created = rawCreatedAt != null
        ? DateTime.tryParse(rawCreatedAt.toString()) ?? DateTime.now()
        : DateTime.now();
    final updated = rawUpdatedAt != null
        ? DateTime.tryParse(rawUpdatedAt.toString()) ?? created
        : created;
    final lastMsg = rawLastMessageAt != null
        ? DateTime.tryParse(rawLastMessageAt.toString())
        : null;

    // Parse events if present
    final List<TicketEvent> parsedEvents = (json['events'] as List<dynamic>? ?? [])
        .map((e) => TicketEvent.fromJson(e as Map<String, dynamic>))
        .toList();

    // Map events to admin responses (only actual chat messages, excluding status changes)
    final List<AdminResponse> mappedResponses = parsedEvents
        .where((e) =>
            e.eventType == 'MESSAGE' &&
            e.message != null &&
            e.message!.trim().isNotEmpty &&
            !e.isStatusChange)
        .map((e) => AdminResponse(
              id: e.eventId,
              responderName: e.isAdmin
                  ? 'Admin Support'
                  : (e.isUser ? (json['userName'] ?? 'User') : 'System'),
              responderEmail: e.isAdmin ? 'admin@cloudsense.com' : rawEmail,
              message: e.message ?? '',
              timestamp: e.timestamp,
              isInternal: false,
              attachments: e.attachments,
            ))
        .toList();

    // Description fallback from first TICKET_CREATED event if empty
    String desc = json['description'] ?? '';
    if (desc.isEmpty && parsedEvents.isNotEmpty) {
      final first = parsedEvents.firstWhere(
        (e) => e.eventType == 'TICKET_CREATED',
        orElse: () => parsedEvents.first,
      );
      desc = first.message ?? '';
    }

    // Attachment URLs extracted from all sources (events, attachments, attachmentUrls)
    final Set<String> allAttachments = {};
    if (json['attachmentUrls'] is List) {
      for (final u in json['attachmentUrls']) {
        if (u != null && u.toString().isNotEmpty) {
          allAttachments.add(u.toString());
        }
      }
    }
    if (json['attachments'] is List) {
      for (final a in json['attachments']) {
        if (a is String && a.isNotEmpty) {
          allAttachments.add(a);
        } else if (a is Map) {
          final u = a['downloadUrl'] ?? a['download_url'] ?? a['url'] ?? a['s3Url'] ?? a['imageUrl'];
          if (u != null && u.toString().isNotEmpty) {
            allAttachments.add(u.toString());
          } else if (a['key'] != null) {
            final k = a['key'].toString();
            if (k.startsWith('http://') || k.startsWith('https://')) {
              allAttachments.add(k);
            } else if (TicketAttachment.s3BucketBaseUrl != null &&
                TicketAttachment.s3BucketBaseUrl!.isNotEmpty) {
              allAttachments.add('${TicketAttachment.s3BucketBaseUrl}/$k');
            }
          }
        }
      }
    }
    for (final ev in parsedEvents) {
      for (final att in ev.attachments) {
        final u = att.displayUrl;
        if (u.isNotEmpty) {
          allAttachments.add(u);
        }
      }
    }

    return ComplaintTicket(
      ticketId: rawTicketId,
      userEmail: rawEmail,
      userName: json['userName'] ?? rawEmail.split('@').first,
      deviceId: rawDeviceId,
      deviceTopic: json['deviceTopic'],
      location: json['location'],
      category: category,
      isCustomCategory: category == ComplaintCategory.other,
      customCategoryText: rawCustomIssue,
      priority: priority,
      urgent: urgent,
      subject: rawSubject,
      description: desc,
      attachmentUrls: allAttachments.toList(),
      telemetrySnapshot:
          Map<String, dynamic>.from(json['telemetrySnapshot'] ?? {}),
      status: status,
      assignedTo: json['assignedTo'],
      adminResponses: mappedResponses.isNotEmpty
          ? mappedResponses
          : (json['adminResponses'] as List<dynamic>? ?? [])
              .map((r) => AdminResponse.fromJson(r as Map<String, dynamic>))
              .toList(),
      events: parsedEvents,
      createdAt: created,
      updatedAt: updated,
      resolvedAt: status == ComplaintStatus.resolved || status == ComplaintStatus.closed
          ? updated
          : null,
      lastMessageAt: lastMsg,
    );
  }
}
