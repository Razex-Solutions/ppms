import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final activeOrganizations = _organizations
        .where(
          (item) => item is Map<String, dynamic> && item['is_active'] == true,
        )
        .length;
    final inactiveOrganizations = _organizations.length - activeOrganizations;
    final trialOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['billing_status']?.toString().toLowerCase() == 'trial'),
        )
        .length;
    final dueOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['billing_status']?.toString().toLowerCase() == 'due'),
        )
        .length;
    final suspendedOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['billing_status']?.toString().toLowerCase() == 'suspended'),
        )
        .length;
    final draftOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['onboarding_status']?.toString().toLowerCase() == 'draft'),
        )
        .length;
    final setupOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['onboarding_status']?.toString().toLowerCase() == 'setup'),
        )
        .length;
    final liveOrganizations = _organizations
        .where(
          (item) =>
              item is Map<String, dynamic> &&
              (item['onboarding_status']?.toString().toLowerCase() == 'live'),
        )
        .length;
    final attentionItems = _buildAttentionItems(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Razex Platform',
            title: 'Platform Dashboard',
            subtitle:
                'Track tenant readiness, onboarding pipeline, and billing health before organizations become operational support cases.',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Open tenants',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_organizations.length}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                DashboardMetricTile(
                  label: 'Live organizations',
                  value: '$liveOrganizations',
                  caption: 'Finished onboarding and active in the platform',
                  icon: Icons.verified_outlined,
                  tint: colorScheme.primary,
                ),
                DashboardMetricTile(
                  label: 'Trial accounts',
                  value: '$trialOrganizations',
                  caption: 'Need billing follow-up before conversion',
                  icon: Icons.schedule_outlined,
                  tint: colorScheme.tertiary,
                ),
                DashboardMetricTile(
                  label: 'Setup in progress',
                  value: '$setupOrganizations',
                  caption: 'Organizations still configuring stations',
                  icon: Icons.construction_outlined,
                  tint: colorScheme.secondary,
                ),
                DashboardMetricTile(
                  label: 'Needs action',
                  value: '${attentionItems.length}',
                  caption: 'Billing, onboarding, or inactive tenant issues',
                  icon: Icons.warning_amber_outlined,
                  tint: colorScheme.error,
                ),
              ],
            ),
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
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1180;
                final pipelineCard = DashboardSectionCard(
                  icon: Icons.account_tree_outlined,
                  title: 'Tenant pipeline',
                  subtitle:
                      'See where organizations sit in onboarding, go-live, and billing follow-up.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardDistributionBar(
                        segments: [
                          DashboardDistributionSegment(
                            label: 'Draft',
                            value: draftOrganizations.toDouble(),
                            color: colorScheme.error,
                            caption: 'Fresh onboardings',
                          ),
                          DashboardDistributionSegment(
                            label: 'Setup',
                            value: setupOrganizations.toDouble(),
                            color: colorScheme.secondary,
                            caption: 'Station config in progress',
                          ),
                          DashboardDistributionSegment(
                            label: 'Live',
                            value: liveOrganizations.toDouble(),
                            color: colorScheme.primary,
                            caption: 'Operational tenants',
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      DashboardDistributionBar(
                        segments: [
                          DashboardDistributionSegment(
                            label: 'Active',
                            value: activeOrganizations.toDouble(),
                            color: colorScheme.primary,
                            caption: 'Usable organizations',
                          ),
                          DashboardDistributionSegment(
                            label: 'Inactive',
                            value: inactiveOrganizations.toDouble(),
                            color: colorScheme.outline,
                            caption: 'Disabled tenants',
                          ),
                          DashboardDistributionSegment(
                            label: 'Trial',
                            value: trialOrganizations.toDouble(),
                            color: colorScheme.tertiary,
                            caption: 'Trial stage billing',
                          ),
                          DashboardDistributionSegment(
                            label: 'Due',
                            value: dueOrganizations.toDouble(),
                            color: colorScheme.error,
                            caption: 'Billing follow-up needed',
                          ),
                          DashboardDistributionSegment(
                            label: 'Suspended',
                            value: suspendedOrganizations.toDouble(),
                            color: colorScheme.errorContainer,
                            caption: 'Access restricted',
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final attentionCard = DashboardSectionCard(
                  icon: Icons.assignment_late_outlined,
                  title: 'Needs attention',
                  subtitle:
                      'Platform-side issues worth fixing before support tickets start coming in.',
                  child: DashboardAttentionList(items: attentionItems),
                );

                final organizationsCard = DashboardSectionCard(
                  icon: Icons.apartment_outlined,
                  title: 'Organization watchlist',
                  subtitle:
                      'Quick look at brands, billing state, and onboarding progression.',
                  child: _organizations.isEmpty
                      ? const Text('No organizations are available yet.')
                      : Column(
                          children: [
                            for (final organization in _organizations.take(12))
                              _OrganizationTile(
                                organization: organization as Map<String, dynamic>,
                              ),
                          ],
                        ),
                );

                if (desktop) {
                  return Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: pipelineCard),
                          const SizedBox(width: 20),
                          Expanded(flex: 2, child: attentionCard),
                        ],
                      ),
                      const SizedBox(height: 20),
                      organizationsCard,
                    ],
                  );
                }

                return Column(
                  children: [
                    pipelineCard,
                    const SizedBox(height: 20),
                    attentionCard,
                    const SizedBox(height: 20),
                    organizationsCard,
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<DashboardAttentionItem> _buildAttentionItems(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = <DashboardAttentionItem>[];
    for (final organization in _organizations) {
      if (organization is! Map<String, dynamic>) {
        continue;
      }
      final name = organization['name']?.toString() ?? 'Organization';
      final code = organization['code']?.toString() ?? '';
      final onboarding =
          organization['onboarding_status']?.toString().toLowerCase() ?? 'unknown';
      final billing =
          organization['billing_status']?.toString().toLowerCase() ?? 'unknown';
      final isActive = organization['is_active'] == true;

      if (billing == 'due' || billing == 'suspended') {
        items.add(
          DashboardAttentionItem(
            title: name,
            subtitle: 'Billing is $billing and needs platform follow-up.',
            icon: Icons.payments_outlined,
            color: colorScheme.error,
            trailing: code,
          ),
        );
      } else if (!isActive) {
        items.add(
          DashboardAttentionItem(
            title: name,
            subtitle: 'Organization is inactive and may need support reactivation.',
            icon: Icons.pause_circle_outline,
            color: colorScheme.outline,
            trailing: code,
          ),
        );
      } else if (onboarding == 'draft' || onboarding == 'setup') {
        items.add(
          DashboardAttentionItem(
            title: name,
            subtitle: 'Onboarding is still in $onboarding and not fully live yet.',
            icon: Icons.assignment_outlined,
            color: colorScheme.secondary,
            trailing: code,
          ),
        );
      }
    }
    return items;
  }
}

class _OrganizationTile extends StatelessWidget {
  const _OrganizationTile({required this.organization});

  final Map<String, dynamic> organization;

  @override
  Widget build(BuildContext context) {
    final brand = organization['brand_name']?.toString();
    final onboarding = organization['onboarding_status']?.toString() ?? 'unknown';
    final billing = organization['billing_status']?.toString() ?? 'unknown';
    final isActive = organization['is_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  organization['name']?.toString() ?? 'Organization',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (brand != null && brand.isNotEmpty) brand,
                    'Onboarding: $onboarding',
                    'Billing: $billing',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                organization['code']?.toString() ?? '',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(isActive ? 'Active' : 'Inactive'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
