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
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(label: 'Sales', value: _value(sales['total'])),
              _MetricCard(
                label: 'Expenses',
                value: _value(dashboard?['expenses']),
              ),
              _MetricCard(
                label: 'Net Profit',
                value: _value(dashboard?['net_profit']),
              ),
              _MetricCard(
                label: 'Fuel Stock (L)',
                value: _value(dashboard?['fuel_stock_liters']),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
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
                  Text('Cash sales: ${_value(sales['cash'])}'),
                  Text('Credit sales: ${_value(sales['credit'])}'),
                  Text('Receivables: ${_value(dashboard?['receivables'])}'),
                  Text('Payables: ${_value(dashboard?['payables'])}'),
                  Text(
                    'Tanker completed trips: ${tanker['completed_trips'] ?? 0}',
                  ),
                  Text('Tanker net profit: ${_value(tanker['net_profit'])}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Alerts', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
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
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
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
