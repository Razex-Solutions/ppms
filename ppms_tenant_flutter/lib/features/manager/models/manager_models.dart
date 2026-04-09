class ShiftTemplateSummary {
  const ShiftTemplateSummary({
    required this.id,
    required this.stationId,
    required this.name,
    required this.windowLabel,
    required this.isActive,
  });

  final int id;
  final int stationId;
  final String name;
  final String windowLabel;
  final bool isActive;

  factory ShiftTemplateSummary.fromJson(Map<String, dynamic> json) {
    return ShiftTemplateSummary(
      id: json['id'] as int,
      stationId: json['station_id'] as int,
      name: json['name'] as String,
      windowLabel: json['window_label'] as String,
      isActive: json['is_active'] == true,
    );
  }
}

class ShiftSummary {
  const ShiftSummary({
    required this.id,
    required this.stationId,
    required this.userId,
    required this.status,
    required this.initialCash,
    required this.totalSalesCash,
    required this.totalSalesCredit,
    required this.expectedCash,
    required this.startTime,
    this.shiftTemplateId,
    this.shiftName,
    this.endTime,
    this.actualCashCollected,
    this.difference,
    this.notes,
  });

  final int id;
  final int stationId;
  final int userId;
  final int? shiftTemplateId;
  final String? shiftName;
  final String status;
  final double initialCash;
  final double totalSalesCash;
  final double totalSalesCredit;
  final double expectedCash;
  final DateTime startTime;
  final DateTime? endTime;
  final double? actualCashCollected;
  final double? difference;
  final String? notes;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) {
    return ShiftSummary(
      id: json['id'] as int,
      stationId: json['station_id'] as int,
      userId: json['user_id'] as int,
      shiftTemplateId: json['shift_template_id'] as int?,
      shiftName: json['shift_name'] as String?,
      status: json['status'] as String,
      initialCash: (json['initial_cash'] as num).toDouble(),
      totalSalesCash: (json['total_sales_cash'] as num).toDouble(),
      totalSalesCredit: (json['total_sales_credit'] as num).toDouble(),
      expectedCash: (json['expected_cash'] as num).toDouble(),
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: json['end_time'] == null
          ? null
          : DateTime.parse(json['end_time'] as String),
      actualCashCollected: (json['actual_cash_collected'] as num?)?.toDouble(),
      difference: (json['difference'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

class ManagerNozzleOpening {
  const ManagerNozzleOpening({
    required this.nozzleId,
    required this.nozzleName,
    required this.nozzleCode,
    required this.dispenserId,
    required this.dispenserName,
    required this.fuelTypeId,
    required this.tankId,
    required this.openingMeter,
    required this.currentMeter,
    required this.hasMeterAdjustmentHistory,
    this.fuelTypeName,
    this.tankName,
  });

  final int nozzleId;
  final String nozzleName;
  final String nozzleCode;
  final int dispenserId;
  final String dispenserName;
  final int fuelTypeId;
  final String? fuelTypeName;
  final int tankId;
  final String? tankName;
  final double openingMeter;
  final double currentMeter;
  final bool hasMeterAdjustmentHistory;

  factory ManagerNozzleOpening.fromJson(Map<String, dynamic> json) {
    return ManagerNozzleOpening(
      nozzleId: json['nozzle_id'] as int,
      nozzleName: json['nozzle_name'] as String,
      nozzleCode: json['nozzle_code'] as String,
      dispenserId: json['dispenser_id'] as int,
      dispenserName: json['dispenser_name'] as String,
      fuelTypeId: json['fuel_type_id'] as int,
      fuelTypeName: json['fuel_type_name'] as String?,
      tankId: json['tank_id'] as int,
      tankName: json['tank_name'] as String?,
      openingMeter: (json['opening_meter'] as num).toDouble(),
      currentMeter: (json['current_meter'] as num).toDouble(),
      hasMeterAdjustmentHistory: json['has_meter_adjustment_history'] == true,
    );
  }
}

class ManagerDispenserGroup {
  const ManagerDispenserGroup({
    required this.dispenserId,
    required this.dispenserName,
    required this.dispenserCode,
    required this.nozzles,
  });

  final int dispenserId;
  final String dispenserName;
  final String dispenserCode;
  final List<ManagerNozzleOpening> nozzles;

  factory ManagerDispenserGroup.fromJson(Map<String, dynamic> json) {
    return ManagerDispenserGroup(
      dispenserId: json['dispenser_id'] as int,
      dispenserName: json['dispenser_name'] as String,
      dispenserCode: json['dispenser_code'] as String,
      nozzles: (json['nozzles'] as List<dynamic>? ?? [])
          .map(
            (item) => ManagerNozzleOpening.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }
}

class ManagerCurrentWorkspace {
  const ManagerCurrentWorkspace({
    required this.stationId,
    required this.managerUserId,
    required this.shiftDate,
    required this.status,
    required this.message,
    required this.openingNozzleGroups,
    required this.requiresManualOpen,
    this.activeShift,
    this.matchedTemplate,
    this.openingCashPreview,
    this.activeManagerUserId,
    this.activeManagerName,
  });

  final int stationId;
  final int managerUserId;
  final int? activeManagerUserId;
  final String? activeManagerName;
  final DateTime shiftDate;
  final String status;
  final String message;
  final ShiftSummary? activeShift;
  final ShiftTemplateSummary? matchedTemplate;
  final double? openingCashPreview;
  final List<ManagerDispenserGroup> openingNozzleGroups;
  final bool requiresManualOpen;

  bool get isPrepared => status == 'prepared';
  bool get isOpen => status == 'open';
  bool get isOccupied => status == 'occupied';

  factory ManagerCurrentWorkspace.fromJson(Map<String, dynamic> json) {
    return ManagerCurrentWorkspace(
      stationId: json['station_id'] as int,
      managerUserId: json['manager_user_id'] as int,
      activeManagerUserId: json['active_manager_user_id'] as int?,
      activeManagerName: json['active_manager_name'] as String?,
      shiftDate: DateTime.parse(json['shift_date'] as String),
      status: json['status'] as String,
      message: json['message'] as String,
      activeShift: json['active_shift'] == null
          ? null
          : ShiftSummary.fromJson(json['active_shift'] as Map<String, dynamic>),
      matchedTemplate: json['matched_template'] == null
          ? null
          : ShiftTemplateSummary.fromJson(
              json['matched_template'] as Map<String, dynamic>,
            ),
      openingCashPreview: (json['opening_cash_preview'] as num?)?.toDouble(),
      openingNozzleGroups: (json['opening_nozzle_groups'] as List<dynamic>? ?? [])
          .map(
            (item) => ManagerDispenserGroup.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
      requiresManualOpen: json['requires_manual_open'] == true,
    );
  }
}

class ShiftCashSummary {
  const ShiftCashSummary({
    required this.id,
    required this.stationId,
    required this.shiftId,
    required this.managerId,
    required this.openingCash,
    required this.cashSales,
    required this.lubricantCashSales,
    required this.creditRecoveries,
    required this.creditGiven,
    required this.cashExpenses,
    required this.expectedCash,
    required this.accountableCash,
    required this.cashSubmitted,
    required this.cashInHand,
    required this.createdAt,
    required this.submissionCount,
    this.closingCash,
    this.difference,
    this.notes,
  });

  final int id;
  final int stationId;
  final int shiftId;
  final int managerId;
  final double openingCash;
  final double cashSales;
  final double lubricantCashSales;
  final double creditRecoveries;
  final double creditGiven;
  final double cashExpenses;
  final double expectedCash;
  final double accountableCash;
  final double cashSubmitted;
  final double cashInHand;
  final DateTime createdAt;
  final int submissionCount;
  final double? closingCash;
  final double? difference;
  final String? notes;

  factory ShiftCashSummary.fromJson(Map<String, dynamic> json) {
    return ShiftCashSummary(
      id: json['id'] as int,
      stationId: json['station_id'] as int,
      shiftId: json['shift_id'] as int,
      managerId: json['manager_id'] as int,
      openingCash: (json['opening_cash'] as num).toDouble(),
      cashSales: (json['cash_sales'] as num).toDouble(),
      lubricantCashSales: (json['lubricant_cash_sales'] as num? ?? 0).toDouble(),
      creditRecoveries: (json['credit_recoveries'] as num? ?? 0).toDouble(),
      creditGiven: (json['credit_given'] as num? ?? 0).toDouble(),
      cashExpenses: (json['cash_expenses'] as num? ?? 0).toDouble(),
      expectedCash: (json['expected_cash'] as num).toDouble(),
      accountableCash: (json['accountable_cash'] as num? ?? json['expected_cash'] as num).toDouble(),
      cashSubmitted: (json['cash_submitted'] as num).toDouble(),
      cashInHand: (json['cash_in_hand'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      submissionCount: json['submission_count'] as int,
      closingCash: (json['closing_cash'] as num?)?.toDouble(),
      difference: (json['difference'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }
}

class CashSubmissionItem {
  const CashSubmissionItem({
    required this.id,
    required this.shiftCashId,
    required this.amount,
    required this.submittedBy,
    required this.submittedAt,
    this.notes,
  });

  final int id;
  final int shiftCashId;
  final double amount;
  final int submittedBy;
  final DateTime submittedAt;
  final String? notes;

  factory CashSubmissionItem.fromJson(Map<String, dynamic> json) {
    return CashSubmissionItem(
      id: json['id'] as int,
      shiftCashId: json['shift_cash_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      submittedBy: json['submitted_by'] as int,
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class ShiftCloseIssue {
  const ShiftCloseIssue({
    required this.code,
    required this.title,
    required this.detail,
    required this.blocking,
    this.nozzleId,
    this.tankId,
    this.usageLiters,
  });

  final String code;
  final String title;
  final String detail;
  final bool blocking;
  final int? nozzleId;
  final int? tankId;
  final double? usageLiters;

  factory ShiftCloseIssue.fromJson(Map<String, dynamic> json) {
    return ShiftCloseIssue(
      code: json['code'] as String,
      title: json['title'] as String,
      detail: json['detail'] as String,
      blocking: json['blocking'] == true,
      nozzleId: json['nozzle_id'] as int?,
      tankId: json['tank_id'] as int?,
      usageLiters: (json['usage_liters'] as num?)?.toDouble(),
    );
  }
}

class ShiftCloseValidation {
  const ShiftCloseValidation({
    required this.shiftId,
    required this.canClose,
    required this.blockingIssueCount,
    required this.warningCount,
    required this.issues,
  });

  final int shiftId;
  final bool canClose;
  final int blockingIssueCount;
  final int warningCount;
  final List<ShiftCloseIssue> issues;

  factory ShiftCloseValidation.fromJson(Map<String, dynamic> json) {
    return ShiftCloseValidation(
      shiftId: json['shift_id'] as int,
      canClose: json['can_close'] == true,
      blockingIssueCount: json['blocking_issue_count'] as int,
      warningCount: json['warning_count'] as int,
      issues: (json['issues'] as List<dynamic>? ?? [])
          .map((item) => ShiftCloseIssue.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FuelTypeOption {
  const FuelTypeOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory FuelTypeOption.fromJson(Map<String, dynamic> json) {
    return FuelTypeOption(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class TankOption {
  const TankOption({
    required this.id,
    required this.name,
    required this.code,
    required this.capacity,
    required this.currentVolume,
    required this.fuelTypeId,
  });

  final int id;
  final String name;
  final String code;
  final double capacity;
  final double currentVolume;
  final int fuelTypeId;

  factory TankOption.fromJson(Map<String, dynamic> json) {
    return TankOption(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      capacity: (json['capacity'] as num).toDouble(),
      currentVolume: (json['current_volume'] as num).toDouble(),
      fuelTypeId: json['fuel_type_id'] as int,
    );
  }
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.creditLimit,
    required this.outstandingBalance,
    this.phone,
  });

  final int id;
  final String name;
  final String code;
  final double creditLimit;
  final double outstandingBalance;
  final String? phone;

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      creditLimit: (json['credit_limit'] as num).toDouble(),
      outstandingBalance: (json['outstanding_balance'] as num).toDouble(),
      phone: json['phone'] as String?,
    );
  }
}

class SupplierSummary {
  const SupplierSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.payableBalance,
  });

  final int id;
  final String name;
  final String code;
  final double payableBalance;

  factory SupplierSummary.fromJson(Map<String, dynamic> json) {
    return SupplierSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      payableBalance: (json['payable_balance'] as num).toDouble(),
    );
  }
}

class PosProductSummary {
  const PosProductSummary({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.module,
    required this.price,
    required this.stockQuantity,
    required this.trackInventory,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final String category;
  final String module;
  final double price;
  final double stockQuantity;
  final bool trackInventory;
  final bool isActive;

  bool get isLubricant =>
      category.toLowerCase().contains('lub') ||
      name.toLowerCase().contains('lub');

  factory PosProductSummary.fromJson(Map<String, dynamic> json) {
    return PosProductSummary(
      id: json['id'] as int,
      name: json['name'] as String,
      code: json['code'] as String,
      category: json['category'] as String,
      module: json['module'] as String,
      price: (json['price'] as num).toDouble(),
      stockQuantity: (json['stock_quantity'] as num).toDouble(),
      trackInventory: json['track_inventory'] == true,
      isActive: json['is_active'] == true,
    );
  }
}

class FuelSaleEntry {
  const FuelSaleEntry({
    required this.id,
    required this.nozzleId,
    required this.fuelTypeId,
    required this.quantity,
    required this.totalAmount,
    required this.createdAt,
  });

  final int id;
  final int nozzleId;
  final int fuelTypeId;
  final double quantity;
  final double totalAmount;
  final DateTime createdAt;

  factory FuelSaleEntry.fromJson(Map<String, dynamic> json) {
    return FuelSaleEntry(
      id: json['id'] as int,
      nozzleId: json['nozzle_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      quantity: (json['quantity'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PosSaleEntry {
  const PosSaleEntry({
    required this.id,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
    required this.module,
  });

  final int id;
  final double totalAmount;
  final DateTime createdAt;
  final List<PosSaleItemEntry> items;
  final String module;

  factory PosSaleEntry.fromJson(Map<String, dynamic> json) {
    return PosSaleEntry(
      id: json['id'] as int,
      totalAmount: (json['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      module: json['module'] as String,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => PosSaleItemEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PosSaleItemEntry {
  const PosSaleItemEntry({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final int productId;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  factory PosSaleItemEntry.fromJson(Map<String, dynamic> json) {
    return PosSaleItemEntry(
      productId: json['product_id'] as int,
      quantity: (json['quantity'] as num).toDouble(),
      unitPrice: (json['unit_price'] as num).toDouble(),
      lineTotal: (json['line_total'] as num).toDouble(),
    );
  }
}

class PurchaseEntry {
  const PurchaseEntry({
    required this.id,
    required this.supplierId,
    required this.tankId,
    required this.fuelTypeId,
    required this.quantity,
    required this.ratePerLiter,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.referenceNo,
  });

  final int id;
  final int supplierId;
  final int tankId;
  final int fuelTypeId;
  final double quantity;
  final double ratePerLiter;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final String? referenceNo;

  factory PurchaseEntry.fromJson(Map<String, dynamic> json) {
    return PurchaseEntry(
      id: json['id'] as int,
      supplierId: json['supplier_id'] as int,
      tankId: json['tank_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      quantity: (json['quantity'] as num).toDouble(),
      ratePerLiter: (json['rate_per_liter'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      referenceNo: json['reference_no'] as String?,
    );
  }
}

class ExpenseEntry {
  const ExpenseEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;
  final String? notes;

  factory ExpenseEntry.fromJson(Map<String, dynamic> json) {
    return ExpenseEntry(
      id: json['id'] as int,
      title: json['title'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class CustomerRecoveryEntry {
  const CustomerRecoveryEntry({
    required this.id,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    this.referenceNo,
    this.notes,
  });

  final int id;
  final int customerId;
  final double amount;
  final String paymentMethod;
  final DateTime createdAt;
  final String? referenceNo;
  final String? notes;

  factory CustomerRecoveryEntry.fromJson(Map<String, dynamic> json) {
    return CustomerRecoveryEntry(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      referenceNo: json['reference_no'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class CustomerCreditIssueEntry {
  const CustomerCreditIssueEntry({
    required this.id,
    required this.customerId,
    required this.stationId,
    required this.amount,
    required this.createdByUserId,
    required this.createdAt,
    this.shiftId,
    this.nozzleId,
    this.tankId,
    this.fuelTypeId,
    this.quantity,
    this.ratePerLiter,
    this.notes,
  });

  final int id;
  final int customerId;
  final int stationId;
  final int? shiftId;
  final int? nozzleId;
  final int? tankId;
  final int? fuelTypeId;
  final double? quantity;
  final double? ratePerLiter;
  final double amount;
  final int createdByUserId;
  final DateTime createdAt;
  final String? notes;

  factory CustomerCreditIssueEntry.fromJson(Map<String, dynamic> json) {
    return CustomerCreditIssueEntry(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      stationId: json['station_id'] as int,
      shiftId: json['shift_id'] as int?,
      nozzleId: json['nozzle_id'] as int?,
      tankId: json['tank_id'] as int?,
      fuelTypeId: json['fuel_type_id'] as int?,
      quantity: (json['quantity'] as num?)?.toDouble(),
      ratePerLiter: (json['rate_per_liter'] as num?)?.toDouble(),
      amount: (json['amount'] as num).toDouble(),
      createdByUserId: json['created_by_user_id'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class InternalFuelUsageEntry {
  const InternalFuelUsageEntry({
    required this.id,
    required this.tankId,
    required this.fuelTypeId,
    required this.quantity,
    required this.purpose,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final int tankId;
  final int fuelTypeId;
  final double quantity;
  final String purpose;
  final DateTime createdAt;
  final String? notes;

  factory InternalFuelUsageEntry.fromJson(Map<String, dynamic> json) {
    return InternalFuelUsageEntry(
      id: json['id'] as int,
      tankId: json['tank_id'] as int,
      fuelTypeId: json['fuel_type_id'] as int,
      quantity: (json['quantity'] as num).toDouble(),
      purpose: json['purpose'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class TankDipEntry {
  const TankDipEntry({
    required this.id,
    required this.tankId,
    required this.dipReadingMm,
    required this.calculatedVolume,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final int tankId;
  final double dipReadingMm;
  final double calculatedVolume;
  final DateTime createdAt;
  final String? notes;

  factory TankDipEntry.fromJson(Map<String, dynamic> json) {
    return TankDipEntry(
      id: json['id'] as int,
      tankId: json['tank_id'] as int,
      dipReadingMm: (json['dip_reading_mm'] as num).toDouble(),
      calculatedVolume: (json['calculated_volume'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class NotificationSummaryData {
  const NotificationSummaryData({
    required this.unread,
    required this.total,
  });

  final int unread;
  final int total;

  factory NotificationSummaryData.fromJson(Map<String, dynamic> json) {
    return NotificationSummaryData(
      unread: json['unread'] as int? ?? 0,
      total: json['total'] as int? ?? 0,
    );
  }
}

class ManagerSupportData {
  const ManagerSupportData({
    required this.fuelTypes,
    required this.tanks,
    required this.customers,
    required this.suppliers,
    required this.products,
  });

  final List<FuelTypeOption> fuelTypes;
  final List<TankOption> tanks;
  final List<CustomerSummary> customers;
  final List<SupplierSummary> suppliers;
  final List<PosProductSummary> products;

  List<PosProductSummary> get lubricants =>
      products.where((product) => product.isLubricant).toList();
}

class ManagerDashboardRequest {
  const ManagerDashboardRequest({
    required this.stationId,
    this.shiftId,
    this.fromDate,
  });

  final int stationId;
  final int? shiftId;
  final String? fromDate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagerDashboardRequest &&
          runtimeType == other.runtimeType &&
          stationId == other.stationId &&
          shiftId == other.shiftId &&
          fromDate == other.fromDate;

  @override
  int get hashCode => Object.hash(stationId, shiftId, fromDate);
}

class ManagerDashboardData {
  const ManagerDashboardData({
    required this.fuelSales,
    required this.lubricantSales,
    required this.purchases,
    required this.expenses,
    required this.recoveries,
    required this.creditIssues,
    required this.internalFuelUsages,
    required this.recentDips,
    required this.customers,
    required this.notificationSummary,
  });

  final List<FuelSaleEntry> fuelSales;
  final List<PosSaleEntry> lubricantSales;
  final List<PurchaseEntry> purchases;
  final List<ExpenseEntry> expenses;
  final List<CustomerRecoveryEntry> recoveries;
  final List<CustomerCreditIssueEntry> creditIssues;
  final List<InternalFuelUsageEntry> internalFuelUsages;
  final List<TankDipEntry> recentDips;
  final List<CustomerSummary> customers;
  final NotificationSummaryData notificationSummary;

  double get fuelSalesAmount =>
      fuelSales.fold(0, (sum, item) => sum + item.totalAmount);
  double get fuelSalesLiters =>
      fuelSales.fold(0, (sum, item) => sum + item.quantity);
  double get lubricantSalesAmount =>
      lubricantSales.fold(0, (sum, item) => sum + item.totalAmount);
  double get receivingAmount =>
      purchases.fold(0, (sum, item) => sum + item.totalAmount);
  double get receivingLiters =>
      purchases.fold(0, (sum, item) => sum + item.quantity);
  double get expenseAmount =>
      expenses.fold(0, (sum, item) => sum + item.amount);
  double get recoveryAmount =>
      recoveries.fold(0, (sum, item) => sum + item.amount);
  double get creditGivenAmount =>
      creditIssues.fold(0, (sum, item) => sum + item.amount);
  double get internalUsageLiters =>
      internalFuelUsages.fold(0, (sum, item) => sum + item.quantity);

  List<CustomerSummary> get outstandingCustomers {
    final list = customers.where((customer) => customer.outstandingBalance > 0).toList();
    list.sort(
      (left, right) => right.outstandingBalance.compareTo(left.outstandingBalance),
    );
    return list;
  }
}
