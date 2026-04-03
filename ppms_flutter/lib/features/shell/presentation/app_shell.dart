import 'package:flutter/material.dart';
import 'package:ppms_flutter/features/attendance/presentation/attendance_page.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_page.dart';
import 'package:ppms_flutter/features/home/presentation/module_placeholder_page.dart';
import 'package:ppms_flutter/features/notifications/presentation/notifications_page.dart';
import 'package:ppms_flutter/features/payroll/presentation/payroll_page.dart';
import 'package:ppms_flutter/features/reports/presentation/reports_page.dart';
import 'package:ppms_flutter/features/sales/presentation/sales_page.dart';

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
    final roleName = user['role_name'] ?? 'Unknown';
    final permissions =
        user['permissions'] as Map<String, dynamic>? ?? const {};
    final enabledModules = List<String>.from(
      widget.sessionController.rootInfo?['enabled_modules'] ?? const [],
    );
    final destinations = _buildDestinations(enabledModules, permissions);

    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Center(child: Text(_loadError!))
        : destinations[_selectedIndex].page;

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 980;
        return Scaffold(
          appBar: AppBar(
            title: const Text('PPMS Flutter'),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text('${user['full_name'] ?? ''} • $roleName'),
                ),
              ),
              IconButton(
                onPressed: _loadHomeData,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              IconButton(
                onPressed: widget.sessionController.signOut,
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: Row(
            children: [
              if (useRail)
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  extended: constraints.maxWidth >= 1200,
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
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  destinations: [
                    for (final destination in destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  List<_ShellDestination> _buildDestinations(
    List<String> enabledModules,
    Map<String, dynamic> permissions,
  ) {
    return [
      _ShellDestination(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        page: DashboardPage(dashboard: _dashboard, onRefresh: _loadHomeData),
      ),
      _ShellDestination(
        label: 'Sales',
        icon: Icons.local_gas_station_outlined,
        page: SalesPage(sessionController: widget.sessionController),
      ),
      if (enabledModules.contains('attendance'))
        _ShellDestination(
          label: 'Attendance',
          icon: Icons.badge_outlined,
          page: AttendancePage(sessionController: widget.sessionController),
        ),
      if (enabledModules.contains('payroll'))
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
      if (enabledModules.contains('notifications'))
        _ShellDestination(
          label: 'Notifications',
          icon: Icons.notifications_outlined,
          page: NotificationsPage(sessionController: widget.sessionController),
        ),
      const _ShellDestination(
        label: 'Settings',
        icon: Icons.settings_outlined,
        page: ModulePlaceholderPage(
          title: 'Client Settings',
          description:
              'Future per-device settings, printer config, station defaults, and offline/local options can live here.',
        ),
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
