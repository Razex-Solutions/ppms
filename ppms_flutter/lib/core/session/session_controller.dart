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
  String get baseUrl => _apiClient.baseUrl;
  String get roleName => _currentUser?['role_name'] as String? ?? 'Unknown';
  String get scopeLevel => _currentUser?['scope_level'] as String? ?? 'station';
  bool get isPlatformUser => _currentUser?['is_platform_user'] == true;
  bool get isMasterAdmin => roleName == 'MasterAdmin' || isPlatformUser;
  int? get stationId => _currentUser?['station_id'] as int?;
  int? get organizationId => _currentUser?['organization_id'] as int?;
  Map<String, dynamic> get permissions =>
      _currentUser?['permissions'] as Map<String, dynamic>? ?? const {};
  List<String> get enabledModules =>
      List<String>.from(_rootInfo?['enabled_modules'] ?? const []);
  List<String> get creatableRoles =>
      List<String>.from(_currentUser?['creatable_roles'] ?? const []);
  Map<String, dynamic> get roleScopeRule =>
      _currentUser?['role_scope_rule'] as Map<String, dynamic>? ?? const {};

  bool canAccessModule(String module) =>
      enabledModules.contains(module) || permissions.containsKey(module);

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

  Future<void> updateBaseUrl(String baseUrl) async {
    _apiClient.baseUrl = baseUrl;
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

  Future<String> downloadReportExportText({required int jobId}) async {
    return _apiClient.downloadReportExportText(
      await _validAccessToken(),
      jobId: jobId,
    );
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

  Future<List<dynamic>> fetchExpenses({
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    return _apiClient.getExpenses(
      await _validAccessToken(),
      stationId: stationId,
      status: status,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createExpense(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createExpense(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> approveExpense({
    required int expenseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.approveExpense(
      await _validAccessToken(),
      expenseId: expenseId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> rejectExpense({
    required int expenseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.rejectExpense(
      await _validAccessToken(),
      expenseId: expenseId,
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

  Future<Map<String, dynamic>> createStation(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createStation(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateStation({
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateStation(
      await _validAccessToken(),
      stationId: stationId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> fetchStationSetupFoundation({
    required int stationId,
  }) async {
    return _apiClient.getStationSetupFoundation(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> deleteStation({required int stationId}) async {
    return _apiClient.deleteStation(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<List<dynamic>> fetchOrganizations() async {
    return _apiClient.getOrganizations(await _validAccessToken());
  }

  Future<List<dynamic>> fetchBrands() async {
    return _apiClient.getBrands(await _validAccessToken());
  }

  Future<Map<String, dynamic>> createOrganization(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createOrganization(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> fetchOrganizationSetupFoundation({
    required int organizationId,
  }) async {
    return _apiClient.getOrganizationSetupFoundation(
      await _validAccessToken(),
      organizationId: organizationId,
    );
  }

  Future<List<dynamic>> fetchRoles() async {
    return _apiClient.getRoles(await _validAccessToken());
  }

  Future<Map<String, dynamic>> createRole(Map<String, dynamic> payload) async {
    return _apiClient.createRole(await _validAccessToken(), payload: payload);
  }

  Future<Map<String, dynamic>> updateRole({
    required int roleId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateRole(
      await _validAccessToken(),
      roleId: roleId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteRole({required int roleId}) async {
    return _apiClient.deleteRole(await _validAccessToken(), roleId: roleId);
  }

  Future<Map<String, dynamic>> fetchPermissionCatalog() async {
    return _apiClient.getPermissionCatalog(await _validAccessToken());
  }

  Future<List<dynamic>> fetchUsers({int? stationId}) async {
    return _apiClient.getUsers(await _validAccessToken(), stationId: stationId);
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    return _apiClient.createUser(await _validAccessToken(), payload: payload);
  }

  Future<Map<String, dynamic>> updateUser({
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateUser(
      await _validAccessToken(),
      userId: userId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteUser({required int userId}) async {
    return _apiClient.deleteUser(await _validAccessToken(), userId: userId);
  }

  Future<List<dynamic>> fetchEmployeeProfiles({
    int? stationId,
    int? organizationId,
    String? staffType,
    bool? isActive,
  }) async {
    return _apiClient.getEmployeeProfiles(
      await _validAccessToken(),
      stationId: stationId,
      organizationId: organizationId,
      staffType: staffType,
      isActive: isActive,
    );
  }

  Future<Map<String, dynamic>> createEmployeeProfile(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createEmployeeProfile(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateEmployeeProfile({
    required int profileId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateEmployeeProfile(
      await _validAccessToken(),
      profileId: profileId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteEmployeeProfile({
    required int profileId,
  }) async {
    return _apiClient.deleteEmployeeProfile(
      await _validAccessToken(),
      profileId: profileId,
    );
  }

  Future<List<dynamic>> fetchStationModules({required int stationId}) async {
    return _apiClient.getStationModules(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> updateStationModule({
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateStationModule(
      await _validAccessToken(),
      stationId: stationId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchNozzles({int? stationId}) async {
    return _apiClient.getNozzles(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> createNozzle(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createNozzle(await _validAccessToken(), payload: payload);
  }

  Future<Map<String, dynamic>> updateNozzle({
    required int nozzleId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateNozzle(
      await _validAccessToken(),
      nozzleId: nozzleId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteNozzle({required int nozzleId}) async {
    return _apiClient.deleteNozzle(
      await _validAccessToken(),
      nozzleId: nozzleId,
    );
  }

  Future<List<dynamic>> fetchNozzleAdjustments({
    required int nozzleId,
    int limit = 50,
  }) async {
    return _apiClient.getNozzleAdjustments(
      await _validAccessToken(),
      nozzleId: nozzleId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> adjustNozzleMeter({
    required int nozzleId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.adjustNozzleMeter(
      await _validAccessToken(),
      nozzleId: nozzleId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchCustomers({int? stationId}) async {
    return _apiClient.getCustomers(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> createCustomer(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createCustomer(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateCustomer({
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateCustomer(
      await _validAccessToken(),
      customerId: customerId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteCustomer({required int customerId}) async {
    return _apiClient.deleteCustomer(
      await _validAccessToken(),
      customerId: customerId,
    );
  }

  Future<Map<String, dynamic>> approveCustomerCreditOverride({
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.approveCustomerCreditOverride(
      await _validAccessToken(),
      customerId: customerId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> rejectCustomerCreditOverride({
    required int customerId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.rejectCustomerCreditOverride(
      await _validAccessToken(),
      customerId: customerId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchSuppliers() async {
    return _apiClient.getSuppliers(await _validAccessToken());
  }

  Future<Map<String, dynamic>> createSupplier(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createSupplier(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateSupplier({
    required int supplierId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateSupplier(
      await _validAccessToken(),
      supplierId: supplierId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteSupplier({required int supplierId}) async {
    return _apiClient.deleteSupplier(
      await _validAccessToken(),
      supplierId: supplierId,
    );
  }

  Future<List<dynamic>> fetchTanks({int? stationId}) async {
    return _apiClient.getTanks(await _validAccessToken(), stationId: stationId);
  }

  Future<Map<String, dynamic>> createTank(Map<String, dynamic> payload) async {
    return _apiClient.createTank(await _validAccessToken(), payload: payload);
  }

  Future<Map<String, dynamic>> updateTank({
    required int tankId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateTank(
      await _validAccessToken(),
      tankId: tankId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteTank({required int tankId}) async {
    return _apiClient.deleteTank(await _validAccessToken(), tankId: tankId);
  }

  Future<List<dynamic>> fetchDispensers({int? stationId}) async {
    return _apiClient.getDispensers(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> createDispenser(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createDispenser(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateDispenser({
    required int dispenserId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateDispenser(
      await _validAccessToken(),
      dispenserId: dispenserId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteDispenser({
    required int dispenserId,
  }) async {
    return _apiClient.deleteDispenser(
      await _validAccessToken(),
      dispenserId: dispenserId,
    );
  }

  Future<List<dynamic>> fetchHardwareDevices({
    int? stationId,
    String? deviceType,
    String? status,
    int limit = 50,
  }) async {
    return _apiClient.getHardwareDevices(
      await _validAccessToken(),
      stationId: stationId,
      deviceType: deviceType,
      status: status,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createHardwareDevice(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createHardwareDevice(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchTankers({
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    return _apiClient.getTankers(
      await _validAccessToken(),
      stationId: stationId,
      status: status,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createTanker(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createTanker(await _validAccessToken(), payload: payload);
  }

  Future<List<dynamic>> fetchTankerTrips({
    int? stationId,
    String? tripType,
    String? status,
    int limit = 50,
  }) async {
    return _apiClient.getTankerTrips(
      await _validAccessToken(),
      stationId: stationId,
      tripType: tripType,
      status: status,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createTankerTrip(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createTankerTrip(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> addTankerTripDelivery({
    required int tripId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.addTankerTripDelivery(
      await _validAccessToken(),
      tripId: tripId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> addTankerTripExpense({
    required int tripId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.addTankerTripExpense(
      await _validAccessToken(),
      tripId: tripId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> completeTankerTrip({
    required int tripId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.completeTankerTrip(
      await _validAccessToken(),
      tripId: tripId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchHardwareEvents({
    int? stationId,
    int? deviceId,
    int limit = 50,
  }) async {
    return _apiClient.getHardwareEvents(
      await _validAccessToken(),
      stationId: stationId,
      deviceId: deviceId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> pollHardwareDevice({
    required int deviceId,
  }) async {
    return _apiClient.pollHardwareDevice(
      await _validAccessToken(),
      deviceId: deviceId,
    );
  }

  Future<Map<String, dynamic>> simulateDispenserReading(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.simulateDispenserReading(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> simulateTankProbeReading(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.simulateTankProbeReading(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchPurchases({int? stationId, int limit = 25}) async {
    return _apiClient.getPurchases(
      await _validAccessToken(),
      stationId: stationId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createPurchase(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createPurchase(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> reversePurchase({
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.reversePurchase(
      await _validAccessToken(),
      purchaseId: purchaseId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> approvePurchase({
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.approvePurchase(
      await _validAccessToken(),
      purchaseId: purchaseId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> rejectPurchase({
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.rejectPurchase(
      await _validAccessToken(),
      purchaseId: purchaseId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> approvePurchaseReversal({
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.approvePurchaseReversal(
      await _validAccessToken(),
      purchaseId: purchaseId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> rejectPurchaseReversal({
    required int purchaseId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.rejectPurchaseReversal(
      await _validAccessToken(),
      purchaseId: purchaseId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchCustomerPayments({
    int? stationId,
    int limit = 25,
  }) async {
    return _apiClient.getCustomerPayments(
      await _validAccessToken(),
      stationId: stationId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createCustomerPayment(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createCustomerPayment(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> reverseCustomerPayment({
    required int paymentId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.reverseCustomerPayment(
      await _validAccessToken(),
      paymentId: paymentId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchSupplierPayments({
    int? stationId,
    int limit = 25,
  }) async {
    return _apiClient.getSupplierPayments(
      await _validAccessToken(),
      stationId: stationId,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createSupplierPayment(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createSupplierPayment(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> reverseSupplierPayment({
    required int paymentId,
    Map<String, dynamic>? payload,
  }) async {
    return _apiClient.reverseSupplierPayment(
      await _validAccessToken(),
      paymentId: paymentId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchFuelTypes() async {
    return _apiClient.getFuelTypes(await _validAccessToken());
  }

  Future<Map<String, dynamic>> createFuelType(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createFuelType(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> updateFuelType({
    required int fuelTypeId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateFuelType(
      await _validAccessToken(),
      fuelTypeId: fuelTypeId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> deleteFuelType({required int fuelTypeId}) async {
    return _apiClient.deleteFuelType(
      await _validAccessToken(),
      fuelTypeId: fuelTypeId,
    );
  }

  Future<Map<String, dynamic>> fetchInvoiceProfile({
    required int stationId,
  }) async {
    return _apiClient.getInvoiceProfile(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> updateInvoiceProfile({
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.updateInvoiceProfile(
      await _validAccessToken(),
      stationId: stationId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchCompliancePresets() async {
    final response = await _apiClient.getCompliancePresets(
      await _validAccessToken(),
    );
    return List<dynamic>.from(response['items'] as List? ?? const []);
  }

  Future<Map<String, dynamic>> applyCompliancePreset({
    required int stationId,
    required String presetCode,
  }) async {
    return _apiClient.applyCompliancePreset(
      await _validAccessToken(),
      stationId: stationId,
      presetCode: presetCode,
    );
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

  Future<List<dynamic>> fetchShifts({
    int? stationId,
    String? status,
    int limit = 50,
  }) async {
    return _apiClient.getShifts(
      await _validAccessToken(),
      stationId: stationId,
      status: status,
      limit: limit,
    );
  }

  Future<List<dynamic>> fetchStationShiftTemplates({
    required int stationId,
  }) async {
    return _apiClient.getStationShiftTemplates(
      await _validAccessToken(),
      stationId: stationId,
    );
  }

  Future<Map<String, dynamic>> openShift(Map<String, dynamic> payload) async {
    return _apiClient.openShift(await _validAccessToken(), payload: payload);
  }

  Future<Map<String, dynamic>> closeShift({
    required int shiftId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.closeShift(
      await _validAccessToken(),
      shiftId: shiftId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> fetchShiftCash({required int shiftId}) async {
    return _apiClient.getShiftCash(await _validAccessToken(), shiftId: shiftId);
  }

  Future<List<dynamic>> fetchShiftCashSubmissions({
    required int shiftId,
  }) async {
    return _apiClient.getShiftCashSubmissions(
      await _validAccessToken(),
      shiftId: shiftId,
    );
  }

  Future<Map<String, dynamic>> createShiftCashSubmission({
    required int shiftId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.createShiftCashSubmission(
      await _validAccessToken(),
      shiftId: shiftId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchPosProducts({
    int? stationId,
    String? module,
    bool? isActive,
    int limit = 100,
  }) async {
    return _apiClient.getPosProducts(
      await _validAccessToken(),
      stationId: stationId,
      module: module,
      isActive: isActive,
      limit: limit,
    );
  }

  Future<List<dynamic>> fetchPosSales({
    int? stationId,
    String? module,
    int limit = 50,
  }) async {
    return _apiClient.getPosSales(
      await _validAccessToken(),
      stationId: stationId,
      module: module,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>> createPosSale(
    Map<String, dynamic> payload,
  ) async {
    return _apiClient.createPosSale(
      await _validAccessToken(),
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> reversePosSale({required int saleId}) async {
    return _apiClient.reversePosSale(await _validAccessToken(), saleId: saleId);
  }

  Future<Map<String, dynamic>> fetchFuelSaleDocument({
    required int saleId,
  }) async {
    return _apiClient.getFuelSaleDocument(
      await _validAccessToken(),
      saleId: saleId,
    );
  }

  Future<List<int>> downloadFuelSalePdf({required int saleId}) async {
    return _apiClient.downloadFuelSalePdf(
      await _validAccessToken(),
      saleId: saleId,
    );
  }

  Future<Map<String, dynamic>> sendFuelSaleDocument({
    required int saleId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.sendFuelSaleDocument(
      await _validAccessToken(),
      saleId: saleId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> fetchCustomerPaymentDocument({
    required int paymentId,
  }) async {
    return _apiClient.getCustomerPaymentDocument(
      await _validAccessToken(),
      paymentId: paymentId,
    );
  }

  Future<List<int>> downloadCustomerPaymentPdf({required int paymentId}) async {
    return _apiClient.downloadCustomerPaymentPdf(
      await _validAccessToken(),
      paymentId: paymentId,
    );
  }

  Future<Map<String, dynamic>> sendCustomerPaymentDocument({
    required int paymentId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.sendCustomerPaymentDocument(
      await _validAccessToken(),
      paymentId: paymentId,
      payload: payload,
    );
  }

  Future<Map<String, dynamic>> fetchSupplierPaymentDocument({
    required int paymentId,
  }) async {
    return _apiClient.getSupplierPaymentDocument(
      await _validAccessToken(),
      paymentId: paymentId,
    );
  }

  Future<List<int>> downloadSupplierPaymentPdf({required int paymentId}) async {
    return _apiClient.downloadSupplierPaymentPdf(
      await _validAccessToken(),
      paymentId: paymentId,
    );
  }

  Future<Map<String, dynamic>> sendSupplierPaymentDocument({
    required int paymentId,
    required Map<String, dynamic> payload,
  }) async {
    return _apiClient.sendSupplierPaymentDocument(
      await _validAccessToken(),
      paymentId: paymentId,
      payload: payload,
    );
  }

  Future<List<dynamic>> fetchFinancialDocumentDispatches() async {
    return _apiClient.getFinancialDocumentDispatches(await _validAccessToken());
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
