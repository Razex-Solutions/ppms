import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';

import '../../app/session/session_controller.dart';

class StationAdminRepository {
  const StationAdminRepository(this._dio);

  final Dio _dio;

  Map<String, dynamic> _query(Map<String, dynamic> values) {
    final result = <String, dynamic>{};
    values.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  Future<Map<String, dynamic>> getDashboard({
    required int stationId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/dashboard/',
      queryParameters: _query({
        'station_id': stationId,
        'from_date': fromDate?.toIso8601String().split('T').first,
        'to_date': toDate?.toIso8601String().split('T').first,
      }),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getStation(int stationId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/stations/$stationId');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateStation(
    int stationId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/stations/$stationId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listStationModules(int stationId) async {
    final response =
        await _dio.get<List<dynamic>>('/station-modules/$stationId');
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> updateStationModule(
    int stationId, {
    required String moduleName,
    required bool isEnabled,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/station-modules/$stationId',
      data: {'module_name': moduleName, 'is_enabled': isEnabled},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listRoles() async {
    final response = await _dio.get<List<dynamic>>(
      '/roles/',
      queryParameters: {'limit': 200},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listUsers({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/users/',
      queryParameters: {
        'station_id': stationId,
        'limit': 200,
      },
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listCustomers({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/customers/',
      queryParameters: {
        'station_id': stationId,
        'limit': 200,
      },
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/users/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateUser(
    int userId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/users/$userId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('/users/$userId');
  }

  Future<List<Map<String, dynamic>>> listEmployeeProfiles({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/employee-profiles/',
      queryParameters: {
        'station_id': stationId,
        'limit': 200,
      },
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createEmployeeProfile(
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/employee-profiles/',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateEmployeeProfile(
    int profileId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/employee-profiles/$profileId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteEmployeeProfile(int profileId) async {
    await _dio.delete('/employee-profiles/$profileId');
  }

  Future<List<Map<String, dynamic>>> listFuelTypes() async {
    final response = await _dio.get<List<dynamic>>(
      '/fuel-types/',
      queryParameters: {'limit': 200},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createFuelType(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/fuel-types/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateFuelType(
    int fuelTypeId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/fuel-types/$fuelTypeId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listFuelPriceHistory({
    required int stationId,
    required int fuelTypeId,
    int limit = 20,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/fuel-types/$fuelTypeId/price-history',
      queryParameters: {
        'station_id': stationId,
        'limit': limit,
      },
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createFuelPriceHistory({
    required int stationId,
    required int fuelTypeId,
    required double price,
    required String reason,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/fuel-types/$fuelTypeId/price-history',
      data: {
        'station_id': stationId,
        'price': price,
        'reason': reason,
        'notes': notes,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listTanks({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/tanks/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createTank(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/tanks/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateTank(
    int tankId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/tanks/$tankId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteTank(int tankId) async {
    await _dio.delete('/tanks/$tankId');
  }

  Future<List<Map<String, dynamic>>> listDispensers({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/dispensers/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createDispenser(
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/dispensers/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateDispenser(
    int dispenserId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/dispensers/$dispenserId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteDispenser(int dispenserId) async {
    await _dio.delete('/dispensers/$dispenserId');
  }

  Future<List<Map<String, dynamic>>> listNozzles({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/nozzles/',
      queryParameters: {'station_id': stationId, 'limit': 300},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createNozzle(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/nozzles/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateNozzle(
    int nozzleId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/nozzles/$nozzleId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteNozzle(int nozzleId) async {
    await _dio.delete('/nozzles/$nozzleId');
  }

  Future<List<Map<String, dynamic>>> listNozzleAdjustments(int nozzleId) async {
    final response = await _dio.get<List<dynamic>>(
      '/nozzles/$nozzleId/adjustments',
      queryParameters: {'limit': 50},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> adjustNozzleMeter(
    int nozzleId, {
    required double oldReading,
    required double newReading,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/nozzles/$nozzleId/adjust-meter',
      data: {
        'old_reading': oldReading,
        'new_reading': newReading,
        'reason': reason,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getInvoiceProfile(int stationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/invoice-profiles/$stationId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateInvoiceProfile(
    int stationId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/invoice-profiles/$stationId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listDocumentTemplates(int stationId) async {
    final response = await _dio.get<List<dynamic>>(
      '/document-templates/$stationId',
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> upsertDocumentTemplate(
    int stationId,
    String documentType,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/document-templates/$stationId/$documentType',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> seedDocumentTemplates(int stationId) async {
    final response = await _dio.post<List<dynamic>>(
      '/document-templates/$stationId/seed-defaults',
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getTankerSummary({required int stationId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/tankers/summary',
      queryParameters: {'station_id': stationId},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listTankers({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/tankers/',
      queryParameters: {'station_id': stationId, 'limit': 100},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listTankerTrips({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/tankers/trips',
      queryParameters: {'station_id': stationId, 'limit': 100},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createTanker(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/tankers/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createTankerTrip(
    Map<String, dynamic> payload,
  ) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/tankers/trips', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addTankerTripDelivery(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/tankers/trips/$tripId/deliveries',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addTankerTripPayment(
    int tripId,
    int deliveryId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/tankers/trips/$tripId/deliveries/$deliveryId/payments',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> addTankerTripExpense(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/tankers/trips/$tripId/expenses',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> completeTankerTrip(
    int tripId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/tankers/trips/$tripId/complete',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listSuppliers() async {
    final response = await _dio.get<List<dynamic>>(
      '/suppliers/',
      queryParameters: {'limit': 200},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/suppliers/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updateSupplier(
    int supplierId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/suppliers/$supplierId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deleteSupplier(int supplierId) async {
    await _dio.delete('/suppliers/$supplierId');
  }

  Future<List<Map<String, dynamic>>> listPurchases({
    required int stationId,
    int limit = 100,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/purchases/',
      queryParameters: {'station_id': stationId, 'limit': limit},
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> listPosProducts({
    required int stationId,
    String? module,
    bool? isActive,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/pos-products/',
      queryParameters: _query({
        'station_id': stationId,
        'module': module,
        'is_active': isActive,
        'limit': 200,
      }),
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createPosProduct(Map<String, dynamic> payload) async {
    final response =
        await _dio.post<Map<String, dynamic>>('/pos-products/', data: payload);
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> updatePosProduct(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/pos-products/$productId',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> deletePosProduct(int productId) async {
    await _dio.delete('/pos-products/$productId');
  }

  Future<Map<String, dynamic>> getReportCatalog() async {
    final response = await _dio.get<Map<String, dynamic>>('/reports/catalog');
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> runReport({
    required String reportKey,
    required int stationId,
    DateTime? reportDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final endpoint = switch (reportKey) {
      'daily_closing' => '/reports/daily-closing',
      'shift_variance' => '/reports/shift-variance',
      'stock_movement' => '/reports/stock-movement',
      'customer_balances' => '/reports/customer-balances',
      'supplier_balances' => '/reports/supplier-balances',
      'staff_payroll_summary' => '/reports/staff-payroll-summary',
      'exception_variance' => '/reports/exception-variance',
      'tanker_profit' => '/reports/tanker-profit',
      'tanker_deliveries' => '/reports/tanker-deliveries',
      'tanker_expenses' => '/reports/tanker-expenses',
      _ => throw ArgumentError('Unsupported report key: $reportKey'),
    };
    final response = await _dio.get<Map<String, dynamic>>(
      endpoint,
      queryParameters: _query({
        'station_id': stationId,
        'report_date': reportDate?.toIso8601String().split('T').first,
        'from_date': fromDate?.toIso8601String().split('T').first,
        'to_date': toDate?.toIso8601String().split('T').first,
      }),
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> createReportExport({
    required String reportType,
    required String format,
    required int stationId,
    DateTime? reportDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/report-exports/',
      data: {
        'report_type': reportType,
        'format': format,
        'station_id': stationId,
        'report_date': reportDate?.toIso8601String().split('T').first,
        'from_date': fromDate?.toIso8601String().split('T').first,
        'to_date': toDate?.toIso8601String().split('T').first,
      },
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listReportExports({
    String? reportType,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/report-exports/',
      queryParameters: _query({
        'report_type': reportType,
        'limit': 50,
      }),
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Uint8List> downloadReportExport(int jobId) async {
    final response = await _dio.get<List<int>>(
      '/report-exports/$jobId/download',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data ?? const <int>[];
    return Uint8List.fromList(bytes);
  }

  Future<Map<String, dynamic>> getCustomerLedgerDocument(int customerId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/financial-documents/customer-ledgers/$customerId',
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendCustomerLedgerDocument(
    int customerId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/financial-documents/customer-ledgers/$customerId/send',
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> getSupplierLedgerDocument({
    required int supplierId,
    required int stationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/financial-documents/supplier-ledgers/$supplierId',
      queryParameters: {'station_id': stationId},
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> sendSupplierLedgerDocument({
    required int supplierId,
    required int stationId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/financial-documents/supplier-ledgers/$supplierId/send',
      queryParameters: {'station_id': stationId},
      data: payload,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<List<Map<String, dynamic>>> listDocumentDispatches({
    String? status,
    String? channel,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/financial-documents/dispatches',
      queryParameters: _query({
        'status': status,
        'channel': channel,
        'limit': 50,
      }),
    );
    return (response.data ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> getDocumentDispatchDiagnostics() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/financial-documents/dispatches/diagnostics',
    );
    return response.data ?? <String, dynamic>{};
  }
}

final stationAdminRepositoryProvider = Provider<StationAdminRepository>((ref) {
  return StationAdminRepository(ref.watch(dioProvider));
});
