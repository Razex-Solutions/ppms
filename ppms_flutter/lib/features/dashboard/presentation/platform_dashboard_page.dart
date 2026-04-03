import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class PlatformDashboardPage extends StatefulWidget {
  const PlatformDashboardPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<PlatformDashboardPage> createState() => _PlatformDashboardPageState();
}

class _PlatformDashboardPageState extends State<PlatformDashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _organizations = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final organizations = await widget.sessionController.fetchOrganizations();
      if (!mounted) {
        return;
      }
      setState(() {
        _organizations = organizations;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrganizations = _organizations
        .where(
          (item) => item is Map<String, dynamic> && item['is_active'] == true,
        )
        .length;
    final trialOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['billing_status']?.toString().toLowerCase() == 'trial'),
        )
        .length;
    final draftOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['onboarding_status']?.toString().toLowerCase() == 'draft'),
        )
        .length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Platform Dashboard',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Razex Solutions overview for organizations, onboarding progress, and tenant readiness.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _MetricCard(
                label: 'Organizations',
                value: '${_organizations.length}',
              ),
              _MetricCard(label: 'Active', value: '$activeOrganizations'),
              _MetricCard(label: 'Trial', value: '$trialOrganizations'),
              _MetricCard(
                label: 'Draft Onboarding',
                value: '$draftOrganizations',
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(_errorMessage!),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Organizations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    if (_organizations.isEmpty)
                      const Text('No organizations are available yet.')
                    else
                      ..._organizations.map((organization) {
                        final item = organization as Map<String, dynamic>;
                        final brand = item['brand_name']?.toString();
                        final onboarding =
                            item['onboarding_status']?.toString() ?? 'unknown';
                        final billing =
                            item['billing_status']?.toString() ?? 'unknown';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.apartment_outlined),
                          title: Text(
                            item['name']?.toString() ?? 'Organization',
                          ),
                          subtitle: Text(
                            [
                              if (brand != null && brand.isNotEmpty) brand,
                              'Onboarding: $onboarding',
                              'Billing: $billing',
                            ].join(' • '),
                          ),
                          trailing: Text(item['code']?.toString() ?? ''),
                        );
                      }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 10),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      ),
    );
  }
}
