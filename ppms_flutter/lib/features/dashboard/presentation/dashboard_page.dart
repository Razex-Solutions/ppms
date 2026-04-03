import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.dashboard,
    required this.onRefresh,
  });

  final Map<String, dynamic>? dashboard;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final sales = dashboard?['sales'] as Map<String, dynamic>? ?? const {};
    final tanker = dashboard?['tanker'] as Map<String, dynamic>? ?? const {};
    final alerts =
        (dashboard?['low_stock_alerts'] as List<dynamic>? ?? const []);
    final creditAlerts =
        (dashboard?['credit_limit_alerts'] as List<dynamic>? ?? const []);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1180;
              final metricWidth = desktop
                  ? (constraints.maxWidth - 48) / 4
                  : 220.0;
              final summaryCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operations Summary',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _SummaryChip(
                            label: 'Cash sales',
                            value: _value(sales['cash']),
                          ),
                          _SummaryChip(
                            label: 'Credit sales',
                            value: _value(sales['credit']),
                          ),
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
                    ],
                  ),
                ),
              );
              final alertsCard = Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alerts',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (alerts.isEmpty && creditAlerts.isEmpty)
                        const Text(
                          'No active low-stock or credit-limit alerts.',
                        )
                      else ...[
                        for (final alert in alerts)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(
                              Icons.local_gas_station_outlined,
                            ),
                            title: Text(
                              '${alert['tank_name']} is below threshold',
                            ),
                            subtitle: Text(
                              'Remaining ${alert['current_volume']}L, threshold ${alert['threshold']}L',
                            ),
                          ),
                        for (final alert in creditAlerts)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_outlined),
                            title: Text(
                              '${alert['customer_name']} is near credit limit',
                            ),
                            subtitle: Text(
                              '${alert['usage_percentage']}% of the configured limit is used',
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
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
            },
          ),
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
