class BrandOption {
  const BrandOption({
    required this.id,
    required this.code,
    required this.name,
    this.logoUrl,
  });

  final int id;
  final String code;
  final String name;
  final String? logoUrl;

  factory BrandOption.fromJson(Map<String, dynamic> json) {
    return BrandOption(
      id: json['id'] as int,
      code: json['code'] as String,
      name: json['name'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class OrganizationListItem {
  const OrganizationListItem({
    required this.id,
    required this.name,
    required this.code,
    required this.onboardingStatus,
    required this.isActive,
    this.brandName,
    this.stationTargetCount,
  });

  final int id;
  final String name;
  final String code;
  final String onboardingStatus;
  final bool isActive;
  final String? brandName;
  final int? stationTargetCount;

  factory OrganizationListItem.fromJson(Map<String, dynamic> json) {
    return OrganizationListItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      onboardingStatus: json['onboarding_status'] as String,
      isActive: json['is_active'] == true,
      brandName: json['brand_name'] as String?,
      stationTargetCount: json['station_target_count'] as int?,
    );
  }
}

class OrganizationDetail {
  const OrganizationDetail({
    required this.id,
    required this.name,
    required this.code,
    required this.onboardingStatus,
    required this.isActive,
    this.legalName,
    this.brandCatalogId,
    this.brandName,
    this.contactEmail,
    this.contactPhone,
    this.registrationNumber,
    this.taxRegistrationNumber,
    this.stationTargetCount,
    this.inheritBrandingToStations = true,
  });

  final int id;
  final String name;
  final String code;
  final String onboardingStatus;
  final bool isActive;
  final String? legalName;
  final int? brandCatalogId;
  final String? brandName;
  final String? contactEmail;
  final String? contactPhone;
  final String? registrationNumber;
  final String? taxRegistrationNumber;
  final int? stationTargetCount;
  final bool inheritBrandingToStations;

  factory OrganizationDetail.fromJson(Map<String, dynamic> json) {
    return OrganizationDetail(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      onboardingStatus: json['onboarding_status'] as String,
      isActive: json['is_active'] == true,
      legalName: json['legal_name'] as String?,
      brandCatalogId: json['brand_catalog_id'] as int?,
      brandName: json['brand_name'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactPhone: json['contact_phone'] as String?,
      registrationNumber: json['registration_number'] as String?,
      taxRegistrationNumber: json['tax_registration_number'] as String?,
      stationTargetCount: json['station_target_count'] as int?,
      inheritBrandingToStations: json['inherit_branding_to_stations'] == true,
    );
  }
}

class OnboardingStep {
  const OnboardingStep({
    required this.stepKey,
    required this.title,
    required this.status,
    required this.detail,
    required this.blocking,
  });

  final String stepKey;
  final String title;
  final String status;
  final String detail;
  final bool blocking;

  factory OnboardingStep.fromJson(Map<String, dynamic> json) {
    return OnboardingStep(
      stepKey: json['step_key'] as String,
      title: json['title'] as String,
      status: json['status'] as String,
      detail: json['detail'] as String,
      blocking: json['blocking'] == true,
    );
  }
}

class OnboardingIssue {
  const OnboardingIssue({
    required this.code,
    required this.title,
    required this.detail,
    required this.ownerScope,
    required this.ownerRole,
    required this.blocking,
    this.stationName,
  });

  final String code;
  final String title;
  final String detail;
  final String ownerScope;
  final String ownerRole;
  final bool blocking;
  final String? stationName;

  factory OnboardingIssue.fromJson(Map<String, dynamic> json) {
    return OnboardingIssue(
      code: json['code'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
      ownerScope: json['owner_scope'] as String,
      ownerRole: json['owner_role'] as String,
      blocking: json['blocking'] == true,
      stationName: json['station_name'] as String?,
    );
  }
}

class OrganizationOnboardingSummary {
  const OrganizationOnboardingSummary({
    required this.organizationId,
    required this.organizationName,
    required this.organizationCode,
    required this.onboardingStatus,
    required this.currentStationCount,
    required this.stationAdminCount,
    required this.headOfficeCount,
    required this.completedStationCount,
    required this.pendingStationCount,
    required this.progressPercent,
    required this.steps,
    required this.pendingIssues,
    this.targetStationCount,
  });

  final int organizationId;
  final String organizationName;
  final String organizationCode;
  final String onboardingStatus;
  final int? targetStationCount;
  final int currentStationCount;
  final int stationAdminCount;
  final int headOfficeCount;
  final int completedStationCount;
  final int pendingStationCount;
  final int progressPercent;
  final List<OnboardingStep> steps;
  final List<OnboardingIssue> pendingIssues;

  factory OrganizationOnboardingSummary.fromJson(Map<String, dynamic> json) {
    return OrganizationOnboardingSummary(
      organizationId: json['organization_id'] as int,
      organizationName: json['organization_name'] as String,
      organizationCode: json['organization_code'] as String,
      onboardingStatus: json['onboarding_status'] as String,
      targetStationCount: json['target_station_count'] as int?,
      currentStationCount: json['current_station_count'] as int,
      stationAdminCount: json['station_admin_count'] as int,
      headOfficeCount: json['head_office_count'] as int,
      completedStationCount: json['completed_station_count'] as int,
      pendingStationCount: json['pending_station_count'] as int,
      progressPercent: json['progress_percent'] as int,
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((item) => OnboardingStep.fromJson(item as Map<String, dynamic>))
          .toList(),
      pendingIssues: (json['pending_issues'] as List<dynamic>? ?? [])
          .map((item) => OnboardingIssue.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StationSetupItem {
  const StationSetupItem({
    required this.id,
    required this.name,
    required this.code,
    required this.isHeadOffice,
    required this.setupStatus,
  });

  final int id;
  final String name;
  final String code;
  final bool isHeadOffice;
  final String setupStatus;

  factory StationSetupItem.fromJson(Map<String, dynamic> json) {
    return StationSetupItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      isHeadOffice: json['is_head_office'] == true,
      setupStatus: json['setup_status'] as String,
    );
  }
}

class OrganizationSetupFoundation {
  const OrganizationSetupFoundation({
    required this.organizationId,
    required this.organizationName,
    required this.organizationCode,
    required this.onboardingStatus,
    required this.inheritBrandingToStations,
    required this.stations,
    this.stationTargetCount,
    this.legalName,
  });

  final int organizationId;
  final String organizationName;
  final String organizationCode;
  final String onboardingStatus;
  final int? stationTargetCount;
  final String? legalName;
  final bool inheritBrandingToStations;
  final List<StationSetupItem> stations;

  factory OrganizationSetupFoundation.fromJson(Map<String, dynamic> json) {
    return OrganizationSetupFoundation(
      organizationId: json['organization_id'] as int,
      organizationName: json['organization_name'] as String,
      organizationCode: json['organization_code'] as String,
      onboardingStatus: json['onboarding_status'] as String,
      stationTargetCount: json['station_target_count'] as int?,
      legalName: json['legal_name'] as String?,
      inheritBrandingToStations: json['inherit_branding_to_stations'] == true,
      stations: (json['stations'] as List<dynamic>? ?? [])
          .map((item) => StationSetupItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StationFuelTypeItem {
  const StationFuelTypeItem({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;

  factory StationFuelTypeItem.fromJson(Map<String, dynamic> json) {
    return StationFuelTypeItem(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}

class StationTankItem {
  const StationTankItem({
    required this.id,
    required this.name,
    required this.code,
    required this.fuelTypeId,
    required this.capacity,
    required this.lowStockThreshold,
    required this.currentVolume,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final int fuelTypeId;
  final double capacity;
  final double lowStockThreshold;
  final double currentVolume;
  final bool isActive;

  factory StationTankItem.fromJson(Map<String, dynamic> json) {
    return StationTankItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      fuelTypeId: json['fuel_type_id'] as int,
      capacity: (json['capacity'] as num).toDouble(),
      lowStockThreshold: (json['low_stock_threshold'] as num).toDouble(),
      currentVolume: (json['current_volume'] as num).toDouble(),
      isActive: json['is_active'] == true,
    );
  }
}

class StationNozzleItem {
  const StationNozzleItem({
    required this.id,
    required this.name,
    required this.code,
    required this.tankId,
    required this.fuelTypeId,
    required this.meterReading,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final int tankId;
  final int fuelTypeId;
  final double meterReading;
  final bool isActive;

  factory StationNozzleItem.fromJson(Map<String, dynamic> json) {
    return StationNozzleItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      tankId: json['tank_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      meterReading: (json['meter_reading'] as num).toDouble(),
      isActive: json['is_active'] == true,
    );
  }
}

class StationDispenserItem {
  const StationDispenserItem({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
    required this.nozzles,
  });

  final int id;
  final String name;
  final String code;
  final bool isActive;
  final List<StationNozzleItem> nozzles;

  factory StationDispenserItem.fromJson(Map<String, dynamic> json) {
    return StationDispenserItem(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      isActive: json['is_active'] == true,
      nozzles: (json['nozzles'] as List<dynamic>? ?? [])
          .map((item) => StationNozzleItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StationSetupFoundation {
  const StationSetupFoundation({
    required this.stationId,
    required this.organizationId,
    required this.stationName,
    required this.stationCode,
    required this.setupStatus,
    required this.fuelTypes,
    required this.tanks,
    required this.dispensers,
    required this.tankCount,
    required this.dispenserCount,
    required this.nozzleCount,
  });

  final int stationId;
  final int? organizationId;
  final String stationName;
  final String stationCode;
  final String setupStatus;
  final List<StationFuelTypeItem> fuelTypes;
  final List<StationTankItem> tanks;
  final List<StationDispenserItem> dispensers;
  final int tankCount;
  final int dispenserCount;
  final int nozzleCount;

  factory StationSetupFoundation.fromJson(Map<String, dynamic> json) {
    return StationSetupFoundation(
      stationId: json['station_id'] as int,
      organizationId: json['organization_id'] as int?,
      stationName: json['station_name'] as String,
      stationCode: json['station_code'] as String,
      setupStatus: json['setup_status'] as String,
      fuelTypes: (json['fuel_types'] as List<dynamic>? ?? [])
          .map((item) => StationFuelTypeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      tanks: (json['tanks'] as List<dynamic>? ?? [])
          .map((item) => StationTankItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      dispensers: (json['dispensers'] as List<dynamic>? ?? [])
          .map((item) => StationDispenserItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      tankCount: json['tank_count'] as int,
      dispenserCount: json['dispenser_count'] as int,
      nozzleCount: json['nozzle_count'] as int,
    );
  }
}
