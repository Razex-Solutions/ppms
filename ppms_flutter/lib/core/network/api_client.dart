import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ppms_flutter/core/network/api_exception.dart';

class ApiClient {
  ApiClient({required String baseUrl, http.Client? httpClient})
    : _baseUrl = baseUrl,
      _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String _baseUrl;

  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = value.trim().replaceAll(RegExp(r'/$'), '');
  }

  Future<Map<String, dynamic>> getRootInfo() async {
    return _send('GET', '/');
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    return _send(
      'POST',
      '/auth/login',
      body: {'username': username, 'password': password},
    );
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    return _send(
      'POST',
      '/auth/refresh',
      body: {'refresh_token': refreshToken},
    );
  }

  Future<void> logout(String accessToken) async {
    await _send('POST', '/auth/logout', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getCurrentUser(String accessToken) async {
    return _send('GET', '/auth/me', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getDashboard({
    required String accessToken,
    int? stationId,
    int? organizationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    return _send(
      'GET',
      '/dashboard/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<List<dynamic>> getNotifications(String accessToken) async {
    return _sendList('GET', '/notifications/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getNotificationSummary(
    String accessToken,
  ) async {
    return _send('GET', '/notifications/summary', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> markNotificationRead(
    String accessToken, {
    required int notificationId,
  }) async {
    return _send(
      'POST',
      '/notifications/$notificationId/read',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> markAllNotificationsRead(
    String accessToken,
  ) async {
    return _send('POST', '/notifications/read-all', accessToken: accessToken);
  }

  Future<List<dynamic>> getNotificationPreferences(String accessToken) async {
    return _sendList(
      'GET',
      '/notifications/preferences',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> updateNotificationPreference(
    String accessToken, {
    required String eventType,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/notifications/preferences/$eventType',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getNotificationDeliveries(String accessToken) async {
    return _sendList(
      'GET',
      '/notifications/deliveries',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> getNotificationDeliveryDiagnostics(
    String accessToken,
  ) async {
    return _send(
      'GET',
      '/notifications/deliveries/diagnostics',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> getDailyClosingReport(
    String accessToken, {
    required String reportDate,
    int? stationId,
    int? organizationId,
  }) async {
    final params = <String, String>{'report_date': reportDate};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    return _send(
      'GET',
      '/reports/daily-closing',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> getStockMovementReport(
    String accessToken, {
    int? stationId,
    int? organizationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    return _send(
      'GET',
      '/reports/stock-movement',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> getCustomerBalancesReport(
    String accessToken, {
    int? stationId,
    int? organizationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    return _send(
      'GET',
      '/reports/customer-balances',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> getSupplierBalancesReport(
    String accessToken, {
    int? stationId,
    int? organizationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    return _send(
      'GET',
      '/reports/supplier-balances',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createReportExport(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/report-exports/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getReportExports(String accessToken) async {
    return _sendList('GET', '/report-exports/', accessToken: accessToken);
  }

  Future<String> downloadReportExportText(
    String accessToken, {
    required int jobId,
  }) async {
    return _sendText(
      'GET',
      '/report-exports/$jobId/download',
      accessToken: accessToken,
    );
  }

  Future<List<dynamic>> getAttendance(String accessToken) async {
    return _sendList('GET', '/attendance/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> checkIn(
    String accessToken, {
    required int stationId,
    String? notes,
  }) async {
    return _send(
      'POST',
      '/attendance/check-in',
      accessToken: accessToken,
      body: {'station_id': stationId, 'notes': notes},
    );
  }

  Future<Map<String, dynamic>> checkOut(
    String accessToken, {
    required int attendanceId,
    String? notes,
  }) async {
    return _send(
      'POST',
      '/attendance/$attendanceId/check-out',
      accessToken: accessToken,
      body: {'notes': notes},
    );
  }

  Future<Map<String, dynamic>> createAttendanceRecord(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/attendance/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getExpenses(
    String accessToken, {
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return _sendList(
      'GET',
      '/expenses/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createExpense(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/expenses/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> approveExpense(
    String accessToken, {
    required int expenseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/expenses/$expenseId/approve',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<Map<String, dynamic>> rejectExpense(
    String accessToken, {
    required int expenseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/expenses/$expenseId/reject',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<List<dynamic>> getPayrollRuns(String accessToken) async {
    return _sendList('GET', '/payroll/runs', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createPayrollRun(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/payroll/runs',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> finalizePayrollRun(
    String accessToken, {
    required int payrollRunId,
    String? notes,
  }) async {
    return _send(
      'POST',
      '/payroll/runs/$payrollRunId/finalize',
      accessToken: accessToken,
      body: {'notes': notes},
    );
  }

  Future<List<dynamic>> getPayrollLines(
    String accessToken, {
    required int payrollRunId,
  }) async {
    return _sendList(
      'GET',
      '/payroll/runs/$payrollRunId/lines',
      accessToken: accessToken,
    );
  }

  Future<List<dynamic>> getStations(String accessToken) async {
    return _sendList('GET', '/stations/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createStation(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/stations/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> updateStation(
    String accessToken, {
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/stations/$stationId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteStation(
    String accessToken, {
    required int stationId,
  }) async {
    return _send('DELETE', '/stations/$stationId', accessToken: accessToken);
  }

  Future<List<dynamic>> getOrganizations(String accessToken) async {
    return _sendList('GET', '/organizations/', accessToken: accessToken);
  }

  Future<List<dynamic>> getBrands(String accessToken) async {
    return _sendList('GET', '/brands/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createOrganization(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/organizations/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getRoles(String accessToken) async {
    return _sendList('GET', '/roles/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createRole(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/roles/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> updateRole(
    String accessToken, {
    required int roleId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/roles/$roleId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteRole(
    String accessToken, {
    required int roleId,
  }) async {
    return _send('DELETE', '/roles/$roleId', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getPermissionCatalog(String accessToken) async {
    return _send('GET', '/roles/permission-catalog', accessToken: accessToken);
  }

  Future<List<dynamic>> getUsers(String accessToken, {int? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/users/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createUser(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/users/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> updateUser(
    String accessToken, {
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/users/$userId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteUser(
    String accessToken, {
    required int userId,
  }) async {
    return _send('DELETE', '/users/$userId', accessToken: accessToken);
  }

  Future<List<dynamic>> getEmployeeProfiles(
    String accessToken, {
    int? stationId,
    int? organizationId,
    String? staffType,
    bool? isActive,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (organizationId != null) {
      params['organization_id'] = '$organizationId';
    }
    if (staffType != null && staffType.isNotEmpty) {
      params['staff_type'] = staffType;
    }
    if (isActive != null) {
      params['is_active'] = '$isActive';
    }
    return _sendList(
      'GET',
      '/employee-profiles/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createEmployeeProfile(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/employee-profiles/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateEmployeeProfile(
    String accessToken, {
    required int profileId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/employee-profiles/$profileId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteEmployeeProfile(
    String accessToken, {
    required int profileId,
  }) async {
    return _send(
      'DELETE',
      '/employee-profiles/$profileId',
      accessToken: accessToken,
    );
  }

  Future<List<dynamic>> getStationModules(
    String accessToken, {
    required int stationId,
  }) async {
    return _sendList(
      'GET',
      '/station-modules/$stationId',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> updateStationModule(
    String accessToken, {
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/station-modules/$stationId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getNozzles(String accessToken, {int? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/nozzles/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createNozzle(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/nozzles/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> updateNozzle(
    String accessToken, {
    required int nozzleId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/nozzles/$nozzleId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteNozzle(
    String accessToken, {
    required int nozzleId,
  }) async {
    return _send('DELETE', '/nozzles/$nozzleId', accessToken: accessToken);
  }

  Future<List<dynamic>> getCustomers(
    String accessToken, {
    int? stationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/customers/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createCustomer(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/customers/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateCustomer(
    String accessToken, {
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/customers/$customerId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteCustomer(
    String accessToken, {
    required int customerId,
  }) async {
    return _send('DELETE', '/customers/$customerId', accessToken: accessToken);
  }

  Future<List<dynamic>> getNozzleAdjustments(
    String accessToken, {
    required int nozzleId,
    int limit = 50,
  }) async {
    return _sendList(
      'GET',
      '/nozzles/$nozzleId/adjustments',
      accessToken: accessToken,
      queryParams: {'limit': '$limit'},
    );
  }

  Future<Map<String, dynamic>> adjustNozzleMeter(
    String accessToken, {
    required int nozzleId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/nozzles/$nozzleId/adjust-meter',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> approveCustomerCreditOverride(
    String accessToken, {
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/customers/$customerId/approve-credit-override',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> rejectCustomerCreditOverride(
    String accessToken, {
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/customers/$customerId/reject-credit-override',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getSuppliers(String accessToken) async {
    return _sendList('GET', '/suppliers/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createSupplier(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/suppliers/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateSupplier(
    String accessToken, {
    required int supplierId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/suppliers/$supplierId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteSupplier(
    String accessToken, {
    required int supplierId,
  }) async {
    return _send('DELETE', '/suppliers/$supplierId', accessToken: accessToken);
  }

  Future<List<dynamic>> getTanks(String accessToken, {int? stationId}) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/tanks/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createTank(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/tanks/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> updateTank(
    String accessToken, {
    required int tankId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/tanks/$tankId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteTank(
    String accessToken, {
    required int tankId,
  }) async {
    return _send('DELETE', '/tanks/$tankId', accessToken: accessToken);
  }

  Future<List<dynamic>> getDispensers(
    String accessToken, {
    int? stationId,
  }) async {
    final params = <String, String>{};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/dispensers/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createDispenser(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/dispensers/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateDispenser(
    String accessToken, {
    required int dispenserId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/dispensers/$dispenserId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteDispenser(
    String accessToken, {
    required int dispenserId,
  }) async {
    return _send(
      'DELETE',
      '/dispensers/$dispenserId',
      accessToken: accessToken,
    );
  }

  Future<List<dynamic>> getHardwareDevices(
    String accessToken, {
    int? stationId,
    String? deviceType,
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (deviceType != null && deviceType.isNotEmpty) {
      params['device_type'] = deviceType;
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return _sendList(
      'GET',
      '/hardware/devices',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createHardwareDevice(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/hardware/devices',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getTankers(
    String accessToken, {
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return _sendList(
      'GET',
      '/tankers/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createTanker(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/tankers/', accessToken: accessToken, body: payload);
  }

  Future<List<dynamic>> getTankerTrips(
    String accessToken, {
    int? stationId,
    String? tripType,
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (tripType != null && tripType.isNotEmpty) {
      params['trip_type'] = tripType;
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return _sendList(
      'GET',
      '/tankers/trips',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createTankerTrip(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/tankers/trips',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> addTankerTripDelivery(
    String accessToken, {
    required int tripId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/tankers/trips/$tripId/deliveries',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> addTankerTripExpense(
    String accessToken, {
    required int tripId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/tankers/trips/$tripId/expenses',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> completeTankerTrip(
    String accessToken, {
    required int tripId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/tankers/trips/$tripId/complete',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<List<dynamic>> getHardwareEvents(
    String accessToken, {
    int? stationId,
    int? deviceId,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (deviceId != null) {
      params['device_id'] = '$deviceId';
    }
    return _sendList(
      'GET',
      '/hardware/events',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> pollHardwareDevice(
    String accessToken, {
    required int deviceId,
  }) async {
    return _send(
      'POST',
      '/hardware/devices/$deviceId/vendor-poll',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> simulateDispenserReading(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/hardware/simulate/dispenser-reading',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> simulateTankProbeReading(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/hardware/simulate/tank-probe-reading',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getPurchases(
    String accessToken, {
    int? stationId,
    int limit = 25,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/purchases/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createPurchase(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/purchases/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> reversePurchase(
    String accessToken, {
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/purchases/$purchaseId/reverse',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<Map<String, dynamic>> approvePurchase(
    String accessToken, {
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/purchases/$purchaseId/approve',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<Map<String, dynamic>> rejectPurchase(
    String accessToken, {
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/purchases/$purchaseId/reject',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<Map<String, dynamic>> approvePurchaseReversal(
    String accessToken, {
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/purchases/$purchaseId/approve-reversal',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<Map<String, dynamic>> rejectPurchaseReversal(
    String accessToken, {
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/purchases/$purchaseId/reject-reversal',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<List<dynamic>> getCustomerPayments(
    String accessToken, {
    int? stationId,
    int limit = 25,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/customer-payments/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createCustomerPayment(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/customer-payments/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> reverseCustomerPayment(
    String accessToken, {
    required int paymentId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/customer-payments/$paymentId/reverse',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<List<dynamic>> getSupplierPayments(
    String accessToken, {
    int? stationId,
    int limit = 25,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/supplier-payments/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createSupplierPayment(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/supplier-payments/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> reverseSupplierPayment(
    String accessToken, {
    required int paymentId,
    Map<String, dynamic>? payload,
  }) async {
    return _send(
      'POST',
      '/supplier-payments/$paymentId/reverse',
      accessToken: accessToken,
      body: payload ?? const {},
    );
  }

  Future<List<dynamic>> getFuelTypes(String accessToken) async {
    return _sendList('GET', '/fuel-types/', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> createFuelType(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/fuel-types/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> updateFuelType(
    String accessToken, {
    required int fuelTypeId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/fuel-types/$fuelTypeId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> deleteFuelType(
    String accessToken, {
    required int fuelTypeId,
  }) async {
    return _send('DELETE', '/fuel-types/$fuelTypeId', accessToken: accessToken);
  }

  Future<Map<String, dynamic>> getInvoiceProfile(
    String accessToken, {
    required int stationId,
  }) async {
    return _send(
      'GET',
      '/invoice-profiles/$stationId',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> updateInvoiceProfile(
    String accessToken, {
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'PUT',
      '/invoice-profiles/$stationId',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> getCompliancePresets(String accessToken) async {
    return _send(
      'GET',
      '/invoice-profiles/compliance-presets',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> applyCompliancePreset(
    String accessToken, {
    required int stationId,
    required String presetCode,
  }) async {
    return _send(
      'POST',
      '/invoice-profiles/$stationId/apply-preset',
      accessToken: accessToken,
      queryParams: {'preset_code': presetCode},
    );
  }

  Future<List<dynamic>> getFuelSales(
    String accessToken, {
    int? stationId,
    int limit = 25,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    return _sendList(
      'GET',
      '/fuel-sales/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createFuelSale(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/fuel-sales/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getShifts(
    String accessToken, {
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return _sendList(
      'GET',
      '/shifts/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> openShift(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send('POST', '/shifts/', accessToken: accessToken, body: payload);
  }

  Future<Map<String, dynamic>> closeShift(
    String accessToken, {
    required int shiftId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/shifts/$shiftId/close',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getPosProducts(
    String accessToken, {
    int? stationId,
    String? module,
    bool? isActive,
    int limit = 100,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (module != null && module.isNotEmpty) {
      params['module'] = module;
    }
    if (isActive != null) {
      params['is_active'] = '$isActive';
    }
    return _sendList(
      'GET',
      '/pos-products/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<List<dynamic>> getPosSales(
    String accessToken, {
    int? stationId,
    String? module,
    int limit = 50,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (stationId != null) {
      params['station_id'] = '$stationId';
    }
    if (module != null && module.isNotEmpty) {
      params['module'] = module;
    }
    return _sendList(
      'GET',
      '/pos-sales/',
      accessToken: accessToken,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> createPosSale(
    String accessToken, {
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/pos-sales/',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> reversePosSale(
    String accessToken, {
    required int saleId,
  }) async {
    return _send(
      'POST',
      '/pos-sales/$saleId/reverse',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> getFuelSaleDocument(
    String accessToken, {
    required int saleId,
  }) async {
    return _send(
      'GET',
      '/financial-documents/fuel-sales/$saleId',
      accessToken: accessToken,
    );
  }

  Future<List<int>> downloadFuelSalePdf(
    String accessToken, {
    required int saleId,
  }) async {
    return _sendBytes(
      'GET',
      '/financial-documents/fuel-sales/$saleId/pdf',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendFuelSaleDocument(
    String accessToken, {
    required int saleId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/financial-documents/fuel-sales/$saleId/send',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> getCustomerPaymentDocument(
    String accessToken, {
    required int paymentId,
  }) async {
    return _send(
      'GET',
      '/financial-documents/customer-payments/$paymentId',
      accessToken: accessToken,
    );
  }

  Future<List<int>> downloadCustomerPaymentPdf(
    String accessToken, {
    required int paymentId,
  }) async {
    return _sendBytes(
      'GET',
      '/financial-documents/customer-payments/$paymentId/pdf',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendCustomerPaymentDocument(
    String accessToken, {
    required int paymentId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/financial-documents/customer-payments/$paymentId/send',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<Map<String, dynamic>> getSupplierPaymentDocument(
    String accessToken, {
    required int paymentId,
  }) async {
    return _send(
      'GET',
      '/financial-documents/supplier-payments/$paymentId',
      accessToken: accessToken,
    );
  }

  Future<List<int>> downloadSupplierPaymentPdf(
    String accessToken, {
    required int paymentId,
  }) async {
    return _sendBytes(
      'GET',
      '/financial-documents/supplier-payments/$paymentId/pdf',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> sendSupplierPaymentDocument(
    String accessToken, {
    required int paymentId,
    required Map<String, dynamic> payload,
  }) async {
    return _send(
      'POST',
      '/financial-documents/supplier-payments/$paymentId/send',
      accessToken: accessToken,
      body: payload,
    );
  }

  Future<List<dynamic>> getFinancialDocumentDispatches(
    String accessToken,
  ) async {
    return _sendList(
      'GET',
      '/financial-documents/dispatches',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? accessToken,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _httpClient.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        case 'PUT':
          response = await _httpClient.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        case 'DELETE':
          response = await _httpClient.delete(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported request method: $method');
      }
    } on http.ClientException catch (error) {
      throw ApiException('Unable to reach PPMS backend: $error');
    }

    return _decodeMap(response);
  }

  Future<List<dynamic>> _sendList(
    String method,
    String path, {
    String? accessToken,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported request method: $method');
      }
    } on http.ClientException catch (error) {
      throw ApiException('Unable to reach PPMS backend: $error');
    }

    return _decodeList(response);
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = response.body.isEmpty
        ? <dynamic>[]
        : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(
        _extractMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return List<dynamic>.from(decoded as List);
  }

  Future<String> _sendText(
    String method,
    String path, {
    String? accessToken,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported request method: $method');
      }
    } on http.ClientException catch (error) {
      throw ApiException('Unable to reach PPMS backend: $error');
    }

    if (response.statusCode >= 400) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = <String, dynamic>{'detail': response.body};
      }
      throw ApiException(
        _extractMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return response.body;
  }

  Future<List<int>> _sendBytes(
    String method,
    String path, {
    String? accessToken,
    Map<String, String>? queryParams,
  }) async {
    final uri = Uri.parse(
      '$_baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _httpClient.get(uri, headers: headers);
          break;
        default:
          throw ApiException('Unsupported request method: $method');
      }
    } on http.ClientException catch (error) {
      throw ApiException('Unable to reach PPMS backend: $error');
    }

    if (response.statusCode >= 400) {
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = <String, dynamic>{'detail': response.body};
      }
      throw ApiException(
        _extractMessage(decoded),
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  String _extractMessage(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) {
        return detail;
      }
      if (detail is List) {
        return detail
            .map(
              (item) =>
                  item is Map<String, dynamic> ? item['msg'] : item.toString(),
            )
            .join('; ');
      }
    }
    return 'Request failed';
  }
}
