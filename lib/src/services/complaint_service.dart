import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:universal_html/html.dart' as html;
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
    String ext = (file.extension ?? '').toLowerCase();
    if (ext.isEmpty && file.name.contains('.')) {
      ext = file.name.split('.').last.toLowerCase();
    }

    // Default allowlist per AWS documentation: image/jpeg, image/png, image/webp, application/pdf
    String mime = 'image/jpeg';
    if (ext == 'png') {
      mime = 'image/png';
    } else if (ext == 'webp') {
      mime = 'image/webp';
    } else if (ext == 'pdf') {
      mime = 'application/pdf';
    } else if (ext == 'jpg' || ext == 'jpeg') {
      mime = 'image/jpeg';
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
  ComplaintService._internal() {
    _loadSavedBucketOrigin();
  }

  void _loadSavedBucketOrigin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('ticket_s3_bucket_origin');
      if (saved != null && saved.isNotEmpty) {
        s3BucketOrigin = saved;
        TicketAttachment.s3BucketBaseUrl = saved;
      }
    } catch (_) {}
  }

  /// Live log entries for real-time diagnostic viewing
  static final List<String> uploadLogs = [];

  static void log(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final line = '[$timestamp] $message';
    uploadLogs.add(line);
    if (uploadLogs.length > 250) {
      uploadLogs.removeAt(0);
    }
    lastDebugInfo += '\n$line';
    debugPrint('[ComplaintService] $message');
  }

  static String get formattedLogs => uploadLogs.join('\n');

  /// Holds the last raw HTTP call and response for live diagnostics
  static String lastDebugInfo = 'No API call made yet';

  /// Production AWS API Gateway Base URL
  static const String apiBaseUrl =
      'https://hd20svxcbh.execute-api.us-east-1.amazonaws.com';

  /// Known S3 bucket origin dynamically learned from uploadUrl
  static String? s3BucketOrigin;

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

  /// Executes raw PUT of binary bytes to S3 using native browser XHR on Web
  /// to capture precise HTTP status codes, error bodies, and CORS preflight blocks.
  Future<int> _executeS3Upload({
    required String uploadUrl,
    required Map<String, String> headers,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (kIsWeb) {
      final completer = Completer<int>();
      try {
        final xhr = html.HttpRequest();
        xhr.open('PUT', uploadUrl, async: true);
        headers.forEach((key, val) {
          try {
            xhr.setRequestHeader(key, val);
          } catch (e) {
            log('Header warning ($key: $val): $e');
          }
        });

        xhr.onLoad.listen((_) {
          final status = xhr.status ?? 0;
          final respText = xhr.responseText ?? '';
          log('S3 response HTTP $status');
          if (respText.isNotEmpty) {
            log('S3 response body: $respText');
          }
          if (!completer.isCompleted) completer.complete(status);
        });

        xhr.onError.listen((e) {
          final status = xhr.status ?? 0;
          log('S3 XHR error: status=$status, statusText=${xhr.statusText}');
          if (!completer.isCompleted) completer.complete(status);
        });

        final blob = html.Blob([bytes], contentType);
        xhr.send(blob);
        return await completer.future;
      } catch (e) {
        log('S3 XHR exception: $e');
        return 0;
      }
    }

    try {
      final resp = await http.put(
        Uri.parse(uploadUrl),
        headers: headers,
        body: bytes,
      );
      log('HTTP Client response: status=${resp.statusCode}, body=${resp.body}');
      return resp.statusCode;
    } catch (e) {
      log('HTTP Client exception: $e');
      return 0;
    }
  }

  /// Requests a presigned S3 PUT URL and uploads raw bytes directly to S3.
  /// Returns the attachment metadata map to include in POST /tickets/{id}/messages.
  Future<Map<String, dynamic>> uploadAttachment({
    required String ticketId,
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    log('=== START ATTACHMENT UPLOAD ===');
    log('Ticket: $ticketId | File: $filename | Type: $contentType | Size: ${bytes.length} bytes');

    if (bytes.isEmpty) {
      log('ERROR: Attachment has 0 bytes. Aborting.');
      throw Exception('Attachment has 0 bytes. Cannot upload empty file.');
    }

    final headers = await _getHeaders();
    final presignUri =
        Uri.parse('$apiBaseUrl/tickets/$ticketId/attachments/presign');

    log('Step 1: Requesting presigned URL -> POST $presignUri');

    final presignResp = await http.post(
      presignUri,
      headers: headers,
      body: jsonEncode({
        'filename': filename,
        'contentType': contentType,
        'size': bytes.length,
      }),
    );

    log('Step 1 result: HTTP ${presignResp.statusCode}');
    if (presignResp.statusCode != 200) {
      final err = _extractErrorMessage(presignResp);
      log('Presign failed: $err');
      throw Exception('Failed to get upload URL: $err');
    }

    final presignData = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final uploadUrl = presignData['uploadUrl'] as String;
    final attachmentMeta =
        Map<String, dynamic>.from(presignData['attachment'] ?? {});

    log('Presign success! S3 Key: ${attachmentMeta['key']}');
    log('Presigned PUT URL: ${uploadUrl.split('?').first}');

    // Save bucket origin for building absolute image URLs
    try {
      final origin = Uri.parse(uploadUrl).origin;
      s3BucketOrigin = origin;
      TicketAttachment.s3BucketBaseUrl = origin;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('ticket_s3_bucket_origin', origin);
      });
    } catch (_) {}

    // Derive accessible URL for image viewing
    final derivedUrl = presignData['downloadUrl'] ??
        presignData['url'] ??
        uploadUrl.split('?').first;
    attachmentMeta['url'] = derivedUrl;

    // In AWS SigV4, the presigned URL requires Content-Type and x-amz-server-side-encryption: AES256
    final Map<String, String> primaryHeaders = {
      'Content-Type': contentType,
      'x-amz-server-side-encryption': 'AES256',
    };

    debugPrint('[ComplaintService] Uploading ${bytes.length} bytes to S3 with headers: $primaryHeaders');

    int statusCode = await _executeS3Upload(
      uploadUrl: uploadUrl,
      headers: primaryHeaders,
      bytes: bytes,
      contentType: contentType,
    );

    // If first attempt was rejected, fallback to Content-Type only
    if (statusCode != 200 && statusCode != 204) {
      final Map<String, String> retryHeaders = {
        'Content-Type': contentType,
      };
      debugPrint('[ComplaintService] Retrying S3 PUT with fallback headers: $retryHeaders');
      statusCode = await _executeS3Upload(
        uploadUrl: uploadUrl,
        headers: retryHeaders,
        bytes: bytes,
        contentType: contentType,
      );
    }

    if (statusCode != 200 && statusCode != 204) {
      final msg = statusCode == 0
          ? 'S3 upload failed with Status 0: Browser CORS preflight (OPTIONS) was rejected by S3 bucket ws-support-tickets.'
          : 'S3 upload rejected with HTTP $statusCode.';
      log('🚨 $msg');
      throw Exception(msg);
    }

    log('✅ S3 upload successful! (HTTP $statusCode)');
    log('=== END ATTACHMENT UPLOAD ===');
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
    final bool isCustom = category == ComplaintCategory.other &&
        customCategoryText != null &&
        customCategoryText.trim().isNotEmpty;

    final Map<String, dynamic> payload = {
      'deviceId': deviceId.trim(),
      'subject': subject.trim(),
      'issueType': issueType,
      'description': description.trim(),
      'urgent': urgent,
    };

    // Strict check: If user selected anything OTHER THAN "Other" from the dropdown,
    // 'customIssue' is NEVER included in the payload sent to the backend.
    if (category == ComplaintCategory.other &&
        customCategoryText != null &&
        customCategoryText.trim().isNotEmpty) {
      payload['customIssue'] = customCategoryText.trim();
    } else {
      payload.remove('customIssue');
    }

    final body = jsonEncode(payload);

    debugPrint('[ComplaintService] POST $uri payload: $body');

    final resp = await http.post(uri, headers: headers, body: body);
    debugPrint('[ComplaintService] POST $uri response (${resp.statusCode}): ${resp.body}');
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
            if (meta['url'] != null) 'url': meta['url'],
            if (meta['maxBytes'] != null) 'maxBytes': meta['maxBytes'],
          });
        }

        if (uploaded.isNotEmpty) {
          debugPrint('[ComplaintService] Adding message with ${uploaded.length} attachments to ticket $ticketId');
          await addMessage(
            ticketId: ticketId,
            message: 'Attached files from ticket creation',
            attachments: uploaded,
          );
          debugPrint('[ComplaintService] Attachments successfully posted to ticket $ticketId');
        }
      } catch (e, stack) {
        log('❌ ATTACHMENT UPLOAD/POST FAILED: $e\n$stack');
        throw Exception('Ticket #$ticketId was created, but uploading photo to S3 failed:\n$e');
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
        if (meta['url'] != null) 'url': meta['url'],
        if (meta['maxBytes'] != null) 'maxBytes': meta['maxBytes'],
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
        if (meta['url'] != null) 'url': meta['url'],
        if (meta['maxBytes'] != null) 'maxBytes': meta['maxBytes'],
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
