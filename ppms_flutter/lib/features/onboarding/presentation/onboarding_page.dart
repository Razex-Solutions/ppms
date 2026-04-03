import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _organizationNameController = TextEditingController();
  final _organizationCodeController = TextEditingController();
  final _organizationDescriptionController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _registrationController = TextEditingController();
  final _taxRegistrationController = TextEditingController();
  final _headOfficeNameController = TextEditingController();
  final _headOfficeUsernameController = TextEditingController();
  final _headOfficeEmailController = TextEditingController();
  final _headOfficePasswordController = TextEditingController(
    text: 'office123',
  );

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _inheritBranding = true;
  bool _createHeadOfficeAccount = true;
  String? _errorMessage;
  String? _feedbackMessage;
  String _selectedBrand = 'Custom';
  int _stationCount = 1;
  List<Map<String, dynamic>> _organizations = const [];
  List<Map<String, dynamic>> _roles = const [];
  late List<_StationDraft> _stationDrafts;

  static const _brands = <String>[
    'Custom',
    'Shell',
    'PSO',
    'Caltex',
    'Total',
    'Attock',
    'Hascol',
  ];

  @override
  void initState() {
    super.initState();
    _stationDrafts = [_StationDraft()];
    _loadWorkspace();
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _organizationCodeController.dispose();
    _organizationDescriptionController.dispose();
    _legalNameController.dispose();
    _logoUrlController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _registrationController.dispose();
    _taxRegistrationController.dispose();
    _headOfficeNameController.dispose();
    _headOfficeUsernameController.dispose();
    _headOfficeEmailController.dispose();
    _headOfficePasswordController.dispose();
    for (final draft in _stationDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final organizations = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchOrganizations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final roles = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchRoles()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _organizations = organizations;
        _roles = roles;
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

  void _syncStationDraftCount(int count) {
    if (count < 1) {
      count = 1;
    }
    setState(() {
      while (_stationDrafts.length < count) {
        _stationDrafts.add(_StationDraft());
      }
      while (_stationDrafts.length > count) {
        _stationDrafts.removeLast().dispose();
      }
      _stationCount = count;
      if (_stationDrafts.isNotEmpty) {
        _stationDrafts.first.isHeadOffice = true;
      }
    });
  }

  Future<void> _submitOnboarding() async {
    if (_organizationNameController.text.trim().isEmpty ||
        _organizationCodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Organization name and code are required.';
      });
      return;
    }
    for (final draft in _stationDrafts) {
      if (draft.nameController.text.trim().isEmpty ||
          draft.codeController.text.trim().isEmpty) {
        setState(() {
          _errorMessage = 'Every station needs a name and code.';
        });
        return;
      }
    }
    if (_createHeadOfficeAccount &&
        (_headOfficeNameController.text.trim().isEmpty ||
            _headOfficeUsernameController.text.trim().isEmpty ||
            _headOfficePasswordController.text.trim().isEmpty)) {
      setState(() {
        _errorMessage =
            'Head office name, username, and password are required when creating the initial account.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final organization = await widget.sessionController.createOrganization({
        'name': _organizationNameController.text.trim(),
        'code': _organizationCodeController.text.trim(),
        'description': _emptyToNull(_organizationDescriptionController.text),
        'legal_name': _emptyToNull(_legalNameController.text),
        'brand_name': _selectedBrand == 'Custom' ? null : _selectedBrand,
        'brand_code': _selectedBrand == 'Custom'
            ? 'CUSTOM'
            : _selectedBrand.toUpperCase(),
        'logo_url': _emptyToNull(_logoUrlController.text),
        'contact_email': _emptyToNull(_contactEmailController.text),
        'contact_phone': _emptyToNull(_contactPhoneController.text),
        'registration_number': _emptyToNull(_registrationController.text),
        'tax_registration_number': _emptyToNull(
          _taxRegistrationController.text,
        ),
        'onboarding_status': 'active',
        'billing_status': 'trial',
        'station_target_count': _stationCount,
        'inherit_branding_to_stations': _inheritBranding,
        'is_active': true,
      });

      final organizationId = organization['id'] as int;
      int? firstStationId;
      for (var i = 0; i < _stationDrafts.length; i++) {
        final draft = _stationDrafts[i];
        final station = await widget.sessionController.createStation({
          'name': draft.nameController.text.trim(),
          'code': draft.codeController.text.trim(),
          'address': _emptyToNull(draft.addressController.text),
          'city': _emptyToNull(draft.cityController.text),
          'organization_id': organizationId,
          'is_head_office': draft.isHeadOffice,
          'display_name': _emptyToNull(draft.displayNameController.text),
          'logo_url': _emptyToNull(draft.logoUrlController.text),
          'use_organization_branding': draft.useOrganizationBranding,
          'setup_status': 'draft',
          'has_shops': draft.hasShops,
          'has_pos': draft.hasPos,
          'has_tankers': draft.hasTankers,
          'has_hardware': draft.hasHardware,
          'allow_meter_adjustments': draft.allowMeterAdjustments,
        });
        firstStationId ??= station['id'] as int;
      }

      if (_createHeadOfficeAccount) {
        final headOfficeRole = _roles.cast<Map<String, dynamic>?>().firstWhere(
          (role) => role?['name'] == 'HeadOffice',
          orElse: () => null,
        );
        if (headOfficeRole != null) {
          await widget.sessionController.createUser({
            'full_name': _headOfficeNameController.text.trim(),
            'username': _headOfficeUsernameController.text.trim(),
            'email': _emptyToNull(_headOfficeEmailController.text),
            'password': _headOfficePasswordController.text.trim(),
            'role_id': headOfficeRole['id'] as int,
            'organization_id': organizationId,
            'scope_level': 'organization',
          });
        }
      }

      if (!mounted) {
        return;
      }
      _resetForm();
      await _loadWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Organization ${organization['name']} created with $_stationCount station(s)'
            '${_createHeadOfficeAccount ? ' and initial head office login' : ''}.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  void _resetForm() {
    _organizationNameController.clear();
    _organizationCodeController.clear();
    _organizationDescriptionController.clear();
    _legalNameController.clear();
    _logoUrlController.clear();
    _contactEmailController.clear();
    _contactPhoneController.clear();
    _registrationController.clear();
    _taxRegistrationController.clear();
    _headOfficeNameController.clear();
    _headOfficeUsernameController.clear();
    _headOfficeEmailController.clear();
    _headOfficePasswordController.text = 'office123';
    _selectedBrand = 'Custom';
    _inheritBranding = true;
    _createHeadOfficeAccount = true;
    _syncStationDraftCount(1);
    for (final draft in _stationDrafts) {
      draft.reset();
    }
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Organization Onboarding',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a company, define branding, add stations, and optionally create the first head office login.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  ResponsiveSplit(
                    breakpoint: 1220,
                    primary: _buildPrimaryPane(context),
                    secondary: _buildSecondaryPane(context),
                  ),
                  if (_errorMessage != null || _feedbackMessage != null)
                    const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_feedbackMessage != null)
                    Text(
                      _feedbackMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryPane(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Organization', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationNameController,
          decoration: const InputDecoration(labelText: 'Organization Name'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationCodeController,
          decoration: const InputDecoration(labelText: 'Organization Code'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('onboarding-brand-$_selectedBrand'),
          initialValue: _selectedBrand,
          decoration: const InputDecoration(labelText: 'Brand'),
          items: [
            for (final brand in _brands)
              DropdownMenuItem<String>(value: brand, child: Text(brand)),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBrand = value ?? 'Custom';
            });
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _legalNameController,
          decoration: const InputDecoration(labelText: 'Legal Name'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationDescriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _logoUrlController,
          decoration: const InputDecoration(labelText: 'Logo URL'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _contactEmailController,
          decoration: const InputDecoration(labelText: 'Contact Email'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _contactPhoneController,
          decoration: const InputDecoration(labelText: 'Contact Phone'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _registrationController,
          decoration: const InputDecoration(labelText: 'Registration Number'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _taxRegistrationController,
          decoration: const InputDecoration(
            labelText: 'Tax Registration Number',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          key: ValueKey<int>(_stationCount),
          initialValue: _stationCount,
          decoration: const InputDecoration(labelText: 'Station Count'),
          items: List.generate(
            5,
            (index) => DropdownMenuItem<int>(
              value: index + 1,
              child: Text('${index + 1}'),
            ),
          ),
          onChanged: (value) {
            if (value != null) {
              _syncStationDraftCount(value);
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _inheritBranding,
          title: const Text('Inherit organization branding to stations'),
          onChanged: (value) {
            setState(() {
              _inheritBranding = value;
            });
          },
        ),
        const SizedBox(height: 24),
        Text('Stations', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        for (var index = 0; index < _stationDrafts.length; index++)
          _StationDraftCard(index: index, draft: _stationDrafts[index]),
        const SizedBox(height: 24),
        Text(
          'Initial Head Office Login',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _createHeadOfficeAccount,
          title: const Text('Create first HeadOffice user'),
          onChanged: (value) {
            setState(() {
              _createHeadOfficeAccount = value;
            });
          },
        ),
        if (_createHeadOfficeAccount) ...[
          TextFormField(
            controller: _headOfficeNameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _headOfficeUsernameController,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _headOfficeEmailController,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _headOfficePasswordController,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _isSubmitting ? null : _submitOnboarding,
          icon: const Icon(Icons.apartment_outlined),
          label: Text(_isSubmitting ? 'Creating...' : 'Create Organization'),
        ),
      ],
    );
  }

  Widget _buildSecondaryPane(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Organizations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_organizations.isEmpty)
              const Text('No organizations created yet.')
            else
              for (final organization in _organizations.take(8))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.apartment_outlined),
                  title: Text(
                    organization['name'] as String? ?? 'Organization',
                  ),
                  subtitle: Text(
                    [
                      organization['code']?.toString() ?? '',
                      organization['brand_name']?.toString() ?? 'Custom',
                      'Stations target: ${organization['station_target_count'] ?? '-'}',
                    ].join(' • '),
                  ),
                ),
            const Divider(height: 28),
            Text(
              'What this flow sets up',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('1. Organization identity and branding'),
            const Text('2. Initial station list and setup flags'),
            const Text('3. First HeadOffice login for the tenant'),
            const SizedBox(height: 20),
            Text(
              'Current platform user',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.sessionController.currentUser?['full_name'] as String? ??
                  'Master Admin',
            ),
            Text(widget.sessionController.roleName),
          ],
        ),
      ),
    );
  }
}

class _StationDraftCard extends StatefulWidget {
  const _StationDraftCard({required this.index, required this.draft});

  final int index;
  final _StationDraft draft;

  @override
  State<_StationDraftCard> createState() => _StationDraftCardState();
}

class _StationDraftCardState extends State<_StationDraftCard> {
  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station ${widget.index + 1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.nameController,
              decoration: const InputDecoration(labelText: 'Station Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.codeController,
              decoration: const InputDecoration(labelText: 'Station Code'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.displayNameController,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.cityController,
              decoration: const InputDecoration(labelText: 'City'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.logoUrlController,
              decoration: const InputDecoration(labelText: 'Station Logo URL'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilterChip(
                  selected: draft.isHeadOffice,
                  label: const Text('Head Office'),
                  onSelected: (value) {
                    setState(() {
                      draft.isHeadOffice = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.useOrganizationBranding,
                  label: const Text('Use Org Branding'),
                  onSelected: (value) {
                    setState(() {
                      draft.useOrganizationBranding = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.hasShops,
                  label: const Text('Shops'),
                  onSelected: (value) {
                    setState(() {
                      draft.hasShops = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.hasPos,
                  label: const Text('POS'),
                  onSelected: (value) {
                    setState(() {
                      draft.hasPos = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.hasTankers,
                  label: const Text('Tankers'),
                  onSelected: (value) {
                    setState(() {
                      draft.hasTankers = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.hasHardware,
                  label: const Text('Hardware'),
                  onSelected: (value) {
                    setState(() {
                      draft.hasHardware = value;
                    });
                  },
                ),
                FilterChip(
                  selected: draft.allowMeterAdjustments,
                  label: const Text('Meter Adjustments'),
                  onSelected: (value) {
                    setState(() {
                      draft.allowMeterAdjustments = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StationDraft {
  _StationDraft()
    : nameController = TextEditingController(),
      codeController = TextEditingController(),
      displayNameController = TextEditingController(),
      addressController = TextEditingController(),
      cityController = TextEditingController(),
      logoUrlController = TextEditingController();

  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController displayNameController;
  final TextEditingController addressController;
  final TextEditingController cityController;
  final TextEditingController logoUrlController;

  bool isHeadOffice = false;
  bool useOrganizationBranding = true;
  bool hasShops = false;
  bool hasPos = false;
  bool hasTankers = false;
  bool hasHardware = false;
  bool allowMeterAdjustments = true;

  void reset() {
    nameController.clear();
    codeController.clear();
    displayNameController.clear();
    addressController.clear();
    cityController.clear();
    logoUrlController.clear();
    isHeadOffice = false;
    useOrganizationBranding = true;
    hasShops = false;
    hasPos = false;
    hasTankers = false;
    hasHardware = false;
    allowMeterAdjustments = true;
  }

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    displayNameController.dispose();
    addressController.dispose();
    cityController.dispose();
    logoUrlController.dispose();
  }
}
