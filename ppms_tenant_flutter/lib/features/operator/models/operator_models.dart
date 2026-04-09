class SelfEmployeeProfile {
  const SelfEmployeeProfile({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.roleName,
    required this.scopeLevel,
    required this.hasEmployeeProfile,
    required this.isActive,
    required this.payrollEnabled,
    required this.monthlySalary,
    required this.canLogin,
    this.email,
    this.phone,
    this.whatsappNumber,
    this.organizationId,
    this.organizationName,
    this.stationId,
    this.stationName,
    this.linkedEmployeeProfileId,
    this.staffType,
    this.staffTitle,
    this.employeeCode,
    this.nationalId,
    this.address,
  });

  final int userId;
  final String username;
  final String fullName;
  final String roleName;
  final String scopeLevel;
  final String? email;
  final String? phone;
  final String? whatsappNumber;
  final int? organizationId;
  final String? organizationName;
  final int? stationId;
  final String? stationName;
  final bool hasEmployeeProfile;
  final int? linkedEmployeeProfileId;
  final String? staffType;
  final String? staffTitle;
  final String? employeeCode;
  final String? nationalId;
  final String? address;
  final bool isActive;
  final bool payrollEnabled;
  final double monthlySalary;
  final bool canLogin;

  factory SelfEmployeeProfile.fromJson(Map<String, dynamic> json) {
    return SelfEmployeeProfile(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      roleName: json['role_name'] as String,
      scopeLevel: json['scope_level'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsappNumber: json['whatsapp_number'] as String?,
      organizationId: json['organization_id'] as int?,
      organizationName: json['organization_name'] as String?,
      stationId: json['station_id'] as int?,
      stationName: json['station_name'] as String?,
      hasEmployeeProfile: json['has_employee_profile'] == true,
      linkedEmployeeProfileId: json['linked_employee_profile_id'] as int?,
      staffType: json['staff_type'] as String?,
      staffTitle: json['staff_title'] as String?,
      employeeCode: json['employee_code'] as String?,
      nationalId: json['national_id'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] == true,
      payrollEnabled: json['payroll_enabled'] == true,
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0,
      canLogin: json['can_login'] == true,
    );
  }
}

class SelfAttendanceRecord {
  const SelfAttendanceRecord({
    required this.id,
    required this.stationId,
    required this.attendanceDate,
    required this.status,
    this.userId,
    this.employeeProfileId,
    this.checkInAt,
    this.checkOutAt,
    this.notes,
  });

  final int id;
  final int stationId;
  final int? userId;
  final int? employeeProfileId;
  final DateTime attendanceDate;
  final String status;
  final DateTime? checkInAt;
  final DateTime? checkOutAt;
  final String? notes;

  bool get isOpen => checkInAt != null && checkOutAt == null;

  factory SelfAttendanceRecord.fromJson(Map<String, dynamic> json) {
    return SelfAttendanceRecord(
      id: json['id'] as int,
      stationId: json['station_id'] as int,
      userId: json['user_id'] as int?,
      employeeProfileId: json['employee_profile_id'] as int?,
      attendanceDate: DateTime.parse(json['attendance_date'] as String),
      status: json['status'] as String,
      checkInAt: json['check_in_at'] == null
          ? null
          : DateTime.parse(json['check_in_at'] as String),
      checkOutAt: json['check_out_at'] == null
          ? null
          : DateTime.parse(json['check_out_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class SelfAttendanceSummary {
  const SelfAttendanceSummary({
    required this.enabled,
    required this.recentRecords,
    this.stationId,
    this.stationName,
    this.todayRecord,
  });

  final bool enabled;
  final int? stationId;
  final String? stationName;
  final SelfAttendanceRecord? todayRecord;
  final List<SelfAttendanceRecord> recentRecords;

  factory SelfAttendanceSummary.fromJson(Map<String, dynamic> json) {
    return SelfAttendanceSummary(
      enabled: json['enabled'] == true,
      stationId: json['station_id'] as int?,
      stationName: json['station_name'] as String?,
      todayRecord: json['today_record'] == null
          ? null
          : SelfAttendanceRecord.fromJson(
              json['today_record'] as Map<String, dynamic>,
            ),
      recentRecords: (json['recent_records'] as List<dynamic>? ?? [])
          .map(
            (item) => SelfAttendanceRecord.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class SelfPayrollPeriod {
  const SelfPayrollPeriod({
    required this.payrollRunId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.monthlySalary,
    required this.grossAmount,
    required this.attendanceDeductions,
    required this.adjustmentAdditions,
    required this.adjustmentDeductions,
    required this.deductions,
    required this.netAmount,
  });

  final int payrollRunId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final double monthlySalary;
  final double grossAmount;
  final double attendanceDeductions;
  final double adjustmentAdditions;
  final double adjustmentDeductions;
  final double deductions;
  final double netAmount;

  bool get hasBonus => adjustmentAdditions > 0;
  bool get hasExtraDeductions =>
      adjustmentDeductions > 0 || attendanceDeductions > 0;

  factory SelfPayrollPeriod.fromJson(Map<String, dynamic> json) {
    return SelfPayrollPeriod(
      payrollRunId: json['payroll_run_id'] as int,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      status: json['status'] as String,
      monthlySalary: (json['monthly_salary'] as num).toDouble(),
      grossAmount: (json['gross_amount'] as num).toDouble(),
      attendanceDeductions:
          (json['attendance_deductions'] as num).toDouble(),
      adjustmentAdditions:
          (json['adjustment_additions'] as num).toDouble(),
      adjustmentDeductions:
          (json['adjustment_deductions'] as num).toDouble(),
      deductions: (json['deductions'] as num).toDouble(),
      netAmount: (json['net_amount'] as num).toDouble(),
    );
  }
}

class SelfPayrollSummary {
  const SelfPayrollSummary({
    required this.enabled,
    required this.currentMonthlySalary,
    required this.history,
    this.latestRun,
  });

  final bool enabled;
  final double currentMonthlySalary;
  final SelfPayrollPeriod? latestRun;
  final List<SelfPayrollPeriod> history;

  factory SelfPayrollSummary.fromJson(Map<String, dynamic> json) {
    return SelfPayrollSummary(
      enabled: json['enabled'] == true,
      currentMonthlySalary:
          (json['current_monthly_salary'] as num?)?.toDouble() ?? 0,
      latestRun: json['latest_run'] == null
          ? null
          : SelfPayrollPeriod.fromJson(
              json['latest_run'] as Map<String, dynamic>,
            ),
      history: (json['history'] as List<dynamic>? ?? [])
          .map(
            (item) => SelfPayrollPeriod.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}
