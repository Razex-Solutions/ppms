import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/info_card.dart';
import 'models/onboarding_models.dart';
import 'onboarding_repository.dart';

const _moduleOptions = <String>[
  'attendance',
  'payroll',
  'tankers',
  'notifications',
  'reports',
  'pos_sales',
  'expenses',
  'customers',
];

class MasterAdminOnboardingScreen extends ConsumerStatefulWidget {
  const MasterAdminOnboardingScreen({super.key});

  @override
  ConsumerState<MasterAdminOnboardingScreen> createState() =>
      _MasterAdminOnboardingScreenState();
}

class _MasterAdminOnboardingScreenState
    extends ConsumerState<MasterAdminOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registrationController = TextEditingController();
  final _taxController = TextEditingController();
  final _stationTargetController = TextEditingController(text: '1');
  final _adminFullNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminPasswordController = TextEditingController(text: 'password123');
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  int? _selectedBrandId;
  bool _inheritBranding = true;
  bool _isActive = true;
  final Map<String, bool> _moduleSettings = {
    for (final module in _moduleOptions) module: true,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _legalNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _registrationController.dispose();
    _taxController.dispose();
    _stationTargetController.dispose();
    _adminFullNameController.dispose();
    _adminUsernameController.dispose();
    _adminPasswordController.dispose();
    _adminEmailController.dispose();
    _adminPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(organizationsProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final selectedOrganizationId = ref.watch(selectedOrganizationIdProvider);
    final actionState = ref.watch(onboardingActionProvider);
    final summaryAsync = selectedOrganizationId == null
        ? null
        : ref.watch(onboardingSummaryProvider(selectedOrganizationId));
    final foundationAsync = selectedOrganizationId == null
        ? null
        : ref.watch(onboardingFoundationProvider(selectedOrganizationId));

    ref.listen<OnboardingActionState>(onboardingActionProvider, (previous, next) {
      if (!mounted) {
        return;
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Onboarding details saved.')),
        );
        ref.read(onboardingActionProvider.notifier).clearMessage();
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: 360, child: _organizationsCard(organizationsAsync)),
            SizedBox(width: 420, child: _summaryCard(summaryAsync)),
            SizedBox(width: 420, child: _foundationCard(foundationAsync)),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MasterAdmin onboarding workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This phase covers organization basics, brand default, station count, module toggles, first admin assignment, and handoff into station setup.',
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(width: 320, child: _nameField()),
                      SizedBox(width: 320, child: _legalNameField()),
                      SizedBox(width: 220, child: _brandField(brandsAsync)),
                      SizedBox(width: 220, child: _stationCountField()),
                      SizedBox(width: 280, child: _emailField()),
                      SizedBox(width: 280, child: _phoneField()),
                      SizedBox(width: 240, child: _registrationField()),
                      SizedBox(width: 240, child: _taxField()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilterChip(
                        label: const Text('Inherit branding to stations'),
                        selected: _inheritBranding,
                        onSelected: (value) => setState(() => _inheritBranding = value),
                      ),
                      FilterChip(
                        label: const Text('Organization active'),
                        selected: _isActive,
                        onSelected: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Module toggles', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final module in _moduleOptions)
                        FilterChip(
                          label: Text(module),
                          selected: _moduleSettings[module] ?? false,
                          onSelected: (value) {
                            setState(() {
                              _moduleSettings[module] = value;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('First admin', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(width: 260, child: _adminFullNameField()),
                      SizedBox(width: 220, child: _adminUsernameField()),
                      SizedBox(width: 220, child: _adminPasswordField()),
                      SizedBox(width: 260, child: _adminEmailField()),
                      SizedBox(width: 240, child: _adminPhoneField()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _generatedStationsPreview(),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: actionState.isSaving ? null : _submit,
                        icon: actionState.isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          selectedOrganizationId == null
                              ? 'Create organization'
                              : 'Update organization',
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (selectedOrganizationId != null)
                        OutlinedButton(
                          onPressed: actionState.isSaving ? null : _resetForm,
                          child: const Text('Start new'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _organizationsCard(AsyncValue<List<OrganizationListItem>> asyncValue) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: asyncValue.when(
          data: (organizations) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Organizations', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              if (organizations.isEmpty)
                const Text('No organizations yet.')
              else
                for (final organization in organizations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(organization.name),
                    subtitle: Text(
                      '${organization.code} - ${organization.onboardingStatus}',
                    ),
                    trailing: TextButton(
                      onPressed: () => _selectOrganization(organization),
                      child: const Text('Open'),
                    ),
                  ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text('Organizations failed: $error'),
        ),
      ),
    );
  }

  Widget _summaryCard(AsyncValue<OrganizationOnboardingSummary>? asyncValue) {
    if (asyncValue == null) {
      return const InfoCard(
        title: 'Onboarding progress',
        body: 'Select an organization to see its setup progress and blockers.',
        icon: Icons.timeline_outlined,
      );
    }
    return asyncValue.when(
      data: (summary) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${summary.organizationName} (${summary.progressPercent}%)',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Stations ${summary.currentStationCount}/${summary.targetStationCount ?? '-'} - Pending ${summary.pendingStationCount}',
              ),
              const SizedBox(height: 12),
              for (final step in summary.steps.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    step.status == 'completed'
                        ? Icons.check_circle_outline
                        : Icons.pending_outlined,
                  ),
                  title: Text(step.title),
                  subtitle: Text(step.detail),
                ),
              if (summary.pendingIssues.isNotEmpty) ...[
                const Divider(),
                Text('Top issues', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                for (final issue in summary.pendingIssues.take(3))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(issue.title),
                    subtitle: Text(issue.detail),
                  ),
              ],
            ],
          ),
        ),
      ),
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: 'Summary failed: $error'),
    );
  }

  Widget _foundationCard(AsyncValue<OrganizationSetupFoundation>? asyncValue) {
    if (asyncValue == null) {
      return const InfoCard(
        title: 'Station checklist',
        body: 'Station setup cards appear here after you open an organization.',
        icon: Icons.checklist_rtl_outlined,
      );
    }
    return asyncValue.when(
      data: (foundation) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Station checklist', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              for (final station in foundation.stations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${station.name} (${station.code})'),
                  subtitle: Text(
                    '${station.isHeadOffice ? 'Head office' : 'Station'} - ${station.setupStatus}',
                  ),
                  trailing: TextButton(
                    onPressed: () => context.go('/station-setup/${station.id}'),
                    child: const Text('Configure'),
                  ),
                ),
            ],
          ),
        ),
      ),
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: 'Foundation failed: $error'),
    );
  }

  Widget _brandField(AsyncValue<List<BrandOption>> brandsAsync) {
    return brandsAsync.when(
      data: (brands) => DropdownButtonFormField<int>(
        initialValue: _selectedBrandId,
        decoration: const InputDecoration(labelText: 'Brand'),
        items: [
          const DropdownMenuItem<int>(value: null, child: Text('No brand')),
          ...brands.map(
            (brand) => DropdownMenuItem<int>(
              value: brand.id,
              child: Text('${brand.name} (${brand.code})'),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedBrandId = value),
      ),
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('Brands failed: $error'),
    );
  }

  Widget _generatedStationsPreview() {
    final count = int.tryParse(_stationTargetController.text) ?? 1;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Auto-generated stations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Organization save creates station drafts automatically. Use the Configure action in the station checklist to complete forecourt setup.',
            ),
            const SizedBox(height: 10),
            for (var index = 1; index <= count; index++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  index == 1 ? Icons.apartment_outlined : Icons.storefront_outlined,
                ),
                title: Text('Station $index'),
                subtitle: Text(
                  index == 1 && count > 1
                      ? 'Head office candidate'
                      : 'Auto-generated draft',
                ),
              ),
          ],
        ),
      ),
    );
  }

  TextFormField _nameField() => TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(labelText: 'Organization name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Organization name is required'
            : null,
      );

  TextFormField _legalNameField() => TextFormField(
        controller: _legalNameController,
        decoration: const InputDecoration(labelText: 'Legal name'),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Legal name is required'
            : null,
      );

  TextFormField _stationCountField() => TextFormField(
        controller: _stationTargetController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Station count'),
        validator: (value) {
          final count = int.tryParse(value ?? '');
          if (count == null || count < 1) {
            return 'Enter at least 1 station';
          }
          return null;
        },
        onChanged: (_) => setState(() {}),
      );

  TextFormField _emailField() => TextFormField(
        controller: _emailController,
        decoration: const InputDecoration(labelText: 'Contact email'),
      );

  TextFormField _phoneField() => TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(labelText: 'Contact phone'),
      );

  TextFormField _registrationField() => TextFormField(
        controller: _registrationController,
        decoration: const InputDecoration(labelText: 'Registration number'),
      );

  TextFormField _taxField() => TextFormField(
        controller: _taxController,
        decoration: const InputDecoration(labelText: 'Tax / GST number'),
      );

  TextFormField _adminFullNameField() => TextFormField(
        controller: _adminFullNameController,
        decoration: const InputDecoration(labelText: 'Admin full name'),
      );

  TextFormField _adminUsernameField() => TextFormField(
        controller: _adminUsernameController,
        decoration: const InputDecoration(labelText: 'Admin username'),
      );

  TextFormField _adminPasswordField() => TextFormField(
        controller: _adminPasswordController,
        decoration: const InputDecoration(labelText: 'Admin password'),
      );

  TextFormField _adminEmailField() => TextFormField(
        controller: _adminEmailController,
        decoration: const InputDecoration(labelText: 'Admin email'),
      );

  TextFormField _adminPhoneField() => TextFormField(
        controller: _adminPhoneController,
        decoration: const InputDecoration(labelText: 'Admin phone'),
      );

  void _selectOrganization(OrganizationListItem item) {
    ref.read(selectedOrganizationIdProvider.notifier).select(item.id);
    _nameController.text = item.name;
    _legalNameController.text = item.name;
    _stationTargetController.text = '${item.stationTargetCount ?? 1}';
  }

  void _resetForm() {
    ref.read(selectedOrganizationIdProvider.notifier).select(null);
    _nameController.clear();
    _legalNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _registrationController.clear();
    _taxController.clear();
    _stationTargetController.text = '1';
    _adminFullNameController.clear();
    _adminUsernameController.clear();
    _adminPasswordController.text = 'password123';
    _adminEmailController.clear();
    _adminPhoneController.clear();
    _selectedBrandId = null;
    _inheritBranding = true;
    _isActive = true;
    for (final module in _moduleOptions) {
      _moduleSettings[module] = true;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final stationCount = int.parse(_stationTargetController.text);
    final selectedOrganizationId = ref.read(selectedOrganizationIdProvider);
    await ref.read(onboardingActionProvider.notifier).submit(
          organizationId: selectedOrganizationId,
          name: _nameController.text.trim(),
          legalName: _legalNameController.text.trim(),
          contactEmail: _emailController.text,
          contactPhone: _phoneController.text,
          registrationNumber: _registrationController.text,
          taxRegistrationNumber: _taxController.text,
          stationTargetCount: stationCount,
          inheritBrandingToStations: _inheritBranding,
          isActive: _isActive,
          brandCatalogId: _selectedBrandId,
          moduleSettings: _moduleSettings.entries
              .map(
                (entry) => {
                  'module_name': entry.key,
                  'is_enabled': entry.value,
                },
              )
              .toList(),
          stations: List.generate(
            stationCount,
            (index) => {
              'name': 'Station ${index + 1}',
              'display_name': 'Station ${index + 1}',
              'is_head_office': stationCount > 1 ? index == 0 : true,
              'use_organization_branding': _inheritBranding,
              'is_active': true,
            },
          ),
          initialAdmin: _adminUsernameController.text.trim().isEmpty
              ? null
              : {
                  'full_name': _adminFullNameController.text.trim(),
                  'username': _adminUsernameController.text.trim(),
                  'email': _adminEmailController.text.trim().isEmpty
                      ? null
                      : _adminEmailController.text.trim(),
                  'phone': _adminPhoneController.text.trim().isEmpty
                      ? null
                      : _adminPhoneController.text.trim(),
                  'password': _adminPasswordController.text,
                },
        );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}
