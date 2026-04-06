import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class PayrollPage extends StatefulWidget {
  const PayrollPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends State<PayrollPage> {
  final _createFormKey = GlobalKey<FormState>();
  final _adjustmentFormKey = GlobalKey<FormState>();
  final _periodStartController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _periodEndController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _notesController = TextEditingController();
  final _finalizeNotesController = TextEditingController();
  final _adjustmentDateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _adjustmentAmountController = TextEditingController();
  final _adjustmentReasonController = TextEditingController();
  final _adjustmentNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _payrollRuns = const [];
  List<Map<String, dynamic>> _selectedLines = const [];
  List<Map<String, dynamic>> _salaryAdjustments = const [];
  List<Map<String, dynamic>> _stationUsers = const [];
  int? _selectedPayrollRunId;
  int? _selectedAdjustmentUserId;
  String _selectedAdjustmentImpact = 'addition';

  @override
  void initState() {
    super.initState();
    _loadPayrollData();
  }

  @override
  void dispose() {
    _periodStartController.dispose();
    _periodEndController.dispose();
    _notesController.dispose();
    _finalizeNotesController.dispose();
    _adjustmentDateController.dispose();
    _adjustmentAmountController.dispose();
    _adjustmentReasonController.dispose();
    _adjustmentNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadPayrollData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final runs = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchPayrollRuns()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final selectedRunId =
          _selectedPayrollRunId ??
          (runs.isNotEmpty ? runs.first['id'] as int : null);
      final lines = selectedRunId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchPayrollLines(
                payrollRunId: selectedRunId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final adjustments = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchSalaryAdjustments(
          stationId: stationId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      );
      final users = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchUsers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _payrollRuns = runs;
        _selectedPayrollRunId = selectedRunId;
        _selectedLines = lines;
        _salaryAdjustments = adjustments;
        _stationUsers = users;
        _selectedAdjustmentUserId ??= users.isNotEmpty
            ? users.first['id'] as int
            : null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectRun(int payrollRunId) async {
    setState(() {
      _selectedPayrollRunId = payrollRunId;
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final lines = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchPayrollLines(
          payrollRunId: payrollRunId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedLines = lines;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _createRun() async {
    if (!_createFormKey.currentState!.validate()) {
      return;
    }
    final stationId =
        widget.sessionController.currentUser?['station_id'] as int?;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Your account is not assigned to a station.';
      });
      return;
    }
    await _submitAction(() async {
      final run = await widget.sessionController.createPayrollRun({
        'station_id': stationId,
        'period_start': _periodStartController.text.trim(),
        'period_end': _periodEndController.text.trim(),
        'notes': _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      });
      _notesController.clear();
      _selectedPayrollRunId = run['id'] as int;
      _feedbackMessage = 'Payroll run #${run['id']} created successfully.';
      await _loadPayrollData();
    });
  }

  Future<void> _createSalaryAdjustment() async {
    if (!_adjustmentFormKey.currentState!.validate()) {
      return;
    }
    final stationId =
        widget.sessionController.currentUser?['station_id'] as int?;
    final userId = _selectedAdjustmentUserId;
    if (stationId == null || userId == null) {
      setState(() {
        _feedbackMessage =
            'A station user is required before you can post salary adjustments.';
      });
      return;
    }
    await _submitAction(() async {
      final adjustment = await widget.sessionController.createSalaryAdjustment({
        'station_id': stationId,
        'user_id': userId,
        'effective_date': _adjustmentDateController.text.trim(),
        'impact': _selectedAdjustmentImpact,
        'amount': double.parse(_adjustmentAmountController.text.trim()),
        'reason': _adjustmentReasonController.text.trim(),
        'notes': _adjustmentNotesController.text.trim().isEmpty
            ? null
            : _adjustmentNotesController.text.trim(),
      });
      _adjustmentAmountController.clear();
      _adjustmentReasonController.clear();
      _adjustmentNotesController.clear();
      _feedbackMessage =
          'Salary adjustment #${adjustment['id']} recorded successfully.';
      await _loadPayrollData();
    });
  }

  Future<void> _finalizeRun() async {
    final selectedRun = _selectedRun;
    if (selectedRun == null) {
      setState(() {
        _feedbackMessage = 'Select a payroll run first.';
      });
      return;
    }
    await _submitAction(() async {
      final run = await widget.sessionController.finalizePayrollRun(
        payrollRunId: selectedRun['id'] as int,
        notes: _finalizeNotesController.text.trim().isEmpty
            ? null
            : _finalizeNotesController.text.trim(),
      );
      _finalizeNotesController.clear();
      _feedbackMessage = 'Payroll run #${run['id']} finalized successfully.';
      await _loadPayrollData();
    });
  }

  Future<void> _submitAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _selectedRun {
    for (final run in _payrollRuns) {
      if (run['id'] == _selectedPayrollRunId) {
        return run;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedAdjustmentUser {
    for (final user in _stationUsers) {
      if (user['id'] == _selectedAdjustmentUserId) {
        return user;
      }
    }
    return null;
  }

  double get _selectedNetTotal => _selectedLines.fold<double>(
    0,
    (total, line) => total + ((line['net_amount'] as num?)?.toDouble() ?? 0),
  );

  double get _adjustmentAdditions => _salaryAdjustments.fold<double>(
    0,
    (total, adjustment) => adjustment['impact'] == 'addition'
        ? total + ((adjustment['amount'] as num?)?.toDouble() ?? 0)
        : total,
  );

  double get _adjustmentDeductions => _salaryAdjustments.fold<double>(
    0,
    (total, adjustment) => adjustment['impact'] == 'deduction'
        ? total + ((adjustment['amount'] as num?)?.toDouble() ?? 0)
        : total,
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _payrollRuns.isEmpty && _salaryAdjustments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null &&
        _payrollRuns.isEmpty &&
        _salaryAdjustments.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final selectedRun = _selectedRun;
    final canFinalize = selectedRun != null && selectedRun['status'] == 'draft';

    return RefreshIndicator(
      onRefresh: _loadPayrollData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildWorkspaceReview(context, selectedRun: selectedRun),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 420,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _createFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Payroll Run',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Generate a payroll run from attendance plus all salary adjustments posted inside the selected period.',
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _periodStartController,
                            decoration: const InputDecoration(
                              labelText: 'Period Start (YYYY-MM-DD)',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the start date'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _periodEndController,
                            decoration: const InputDecoration(
                              labelText: 'Period End (YYYY-MM-DD)',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the end date'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isSubmitting ? null : _createRun,
                            icon: const Icon(
                              Icons.playlist_add_check_circle_outlined,
                            ),
                            label: const Text('Create Payroll Run'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _adjustmentFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Salary Adjustments',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Capture bonuses, allowances, and deductions before payroll is generated so the month closes with the right net pay.',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            initialValue: _selectedAdjustmentUserId,
                            decoration: const InputDecoration(
                              labelText: 'Employee',
                            ),
                            items: _stationUsers
                                .map(
                                  (user) => DropdownMenuItem<int>(
                                    value: user['id'] as int,
                                    child: Text(_formatUserName(user)),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedAdjustmentUserId = value;
                              });
                            },
                            validator: (value) =>
                                value == null ? 'Select the employee' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedAdjustmentImpact,
                            decoration: const InputDecoration(
                              labelText: 'Impact',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'addition',
                                child: Text('Addition'),
                              ),
                              DropdownMenuItem(
                                value: 'deduction',
                                child: Text('Deduction'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedAdjustmentImpact = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _adjustmentDateController,
                            decoration: const InputDecoration(
                              labelText: 'Effective Date (YYYY-MM-DD)',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the effective date'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _adjustmentAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter the amount';
                              }
                              return double.tryParse(value.trim()) == null
                                  ? 'Enter a valid number'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _adjustmentReasonController,
                            decoration: const InputDecoration(
                              labelText: 'Reason',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the reason'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _adjustmentNotesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _selectedAdjustmentUser == null
                                ? 'No station staff available yet.'
                                : 'Selected employee: ${_formatUserName(_selectedAdjustmentUser!)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : _createSalaryAdjustment,
                            icon: const Icon(Icons.tune_outlined),
                            label: const Text('Record Adjustment'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 420,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Finalize Payroll',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selectedRun == null
                              ? 'Select a payroll run from the list to inspect its lines and finalize it.'
                              : 'Selected run #${selectedRun['id']} | status ${selectedRun['status']} | net ${_formatNumber(selectedRun['total_net_amount'])}',
                        ),
                        if (selectedRun != null) ...[
                          const SizedBox(height: 12),
                          _buildSummaryBanner(
                            context,
                            title:
                                'Run #${selectedRun['id']} • ${selectedRun['period_start']} to ${selectedRun['period_end']}',
                            subtitle:
                                'Staff ${selectedRun['total_staff']} • Net ${_formatNumber(selectedRun['total_net_amount'])} • Status ${selectedRun['status']}',
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextField(
                          controller: _finalizeNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Finalize Notes',
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _isSubmitting || !canFinalize
                              ? null
                              : _finalizeRun,
                          icon: const Icon(Icons.task_alt_outlined),
                          label: const Text('Finalize Selected Run'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_feedbackMessage != null)
            Text(
              _feedbackMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Runs',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_payrollRuns.isEmpty)
                    const Text('No payroll runs found yet.')
                  else
                    for (final run in _payrollRuns)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.payments_outlined),
                        title: Text(
                          'Run #${run['id']} | ${run['period_start']} to ${run['period_end']}',
                        ),
                        subtitle: Text(
                          'Status ${run['status']} | staff ${run['total_staff']} | net ${_formatNumber(run['total_net_amount'])}',
                        ),
                        trailing: run['id'] == _selectedPayrollRunId
                            ? const Chip(label: Text('Selected'))
                            : null,
                        onTap: () => _selectRun(run['id'] as int),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payroll Lines',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_selectedLines.isEmpty)
                    const Text(
                      'Select a payroll run to inspect line-level payroll calculations.',
                    )
                  else
                    for (final line in _selectedLines)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text(
                          '${_formatUserNameById(line['user_id'] as int)} | Net ${_formatNumber(line['net_amount'])}',
                        ),
                        subtitle: Text(
                          'Gross ${_formatNumber(line['gross_amount'])} | Adds ${_formatNumber(line['adjustment_additions'])} | Attendance deductions ${_formatNumber(line['attendance_deductions'])} | Other deductions ${_formatNumber(line['adjustment_deductions'])}',
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Salary Adjustments',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_salaryAdjustments.isEmpty)
                    const Text(
                      'No salary adjustments recorded yet for this station.',
                    )
                  else
                    for (final adjustment in _salaryAdjustments)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          adjustment['impact'] == 'deduction'
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                        ),
                        title: Text(
                          '${adjustment['reason']} | ${_formatUserNameById(adjustment['user_id'] as int)}',
                        ),
                        subtitle: Text(
                          '${adjustment['effective_date']} | ${adjustment['impact']} | ${_formatNumber(adjustment['amount'])}',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatUserName(Map<String, dynamic> user) {
    final fullName = (user['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }
    return (user['username'] as String?) ?? 'User #${user['id']}';
  }

  String _formatUserNameById(int userId) {
    for (final user in _stationUsers) {
      if (user['id'] == userId) {
        return _formatUserName(user);
      }
    }
    return 'User #$userId';
  }

  Widget _buildWorkspaceReview(
    BuildContext context, {
    required Map<String, dynamic>? selectedRun,
  }) {
    final selectedTitle = selectedRun == null
        ? 'No payroll run selected yet'
        : 'Payroll run #${selectedRun['id']} is selected';
    final nextAction = selectedRun == null
        ? 'Create a payroll run for the period, or choose an existing run to review staff lines before finalizing.'
        : selectedRun['status'] == 'draft'
        ? 'Review net pay, additions, deductions, and attendance impact before finalizing this draft run.'
        : 'Review finalized payroll totals and line detail before starting the next period.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payroll Review',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(selectedTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(nextAction, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                context,
                icon: Icons.payments_outlined,
                label: 'Runs ${_payrollRuns.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.groups_outlined,
                label: 'Staff ${_stationUsers.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.receipt_long_outlined,
                label: 'Selected net ${_formatNumber(_selectedNetTotal)}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.add_circle_outline,
                label: 'Adds ${_formatNumber(_adjustmentAdditions)}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.remove_circle_outline,
                label: 'Deductions ${_formatNumber(_adjustmentDeductions)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }
}
