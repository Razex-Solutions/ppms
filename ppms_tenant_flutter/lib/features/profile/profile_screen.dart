import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/session/session_controller.dart';
import '../../widgets/info_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider).session;
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
