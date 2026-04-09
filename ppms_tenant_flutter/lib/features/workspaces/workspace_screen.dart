import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/session/models/app_role.dart';
import '../../app/session/session_controller.dart';
import '../onboarding/master_admin_onboarding_screen.dart';
import '../operator/operator_home_screen.dart';
import '../../widgets/info_card.dart';

class WorkspaceScreen extends ConsumerWidget {
  const WorkspaceScreen({
    super.key,
    this.requestedType,
  });

  final String? requestedType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    if (session == null) {
      return const SizedBox.shrink();
    }

    if ((requestedType == 'master-admin' || requestedType == null) &&
        session.role == AppRole.masterAdmin) {
      return const MasterAdminOnboardingScreen();
    }

    if ((requestedType == 'operator' || requestedType == null) &&
        session.role == AppRole.operator) {
      return const OperatorHomeScreen();
    }

    final titleKey = _resolveTitleKey(session.role, requestedType);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        InfoCard(
          title: context.l10n.text(titleKey),
          body: context.l10n.text(
            requestedType == null ? 'sessionReadyHint' : 'workspaceHint',
          ),
          icon: Icons.layers_outlined,
          footer: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(
                label: Text(
                  '${context.l10n.text('currentRole')}: ${session.role.backendName}',
                ),
              ),
              Chip(
                label: Text(
                  '${context.l10n.text('scopeLevel')}: ${session.scopeLevel}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 360,
              child: _KeyValueCard(
                title: context.l10n.text('quickStatus'),
                values: {
                  context.l10n.text('apiBaseUrl'):
                      ref.read(dioProvider).options.baseUrl,
                  context.l10n.text('sessionRestore'):
                      context.l10n.text('sessionReady'),
                  context.l10n.text('roleModules'):
                      '${session.effectiveEnabledModules.length} modules',
                },
              ),
            ),
            SizedBox(
              width: 360,
              child: _ListCard(
                title: context.l10n.text('activeModules'),
                items: session.effectiveEnabledModules,
              ),
            ),
            SizedBox(
              width: 360,
              child: _ListCard(
                title: context.l10n.text('featureFlags'),
                items: session.featureFlags.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _ListCard(
          title: context.l10n.text('permissions'),
          items: session.permissions.entries
              .map((entry) => '${entry.key}: ${entry.value.join(', ')}')
              .toList(),
        ),
      ],
    );
  }

  String _resolveTitleKey(AppRole role, String? type) {
    switch (type) {
      case 'manager':
        return 'managerWorkspace';
      case 'operator':
        return 'operatorWorkspace';
      case 'accountant':
        return 'accountantWorkspace';
      case 'station-admin':
        return 'stationAdminWorkspace';
      case 'head-office':
        return 'headOfficeWorkspace';
      case 'master-admin':
        return 'masterAdminWorkspace';
    }

    switch (role) {
      case AppRole.manager:
        return 'managerWorkspace';
      case AppRole.operator:
        return 'operatorWorkspace';
      case AppRole.accountant:
        return 'accountantWorkspace';
      case AppRole.stationAdmin:
        return 'stationAdminWorkspace';
      case AppRole.headOffice:
        return 'headOfficeWorkspace';
      case AppRole.masterAdmin:
        return 'masterAdminWorkspace';
    }
  }
}

class _KeyValueCard extends StatelessWidget {
  const _KeyValueCard({
    required this.title,
    required this.values,
  });

  final String title;
  final Map<String, String> values;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final entry in values.entries) ...[
              Text(
                entry.key,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(entry.value),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('-')
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(Icons.circle, size: 8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
