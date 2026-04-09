import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/session_controller.dart';
import 'models/manager_models.dart';

class ManagerRepository {
  const ManagerRepository(this._dio);

  final Dio _dio;

  List<dynamic> _listData(Object? data) {
    if (data is List<dynamic>) {
      return data;
    }
    return const <dynamic>[];
  }

  Map<String, dynamic> _mapData(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    return const <String, dynamic>{};
  }

  Map<String, dynamic> _query(Map<String, dynamic> values) {
    final result = <String, dynamic>{};
    values.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  Future<ManagerCurrentWorkspace> getCurrentWorkspace() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/shifts/current-workspace',
    );
    return ManagerCurrentWorkspace.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<ShiftSummary> startCurrentShift({
    required int stationId,
    int? shiftTemplateId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shifts/',
      data: {
        'station_id': stationId,
        'shift_template_id': shiftTemplateId,
        'initial_cash': 0,
      },
    );
    return ShiftSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ShiftCashSummary> getShiftCash(int shiftId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/shifts/$shiftId/cash');
    return ShiftCashSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<CashSubmissionItem>> listCashSubmissions(int shiftId) async {
    final response = await _dio.get<List<dynamic>>(
      '/shifts/$shiftId/cash-submissions',
    );
    return (response.data ?? [])
        .map(
          (item) => CashSubmissionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<CashSubmissionItem> submitCash({
    required int shiftId,
    required double amount,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shifts/$shiftId/cash-submissions',
      data: {'amount': amount},
    );
    return CashSubmissionItem.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ShiftCloseValidation> runCloseCheck({
    required int shiftId,
    required double actualCashCollected,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shifts/$shiftId/close-check',
      data: {
        'actual_cash_collected': actualCashCollected,
        'nozzle_readings': nozzleReadings,
      },
    );
    return ShiftCloseValidation.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ShiftSummary> closeShift({
    required int shiftId,
    required double actualCashCollected,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shifts/$shiftId/close',
      data: {
        'actual_cash_collected': actualCashCollected,
        'nozzle_readings': nozzleReadings,
      },
    );
    return ShiftSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ManagerSupportData> loadSupportData({required int stationId}) async {
    final responses = await Future.wait([
      _dio.get<List<dynamic>>('/fuel-types/'),
      _dio.get<List<dynamic>>('/tanks/', queryParameters: {'station_id': stationId}),
      _dio.get<List<dynamic>>('/customers/', queryParameters: {'station_id': stationId, 'limit': 200}),
      _dio.get<List<dynamic>>('/suppliers/', queryParameters: {'limit': 200}),
      _dio.get<List<dynamic>>('/tankers/trips', queryParameters: {'station_id': stationId, 'limit': 200}),
      _dio.get<List<dynamic>>(
        '/pos-products/',
        queryParameters: {'station_id': stationId, 'is_active': true, 'limit': 200},
      ),
    ]);

    return ManagerSupportData(
      fuelTypes: _listData(responses[0].data)
          .map((item) => FuelTypeOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      tanks: _listData(responses[1].data)
          .map((item) => TankOption.fromJson(item as Map<String, dynamic>))
          .toList(),
      customers: _listData(responses[2].data)
          .map((item) => CustomerSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      suppliers: _listData(responses[3].data)
          .map((item) => SupplierSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      ownTankerTrips: _listData(responses[4].data)
          .map((item) => ManagerTankerTripOption.fromJson(item as Map<String, dynamic>))
          .where((trip) => trip.leftoverQuantity > 0 && trip.status != 'settled')
          .toList(),
      products: _listData(responses[5].data)
          .map((item) => PosProductSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<ManagerDashboardData> loadDashboard(
    ManagerDashboardRequest request,
  ) async {
    final shiftStart = request.shiftStartIso == null
        ? null
        : DateTime.parse(request.shiftStartIso!).toUtc();
    final responses = await Future.wait([
      _dio.get<List<dynamic>>(
        '/fuel-sales/',
        queryParameters: _query({
          'station_id': request.stationId,
          'shift_id': request.shiftId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/pos-sales/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/purchases/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/fuel-transfers/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/expenses/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/customer-payments/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/customers/credit-issues/',
        queryParameters: _query({
          'station_id': request.stationId,
          'shift_id': request.shiftId,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/internal-fuel-usage/',
        queryParameters: _query({
          'station_id': request.stationId,
          'limit': 200,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/tank-dips/',
        queryParameters: _query({
          'station_id': request.stationId,
          'from_date': request.fromDate,
          'limit': 20,
        }),
      ),
      _dio.get<List<dynamic>>(
        '/customers/',
        queryParameters: _query({'station_id': request.stationId, 'limit': 200}),
      ),
      _dio.get<Map<String, dynamic>>('/notifications/summary'),
    ]);

    bool isInShiftWindow(DateTime createdAt) {
      if (shiftStart == null) return true;
      return !createdAt.toUtc().isBefore(shiftStart);
    }

    final allPosSales = _listData(responses[1].data)
        .map((item) => PosSaleEntry.fromJson(item as Map<String, dynamic>))
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final purchases = _listData(responses[2].data)
        .map((item) => PurchaseEntry.fromJson(item as Map<String, dynamic>))
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final fuelTransfers = _listData(responses[3].data)
        .map((item) => FuelTransferEntry.fromJson(item as Map<String, dynamic>))
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final expenses = _listData(responses[4].data)
        .map((item) => ExpenseEntry.fromJson(item as Map<String, dynamic>))
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final recoveries = _listData(responses[5].data)
        .map(
          (item) => CustomerRecoveryEntry.fromJson(item as Map<String, dynamic>),
        )
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final internalFuelUsages = _listData(responses[7].data)
        .map(
          (item) => InternalFuelUsageEntry.fromJson(item as Map<String, dynamic>),
        )
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    final recentDips = _listData(responses[8].data)
        .map((item) => TankDipEntry.fromJson(item as Map<String, dynamic>))
        .where((item) => isInShiftWindow(item.createdAt))
        .toList();

    return ManagerDashboardData(
      fuelSales: _listData(responses[0].data)
          .map((item) => FuelSaleEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      lubricantSales: allPosSales
          .where((sale) => sale.module == 'other')
          .toList(),
      purchases: purchases,
      fuelTransfers: fuelTransfers,
      expenses: expenses,
      recoveries: recoveries,
      creditIssues: _listData(responses[6].data)
          .map(
            (item) =>
                CustomerCreditIssueEntry.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      internalFuelUsages: internalFuelUsages,
      recentDips: recentDips,
      customers: _listData(responses[9].data)
          .map((item) => CustomerSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      notificationSummary: NotificationSummaryData.fromJson(_mapData(responses[10].data)),
    );
  }

  Future<TankDipEntry> recordDip({
    required int tankId,
    required double dipReadingMm,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/tank-dips/',
      data: {
        'tank_id': tankId,
        'dip_reading_mm': dipReadingMm,
        'notes': notes,
      },
    );
    return TankDipEntry.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<PurchaseEntry> createReceiving({
    required int supplierId,
    required int tankId,
    required int fuelTypeId,
    required double quantity,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/purchases/manager-receiving',
      data: {
        'supplier_id': supplierId,
        'tank_id': tankId,
        'fuel_type_id': fuelTypeId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return PurchaseEntry.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<FuelTransferEntry> createOwnTankerReceiving({
    required int tripId,
    required int tankId,
    required double quantity,
    String? referenceNo,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/purchases/manager-own-tanker-receiving',
      data: {
        'trip_id': tripId,
        'tank_id': tankId,
        'quantity': quantity,
        'reference_no': referenceNo,
        'notes': notes,
      },
    );
    return FuelTransferEntry.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<ManagerCurrentWorkspace> captureRateChangeBoundary({
    required int shiftId,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/shifts/$shiftId/rate-change-boundary',
      data: {
        'nozzle_readings': nozzleReadings,
      },
    );
    return ManagerCurrentWorkspace.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<CustomerRecoveryEntry> createCustomerRecovery({
    required int stationId,
    required int customerId,
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
    return CustomerRecoveryEntry.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<CustomerCreditIssueEntry> createCustomerCreditIssue({
    required int customerId,
    required int nozzleId,
    required double quantity,
    int? shiftId,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/customers/$customerId/manager-credit-issue',
      data: {
        'nozzle_id': nozzleId,
        'quantity': quantity,
        'shift_id': shiftId,
        'notes': notes,
      },
    );
    return CustomerCreditIssueEntry.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<ExpenseEntry> createExpense({
    required int stationId,
    required String category,
    required double amount,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/expenses/',
      data: {
        'title': category,
        'category': category,
        'amount': amount,
        'notes': notes,
        'station_id': stationId,
      },
    );
    return ExpenseEntry.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<PosSaleEntry> createLubricantSale({
    required int stationId,
    required int productId,
    required double quantity,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/pos-sales/',
      data: {
        'station_id': stationId,
        'module': 'other',
        'payment_method': 'cash',
        'notes': notes,
        'items': [
          {
            'product_id': productId,
            'quantity': quantity,
          },
        ],
      },
    );
    return PosSaleEntry.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<InternalFuelUsageEntry> createInternalUsage({
    required int tankId,
    required int fuelTypeId,
    required double quantity,
    required String purpose,
    String? notes,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/internal-fuel-usage/',
      data: {
        'tank_id': tankId,
        'fuel_type_id': fuelTypeId,
        'quantity': quantity,
        'purpose': purpose,
        'notes': notes,
      },
    );
    return InternalFuelUsageEntry.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }
}

final managerRepositoryProvider = Provider<ManagerRepository>((ref) {
  return ManagerRepository(ref.watch(dioProvider));
});

final managerWorkspaceProvider = FutureProvider.autoDispose<ManagerCurrentWorkspace>((ref) {
  return ref.watch(managerRepositoryProvider).getCurrentWorkspace();
});

final managerSupportProvider =
    FutureProvider.autoDispose.family<ManagerSupportData, int>((ref, stationId) {
  return ref.watch(managerRepositoryProvider).loadSupportData(
        stationId: stationId,
      );
});

final managerDashboardProvider =
    FutureProvider.autoDispose.family<ManagerDashboardData, ManagerDashboardRequest>(
  (ref, request) {
    return ref.watch(managerRepositoryProvider).loadDashboard(request);
  },
);

final shiftCashProvider =
    FutureProvider.autoDispose.family<ShiftCashSummary, int>((ref, shiftId) {
  return ref.watch(managerRepositoryProvider).getShiftCash(shiftId);
});

final cashSubmissionsProvider =
    FutureProvider.autoDispose.family<List<CashSubmissionItem>, int>((ref, shiftId) {
  return ref.watch(managerRepositoryProvider).listCashSubmissions(shiftId);
});

class ManagerActionState {
  const ManagerActionState({
    this.isBusy = false,
    this.errorMessage,
    this.successMessage,
    this.validation,
  });

  final bool isBusy;
  final String? errorMessage;
  final String? successMessage;
  final ShiftCloseValidation? validation;

  ManagerActionState copyWith({
    bool? isBusy,
    String? errorMessage,
    String? successMessage,
    ShiftCloseValidation? validation,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearValidation = false,
  }) {
    return ManagerActionState(
      isBusy: isBusy ?? this.isBusy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
      validation: clearValidation ? null : validation ?? this.validation,
    );
  }
}

final managerActionProvider =
    NotifierProvider<ManagerActionController, ManagerActionState>(
  ManagerActionController.new,
);

class ManagerActionController extends Notifier<ManagerActionState> {
  @override
  ManagerActionState build() => const ManagerActionState();

  Future<void> startShift({
    required int stationId,
    int? shiftTemplateId,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).startCurrentShift(
            stationId: stationId,
            shiftTemplateId: shiftTemplateId,
          );
      _refreshStation(stationId);
      state = const ManagerActionState(successMessage: 'Shift started.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to start shift');
    }
  }

  Future<void> submitCash({
    required int stationId,
    required int shiftId,
    required double amount,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).submitCash(
            shiftId: shiftId,
            amount: amount,
          );
      ref.invalidate(shiftCashProvider(shiftId));
      ref.invalidate(cashSubmissionsProvider(shiftId));
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Cash submitted.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to submit cash');
    }
  }

  Future<void> runCloseCheck({
    required int shiftId,
    required double actualCashCollected,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      final validation = await ref.read(managerRepositoryProvider).runCloseCheck(
            shiftId: shiftId,
            actualCashCollected: actualCashCollected,
            nozzleReadings: nozzleReadings,
          );
      state = ManagerActionState(validation: validation);
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to validate shift');
    }
  }

  Future<void> closeShift({
    required int stationId,
    required int shiftId,
    required double actualCashCollected,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).closeShift(
            shiftId: shiftId,
            actualCashCollected: actualCashCollected,
            nozzleReadings: nozzleReadings,
          );
      ref.invalidate(shiftCashProvider(shiftId));
      ref.invalidate(cashSubmissionsProvider(shiftId));
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Shift closed.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to close shift');
    }
  }

  Future<void> recordDip({
    required int stationId,
    int? shiftId,
    required int tankId,
    required double dipReadingMm,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).recordDip(
            tankId: tankId,
            dipReadingMm: dipReadingMm,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Dip recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record dip');
    }
  }

  Future<void> createReceiving({
    required int stationId,
    int? shiftId,
    required int supplierId,
    required int tankId,
    required int fuelTypeId,
    required double quantity,
    String? referenceNo,
    String? notes,
    double? dipBeforeMm,
    double? dipAfterMm,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      final repository = ref.read(managerRepositoryProvider);
      if (dipBeforeMm != null && dipBeforeMm > 0) {
        await repository.recordDip(
          tankId: tankId,
          dipReadingMm: dipBeforeMm,
          notes: 'Before receiving${referenceNo == null || referenceNo.isEmpty ? '' : ' ($referenceNo)'}',
        );
      }
      await repository.createReceiving(
        supplierId: supplierId,
        tankId: tankId,
        fuelTypeId: fuelTypeId,
        quantity: quantity,
        referenceNo: referenceNo,
        notes: notes,
      );
      if (dipAfterMm != null && dipAfterMm > 0) {
        await repository.recordDip(
          tankId: tankId,
          dipReadingMm: dipAfterMm,
          notes: 'After receiving${referenceNo == null || referenceNo.isEmpty ? '' : ' ($referenceNo)'}',
        );
      }
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Receiving recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record receiving');
    }
  }

  Future<void> createOwnTankerReceiving({
    required int stationId,
    int? shiftId,
    required int tripId,
    required int tankId,
    required double quantity,
    String? referenceNo,
    String? notes,
    double? dipBeforeMm,
    double? dipAfterMm,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      final repository = ref.read(managerRepositoryProvider);
      if (dipBeforeMm != null && dipBeforeMm > 0) {
        await repository.recordDip(
          tankId: tankId,
          dipReadingMm: dipBeforeMm,
          notes: 'Before own tanker receiving${referenceNo == null || referenceNo.isEmpty ? '' : ' ($referenceNo)'}',
        );
      }
      await repository.createOwnTankerReceiving(
        tripId: tripId,
        tankId: tankId,
        quantity: quantity,
        referenceNo: referenceNo,
        notes: notes,
      );
      if (dipAfterMm != null && dipAfterMm > 0) {
        await repository.recordDip(
          tankId: tankId,
          dipReadingMm: dipAfterMm,
          notes: 'After own tanker receiving${referenceNo == null || referenceNo.isEmpty ? '' : ' ($referenceNo)'}',
        );
      }
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Own tanker receiving recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record own tanker receiving');
    }
  }

  Future<void> captureRateChangeBoundary({
    required int stationId,
    required int shiftId,
    required List<Map<String, dynamic>> nozzleReadings,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).captureRateChangeBoundary(
            shiftId: shiftId,
            nozzleReadings: nozzleReadings,
          );
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Rate-change boundary captured.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to capture rate-change boundary');
    }
  }

  Future<void> recoverCustomerCredit({
    required int stationId,
    int? shiftId,
    required int customerId,
    required double amount,
    String? referenceNo,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).createCustomerRecovery(
            stationId: stationId,
            customerId: customerId,
            amount: amount,
            referenceNo: referenceNo,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Recovery recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record recovery');
    }
  }

  Future<void> giveCustomerCredit({
    required int stationId,
    int? shiftId,
    required int customerId,
    required int nozzleId,
    required double quantity,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).createCustomerCreditIssue(
            customerId: customerId,
            nozzleId: nozzleId,
            quantity: quantity,
            shiftId: shiftId,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Credit recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record credit');
    }
  }

  Future<void> createExpense({
    required int stationId,
    int? shiftId,
    required String category,
    required double amount,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).createExpense(
            stationId: stationId,
            category: category,
            amount: amount,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Expense recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record expense');
    }
  }

  Future<void> createLubricantSale({
    required int stationId,
    int? shiftId,
    required int productId,
    required double quantity,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).createLubricantSale(
            stationId: stationId,
            productId: productId,
            quantity: quantity,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Lubricant sale recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record lubricant sale');
    }
  }

  Future<void> createInternalUsage({
    required int stationId,
    int? shiftId,
    required int tankId,
    required int fuelTypeId,
    required double quantity,
    required String purpose,
    String? notes,
  }) async {
    state = const ManagerActionState(isBusy: true);
    try {
      await ref.read(managerRepositoryProvider).createInternalUsage(
            tankId: tankId,
            fuelTypeId: fuelTypeId,
            quantity: quantity,
            purpose: purpose,
            notes: notes,
          );
      if (shiftId != null) {
        ref.invalidate(shiftCashProvider(shiftId));
      }
      _refreshStation(stationId, shiftId: shiftId);
      state = const ManagerActionState(successMessage: 'Internal fuel usage recorded.');
    } on DioException catch (error) {
      state = ManagerActionState(errorMessage: _extractError(error));
    } catch (_) {
      state = const ManagerActionState(errorMessage: 'Unable to record internal fuel usage');
    }
  }

  void clearMessages() {
    state = const ManagerActionState();
  }

  void _refreshStation(int stationId, {int? shiftId}) {
    ref.invalidate(managerWorkspaceProvider);
    ref.invalidate(managerSupportProvider(stationId));
    ref.invalidate(managerDashboardProvider);
    ref.invalidate(
      managerDashboardProvider(
        ManagerDashboardRequest(stationId: stationId, shiftId: shiftId),
      ),
    );
    if (shiftId != null) {
      ref.invalidate(shiftCashProvider(shiftId));
      ref.invalidate(cashSubmissionsProvider(shiftId));
    }
  }

  String _extractError(DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is Map<String, dynamic>) {
        final message = detail['message'];
        if (message is String) return message;
      }
    }
    return 'Request failed';
  }
}
