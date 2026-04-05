import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _GovernanceSection { expenses, purchases, creditOverrides }

class GovernancePage extends StatefulWidget {
  const GovernancePage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<GovernancePage> createState() => _GovernancePageState();
}

class _GovernancePageState extends State<GovernancePage> {
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _GovernanceSection _section = _GovernanceSection.expenses;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _expenses = const [];
  List<Map<String, dynamic>> _purchases = const [];
  List<Map<String, dynamic>> _customers = const [];
  int? _selectedStationId;
  int? _selectedExpenseId;
  int? _selectedPurchaseId;
  int? _selectedCustomerId;

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  bool _hasAction(String module, String action) {
    final modulePermissions =
        widget.sessionController.permissions[module] as List<dynamic>?;
    return modulePermissions?.contains(action) ?? false;
  }

  bool get _canReviewExpenses =>
      _hasAction('expenses', 'approve') || _hasAction('expenses', 'reject');
  bool get _canReviewPurchases =>
      _hasAction('purchases', 'approve') ||
      _hasAction('purchases', 'reject') ||
      _hasAction('purchases', 'approve_reverse') ||
      _hasAction('purchases', 'reject_reverse');
  bool get _canReviewCreditOverrides =>
      _hasAction('customers', 'approve_credit_override') ||
      _hasAction('customers', 'reject_credit_override');
  bool get _showGovernanceWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['expenses', 'purchases', 'customers'],
    permissionModules: const ['expenses', 'purchases', 'customers'],
    hideWhenModulesOff: true,
  );

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
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

      final expenses = !_showGovernanceWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchExpenses(
                stationId: stationId,
                status: 'pending',
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final purchases = !_showGovernanceWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchPurchases(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final customers = !_showGovernanceWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      final filteredPurchases = purchases.where((purchase) {
        final status = purchase['status'] as String? ?? '';
        final reversalStatus = purchase['reversal_request_status'] as String?;
        return status == 'pending' || reversalStatus == 'requested';
      }).toList();
      final filteredCustomers = customers.where((customer) {
        final overrideStatus = customer['credit_override_status'] as String?;
        final requestedAmount =
            (customer['credit_override_requested_amount'] as num?)
                ?.toDouble() ??
            0;
        return overrideStatus == 'requested' || requestedAmount > 0;
      }).toList();

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _expenses = expenses;
        _purchases = filteredPurchases;
        _customers = filteredCustomers;
        _selectedExpenseId = _selectedExpenseId ?? _firstId(expenses);
        _selectedPurchaseId =
            _selectedPurchaseId ?? _firstId(filteredPurchases);
        _selectedCustomerId =
            _selectedCustomerId ?? _firstId(filteredCustomers);
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

  int? _firstId(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    return items.first['id'] as int;
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
      _selectedExpenseId = null;
      _selectedPurchaseId = null;
      _selectedCustomerId = null;
    });
    await _loadWorkspace();
  }

  Future<void> _handleDecision(bool approve) async {
    final reason =
        _emptyToNull(_reasonController.text) ??
        'Reviewed from Flutter governance screen';

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      switch (_section) {
        case _GovernanceSection.expenses:
          final expenseId = _selectedExpenseId;
          if (expenseId == null) {
            throw ApiException('Select an expense to review.');
          }
          final result = approve
              ? await widget.sessionController.approveExpense(
                  expenseId: expenseId,
                  payload: {'reason': reason},
                )
              : await widget.sessionController.rejectExpense(
                  expenseId: expenseId,
                  payload: {'reason': reason},
                );
          _feedbackMessage =
              'Expense #${result['id']} ${approve ? 'approved' : 'rejected'}.';
        case _GovernanceSection.purchases:
          final purchaseId = _selectedPurchaseId;
          if (purchaseId == null) {
            throw ApiException('Select a purchase request to review.');
          }
          final purchase = _selectedPurchase;
          final reversalRequested =
              purchase?['reversal_request_status'] == 'requested';
          final result = reversalRequested
              ? approve
                    ? await widget.sessionController.approvePurchaseReversal(
                        purchaseId: purchaseId,
                        payload: {'reason': reason},
                      )
                    : await widget.sessionController.rejectPurchaseReversal(
                        purchaseId: purchaseId,
                        payload: {'reason': reason},
                      )
              : approve
              ? await widget.sessionController.approvePurchase(
                  purchaseId: purchaseId,
                  payload: {'reason': reason},
                )
              : await widget.sessionController.rejectPurchase(
                  purchaseId: purchaseId,
                  payload: {'reason': reason},
                );
          _feedbackMessage =
              'Purchase #${result['id']} ${approve ? 'approved' : 'rejected'}.';
        case _GovernanceSection.creditOverrides:
          final customerId = _selectedCustomerId;
          if (customerId == null) {
            throw ApiException('Select a credit override request to review.');
          }
          final amount =
              (_selectedCustomer?['credit_override_requested_amount'] as num?)
                  ?.toDouble() ??
              0;
          final result = approve
              ? await widget.sessionController.approveCustomerCreditOverride(
                  customerId: customerId,
                  payload: {'amount': amount, 'reason': reason},
                )
              : await widget.sessionController.rejectCustomerCreditOverride(
                  customerId: customerId,
                  payload: {'amount': amount, 'reason': reason},
                );
          _feedbackMessage =
              'Customer ${result['name']} credit override ${approve ? 'approved' : 'rejected'}.';
      }

      if (!mounted) return;
      _reasonController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
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

  Map<String, dynamic>? get _selectedPurchase =>
      _findById(_purchases, _selectedPurchaseId);
  Map<String, dynamic>? get _selectedExpense =>
      _findById(_expenses, _selectedExpenseId);
  Map<String, dynamic>? get _selectedCustomer =>
      _findById(_customers, _selectedCustomerId);

  Map<String, dynamic>? _findById(List<Map<String, dynamic>> items, int? id) {
    for (final item in items) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  bool get _canReviewCurrentSection {
    switch (_section) {
      case _GovernanceSection.expenses:
        return _canReviewExpenses;
      case _GovernanceSection.purchases:
        return _canReviewPurchases;
      case _GovernanceSection.creditOverrides:
        return _canReviewCreditOverrides;
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showGovernanceWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Governance queues are turned off for this scope, so approval workflows stay hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableSections = <_GovernanceSection>[
      if (_canReviewExpenses) _GovernanceSection.expenses,
      if (_canReviewPurchases) _GovernanceSection.purchases,
      if (_canReviewCreditOverrides) _GovernanceSection.creditOverrides,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final sectionMeta = _sectionMeta();

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Governance Workspace',
            title: sectionMeta.$1,
            subtitle: sectionMeta.$2,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Pending queue',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _queueCountForSection().toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (_canReviewExpenses)
                  DashboardMetricTile(
                    label: 'Expense approvals',
                    value: _expenses.length.toString(),
                    caption: 'Pending expense items in scope',
                    icon: Icons.receipt_long_outlined,
                    tint: colorScheme.primary,
                  ),
                if (_canReviewPurchases)
                  DashboardMetricTile(
                    label: 'Purchase reviews',
                    value: _purchases.length.toString(),
                    caption: 'Pending purchase or reversal decisions',
                    icon: Icons.inventory_2_outlined,
                    tint: colorScheme.tertiary,
                  ),
                if (_canReviewCreditOverrides)
                  DashboardMetricTile(
                    label: 'Credit overrides',
                    value: _customers.length.toString(),
                    caption: 'Customers waiting for override review',
                    icon: Icons.rule_folder_outlined,
                    tint: colorScheme.error,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardSectionCard(
                    icon: sectionMeta.$3,
                    title: sectionMeta.$1,
                    subtitle: sectionMeta.$2,
                    child: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'governance-station-${_selectedStationId ?? 'none'}',
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<_GovernanceSection>(
                          segments: [
                            if (_canReviewExpenses)
                              const ButtonSegment(
                                value: _GovernanceSection.expenses,
                                label: Text('Expenses'),
                                icon: Icon(Icons.receipt_long_outlined),
                              ),
                            if (_canReviewPurchases)
                              const ButtonSegment(
                                value: _GovernanceSection.purchases,
                                label: Text('Purchases'),
                                icon: Icon(Icons.inventory_2_outlined),
                              ),
                            if (_canReviewCreditOverrides)
                              const ButtonSegment(
                                value: _GovernanceSection.creditOverrides,
                                label: Text('Credit'),
                                icon: Icon(Icons.rule_folder_outlined),
                              ),
                          ],
                          selected: {_section},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _section = selection.first;
                              _errorMessage = null;
                              _feedbackMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildCurrentQueue(context),
                  const SizedBox(height: 16),
                  _buildSelectedDetail(context),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonController,
                    enabled: _canReviewCurrentSection,
                    decoration: const InputDecoration(
                      labelText: 'Review Reason (optional)',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: !_canReviewCurrentSection || _isSubmitting
                            ? null
                            : () => _handleDecision(true),
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.task_alt_outlined),
                        label: const Text('Approve'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: !_canReviewCurrentSection || _isSubmitting
                            ? null
                            : () => _handleDecision(false),
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Reject'),
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

  (String, String, IconData) _sectionMeta() {
    switch (_section) {
      case _GovernanceSection.expenses:
        return (
          'Expense approvals',
          'Review expense requests with enough context to approve or reject them confidently.',
          Icons.receipt_long_outlined,
        );
      case _GovernanceSection.purchases:
        return (
          'Purchase governance',
          'Review purchase requests and reversal actions without losing the operational context.',
          Icons.inventory_2_outlined,
        );
      case _GovernanceSection.creditOverrides:
        return (
          'Credit override governance',
          'Control customer credit exceptions with a clearer view of exposure and requested override amounts.',
          Icons.rule_folder_outlined,
        );
    }
  }

  int _queueCountForSection() {
    switch (_section) {
      case _GovernanceSection.expenses:
        return _expenses.length;
      case _GovernanceSection.purchases:
        return _purchases.length;
      case _GovernanceSection.creditOverrides:
        return _customers.length;
    }
  }

  Widget _buildCurrentQueue(BuildContext context) {
    switch (_section) {
      case _GovernanceSection.expenses:
        return _buildExpenseQueue(context);
      case _GovernanceSection.purchases:
        return _buildPurchaseQueue(context);
      case _GovernanceSection.creditOverrides:
        return _buildCreditQueue(context);
    }
  }

  Widget _buildSelectedDetail(BuildContext context) {
    switch (_section) {
      case _GovernanceSection.expenses:
        return _buildDetailCard(
          context,
          title: 'Selected Expense',
          item: _selectedExpense,
          rows: _selectedExpense == null
              ? const []
              : [
                  _detailRow('ID', '#${_selectedExpense!['id']}'),
                  _detailRow('Title', _selectedExpense!['title']),
                  _detailRow('Category', _selectedExpense!['category']),
                  _detailRow(
                    'Amount',
                    _formatNumber(_selectedExpense!['amount']),
                  ),
                  _detailRow('Status', _selectedExpense!['status']),
                  _detailRow(
                    'Created',
                    _formatDateTime(_selectedExpense!['created_at']),
                  ),
                  _detailRow('Description', _selectedExpense!['description']),
                ],
        );
      case _GovernanceSection.purchases:
        return _buildDetailCard(
          context,
          title: 'Selected Purchase',
          item: _selectedPurchase,
          rows: _selectedPurchase == null
              ? const []
              : [
                  _detailRow('ID', '#${_selectedPurchase!['id']}'),
                  _detailRow(
                    'Total',
                    _formatNumber(_selectedPurchase!['total_amount']),
                  ),
                  _detailRow('Status', _selectedPurchase!['status']),
                  _detailRow(
                    'Reversal',
                    _selectedPurchase!['reversal_request_status'] ?? 'none',
                  ),
                  _detailRow(
                    'Quantity',
                    _formatNumber(_selectedPurchase!['quantity']),
                  ),
                  _detailRow(
                    'Fuel Type ID',
                    _selectedPurchase!['fuel_type_id'],
                  ),
                  _detailRow('Supplier ID', _selectedPurchase!['supplier_id']),
                  _detailRow(
                    'Created',
                    _formatDateTime(_selectedPurchase!['created_at']),
                  ),
                ],
        );
      case _GovernanceSection.creditOverrides:
        return _buildDetailCard(
          context,
          title: 'Selected Credit Request',
          item: _selectedCustomer,
          rows: _selectedCustomer == null
              ? const []
              : [
                  _detailRow('Code', _selectedCustomer!['code']),
                  _detailRow('Name', _selectedCustomer!['name']),
                  _detailRow('Type', _selectedCustomer!['customer_type']),
                  _detailRow(
                    'Current Limit',
                    _formatNumber(_selectedCustomer!['credit_limit']),
                  ),
                  _detailRow(
                    'Outstanding',
                    _formatNumber(_selectedCustomer!['outstanding_balance']),
                  ),
                  _detailRow(
                    'Requested Override',
                    _formatNumber(
                      _selectedCustomer!['credit_override_requested_amount'],
                    ),
                  ),
                  _detailRow(
                    'Override Status',
                    _selectedCustomer!['credit_override_status'],
                  ),
                ],
        );
    }
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required String title,
    required Map<String, dynamic>? item,
    required List<MapEntry<String, String>> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (item == null)
              const Text('Select an item from the queue to review its details.')
            else
              ...rows.map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('${row.key}: ${row.value}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  MapEntry<String, String> _detailRow(String label, dynamic value) {
    final text = value == null || '$value'.trim().isEmpty ? '-' : '$value';
    return MapEntry(label, text);
  }

  Widget _buildExpenseQueue(BuildContext context) {
    return _buildQueueCard(
      context,
      title: 'Pending Expenses',
      emptyText: 'No pending expenses found.',
      items: _expenses,
      selectedId: _selectedExpenseId,
      onSelect: (id) => setState(() => _selectedExpenseId = id),
      titleForItem: (item) =>
          '#${item['id']} • ${item['title']} • ${_formatNumber(item['amount'])}',
      subtitleForItem: (item) =>
          '${item['category']} • ${_formatDateTime(item['created_at'])}',
    );
  }

  Widget _buildPurchaseQueue(BuildContext context) {
    return _buildQueueCard(
      context,
      title: 'Pending Purchases / Reversals',
      emptyText: 'No pending purchase governance items found.',
      items: _purchases,
      selectedId: _selectedPurchaseId,
      onSelect: (id) => setState(() => _selectedPurchaseId = id),
      titleForItem: (item) =>
          '#${item['id']} • ${_formatNumber(item['total_amount'])}',
      subtitleForItem: (item) =>
          '${item['status']} • reversal: ${item['reversal_request_status'] ?? 'none'} • ${_formatDateTime(item['created_at'])}',
    );
  }

  Widget _buildCreditQueue(BuildContext context) {
    return _buildQueueCard(
      context,
      title: 'Credit Override Requests',
      emptyText: 'No pending credit override requests found.',
      items: _customers,
      selectedId: _selectedCustomerId,
      onSelect: (id) => setState(() => _selectedCustomerId = id),
      titleForItem: (item) =>
          '${item['code']} • ${item['name']} • request ${_formatNumber(item['credit_override_requested_amount'])}',
      subtitleForItem: (item) =>
          '${item['customer_type']} • current limit ${_formatNumber(item['credit_limit'])}',
    );
  }

  Widget _buildQueueCard(
    BuildContext context, {
    required String title,
    required String emptyText,
    required List<Map<String, dynamic>> items,
    required int? selectedId,
    required void Function(int) onSelect,
    required String Function(Map<String, dynamic>) titleForItem,
    required String Function(Map<String, dynamic>) subtitleForItem,
  }) {
    final query = _searchController.text.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? items
        : items.where((item) {
            final haystack = '${titleForItem(item)} ${subtitleForItem(item)}'
                .toLowerCase();
            return haystack.contains(query);
          }).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Queue',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (filteredItems.isEmpty)
              Text(emptyText)
            else
              for (final item in filteredItems)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  selected: item['id'] == selectedId,
                  title: Text(titleForItem(item)),
                  subtitle: Text(subtitleForItem(item)),
                  onTap: () => onSelect(item['id'] as int),
                ),
          ],
        ),
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
