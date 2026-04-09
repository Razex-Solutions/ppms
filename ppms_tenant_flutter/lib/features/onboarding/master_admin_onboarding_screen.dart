import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/app_localizations.dart';
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
  final _adminPasswordController = TextEditingController(text: 'office123');
  final _adminEmailController = TextEditingController();
  final _adminPhoneController = TextEditingController();

  int _currentStep = 0;
  int? _selectedBrandId;
  bool _inheritBranding = true;
  bool _isActive = true;
  bool _useOrganizationNameForLegalName = true;
  bool _isSelectingOrganization = false;
  final List<_StationDraft> _stationDrafts = [];
  final Map<String, bool> _moduleSettings = {
    for (final module in _moduleOptions) module: true,
  };

  @override
  void initState() {
    super.initState();
    _ensureStationDrafts(1);
    _nameController.addListener(_syncGeneratedNames);
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncGeneratedNames);
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
    for (final station in _stationDrafts) {
      station.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(organizationsProvider);
    final selectedOrganizationId = ref.watch(selectedOrganizationIdProvider);
    final brandsAsync = ref.watch(brandsProvider);
    final actionState = ref.watch(onboardingActionProvider);
    final summaryAsync = selectedOrganizationId == null
        ? null
        : ref.watch(onboardingSummaryProvider(selectedOrganizationId));
    final foundationAsync = selectedOrganizationId == null
        ? null
        : ref.watch(onboardingFoundationProvider(selectedOrganizationId));

    ref.listen<OnboardingActionState>(onboardingActionProvider, (previous, next) {
      if (!mounted) return;
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('onboardingSaved'))),
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
            SizedBox(width: 360, child: _organizationsCard(context, organizationsAsync)),
            SizedBox(width: 420, child: _summaryCard(context, summaryAsync)),
            SizedBox(width: 420, child: _foundationCard(context, foundationAsync)),
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
                    context.l10n.text('masterAdminTitle'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(context.l10n.text('masterAdminSubtitle')),
                  const SizedBox(height: 20),
                  Stepper(
                    currentStep: _currentStep,
                    onStepTapped: (value) => setState(() => _currentStep = value),
                    controlsBuilder: (context, details) {
                      final isLastStep = _currentStep == 2;
                      return Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: actionState.isSaving
                                  ? null
                                  : isLastStep
                                      ? _submit
                                      : () => setState(() => _currentStep += 1),
                              icon: actionState.isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Icon(isLastStep ? Icons.save_outlined : Icons.arrow_forward),
                              label: Text(isLastStep
                                  ? (selectedOrganizationId == null
                                      ? context.l10n.text('createOrganization')
                                      : context.l10n.text('updateOrganization'))
                                  : 'Next'),
                            ),
                            if (_currentStep > 0)
                              OutlinedButton(
                                onPressed: actionState.isSaving
                                    ? null
                                    : () => setState(() => _currentStep -= 1),
                                child: const Text('Back'),
                              ),
                            if (selectedOrganizationId != null)
                              OutlinedButton(
                                onPressed: actionState.isSaving ? null : _resetForm,
                                child: Text(context.l10n.text('startNew')),
                              ),
                          ],
                        ),
                      );
                    },
                    steps: [
                      Step(
                        isActive: _currentStep >= 0,
                        title: Text(context.l10n.text('organizationBasicsStep')),
                        content: _organizationStep(context, brandsAsync),
                      ),
                      Step(
                        isActive: _currentStep >= 1,
                        title: Text(context.l10n.text('stationPlanningStep')),
                        content: _stationStep(context),
                      ),
                      Step(
                        isActive: _currentStep >= 2,
                        title: Text(context.l10n.text('adminStep')),
                        content: _adminStep(context, summaryAsync),
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

  Widget _organizationStep(
    BuildContext context,
    AsyncValue<List<BrandOption>> brandsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: 320, child: _nameField(context)),
            SizedBox(width: 320, child: _legalNameField(context)),
            SizedBox(width: 220, child: _brandField(context, brandsAsync)),
            SizedBox(width: 280, child: _emailField(context)),
            SizedBox(width: 280, child: _phoneField(context)),
            SizedBox(width: 240, child: _registrationField(context)),
            SizedBox(width: 240, child: _taxField(context)),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilterChip(
              label: Text(context.l10n.text('sameAsOrganizationName')),
              selected: _useOrganizationNameForLegalName,
              onSelected: (value) {
                setState(() {
                  _useOrganizationNameForLegalName = value;
                  if (value) {
                    _legalNameController.text = _nameController.text.trim();
                  }
                });
              },
            ),
            FilterChip(
              label: Text(context.l10n.text('inheritBrandingToStations')),
              selected: _inheritBranding,
              onSelected: (value) => setState(() => _inheritBranding = value),
            ),
            FilterChip(
              label: Text(context.l10n.text('organizationActive')),
              selected: _isActive,
              onSelected: (value) => setState(() => _isActive = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InfoCard(
          title: context.l10n.text('brandPreview'),
          body: _selectedBrandId == null
              ? context.l10n.text('noBrand')
              : 'Backend will attach the linked brand name, code, and logo defaults.',
          icon: Icons.palette_outlined,
        ),
      ],
    );
  }

  Widget _stationStep(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 220, child: _stationCountField(context)),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('stationDraftsTitle'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(context.l10n.text('stationDraftsHint')),
                const SizedBox(height: 6),
                Text(context.l10n.text('stationDraftsSingleHint')),
                const SizedBox(height: 12),
                for (var index = 0; index < _stationDrafts.length; index++)
                  _StationDraftCard(
                    index: index,
                    draft: _stationDrafts[index],
                    isSingleStation: _stationDrafts.length == 1,
                    onHeadOfficeSelected: () => setState(() => _markHeadOffice(index)),
                    onChanged: () => setState(() {}),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.text('moduleToggles'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final module in _moduleOptions)
              FilterChip(
                label: Text(_moduleLabel(module)),
                selected: _moduleSettings[module] ?? false,
                onSelected: (value) {
                  setState(() {
                    _moduleSettings[module] = value;
                  });
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _adminStep(
    BuildContext context,
    AsyncValue<OrganizationOnboardingSummary>? summaryAsync,
  ) {
    final stationCount = int.tryParse(_stationTargetController.text) ?? 1;
    final hint = stationCount == 1
        ? 'Single-station onboarding keeps one acting HeadOffice owner.'
        : 'Multi-station onboarding starts with HeadOffice, then station admins are assigned later.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('firstAdmin'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(hint),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: 260, child: _adminFullNameField(context)),
            SizedBox(width: 220, child: _adminUsernameField(context)),
            SizedBox(width: 220, child: _adminPasswordField(context)),
            SizedBox(width: 260, child: _adminEmailField(context)),
            SizedBox(width: 240, child: _adminPhoneField(context)),
          ],
        ),
        const SizedBox(height: 16),
        if (summaryAsync != null)
          summaryAsync.when(
            data: (summary) => Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.text('topIssues'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    if (summary.pendingIssues.isEmpty)
                      const Text('No blocking onboarding issues right now.')
                    else
                      for (final issue in summary.pendingIssues.take(5))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            issue.blocking ? Icons.error_outline : Icons.info_outline,
                          ),
                          title: Text(issue.title),
                          subtitle: Text(issue.detail),
                        ),
                  ],
                ),
              ),
            ),
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(message: 'Summary failed: $error'),
          ),
      ],
    );
  }

  Widget _organizationsCard(
    BuildContext context,
    AsyncValue<List<OrganizationListItem>> asyncValue,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: asyncValue.when(
          data: (organizations) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.text('organizations'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              if (_isSelectingOrganization) const LinearProgressIndicator(),
              if (organizations.isEmpty)
                Text(context.l10n.text('noOrganizationsYet'))
              else
                for (final organization in organizations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(organization.name),
                    subtitle:
                        Text('${organization.code} • ${organization.onboardingStatus}'),
                    trailing: TextButton(
                      onPressed: () => _selectOrganization(organization),
                      child: Text(context.l10n.text('open')),
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

  Widget _summaryCard(
    BuildContext context,
    AsyncValue<OrganizationOnboardingSummary>? asyncValue,
  ) {
    if (asyncValue == null) {
      return InfoCard(
        title: context.l10n.text('onboardingProgress'),
        body: context.l10n.text('onboardingProgressHint'),
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
                'Stations ${summary.currentStationCount}/${summary.targetStationCount ?? '-'} • Pending ${summary.pendingStationCount}',
              ),
              const SizedBox(height: 12),
              for (final step in summary.steps)
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
            ],
          ),
        ),
      ),
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: 'Summary failed: $error'),
    );
  }

  Widget _foundationCard(
    BuildContext context,
    AsyncValue<OrganizationSetupFoundation>? asyncValue,
  ) {
    if (asyncValue == null) {
      return InfoCard(
        title: context.l10n.text('stationChecklist'),
        body: context.l10n.text('stationChecklistHint'),
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
              Text(
                context.l10n.text('stationChecklist'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              for (final station in foundation.stations)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${station.name} (${station.code})'),
                  subtitle: Text(
                    '${station.isHeadOffice ? context.l10n.text('headOfficeStation') : context.l10n.text('station')} • ${station.setupStatus}',
                  ),
                  trailing: TextButton(
                    onPressed: () => context.go('/station-setup/${station.id}'),
                    child: Text(context.l10n.text('configure')),
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

  Widget _brandField(
    BuildContext context,
    AsyncValue<List<BrandOption>> brandsAsync,
  ) {
    return brandsAsync.when(
      data: (brands) => DropdownButtonFormField<int?>(
        initialValue: _selectedBrandId,
        decoration: InputDecoration(labelText: context.l10n.text('brand')),
        items: [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(context.l10n.text('noBrand')),
          ),
          ...brands.map(
            (brand) => DropdownMenuItem<int?>(
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

  TextFormField _nameField(BuildContext context) => TextFormField(
        controller: _nameController,
        decoration: InputDecoration(labelText: context.l10n.text('organizationName')),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Organization name is required'
            : null,
      );

  TextFormField _legalNameField(BuildContext context) => TextFormField(
        controller: _legalNameController,
        enabled: !_useOrganizationNameForLegalName,
        decoration: InputDecoration(labelText: context.l10n.text('legalName')),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Legal name is required'
            : null,
      );

  TextFormField _stationCountField(BuildContext context) => TextFormField(
        controller: _stationTargetController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: context.l10n.text('stationCount')),
        validator: (value) {
          final count = int.tryParse(value ?? '');
          if (count == null || count < 1) return 'Enter at least 1 station';
          return null;
        },
        onChanged: (value) {
          final count = int.tryParse(value) ?? 1;
          setState(() => _ensureStationDrafts(count));
        },
      );

  TextFormField _emailField(BuildContext context) => TextFormField(
        controller: _emailController,
        decoration: InputDecoration(labelText: context.l10n.text('contactEmail')),
      );

  TextFormField _phoneField(BuildContext context) => TextFormField(
        controller: _phoneController,
        decoration: InputDecoration(labelText: context.l10n.text('contactPhone')),
      );

  TextFormField _registrationField(BuildContext context) => TextFormField(
        controller: _registrationController,
        decoration:
            InputDecoration(labelText: context.l10n.text('registrationNumber')),
      );

  TextFormField _taxField(BuildContext context) => TextFormField(
        controller: _taxController,
        decoration: InputDecoration(labelText: context.l10n.text('taxNumber')),
      );

  TextFormField _adminFullNameField(BuildContext context) => TextFormField(
        controller: _adminFullNameController,
        decoration: InputDecoration(labelText: context.l10n.text('adminFullName')),
      );

  TextFormField _adminUsernameField(BuildContext context) => TextFormField(
        controller: _adminUsernameController,
        decoration: InputDecoration(labelText: context.l10n.text('adminUsername')),
      );

  TextFormField _adminPasswordField(BuildContext context) => TextFormField(
        controller: _adminPasswordController,
        decoration: InputDecoration(labelText: context.l10n.text('adminPassword')),
      );

  TextFormField _adminEmailField(BuildContext context) => TextFormField(
        controller: _adminEmailController,
        decoration: InputDecoration(labelText: context.l10n.text('adminEmail')),
      );

  TextFormField _adminPhoneField(BuildContext context) => TextFormField(
        controller: _adminPhoneController,
        decoration: InputDecoration(labelText: context.l10n.text('adminPhone')),
      );

  Future<void> _selectOrganization(OrganizationListItem item) async {
    setState(() => _isSelectingOrganization = true);
    try {
      final repository = ref.read(onboardingRepositoryProvider);
      final detail = await repository.getOrganizationDetail(item.id);
      final foundation = await repository.getFoundation(item.id);
      ref.read(selectedOrganizationIdProvider.notifier).select(item.id);
      _nameController.text = detail.name;
      _useOrganizationNameForLegalName =
          detail.legalName == null || detail.legalName == detail.name;
      _legalNameController.text = detail.legalName ?? detail.name;
      _emailController.text = detail.contactEmail ?? '';
      _phoneController.text = detail.contactPhone ?? '';
      _registrationController.text = detail.registrationNumber ?? '';
      _taxController.text = detail.taxRegistrationNumber ?? '';
      _stationTargetController.text = '${detail.stationTargetCount ?? 1}';
      _selectedBrandId = detail.brandCatalogId;
      _inheritBranding = detail.inheritBrandingToStations;
      _isActive = detail.isActive;
      _ensureStationDrafts(detail.stationTargetCount ?? foundation.stations.length);
      for (var index = 0; index < _stationDrafts.length; index++) {
        if (index >= foundation.stations.length) continue;
        final station = foundation.stations[index];
        _stationDrafts[index].nameController.text = station.name;
        _stationDrafts[index].codeController.text = station.code;
        _stationDrafts[index].isHeadOffice = station.isHeadOffice;
      }
      setState(() {});
    } finally {
      if (mounted) setState(() => _isSelectingOrganization = false);
    }
  }

  void _resetForm() {
    ref.read(selectedOrganizationIdProvider.notifier).select(null);
    _currentStep = 0;
    _nameController.clear();
    _legalNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _registrationController.clear();
    _taxController.clear();
    _stationTargetController.text = '1';
    _adminFullNameController.clear();
    _adminUsernameController.clear();
    _adminPasswordController.text = 'office123';
    _adminEmailController.clear();
    _adminPhoneController.clear();
    _selectedBrandId = null;
    _inheritBranding = true;
    _isActive = true;
    _useOrganizationNameForLegalName = true;
    for (final module in _moduleOptions) {
      _moduleSettings[module] = true;
    }
    _ensureStationDrafts(1, resetExisting: true);
    setState(() {});
  }

  void _syncGeneratedNames() {
    if (_useOrganizationNameForLegalName) {
      _legalNameController.text = _nameController.text.trim();
    }
    for (var index = 0; index < _stationDrafts.length; index++) {
      final station = _stationDrafts[index];
      if (station.nameWasGenerated) {
        station.nameController.text = _defaultStationName(index + 1);
      }
      if (station.codeWasGenerated) {
        station.codeController.text = _defaultStationCode(index + 1);
      }
    }
    if (mounted) setState(() {});
  }

  void _ensureStationDrafts(int count, {bool resetExisting = false}) {
    final safeCount = count < 1 ? 1 : count;
    if (resetExisting) {
      for (final station in _stationDrafts) {
        station.dispose();
      }
      _stationDrafts.clear();
    }
    while (_stationDrafts.length < safeCount) {
      final index = _stationDrafts.length + 1;
      _stationDrafts.add(
        _StationDraft(
          name: _defaultStationName(index),
          code: _defaultStationCode(index),
          isHeadOffice: index == 1,
        ),
      );
    }
    while (_stationDrafts.length > safeCount) {
      _stationDrafts.removeLast().dispose();
    }
    if (safeCount == 1) {
      _stationDrafts.first.isHeadOffice = true;
    } else if (!_stationDrafts.any((item) => item.isHeadOffice)) {
      _stationDrafts.first.isHeadOffice = true;
    }
  }

  String _defaultStationName(int index) {
    final organizationName = _nameController.text.trim();
    if (organizationName.isEmpty) return 'Station $index';
    if ((int.tryParse(_stationTargetController.text) ?? 1) == 1) {
      return organizationName;
    }
    return '$organizationName Station $index';
  }

  String _defaultStationCode(int index) {
    final parts = _nameController.text
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .toList();
    final prefix = parts.isEmpty
        ? 'ORG'
        : parts.map((part) => part[0].toUpperCase()).join().padRight(3, 'X');
    return '${prefix.substring(0, 3)}-S${index.toString().padLeft(2, '0')}';
  }

  void _markHeadOffice(int index) {
    for (var itemIndex = 0; itemIndex < _stationDrafts.length; itemIndex++) {
      _stationDrafts[itemIndex].isHeadOffice = itemIndex == index;
    }
  }

  String _moduleLabel(String value) {
    return value
        .split('_')
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final selectedOrganizationId = ref.read(selectedOrganizationIdProvider);
    await ref.read(onboardingActionProvider.notifier).submit(
          organizationId: selectedOrganizationId,
          name: _nameController.text.trim(),
          legalName: _useOrganizationNameForLegalName
              ? _nameController.text.trim()
              : _legalNameController.text.trim(),
          contactEmail: _emailController.text,
          contactPhone: _phoneController.text,
          registrationNumber: _registrationController.text,
          taxRegistrationNumber: _taxController.text,
          stationTargetCount: int.parse(_stationTargetController.text),
          inheritBrandingToStations: _inheritBranding,
          isActive: _isActive,
          brandCatalogId: _selectedBrandId,
          moduleSettings: _moduleSettings.entries
              .map((entry) => {
                    'module_name': entry.key,
                    'is_enabled': entry.value,
                  })
              .toList(),
          stations: _stationDrafts
              .map(
                (station) => {
                  'name': station.nameController.text.trim(),
                  'code': station.codeController.text.trim().isEmpty
                      ? null
                      : station.codeController.text.trim(),
                  'display_name': station.nameController.text.trim(),
                  'is_head_office': station.isHeadOffice,
                  'use_organization_branding': _inheritBranding,
                  'is_active': station.isActive,
                },
              )
              .toList(),
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

class _StationDraft {
  _StationDraft({
    required String name,
    required String code,
    required this.isHeadOffice,
  })  : nameController = TextEditingController(text: name),
        codeController = TextEditingController(text: code);

  final TextEditingController nameController;
  final TextEditingController codeController;
  bool isHeadOffice;
  bool isActive = true;
  bool nameWasGenerated = true;
  bool codeWasGenerated = true;

  void dispose() {
    nameController.dispose();
    codeController.dispose();
  }
}

class _StationDraftCard extends StatelessWidget {
  const _StationDraftCard({
    required this.index,
    required this.draft,
    required this.isSingleStation,
    required this.onHeadOfficeSelected,
    required this.onChanged,
  });

  final int index;
  final _StationDraft draft;
  final bool isSingleStation;
  final VoidCallback onHeadOfficeSelected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 260,
              child: TextField(
                controller: draft.nameController,
                decoration: InputDecoration(
                  labelText: '${context.l10n.text('stationName')} ${index + 1}',
                ),
                onChanged: (_) {
                  draft.nameWasGenerated = false;
                  onChanged();
                },
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: draft.codeController,
                decoration:
                    InputDecoration(labelText: context.l10n.text('stationCode')),
                onChanged: (_) {
                  draft.codeWasGenerated = false;
                  onChanged();
                },
              ),
            ),
            FilterChip(
              label: Text(context.l10n.text('headOfficeStation')),
              selected: draft.isHeadOffice,
              onSelected: isSingleStation ? null : (_) => onHeadOfficeSelected(),
            ),
            FilterChip(
              label: Text(context.l10n.text('activeStation')),
              selected: draft.isActive,
              onSelected: (value) {
                draft.isActive = value;
                onChanged();
              },
            ),
          ],
        ),
      ),
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
