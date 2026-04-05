import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

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

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

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

      final expenses = !_showExpensesWorkspace || stationId == null
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

  bool _hasAction(String module, String action) {
    final modulePermissions =
        widget.sessionController.permissions[module] as List<dynamic>?;
    if (modulePermissions == null) {
      return false;
    }
    return modulePermissions.contains(action);
  }

  bool get _canCreateExpenses => _hasAction('expenses', 'create');
  bool get _canReadExpenses =>
      _canCreateExpenses ||
      _hasAction('expenses', 'update') ||
      _hasAction('expenses', 'delete') ||
      _hasAction('expenses', 'approve') ||
      _hasAction('expenses', 'reject');
  bool get _showExpensesWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['expenses'],
    permissionModules: const ['expenses'],
    hideWhenModulesOff: true,
  );

  Map<String, String> _workspaceMeta() {
    if (_canCreateExpenses) {
      return {
        'title': 'Expense Control',
        'subtitle':
            'Record station expenses, watch approval movement, and keep operating spend visible.',
      };
    }
    return {
      'title': 'Expense Review',
      'subtitle':
          'Inspect station expense activity and approval outcomes without changing records.',
    };
  }

  Widget _buildPermissionNotice(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showExpensesWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Expenses are turned off for this scope, so this workspace stays hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canCreateExpenses = _canCreateExpenses;
    final canReadExpenses = _canReadExpenses;
    final meta = _workspaceMeta();
    final totalAmount = _expenses.fold<double>(
      0,
      (sum, expense) => sum + ((expense['amount'] as num?)?.toDouble() ?? 0),
    );
    final pendingCount = _expenses.where((expense) {
      return expense['status']?.toString() == 'pending';
    }).length;
    final approvedCount = _expenses.where((expense) {
      return expense['status']?.toString() == 'approved';
    }).length;
    final rejectedCount = _expenses.where((expense) {
      return expense['status']?.toString() == 'rejected';
    }).length;

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Expense Control',
            title: meta['title']!,
            subtitle: meta['subtitle']!,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DashboardMetricTile(
                  label: 'Visible Expenses',
                  value: '${_expenses.length}',
                  caption: 'Current filter scope',
                  icon: Icons.receipt_long_outlined,
                  tint: Theme.of(context).colorScheme.primaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Pending',
                  value: '$pendingCount',
                  caption: 'Awaiting decision',
                  icon: Icons.pending_actions_outlined,
                  tint: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Approved',
                  value: '$approvedCount',
                  caption: 'Cleared items',
                  icon: Icons.verified_outlined,
                  tint: Theme.of(context).colorScheme.secondaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Value',
                  value: _formatNumber(totalAmount),
                  caption: '$rejectedCount rejected',
                  icon: Icons.account_balance_wallet_outlined,
                  tint: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: 'Workspace Focus',
            subtitle:
                'Keep expense capture and review in one place while staying aligned with the selected station and filter.',
            icon: Icons.rule_folder_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip(
                  context,
                  icon: Icons.store_outlined,
                  label: _selectedStationId == null
                      ? 'No station selected'
                      : 'Station #$_selectedStationId',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.filter_alt_outlined,
                  label: 'Filter: $_statusFilter',
                ),
                _buildInfoChip(
                  context,
                  icon: canCreateExpenses
                      ? Icons.edit_note_outlined
                      : Icons.visibility_outlined,
                  label: canCreateExpenses ? 'Create + review' : 'Review only',
                ),
              ],
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
                    'Expenses Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canCreateExpenses
                        ? 'Record station expenses and monitor their review status.'
                        : 'Review station expense history and approval status for the selected station.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (!canCreateExpenses) ...[
                    _buildPermissionNotice(
                      context,
                      'This role can review expenses but cannot create them from this workspace.',
                    ),
                    const SizedBox(height: 16),
                  ],
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
                              onChanged: canReadExpenses
                                  ? _changeStation
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _titleController,
                              enabled: canCreateExpenses,
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
                              onChanged: canCreateExpenses
                                  ? (value) {
                                      setState(() {
                                        _category = value ?? 'operations';
                                      });
                                    }
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _amountController,
                              enabled: canCreateExpenses,
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
                              enabled: canCreateExpenses,
                              decoration: const InputDecoration(
                                labelText: 'Notes',
                              ),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _isSubmitting || !canCreateExpenses
                                  ? null
                                  : _createExpense,
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
                                        onChanged: canReadExpenses
                                            ? _changeStatus
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (!canReadExpenses)
                                  const Text('No expense access for this role.')
                                else if (_expenses.isEmpty)
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

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}
