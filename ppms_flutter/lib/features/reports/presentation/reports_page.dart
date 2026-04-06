import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _reportDateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );
  final _fromDateController = TextEditingController(
    text: DateTime.now()
        .subtract(const Duration(days: 30))
        .toIso8601String()
        .split('T')
        .first,
  );
  final _toDateController = TextEditingController(
    text: DateTime.now()
        .add(const Duration(days: 1))
        .toIso8601String()
        .split('T')
        .first,
  );

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  Map<String, dynamic>? _dailyClosing;
  Map<String, dynamic>? _stockMovement;
  Map<String, dynamic>? _customerBalances;
  Map<String, dynamic>? _supplierBalances;
  Map<String, dynamic>? _profitSummary;
  List<Map<String, dynamic>> _exports = const [];
  List<Map<String, dynamic>> _definitions = const [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  @override
  void dispose() {
    _reportDateController.dispose();
    _fromDateController.dispose();
    _toDateController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final dailyClosing = await widget.sessionController
          .fetchDailyClosingReport(
            reportDate: _reportDateController.text.trim(),
          );
      final stockMovement = await widget.sessionController
          .fetchStockMovementReport();
      final customerBalances = await widget.sessionController
          .fetchCustomerBalancesReport();
      final supplierBalances = await widget.sessionController
          .fetchSupplierBalancesReport();
      final profitSummary = await widget.sessionController.fetchProfitSummary(
        fromDate: _fromDateController.text.trim(),
        toDate: _toDateController.text.trim(),
      );
      final exports = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchReportExports()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final definitions = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchReportDefinitions()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _dailyClosing = dailyClosing;
        _stockMovement = stockMovement;
        _customerBalances = customerBalances;
        _supplierBalances = supplierBalances;
        _profitSummary = profitSummary;
        _exports = exports;
        _definitions = definitions;
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

  Future<void> _createExport(String reportType) async {
    await _submitAction(() async {
      final export = await widget.sessionController.createReportExport({
        'report_type': reportType,
        'format': 'csv',
        'report_date': reportType == 'daily_closing'
            ? _reportDateController.text.trim()
            : null,
      });
      _feedbackMessage = 'Export job #${export['id']} created for $reportType.';
      await _loadReports();
    });
  }

  Future<void> _saveCurrentViews() async {
    await _submitAction(() async {
      final definition = await widget.sessionController.createReportDefinition({
        'name': 'Reports ${DateTime.now().toIso8601String().split('T').first}',
        'report_type': 'profit_summary',
        'is_shared': true,
        'filters': {
          'report_date': _reportDateController.text.trim(),
          'from_date': _fromDateController.text.trim(),
          'to_date': _toDateController.text.trim(),
        },
      });
      _feedbackMessage =
          'Saved report definition ${definition['name']} for reuse.';
      await _loadReports();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _dailyClosing == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _dailyClosing == null) {
      return Center(child: Text(_errorMessage!));
    }

    final stockItems = List<Map<String, dynamic>>.from(
      (_stockMovement?['items'] as List<dynamic>? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final customerItems = List<Map<String, dynamic>>.from(
      (_customerBalances?['items'] as List<dynamic>? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );
    final supplierItems = List<Map<String, dynamic>>.from(
      (_supplierBalances?['items'] as List<dynamic>? ?? const []).map(
        (item) => Map<String, dynamic>.from(item as Map),
      ),
    );

    return RefreshIndicator(
      onRefresh: _loadReports,
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
                    'Daily Closing',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _reportDateController,
                          decoration: const InputDecoration(
                            labelText: 'Report Date (YYYY-MM-DD)',
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _loadReports,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Report'),
                      ),
                      FilledButton.icon(
                        onPressed: _isSubmitting
                            ? null
                            : () => _createExport('daily_closing'),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Export CSV'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _saveCurrentViews,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Save View'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricChip(
                        label: 'Cash Inflows',
                        value: _value(_dailyClosing?['cash_inflows']),
                      ),
                      _MetricChip(
                        label: 'Cash Outflows',
                        value: _value(_dailyClosing?['cash_outflows']),
                      ),
                      _MetricChip(
                        label: 'Net Cash',
                        value: _value(_dailyClosing?['net_cash_movement']),
                      ),
                      _MetricChip(
                        label: 'Expenses',
                        value: _value(_dailyClosing?['expenses']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: 420,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Stock Movement',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _createExport('stock_movement'),
                              icon: const Icon(Icons.download_outlined),
                              tooltip: 'Export stock movement',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (stockItems.isEmpty)
                          const Text('No stock movement data found.')
                        else
                          for (final item in stockItems.take(8))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['tank_name'] as String? ?? 'Tank',
                              ),
                              subtitle: Text(
                                'Purchased ${_value(item['purchased_liters'])}L • Sold ${_value(item['sold_liters'])}L',
                              ),
                              trailing: Text(
                                '${_value(item['current_volume_liters'])}L',
                              ),
                            ),
                      ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Customer Balances',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _createExport('customer_balances'),
                              icon: const Icon(Icons.download_outlined),
                              tooltip: 'Export customer balances',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (customerItems.isEmpty)
                          const Text('No customer balances found.')
                        else
                          for (final item in customerItems.take(8))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['customer_name'] as String? ?? 'Customer',
                              ),
                              subtitle: Text(
                                'Credit limit ${_value(item['credit_limit'])}',
                              ),
                              trailing: Text(
                                _value(item['outstanding_balance']),
                              ),
                            ),
                      ],
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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Supplier Balances',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ),
                            IconButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => _createExport('supplier_balances'),
                              icon: const Icon(Icons.download_outlined),
                              tooltip: 'Export supplier balances',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (supplierItems.isEmpty)
                          const Text('No supplier balances found.')
                        else
                          for (final item in supplierItems.take(8))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                item['supplier_name'] as String? ?? 'Supplier',
                              ),
                              trailing: Text(_value(item['payable_balance'])),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profit Summary',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _fromDateController,
                          decoration: const InputDecoration(
                            labelText: 'From Date',
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          controller: _toDateController,
                          decoration: const InputDecoration(
                            labelText: 'To Date',
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _loadReports,
                        icon: const Icon(Icons.timeline_outlined),
                        label: const Text('Refresh Profit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricChip(
                        label: 'Total Sales',
                        value: _value(_profitSummary?['total_sales']),
                      ),
                      _MetricChip(
                        label: 'Purchase Cost',
                        value: _value(_profitSummary?['total_purchase_cost']),
                      ),
                      _MetricChip(
                        label: 'Gross Margin',
                        value: _value(_profitSummary?['gross_margin']),
                      ),
                      _MetricChip(
                        label: 'Internal Fuel Cost',
                        value: _value(
                          _profitSummary?['total_internal_fuel_cost'],
                        ),
                      ),
                      _MetricChip(
                        label: 'Net Profit',
                        value: _value(_profitSummary?['net_profit']),
                      ),
                    ],
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
                    'Report Exports',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (_exports.isEmpty)
                    const Text('No export jobs created yet.')
                  else
                    for (final export in _exports.take(12))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.file_download_outlined),
                        title: Text(
                          '${export['report_type']} • ${export['file_name']}',
                        ),
                        subtitle: Text(
                          'Status ${export['status']} • Created ${_displayTimestamp(export['created_at'])}',
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
                    'Saved Report Views',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  if (_definitions.isEmpty)
                    const Text('No saved report definitions yet.')
                  else
                    for (final definition in _definitions.take(10))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.bookmark_outline),
                        title: Text(
                          definition['name'] as String? ?? 'Saved report',
                        ),
                        subtitle: Text(
                          '${definition['report_type']} • shared ${definition['is_shared']}',
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

  String _value(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  String _displayTimestamp(dynamic value) {
    if (value == null) {
      return '-';
    }
    final text = value.toString().replaceFirst('T', ' ');
    return text.length >= 19 ? text.substring(0, 19) : text;
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
