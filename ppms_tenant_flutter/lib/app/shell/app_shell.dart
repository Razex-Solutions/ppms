import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../localization/app_localizations.dart';
import '../session/models/app_role.dart';
import '../session/session_controller.dart';
import '../theme/app_breakpoints.dart';
import 'app_navigation_item.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session == null) {
      return const SizedBox.shrink();
    }

    final items = _buildItems(session.role);
    final currentLocation = GoRouterState.of(context).uri.path;
    final selectedIndex = items.indexWhere(
      (item) => item.location == currentLocation,
    );
    final breakpoint = context.breakpoint;
    final selected = selectedIndex >= 0 ? selectedIndex : 0;

    if (breakpoint == AppBreakpoint.compact) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.text('appName')),
        ),
        drawer: Drawer(
          child: _NavList(
            items: items,
            selectedIndex: selected,
          ),
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          onDestinationSelected: (index) =>
              context.go(items[index].location),
          destinations: [
            for (final item in items)
              NavigationDestination(
                icon: Icon(item.icon),
                label: context.l10n.text(item.labelKey),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selected,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (index) => context.go(items[index].location),
            destinations: [
              for (final item in items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  label: Text(context.l10n.text(item.labelKey)),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: IconButton(
                    tooltip: context.l10n.text('logout'),
                    onPressed: () =>
                        ref.read(sessionControllerProvider.notifier).logout(),
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  child: ListTile(
                    title: Text(session.fullName),
                    subtitle: Text(
                      '${context.l10n.text('currentRole')}: ${session.role.backendName}',
                    ),
                    trailing: FilledButton.tonalIcon(
                      onPressed: () =>
                          ref.read(sessionControllerProvider.notifier).logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(context.l10n.text('logout')),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<AppNavigationItem> _buildItems(AppRole role) {
    final items = <AppNavigationItem>[
      const AppNavigationItem(
        labelKey: 'overview',
        icon: Icons.dashboard_outlined,
        location: '/',
      ),
    ];

    switch (role) {
      case AppRole.manager:
        items.add(
          const AppNavigationItem(
            labelKey: 'managerWorkspace',
            icon: Icons.local_gas_station_outlined,
            location: '/workspace/manager',
          ),
        );
      case AppRole.operator:
        items.add(
          const AppNavigationItem(
            labelKey: 'operatorWorkspace',
            icon: Icons.badge_outlined,
            location: '/workspace/operator',
          ),
        );
      case AppRole.accountant:
        items.add(
          const AppNavigationItem(
            labelKey: 'accountantWorkspace',
            icon: Icons.account_balance_wallet_outlined,
            location: '/workspace/accountant',
          ),
        );
      case AppRole.stationAdmin:
        items.add(
          const AppNavigationItem(
            labelKey: 'stationAdminWorkspace',
            icon: Icons.settings_input_antenna_outlined,
            location: '/workspace/station-admin',
          ),
        );
      case AppRole.headOffice:
        items.add(
          const AppNavigationItem(
            labelKey: 'headOfficeWorkspace',
            icon: Icons.apartment_outlined,
            location: '/workspace/head-office',
          ),
        );
      case AppRole.masterAdmin:
        items.add(
          const AppNavigationItem(
            labelKey: 'masterAdminWorkspace',
            icon: Icons.admin_panel_settings_outlined,
            location: '/workspace/master-admin',
          ),
        );
    }

    items.addAll(const [
      AppNavigationItem(
        labelKey: 'notifications',
        icon: Icons.notifications_none_rounded,
        location: '/notifications',
      ),
      AppNavigationItem(
        labelKey: 'profile',
        icon: Icons.person_outline_rounded,
        location: '/profile',
      ),
    ]);

    return items;
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.items,
    required this.selectedIndex,
  });

  final List<AppNavigationItem> items;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        DrawerHeader(
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Text(
              context.l10n.text('menu'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
        ),
        for (var index = 0; index < items.length; index++)
          ListTile(
            leading: Icon(items[index].icon),
            title: Text(context.l10n.text(items[index].labelKey)),
            selected: selectedIndex == index,
            onTap: () {
              Navigator.of(context).pop();
              context.go(items[index].location);
            },
          ),
      ],
    );
  }
}
