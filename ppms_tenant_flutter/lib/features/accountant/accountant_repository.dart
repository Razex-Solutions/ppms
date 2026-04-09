import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/session_controller.dart';
import 'models/accountant_models.dart';

class AccountantRepository {
  const AccountantRepository(this._dio);

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

  Future<AccountantWorkspaceSummary> getWorkspaceSummary({
    int? stationId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/accounting/workspace-summary',
      queryParameters: _query({'station_id': stationId}),
    );
    return AccountantWorkspaceSummary.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<ProfitSummary> getProfitSummary({int? stationId}) async {
    return getProfitSummaryForRange(stationId: stationId);
  }

  Future<ProfitSummary> getProfitSummaryForRange({
    int? stationId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/accounting/profit-summary',
      queryParameters: _query({
        'station_id': stationId,
        'from_date': fromDate?.toIso8601String().split('T').first,
        'to_date': toDate?.toIso8601String().split('T').first,
      }),
    );
    return ProfitSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<CustomerFinanceItem>> listCustomers({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/customers/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? [])
        .map(
          (item) =>
              CustomerFinanceItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<SupplierFinanceItem>> listSuppliers() async {
    final response = await _dio.get<List<dynamic>>(
      '/suppliers/',
      queryParameters: {'limit': 200},
    );
    return (response.data ?? [])
        .map(
          (item) =>
              SupplierFinanceItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<LedgerDetail> getCustomerLedger(int customerId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/ledger/customer/$customerId');
    return LedgerDetail.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<LedgerDetail> getSupplierLedger(int supplierId, {int? stationId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/ledger/supplier/$supplierId',
      queryParameters: _query({'station_id': stationId}),
    );
    return LedgerDetail.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<CustomerPaymentItem>> listCustomerPayments({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/customer-payments/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? [])
        .map((item) => CustomerPaymentItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerPaymentItem> createCustomerPayment({
    required int customerId,
    required int stationId,
    required double amount,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/customer-payments/',
      data: {
        'customer_id': customerId,
        'station_id': stationId,
        'amount': amount,
        'payment_method': 'cash',
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return CustomerPaymentItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<CustomerPaymentItem> updateCustomerPayment({
    required int paymentId,
    required double amount,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/customer-payments/$paymentId',
      data: {
        'amount': amount,
        'payment_method': 'cash',
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return CustomerPaymentItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteCustomerPayment(int paymentId) async {
    await _dio.delete('/customer-payments/$paymentId');
  }

  Future<List<SupplierPaymentItem>> listSupplierPayments({
    required int stationId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/supplier-payments/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? [])
        .map((item) => SupplierPaymentItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SupplierPaymentItem> createSupplierPayment({
    required int supplierId,
    required int stationId,
    required double amount,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/supplier-payments/',
      data: {
        'supplier_id': supplierId,
        'station_id': stationId,
        'amount': amount,
        'payment_method': 'cash',
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return SupplierPaymentItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SupplierPaymentItem> updateSupplierPayment({
    required int paymentId,
    required double amount,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/supplier-payments/$paymentId',
      data: {
        'amount': amount,
        'payment_method': 'cash',
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return SupplierPaymentItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteSupplierPayment(int paymentId) async {
    await _dio.delete('/supplier-payments/$paymentId');
  }

  Future<List<ExpenseItem>> listExpenses({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/expenses/',
      queryParameters: {'station_id': stationId, 'limit': 200},
    );
    return (response.data ?? [])
        .map((item) => ExpenseItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseItem> updateExpense({
    required int expenseId,
    required String title,
    required String category,
    required double amount,
    String? notes,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/expenses/$expenseId',
      data: {
        'title': title,
        'category': category,
        'amount': amount,
        'notes': notes,
      },
    );
    return ExpenseItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<void> deleteExpense(int expenseId) async {
    await _dio.delete('/expenses/$expenseId');
  }

  Future<List<PayrollRunItem>> listPayrollRuns({required int stationId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/payroll/runs',
      queryParameters: {'station_id': stationId, 'limit': 100},
    );
    return (response.data ?? [])
        .map((item) => PayrollRunItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PayrollLineItem>> getPayrollLines(int payrollRunId) async {
    final response = await _dio.get<List<dynamic>>(
      '/payroll/runs/$payrollRunId/lines',
    );
    return (response.data ?? [])
        .map((item) => PayrollLineItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PayrollRunItem> createPayrollRun({
    required int stationId,
    required DateTime periodStart,
    required DateTime periodEnd,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payroll/runs',
      data: {
        'station_id': stationId,
        'period_start': periodStart.toIso8601String().split('T').first,
        'period_end': periodEnd.toIso8601String().split('T').first,
        'notes': notes,
      },
    );
    return PayrollRunItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<PayrollRunItem> finalizePayrollRun(int payrollRunId, {String? notes}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payroll/runs/$payrollRunId/finalize',
      data: {'notes': notes},
    );
    return PayrollRunItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<AccountantDashboardBundle> loadDashboard({
    required int stationId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final results = await Future.wait([
      getWorkspaceSummary(stationId: stationId),
      getProfitSummaryForRange(
        stationId: stationId,
        fromDate: fromDate,
        toDate: toDate,
      ),
      listCustomers(stationId: stationId),
      listSuppliers(),
      listCustomerPayments(stationId: stationId),
      listSupplierPayments(stationId: stationId),
      listExpenses(stationId: stationId),
      listPayrollRuns(stationId: stationId),
    ]);

    return AccountantDashboardBundle(
      workspaceSummary: results[0] as AccountantWorkspaceSummary,
      profitSummary: results[1] as ProfitSummary,
      customers: results[2] as List<CustomerFinanceItem>,
      suppliers: results[3] as List<SupplierFinanceItem>,
      customerPayments: results[4] as List<CustomerPaymentItem>,
      supplierPayments: results[5] as List<SupplierPaymentItem>,
      expenses: results[6] as List<ExpenseItem>,
      payrollRuns: results[7] as List<PayrollRunItem>,
    );
  }
}

final accountantRepositoryProvider = Provider<AccountantRepository>((ref) {
  return AccountantRepository(ref.watch(dioProvider));
});
