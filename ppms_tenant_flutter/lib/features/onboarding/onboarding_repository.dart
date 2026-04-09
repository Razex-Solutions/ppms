import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session/session_controller.dart';
import 'models/onboarding_models.dart';

class OnboardingRepository {
  const OnboardingRepository(this._dio);

  final Dio _dio;

  Future<List<BrandOption>> listBrands() async {
    final response = await _dio.get<List<dynamic>>('/brands/');
    return (response.data ?? [])
        .map((item) => BrandOption.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrganizationListItem>> listOrganizations() async {
    final response = await _dio.get<List<dynamic>>('/organizations/');
    return (response.data ?? [])
        .map(
          (item) => OrganizationListItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<OrganizationDetail> getOrganizationDetail(int organizationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$organizationId',
    );
    return OrganizationDetail.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<OrganizationOnboardingSummary> getOnboardingSummary(
    int organizationId,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$organizationId/onboarding-summary',
    );
    return OrganizationOnboardingSummary.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<OrganizationSetupFoundation> getFoundation(int organizationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/organizations/$organizationId/setup-foundation',
    );
    return OrganizationSetupFoundation.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<void> applyOrganizationOnboarding({
    int? organizationId,
    required String name,
    required String legalName,
    required String? contactEmail,
    required String? contactPhone,
    required String? registrationNumber,
    required String? taxRegistrationNumber,
    required int stationTargetCount,
    required bool inheritBrandingToStations,
    required bool isActive,
    int? brandCatalogId,
    required List<Map<String, dynamic>> moduleSettings,
    required List<Map<String, dynamic>> stations,
    Map<String, dynamic>? initialAdmin,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/organizations/onboarding/apply',
      data: {
        'organization_id': organizationId,
        'name': name,
        'legal_name': legalName,
        'contact_email': contactEmail?.trim().isEmpty == true ? null : contactEmail,
        'contact_phone': contactPhone?.trim().isEmpty == true ? null : contactPhone,
        'registration_number':
            registrationNumber?.trim().isEmpty == true ? null : registrationNumber,
        'tax_registration_number': taxRegistrationNumber?.trim().isEmpty == true
            ? null
            : taxRegistrationNumber,
        'station_target_count': stationTargetCount,
        'inherit_branding_to_stations': inheritBrandingToStations,
        'is_active': isActive,
        'brand_catalog_id': brandCatalogId,
        'module_settings': moduleSettings,
        'stations': stations,
        'initial_admin': initialAdmin,
      },
    );
  }

  Future<StationSetupFoundation> getStationFoundation(int stationId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/stations/$stationId/setup-foundation',
    );
    return StationSetupFoundation.fromJson(
      response.data ?? <String, dynamic>{},
    );
  }

  Future<void> applyStationSetup({
    required int stationId,
    required String? displayName,
    required String shiftMode,
    required bool hasPos,
    required bool hasTankers,
    required bool hasShops,
    required bool hasHardware,
    required bool allowMeterAdjustments,
    required List<Map<String, dynamic>> fuelTypes,
    required List<Map<String, dynamic>> tanks,
    required List<Map<String, dynamic>> dispensers,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/stations/$stationId/setup-wizard/apply',
      data: {
        'display_name': displayName,
        'setup_status': 'completed',
        'has_pos': hasPos,
        'has_tankers': hasTankers,
        'has_shops': hasShops,
        'has_hardware': hasHardware,
        'allow_meter_adjustments': allowMeterAdjustments,
        'shift_mode': shiftMode,
        'fuel_types': fuelTypes,
        'tanks': tanks,
        'dispensers': dispensers,
      },
    );
  }
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(ref.watch(dioProvider));
});

final brandsProvider = FutureProvider<List<BrandOption>>((ref) {
  return ref.watch(onboardingRepositoryProvider).listBrands();
});

final organizationsProvider = FutureProvider<List<OrganizationListItem>>((ref) {
  return ref.watch(onboardingRepositoryProvider).listOrganizations();
});

final selectedOrganizationIdProvider = NotifierProvider<
    SelectedOrganizationController, int?>(SelectedOrganizationController.new);

final onboardingSummaryProvider =
    FutureProvider.family<OrganizationOnboardingSummary, int>((ref, id) {
  return ref.watch(onboardingRepositoryProvider).getOnboardingSummary(id);
});

final onboardingFoundationProvider =
    FutureProvider.family<OrganizationSetupFoundation, int>((ref, id) {
  return ref.watch(onboardingRepositoryProvider).getFoundation(id);
});

final stationSetupFoundationProvider =
    FutureProvider.family<StationSetupFoundation, int>((ref, id) {
  return ref.watch(onboardingRepositoryProvider).getStationFoundation(id);
});

class OnboardingActionState {
  const OnboardingActionState({
    this.isSaving = false,
    this.errorMessage,
    this.isSuccess = false,
  });

  final bool isSaving;
  final String? errorMessage;
  final bool isSuccess;

  OnboardingActionState copyWith({
    bool? isSaving,
    String? errorMessage,
    bool? isSuccess,
    bool clearError = false,
  }) {
    return OnboardingActionState(
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

final onboardingActionProvider = NotifierProvider<
    OnboardingActionController, OnboardingActionState>(
  OnboardingActionController.new,
);

final stationSetupActionProvider = NotifierProvider<
    StationSetupActionController, OnboardingActionState>(
  StationSetupActionController.new,
);

class OnboardingActionController extends Notifier<OnboardingActionState> {
  @override
  OnboardingActionState build() => const OnboardingActionState();

  Future<void> submit({
    int? organizationId,
    required String name,
    required String legalName,
    required String? contactEmail,
    required String? contactPhone,
    required String? registrationNumber,
    required String? taxRegistrationNumber,
    required int stationTargetCount,
    required bool inheritBrandingToStations,
    required bool isActive,
    int? brandCatalogId,
    required List<Map<String, dynamic>> moduleSettings,
    required List<Map<String, dynamic>> stations,
    Map<String, dynamic>? initialAdmin,
  }) async {
    state = const OnboardingActionState(isSaving: true);
    try {
      await ref.read(onboardingRepositoryProvider).applyOrganizationOnboarding(
            organizationId: organizationId,
            name: name,
            legalName: legalName,
            contactEmail: contactEmail,
            contactPhone: contactPhone,
            registrationNumber: registrationNumber,
            taxRegistrationNumber: taxRegistrationNumber,
            stationTargetCount: stationTargetCount,
            inheritBrandingToStations: inheritBrandingToStations,
            isActive: isActive,
            brandCatalogId: brandCatalogId,
            moduleSettings: moduleSettings,
            stations: stations,
            initialAdmin: initialAdmin,
          );
      ref.invalidate(organizationsProvider);
      if (organizationId != null) {
        ref.invalidate(onboardingSummaryProvider(organizationId));
        ref.invalidate(onboardingFoundationProvider(organizationId));
        ref.read(selectedOrganizationIdProvider.notifier).state = organizationId;
      }
      state = const OnboardingActionState(isSuccess: true);
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['detail'] as String? ?? 'Save failed')
          : 'Save failed';
      state = OnboardingActionState(errorMessage: detail);
    } catch (_) {
      state = const OnboardingActionState(errorMessage: 'Save failed');
    }
  }

  void clearMessage() {
    state = const OnboardingActionState();
  }
}

class SelectedOrganizationController extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? organizationId) {
    state = organizationId;
  }
}

class StationSetupActionController extends Notifier<OnboardingActionState> {
  @override
  OnboardingActionState build() => const OnboardingActionState();

  Future<void> submit({
    required int stationId,
    required String? displayName,
    required String shiftMode,
    required bool hasPos,
    required bool hasTankers,
    required bool hasShops,
    required bool hasHardware,
    required bool allowMeterAdjustments,
    required List<Map<String, dynamic>> fuelTypes,
    required List<Map<String, dynamic>> tanks,
    required List<Map<String, dynamic>> dispensers,
    int? organizationId,
  }) async {
    state = const OnboardingActionState(isSaving: true);
    try {
      await ref.read(onboardingRepositoryProvider).applyStationSetup(
            stationId: stationId,
            displayName: displayName,
            shiftMode: shiftMode,
            hasPos: hasPos,
            hasTankers: hasTankers,
            hasShops: hasShops,
            hasHardware: hasHardware,
            allowMeterAdjustments: allowMeterAdjustments,
            fuelTypes: fuelTypes,
            tanks: tanks,
            dispensers: dispensers,
          );
      ref.invalidate(stationSetupFoundationProvider(stationId));
      if (organizationId != null) {
        ref.invalidate(onboardingFoundationProvider(organizationId));
        ref.invalidate(onboardingSummaryProvider(organizationId));
      }
      state = const OnboardingActionState(isSuccess: true);
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['detail'] as String? ?? 'Station setup failed')
          : 'Station setup failed';
      state = OnboardingActionState(errorMessage: detail);
    } catch (_) {
      state = const OnboardingActionState(errorMessage: 'Station setup failed');
    }
  }

  void clearMessage() {
    state = const OnboardingActionState();
  }
}
