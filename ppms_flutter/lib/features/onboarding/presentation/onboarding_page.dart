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
  bool _singleStationUsesOrganizationDetails = true;
  bool _legalNameMatchesOrganization = true;
  String? _errorMessage;
  String? _feedbackMessage;
  int? _selectedBrandId;
  int? _editingOrganizationId;
  List<Map<String, dynamic>> _brands = const [];
  int _stationCount = 1;
  List<Map<String, dynamic>> _organizations = const [];
  List<Map<String, dynamic>> _roles = const [];
  Map<String, dynamic>? _latestSetupFoundation;
  late List<_StationDraft> _stationDrafts;

  @override
  void initState() {
    super.initState();
    _stationDrafts = [_StationDraft()];
    _organizationNameController.addListener(_syncGeneratedOrganizationFields);
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
    _organizationNameController.removeListener(
      _syncGeneratedOrganizationFields,
    );
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
      final brands = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchBrands()).map(
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
        _brands = brands;
        _selectedBrandId ??=
            brands.cast<Map<String, dynamic>?>().firstWhere(
                  (brand) => brand?['code'] == 'CUSTOM',
                  orElse: () => brands.isNotEmpty ? brands.first : null,
                )?['id']
                as int?;
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
        _stationDrafts.first.useOrganizationBranding = _inheritBranding;
      }
    });
  }

  bool get _isSingleStationFlow => _stationCount == 1;

  bool get _isEditingOrganization => _editingOrganizationId != null;

  String _resolvedStationName(_StationDraft draft) {
    if (_isSingleStationFlow && _singleStationUsesOrganizationDetails) {
      return _organizationNameController.text.trim();
    }
    return draft.nameController.text.trim();
  }

  String _resolvedStationCode(_StationDraft draft) {
    if (_isSingleStationFlow && _singleStationUsesOrganizationDetails) {
      return _organizationCodeController.text.trim();
    }
    return draft.codeController.text.trim();
  }

  String? _resolvedStationDisplayName(_StationDraft draft) {
    if (_isSingleStationFlow && _singleStationUsesOrganizationDetails) {
      return _emptyToNull(_organizationNameController.text);
    }
    return _emptyToNull(draft.displayNameController.text);
  }

  void _syncGeneratedOrganizationFields() {
    if (_legalNameMatchesOrganization &&
        _legalNameController.text != _organizationNameController.text) {
      _legalNameController.text = _organizationNameController.text;
    }
    if (!_isEditingOrganization) {
      final generatedCode = _generateOrganizationCode();
      if (_organizationCodeController.text != generatedCode) {
        _organizationCodeController.text = generatedCode;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  String _generateOrganizationCode() {
    final organizationPart = _codePart(_organizationNameController.text, 'ORG');
    final brandPart = _codePart(
      _selectedBrandData?['code'] as String? ?? _selectedBrandName,
      'BR',
    );
    var sequence = (_organizations.length + 1).clamp(1, 999).toString();
    sequence = sequence.padLeft(3, '0');
    var code = '$organizationPart-$brandPart-$sequence';
    var attempt = _organizations.length + 1;
    final existingCodes = _organizations
        .map((organization) => organization['code']?.toString().toUpperCase())
        .whereType<String>()
        .toSet();
    while (existingCodes.contains(code)) {
      attempt += 1;
      code =
          '$organizationPart-$brandPart-${attempt.clamp(1, 999).toString().padLeft(3, '0')}';
    }
    return code;
  }

  String _codePart(String value, String fallback) {
    final normalized = value.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]+'),
      '',
    );
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized.length <= 8 ? normalized : normalized.substring(0, 8);
  }

  Map<String, dynamic> _organizationPayload({
    required bool includeCode,
    required bool includeCreateDefaults,
  }) {
    final selectedBrand = _selectedBrandData;
    final legalName = _legalNameMatchesOrganization
        ? _organizationNameController.text.trim()
        : _legalNameController.text.trim();
    final payload = <String, dynamic>{
      'name': _organizationNameController.text.trim(),
      if (includeCode) 'code': _organizationCodeController.text.trim(),
      'description': _emptyToNull(_organizationDescriptionController.text),
      'legal_name': _emptyToNull(legalName),
      'brand_catalog_id': _selectedBrandId,
      'brand_name': _selectedBrandIsCustom
          ? _organizationNameController.text.trim()
          : selectedBrand?['name'],
      'brand_code': _selectedBrandIsCustom
          ? _organizationCodeController.text.trim().toUpperCase()
          : selectedBrand?['code'],
      'logo_url': _selectedBrandIsCustom
          ? _emptyToNull(_logoUrlController.text)
          : selectedBrand?['logo_url'] as String?,
      'contact_email': _emptyToNull(_contactEmailController.text),
      'contact_phone': _emptyToNull(_contactPhoneController.text),
      'registration_number': _emptyToNull(_registrationController.text),
      'tax_registration_number': _emptyToNull(_taxRegistrationController.text),
      'station_target_count': _stationCount,
      'inherit_branding_to_stations': _inheritBranding,
      'is_active': true,
    };
    if (includeCreateDefaults) {
      payload.addAll({
        'onboarding_status': 'active',
        'billing_status': 'trial',
      });
    }
    return payload;
  }

  Future<void> _submitOnboarding() async {
    if (_organizationNameController.text.trim().isEmpty ||
        _organizationCodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Organization name and code are required.';
      });
      return;
    }
    if (_isEditingOrganization) {
      await _updateOrganizationDetails();
      return;
    }
    for (final draft in _stationDrafts) {
      if (_resolvedStationName(draft).isEmpty ||
          _resolvedStationCode(draft).isEmpty) {
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
      final organization = await widget.sessionController.createOrganization(
        _organizationPayload(includeCode: true, includeCreateDefaults: true),
      );

      final organizationId = organization['id'] as int;
      int? firstStationId;
      for (var i = 0; i < _stationDrafts.length; i++) {
        final draft = _stationDrafts[i];
        final station = await widget.sessionController.createStation({
          'name': _resolvedStationName(draft),
          'code': _resolvedStationCode(draft),
          'address': _emptyToNull(draft.addressController.text),
          'city': _emptyToNull(draft.cityController.text),
          'organization_id': organizationId,
          'is_head_office': draft.isHeadOffice,
          'display_name': _resolvedStationDisplayName(draft),
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
      final setupFoundation = await widget.sessionController
          .fetchOrganizationSetupFoundation(organizationId: organizationId);
      if (!mounted) {
        return;
      }
      _resetForm();
      await _loadWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _latestSetupFoundation = setupFoundation;
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

  Future<void> _updateOrganizationDetails() async {
    final organizationId = _editingOrganizationId;
    if (organizationId == null) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final organization = await widget.sessionController.updateOrganization(
        organizationId: organizationId,
        payload: _organizationPayload(
          includeCode: false,
          includeCreateDefaults: false,
        ),
      );
      if (!mounted) {
        return;
      }
      await _loadWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Organization ${organization['name']} updated. Code ${organization['code']} stayed unchanged.';
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
    _editingOrganizationId = null;
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
    _selectedBrandId =
        _brands.cast<Map<String, dynamic>?>().firstWhere(
              (brand) => brand?['code'] == 'CUSTOM',
              orElse: () => _brands.isNotEmpty ? _brands.first : null,
            )?['id']
            as int?;
    _inheritBranding = true;
    _createHeadOfficeAccount = true;
    _singleStationUsesOrganizationDetails = true;
    _legalNameMatchesOrganization = true;
    _latestSetupFoundation = null;
    _syncStationDraftCount(1);
    for (final draft in _stationDrafts) {
      draft.reset();
    }
    _syncGeneratedOrganizationFields();
  }

  void _editOrganization(Map<String, dynamic> organization) {
    setState(() {
      _editingOrganizationId = organization['id'] as int?;
      _organizationNameController.text = organization['name'] as String? ?? '';
      _organizationCodeController.text = organization['code'] as String? ?? '';
      _organizationDescriptionController.text =
          organization['description'] as String? ?? '';
      final legalName = organization['legal_name'] as String? ?? '';
      _legalNameMatchesOrganization =
          legalName.isEmpty || legalName == _organizationNameController.text;
      _legalNameController.text = _legalNameMatchesOrganization
          ? _organizationNameController.text
          : legalName;
      _logoUrlController.text = organization['logo_url'] as String? ?? '';
      _contactEmailController.text =
          organization['contact_email'] as String? ?? '';
      _contactPhoneController.text =
          organization['contact_phone'] as String? ?? '';
      _registrationController.text =
          organization['registration_number'] as String? ?? '';
      _taxRegistrationController.text =
          organization['tax_registration_number'] as String? ?? '';
      _selectedBrandId =
          organization['brand_catalog_id'] as int? ??
          _brands.cast<Map<String, dynamic>?>().firstWhere(
                (brand) =>
                    brand?['code']?.toString() ==
                    organization['brand_code']?.toString(),
                orElse: () => _brands.isNotEmpty ? _brands.first : null,
              )?['id']
              as int?;
      _inheritBranding =
          organization['inherit_branding_to_stations'] as bool? ?? true;
      _stationCount = organization['station_target_count'] as int? ?? 1;
      _createHeadOfficeAccount = false;
      _singleStationUsesOrganizationDetails = true;
      _latestSetupFoundation = null;
      _errorMessage = null;
      _feedbackMessage =
          'Editing ${_organizationNameController.text}. Station and HeadOffice creation are paused in edit mode.';
    });
    _syncStationDraftCount(_stationCount);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Map<String, dynamic>? get _selectedBrandData =>
      _brands.cast<Map<String, dynamic>?>().firstWhere(
        (brand) => brand?['id'] == _selectedBrandId,
        orElse: () => null,
      );

  bool get _selectedBrandIsCustom =>
      (_selectedBrandData?['code'] as String? ?? '') == 'CUSTOM';

  String get _selectedBrandName =>
      _selectedBrandData?['name'] as String? ?? 'Custom';

  int get _resolvedHeadOfficeCount =>
      _stationDrafts.where((draft) => draft.isHeadOffice).length;

  List<_ResolvedStationPreview> get _stationPreviews =>
      List.generate(_stationDrafts.length, (index) {
        final draft = _stationDrafts[index];
        return _ResolvedStationPreview(
          title: _resolvedStationName(draft).isEmpty
              ? 'Station ${index + 1}'
              : _resolvedStationName(draft),
          code: _resolvedStationCode(draft),
          city: _emptyToNull(draft.cityController.text),
          usesOrganizationBranding: draft.useOrganizationBranding,
          isHeadOffice: draft.isHeadOffice,
        );
      });

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
        Text(
          _isEditingOrganization ? 'Edit Organization Details' : 'Organization',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationNameController,
          decoration: const InputDecoration(labelText: 'Organization Name'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationCodeController,
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Organization Code',
            helperText: _isEditingOrganization
                ? 'Code is kept stable while editing organization details.'
                : 'Auto-generated from organization name, brand, and the next local sequence.',
            suffixIcon: _isEditingOrganization
                ? null
                : IconButton(
                    tooltip: 'Regenerate organization code',
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      setState(() {
                        _organizationCodeController.text =
                            _generateOrganizationCode();
                      });
                    },
                  ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey<String>(
            'onboarding-brand-${_selectedBrandId ?? 'none'}',
          ),
          initialValue: _selectedBrandId?.toString(),
          decoration: const InputDecoration(labelText: 'Brand'),
          items: [
            for (final brand in _brands)
              DropdownMenuItem<String>(
                value: (brand['id'] as int).toString(),
                child: Text(brand['name'] as String? ?? 'Brand'),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBrandId = int.tryParse(value ?? '');
              if (!_isEditingOrganization) {
                _organizationCodeController.text = _generateOrganizationCode();
              }
            });
          },
        ),
        const SizedBox(height: 12),
        _BrandPreviewCard(
          title: 'Organization Branding',
          brandName: _selectedBrandIsCustom
              ? (_organizationNameController.text.trim().isEmpty
                    ? 'Custom Brand'
                    : _organizationNameController.text.trim())
              : _selectedBrandName,
          logoUrl: _selectedBrandData?['logo_url'] as String?,
          primaryColor: _selectedBrandData?['primary_color'] as String?,
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _legalNameMatchesOrganization,
          title: const Text('Legal name is same as organization name'),
          onChanged: (value) {
            setState(() {
              _legalNameMatchesOrganization = value;
              if (value) {
                _legalNameController.text = _organizationNameController.text;
              }
            });
          },
        ),
        TextFormField(
          controller: _legalNameController,
          enabled: !_legalNameMatchesOrganization,
          decoration: InputDecoration(
            labelText: 'Legal Name',
            helperText: _legalNameMatchesOrganization
                ? 'This will be saved as the organization name.'
                : null,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _organizationDescriptionController,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        if (_selectedBrandIsCustom) ...[
          TextFormField(
            controller: _logoUrlController,
            decoration: const InputDecoration(
              labelText: 'Custom Logo URL',
              helperText:
                  'Only needed for custom brands. Known pump brands auto-apply their branding.',
            ),
          ),
          const SizedBox(height: 12),
        ],
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
        if (!_isEditingOrganization) ...[
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
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _inheritBranding,
          title: const Text('Inherit organization branding to stations'),
          onChanged: (value) {
            setState(() {
              _inheritBranding = value;
              if (_stationDrafts.isNotEmpty) {
                _stationDrafts.first.useOrganizationBranding = value;
              }
            });
          },
        ),
        if (!_isEditingOrganization && _isSingleStationFlow)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _singleStationUsesOrganizationDetails,
            title: const Text('Use organization details for this station'),
            subtitle: const Text(
              'For single-station businesses, keep the first station aligned with the organization by default.',
            ),
            onChanged: (value) {
              setState(() {
                _singleStationUsesOrganizationDetails = value;
              });
            },
          ),
        if (!_isEditingOrganization) ...[
          const SizedBox(height: 24),
          Text('Stations', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (var index = 0; index < _stationDrafts.length; index++)
            _StationDraftCard(
              index: index,
              draft: _stationDrafts[index],
              inheritFromOrganization:
                  _isSingleStationFlow &&
                  index == 0 &&
                  _singleStationUsesOrganizationDetails,
              inheritedStationName: _organizationNameController.text.trim(),
              inheritedStationCode: _organizationCodeController.text.trim(),
            ),
          const SizedBox(height: 24),
          _OnboardingReviewCard(
            organizationName: _organizationNameController.text.trim(),
            organizationCode: _organizationCodeController.text.trim(),
            brandName: _selectedBrandIsCustom
                ? (_organizationNameController.text.trim().isEmpty
                      ? 'Custom'
                      : _organizationNameController.text.trim())
                : _selectedBrandName,
            stationCount: _stationCount,
            headOfficeCount: _resolvedHeadOfficeCount,
            createHeadOfficeAccount: _createHeadOfficeAccount,
            singleStationInherited:
                _isSingleStationFlow && _singleStationUsesOrganizationDetails,
            stations: _stationPreviews,
          ),
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
        ],
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitOnboarding,
              icon: Icon(
                _isEditingOrganization
                    ? Icons.save_outlined
                    : Icons.apartment_outlined,
              ),
              label: Text(
                _isSubmitting
                    ? (_isEditingOrganization ? 'Updating...' : 'Creating...')
                    : (_isEditingOrganization
                          ? 'Update Organization'
                          : 'Create Organization'),
              ),
            ),
            if (_isEditingOrganization)
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _resetForm,
                icon: const Icon(Icons.close),
                label: const Text('Cancel Edit'),
              ),
          ],
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
                  trailing: TextButton.icon(
                    onPressed: () => _editOrganization(organization),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
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
            const SizedBox(height: 16),
            Text(
              'Current setup outcome',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Stations to create: $_stationCount'),
            Text(
              _isSingleStationFlow && _singleStationUsesOrganizationDetails
                  ? 'Single station will inherit organization name and code.'
                  : 'Stations will use their own entered details.',
            ),
            if (_latestSetupFoundation != null) ...[
              const Divider(height: 28),
              Text(
                'Latest Setup Foundation',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _latestSetupFoundation?['organization_name'] as String? ??
                    'Organization',
              ),
              Text(
                'Stations: ${(_latestSetupFoundation?['stations'] as List?)?.length ?? 0}',
              ),
              Text(
                'Brand: ${(_latestSetupFoundation?['resolved_branding'] as Map?)?['brand_name'] ?? 'Custom'}',
              ),
            ],
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
  const _StationDraftCard({
    required this.index,
    required this.draft,
    required this.inheritFromOrganization,
    required this.inheritedStationName,
    required this.inheritedStationCode,
  });

  final int index;
  final _StationDraft draft;
  final bool inheritFromOrganization;
  final String inheritedStationName;
  final String inheritedStationCode;

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
            if (widget.inheritFromOrganization) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Using organization details',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.inheritedStationName.isEmpty
                          ? 'Station name will follow the organization name.'
                          : 'Station name: ${widget.inheritedStationName}',
                    ),
                    Text(
                      widget.inheritedStationCode.isEmpty
                          ? 'Station code will follow the organization code.'
                          : 'Station code: ${widget.inheritedStationCode}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: draft.nameController,
              enabled: !widget.inheritFromOrganization,
              decoration: InputDecoration(
                labelText: 'Station Name',
                helperText: widget.inheritFromOrganization
                    ? 'Auto-filled from the organization for this single-station setup.'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.codeController,
              enabled: !widget.inheritFromOrganization,
              decoration: InputDecoration(
                labelText: 'Station Code',
                helperText: widget.inheritFromOrganization
                    ? 'Auto-filled from the organization for this single-station setup.'
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: draft.displayNameController,
              enabled: !widget.inheritFromOrganization,
              decoration: InputDecoration(
                labelText: 'Display Name',
                helperText: widget.inheritFromOrganization
                    ? 'The app display name will also follow the organization unless you turn inheritance off.'
                    : null,
              ),
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
            if (!draft.useOrganizationBranding) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.logoUrlController,
                decoration: const InputDecoration(
                  labelText: 'Station Logo URL',
                  helperText:
                      'Only needed when this station should override the organization branding.',
                ),
              ),
            ],
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

class _BrandPreviewCard extends StatelessWidget {
  const _BrandPreviewCard({
    required this.title,
    required this.brandName,
    required this.logoUrl,
    required this.primaryColor,
  });

  final String title;
  final String brandName;
  final String? logoUrl;
  final String? primaryColor;

  @override
  Widget build(BuildContext context) {
    final fallbackColor =
        _colorFromHex(primaryColor) ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: _BrandAvatar(
          brandName: brandName,
          logoUrl: logoUrl,
          color: fallbackColor,
        ),
        title: Text(title),
        subtitle: Text(brandName),
      ),
    );
  }
}

class _BrandAvatar extends StatelessWidget {
  const _BrandAvatar({
    required this.brandName,
    required this.logoUrl,
    required this.color,
  });

  final String brandName;
  final String? logoUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trimmed = logoUrl?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          trimmed,
          width: 52,
          height: 52,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackAvatar(),
        ),
      );
    }
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final initials = brandName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: 26,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials.isEmpty ? 'BR' : initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ResolvedStationPreview {
  const _ResolvedStationPreview({
    required this.title,
    required this.code,
    required this.city,
    required this.usesOrganizationBranding,
    required this.isHeadOffice,
  });

  final String title;
  final String code;
  final String? city;
  final bool usesOrganizationBranding;
  final bool isHeadOffice;
}

class _OnboardingReviewCard extends StatelessWidget {
  const _OnboardingReviewCard({
    required this.organizationName,
    required this.organizationCode,
    required this.brandName,
    required this.stationCount,
    required this.headOfficeCount,
    required this.createHeadOfficeAccount,
    required this.singleStationInherited,
    required this.stations,
  });

  final String organizationName;
  final String organizationCode;
  final String brandName;
  final int stationCount;
  final int headOfficeCount;
  final bool createHeadOfficeAccount;
  final bool singleStationInherited;
  final List<_ResolvedStationPreview> stations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Review Before Create',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            _reviewLine(
              'Organization',
              organizationName.isEmpty ? 'Not entered yet' : organizationName,
            ),
            _reviewLine(
              'Code',
              organizationCode.isEmpty ? 'Not entered yet' : organizationCode,
            ),
            _reviewLine('Brand', brandName),
            _reviewLine('Stations', '$stationCount'),
            _reviewLine('Head office stations', '$headOfficeCount'),
            _reviewLine(
              'First login',
              createHeadOfficeAccount ? 'Will be created' : 'Skipped',
            ),
            if (singleStationInherited)
              _reviewLine(
                'Single-station mode',
                'Station will inherit organization name/code',
              ),
            const SizedBox(height: 12),
            Text(
              'Resolved station preview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final station in stations)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  station.isHeadOffice
                      ? Icons.apartment_outlined
                      : Icons.store_outlined,
                ),
                title: Text(station.title),
                subtitle: Text(
                  [
                    if (station.code.isNotEmpty) station.code,
                    if (station.city != null && station.city!.isNotEmpty)
                      station.city!,
                    station.usesOrganizationBranding
                        ? 'Org branding'
                        : 'Custom branding',
                  ].join(' • '),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

Color? _colorFromHex(String? value) {
  final normalized = value?.trim() ?? '';
  if (normalized.isEmpty) {
    return null;
  }
  final hex = normalized.replaceFirst('#', '');
  final full = hex.length == 6 ? 'FF$hex' : hex;
  final parsed = int.tryParse(full, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(parsed);
}
