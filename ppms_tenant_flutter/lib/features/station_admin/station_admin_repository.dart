import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required double newReading,
    required String reason,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/nozzles/$nozzleId/adjust-meter',
      data: {'new_reading': newReading, 'reason': reason},
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
}

final stationAdminRepositoryProvider = Provider<StationAdminRepository>((ref) {
  return StationAdminRepository(ref.watch(dioProvider));
});
