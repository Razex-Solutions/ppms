import 'package:flutter/material.dart';

void main() {
  runApp(const PpmsTenantApp());
}

class PpmsTenantApp extends StatelessWidget {
  const PpmsTenantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PPMS Tenant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
      ),
      home: const TenantRebuildLandingPage(),
    );
  }
}

class TenantRebuildLandingPage extends StatelessWidget {
  const TenantRebuildLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PPMS Tenant App', style: textTheme.headlineMedium),
                  const SizedBox(height: 12),
                  Text(
                    'Clean rebuild shell for HeadOffice, Manager, Accountant, and Operator workflows.',
                    style: textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  const _PlanCard(
                    title: 'Current slice',
                    body:
                        'Login, session context, tenant landing page, role-aware navigation, and HeadOffice worker creation.',
                  ),
                  const SizedBox(height: 12),
                  const _PlanCard(
                    title: 'Rules',
                    body:
                        'No dashboards, no MasterAdmin daily-work screens, and no StationAdmin for one-station tenants.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
