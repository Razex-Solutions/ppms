import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

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
    final user = sessionController.currentUser ?? const <String, dynamic>{};
    final workspaces = _visibleWorkspaces(capabilities);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Phase9Card(
            icon: Icons.fact_check_outlined,
            title: 'Phase 9 testing landing',
            subtitle:
                'Dashboards are intentionally simplified for stabilization. Use the left menu to test real actions and report leakage or broken workflows.',
            children: [
              _InfoRow(label: 'Role', value: roleName),
              _InfoRow(label: 'Scope', value: scopeLevel),
              _InfoRow(
                label: 'Organization',
                value: _displayValue(user['organization_id']),
              ),
              _InfoRow(
                label: 'Station',
                value: _displayValue(user['station_id']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Phase9Card(
            icon: Icons.security_outlined,
            title: 'Leakage check',
            subtitle:
                'Tenant roles must only see their own organization/station data. MasterAdmin is the only true platform-wide role.',
            children: const [
              _ChecklistText('Open each visible workspace from the menu.'),
              _ChecklistText('Check station selectors and record lists.'),
              _ChecklistText(
                'Report any station, user, sale, report, or total from another organization.',
              ),
              _ChecklistText(
                'Report any placeholder card, dead button, or action that does nothing.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Phase9Card(
            icon: Icons.apps_outlined,
            title: 'Visible workspaces',
            subtitle:
                'These are the workspaces currently exposed by role/module permissions. Test these instead of dashboard cards.',
            children: [
              if (workspaces.isEmpty)
                const Text('No action workspaces are visible for this role.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final workspace in workspaces)
                      Chip(label: Text(workspace)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _displayValue(dynamic value) {
    if (value == null) {
      return 'Not assigned';
    }
    return value.toString();
  }

  static List<String> _visibleWorkspaces(SessionCapabilities capabilities) {
    final workspaces = <String>[];
    void addIf(String label, bool visible) {
      if (visible) {
        workspaces.add(label);
      }
    }

    addIf(
      'Admin',
      capabilities.hasAnyRole(const ['HeadOffice', 'StationAdmin']),
    );
    addIf('Sales', capabilities.hasPermission('fuel_sales'));
    addIf('Shifts', capabilities.hasPermission('shifts'));
    addIf(
      'POS',
      capabilities.hasAnyPermission(const ['pos_products', 'pos_sales']),
    );
    addIf('Attendance', capabilities.hasPermission('attendance'));
    addIf('Expenses', capabilities.hasPermission('expenses'));
    addIf(
      'Parties',
      capabilities.hasAnyPermission(const ['customers', 'suppliers']),
    );
    addIf(
      'Inventory',
      capabilities.hasAnyPermission(const ['tanks', 'dispensers', 'nozzles']),
    );
    addIf('Setup', capabilities.hasPermission('invoice_profiles'));
    addIf(
      'Finance',
      capabilities.hasAnyPermission(const [
        'purchases',
        'customer_payments',
        'supplier_payments',
      ]),
    );
    addIf('Payroll', capabilities.hasPermission('payroll'));
    addIf('Reports', capabilities.hasPermission('reports'));
    addIf(
      'Documents',
      capabilities.hasPermission('financial_documents') ||
          capabilities.hasPermission('reports'),
    );
    addIf('Notifications', capabilities.hasPermission('notifications'));
    addIf(
      'Hardware',
      capabilities.hasAnyPermission(const ['hardware', 'nozzles']),
    );
    addIf('Tankers', capabilities.hasPermission('tankers'));
    addIf('Governance', capabilities.hasRole('HeadOffice'));
    addIf('Settings', true);
    return workspaces;
  }
}

class _Phase9Card extends StatelessWidget {
  const _Phase9Card({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ChecklistText extends StatelessWidget {
  const _ChecklistText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('- '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
