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

  Future<List<dynamic>> getSuppliers(String accessToken) async {
    return _sendList('GET', '/suppliers/', accessToken: accessToken);
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

  Future<List<dynamic>> getFuelTypes(String accessToken) async {
    return _sendList('GET', '/fuel-types/', accessToken: accessToken);
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
