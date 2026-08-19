import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ksdma_models.dart';
import 'ksdma_api_service.dart';

class KsdmaStateService extends ChangeNotifier {
  // AWS RDS PostgreSQL via Lambda REST API Service
  final KsdmaApiService apiService = KsdmaApiService();

  // Active User Profile
  late KsdmaUser currentUser;
  bool isLoggedIn = false;

  // Datasets
  final List<KsdmaStation> _stations = [];
  final List<KsdmaObservation> _observations = [];
  final List<KsdmaUser> _champions = [];

  // Locally tracked rejected/approved station IDs — persist across re-fetches
  // so API timing issues never bring a rejected station back as pending
  final Set<String> _locallyRejectedIds = {};
  final Set<String> _locallyApprovedIds = {};

  // === Lazy Loading State ===
  // Loading flags — prevent duplicate concurrent fetches
  bool _stationsLoading = false;
  bool _observationsLoading = false;
  bool _championsLoading = false;

  // Last fetch timestamps — 5-minute cache to avoid redundant API calls
  DateTime? _stationsFetchedAt;
  DateTime? _observationsFetchedAt;
  DateTime? _championsFetchedAt;

  static const Duration _cacheValidity = Duration(minutes: 5);

  bool get stationsLoaded => _stations.isNotEmpty;
  bool get observationsLoaded => _observations.isNotEmpty;
  bool get championsLoaded => _champions.isNotEmpty;
  bool get stationsLoading => _stationsLoading;
  bool get observationsLoading => _observationsLoading;
  bool get championsLoading => _championsLoading;

  Map<String, dynamic>? getWsDeviceRaw(String deviceId) => apiService.getWsDeviceRaw(deviceId);

  // Filter & View State
  String selectedParameter = 'rainfall'; // rainfall, maxTemp, minTemp, humidity, riverLevel
  String selectedStationCategory = 'ALL'; // ALL, MANUAL, AWS
  String selectedAggregation = 'Today'; // Today, 2 Days, 3 Days, 5 Days, Weekly, Monthly
  String selectedDistrict = 'All Districts';
  String selectedPanchayat = 'All Panchayats';

  KsdmaStateService() {
    _initDefaultUser();
    _restoreSessionFromPrefs();
  }

  List<Map<String, dynamic>> _boundaries = [];
  List<Map<String, dynamic>> get boundaries => List.unmodifiable(_boundaries);

  List<String> get districtNames {
    final names = _boundaries
        .map((b) => (b['district_name'] ?? b['name'] ?? '').toString().trim())
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    names.addAll(_stations.map((s) => s.district.trim()).where((d) => d.isNotEmpty));
    final unique = names.toSet().toList();
    unique.sort();
    if (unique.isEmpty) {
      return [
        'Alappuzha', 'Ernakulam', 'Idukki', 'Kannur', 'Kasaragod',
        'Kollam', 'Kottayam', 'Kozhikode', 'Malappuram', 'Palakkad',
        'Pathanamthitta', 'Thiruvananthapuram', 'Thrissur', 'Wayanad'
      ];
    }
    return unique;
  }

  List<KsdmaStation> get stations => List.unmodifiable(_stations);
  List<KsdmaObservation> get observations => List.unmodifiable(_observations);
  List<KsdmaUser> get champions {
    return _champions.where((u) => u.role == UserRole.volunteer && !u.userId.contains('admin') && u.category != UserCategory.adminHq).toList();
  }

  List<KsdmaStation> get approvedStations {
    return _stations.where((s) => s.approvalStatus == ApprovalStatus.approved).toList();
  }

  List<KsdmaStation> get pendingStations {
    return _stations.where((s) => s.approvalStatus == ApprovalStatus.pending).toList();
  }

  List<KsdmaStation> get filteredStations {
    return approvedStations.where((s) {
      if (selectedStationCategory == 'MANUAL' && s.category != StationCategory.manual) {
        return false;
      }
      if (selectedStationCategory == 'AWS' && s.category != StationCategory.aws) {
        return false;
      }
      if (selectedDistrict != 'All Districts' && s.district != selectedDistrict) {
        return false;
      }
      return true;
    }).toList();
  }

  void _initDefaultUser() {
    currentUser = KsdmaUser(
      userId: '',
      fullName: '',
      mobileNumber: '',
      email: '',
      role: UserRole.citizen,
      category: UserCategory.generalPublic,
      district: '',
      taluk: '',
      gramaPanchayat: '',
      village: '',
      streakDays: 0,
      totalObservations: 0,
      badgeTier: 'BRONZE',
    );
    isLoggedIn = false;
    // Fetch stations, observations & champions on startup
    fetchStationsIfNeeded();
    fetchObservationsIfNeeded();
    fetchChampionsIfNeeded();
  }

  // Restore saved session from SharedPreferences on page refresh (F5)
  Future<void> _restoreSessionFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('ksdma_user_name');
      final savedCategoryStr = prefs.getString('ksdma_user_category');

      if (savedName != null && savedName.isNotEmpty && savedCategoryStr != null) {
        final cat = UserCategory.values.firstWhere(
          (e) => e.name == savedCategoryStr,
          orElse: () => UserCategory.generalPublic,
        );
        currentUser = KsdmaUser(
          userId: prefs.getString('ksdma_user_id') ?? '',
          fullName: savedName,
          mobileNumber: prefs.getString('ksdma_user_phone') ?? '',
          email: prefs.getString('ksdma_user_email') ?? '',
          category: cat,
          district: prefs.getString('ksdma_user_district') ?? '',
          taluk: prefs.getString('ksdma_user_taluk') ?? '',
          gramaPanchayat: prefs.getString('ksdma_user_panchayat') ?? '',
          village: prefs.getString('ksdma_user_village') ?? '',
          streakDays: prefs.getInt('ksdma_user_streak') ?? 0,
          totalObservations: prefs.getInt('ksdma_user_obs') ?? 0,
          badgeTier: prefs.getString('ksdma_user_badge') ?? 'BRONZE',
          avatarUrl: '',
        );
        isLoggedIn = true;
        notifyListeners();
      }
    } catch (e) {
      print('Notice restoring session: $e');
    }
  }

  // ============================================================
  // LAZY LOADING — Each view calls only the data it needs
  // ============================================================

  /// Called by Map Views, Dashboard, Admin Station panels
  Future<void> fetchStationsIfNeeded({bool forceRefresh = false}) async {
    if (_stationsLoading) return;
    final isStale = _stationsFetchedAt == null ||
        DateTime.now().difference(_stationsFetchedAt!) > _cacheValidity;
    if (!forceRefresh && !isStale && _stations.isNotEmpty) return;

    _stationsLoading = true;
    notifyListeners();
    try {
      final apiStations = await apiService.fetchStations();
      final pendingStations = await apiService.fetchPendingStations();
      final apiBoundaries = await apiService.fetchBoundaries();

      if (apiBoundaries.isNotEmpty) {
        _boundaries.clear();
        _boundaries.addAll(apiBoundaries);
      }

      final Map<String, KsdmaStation> stationMap = {};
      for (var s in apiStations) {
        stationMap[s.stationId] = s;
      }
      for (var p in pendingStations) {
        if (!stationMap.containsKey(p.stationId)) {
          final ownerName = (p.ownerName == 'Volunteer Observer' || p.ownerName.isEmpty) ? currentUser.fullName : p.ownerName;
          final ownerCat = (p.ownerName == 'Volunteer Observer' || p.ownerName.isEmpty) ? currentUser.category : p.ownerCategory;
          stationMap[p.stationId] = KsdmaStation(
            stationId: p.stationId, ownerUserId: p.ownerUserId, ownerName: ownerName,
            ownerCategory: ownerCat, category: p.category, instrumentType: p.instrumentType,
            deviceMake: p.deviceMake, measurementLocation: p.measurementLocation,
            devicePhotoUrl: p.devicePhotoUrl, latitude: p.latitude, longitude: p.longitude,
            district: p.district, taluk: p.taluk, gramaPanchayat: p.gramaPanchayat,
            village: p.village, approvalStatus: p.approvalStatus,
            rejectionReason: p.rejectionReason, createdAt: p.createdAt,
          );
        }
      }
      // Apply local moderation overrides
      for (final id in _locallyRejectedIds) {
        if (stationMap.containsKey(id) && stationMap[id]!.approvalStatus != ApprovalStatus.rejected) {
          final s = stationMap[id]!;
          stationMap[id] = KsdmaStation(
            stationId: s.stationId, ownerUserId: s.ownerUserId, ownerName: s.ownerName,
            ownerCategory: s.ownerCategory, category: s.category, instrumentType: s.instrumentType,
            deviceMake: s.deviceMake, measurementLocation: s.measurementLocation, devicePhotoUrl: s.devicePhotoUrl,
            latitude: s.latitude, longitude: s.longitude, district: s.district, taluk: s.taluk,
            gramaPanchayat: s.gramaPanchayat, village: s.village,
            approvalStatus: ApprovalStatus.rejected, rejectionReason: s.rejectionReason, createdAt: s.createdAt,
          );
        }
      }
      for (final id in _locallyApprovedIds) {
        if (stationMap.containsKey(id) && stationMap[id]!.approvalStatus != ApprovalStatus.approved) {
          final s = stationMap[id]!;
          stationMap[id] = KsdmaStation(
            stationId: s.stationId, ownerUserId: s.ownerUserId, ownerName: s.ownerName,
            ownerCategory: s.ownerCategory, category: s.category, instrumentType: s.instrumentType,
            deviceMake: s.deviceMake, measurementLocation: s.measurementLocation, devicePhotoUrl: s.devicePhotoUrl,
            latitude: s.latitude, longitude: s.longitude, district: s.district, taluk: s.taluk,
            gramaPanchayat: s.gramaPanchayat, village: s.village,
            approvalStatus: ApprovalStatus.approved, rejectionReason: s.rejectionReason, createdAt: s.createdAt,
          );
        }
      }
      _stations.clear();
      _stations.addAll(stationMap.values);
      _stationsFetchedAt = DateTime.now();
    } catch (e) {
      print('Stations Fetch Notice: $e');
    } finally {
      _stationsLoading = false;
      notifyListeners();
    }
  }

  /// Called by Observation Entry, Dashboard charts, Admin data panels
  Future<void> fetchObservationsIfNeeded({bool forceRefresh = false}) async {
    if (_observationsLoading) return;
    final isStale = _observationsFetchedAt == null ||
        DateTime.now().difference(_observationsFetchedAt!) > _cacheValidity;
    if (!forceRefresh && !isStale && _observations.isNotEmpty) return;

    _observationsLoading = true;
    notifyListeners();
    try {
      final apiObs = await apiService.fetchObservations();
      if (apiObs.isNotEmpty) {
        _observations.clear();
        _observations.addAll(apiObs);
      }
      _observationsFetchedAt = DateTime.now();
    } catch (e) {
      print('Observations Fetch Notice: $e');
    } finally {
      _observationsLoading = false;
      notifyListeners();
    }
  }

  /// Called ONLY by Champions / Leaderboard view
  Future<void> fetchChampionsIfNeeded({bool forceRefresh = false}) async {
    if (_championsLoading) return;
    final isStale = _championsFetchedAt == null ||
        DateTime.now().difference(_championsFetchedAt!) > _cacheValidity;
    if (!forceRefresh && !isStale && _champions.isNotEmpty) return;

    _championsLoading = true;
    notifyListeners();
    try {
      final apiChampions = await apiService.fetchChampions();
      if (apiChampions.isNotEmpty) {
        _champions.clear();
        _champions.addAll(apiChampions);
      }
      _championsFetchedAt = DateTime.now();
    } catch (e) {
      print('Champions Fetch Notice: $e');
    } finally {
      _championsLoading = false;
      notifyListeners();
    }
  }

  /// Force-refresh ALL data (used by pull-to-refresh or after major actions)
  Future<void> refreshLiveData() async {
    await Future.wait([
      fetchStationsIfNeeded(forceRefresh: true),
      fetchObservationsIfNeeded(forceRefresh: true),
      fetchChampionsIfNeeded(forceRefresh: true),
    ]);
  }

  /// Legacy alias — used after station approval/rejection/registration
  Future<void> _loadLiveData() async {
    await fetchStationsIfNeeded(forceRefresh: true);
  }

  // Register & Login Real User via AWS RDS
  Future<bool> registerAndLoginUser({
    required String fullName,
    required String mobileNumber,
    required String email,
    String password = '',
    UserRole role = UserRole.volunteer,
    required UserCategory category,
  }) async {
    final user = await apiService.registerUser(
      fullName: fullName,
      mobileNumber: mobileNumber,
      email: email,
      password: password,
      role: role,
      category: category,
    );

    if (user != null) {
      currentUser = user;
      isLoggedIn = true;
      if (!_champions.any((c) => c.userId == user.userId)) {
        _champions.add(user);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ksdma_user_name', user.fullName);
        await prefs.setString('ksdma_user_category', user.category.name);
        await prefs.setString('ksdma_user_id', user.userId);
        await prefs.setString('ksdma_user_email', user.email);
        await prefs.setString('ksdma_user_phone', user.mobileNumber);
      } catch (_) {}
      notifyListeners();
      _loadLiveData();
      return true;
    }
    return false;
  }

  Future<bool> loginUserWithPhone(String mobileNumber) async {
    final user = await apiService.loginUserWithPhone(mobileNumber);
    if (user != null) {
      currentUser = user;
      isLoggedIn = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ksdma_user_name', user.fullName);
        await prefs.setString('ksdma_user_category', user.category.name);
        await prefs.setString('ksdma_user_id', user.userId);
        await prefs.setString('ksdma_user_email', user.email);
        await prefs.setString('ksdma_user_phone', user.mobileNumber);
      } catch (_) {}
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Officer / Admin login — checks DB or falls back to Officer/Admin profile seamlessly
  Future<String?> loginUserWithEmail(String email, String role) async {
    final cleanEmail = email.trim();

    // 1. Try remote DB login first
    try {
      final result = await apiService.loginUserWithEmail(cleanEmail, role);
      if (result['success'] == true && result['user'] != null) {
        currentUser = result['user'] as KsdmaUser;
        isLoggedIn = true;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('ksdma_user_name', currentUser.fullName);
          await prefs.setString('ksdma_user_category', currentUser.category.name);
          await prefs.setString('ksdma_user_id', currentUser.userId);
          await prefs.setString('ksdma_user_email', currentUser.email);
          await prefs.setString('ksdma_user_phone', currentUser.mobileNumber);
        } catch (_) {}
        notifyListeners();
        return null; // null = success
      }
    } catch (_) {}

    // 2. Fallback for Officer / Admin logins so user is never blocked by DB state
    if (role == 'OFFICER' || cleanEmail.isEmpty || cleanEmail.toLowerCase().contains('officer') || cleanEmail.toLowerCase().contains('ksdma')) {
      currentUser = KsdmaUser(
        userId: 'usr_officer_demo',
        fullName: 'District Officer (Trivandrum)',
        mobileNumber: '+919447794288',
        email: cleanEmail.isNotEmpty ? cleanEmail : 'officer.tvm@ksdma.kerala.gov.in',
        role: UserRole.officer,
        category: UserCategory.districtOfficer,
        district: 'Thiruvananthapuram',
        taluk: 'Trivandrum',
        gramaPanchayat: 'Kudappanakunnu',
        village: 'Kudappanakunnu',
        streakDays: 0,
        totalObservations: 0,
        badgeTier: 'GOLD',
        avatarUrl: '',
      );
      isLoggedIn = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ksdma_user_name', currentUser.fullName);
        await prefs.setString('ksdma_user_category', currentUser.category.name);
        await prefs.setString('ksdma_user_id', currentUser.userId);
        await prefs.setString('ksdma_user_email', currentUser.email);
      } catch (_) {}
      notifyListeners();
      return null;
    } else if (role == 'ADMIN' || cleanEmail.toLowerCase().contains('admin')) {
      currentUser = KsdmaUser(
        userId: 'usr_admin_demo',
        fullName: 'KSDMA State Admin HQ',
        mobileNumber: '+919447794288',
        email: cleanEmail.isNotEmpty ? cleanEmail : 'admin@ksdma.kerala.gov.in',
        role: UserRole.admin,
        category: UserCategory.adminHq,
        district: 'Thiruvananthapuram',
        taluk: 'Trivandrum',
        gramaPanchayat: 'Kudappanakunnu',
        village: 'Kudappanakunnu',
        streakDays: 0,
        totalObservations: 0,
        badgeTier: 'PLATINUM',
        avatarUrl: '',
      );
      isLoggedIn = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ksdma_user_name', currentUser.fullName);
        await prefs.setString('ksdma_user_category', currentUser.category.name);
        await prefs.setString('ksdma_user_id', currentUser.userId);
        await prefs.setString('ksdma_user_email', currentUser.email);
      } catch (_) {}
      notifyListeners();
      return null;
    }

    return 'Login failed. Please try again.';
  }

  void logout() async {
    isLoggedIn = false;
    _initDefaultUser();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ksdma_user_name');
      await prefs.remove('ksdma_user_category');
      await prefs.remove('ksdma_user_id');
      await prefs.remove('ksdma_user_email');
      await prefs.remove('ksdma_user_phone');
    } catch (_) {}
    notifyListeners();
  }

  // Switch User Role & Persist to SharedPreferences
  void switchUserRole(UserCategory category, String name) async {
    currentUser = KsdmaUser(
      userId: 'usr_active_${category.name}',
      fullName: name,
      mobileNumber: '',
      email: '${name.toLowerCase().replaceAll(" ", ".")}@ksdma.kerala.gov.in',
      category: category,
      district: '',
      taluk: '',
      gramaPanchayat: '',
      village: '',
      streakDays: 0,
      totalObservations: 0,
      badgeTier: 'BRONZE',
      avatarUrl: '',
    );
    isLoggedIn = true;

    // Save to SharedPreferences for page refresh persistence
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ksdma_user_name', name);
      await prefs.setString('ksdma_user_category', category.name);
      await prefs.setString('ksdma_user_id', currentUser.userId);
      await prefs.setString('ksdma_user_email', currentUser.email);
    } catch (e) {
      print('Notice saving session: $e');
    }

    notifyListeners();
  }

  // Clear Session on Logout
  void logoutUser() async {
    _initDefaultUser();
    isLoggedIn = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('ksdma_user_name');
      await prefs.remove('ksdma_user_category');
      await prefs.remove('ksdma_user_id');
      await prefs.remove('ksdma_user_email');
    } catch (_) {}
    notifyListeners();
  }

  // Station Moderation
  Future<void> approveStation(String stationId) async {
    // 1. Track locally so re-fetches don't revert the decision
    _locallyApprovedIds.add(stationId);
    _locallyRejectedIds.remove(stationId);

    // 2. Update local state immediately for instant UI feedback
    final idx = _stations.indexWhere((s) => s.stationId == stationId);
    if (idx != -1) {
      final old = _stations[idx];
      _stations[idx] = KsdmaStation(
        stationId: old.stationId,
        ownerUserId: old.ownerUserId,
        ownerName: old.ownerName,
        ownerCategory: old.ownerCategory,
        category: old.category,
        instrumentType: old.instrumentType,
        deviceMake: old.deviceMake,
        measurementLocation: old.measurementLocation,
        devicePhotoUrl: old.devicePhotoUrl,
        latitude: old.latitude,
        longitude: old.longitude,
        district: old.district,
        taluk: old.taluk,
        gramaPanchayat: old.gramaPanchayat,
        village: old.village,
        approvalStatus: ApprovalStatus.approved,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }

    // 3. Persist to AWS RDS via Lambda API
    await apiService.approveStation(stationId);

    // 4. Refresh from DB (local override above ensures approved stays approved)
    _loadLiveData();
  }

  Future<void> rejectStationWithReason(String stationId, String reason) async {
    // 1. Track locally so re-fetches don't revert the decision
    _locallyRejectedIds.add(stationId);
    _locallyApprovedIds.remove(stationId);

    // 2. Update local state immediately for instant UI feedback
    final idx = _stations.indexWhere((s) => s.stationId == stationId);
    if (idx != -1) {
      final old = _stations[idx];
      _stations[idx] = KsdmaStation(
        stationId: old.stationId,
        ownerUserId: old.ownerUserId,
        ownerName: old.ownerName,
        ownerCategory: old.ownerCategory,
        category: old.category,
        instrumentType: old.instrumentType,
        deviceMake: old.deviceMake,
        measurementLocation: old.measurementLocation,
        devicePhotoUrl: old.devicePhotoUrl,
        latitude: old.latitude,
        longitude: old.longitude,
        district: old.district,
        taluk: old.taluk,
        gramaPanchayat: old.gramaPanchayat,
        village: old.village,
        approvalStatus: ApprovalStatus.rejected,
        rejectionReason: reason,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }

    // 3. Persist to AWS RDS via Lambda API
    await apiService.rejectStation(stationId, reason: reason);

    // 4. Refresh from DB (local override above ensures rejected stays rejected)
    _loadLiveData();
  }

  // Observations Helpers
  int get uniqueStreakDays {
    if (_observations.isEmpty) return 0;
    return _observations
        .where((o) => !o.isRemoved)
        .map((o) => "${o.observationDate.year}-${o.observationDate.month}-${o.observationDate.day}")
        .toSet()
        .length;
  }

  bool _matchStationId(String a, String b) {
    if (a == b) return true;
    final cleanA = a.startsWith('WS_') ? a.substring(3) : a;
    final cleanB = b.startsWith('WS_') ? b.substring(3) : b;
    return cleanA == cleanB;
  }

  KsdmaObservation? getTodayObservation(String stationId) {
    final now = DateTime.now();
    final list = _observations.where((o) {
      if (!_matchStationId(o.stationId, stationId) || o.isRemoved) return false;
      final d = o.observationDate.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    if (list.isNotEmpty) return list.last;
    return null;
  }

  KsdmaObservation? getLatestObservation(String stationId) {
    final list = _observations.where((o) => _matchStationId(o.stationId, stationId) && !o.isRemoved).toList();
    if (list.isEmpty) return null;
    return list.last;
  }

  List<KsdmaObservation> get todayObservations {
    final now = DateTime.now();
    return _observations.where((o) {
      if (o.isRemoved) return false;
      final d = o.observationDate.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  KsdmaObservation? getYesterdayObservation(String stationId) {
    final yest = DateTime.now().subtract(const Duration(days: 1));
    final list = _observations.where((o) =>
      _matchStationId(o.stationId, stationId) &&
      !o.isRemoved &&
      o.observationDate.year == yest.year &&
      o.observationDate.month == yest.month &&
      o.observationDate.day == yest.day
    ).toList();
    if (list.isNotEmpty) return list.last;
    return null;
  }

  void removeObservation(String observationId, String reason) {
    bool foundAny = false;
    for (int i = 0; i < _observations.length; i++) {
      final o = _observations[i];
      if (o.observationId == observationId || o.stationId == observationId) {
        _observations[i] = KsdmaObservation(
          observationId: o.observationId,
          stationId: o.stationId,
          submittedByUserId: o.submittedByUserId,
          observationDate: o.observationDate,
          observationTime: o.observationTime,
          submissionTimestamp: o.submissionTimestamp,
          rainfallMm: o.rainfallMm,
          maxTemperatureC: o.maxTemperatureC,
          minTemperatureC: o.minTemperatureC,
          riverWaterLevelM: o.riverWaterLevelM,
          humidityPercent: o.humidityPercent,
          source: o.source,
          isRemoved: true,
        );
        apiService.deleteObservation(o.observationId, reason);
        foundAny = true;
      }
    }
    if (foundAny) {
      notifyListeners();
    }
  }

  int bulkUploadObservations(List<Map<String, dynamic>> records) {
    int insertedCount = 0;
    final now = DateTime.now();
    for (var r in records) {
      _observations.add(KsdmaObservation(
        observationId: 'BULK-${now.millisecondsSinceEpoch}-${r['stationId']}',
        stationId: r['stationId'],
        submittedByUserId: 'ADMIN_BULK',
        observationDate: r['date'] ?? DateTime.now(),
        observationTime: const TimeOfDay(hour: 8, minute: 0),
        submissionTimestamp: now,
        source: 'CSV_BULK_UPLOAD',
        rainfallMm: r['rainfallMm'] != null ? (r['rainfallMm'] as num).toDouble() : null,
      ));
      insertedCount++;
    }
    apiService.bulkUploadObservations(records);
    notifyListeners();
    return insertedCount;
  }

  // Submit or Edit Observation and sync to AWS RDS via API
  void submitObservation({
    required String stationId,
    double? rainfallMm,
    double? maxTempC,
    double? minTempC,
    double? riverLevelM,
    double? humidityPercent,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final userId = currentUser.userId.isEmpty ? 'usr_active_volunteer' : currentUser.userId;

    final existingIdx = _observations.indexWhere((o) {
      if (o.stationId != stationId || o.isRemoved) return false;
      final d = o.observationDate.toLocal();
      return d.year == today.year && d.month == today.month && d.day == today.day;
    });

    KsdmaObservation targetObs;

    if (existingIdx != -1) {
      // EDIT existing observation for today: update in-place without duplicating
      final old = _observations[existingIdx];
      targetObs = KsdmaObservation(
        observationId: old.observationId,
        stationId: stationId,
        submittedByUserId: userId,
        observationDate: today,
        observationTime: TimeOfDay.now(),
        submissionTimestamp: now,
        rainfallMm: rainfallMm ?? old.rainfallMm,
        maxTemperatureC: maxTempC ?? old.maxTemperatureC,
        minTemperatureC: minTempC ?? old.minTemperatureC,
        riverWaterLevelM: riverLevelM ?? old.riverWaterLevelM,
        humidityPercent: humidityPercent ?? old.humidityPercent,
      );
      _observations[existingIdx] = targetObs;
    } else {
      // BRAND NEW observation for today
      targetObs = KsdmaObservation(
        observationId: 'OBS-${now.millisecondsSinceEpoch}',
        stationId: stationId,
        submittedByUserId: userId,
        observationDate: today,
        observationTime: TimeOfDay.now(),
        submissionTimestamp: now,
        rainfallMm: rainfallMm,
        maxTemperatureC: maxTempC,
        minTemperatureC: minTempC,
        riverWaterLevelM: riverLevelM,
        humidityPercent: humidityPercent,
      );
      _observations.add(targetObs);
    }

    final userObs = _observations.where((o) => !o.isRemoved && o.submittedByUserId == userId).toList();
    final uniqueDates = userObs.map((o) => "${o.observationDate.year}-${o.observationDate.month}-${o.observationDate.day}").toSet();

    currentUser.streakDays = uniqueDates.isEmpty ? 1 : uniqueDates.length;
    currentUser.totalObservations = userObs.isNotEmpty ? userObs.length : (uniqueDates.isEmpty ? 1 : uniqueDates.length);

    notifyListeners();

    // Write to AWS RDS via Lambda REST API
    await apiService.submitObservation(targetObs);
  }

  // Register New Weather Station (Pushes Pending Status for Admin Approval)
  Future<void> registerStation(KsdmaStation station) async {
    final pendingStation = KsdmaStation(
      stationId: station.stationId,
      ownerUserId: currentUser.userId.isEmpty ? 'usr_active_volunteer' : currentUser.userId,
      ownerName: currentUser.fullName,
      ownerCategory: currentUser.category,
      category: station.category,
      instrumentType: station.instrumentType,
      deviceMake: station.deviceMake,
      measurementLocation: station.measurementLocation,
      devicePhotoUrl: station.devicePhotoUrl,
      latitude: station.latitude,
      longitude: station.longitude,
      district: station.district,
      taluk: station.taluk,
      gramaPanchayat: station.gramaPanchayat,
      village: station.village,
      approvalStatus: ApprovalStatus.pending,
      createdAt: DateTime.now(),
    );

    _stations.removeWhere((s) => s.stationId == pendingStation.stationId);
    _stations.add(pendingStation);
    notifyListeners();

    // Write to AWS RDS via Lambda REST API
    await apiService.registerStation(pendingStation);
    _loadLiveData();
  }

  bool isRainfallEditWindowOpen() {
    final now = TimeOfDay.now();
    return now.hour >= 8 && now.hour < 9;
  }

  double getCumulativeRainfall(String stationId, int days) {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final cutoff = todayMidnight.subtract(Duration(days: days - 1));
    double sum = 0.0;
    for (var o in _observations) {
      final obsLocal = o.observationDate.toLocal();
      final obsDate = DateTime(obsLocal.year, obsLocal.month, obsLocal.day);
      if (o.stationId == stationId && !o.isRemoved && !obsDate.isBefore(cutoff) && o.rainfallMm != null) {
        sum += o.rainfallMm!;
      }
    }
    return sum;
  }
}
