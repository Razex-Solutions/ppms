import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.sessionController,
    required this.dashboard,
    required this.onRefresh,
    required this.roleName,
    required this.scopeLevel,
  });

  final SessionController sessionController;
  final Map<String, dynamic>? dashboard;
  final Future<void> Function() onRefresh;
  final String roleName;
  final String scopeLevel;

  @override
  Widget build(BuildContext context) {
    final capabilities = SessionCapabilities(sessionController);
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
                      for (final item in _roleFocus(roleName, capabilities))
                        _SummaryChip(label: 'Focus', value: item),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (roleName == 'HeadOffice')
            _buildHeadOfficeLayout(
              context,
              capabilities,
              sales,
              alerts,
              creditAlerts,
            )
          else if (roleName == 'StationAdmin')
            _buildStationAdminLayout(
              context,
              capabilities,
              sales,
              tanker,
              alerts,
            )
          else if (roleName == 'Manager')
            _buildManagerLayout(
              context,
              capabilities,
              sales,
              alerts,
              creditAlerts,
            )
          else if (roleName == 'Accountant')
            _buildAccountantLayout(
              context,
              capabilities,
              sales,
              alerts,
              creditAlerts,
            )
          else if (roleName == 'Operator')
            _buildOperatorLayout(
              context,
              capabilities,
              sales,
              alerts,
            )
          else
            _buildGeneralLayout(
              context,
              capabilities,
              sales,
              tanker,
              alerts,
              creditAlerts,
            ),
        ],
      ),
    );
  }

  Widget _buildHeadOfficeLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    List<dynamic> alerts,
    List<dynamic> creditAlerts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final receivables = _num(dashboard?['receivables']);
    final payables = _num(dashboard?['payables']);
    final stock = _num(dashboard?['fuel_stock_liters']);
    final profit = _num(dashboard?['net_profit']);
    final salesTotal = _num(sales['total']);
    final cashSales = _num(sales['cash']);
    final creditSales = _num(sales['credit']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final overviewCard = DashboardSectionCard(
          icon: Icons.hub_outlined,
          title: 'Organization oversight',
          subtitle:
              'Use these balances to spot collection pressure, supplier exposure, and liquidity trends.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Receivables',
                trailingLabel: 'Payables',
                leadingValue: receivables,
                trailingValue: payables,
                leadingColor: colorScheme.primary,
                trailingColor: colorScheme.secondary,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_canShowFinanceSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Net profit',
                      value: _value(profit),
                      caption: 'Current profitability signal from the backend summary',
                      icon: Icons.trending_up_outlined,
                      tint: colorScheme.primary,
                    ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Organization-wide liters currently in tanks',
                      icon: Icons.local_gas_station_outlined,
                      tint: colorScheme.secondary,
                    ),
                ],
              ),
            ],
          ),
        );
        final salesMixCard = DashboardSectionCard(
          icon: Icons.pie_chart_outline,
          title: 'Sales mix',
          subtitle:
              'Understand how much of the day is staying liquid versus becoming credit exposure.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Cash sales',
                trailingLabel: 'Credit sales',
                leadingValue: cashSales,
                trailingValue: creditSales,
                leadingColor: colorScheme.tertiary,
                trailingColor: colorScheme.error,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DashboardMetricTile(
                    label: 'Total sales',
                    value: _value(salesTotal),
                    caption: 'Aggregate sales value currently visible to HeadOffice',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.tertiary,
                  ),
                  DashboardMetricTile(
                    label: 'Alert volume',
                    value: '${alerts.length + creditAlerts.length}',
                    caption: 'Low stock and credit-limit exceptions needing review',
                    icon: Icons.rule_folder_outlined,
                    tint: colorScheme.error,
                  ),
                ],
              ),
            ],
          ),
        );
        final exceptionCard = DashboardSectionCard(
          icon: Icons.priority_high_outlined,
          title: 'Exceptions requiring attention',
          subtitle:
              'Low stock and customer credit pressure should be reviewed before they become station escalations.',
          child: DashboardAttentionList(
            emptyLabel: 'No active low-stock or credit-limit alerts.',
            items: [
              for (final alert in alerts)
                DashboardAttentionItem(
                  title: '${alert['tank_name']} is below threshold',
                  subtitle:
                      'Remaining ${alert['current_volume']}L, threshold ${alert['threshold']}L.',
                  icon: Icons.local_gas_station_outlined,
                  color: colorScheme.secondary,
                ),
              for (final alert in creditAlerts)
                DashboardAttentionItem(
                  title: '${alert['customer_name']} is near credit limit',
                  subtitle:
                      '${alert['usage_percentage']}% of the configured limit is already used.',
                  icon: Icons.warning_amber_outlined,
                  color: colorScheme.error,
                ),
            ],
          ),
        );

        return Column(
          children: [
            DashboardHeroCard(
              eyebrow: 'Head Office',
              title: 'Organization health at a glance',
              subtitle:
                  'Track liquidity, stock pressure, and oversight exceptions without dropping into station-by-station operations.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DashboardMetricTile(
                    label: 'Total sales',
                    value: _value(salesTotal),
                    caption: 'Today across visible stations',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.primary,
                  ),
                  if (_canShowFinanceSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Receivables',
                      value: _value(receivables),
                      caption: 'Collections still outstanding',
                      icon: Icons.account_balance_wallet_outlined,
                      tint: colorScheme.primary,
                    ),
                  if (_canShowFinanceSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Payables',
                      value: _value(payables),
                      caption: 'Supplier obligations visible now',
                      icon: Icons.payments_outlined,
                      tint: colorScheme.secondary,
                    ),
                  if (_canShowFinanceSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Net profit',
                      value: _value(profit),
                      caption: 'Profitability snapshot from the current dashboard payload',
                      icon: Icons.insights_outlined,
                      tint: colorScheme.tertiary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: overviewCard),
                  const SizedBox(width: 20),
                  Expanded(child: salesMixCard),
                ],
              )
            else ...[
              overviewCard,
              const SizedBox(height: 20),
              salesMixCard,
            ],
            const SizedBox(height: 20),
            exceptionCard,
          ],
        );
      },
    );
  }

  Widget _buildGeneralLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    Map<String, dynamic> tanker,
    List<dynamic> alerts,
    List<dynamic> creditAlerts,
  ) {
    final metricCards = <Widget>[
      if (_canShowSalesSummary(capabilities))
        _MetricCard(label: 'Sales', value: _value(sales['total'])),
      if (_canShowExpensesSummary(capabilities))
        _MetricCard(label: 'Expenses', value: _value(dashboard?['expenses'])),
      if (_canShowFinanceSummary(capabilities))
        _MetricCard(label: 'Net Profit', value: _value(dashboard?['net_profit'])),
      if (_canShowInventorySummary(capabilities))
        _MetricCard(
          label: 'Fuel Stock (L)',
          value: _value(dashboard?['fuel_stock_liters']),
        ),
      if (_canShowTankerSummary(capabilities))
        _MetricCard(
          label: 'Tanker Profit',
          value: _value(tanker['net_profit']),
        ),
    ];

    return Column(
      children: [
        Wrap(spacing: 16, runSpacing: 16, children: metricCards),
        const SizedBox(height: 20),
        _buildAlertsCard(
          context,
          title: 'Alerts',
          alerts: alerts,
          creditAlerts: creditAlerts,
        ),
      ],
    );
  }

  Widget _buildStationAdminLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    Map<String, dynamic> tanker,
    List<dynamic> alerts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final stock = _num(dashboard?['fuel_stock_liters']);
    final expenses = _num(dashboard?['expenses']);
    final salesTotal = _num(sales['total']);
    final cashSales = _num(sales['cash']);
    final creditSales = _num(sales['credit']);
    final tankerProfit = _num(tanker['net_profit']);
    final tankerTrips = _num(tanker['completed_trips']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final readinessCard = DashboardSectionCard(
          icon: Icons.fact_check_outlined,
          title: 'Station readiness',
          subtitle:
              'Track whether this station is balanced across sales, expenses, stock, and optional modules.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Cash sales',
                trailingLabel: 'Credit sales',
                leadingValue: cashSales,
                trailingValue: creditSales,
                leadingColor: colorScheme.primary,
                trailingColor: colorScheme.tertiary,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Liters available across active tanks',
                      icon: Icons.inventory_2_outlined,
                      tint: colorScheme.secondary,
                    ),
                  if (_canShowExpensesSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Expenses',
                      value: _value(expenses),
                      caption: 'Current visible operational spending',
                      icon: Icons.receipt_long_outlined,
                      tint: colorScheme.error,
                    ),
                ],
              ),
            ],
          ),
        );

        final opsCard = DashboardSectionCard(
          icon: Icons.settings_suggest_outlined,
          title: 'Operations control',
          subtitle:
              'Use this snapshot to keep setup, stock pressure, and optional business lines under control.',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              DashboardMetricTile(
                label: 'Active alerts',
                value: '${alerts.length}',
                caption: 'Stock alerts currently visible on this station',
                icon: Icons.notification_important_outlined,
                tint: colorScheme.error,
              ),
              if (_canShowTankerSummary(capabilities))
                DashboardMetricTile(
                  label: 'Tanker profit',
                  value: _value(tankerProfit),
                  caption: '${tankerTrips.toStringAsFixed(0)} completed trips',
                  icon: Icons.local_shipping_outlined,
                  tint: colorScheme.tertiary,
                ),
            ],
          ),
        );

        final attentionCard = DashboardSectionCard(
          icon: Icons.track_changes_outlined,
          title: 'Station attention list',
          subtitle:
              'These are the things a station admin usually needs to react to first.',
          child: DashboardAttentionList(
            emptyLabel: 'No active station alerts are currently visible.',
            items: [
              for (final alert in alerts)
                DashboardAttentionItem(
                  title: '${alert['tank_name']} is below threshold',
                  subtitle:
                      'Remaining ${alert['current_volume']}L, threshold ${alert['threshold']}L.',
                  icon: Icons.local_gas_station_outlined,
                  color: colorScheme.secondary,
                ),
            ],
          ),
        );

        return Column(
          children: [
            DashboardHeroCard(
              eyebrow: 'Station Admin',
              title: 'Station control center',
              subtitle:
                  'Balance setup, people, inventory, and business lines without dropping into every individual form first.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DashboardMetricTile(
                    label: 'Sales',
                    value: _value(salesTotal),
                    caption: 'Current station sales visible in this session',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.primary,
                  ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Liters currently available',
                      icon: Icons.local_gas_station_outlined,
                      tint: colorScheme.secondary,
                    ),
                  if (_canShowExpensesSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Expenses',
                      value: _value(expenses),
                      caption: 'Operational outflow in the current summary',
                      icon: Icons.payments_outlined,
                      tint: colorScheme.error,
                    ),
                  if (_canShowTankerSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Tanker trips',
                      value: tankerTrips.toStringAsFixed(0),
                      caption: 'Trips completed in this dashboard summary',
                      icon: Icons.local_shipping_outlined,
                      tint: colorScheme.tertiary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: readinessCard),
                  const SizedBox(width: 20),
                  Expanded(child: opsCard),
                ],
              )
            else ...[
              readinessCard,
              const SizedBox(height: 20),
              opsCard,
            ],
            const SizedBox(height: 20),
            attentionCard,
          ],
        );
      },
    );
  }

  Widget _buildManagerLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    List<dynamic> alerts,
    List<dynamic> creditAlerts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final stock = _num(dashboard?['fuel_stock_liters']);
    final expenses = _num(dashboard?['expenses']);
    final salesTotal = _num(sales['total']);
    final cashSales = _num(sales['cash']);
    final creditSales = _num(sales['credit']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final flowCard = DashboardSectionCard(
          icon: Icons.swap_horiz_outlined,
          title: 'Shift flow',
          subtitle:
              'Managers need a fast read on how today is moving between cash, credit, stock pressure, and expenses.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Cash sales',
                trailingLabel: 'Credit sales',
                leadingValue: cashSales,
                trailingValue: creditSales,
                leadingColor: colorScheme.primary,
                trailingColor: colorScheme.tertiary,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (_canShowExpensesSummary(capabilities))
                    DashboardMetricTile(
                      label: 'Expenses',
                      value: _value(expenses),
                      caption: 'Current visible shift spending',
                      icon: Icons.receipt_long_outlined,
                      tint: colorScheme.error,
                    ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Operational stock remaining',
                      icon: Icons.inventory_outlined,
                      tint: colorScheme.secondary,
                    ),
                ],
              ),
            ],
          ),
        );

        final attentionCard = DashboardSectionCard(
          icon: Icons.priority_high_outlined,
          title: 'Manager attention list',
          subtitle:
              'These are the exceptions that can disrupt the day if they are ignored.',
          child: DashboardAttentionList(
            emptyLabel: 'No operational alerts are active right now.',
            items: [
              for (final alert in alerts)
                DashboardAttentionItem(
                  title: '${alert['tank_name']} is below threshold',
                  subtitle:
                      'Remaining ${alert['current_volume']}L, threshold ${alert['threshold']}L.',
                  icon: Icons.local_gas_station_outlined,
                  color: colorScheme.secondary,
                ),
              for (final alert in creditAlerts)
                DashboardAttentionItem(
                  title: '${alert['customer_name']} is near credit limit',
                  subtitle:
                      '${alert['usage_percentage']}% of the configured limit is already used.',
                  icon: Icons.warning_amber_outlined,
                  color: colorScheme.error,
                ),
            ],
          ),
        );

        return Column(
          children: [
            DashboardHeroCard(
              eyebrow: 'Manager',
              title: 'Daily operations board',
              subtitle:
                  'Keep the forecourt moving, watch cash versus credit, and catch issues before they turn into end-of-shift problems.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DashboardMetricTile(
                    label: 'Sales',
                    value: _value(salesTotal),
                    caption: 'Total visible sales in the current operational window',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.primary,
                  ),
                  DashboardMetricTile(
                    label: 'Cash sales',
                    value: _value(cashSales),
                    caption: 'Immediate liquidity in today’s flow',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: colorScheme.primary,
                  ),
                  DashboardMetricTile(
                    label: 'Credit sales',
                    value: _value(creditSales),
                    caption: 'Exposure that still needs collection follow-up',
                    icon: Icons.credit_score_outlined,
                    tint: colorScheme.tertiary,
                  ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Remaining operational stock',
                      icon: Icons.local_gas_station_outlined,
                      tint: colorScheme.secondary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: flowCard),
                  const SizedBox(width: 20),
                  Expanded(child: attentionCard),
                ],
              )
            else ...[
              flowCard,
              const SizedBox(height: 20),
              attentionCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildAccountantLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    List<dynamic> alerts,
    List<dynamic> creditAlerts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final receivables = _num(dashboard?['receivables']);
    final payables = _num(dashboard?['payables']);
    final expenses = _num(dashboard?['expenses']);
    final profit = _num(dashboard?['net_profit']);
    final cashSales = _num(sales['cash']);
    final creditSales = _num(sales['credit']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final financeFlowCard = DashboardSectionCard(
          icon: Icons.account_balance_outlined,
          title: 'Finance flow',
          subtitle:
              'Watch collections, obligations, and expense pressure together instead of jumping between ledgers.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Receivables',
                trailingLabel: 'Payables',
                leadingValue: receivables,
                trailingValue: payables,
                leadingColor: colorScheme.primary,
                trailingColor: colorScheme.secondary,
              ),
              const SizedBox(height: 18),
              DashboardRatioBar(
                leadingLabel: 'Cash sales',
                trailingLabel: 'Credit sales',
                leadingValue: cashSales,
                trailingValue: creditSales,
                leadingColor: colorScheme.tertiary,
                trailingColor: colorScheme.error,
              ),
            ],
          ),
        );

        final financeAttentionCard = DashboardSectionCard(
          icon: Icons.request_quote_outlined,
          title: 'Finance attention list',
          subtitle:
              'Use this to see where follow-up is needed before numbers drift out of control.',
          child: DashboardAttentionList(
            emptyLabel: 'No credit-limit or stock-linked finance alerts are active.',
            items: [
              for (final alert in creditAlerts)
                DashboardAttentionItem(
                  title: '${alert['customer_name']} is near credit limit',
                  subtitle:
                      '${alert['usage_percentage']}% of the configured limit is already used.',
                  icon: Icons.warning_amber_outlined,
                  color: colorScheme.error,
                ),
              for (final alert in alerts)
                DashboardAttentionItem(
                  title: '${alert['tank_name']} is below threshold',
                  subtitle:
                      'Low stock can affect purchase timing and supplier settlements.',
                  icon: Icons.inventory_2_outlined,
                  color: colorScheme.secondary,
                ),
            ],
          ),
        );

        return Column(
          children: [
            DashboardHeroCard(
              eyebrow: 'Accountant',
              title: 'Finance control board',
              subtitle:
                  'Stay on top of collections, supplier pressure, expense drift, and profitability without operational clutter.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DashboardMetricTile(
                    label: 'Receivables',
                    value: _value(receivables),
                    caption: 'Collections still outstanding',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: colorScheme.primary,
                  ),
                  DashboardMetricTile(
                    label: 'Payables',
                    value: _value(payables),
                    caption: 'Supplier obligations visible now',
                    icon: Icons.payments_outlined,
                    tint: colorScheme.secondary,
                  ),
                  DashboardMetricTile(
                    label: 'Expenses',
                    value: _value(expenses),
                    caption: 'Current expense load in the dashboard summary',
                    icon: Icons.receipt_long_outlined,
                    tint: colorScheme.error,
                  ),
                  DashboardMetricTile(
                    label: 'Net profit',
                    value: _value(profit),
                    caption: 'Profitability snapshot for this scope',
                    icon: Icons.insights_outlined,
                    tint: colorScheme.tertiary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: financeFlowCard),
                  const SizedBox(width: 20),
                  Expanded(child: financeAttentionCard),
                ],
              )
            else ...[
              financeFlowCard,
              const SizedBox(height: 20),
              financeAttentionCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildOperatorLayout(
    BuildContext context,
    SessionCapabilities capabilities,
    Map<String, dynamic> sales,
    List<dynamic> alerts,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final salesTotal = _num(sales['total']);
    final cashSales = _num(sales['cash']);
    final creditSales = _num(sales['credit']);
    final stock = _num(dashboard?['fuel_stock_liters']);

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1180;
        final shiftFocusCard = DashboardSectionCard(
          icon: Icons.local_activity_outlined,
          title: 'Shift focus',
          subtitle:
              'Operators need a fast operational read without finance or setup noise.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DashboardRatioBar(
                leadingLabel: 'Cash sales',
                trailingLabel: 'Credit sales',
                leadingValue: cashSales,
                trailingValue: creditSales,
                leadingColor: colorScheme.primary,
                trailingColor: colorScheme.tertiary,
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  DashboardMetricTile(
                    label: 'Sales total',
                    value: _value(salesTotal),
                    caption: 'Visible sales in the current shift context',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.primary,
                  ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Quick operational stock reference',
                      icon: Icons.local_gas_station_outlined,
                      tint: colorScheme.secondary,
                    ),
                ],
              ),
            ],
          ),
        );

        final operatorAttentionCard = DashboardSectionCard(
          icon: Icons.error_outline,
          title: 'Operator attention list',
          subtitle:
              'This keeps the front line focused on what can interrupt the shift right now.',
          child: DashboardAttentionList(
            emptyLabel: 'No visible operational alerts are active right now.',
            items: [
              for (final alert in alerts)
                DashboardAttentionItem(
                  title: '${alert['tank_name']} is below threshold',
                  subtitle:
                      'Low stock may affect active nozzles and forecourt flow.',
                  icon: Icons.local_gas_station_outlined,
                  color: colorScheme.secondary,
                ),
            ],
          ),
        );

        return Column(
          children: [
            DashboardHeroCard(
              eyebrow: 'Operator',
              title: 'Forecourt activity board',
              subtitle:
                  'Focus on live sales, stock awareness, and shift-safe operational work only.',
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  DashboardMetricTile(
                    label: 'Sales total',
                    value: _value(salesTotal),
                    caption: 'Visible forecourt sales in this session',
                    icon: Icons.point_of_sale_outlined,
                    tint: colorScheme.primary,
                  ),
                  DashboardMetricTile(
                    label: 'Cash sales',
                    value: _value(cashSales),
                    caption: 'Immediate cashier-facing flow',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: colorScheme.primary,
                  ),
                  DashboardMetricTile(
                    label: 'Credit sales',
                    value: _value(creditSales),
                    caption: 'Credit handled in the current operational view',
                    icon: Icons.credit_score_outlined,
                    tint: colorScheme.tertiary,
                  ),
                  if (_canShowInventorySummary(capabilities))
                    DashboardMetricTile(
                      label: 'Fuel stock',
                      value: _value(stock),
                      caption: 'Quick stock awareness only',
                      icon: Icons.inventory_outlined,
                      tint: colorScheme.secondary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: shiftFocusCard),
                  const SizedBox(width: 20),
                  Expanded(child: operatorAttentionCard),
                ],
              )
            else ...[
              shiftFocusCard,
              const SizedBox(height: 20),
              operatorAttentionCard,
            ],
          ],
        );
      },
    );
  }

  Widget _buildAlertsCard(
    BuildContext context, {
    required String title,
    required List<dynamic> alerts,
    required List<dynamic> creditAlerts,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
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
                  title: Text('${alert['customer_name']} is near credit limit'),
                  subtitle: Text(
                    '${alert['usage_percentage']}% of the configured limit is used',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _value(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  static double _num(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return 0;
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
          'Current access scope: $scopeLevel. Review today''s operational and financial summary.',
        );
    }
  }

  static List<String> _roleFocus(
    String roleName,
    SessionCapabilities capabilities,
  ) {
    switch (roleName) {
      case 'HeadOffice':
        return [
          if (_canShowGovernanceSummary(capabilities)) 'Approvals',
          if (capabilities.hasPermission('reports')) 'Reports',
          'Station Oversight',
        ];
      case 'StationAdmin':
        return [
          if (capabilities.hasAnyPermission(
            const ['invoice_profiles', 'document_templates'],
          ))
            'Setup',
          if (capabilities.hasAnyPermission(
            const ['users', 'employee_profiles'],
          ))
            'Users',
          if (capabilities.hasAnyPermission(const ['station_modules']))
            'Module Control',
        ];
      case 'Manager':
        return [
          if (_canShowSalesSummary(capabilities)) 'Sales',
          if (capabilities.hasPermission('shifts')) 'Shifts',
          if (_canShowExpensesSummary(capabilities)) 'Expenses',
        ];
      case 'Accountant':
        return [
          if (_canShowFinanceSummary(capabilities)) 'Collections',
          if (capabilities.hasPermission('supplier_payments'))
            'Supplier Payments',
          if (capabilities.hasPermission('reports')) 'Ledgers',
        ];
      case 'Operator':
        return [
          if (_canShowSalesSummary(capabilities)) 'Forecourt Sales',
          if (capabilities.hasPermission('attendance')) 'Attendance',
          if (capabilities.hasPermission('shifts')) 'Shift Activity',
        ];
      default:
        return [
          if (_canShowSalesSummary(capabilities)) 'Operations',
          if (_canShowFinanceSummary(capabilities)) 'Finance',
          'Alerts',
        ];
    }
  }

  static bool _canShowSalesSummary(SessionCapabilities capabilities) {
    return capabilities.hasPermission('fuel_sales');
  }

  static bool _canShowFinanceSummary(SessionCapabilities capabilities) {
    return capabilities.hasAnyPermission(
      const ['customer_payments', 'supplier_payments', 'reports'],
    );
  }

  static bool _canShowExpensesSummary(SessionCapabilities capabilities) {
    return capabilities.hasPermission('expenses');
  }

  static bool _canShowInventorySummary(SessionCapabilities capabilities) {
    return capabilities.hasAnyPermission(const ['tanks', 'dispensers', 'nozzles']);
  }

  static bool _canShowTankerSummary(SessionCapabilities capabilities) {
    return capabilities.hasPermission('tankers');
  }

  static bool _canShowGovernanceSummary(SessionCapabilities capabilities) {
    return capabilities.hasAnyPermission(
      const ['expenses', 'purchases', 'customers'],
      actions: const [
        'approve',
        'reject',
        'approve_credit_override',
        'reject_credit_override',
      ],
    );
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
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
