import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ppms_flutter/core/config/app_config.dart';
import 'package:ppms_flutter/core/network/api_client.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionController extends ChangeNotifier {
  SessionController()
    : _apiClient = ApiClient(baseUrl: AppConfig.defaultBaseUrl);

  static const _storageKey = 'ppms_flutter_session';

  final ApiClient _apiClient;

  Map<String, dynamic>? _tokens;
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _rootInfo;

  bool get isAuthenticated => _tokens != null && _currentUser != null;
  ApiClient get apiClient => _apiClient;
  Map<String, dynamic>? get currentUser => _currentUser;
  Map<String, dynamic>? get rootInfo => _rootInfo;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      return;
    }

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    _apiClient.baseUrl =
        payload['baseUrl'] as String? ?? AppConfig.defaultBaseUrl;
    _tokens = Map<String, dynamic>.from(payload['tokens'] as Map);

    try {
      await _refreshCurrentUser();
    } on ApiException {
      await clear();
    }
  }

  Future<void> signIn({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _apiClient.baseUrl = baseUrl;
    _rootInfo = await _apiClient.getRootInfo();
    _tokens = await _apiClient.login(username: username, password: password);
    await _refreshCurrentUser();
    await _persist();
    notifyListeners();
  }

  Future<void> signOut() async {
    if (_tokens case {'access_token': final String accessToken}) {
      try {
        await _apiClient.logout(accessToken);
      } on ApiException {
        // Local cleanup should still continue.
      }
    }
    await clear();
  }

  Future<void> clear() async {
    _tokens = null;
    _currentUser = null;
    _rootInfo = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>> fetchDashboard() async {
    final accessToken = await _validAccessToken();
    return _apiClient.getDashboard(
      accessToken: accessToken,
      stationId: _currentUser?['station_id'] as int?,
      organizationId: _currentUser?['organization_id'] as int?,
    );
  }

  Future<List<dynamic>> fetchNotifications() async {
    return _apiClient.getNotifications(await _validAccessToken());
  }

  Future<Map<String, dynamic>> fetchNotificationSummary() async {
    return _apiClient.getNotificationSummary(await _validAccessToken());
  }

  Future<Map<String, dynamic>> markNotificationRead({
    required int notificationId,
  }) async {
    return _apiClient.markNotificationRead(
      await _validAccessToken(),
      notificationId: notificationId,
    );
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    return _apiClient.markAllNotificationsRead(await _validAccessToken());
  }

  Future<List<dynamic>> fetchNotificationPreferences() async {
    return _apiClient.getNotificationPreferences(await _validAccessToken());
  }

  Future<Map<String, dynamic>> updateNotificationPreference({
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateNotificationPreference(
      await _validAccessToken(),
      eventType: eventType,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchNotificationDeliveries() async {
    return _apiClient.getNotificationDeliveries(await _validAccessToken());
  }

  Future<Map<String, dynamic>> fetchNotificationDeliveryDiagnostics() async {
    return _apiClient.getNotificationDeliveryDiagnostics(
      await _validAccessToken(),
    );
  }

  Future<Map<String, dynamic>> fetchDailyClosingReport({
    required String reportDate,
  }) async {
    return _apiClient.getDailyClosingReport(
      await _validAccessToken(),
      reportDate: reportDate,
      stationId: _currentUser?['station_id'] as int?,
      organizationId: _currentUser?['organization_id'] as int?,
    );
  }

  Future<Map<String, dynamic>> fetchStockMovementReport() async {
    return _apiClient.getStockMovementReport(
      await _validAccessToken(),
      stationId: _currentUser?['station_id'] as int?,
      organizationId: _currentUser?['organization_id'] as int?,
    );
  }

  Future<Map<String, dynamic>> fetchCustomerBalancesReport() async {
    return _apiClient.getCustomerBalancesReport(
      await _validAccessToken(),
      stationId: _currentUser?['station_id'] as int?,
      organizationId: _currentUser?['organization_id'] as int?,
    );
  }

  Future<Map<String, dynamic>> fetchSupplierBalancesReport() async {
    return _apiClient.getSupplierBalancesReport(
      await _validAccessToken(),
      stationId: _currentUser?['station_id'] as int?,
      organizationId: _currentUser?['organization_id'] as int?,
    );
  }

  Future<Map<String, dynamic>> createReportExport(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createReportExport(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchReportExports() async {
    return _apiClient.getReportExports(await _validAccessToken());
  }

  Future<List<dynamic>> fetchAttendance() async {
    return _apiClient.getAttendance(await _validAccessToken());
  }

  Future<Map<String, dynamic>> checkIn({
    required int stationId,
    String? notes,
  }) async {
    return _apiClient.checkIn(
      await _validAccessToken(),
      stationId: stationId,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> checkOut({
    required int attendanceId,
    String? notes,
  }) async {
    return _apiClient.checkOut(
      await _validAccessToken(),
      attendanceId: attendanceId,
      notes: notes,
    );
  }

  Future<Map<String, dynamic>> createAttendanceRecord(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createAttendanceRecord(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchPayrollRuns() async {
    return _apiClient.getPayrollRuns(await _validAccessToken());
  }

  Future<Map<String, dynamic>> createPayrollRun(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createPayrollRun(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> finalizePayrollRun({
    required int payrollRunId,
    String? notes,
  }) async {
    return _apiClient.finalizePayrollRun(
      await _validAccessToken(),
      payrollRunId: payrollRunId,
      notes: notes,
    );
  }

  Future<List<dynamic>> fetchPayrollLines({required int payrollRunId}) async {
    return _apiClient.getPayrollLines(
      await _validAccessToken(),
      payrollRunId: payrollRunId,
    );
  }

  Future<List<dynamic>> fetchStations() async {
    return _apiClient.getStations(await _validAccessToken());
  }

  Future<List<dynamic>> fetchUsers({int? stationId}) async {
    return _apiClient.getUsers(await _validAccessToken(), stationId: stationId);
  }

  Future<List<dynamic>> fetchNozzles({int? stationId}) async {
    return _apiClient.getNozzles(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<List<dynamic>> fetchCustomers({int? stationId}) async {
    return _apiClient.getCustomers(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<List<dynamic>> fetchFuelTypes() async {
    return _apiClient.getFuelTypes(await _validAccessToken());
  }

  Future<List<dynamic>> fetchFuelSales({int? stationId, int limit = 25}) async {
    return _apiClient.getFuelSales(
      await _validAccessToken(),
      stationId: stationId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createFuelSale(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createFuelSale(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<void> _refreshCurrentUser() async {
    final accessToken = await _validAccessToken();
    _currentUser = await _apiClient.getCurrentUser(accessToken);
    _rootInfo ??= await _apiClient.getRootInfo();
    await _persist();
  }

  Future<String> _validAccessToken() async {
    if (_tokens case {'access_token': final String accessToken}) {
      return accessToken;
    }
    if (_tokens case {'refresh_token': final String refreshToken}) {
      _tokens = await _apiClient.refresh(refreshToken);
      await _persist();
      return _tokens!['access_token'] as String;
    }
    throw ApiException(
      'Session expired. Please sign in again.',
      statusCode: 401,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode({
      'baseUrl': _apiClient.baseUrl,
      'tokens': _tokens,
    });
    await prefs.setString(_storageKey, payload);
  }
}
