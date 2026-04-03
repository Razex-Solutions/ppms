import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _expenses = const [];
  int? _selectedStationId;
  String _category = 'operations';
  String _statusFilter = 'all';

  static const _categories = <String>[
    'operations',
    'maintenance',
    'utilities',
    'salary',
    'delivery',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stations = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchStations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final preferredStationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final stationId =
          _selectedStationId ??
          preferredStationId ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      final expenses = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchExpenses(
                stationId: stationId,
                status: _statusFilter == 'all' ? null : _statusFilter,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) return;

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _expenses = expenses;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
    });
    await _loadWorkspace();
  }

  Future<void> _changeStatus(String? status) async {
    setState(() {
      _statusFilter = status ?? 'all';
    });
    await _loadWorkspace();
  }

  Future<void> _createExpense() async {
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station before creating an expense.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final expense = await widget.sessionController.createExpense({
        'title': _titleController.text.trim(),
        'category': _category,
        'amount': double.parse(_amountController.text.trim()),
        'notes': _emptyToNull(_notesController.text),
        'station_id': stationId,
      });

      if (!mounted) return;

      _titleController.clear();
      _amountController.clear();
      _notesController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Expense #${expense['id']} created with status ${expense['status']}.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expenses Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Record station expenses and monitor their review status.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              key: ValueKey<String>(
                                'expenses-station-${_selectedStationId ?? 'none'}',
                              ),
                              initialValue: _selectedStationId,
                              decoration: const InputDecoration(
                                labelText: 'Station',
                              ),
                              items: [
                                for (final station in _stations)
                                  DropdownMenuItem<int>(
                                    value: station['id'] as int,
                                    child: Text(
                                      '${station['name']} (${station['code']})',
                                    ),
                                  ),
                              ],
                              onChanged: _changeStation,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Title',
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              key: ValueKey<String>(
                                'expense-category-$_category',
                              ),
                              initialValue: _category,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                              ),
                              items: [
                                for (final category in _categories)
                                  DropdownMenuItem<String>(
                                    value: category,
                                    child: Text(category),
                                  ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _category = value ?? 'operations';
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesController,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isSubmitting ? null : _createExpense,
                              icon: _isSubmitting
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.receipt_long_outlined),
                              label: const Text('Create Expense'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Recent Expenses',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 160,
                                      child: DropdownButtonFormField<String>(
                                        key: ValueKey<String>(
                                          'expense-status-$_statusFilter',
                                        ),
                                        initialValue: _statusFilter,
                                        decoration: const InputDecoration(
                                          labelText: 'Status',
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'all',
                                            child: Text('All'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'pending',
                                            child: Text('Pending'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'approved',
                                            child: Text('Approved'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'rejected',
                                            child: Text('Rejected'),
                                          ),
                                        ],
                                        onChanged: _changeStatus,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (_expenses.isEmpty)
                                  const Text(
                                    'No expenses found for this filter.',
                                  )
                                else
                                  for (final expense in _expenses)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '#${expense['id']} • ${expense['title']} • ${_formatNumber(expense['amount'])}',
                                      ),
                                      subtitle: Text(
                                        '${expense['category']} • ${expense['status']} • ${_formatDateTime(expense['created_at'])}',
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_errorMessage != null || _feedbackMessage != null)
                    const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_feedbackMessage != null)
                    Text(
                      _feedbackMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
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
    if (value is num) return value.toStringAsFixed(2);
    return '0.00';
  }

  String _formatDateTime(dynamic value) {
    if (value is! String || value.isEmpty) return 'Unknown';
    return value.replaceFirst('T', ' ').substring(0, 16);
  }
}
