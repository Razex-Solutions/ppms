import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.dashboard,
    required this.onRefresh,
    required this.roleName,
    required this.scopeLevel,
  });

  final Map<String, dynamic>? dashboard;
  final Future<void> Function() onRefresh;
  final String roleName;
  final String scopeLevel;

  @override
  Widget build(BuildContext context) {
    final sales = dashboard?['sales'] as Map<String, dynamic>? ?? const {};
    final tanker = dashboard?['tanker'] as Map<String, dynamic>? ?? const {};
    final alerts =
        (dashboard?['low_stock_alerts'] as List<dynamic>? ?? const []);
    final creditAlerts =
        (dashboard?['credit_limit_alerts'] as List<dynamic>? ?? const []);
    final roleSummary = _roleSummary(roleName, scopeLevel);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roleSummary.$1,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    roleSummary.$2,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final item in _roleFocus(roleName))
                        _SummaryChip(label: 'Focus', value: item),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildRoleDashboard(context, sales, tanker, alerts, creditAlerts),
        ],
      ),
    );
  }

  Widget _buildRoleDashboard(
    BuildContext context,
    Map<String, dynamic> sales,
    Map<String, dynamic> tanker,
    List<dynamic> alerts,
    List<dynamic> creditAlerts,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final metricWidth = desktop ? (constraints.maxWidth - 48) / 4 : 220.0;

        switch (roleName) {
          case 'HeadOffice':
            return _buildHeadOfficeLayout(
              context,
              desktop: desktop,
              metricWidth: metricWidth,
              sales: sales,
              alerts: alerts,
              creditAlerts: creditAlerts,
            );
          case 'StationAdmin':
            return _buildStationAdminLayout(
              context,
              desktop: desktop,
              metricWidth: metricWidth,
              sales: sales,
              tanker: tanker,
              alerts: alerts,
            );
          case 'Manager':
            return _buildManagerLayout(
              context,
              desktop: desktop,
              metricWidth: metricWidth,
              sales: sales,
              alerts: alerts,
              creditAlerts: creditAlerts,
            );
          case 'Accountant':
            return _buildAccountantLayout(
              context,
              desktop: desktop,
              metricWidth: metricWidth,
              sales: sales,
            );
          default:
            return _buildDefaultLayout(
              context,
              desktop: desktop,
              metricWidth: metricWidth,
              sales: sales,
              tanker: tanker,
              alerts: alerts,
              creditAlerts: creditAlerts,
            );
        }
      },
    );
  }

  Widget _buildHeadOfficeLayout(
    BuildContext context, {
    required bool desktop,
    required double metricWidth,
    required Map<String, dynamic> sales,
    required List<dynamic> alerts,
    required List<dynamic> creditAlerts,
  }) {
    final approvalsCard = _buildCard(
      context,
      'Organization Oversight',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(
            label: 'Receivables',
            value: _value(dashboard?['receivables']),
          ),
          _SummaryChip(
            label: 'Payables',
            value: _value(dashboard?['payables']),
          ),
          _SummaryChip(
            label: 'Net Profit',
            value: _value(dashboard?['net_profit']),
          ),
          _SummaryChip(
            label: 'Stock (L)',
            value: _value(dashboard?['fuel_stock_liters']),
          ),
        ],
      ),
    );
    final exceptionCard = _buildAlertsCard(
      context,
      title: 'Exceptions Requiring Attention',
      alerts: alerts,
      creditAlerts: creditAlerts,
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Total Sales',
              value: _value(sales['total']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Receivables',
              value: _value(dashboard?['receivables']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Payables',
              value: _value(dashboard?['payables']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Net Profit',
              value: _value(dashboard?['net_profit']),
              width: metricWidth,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: approvalsCard),
              const SizedBox(width: 20),
              Expanded(child: exceptionCard),
            ],
          )
        else ...[
          approvalsCard,
          const SizedBox(height: 20),
          exceptionCard,
        ],
      ],
    );
  }

  Widget _buildStationAdminLayout(
    BuildContext context, {
    required bool desktop,
    required double metricWidth,
    required Map<String, dynamic> sales,
    required Map<String, dynamic> tanker,
    required List<dynamic> alerts,
  }) {
    final readinessCard = _buildCard(
      context,
      'Station Readiness',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(
            label: 'Fuel Stock',
            value: _value(dashboard?['fuel_stock_liters']),
          ),
          _SummaryChip(
            label: 'Expenses',
            value: _value(dashboard?['expenses']),
          ),
          _SummaryChip(
            label: 'Tanker Trips',
            value: '${tanker['completed_trips'] ?? 0}',
          ),
          _SummaryChip(label: 'Cash Sales', value: _value(sales['cash'])),
        ],
      ),
    );
    final stockCard = _buildAlertsCard(
      context,
      title: 'Station Alerts',
      alerts: alerts,
      creditAlerts: const [],
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Sales',
              value: _value(sales['total']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Expenses',
              value: _value(dashboard?['expenses']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Fuel Stock (L)',
              value: _value(dashboard?['fuel_stock_liters']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Tanker Profit',
              value: _value(tanker['net_profit']),
              width: metricWidth,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: readinessCard),
              const SizedBox(width: 20),
              Expanded(child: stockCard),
            ],
          )
        else ...[
          readinessCard,
          const SizedBox(height: 20),
          stockCard,
        ],
      ],
    );
  }

  Widget _buildManagerLayout(
    BuildContext context, {
    required bool desktop,
    required double metricWidth,
    required Map<String, dynamic> sales,
    required List<dynamic> alerts,
    required List<dynamic> creditAlerts,
  }) {
    final operationsCard = _buildCard(
      context,
      'Shift and Sales Focus',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(label: 'Cash Sales', value: _value(sales['cash'])),
          _SummaryChip(label: 'Credit Sales', value: _value(sales['credit'])),
          _SummaryChip(
            label: 'Expenses',
            value: _value(dashboard?['expenses']),
          ),
          _SummaryChip(
            label: 'Stock (L)',
            value: _value(dashboard?['fuel_stock_liters']),
          ),
        ],
      ),
    );
    final alertsCard = _buildAlertsCard(
      context,
      title: 'Operational Alerts',
      alerts: alerts,
      creditAlerts: creditAlerts,
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Sales',
              value: _value(sales['total']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Cash',
              value: _value(sales['cash']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Credit',
              value: _value(sales['credit']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Fuel Stock (L)',
              value: _value(dashboard?['fuel_stock_liters']),
              width: metricWidth,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: operationsCard),
              const SizedBox(width: 20),
              Expanded(child: alertsCard),
            ],
          )
        else ...[
          operationsCard,
          const SizedBox(height: 20),
          alertsCard,
        ],
      ],
    );
  }

  Widget _buildAccountantLayout(
    BuildContext context, {
    required bool desktop,
    required double metricWidth,
    required Map<String, dynamic> sales,
  }) {
    final financeCard = _buildCard(
      context,
      'Financial Control',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(
            label: 'Receivables',
            value: _value(dashboard?['receivables']),
          ),
          _SummaryChip(
            label: 'Payables',
            value: _value(dashboard?['payables']),
          ),
          _SummaryChip(
            label: 'Expenses',
            value: _value(dashboard?['expenses']),
          ),
          _SummaryChip(
            label: 'Net Profit',
            value: _value(dashboard?['net_profit']),
          ),
        ],
      ),
    );
    final collectionCard = _buildCard(
      context,
      'Collections Snapshot',
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.point_of_sale_outlined),
            title: const Text('Cash Sales'),
            trailing: Text(_value(sales['cash'])),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.credit_score_outlined),
            title: const Text('Credit Sales'),
            trailing: Text(_value(sales['credit'])),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Receivables'),
            trailing: Text(_value(dashboard?['receivables'])),
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Payables'),
            trailing: Text(_value(dashboard?['payables'])),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Receivables',
              value: _value(dashboard?['receivables']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Payables',
              value: _value(dashboard?['payables']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Expenses',
              value: _value(dashboard?['expenses']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Net Profit',
              value: _value(dashboard?['net_profit']),
              width: metricWidth,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: financeCard),
              const SizedBox(width: 20),
              Expanded(child: collectionCard),
            ],
          )
        else ...[
          financeCard,
          const SizedBox(height: 20),
          collectionCard,
        ],
      ],
    );
  }

  Widget _buildDefaultLayout(
    BuildContext context, {
    required bool desktop,
    required double metricWidth,
    required Map<String, dynamic> sales,
    required Map<String, dynamic> tanker,
    required List<dynamic> alerts,
    required List<dynamic> creditAlerts,
  }) {
    final summaryCard = _buildCard(
      context,
      'Operations Summary',
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _SummaryChip(label: 'Cash sales', value: _value(sales['cash'])),
          _SummaryChip(label: 'Credit sales', value: _value(sales['credit'])),
          _SummaryChip(
            label: 'Receivables',
            value: _value(dashboard?['receivables']),
          ),
          _SummaryChip(
            label: 'Payables',
            value: _value(dashboard?['payables']),
          ),
          _SummaryChip(
            label: 'Tanker trips',
            value: '${tanker['completed_trips'] ?? 0}',
          ),
          _SummaryChip(
            label: 'Tanker net profit',
            value: _value(tanker['net_profit']),
          ),
        ],
      ),
    );
    final alertsCard = _buildAlertsCard(
      context,
      title: 'Alerts',
      alerts: alerts,
      creditAlerts: creditAlerts,
    );

    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              label: 'Sales',
              value: _value(sales['total']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Expenses',
              value: _value(dashboard?['expenses']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Net Profit',
              value: _value(dashboard?['net_profit']),
              width: metricWidth,
            ),
            _MetricCard(
              label: 'Fuel Stock (L)',
              value: _value(dashboard?['fuel_stock_liters']),
              width: metricWidth,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (desktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summaryCard),
              const SizedBox(width: 20),
              Expanded(child: alertsCard),
            ],
          )
        else ...[
          summaryCard,
          const SizedBox(height: 20),
          alertsCard,
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context, String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsCard(
    BuildContext context, {
    required String title,
    required List<dynamic> alerts,
    required List<dynamic> creditAlerts,
  }) {
    return _buildCard(
      context,
      title,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alerts.isEmpty && creditAlerts.isEmpty)
            const Text('No active low-stock or credit-limit alerts.')
          else ...[
            for (final alert in alerts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.local_gas_station_outlined),
                title: Text('${alert['tank_name']} is below threshold'),
                subtitle: Text(
                  'Remaining ${alert['current_volume']}L, threshold ${alert['threshold']}L',
                ),
              ),
            for (final alert in creditAlerts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text('${alert['customer_name']} is near credit limit'),
                subtitle: Text(
                  '${alert['usage_percentage']}% of the configured limit is used',
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _value(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  static (String, String) _roleSummary(String roleName, String scopeLevel) {
    switch (roleName) {
      case 'HeadOffice':
        return (
          'Head Office Dashboard',
          'Monitor organization-wide station activity, approvals, credit exposure, and management exceptions.',
        );
      case 'StationAdmin':
        return (
          'Station Admin Dashboard',
          'Keep station setup, people, modules, and daily operational readiness under control.',
        );
      case 'Manager':
        return (
          'Manager Dashboard',
          'Run daily forecourt operations, shifts, expenses, parties, and handover-sensitive work.',
        );
      case 'Accountant':
        return (
          'Finance Dashboard',
          'Track collections, supplier payments, receivables, payables, and reporting accuracy.',
        );
      case 'Operator':
        return (
          'Operations Dashboard',
          'Focus on active sales, shift execution, attendance, and real-time station activity.',
        );
      default:
        return (
          'Dashboard',
          'Current access scope: $scopeLevel. Review today’s operational and financial summary.',
        );
    }
  }

  static List<String> _roleFocus(String roleName) {
    switch (roleName) {
      case 'HeadOffice':
        return ['Approvals', 'Reports', 'Station Oversight'];
      case 'StationAdmin':
        return ['Setup', 'Users', 'Module Control'];
      case 'Manager':
        return ['Sales', 'Shifts', 'Expenses'];
      case 'Accountant':
        return ['Collections', 'Supplier Payments', 'Ledgers'];
      case 'Operator':
        return ['Forecourt Sales', 'Attendance', 'Shift Activity'];
      default:
        return ['Operations', 'Finance', 'Alerts'];
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.width = 220,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
