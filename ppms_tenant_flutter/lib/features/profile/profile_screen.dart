import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/session/session_controller.dart';
import '../operator/operator_repository.dart';
import '../../widgets/info_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
    final selfProfileAsync = ref.watch(selfProfileProvider);
    if (session == null) {
      return const SizedBox.shrink();
    }

    final locale = ref.watch(appLocaleProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        InfoCard(
          title: session.fullName,
          body: context.l10n.text('profileHint'),
          icon: Icons.account_circle_outlined,
          footer: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Chip(label: Text('${context.l10n.text('currentRole')}: ${session.role.backendName}')),
              Chip(label: Text('${context.l10n.text('scopeLevel')}: ${session.scopeLevel}')),
              if (session.organizationId != null)
                Chip(label: Text('${context.l10n.text('organization')}: ${session.organizationId}')),
              if (session.stationId != null)
                Chip(label: Text('${context.l10n.text('station')}: ${session.stationId}')),
            ],
          ),
        ),
        const SizedBox(height: 16),
        selfProfileAsync.when(
          data: (profile) => Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.text('employeeDetails'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (profile.staffTitle != null)
                    Text('${context.l10n.text('staffTitle')}: ${profile.staffTitle}'),
                  if (profile.employeeCode != null)
                    Text('${context.l10n.text('employeeCode')}: ${profile.employeeCode}'),
                  if (profile.stationName != null)
                    Text('${context.l10n.text('station')}: ${profile.stationName}'),
                  if (profile.organizationName != null)
                    Text('${context.l10n.text('organization')}: ${profile.organizationName}'),
                  if (profile.email != null)
                    Text('${context.l10n.text('contactEmail')}: ${profile.email}'),
                  if (profile.phone != null)
                    Text('${context.l10n.text('contactPhone')}: ${profile.phone}'),
                ],
              ),
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('language'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                SegmentedButton<Locale>(
                  segments: [
                    ButtonSegment(
                      value: const Locale('en'),
                      label: Text(context.l10n.text('english')),
                    ),
                    ButtonSegment(
                      value: const Locale('ur'),
                      label: Text(context.l10n.text('urdu')),
                    ),
                  ],
                  selected: {Locale(locale.languageCode)},
                  onSelectionChanged: (selection) {
                    ref
                        .read(appLocaleProvider.notifier)
                        .setLocale(selection.first);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
