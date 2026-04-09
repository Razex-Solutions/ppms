class AccountantAlertItem {
  const AccountantAlertItem({
    required this.kind,
    required this.title,
    required this.detail,
    this.entityId,
    this.amount,
  });

  final String kind;
  final int? entityId;
  final String title;
  final String detail;
  final double? amount;

  factory AccountantAlertItem.fromJson(Map<String, dynamic> json) {
    return AccountantAlertItem(
      kind: json['kind'] as String? ?? 'alert',
      entityId: json['entity_id'] as int?,
      title: json['title'] as String? ?? '-',
      detail: json['detail'] as String? ?? '-',
      amount: (json['amount'] as num?)?.toDouble(),
    );
  }
}

class AccountantWorkspaceSummary {
  const AccountantWorkspaceSummary({
    required this.overdueCustomerCount,
    required this.overdueCustomerTotal,
    required this.supplierDueCount,
    required this.supplierDueTotal,
    required this.unusualExpenseCount,
    required this.unusualExpenseTotal,
    required this.draftPayrollCount,
    required this.pendingPayrollTotal,
    required this.unreadNotificationCount,
    required this.alerts,
    this.stationId,
    this.organizationId,
  });

  final int? stationId;
  final int? organizationId;
  final int overdueCustomerCount;
  final double overdueCustomerTotal;
  final int supplierDueCount;
  final double supplierDueTotal;
  final int unusualExpenseCount;
  final double unusualExpenseTotal;
  final int draftPayrollCount;
  final double pendingPayrollTotal;
  final int unreadNotificationCount;
  final List<AccountantAlertItem> alerts;

  factory AccountantWorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return AccountantWorkspaceSummary(
      stationId: json['station_id'] as int?,
      organizationId: json['organization_id'] as int?,
      overdueCustomerCount: json['overdue_customer_count'] as int? ?? 0,
      overdueCustomerTotal:
          (json['overdue_customer_total'] as num?)?.toDouble() ?? 0,
      supplierDueCount: json['supplier_due_count'] as int? ?? 0,
      supplierDueTotal: (json['supplier_due_total'] as num?)?.toDouble() ?? 0,
      unusualExpenseCount: json['unusual_expense_count'] as int? ?? 0,
      unusualExpenseTotal:
          (json['unusual_expense_total'] as num?)?.toDouble() ?? 0,
      draftPayrollCount: json['draft_payroll_count'] as int? ?? 0,
      pendingPayrollTotal:
          (json['pending_payroll_total'] as num?)?.toDouble() ?? 0,
      unreadNotificationCount:
          json['unread_notification_count'] as int? ?? 0,
      alerts: (json['alerts'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                AccountantAlertItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class ProfitSummary {
  const ProfitSummary({
    required this.totalCashSales,
    required this.totalCreditSales,
    required this.totalPosSales,
    required this.totalSales,
    required this.totalPurchaseCost,
    required this.totalExpenses,
    required this.totalInternalFuelCost,
    required this.grossMargin,
    required this.netProfit,
  });

  final double totalCashSales;
  final double totalCreditSales;
  final double totalPosSales;
  final double totalSales;
  final double totalPurchaseCost;
  final double totalExpenses;
  final double totalInternalFuelCost;
  final double grossMargin;
  final double netProfit;

  factory ProfitSummary.fromJson(Map<String, dynamic> json) {
    return ProfitSummary(
      totalCashSales: (json['total_cash_sales'] as num?)?.toDouble() ?? 0,
      totalCreditSales: (json['total_credit_sales'] as num?)?.toDouble() ?? 0,
      totalPosSales: (json['total_pos_sales'] as num?)?.toDouble() ?? 0,
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      totalPurchaseCost:
          (json['total_purchase_cost'] as num?)?.toDouble() ?? 0,
      totalExpenses: (json['total_expenses'] as num?)?.toDouble() ?? 0,
      totalInternalFuelCost:
          (json['total_internal_fuel_cost'] as num?)?.toDouble() ?? 0,
      grossMargin: (json['gross_margin'] as num?)?.toDouble() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CustomerFinanceItem {
  const CustomerFinanceItem({
    required this.id,
    required this.name,
    required this.code,
    required this.creditLimit,
    required this.outstandingBalance,
    required this.stationId,
  });

  final int id;
  final String name;
  final String code;
  final double creditLimit;
  final double outstandingBalance;
  final int stationId;

  factory CustomerFinanceItem.fromJson(Map<String, dynamic> json) {
    return CustomerFinanceItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '-',
      code: json['code'] as String? ?? '-',
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      outstandingBalance:
          (json['outstanding_balance'] as num?)?.toDouble() ?? 0,
      stationId: json['station_id'] as int? ?? 0,
    );
  }
}

class SupplierFinanceItem {
  const SupplierFinanceItem({
    required this.id,
    required this.name,
    required this.code,
    required this.payableBalance,
  });

  final int id;
  final String name;
  final String code;
  final double payableBalance;

  factory SupplierFinanceItem.fromJson(Map<String, dynamic> json) {
    return SupplierFinanceItem(
      id: json['id'] as int,
      name: json['name'] as String? ?? '-',
      code: json['code'] as String? ?? '-',
      payableBalance: (json['payable_balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LedgerSummaryItem {
  const LedgerSummaryItem({
    required this.partyId,
    required this.partyType,
    required this.partyName,
    required this.totalCharges,
    required this.totalPayments,
    required this.currentBalance,
    required this.transactionCount,
    this.partyCode,
    this.stationId,
    this.stationName,
    this.lastActivityAt,
  });

  final int partyId;
  final String partyType;
  final String partyName;
  final String? partyCode;
  final int? stationId;
  final String? stationName;
  final double totalCharges;
  final double totalPayments;
  final double currentBalance;
  final int transactionCount;
  final DateTime? lastActivityAt;

  factory LedgerSummaryItem.fromJson(Map<String, dynamic> json) {
    return LedgerSummaryItem(
      partyId: json['party_id'] as int,
      partyType: json['party_type'] as String? ?? '-',
      partyName: json['party_name'] as String? ?? '-',
      partyCode: json['party_code'] as String?,
      stationId: json['station_id'] as int?,
      stationName: json['station_name'] as String?,
      totalCharges: (json['total_charges'] as num?)?.toDouble() ?? 0,
      totalPayments: (json['total_payments'] as num?)?.toDouble() ?? 0,
      currentBalance: (json['current_balance'] as num?)?.toDouble() ?? 0,
      transactionCount: json['transaction_count'] as int? ?? 0,
      lastActivityAt: json['last_activity_at'] == null
          ? null
          : DateTime.parse(json['last_activity_at'] as String),
    );
  }
}

class LedgerEntryItem {
  const LedgerEntryItem({
    required this.date,
    required this.type,
    required this.amount,
    required this.description,
    required this.balance,
    this.reference,
  });

  final DateTime date;
  final String type;
  final double amount;
  final String description;
  final String? reference;
  final double balance;

  factory LedgerEntryItem.fromJson(Map<String, dynamic> json) {
    return LedgerEntryItem(
      date: DateTime.parse(json['date'] as String),
      type: json['type'] as String? ?? '-',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '-',
      reference: json['reference'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

class LedgerDetail {
  const LedgerDetail({
    required this.partyId,
    required this.partyType,
    required this.partyName,
    required this.summary,
    required this.ledger,
    this.partyCode,
    this.stationId,
    this.stationName,
  });

  final int partyId;
  final String partyType;
  final String partyName;
  final String? partyCode;
  final int? stationId;
  final String? stationName;
  final LedgerSummaryItem summary;
  final List<LedgerEntryItem> ledger;

  factory LedgerDetail.fromJson(Map<String, dynamic> json) {
    return LedgerDetail(
      partyId: json['party_id'] as int,
      partyType: json['party_type'] as String? ?? '-',
      partyName: json['party_name'] as String? ?? '-',
      partyCode: json['party_code'] as String?,
      stationId: json['station_id'] as int?,
      stationName: json['station_name'] as String?,
      summary: LedgerSummaryItem.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      ledger: (json['ledger'] as List<dynamic>? ?? [])
          .map((item) => LedgerEntryItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomerPaymentItem {
  const CustomerPaymentItem({
    required this.id,
    required this.customerId,
    required this.stationId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    required this.isReversed,
    this.referenceNo,
    this.notes,
  });

  final int id;
  final int customerId;
  final int stationId;
  final double amount;
  final String paymentMethod;
  final String? referenceNo;
  final String? notes;
  final DateTime createdAt;
  final bool isReversed;

  factory CustomerPaymentItem.fromJson(Map<String, dynamic> json) {
    return CustomerPaymentItem(
      id: json['id'] as int,
      customerId: json['customer_id'] as int,
      stationId: json['station_id'] as int,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      referenceNo: json['reference_no'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isReversed: json['is_reversed'] == true,
    );
  }
}

class SupplierPaymentItem {
  const SupplierPaymentItem({
    required this.id,
    required this.supplierId,
    required this.stationId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
    required this.isReversed,
    this.referenceNo,
    this.notes,
  });

  final int id;
  final int supplierId;
  final int stationId;
  final double amount;
  final String paymentMethod;
  final String? referenceNo;
  final String? notes;
  final DateTime createdAt;
  final bool isReversed;

  factory SupplierPaymentItem.fromJson(Map<String, dynamic> json) {
    return SupplierPaymentItem(
      id: json['id'] as int,
      supplierId: json['supplier_id'] as int,
      stationId: json['station_id'] as int,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'cash',
      referenceNo: json['reference_no'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isReversed: json['is_reversed'] == true,
    );
  }
}

class ExpenseItem {
  const ExpenseItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.stationId,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  final int id;
  final String title;
  final String category;
  final double amount;
  final int stationId;
  final String status;
  final DateTime createdAt;
  final String? notes;

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? '-',
      category: json['category'] as String? ?? '-',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      stationId: json['station_id'] as int,
      status: json['status'] as String? ?? '-',
      createdAt: DateTime.parse(json['created_at'] as String),
      notes: json['notes'] as String?,
    );
  }
}

class PayrollRunItem {
  const PayrollRunItem({
    required this.id,
    required this.stationId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.totalStaff,
    required this.totalGrossAmount,
    required this.totalDeductions,
    required this.totalNetAmount,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.finalizedAt,
  });

  final int id;
  final int stationId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final int totalStaff;
  final double totalGrossAmount;
  final double totalDeductions;
  final double totalNetAmount;
  final String? notes;
  final DateTime? finalizedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDraft => status == 'draft';

  factory PayrollRunItem.fromJson(Map<String, dynamic> json) {
    return PayrollRunItem(
      id: json['id'] as int,
      stationId: json['station_id'] as int,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      status: json['status'] as String? ?? 'draft',
      totalStaff: json['total_staff'] as int? ?? 0,
      totalGrossAmount:
          (json['total_gross_amount'] as num?)?.toDouble() ?? 0,
      totalDeductions:
          (json['total_deductions'] as num?)?.toDouble() ?? 0,
      totalNetAmount: (json['total_net_amount'] as num?)?.toDouble() ?? 0,
      notes: json['notes'] as String?,
      finalizedAt: json['finalized_at'] == null
          ? null
          : DateTime.parse(json['finalized_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class PayrollLineItem {
  const PayrollLineItem({
    required this.id,
    required this.payrollRunId,
    required this.presentDays,
    required this.leaveDays,
    required this.absentDays,
    required this.payableDays,
    required this.monthlySalary,
    required this.grossAmount,
    required this.attendanceDeductions,
    required this.adjustmentAdditions,
    required this.adjustmentDeductions,
    required this.deductions,
    required this.netAmount,
    this.userId,
    this.employeeProfileId,
  });

  final int id;
  final int payrollRunId;
  final int? userId;
  final int? employeeProfileId;
  final int presentDays;
  final int leaveDays;
  final int absentDays;
  final int payableDays;
  final double monthlySalary;
  final double grossAmount;
  final double attendanceDeductions;
  final double adjustmentAdditions;
  final double adjustmentDeductions;
  final double deductions;
  final double netAmount;

  factory PayrollLineItem.fromJson(Map<String, dynamic> json) {
    return PayrollLineItem(
      id: json['id'] as int,
      payrollRunId: json['payroll_run_id'] as int,
      userId: json['user_id'] as int?,
      employeeProfileId: json['employee_profile_id'] as int?,
      presentDays: json['present_days'] as int? ?? 0,
      leaveDays: json['leave_days'] as int? ?? 0,
      absentDays: json['absent_days'] as int? ?? 0,
      payableDays: json['payable_days'] as int? ?? 0,
      monthlySalary: (json['monthly_salary'] as num?)?.toDouble() ?? 0,
      grossAmount: (json['gross_amount'] as num?)?.toDouble() ?? 0,
      attendanceDeductions:
          (json['attendance_deductions'] as num?)?.toDouble() ?? 0,
      adjustmentAdditions:
          (json['adjustment_additions'] as num?)?.toDouble() ?? 0,
      adjustmentDeductions:
          (json['adjustment_deductions'] as num?)?.toDouble() ?? 0,
      deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
      netAmount: (json['net_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ExpensePeriodSummary {
  const ExpensePeriodSummary({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.yearly,
  });

  final double daily;
  final double weekly;
  final double monthly;
  final double yearly;
}

class AccountantDashboardBundle {
  const AccountantDashboardBundle({
    required this.workspaceSummary,
    required this.profitSummary,
    required this.customers,
    required this.suppliers,
    required this.customerPayments,
    required this.supplierPayments,
    required this.expenses,
    required this.payrollRuns,
  });

  final AccountantWorkspaceSummary workspaceSummary;
  final ProfitSummary profitSummary;
  final List<CustomerFinanceItem> customers;
  final List<SupplierFinanceItem> suppliers;
  final List<CustomerPaymentItem> customerPayments;
  final List<SupplierPaymentItem> supplierPayments;
  final List<ExpenseItem> expenses;
  final List<PayrollRunItem> payrollRuns;
}
