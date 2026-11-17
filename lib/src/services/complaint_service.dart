import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:cloud_sense_webapp/src/models/complaint_model.dart';
import 'package:cloud_sense_webapp/src/utils/Shared_Add_Device.dart';

/// File payload for uploading ticket attachments
class AttachmentUploadPayload {
  final String filename;
  final String contentType;
  final Uint8List bytes;

  AttachmentUploadPayload({
    required this.filename,
    required this.contentType,
    required this.bytes,
  });

  factory AttachmentUploadPayload.fromPlatformFile(PlatformFile file) {
    final bytes = file.bytes ?? Uint8List(0);
    final ext = (file.extension ?? '').toLowerCase();
    String mime = 'application/octet-stream';
    if (ext == 'jpg' || ext == 'jpeg') {
      mime = 'image/jpeg';
    } else if (ext == 'png') {
      mime = 'image/png';
    } else if (ext == 'webp') {
      mime = 'image/webp';
    } else if (ext == 'gif') {
      mime = 'image/gif';
    } else if (ext == 'pdf') {
      mime = 'application/pdf';
    } else if (ext == 'txt') {
      mime = 'text/plain';
    } else if (ext == 'csv') {
      mime = 'text/csv';
    }

    return AttachmentUploadPayload(
      filename: file.name,
      contentType: mime,
      bytes: bytes,
    );
  }
}

/// Service managing support tickets via the AWS Support Ticket API Gateway.
///
/// Production Base URL: https://hd20svxcbh.execute-api.us-east-1.amazonaws.com
/// Uses $default stage (never append stage name or Lambda name).
class ComplaintService {
  static final ComplaintService _instance = ComplaintService._internal();
  factory ComplaintService() => _instance;
  ComplaintService._internal();

  /// Holds the last raw HTTP call and response for live diagnostics
  static String lastDebugInfo = 'No API call made yet';

  /// Production AWS API Gateway Base URL
  static const String apiBaseUrl =
      'https://hd20svxcbh.execute-api.us-east-1.amazonaws.com';

  /// Helper to get the Cognito ID Token from active Amplify Auth session
  Future<String?> getIdToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final tokensResult = session.userPoolTokensResult;
        return tokensResult.value.idToken.raw;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching Cognito ID token: $e');
    }
    return null;
  }

  /// Helper to get the Cognito Access Token from active Amplify Auth session
  Future<String?> getAccessToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        return session.userPoolTokensResult.value.accessToken.raw;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching Cognito Access token: $e');
    }
    return null;
  }

  /// Check whether the current user is an Admin
  /// Checks Cognito ID Token group claims ('Admin') and super admin fallback
  Future<bool> checkIsAdmin({String? email}) async {
    try {
      final diag = await getCognitoDiagnostics();
      if (diag['isAdminInCognito'] == true) return true;
    } catch (e) {
      if (kDebugMode) debugPrint('Error inspecting Cognito groups: $e');
    }
    if (email != null && DeviceUtils.isSuperAdmin(email)) {
      return true;
    }
    return false;
  }

  /// Inspects the current Cognito ID token to return debug metadata
  Future<Map<String, dynamic>> getCognitoDiagnostics() async {
    try {
      final token = await getIdToken();
      if (token == null || token.isEmpty) {
        return {
          'hasToken': false,
          'email': null,
          'groups': <String>[],
          'isAdminInCognito': false,
          'sub': null,
        };
      }

      final parts = token.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final payload = utf8.decode(base64Url.decode(normalized));
        final data = jsonDecode(payload) as Map<String, dynamic>;

        List<String> groupsList = [];
        final rawGroups = data['cognito:groups'];
        if (rawGroups is List) {
          groupsList = rawGroups.map((g) => g.toString()).toList();
        } else if (rawGroups is String) {
          groupsList = rawGroups.split(',').map((g) => g.trim()).toList();
        }

        final email = data['email']?.toString();
        final isCognitoAdmin = groupsList.contains('Admin');

        return {
          'hasToken': true,
          'email': email,
          'groups': groupsList,
          'isAdminInCognito': isCognitoAdmin,
          'sub': data['sub']?.toString(),
          'rawClaims': data,
        };
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error getting Cognito diagnostics: $e');
    }

    return {
      'hasToken': false,
      'email': null,
      'groups': <String>[],
      'isAdminInCognito': false,
      'sub': null,
    };
  }

  /// Construct headers with Cognito Bearer Token
  Future<Map<String, String>> _getHeaders({bool useAccessToken = false}) async {
    final token = useAccessToken ? await getAccessToken() : await getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please sign in again.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _extractErrorMessage(http.Response resp) {
    try {
      final data = jsonDecode(resp.body);
      if (data is Map && data.containsKey('error')) {
        return data['error'].toString();
      }
      if (data is Map && data.containsKey('message')) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'HTTP ${resp.statusCode}: ${resp.body}';
  }

  // ─────────────────────────────────────────────────────────────
  // S3 PRESIGNED ATTACHMENT UPLOAD FLOW
  // ─────────────────────────────────────────────────────────────

  /// Requests a presigned S3 PUT URL and uploads raw bytes directly to S3.
  /// Returns the attachment metadata map to include in POST /tickets/{id}/messages.
  Future<Map<String, dynamic>> uploadAttachment({
    required String ticketId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final headers = await _getHeaders();
    final presignUri =
        Uri.parse('$apiBaseUrl/tickets/$ticketId/attachments/presign');

    final presignResp = await http.post(
      presignUri,
      headers: headers,
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'size': bytes.length,
      }),
    );

    if (presignResp.statusCode != 200) {
      final err = _extractErrorMessage(presignResp);
      throw Exception('Failed to get upload URL: $err');
    }

    final presignData = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final uploadUrl = presignData['uploadUrl'] as String;
    final attachmentMeta =
        Map<String, dynamic>.from(presignData['attachment'] ?? {});

    // Upload raw bytes to S3 using PUT.
    // NOTE: S3 bucket policy requires AES256 server-side encryption.
    // NOTE: Presigned URL is self-authenticated; do NOT include Bearer token.
    final s3Resp = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Type': contentType,
        'x-amz-server-side-encryption': 'AES256',
      },
      body: bytes,
    );

    if (s3Resp.statusCode != 200 && s3Resp.statusCode != 204) {
      throw Exception(
          'Failed to upload file to S3 (Status ${s3Resp.statusCode})');
    }

    return attachmentMeta;
  }

  // ─────────────────────────────────────────────────────────────
  // TICKET CRUD & MESSAGING
  // ─────────────────────────────────────────────────────────────

  /// Create a new ticket (POST /tickets).
  /// If [files] are provided, uploads them via presigned S3 URLs and attaches them
  /// via an initial follow-up message.
  Future<ComplaintTicket> submitComplaint({
    required String userEmail,
    required String userName,
    required String deviceId,
    String? deviceTopic,
    String? location,
    required ComplaintCategory category,
    bool isCustomCategory = false,
    String? customCategoryText,
    required ComplaintPriority priority,
    required String subject,
    required String description,
    List<AttachmentUploadPayload> files = const [],
    List<String> attachmentUrls = const [],
    Map<String, dynamic> telemetrySnapshot = const {},
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$apiBaseUrl/tickets');

    final bool urgent = priority == ComplaintPriority.critical;
    final String issueType = category.apiValue;
    final String customIssue =
        (category == ComplaintCategory.other || isCustomCategory)
            ? (customCategoryText ?? '').trim()
            : '';

    final body = jsonEncode({
      'deviceId': deviceId.trim(),
      'subject': subject.trim(),
      'issueType': issueType,
      'customIssue': customIssue,
      'description': description.trim(),
      'urgent': urgent,
    });

    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 201) {
      final err = _extractErrorMessage(resp);
      throw Exception('Failed to create ticket: $err');
    }

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final ticketId = data['ticketId'] as String;

    // If attachments were selected, upload each to S3 and post as a message
    if (files.isNotEmpty) {
      try {
        final List<Map<String, dynamic>> uploaded = [];
        for (final file in files) {
          final meta = await uploadAttachment(
            ticketId: ticketId,
            filename: file.filename,
            contentType: file.contentType,
            bytes: file.bytes,
          );
          uploaded.add({
            'attachmentId': meta['attachmentId'],
            'key': meta['key'],
            'filename': meta['filename'],
            'contentType': meta['contentType'],
          });
        }

        if (uploaded.isNotEmpty) {
          await addMessage(
            ticketId: ticketId,
            message: 'Attached files from ticket creation',
            attachments: uploaded,
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Warning: Attachment upload failed: $e');
      }
    }

    // Fetch and return the fully populated ticket
    final createdTicket = await getComplaintById(ticketId);
    if (createdTicket != null) return createdTicket;

    return ComplaintTicket(
      ticketId: ticketId,
      userEmail: userEmail,
      userName: userName,
      deviceId: deviceId,
      deviceTopic: deviceTopic,
      location: location,
      category: category,
      isCustomCategory: isCustomCategory,
      customCategoryText: customCategoryText,
      priority: priority,
      urgent: urgent,
      subject: subject,
      description: description,
      status: ComplaintStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Fetch a single page of tickets (GET /tickets)
  /// Base endpoint: https://hd20svxcbh.execute-api.us-east-1.amazonaws.com/tickets
  Future<Map<String, dynamic>> fetchTicketsPage({
    String? status,
    String? nextToken,
    int? limit,
    bool useAccessToken = false,
  }) async {
    final headers = await _getHeaders(useAccessToken: useAccessToken);
    final queryParams = <String, String>{};
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }
    if (nextToken != null && nextToken.isNotEmpty) {
      queryParams['nextToken'] = nextToken;
    }
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      queryParams['status'] = status;
    }

    final baseUri = Uri.parse('$apiBaseUrl/tickets');
    final uri = queryParams.isNotEmpty
        ? baseUri.replace(queryParameters: queryParams)
        : baseUri;

    final tokenType = useAccessToken ? 'ACCESS_TOKEN' : 'ID_TOKEN';
    final resp = await http.get(uri, headers: headers);

    lastDebugInfo +=
        '\n\n[$tokenType] GET $uri\nHTTP ${resp.statusCode} => ${resp.body}';
    debugPrint(
        '[ComplaintService] [$tokenType] GET $uri => HTTP ${resp.statusCode}: ${resp.body}');

    if (resp.statusCode != 200) {
      final err = _extractErrorMessage(resp);
      debugPrint('[ComplaintService] GET $uri FAILED with status ${resp.statusCode}: $err');
      throw Exception('API ${resp.statusCode}: $err');
    }

    final decoded = jsonDecode(resp.body);
    List<dynamic> rawList = [];
    String? next;

    if (decoded is List) {
      rawList = decoded;
    } else if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final dynamic list = map['tickets'] ??
          map['Tickets'] ??
          map['items'] ??
          map['Items'] ??
          map['data'];
      if (list is List) {
        rawList = list;
      }
      next = (map['nextToken'] ?? map['NextToken'])?.toString();
    }

    final List<ComplaintTicket> tickets = [];
    for (final raw in rawList) {
      try {
        if (raw is Map) {
          tickets.add(ComplaintTicket.fromJson(Map<String, dynamic>.from(raw)));
        }
      } catch (e, st) {
        debugPrint(
            '[ComplaintService] Error parsing ticket item: $e\nData: $raw\n$st');
      }
    }

    debugPrint(
        '[ComplaintService] Successfully parsed ${tickets.length}/${rawList.length} tickets from $uri');

    return {
      'tickets': tickets,
      'nextToken': next,
      'count': tickets.length,
      'rawBody': resp.body,
    };
  }

  /// Fetch all complaints.
  /// Handles DynamoDB Scan pagination by following `nextToken` until exhausted.
  /// 1. Calls GET /tickets directly (which returns all tickets across users for Admin,
  ///    or the caller's own tickets for normal user).
  /// 2. If the user is an Admin, also queries additional statuses to ensure
  ///    no tickets are missed (since omitted status defaults to OPEN for Admin).
  Future<List<ComplaintTicket>> getAllComplaints({
    String? status,
    int maxPages = 20,
  }) async {
    // If a specific status is requested (e.g. 'OPEN', 'IN_PROGRESS'), fetch only that
    if (status != null && status.isNotEmpty && status.toUpperCase() != 'ALL') {
      return _fetchAccumulatedTickets(status: status, maxPages: maxPages);
    }

    final Map<String, ComplaintTicket> deduped = {};
    String? primaryError;
    lastDebugInfo = '--- Fetching Tickets ---';

    // Step 1: Call GET /tickets directly with NO status parameter
    try {
      final baseList =
          await _fetchAccumulatedTickets(status: null, maxPages: maxPages);
      for (final t in baseList) {
        deduped[t.ticketId] = t;
      }
    } catch (e) {
      primaryError = e.toString();
      debugPrint('[ComplaintService] Error calling GET /tickets: $e');
    }

    // Step 2: Also test each status (both UPPERCASE and lowercase) to discover what DynamoDB has
    final statusesToTry = [
      'OPEN',
      'open',
      'IN_PROGRESS',
      'in_progress',
      'WAITING_FOR_USER',
      'waiting_for_user',
      'RESOLVED',
      'resolved',
      'CLOSED',
      'closed',
      'REOPENED',
      'reopened',
    ];

    for (final s in statusesToTry) {
      try {
        final list = await _fetchAccumulatedTickets(status: s, maxPages: 2);
        for (final t in list) {
          deduped[t.ticketId] = t;
        }
      } catch (err) {
        debugPrint('[ComplaintService] Status query ($s) error: $err');
      }
    }

    // Step 3: If still 0 tickets with ID token, try with Access Token
    if (deduped.isEmpty) {
      try {
        final accessList = await _fetchAccumulatedTickets(
          status: null,
          maxPages: 5,
          useAccessToken: true,
        );
        for (final t in accessList) {
          deduped[t.ticketId] = t;
        }
      } catch (err) {
        debugPrint('[ComplaintService] Access token attempt error: $err');
      }
    }

    // If both failed and we got nothing, throw the primary error so the UI can display it
    if (deduped.isEmpty && primaryError != null) {
      throw Exception(primaryError);
    }

    final all = deduped.values.toList();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    debugPrint('[ComplaintService] Total unique tickets collected: ${all.length}');
    for (final t in all) {
      debugPrint('  → [${t.ticketId}] ${t.status.apiValue} | ${t.userEmail} | ${t.subject}');
    }
    return all;
  }

  Future<List<ComplaintTicket>> _fetchAccumulatedTickets({
    String? status,
    int maxPages = 20,
    bool useAccessToken = false,
  }) async {
    final List<ComplaintTicket> all = [];
    String? currentToken;
    int pages = 0;

    do {
      final result = await fetchTicketsPage(
        status: status,
        nextToken: currentToken,
        useAccessToken: useAccessToken,
      );
      final List<ComplaintTicket> list =
          (result['tickets'] as List<ComplaintTicket>?) ?? [];
      all.addAll(list);
      currentToken = result['nextToken'] as String?;
      pages++;
    } while (
        currentToken != null && currentToken.isNotEmpty && pages < maxPages);

    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  /// Fetch complaints raised by a specific user.
  /// For normal users, GET /tickets is filtered server-side by their sub/email automatically.
  Future<List<ComplaintTicket>> getComplaintsForUser(String userEmail) async {
    final tickets = await getAllComplaints();
    if (userEmail.trim().isEmpty) return tickets;
    final normalized = userEmail.trim().toLowerCase();
    final filtered = tickets.where((t) {
      return t.userEmail.trim().toLowerCase() == normalized;
    }).toList();
    // If backend already filtered for this user, return all
    return filtered.isNotEmpty ? filtered : tickets;
  }

  /// Fetch a single ticket by ID with full event history (GET /tickets/{ticketId})
  Future<ComplaintTicket?> getComplaintById(String ticketId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('$apiBaseUrl/tickets/$ticketId');
      final resp = await http.get(uri, headers: headers);
      lastDebugInfo += '\n\nGET $uri\nHTTP ${resp.statusCode}\nResponse: ${resp.body}';

      if (resp.statusCode != 200) {
        if (resp.statusCode == 404) return null;
        final err = _extractErrorMessage(resp);
        throw Exception('Failed to get ticket: $err');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final ticketMap = Map<String, dynamic>.from(data['ticket'] ?? data);
      if (data.containsKey('events')) {
        ticketMap['events'] = data['events'];
      }

      return ComplaintTicket.fromJson(ticketMap);
    } catch (e) {
      if (kDebugMode) debugPrint('Error loading ticket $ticketId: $e');
      rethrow;
    }
  }

  /// Admin updates complaint status (PATCH /tickets/{ticketId}/status).
  /// Only users in the Cognito group `Admin` are authorized by the backend.
  Future<ComplaintTicket> updateComplaintStatus({
    required String ticketId,
    required ComplaintStatus status,
    String? assignedTo,
    String? optionalResolutionNote,
    String? adminEmail,
    String? adminName,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$apiBaseUrl/tickets/$ticketId/status');

    final body = jsonEncode({
      'status': status.apiValue,
      if (optionalResolutionNote != null &&
          optionalResolutionNote.trim().isNotEmpty)
        'note': optionalResolutionNote.trim(),
    });

    final resp = await http.patch(uri, headers: headers, body: body);
    if (resp.statusCode != 200) {
      final err = _extractErrorMessage(resp);
      throw Exception('Failed to update status: $err');
    }

    final updated = await getComplaintById(ticketId);
    if (updated != null) return updated;

    return ComplaintTicket(
      ticketId: ticketId,
      userEmail: adminEmail ?? '',
      userName: adminName ?? 'Admin',
      deviceId: '',
      category: ComplaintCategory.other,
      priority: ComplaintPriority.medium,
      subject: '',
      description: '',
      status: status,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Post a message or reply on a ticket (POST /tickets/{ticketId}/messages).
  /// Supports optional attachment metadata.
  Future<void> addMessage({
    required String ticketId,
    required String message,
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$apiBaseUrl/tickets/$ticketId/messages');

    final body = jsonEncode({
      'message': message.trim(),
      'attachments': attachments,
    });

    final resp = await http.post(uri, headers: headers, body: body);
    if (resp.statusCode != 201) {
      final err = _extractErrorMessage(resp);
      throw Exception('Failed to send message: $err');
    }
  }

  /// Admin sends a response/reply to the user on a ticket
  Future<ComplaintTicket> addAdminResponse({
    required String ticketId,
    required String responderName,
    required String responderEmail,
    required String message,
    bool isInternal = false,
    ComplaintStatus? newStatus,
    List<AttachmentUploadPayload> files = const [],
  }) async {
    // 1. Upload files if any
    final List<Map<String, dynamic>> uploaded = [];
    for (final file in files) {
      final meta = await uploadAttachment(
        ticketId: ticketId,
        filename: file.filename,
        contentType: file.contentType,
        bytes: file.bytes,
      );
      uploaded.add({
        'attachmentId': meta['attachmentId'],
        'key': meta['key'],
        'filename': meta['filename'],
        'contentType': meta['contentType'],
      });
    }

    // 2. Post message
    await addMessage(
      ticketId: ticketId,
      message: message,
      attachments: uploaded,
    );

    // 3. Update status if requested
    if (newStatus != null) {
      await updateComplaintStatus(
        ticketId: ticketId,
        status: newStatus,
        adminEmail: responderEmail,
        adminName: responderName,
      );
    }

    final updated = await getComplaintById(ticketId);
    if (updated != null) return updated;
    throw Exception('Failed to reload ticket after response');
  }

  /// User adds a follow-up reply to their existing ticket
  Future<ComplaintTicket> addUserFollowUp({
    required String ticketId,
    required String userEmail,
    required String userName,
    required String message,
    List<AttachmentUploadPayload> files = const [],
  }) async {
    // 1. Upload files if any
    final List<Map<String, dynamic>> uploaded = [];
    for (final file in files) {
      final meta = await uploadAttachment(
        ticketId: ticketId,
        filename: file.filename,
        contentType: file.contentType,
        bytes: file.bytes,
      );
      uploaded.add({
        'attachmentId': meta['attachmentId'],
        'key': meta['key'],
        'filename': meta['filename'],
        'contentType': meta['contentType'],
      });
    }

    // 2. Post message
    await addMessage(
      ticketId: ticketId,
      message: message,
      attachments: uploaded,
    );

    final updated = await getComplaintById(ticketId);
    if (updated != null) return updated;
    throw Exception('Failed to reload ticket after user reply');
  }

  /// User reopens a resolved ticket within 7 days of resolution
  Future<ComplaintTicket> reopenComplaint({
    required String ticketId,
    required String userEmail,
    required String userName,
    required String reason,
  }) async {
    // 1. Post message explaining the reopening
    await addMessage(
      ticketId: ticketId,
      message: 'Ticket reopened by user: ${reason.trim()}',
    );

    // 2. Try updating the status to REOPENED via PATCH /status
    try {
      await updateComplaintStatus(
        ticketId: ticketId,
        status: ComplaintStatus.reopened,
        optionalResolutionNote: reason.trim(),
        adminEmail: userEmail,
        adminName: userName,
      );
    } catch (_) {
      // If PATCH is Admin-only on backend, the message was already recorded
    }

    final updated = await getComplaintById(ticketId);
    if (updated != null) {
      updated.status = ComplaintStatus.reopened;
      return updated;
    }
    throw Exception('Failed to reload ticket after reopen');
  }
}
