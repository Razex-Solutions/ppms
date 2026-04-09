import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/session/session_controller.dart';
import 'accountant_repository.dart';
import 'models/accountant_models.dart';

enum AccountantRangePreset { daily, weekly, monthly, yearly }

class AccountantHomeScreen extends ConsumerStatefulWidget {
  const AccountantHomeScreen({super.key});

  @override
  ConsumerState<AccountantHomeScreen> createState() =>
      _AccountantHomeScreenState();
}

class _AccountantHomeScreenState extends ConsumerState<AccountantHomeScreen> {
  late Future<AccountantDashboardBundle> _bundleFuture;
  int? _selectedCustomerId;
  int? _selectedSupplierId;
  int? _selectedPayrollRunId;
  LedgerDetail? _customerLedger;
  LedgerDetail? _supplierLedger;
  List<PayrollLineItem> _payrollLines = const [];
  bool _loadingCustomerLedger = false;
  bool _loadingSupplierLedger = false;
  bool _loadingPayrollLines = false;
  String? _actionMessage;
  String? _actionError;
  AccountantRangePreset _selectedRange = AccountantRangePreset.monthly;

  @override
  void initState() {
    super.initState();
    _bundleFuture = _loadBundle();
  }

  Future<AccountantDashboardBundle> _loadBundle() async {
    final session = ref.read(sessionControllerProvider).session;
    final stationId = session?.stationId;
    if (stationId == null) {
      throw Exception('Station scope is required for accountant workspace.');
    }
    final range = _resolveRange(_selectedRange);
    final bundle = await ref
        .read(accountantRepositoryProvider)
        .loadDashboard(
          stationId: stationId,
          fromDate: range.start,
          toDate: range.end,
        );
    _selectedCustomerId ??=
        bundle.customers.isNotEmpty ? bundle.customers.first.id : null;
    _selectedSupplierId ??=
        bundle.suppliers.isNotEmpty ? bundle.suppliers.first.id : null;
    _selectedPayrollRunId ??=
        bundle.payrollRuns.isNotEmpty ? bundle.payrollRuns.first.id : null;
    await Future.wait([
      if (_selectedCustomerId != null) _refreshCustomerLedger(_selectedCustomerId!),
      if (_selectedSupplierId != null)
        _refreshSupplierLedger(_selectedSupplierId!, stationId: stationId),
      if (_selectedPayrollRunId != null) _refreshPayrollLines(_selectedPayrollRunId!),
    ]);
    return bundle;
  }

  Future<void> _reloadAll() async {
    setState(() {
      _actionMessage = null;
      _actionError = null;
      _bundleFuture = _loadBundle();
    });
    await _bundleFuture;
  }

  Future<void> _refreshCustomerLedger(int customerId) async {
    setState(() => _loadingCustomerLedger = true);
    try {
      final ledger =
          await ref.read(accountantRepositoryProvider).getCustomerLedger(customerId);
      if (mounted) {
        setState(() => _customerLedger = ledger);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingCustomerLedger = false);
      }
    }
  }

  Future<void> _refreshSupplierLedger(
    int supplierId, {
    required int stationId,
  }) async {
    setState(() => _loadingSupplierLedger = true);
    try {
      final ledger = await ref
          .read(accountantRepositoryProvider)
          .getSupplierLedger(supplierId, stationId: stationId);
      if (mounted) {
        setState(() => _supplierLedger = ledger);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingSupplierLedger = false);
      }
    }
  }

  Future<void> _refreshPayrollLines(int payrollRunId) async {
    setState(() => _loadingPayrollLines = true);
    try {
      final lines =
          await ref.read(accountantRepositoryProvider).getPayrollLines(payrollRunId);
      if (mounted) {
        setState(() => _payrollLines = lines);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingPayrollLines = false);
      }
    }
  }

  Future<void> _performAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final saveFailedLabel = context.l10n.text('saveFailed');
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _actionMessage = successMessage;
        _actionError = null;
      });
      await _reloadAll();
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? ((error.response?.data as Map<String, dynamic>)['detail']?.toString() ??
              saveFailedLabel)
          : saveFailedLabel;
      if (mounted) {
        setState(() {
          _actionError = detail;
          _actionMessage = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _actionError = saveFailedLabel;
          _actionMessage = null;
        });
      }
    }
  }

  String _dateLabel(DateTime value) => DateFormat('dd MMM yyyy').format(value.toLocal());

  String _money(double value) => value.toStringAsFixed(0);

  _DateRange _resolveRange(AccountantRangePreset preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case AccountantRangePreset.daily:
        return _DateRange(todayStart, todayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1)));
      case AccountantRangePreset.weekly:
        final start = todayStart.subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7)).subtract(const Duration(milliseconds: 1));
        return _DateRange(start, end);
      case AccountantRangePreset.monthly:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
        return _DateRange(start, end);
      case AccountantRangePreset.yearly:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year + 1, 1, 1).subtract(const Duration(milliseconds: 1));
        return _DateRange(start, end);
    }
  }

  bool _matchesRange(DateTime value) {
    final localValue = value.toLocal();
    final range = _resolveRange(_selectedRange);
    return !localValue.isBefore(range.start) && !localValue.isAfter(range.end);
  }

  List<CustomerPaymentItem> _filteredCustomerPayments(
    List<CustomerPaymentItem> items,
  ) {
    return items.where((item) => _matchesRange(item.createdAt)).toList();
  }

  List<SupplierPaymentItem> _filteredSupplierPayments(
    List<SupplierPaymentItem> items,
  ) {
    return items.where((item) => _matchesRange(item.createdAt)).toList();
  }

  List<ExpenseItem> _filteredExpenses(List<ExpenseItem> expenses) {
    return expenses.where((item) => _matchesRange(item.createdAt)).toList();
  }

  List<PayrollRunItem> _filteredPayrollRuns(List<PayrollRunItem> runs) {
    return runs
        .where(
          (item) =>
              _matchesRange(item.createdAt) ||
              _matchesRange(item.periodStart) ||
              _matchesRange(item.periodEnd),
        )
        .toList();
  }

  String _rangeLabel(AccountantRangePreset preset) {
    switch (preset) {
      case AccountantRangePreset.daily:
        return context.l10n.text('dailySummary');
      case AccountantRangePreset.weekly:
        return context.l10n.text('weeklySummary');
      case AccountantRangePreset.monthly:
        return context.l10n.text('monthlySummary');
      case AccountantRangePreset.yearly:
        return context.l10n.text('yearlySummary');
    }
  }

  Future<void> _changeRange(AccountantRangePreset value) async {
    if (_selectedRange == value) return;
    setState(() {
      _selectedRange = value;
      _bundleFuture = _loadBundle();
    });
    await _bundleFuture;
  }

  Widget _buildRangeSelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AccountantRangePreset.values.map((preset) {
        final selected = preset == _selectedRange;
        return ChoiceChip(
          label: Text(_rangeLabel(preset)),
          selected: selected,
          onSelected: (_) => _changeRange(preset),
        );
      }).toList(),
    );
  }

  Future<void> _showCustomerPaymentDialog({
    CustomerPaymentItem? existing,
  }) async {
    final l10n = context.l10n;
    final customerId = existing?.customerId ?? _selectedCustomerId;
    if (customerId == null) return;
    final amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final referenceController =
        TextEditingController(text: existing?.referenceNo ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? context.l10n.text('recordCustomerPayment')
              : context.l10n.text('editPayment'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.l10n.text('amount')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              decoration: InputDecoration(labelText: context.l10n.text('referenceNumber')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(existing == null ? context.l10n.text('add') : context.l10n.text('updatePayment')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      setState(() => _actionError = l10n.text('saveFailed'));
      return;
    }
    final stationId = ref.read(sessionControllerProvider).session?.stationId;
    if (stationId == null) return;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(accountantRepositoryProvider).createCustomerPayment(
              customerId: customerId,
              stationId: stationId,
              amount: amount,
              referenceNo: referenceController.text.trim().isEmpty
                  ? null
                  : referenceController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
      } else {
        await ref.read(accountantRepositoryProvider).updateCustomerPayment(
              paymentId: existing.id,
              amount: amount,
              referenceNo: referenceController.text.trim().isEmpty
                  ? null
                  : referenceController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
      }
    }, successMessage: l10n.text('paymentSaved'));
  }

  Future<void> _showSupplierPaymentDialog({
    SupplierPaymentItem? existing,
  }) async {
    final l10n = context.l10n;
    final bundle = await _bundleFuture;
    final selectedSupplier = existing != null
        ? bundle.suppliers
            .where((item) => item.id == existing.supplierId)
            .cast<SupplierFinanceItem?>()
            .firstOrNull
        : bundle.suppliers
            .where((item) => item.id == _selectedSupplierId)
            .cast<SupplierFinanceItem?>()
            .firstOrNull;
    final supplierId = existing?.supplierId ?? _selectedSupplierId;
    if (supplierId == null) return;
    if (existing == null &&
        (selectedSupplier == null || selectedSupplier.payableBalance <= 0)) {
      setState(() {
        _actionError = l10n.text('supplierHasNoPayableBalance');
        _actionMessage = null;
      });
      return;
    }
    final amountController =
        TextEditingController(text: existing?.amount.toStringAsFixed(0) ?? '');
    final referenceController =
        TextEditingController(text: existing?.referenceNo ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? context.l10n.text('recordSupplierPayment')
              : context.l10n.text('editPayment'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selectedSupplier != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${l10n.text('supplierBalance')}: ${_money(selectedSupplier.payableBalance)}',
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.l10n.text('amount')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: referenceController,
              decoration: InputDecoration(labelText: context.l10n.text('referenceNumber')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(existing == null ? context.l10n.text('add') : context.l10n.text('updatePayment')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) {
      setState(() => _actionError = l10n.text('saveFailed'));
      return;
    }
    if (existing == null &&
        selectedSupplier != null &&
        amount > selectedSupplier.payableBalance) {
      setState(() {
        _actionError = l10n.text('supplierPaymentExceedsBalance');
        _actionMessage = null;
      });
      return;
    }
    final stationId = ref.read(sessionControllerProvider).session?.stationId;
    if (stationId == null) return;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(accountantRepositoryProvider).createSupplierPayment(
              supplierId: supplierId,
              stationId: stationId,
              amount: amount,
              referenceNo: referenceController.text.trim().isEmpty
                  ? null
                  : referenceController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
      } else {
        await ref.read(accountantRepositoryProvider).updateSupplierPayment(
              paymentId: existing.id,
              amount: amount,
              referenceNo: referenceController.text.trim().isEmpty
                  ? null
                  : referenceController.text.trim(),
              notes: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
            );
      }
    }, successMessage: l10n.text('paymentSaved'));
  }

  Future<void> _showExpenseEditDialog(ExpenseItem expense) async {
    final l10n = context.l10n;
    final titleController = TextEditingController(text: expense.title);
    final categoryController = TextEditingController(text: expense.category);
    final amountController =
        TextEditingController(text: expense.amount.toStringAsFixed(0));
    final notesController = TextEditingController(text: expense.notes ?? '');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('editExpense')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: context.l10n.text('description')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(labelText: context.l10n.text('expenseCategory')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: context.l10n.text('amount')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
              minLines: 2,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.text('saveLabel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountController.text.trim());
    if (amount == null) return;
    await _performAction(() async {
      await ref.read(accountantRepositoryProvider).updateExpense(
            expenseId: expense.id,
            title: titleController.text.trim(),
            category: categoryController.text.trim(),
            amount: amount,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
    }, successMessage: l10n.text('expenseUpdated'));
  }

  Future<void> _showCreatePayrollDialog() async {
    final l10n = context.l10n;
    final now = DateTime.now();
    DateTime periodStart = DateTime(now.year, now.month, 1);
    DateTime periodEnd = DateTime(now.year, now.month + 1, 0);
    final notesController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            Future<void> pickDate({required bool start}) async {
              final selected = await showDatePicker(
                context: context,
                initialDate: start ? periodStart : periodEnd,
                firstDate: DateTime(2024),
                lastDate: DateTime(2035),
              );
              if (selected != null) {
                setLocalState(() {
                  if (start) {
                    periodStart = selected;
                  } else {
                    periodEnd = selected;
                  }
                });
              }
            }

            return AlertDialog(
              title: Text(context.l10n.text('createPayrollRun')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton(
                    onPressed: () => pickDate(start: true),
                    child: Text(
                      '${context.l10n.text('periodStart')}: ${_dateLabel(periodStart)}',
                    ),
                  ),
                  TextButton(
                    onPressed: () => pickDate(start: false),
                    child: Text(
                      '${context.l10n.text('periodEnd')}: ${_dateLabel(periodEnd)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('optionalNotes'),
                    ),
                    minLines: 2,
                    maxLines: 3,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.text('cancelLabel')),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.text('createPayroll')),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true) return;
    final stationId = ref.read(sessionControllerProvider).session?.stationId;
    if (stationId == null) return;
    await _performAction(() async {
      await ref.read(accountantRepositoryProvider).createPayrollRun(
            stationId: stationId,
            periodStart: periodStart,
            periodEnd: periodEnd,
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
    }, successMessage: l10n.text('payrollRunCreated'));
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    return FutureBuilder<AccountantDashboardBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || session == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.text('loadFailed')),
            ),
          );
        }
        final bundle = snapshot.data!;
        final filteredExpenses = _filteredExpenses(bundle.expenses);
        final filteredCustomerPayments =
            _filteredCustomerPayments(bundle.customerPayments);
        final filteredSupplierPayments =
            _filteredSupplierPayments(bundle.supplierPayments);
        final filteredPayrollRuns = _filteredPayrollRuns(bundle.payrollRuns);
        final expenseSummary = ExpensePeriodSummary(
          daily: filteredExpenses.fold(0, (sum, item) => sum + item.amount),
          weekly: filteredExpenses.fold(0, (sum, item) => sum + item.amount),
          monthly: filteredExpenses.fold(0, (sum, item) => sum + item.amount),
          yearly: filteredExpenses.fold(0, (sum, item) => sum + item.amount),
        );
        final selectedPayroll = filteredPayrollRuns
            .where((item) => item.id == _selectedPayrollRunId)
            .cast<PayrollRunItem?>()
            .firstOrNull;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.l10n.text('accountantTitle'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.text('accountantSubtitle'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _buildRangeSelector(),
            if (_actionMessage != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(
                message: _actionMessage!,
                color: Colors.green.shade700,
              ),
            ],
            if (_actionError != null) ...[
              const SizedBox(height: 12),
              _MessageBanner(
                message: _actionError!,
                color: Theme.of(context).colorScheme.error,
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  title: context.l10n.text('overdueCustomers'),
                  value: _money(bundle.workspaceSummary.overdueCustomerTotal),
                  subtitle:
                      '${bundle.workspaceSummary.overdueCustomerCount} ${context.l10n.text('entries')}',
                ),
                _MetricCard(
                  title: context.l10n.text('supplierDues'),
                  value: _money(bundle.workspaceSummary.supplierDueTotal),
                  subtitle:
                      '${bundle.workspaceSummary.supplierDueCount} ${context.l10n.text('entries')}',
                ),
                _MetricCard(
                  title: context.l10n.text('unusualExpenses'),
                  value: _money(bundle.workspaceSummary.unusualExpenseTotal),
                  subtitle:
                      '${bundle.workspaceSummary.unusualExpenseCount} ${context.l10n.text('entries')}',
                ),
                _MetricCard(
                  title: context.l10n.text('draftPayroll'),
                  value: _money(bundle.workspaceSummary.pendingPayrollTotal),
                  subtitle:
                      '${bundle.workspaceSummary.draftPayrollCount} ${context.l10n.text('entries')}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildAlertsSection(bundle),
            const SizedBox(height: 24),
            _buildFinanceSummarySection(bundle),
            const SizedBox(height: 24),
            _buildCustomerSection(bundle, filteredCustomerPayments),
            const SizedBox(height: 24),
            _buildSupplierSection(
              bundle,
              session.stationId ?? 0,
              filteredSupplierPayments,
            ),
            const SizedBox(height: 24),
            _buildExpenseSection(filteredExpenses, expenseSummary),
            const SizedBox(height: 24),
            _buildPayrollSection(filteredPayrollRuns, selectedPayroll),
          ],
        );
      },
    );
  }

  Widget _buildAlertsSection(AccountantDashboardBundle bundle) {
    return _SectionCard(
      title: context.l10n.text('financeAlerts'),
      child: bundle.workspaceSummary.alerts.isEmpty
          ? Text(context.l10n.text('noRecentItems'))
          : Column(
              children: bundle.workspaceSummary.alerts
                  .map(
                    (alert) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(alert.title),
                      subtitle: Text(alert.detail),
                      trailing: alert.amount == null
                          ? null
                          : Text(_money(alert.amount!)),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildFinanceSummarySection(AccountantDashboardBundle bundle) {
    return _SectionCard(
      title: context.l10n.text('financeSummary'),
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _MetricCard(
            title: context.l10n.text('totalSalesLabel'),
            value: _money(bundle.profitSummary.totalSales),
            subtitle: context.l10n.text('grossAmount'),
            width: 220,
          ),
          _MetricCard(
            title: context.l10n.text('totalPurchasesLabel'),
            value: _money(bundle.profitSummary.totalPurchaseCost),
            subtitle: context.l10n.text('supplierDues'),
            width: 220,
          ),
          _MetricCard(
            title: context.l10n.text('expenseCard'),
            value: _money(bundle.profitSummary.totalExpenses),
            subtitle: context.l10n.text('expenseWorkspace'),
            width: 220,
          ),
          _MetricCard(
            title: context.l10n.text('netProfitLabel'),
            value: _money(bundle.profitSummary.netProfit),
            subtitle: context.l10n.text('accountantWorkspace'),
            width: 220,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(
    AccountantDashboardBundle bundle,
    List<CustomerPaymentItem> filteredPayments,
  ) {
    return _SectionCard(
      title: context.l10n.text('customerLedger'),
      action: FilledButton.tonalIcon(
        onPressed: _showCustomerPaymentDialog,
        icon: const Icon(Icons.add_card_outlined),
        label: Text(context.l10n.text('recordCustomerPayment')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: bundle.customers.any((item) => item.id == _selectedCustomerId)
                ? _selectedCustomerId
                : null,
            items: bundle.customers
                .map(
                  (customer) => DropdownMenuItem(
                    value: customer.id,
                    child: Text('${customer.name} (${customer.code})'),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedCustomerId = value);
              await _refreshCustomerLedger(value);
            },
            decoration: InputDecoration(labelText: context.l10n.text('customer')),
          ),
          const SizedBox(height: 16),
          if (_loadingCustomerLedger)
            const LinearProgressIndicator()
          else if (_customerLedger == null)
            Text(context.l10n.text('noDataYet'))
          else ...[
            _LedgerSummaryView(
              summary: _customerLedger!.summary,
              highlightLabel: context.l10n.text('customerExposure'),
            ),
            const SizedBox(height: 16),
            _TransactionList(
              items: _customerLedger!.ledger,
              emptyLabel: context.l10n.text('noDataYet'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.l10n.text('recentPayments'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...filteredPayments.take(8).map(
            (payment) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_money(payment.amount)),
              subtitle: Text(
                '${payment.referenceNo ?? context.l10n.text('notAvailableLabel')} - ${_dateLabel(payment.createdAt)}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _showCustomerPaymentDialog(existing: payment),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(context.l10n.text('editLabel')),
                  ),
                  TextButton.icon(
                    onPressed: () => _performAction(
                      () => ref.read(accountantRepositoryProvider).deleteCustomerPayment(payment.id),
                      successMessage: context.l10n.text('paymentDeleted'),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(context.l10n.text('deleteLabel')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierSection(
    AccountantDashboardBundle bundle,
    int stationId,
    List<SupplierPaymentItem> filteredPayments,
  ) {
    return _SectionCard(
      title: context.l10n.text('supplierLedger'),
      action: FilledButton.tonalIcon(
        onPressed: _showSupplierPaymentDialog,
        icon: const Icon(Icons.account_balance_outlined),
        label: Text(context.l10n.text('recordSupplierPayment')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: bundle.suppliers.any((item) => item.id == _selectedSupplierId)
                ? _selectedSupplierId
                : null,
            items: bundle.suppliers
                .map(
                  (supplier) => DropdownMenuItem(
                    value: supplier.id,
                    child: Text(
                      '${supplier.name} (${supplier.code}) - ${_money(supplier.payableBalance)}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedSupplierId = value);
              await _refreshSupplierLedger(value, stationId: stationId);
            },
            decoration: InputDecoration(labelText: context.l10n.text('supplier')),
          ),
          const SizedBox(height: 16),
          if (_loadingSupplierLedger)
            const LinearProgressIndicator()
          else if (_supplierLedger == null)
            Text(context.l10n.text('noDataYet'))
          else ...[
            _LedgerSummaryView(
              summary: _supplierLedger!.summary,
              highlightLabel: context.l10n.text('supplierBalance'),
            ),
            const SizedBox(height: 16),
            _TransactionList(
              items: _supplierLedger!.ledger,
              emptyLabel: context.l10n.text('noDataYet'),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            context.l10n.text('recentPayments'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...filteredPayments.take(8).map(
            (payment) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_money(payment.amount)),
              subtitle: Text(
                '${payment.referenceNo ?? context.l10n.text('notAvailableLabel')} - ${_dateLabel(payment.createdAt)}',
              ),
              trailing: Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () => _showSupplierPaymentDialog(existing: payment),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(context.l10n.text('editLabel')),
                  ),
                  TextButton.icon(
                    onPressed: () => _performAction(
                      () => ref.read(accountantRepositoryProvider).deleteSupplierPayment(payment.id),
                      successMessage: context.l10n.text('paymentDeleted'),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(context.l10n.text('deleteLabel')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseSection(
    List<ExpenseItem> filteredExpenses,
    ExpensePeriodSummary expenseSummary,
  ) {
    return _SectionCard(
      title: context.l10n.text('expenseWorkspace'),
      action: FilledButton.tonalIcon(
        onPressed: _reloadAll,
        icon: const Icon(Icons.refresh_outlined),
        label: Text(context.l10n.text('refreshLabel')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(title: _rangeLabel(_selectedRange), value: _money(expenseSummary.daily), width: 180),
              _MetricCard(title: context.l10n.text('entries'), value: '${filteredExpenses.length}', width: 180),
            ],
          ),
          const SizedBox(height: 16),
          ...filteredExpenses.take(12).map(
            (expense) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${expense.title} - ${expense.category}'),
              subtitle: Text('${expense.status} - ${_dateLabel(expense.createdAt)}'),
              trailing: Wrap(
                spacing: 8,
                children: [
                  Text(_money(expense.amount)),
                  TextButton.icon(
                    onPressed: () => _showExpenseEditDialog(expense),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(context.l10n.text('editLabel')),
                  ),
                  TextButton.icon(
                    onPressed: () => _performAction(
                      () => ref.read(accountantRepositoryProvider).deleteExpense(expense.id),
                      successMessage: context.l10n.text('expenseDeleted'),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(context.l10n.text('deleteLabel')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayrollSection(
    List<PayrollRunItem> filteredRuns,
    PayrollRunItem? selectedPayroll,
  ) {
    return _SectionCard(
      title: context.l10n.text('payrollWorkspace'),
      action: FilledButton.tonalIcon(
        onPressed: _showCreatePayrollDialog,
        icon: const Icon(Icons.payments_outlined),
        label: Text(context.l10n.text('createPayrollRun')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: filteredRuns.any((item) => item.id == _selectedPayrollRunId)
                ? _selectedPayrollRunId
                : null,
            items: filteredRuns
                .map(
                  (run) => DropdownMenuItem(
                    value: run.id,
                    child: Text(
                      '#${run.id} - ${_dateLabel(run.periodStart)} to ${_dateLabel(run.periodEnd)} - ${run.status}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedPayrollRunId = value);
              await _refreshPayrollLines(value);
            },
            decoration: InputDecoration(labelText: context.l10n.text('payrollRuns')),
          ),
          const SizedBox(height: 16),
          if (selectedPayroll != null)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(title: context.l10n.text('grossAmount'), value: _money(selectedPayroll.totalGrossAmount), width: 180),
                _MetricCard(title: context.l10n.text('deductions'), value: _money(selectedPayroll.totalDeductions), width: 180),
                _MetricCard(title: context.l10n.text('netAmount'), value: _money(selectedPayroll.totalNetAmount), width: 180),
                _MetricCard(title: context.l10n.text('staffCount'), value: '${selectedPayroll.totalStaff}', width: 180),
              ],
            ),
          if (selectedPayroll?.isDraft == true) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _performAction(
                () => ref.read(accountantRepositoryProvider).finalizePayrollRun(selectedPayroll!.id),
                successMessage: context.l10n.text('payrollFinalized'),
              ),
              child: Text(context.l10n.text('finalizePayroll')),
            ),
          ],
          const SizedBox(height: 16),
          if (_loadingPayrollLines)
            const LinearProgressIndicator()
          else if (_payrollLines.isEmpty)
            Text(context.l10n.text('noDataYet'))
          else
            ..._payrollLines.map(
              (line) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${context.l10n.text('employeeCode')} ${line.userId ?? line.employeeProfileId ?? '-'}',
                ),
                subtitle: Text(
                  '${context.l10n.text('grossAmount')}: ${_money(line.grossAmount)} · ${context.l10n.text('deductions')}: ${_money(line.deductions)}',
                ),
                trailing: Text(_money(line.netAmount)),
              ),
            ),
        ],
      ),
    );
  }
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleLarge),
                ),
                if (action != null) ...[action!],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.width = 240,
  });

  final String title;
  final String value;
  final String? subtitle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerSummaryView extends StatelessWidget {
  const _LedgerSummaryView({
    required this.summary,
    required this.highlightLabel,
  });

  final LedgerSummaryItem summary;
  final String highlightLabel;

  String _money(double value) => value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _MetricCard(title: highlightLabel, value: _money(summary.currentBalance), width: 180),
        _MetricCard(title: context.l10n.text('totalChargesLabel'), value: _money(summary.totalCharges), width: 180),
        _MetricCard(title: context.l10n.text('totalPaymentsLabel'), value: _money(summary.totalPayments), width: 180),
        _MetricCard(title: context.l10n.text('transactionCountLabel'), value: '${summary.transactionCount}', width: 180),
      ],
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.items,
    required this.emptyLabel,
  });

  final List<LedgerEntryItem> items;
  final String emptyLabel;

  String _money(double value) => value.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyLabel);
    }
    return Column(
      children: items.reversed.take(10).map((entry) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(entry.description),
          subtitle: Text(
            '${DateFormat('dd MMM yyyy').format(entry.date.toLocal())} - ${entry.reference ?? context.l10n.text('notAvailableLabel')}',
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(entry.amount)),
              Text(_money(entry.balance)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
