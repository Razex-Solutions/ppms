import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/admin/presentation/admin_page.dart';
import 'package:ppms_flutter/features/attendance/presentation/attendance_page.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_page.dart';
import 'package:ppms_flutter/features/dashboard/presentation/platform_dashboard_page.dart';
import 'package:ppms_flutter/features/documents/presentation/documents_page.dart';
import 'package:ppms_flutter/features/expenses/presentation/expenses_page.dart';
import 'package:ppms_flutter/features/finance/presentation/finance_page.dart';
import 'package:ppms_flutter/features/governance/presentation/governance_page.dart';
import 'package:ppms_flutter/features/hardware/presentation/hardware_page.dart';
import 'package:ppms_flutter/features/inventory/presentation/inventory_page.dart';
import 'package:ppms_flutter/features/notifications/presentation/notifications_page.dart';
import 'package:ppms_flutter/features/onboarding/presentation/onboarding_page.dart';
import 'package:ppms_flutter/features/parties/presentation/parties_page.dart';
import 'package:ppms_flutter/features/payroll/presentation/payroll_page.dart';
import 'package:ppms_flutter/features/pos/presentation/pos_page.dart';
import 'package:ppms_flutter/features/reports/presentation/reports_page.dart';
import 'package:ppms_flutter/features/sales/presentation/sales_page.dart';
import 'package:ppms_flutter/features/settings/presentation/settings_page.dart';
import 'package:ppms_flutter/features/setup/presentation/setup_page.dart';
import 'package:ppms_flutter/features/setup/presentation/station_setup_page.dart';
import 'package:ppms_flutter/features/shifts/presentation/shift_page.dart';
import 'package:ppms_flutter/features/tankers/presentation/tanker_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  Map<String, dynamic>? _dashboard;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final dashboard = await widget.sessionController.fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = dashboard;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.currentUser ?? const {};
    final roleName = widget.sessionController.roleName;
    final permissions = widget.sessionController.permissions;
    final enabledModules = widget.sessionController.enabledModules;
    final destinations = _buildDestinations(enabledModules, permissions);
    if (_selectedIndex >= destinations.length) {
      _selectedIndex = 0;
    }

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(child: Text(_loadError!))
        : destinations[_selectedIndex].page;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 1180;
        final useDrawer = !useRail;
        final selectedDestination = destinations[_selectedIndex];

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.f5): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.keyR, control: true):
                ActivateIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (intent) {
                  _loadHomeData();
                  return null;
                },
              ),
            },
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  useDrawer
                      ? 'PPMS • ${selectedDestination.label}'
                      : 'PPMS Flutter',
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        useDrawer
                            ? roleName.toString()
                            : '${user['full_name'] ?? ''} • $roleName',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _loadHomeData,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh (F5 / Ctrl+R)',
                  ),
                  IconButton(
                    onPressed: widget.sessionController.signOut,
                    icon: const Icon(Icons.logout),
                    tooltip: 'Logout',
                  ),
                ],
              ),
              drawer: useDrawer
                  ? Drawer(
                      child: SafeArea(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            ListTile(
                              title: Text(
                                user['full_name'] as String? ?? 'PPMS User',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              subtitle: Text(roleName.toString()),
                            ),
                            const Divider(),
                            for (
                              var index = 0;
                              index < destinations.length;
                              index++
                            )
                              ListTile(
                                selected: index == _selectedIndex,
                                leading: Icon(destinations[index].icon),
                                title: Text(destinations[index].label),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  setState(() {
                                    _selectedIndex = index;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                    )
                  : null,
              body: Container(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                child: Row(
                  children: [
                    if (useRail)
                      Container(
                        width: constraints.maxWidth >= 1480 ? 290 : 92,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border(
                            right: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: SafeArea(
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  12,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Operations',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      selectedDestination.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: NavigationRail(
                                  selectedIndex: _selectedIndex,
                                  extended: constraints.maxWidth >= 1480,
                                  groupAlignment: -1,
                                  labelType: constraints.maxWidth >= 1480
                                      ? NavigationRailLabelType.none
                                      : NavigationRailLabelType.all,
                                  destinations: [
                                    for (final destination in destinations)
                                      NavigationRailDestination(
                                        icon: Icon(destination.icon),
                                        label: Text(destination.label),
                                      ),
                                  ],
                                  onDestinationSelected: (index) {
                                    setState(() {
                                      _selectedIndex = index;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1760),
                          child: Padding(
                            padding: EdgeInsets.all(useRail ? 20 : 0),
                            child: body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<_ShellDestination> _buildDestinations(
    List<String> enabledModules,
    Map<String, dynamic> permissions,
  ) {
    final currentRoleName = widget.sessionController.roleName;
    final isPlatformUser = widget.sessionController.isMasterAdmin;
    if (isPlatformUser) {
      return [
        _ShellDestination(
          label: 'Platform',
          icon: Icons.dashboard_customize_outlined,
          page: PlatformDashboardPage(
            sessionController: widget.sessionController,
          ),
        ),
        if (permissions.containsKey('organizations') ||
            permissions.containsKey('users'))
          _ShellDestination(
            label: 'Onboarding',
            icon: Icons.playlist_add_check_circle_outlined,
            page: OnboardingPage(sessionController: widget.sessionController),
          ),
        if (permissions.containsKey('stations') ||
            permissions.containsKey('tanks') ||
            permissions.containsKey('dispensers') ||
            permissions.containsKey('nozzles') ||
            permissions.containsKey('invoice_profiles'))
          _ShellDestination(
            label: 'Station Setup',
            icon: Icons.architecture_outlined,
            page: StationSetupPage(sessionController: widget.sessionController),
          ),
        if (permissions.containsKey('organizations') ||
            permissions.containsKey('users') ||
            permissions.containsKey('roles') ||
            permissions.containsKey('saas'))
          _ShellDestination(
            label: 'Admin',
            icon: Icons.admin_panel_settings_outlined,
            page: AdminPage(sessionController: widget.sessionController),
          ),
        if (permissions.containsKey('reports'))
          _ShellDestination(
            label: 'Reports',
            icon: Icons.assessment_outlined,
            page: ReportsPage(sessionController: widget.sessionController),
          ),
        _ShellDestination(
          label: 'Settings',
          icon: Icons.settings_outlined,
          page: SettingsPage(sessionController: widget.sessionController),
        ),
      ];
    }
    return [
      _ShellDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        page: DashboardPage(
          dashboard: _dashboard,
          onRefresh: _loadHomeData,
          roleName: widget.sessionController.roleName,
          scopeLevel: widget.sessionController.scopeLevel,
        ),
      ),
      if (currentRoleName == 'HeadOffice' ||
          currentRoleName == 'StationAdmin' ||
          currentRoleName == 'Admin' ||
          permissions.containsKey('users') ||
          permissions.containsKey('stations') ||
          permissions.containsKey('roles') ||
          permissions.containsKey('station_modules') ||
          permissions.containsKey('employee_profiles'))
        _ShellDestination(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          page: AdminPage(sessionController: widget.sessionController),
        ),
      if (currentRoleName != 'HeadOffice')
        _ShellDestination(
          label: 'Sales',
          icon: Icons.local_gas_station_outlined,
          page: SalesPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('shifts') ||
          permissions.containsKey('shifts'))
        _ShellDestination(
          label: 'Shifts',
          icon: Icons.manage_history_outlined,
          page: ShiftPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('pos_products') ||
          enabledModules.contains('pos_sales') ||
          permissions.containsKey('pos_products') ||
          permissions.containsKey('pos_sales'))
        _ShellDestination(
          label: 'POS',
          icon: Icons.storefront_outlined,
          page: PosPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('attendance') &&
          currentRoleName != 'HeadOffice')
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.badge_outlined,
          page: AttendancePage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('expenses') ||
          permissions.containsKey('expenses'))
        _ShellDestination(
          label: 'Expenses',
          icon: Icons.receipt_long_outlined,
          page: ExpensesPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('customers') ||
          enabledModules.contains('suppliers') ||
          permissions.containsKey('customers') ||
          permissions.containsKey('suppliers'))
        _ShellDestination(
          label: 'Parties',
          icon: Icons.groups_outlined,
          page: PartiesPage(sessionController: widget.sessionController),
        ),
      if ((enabledModules.contains('tanks') ||
              enabledModules.contains('dispensers') ||
              enabledModules.contains('nozzles') ||
              permissions.containsKey('tanks') ||
              permissions.containsKey('dispensers') ||
              permissions.containsKey('nozzles')) &&
          currentRoleName != 'HeadOffice')
        _ShellDestination(
          label: 'Inventory',
          icon: Icons.inventory_outlined,
          page: InventoryPage(sessionController: widget.sessionController),
        ),
      if (permissions.containsKey('invoice_profiles') ||
          currentRoleName == 'Admin' ||
          currentRoleName == 'StationAdmin' ||
          currentRoleName == 'HeadOffice')
        _ShellDestination(
          label: 'Setup',
          icon: Icons.build_circle_outlined,
          page: SetupPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('purchases') ||
          enabledModules.contains('customer_payments') ||
          enabledModules.contains('supplier_payments') ||
          permissions.containsKey('purchases') ||
          permissions.containsKey('customer_payments') ||
          permissions.containsKey('supplier_payments'))
        _ShellDestination(
          label: 'Finance',
          icon: Icons.account_balance_outlined,
          page: FinancePage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('payroll') && currentRoleName != 'Operator')
        _ShellDestination(
          label: 'Payroll',
          icon: Icons.payments_outlined,
          page: PayrollPage(sessionController: widget.sessionController),
        ),
      if (permissions.containsKey('reports'))
        _ShellDestination(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          page: ReportsPage(sessionController: widget.sessionController),
        ),
      if (permissions.containsKey('reports'))
        _ShellDestination(
          label: 'Documents',
          icon: Icons.description_outlined,
          page: DocumentsPage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('notifications'))
        _ShellDestination(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          page: NotificationsPage(sessionController: widget.sessionController),
        ),
      if ((enabledModules.contains('hardware') ||
              permissions.containsKey('hardware') ||
              permissions.containsKey('nozzles')) &&
          currentRoleName != 'HeadOffice')
        _ShellDestination(
          label: 'Hardware',
          icon: Icons.memory_outlined,
          page: HardwarePage(sessionController: widget.sessionController),
        ),
      if ((enabledModules.contains('tankers') ||
              permissions.containsKey('tankers')) &&
          currentRoleName != 'Operator')
        _ShellDestination(
          label: 'Tankers',
          icon: Icons.local_shipping_outlined,
          page: TankerPage(sessionController: widget.sessionController),
        ),
      if ((enabledModules.contains('expenses') ||
              permissions.containsKey('expenses') ||
              permissions.containsKey('purchases') ||
              permissions.containsKey('customers')) &&
          currentRoleName != 'Operator')
        _ShellDestination(
          label: 'Governance',
          icon: Icons.approval_outlined,
          page: GovernancePage(sessionController: widget.sessionController),
        ),
      _ShellDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        page: SettingsPage(sessionController: widget.sessionController),
      ),
    ];
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.page,
  });

  final String label;
  final IconData icon;
  final Widget page;
}
