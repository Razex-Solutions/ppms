import 'package:flutter/material.dart';

import '../../app/localization/app_localizations.dart';
import '../../widgets/info_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        InfoCard(
          title: context.l10n.text('notifications'),
          body: context.l10n.text('notificationsEmpty'),
          icon: Icons.notifications_active_outlined,
        ),
      ],
    );
  }
}
