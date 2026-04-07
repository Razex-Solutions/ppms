import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
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
    setState(() {
      _dashboard = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.currentUser ?? const {};
    final roleName = widget.sessionController.roleName;
    final scopeLevel = widget.sessionController.scopeLevel;
    final isPlatformUser = widget.sessionController.isMasterAdmin;
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
                      ? '${isPlatformUser ? 'Platform' : 'PPMS'} • ${selectedDestination.label}'
                      : isPlatformUser
                      ? 'PPMS Platform'
                      : 'PPMS Flutter',
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        useDrawer
                            ? _buildContextBadge(
                                user: user,
                                roleName: roleName,
                                scopeLevel: scopeLevel,
                                isPlatformUser: isPlatformUser,
                              )
                            : '${user['full_name'] ?? ''} • ${_buildContextBadge(user: user, roleName: roleName, scopeLevel: scopeLevel, isPlatformUser: isPlatformUser)}',
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
                                      isPlatformUser
                                          ? 'Platform'
                                          : 'Operations',
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
                                child: _RailDestinationList(
                                  destinations: destinations,
                                  selectedIndex: _selectedIndex,
                                  extended: constraints.maxWidth >= 1480,
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
    final capabilities = SessionCapabilities(widget.sessionController);
    if (capabilities.isPlatformUser) {
      return [
        _ShellDestination(
          label: 'Platform',
          icon: Icons.dashboard_customize_outlined,
          page: PlatformDashboardPage(
            sessionController: widget.sessionController,
          ),
        ),
        if (capabilities.featureVisible(
          platformFeature: true,
          permissionModules: const ['organizations', 'users'],
        ))
          _ShellDestination(
            label: 'Onboarding',
            icon: Icons.playlist_add_check_circle_outlined,
            page: OnboardingPage(sessionController: widget.sessionController),
          ),
        if (capabilities.featureVisible(
          platformFeature: true,
          permissionModules: const [
            'stations',
            'tanks',
            'dispensers',
            'nozzles',
            'invoice_profiles',
          ],
        ))
          _ShellDestination(
            label: 'Station Setup',
            icon: Icons.architecture_outlined,
            page: StationSetupPage(sessionController: widget.sessionController),
          ),
        if (capabilities.featureVisible(
          platformFeature: true,
          permissionModules: const ['organizations', 'users', 'roles', 'saas'],
        ))
          _ShellDestination(
            label: 'Admin',
            icon: Icons.admin_panel_settings_outlined,
            page: AdminPage(sessionController: widget.sessionController),
          ),
        if (capabilities.featureVisible(
          platformFeature: true,
          permissionModules: const ['reports'],
        ))
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
          sessionController: widget.sessionController,
          dashboard: _dashboard,
          onRefresh: _loadHomeData,
          roleName: widget.sessionController.roleName,
          scopeLevel: widget.sessionController.scopeLevel,
        ),
      ),
      if (capabilities.hasAnyRole(const ['HeadOffice', 'StationAdmin']) &&
          capabilities.featureVisible(
            platformFeature: false,
            permissionModules: const [
              'users',
              'stations',
              'roles',
              'station_modules',
              'employee_profiles',
            ],
          ))
        _ShellDestination(
          label: 'Admin',
          icon: Icons.admin_panel_settings_outlined,
          page: AdminPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['fuel_sales'],
        permissionModules: const ['fuel_sales'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Sales',
          icon: Icons.local_gas_station_outlined,
          page: SalesPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['shifts'],
        permissionModules: const ['shifts'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Shifts',
          icon: Icons.manage_history_outlined,
          page: ShiftPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['pos_products', 'pos_sales'],
        permissionModules: const ['pos_products', 'pos_sales'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'POS',
          icon: Icons.storefront_outlined,
          page: PosPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['attendance'],
        permissionModules: const ['attendance'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.badge_outlined,
          page: AttendancePage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['expenses'],
        permissionModules: const ['expenses'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Expenses',
          icon: Icons.receipt_long_outlined,
          page: ExpensesPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['customers', 'suppliers'],
        permissionModules: const ['customers', 'suppliers'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Parties',
          icon: Icons.groups_outlined,
          page: PartiesPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['tanks', 'dispensers', 'nozzles'],
        permissionModules: const ['tanks', 'dispensers', 'nozzles'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Inventory',
          icon: Icons.inventory_outlined,
          page: InventoryPage(sessionController: widget.sessionController),
        ),
      if (capabilities.hasRole('StationAdmin') &&
          capabilities.featureVisible(
            platformFeature: false,
            permissionModules: const ['invoice_profiles', 'document_templates'],
          ))
        _ShellDestination(
          label: 'Setup',
          icon: Icons.build_circle_outlined,
          page: SetupPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['purchases', 'customer_payments', 'supplier_payments'],
        permissionModules: const [
          'purchases',
          'customer_payments',
          'supplier_payments',
        ],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Finance',
          icon: Icons.account_balance_outlined,
          page: FinancePage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['payroll'],
        permissionModules: const ['payroll'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Payroll',
          icon: Icons.payments_outlined,
          page: PayrollPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        requiredModules: const ['reports'],
        permissionModules: const ['reports'],
      ))
        _ShellDestination(
          label: 'Reports',
          icon: Icons.assessment_outlined,
          page: ReportsPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        requiredModules: const ['financial_documents'],
        permissionModules: const ['reports'],
      ))
        _ShellDestination(
          label: 'Documents',
          icon: Icons.description_outlined,
          page: DocumentsPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['notifications'],
        permissionModules: const ['notifications'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          page: NotificationsPage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        modules: const ['hardware'],
        permissionModules: const ['hardware', 'nozzles'],
        hideWhenModulesOff: true,
      ))
        _ShellDestination(
          label: 'Hardware',
          icon: Icons.memory_outlined,
          page: HardwarePage(sessionController: widget.sessionController),
        ),
      if (capabilities.featureVisible(
        platformFeature: false,
        requiredModules: const ['tankers', 'tanker_operations'],
        permissionModules: const ['tankers'],
      ))
        _ShellDestination(
          label: 'Tankers',
          icon: Icons.local_shipping_outlined,
          page: TankerPage(sessionController: widget.sessionController),
        ),
      if (capabilities.hasRole('HeadOffice') &&
          capabilities.featureVisible(
            platformFeature: false,
            modules: const ['expenses', 'purchases', 'customers'],
            permissionModules: const ['expenses', 'purchases', 'customers'],
            hideWhenModulesOff: true,
          ))
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

  String _buildContextBadge({
    required Map<String, dynamic> user,
    required String roleName,
    required String scopeLevel,
    required bool isPlatformUser,
  }) {
    if (isPlatformUser) {
      return 'Razex • $roleName';
    }
    final organizationId = user['organization_id'];
    final stationId = user['station_id'];
    return switch (scopeLevel) {
      'organization' => 'Org $organizationId • $roleName',
      'station' => 'Station $stationId • $roleName',
      _ => roleName,
    };
  }
}

class _RailDestinationList extends StatelessWidget {
  const _RailDestinationList({
    required this.destinations,
    required this.selectedIndex,
    required this.extended,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
      itemCount: destinations.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final destination = destinations[index];
        final selected = index == selectedIndex;
        final colorScheme = Theme.of(context).colorScheme;
        if (extended) {
          return ListTile(
            selected: selected,
            selectedTileColor: colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            leading: Icon(destination.icon),
            title: Text(destination.label),
            onTap: () => onDestinationSelected(index),
          );
        }
        return Tooltip(
          message: destination.label,
          waitDuration: const Duration(milliseconds: 400),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onDestinationSelected(index),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected ? colorScheme.primaryContainer : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    destination.icon,
                    color: selected ? colorScheme.onPrimaryContainer : null,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected ? colorScheme.onPrimaryContainer : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
