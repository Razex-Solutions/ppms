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
  final _periodStartController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _periodEndController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _notesController = TextEditingController();
  final _finalizeNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _payrollRuns = const [];
  List<Map<String, dynamic>> _selectedLines = const [];
  int? _selectedPayrollRunId;

  @override
  void initState() {
    super.initState();
    _loadPayrollRuns();
  }

  @override
  void dispose() {
    _periodStartController.dispose();
    _periodEndController.dispose();
    _notesController.dispose();
    _finalizeNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadPayrollRuns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
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

      if (!mounted) {
        return;
      }

      setState(() {
        _payrollRuns = runs;
        _selectedPayrollRunId = selectedRunId;
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
      await _loadPayrollRuns();
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
      await _loadPayrollRuns();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _payrollRuns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _payrollRuns.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final selectedRun = _selectedRun;
    final canFinalize = selectedRun != null && selectedRun['status'] == 'draft';

    return RefreshIndicator(
      onRefresh: _loadPayrollRuns,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
                          Text(
                            'Generate a payroll run from the attendance-backed payroll engine already available in the PPMS backend.',
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
                              : 'Selected run #${selectedRun['id']} • status ${selectedRun['status']} • net ${_formatNumber(selectedRun['total_net_amount'])}',
                        ),
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
                          'Run #${run['id']} • ${run['period_start']} to ${run['period_end']}',
                        ),
                        subtitle: Text(
                          'Status ${run['status']} • staff ${run['total_staff']} • net ${_formatNumber(run['total_net_amount'])}',
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
                          'User #${line['user_id']} • Net ${_formatNumber(line['net_amount'])}',
                        ),
                        subtitle: Text(
                          'Present ${line['present_days']} • Leave ${line['leave_days']} • Absent ${line['absent_days']} • Deductions ${_formatNumber(line['deductions'])}',
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

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }
}
