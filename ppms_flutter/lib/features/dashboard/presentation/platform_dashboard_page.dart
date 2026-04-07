import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class PlatformDashboardPage extends StatelessWidget {
  const PlatformDashboardPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final user = sessionController.currentUser ?? const <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PlatformCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'MasterAdmin testing landing',
          subtitle:
              'The platform dashboard is intentionally simplified for Phase 9. Use the menu to test platform actions, organization access, support flows, and leakage boundaries.',
          children: [
            _InfoRow(
              label: 'User',
              value: user['full_name']?.toString() ?? 'MasterAdmin',
            ),
            _InfoRow(label: 'Role', value: sessionController.roleName),
            const _InfoRow(label: 'Scope', value: 'Platform-wide'),
          ],
        ),
        const SizedBox(height: 16),
        const _PlatformCard(
          icon: Icons.security_outlined,
          title: 'Platform access rule',
          subtitle:
              'MasterAdmin is the only Flutter role expected to inspect all organizations. Tenant roles must stay scoped to their own organization or station.',
          children: [
            _ChecklistText(
              'Open Onboarding, Station Setup, Admin, Reports, and Settings from the menu.',
            ),
            _ChecklistText(
              'Check that platform actions are useful and not placeholder-only.',
            ),
            _ChecklistText(
              'Use tenant roles separately to verify they cannot see platform-wide data.',
            ),
            _ChecklistText(
              'Report dead buttons, fake totals, confusing controls, or tenant/platform overlap.',
            ),
          ],
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
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
