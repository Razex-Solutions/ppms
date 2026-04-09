import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/session_controller.dart';
import 'models/operator_models.dart';

class OperatorRepository {
  const OperatorRepository(this._dio);

  final Dio _dio;

  Future<SelfEmployeeProfile> getSelfProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/employee-profiles/me');
    return SelfEmployeeProfile.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SelfAttendanceSummary> getAttendanceSummary() async {
    final response = await _dio.get<Map<String, dynamic>>('/attendance/me');
    return SelfAttendanceSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SelfAttendanceRecord> checkIn({String? notes}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/attendance/me/check-in',
      data: {'notes': notes},
    );
    return SelfAttendanceRecord.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SelfAttendanceRecord> checkOut({String? notes}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/attendance/me/check-out',
      data: {'notes': notes},
    );
    return SelfAttendanceRecord.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SelfPayrollSummary> getPayrollSummary() async {
    final response = await _dio.get<Map<String, dynamic>>('/payroll/my-summary');
    return SelfPayrollSummary.fromJson(response.data ?? <String, dynamic>{});
  }
}

final operatorRepositoryProvider = Provider<OperatorRepository>((ref) {
  return OperatorRepository(ref.watch(dioProvider));
});

final selfProfileProvider = FutureProvider<SelfEmployeeProfile>((ref) {
  return ref.watch(operatorRepositoryProvider).getSelfProfile();
});

final selfAttendanceProvider = FutureProvider<SelfAttendanceSummary>((ref) {
  return ref.watch(operatorRepositoryProvider).getAttendanceSummary();
});

final selfPayrollProvider = FutureProvider<SelfPayrollSummary>((ref) {
  return ref.watch(operatorRepositoryProvider).getPayrollSummary();
});

class AttendanceActionState {
  const AttendanceActionState({
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  AttendanceActionState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AttendanceActionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage:
          clearSuccess ? null : successMessage ?? this.successMessage,
    );
  }
}

final attendanceActionProvider = NotifierProvider<
    AttendanceActionController, AttendanceActionState>(
  AttendanceActionController.new,
);

class AttendanceActionController extends Notifier<AttendanceActionState> {
  @override
  AttendanceActionState build() => const AttendanceActionState();

  Future<void> checkIn() async {
    state = const AttendanceActionState(isSubmitting: true);
    try {
      await ref.read(operatorRepositoryProvider).checkIn();
      ref.invalidate(selfAttendanceProvider);
      state = const AttendanceActionState(successMessage: 'checked_in');
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['detail'] as String? ?? 'Unable to check in')
          : 'Unable to check in';
      state = AttendanceActionState(errorMessage: detail);
    } catch (_) {
      state = const AttendanceActionState(errorMessage: 'Unable to check in');
    }
  }

  Future<void> checkOut() async {
    state = const AttendanceActionState(isSubmitting: true);
    try {
      await ref.read(operatorRepositoryProvider).checkOut();
      ref.invalidate(selfAttendanceProvider);
      state = const AttendanceActionState(successMessage: 'checked_out');
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['detail'] as String? ?? 'Unable to check out')
          : 'Unable to check out';
      state = AttendanceActionState(errorMessage: detail);
    } catch (_) {
      state = const AttendanceActionState(errorMessage: 'Unable to check out');
    }
  }

  void clearMessages() {
    state = const AttendanceActionState();
  }
}
