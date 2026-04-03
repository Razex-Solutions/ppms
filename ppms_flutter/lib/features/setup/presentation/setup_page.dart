import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

enum _SetupSection { fuelTypes, invoiceProfile }

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _fuelTypeNameController = TextEditingController();
  final _fuelTypeDescriptionController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _legalNameController = TextEditingController();
  final _registrationNoController = TextEditingController();
  final _taxRegistrationNoController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0');
  final _regionCodeController = TextEditingController();
  final _currencyCodeController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _invoiceSeriesController = TextEditingController();
  final _invoiceWidthController = TextEditingController(text: '6');
  final _paymentTermsController = TextEditingController();
  final _footerTextController = TextEditingController();
  final _saleNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _SetupSection _section = _SetupSection.fuelTypes;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _compliancePresets = const [];
  Map<String, dynamic>? _invoiceProfile;

  int? _selectedStationId;
  int? _selectedFuelTypeId;
  String _selectedComplianceMode = 'standard';
  String? _selectedPresetCode;
  bool _taxInclusive = false;
  bool _enforceTaxRegistration = false;

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _fuelTypeNameController.dispose();
    _fuelTypeDescriptionController.dispose();
    _businessNameController.dispose();
    _legalNameController.dispose();
    _registrationNoController.dispose();
    _taxRegistrationNoController.dispose();
    _taxRateController.dispose();
    _regionCodeController.dispose();
    _currencyCodeController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _invoicePrefixController.dispose();
    _invoiceSeriesController.dispose();
    _invoiceWidthController.dispose();
    _paymentTermsController.dispose();
    _footerTextController.dispose();
    _saleNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stations = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchStations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final fuelTypes = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelTypes()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final presets = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchCompliancePresets()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      final preferredStationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final stationId =
          _selectedStationId ??
          preferredStationId ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      Map<String, dynamic>? invoiceProfile;
      if (stationId != null) {
        invoiceProfile = await widget.sessionController.fetchInvoiceProfile(
          stationId: stationId,
        );
      }

      if (!mounted) return;

      _hydrateInvoiceProfile(invoiceProfile);

      setState(() {
        _stations = stations;
        _fuelTypes = fuelTypes;
        _compliancePresets = presets;
        _invoiceProfile = invoiceProfile;
        _selectedStationId = stationId;
        _selectedPresetCode = presets.isNotEmpty
            ? (presets.first['code'] as String?)
            : null;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  void _hydrateInvoiceProfile(Map<String, dynamic>? profile) {
    _businessNameController.text = profile?['business_name'] as String? ?? '';
    _legalNameController.text = profile?['legal_name'] as String? ?? '';
    _registrationNoController.text =
        profile?['registration_no'] as String? ?? '';
    _taxRegistrationNoController.text =
        profile?['tax_registration_no'] as String? ?? '';
    _taxRateController.text = ((profile?['default_tax_rate'] as num?) ?? 0)
        .toString();
    _regionCodeController.text = profile?['region_code'] as String? ?? '';
    _currencyCodeController.text = profile?['currency_code'] as String? ?? '';
    _contactEmailController.text = profile?['contact_email'] as String? ?? '';
    _contactPhoneController.text = profile?['contact_phone'] as String? ?? '';
    _invoicePrefixController.text = profile?['invoice_prefix'] as String? ?? '';
    _invoiceSeriesController.text = profile?['invoice_series'] as String? ?? '';
    _invoiceWidthController.text =
        ((profile?['invoice_number_width'] as num?) ?? 6).toString();
    _paymentTermsController.text = profile?['payment_terms'] as String? ?? '';
    _footerTextController.text = profile?['footer_text'] as String? ?? '';
    _saleNotesController.text = profile?['sale_invoice_notes'] as String? ?? '';
    _selectedComplianceMode =
        profile?['compliance_mode'] as String? ?? 'standard';
    _taxInclusive = profile?['tax_inclusive'] as bool? ?? false;
    _enforceTaxRegistration =
        profile?['enforce_tax_registration'] as bool? ?? false;
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
    });
    await _loadWorkspace();
  }

  Future<void> _createFuelType() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final isEditing = _selectedFuelTypeId != null;
      final fuelType = isEditing
          ? await widget.sessionController.updateFuelType(
              fuelTypeId: _selectedFuelTypeId!,
              payload: {
                'name': _fuelTypeNameController.text.trim(),
                'description': _emptyToNull(
                  _fuelTypeDescriptionController.text,
                ),
              },
            )
          : await widget.sessionController.createFuelType({
              'name': _fuelTypeNameController.text.trim(),
              'description': _emptyToNull(_fuelTypeDescriptionController.text),
            });
      if (!mounted) return;
      _resetFuelTypeForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Fuel type ${fuelType['name']} ${isEditing ? 'updated' : 'created'}.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteFuelType() async {
    final fuelTypeId = _selectedFuelTypeId;
    if (fuelTypeId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Fuel Type',
      message:
          'Delete this fuel type only if it is no longer used by tanks, nozzles, or purchases.',
    );
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final response = await widget.sessionController.deleteFuelType(
        fuelTypeId: fuelTypeId,
      );
      if (!mounted) return;
      _resetFuelTypeForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Fuel type deleted successfully.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  void _selectFuelType(Map<String, dynamic> fuelType) {
    setState(() {
      _selectedFuelTypeId = fuelType['id'] as int;
      _fuelTypeNameController.text = fuelType['name'] as String? ?? '';
      _fuelTypeDescriptionController.text =
          fuelType['description'] as String? ?? '';
      _feedbackMessage = 'Editing fuel type ${fuelType['name']}.';
      _errorMessage = null;
    });
  }

  void _resetFuelTypeForm() {
    _selectedFuelTypeId = null;
    _fuelTypeNameController.clear();
    _fuelTypeDescriptionController.clear();
  }

  Future<void> _saveInvoiceProfile() async {
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final profile = await widget.sessionController.updateInvoiceProfile(
        stationId: stationId,
        payload: {
          'business_name': _businessNameController.text.trim(),
          'legal_name': _emptyToNull(_legalNameController.text),
          'registration_no': _emptyToNull(_registrationNoController.text),
          'tax_registration_no': _emptyToNull(
            _taxRegistrationNoController.text,
          ),
          'default_tax_rate': double.parse(_taxRateController.text.trim()),
          'tax_inclusive': _taxInclusive,
          'region_code': _emptyToNull(_regionCodeController.text),
          'currency_code': _emptyToNull(_currencyCodeController.text),
          'compliance_mode': _selectedComplianceMode,
          'enforce_tax_registration': _enforceTaxRegistration,
          'contact_email': _emptyToNull(_contactEmailController.text),
          'contact_phone': _emptyToNull(_contactPhoneController.text),
          'footer_text': _emptyToNull(_footerTextController.text),
          'invoice_prefix': _emptyToNull(_invoicePrefixController.text),
          'invoice_series': _emptyToNull(_invoiceSeriesController.text),
          'invoice_number_width': int.parse(
            _invoiceWidthController.text.trim(),
          ),
          'payment_terms': _emptyToNull(_paymentTermsController.text),
          'sale_invoice_notes': _emptyToNull(_saleNotesController.text),
        },
      );
      if (!mounted) return;
      _hydrateInvoiceProfile(profile);
      setState(() {
        _invoiceProfile = profile;
        _feedbackMessage = 'Invoice profile updated.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _applyPreset() async {
    final stationId = _selectedStationId;
    final presetCode = _selectedPresetCode;
    if (stationId == null || presetCode == null || presetCode.isEmpty) {
      setState(() {
        _feedbackMessage = 'Select a station and compliance preset first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final profile = await widget.sessionController.applyCompliancePreset(
        stationId: stationId,
        presetCode: presetCode,
      );
      if (!mounted) return;
      _hydrateInvoiceProfile(profile);
      setState(() {
        _invoiceProfile = profile;
        _feedbackMessage = 'Compliance preset $presetCode applied.';
        _isSubmitting = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
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
                    'Setup Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configure core business setup like fuel types and invoice profile details for the station.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'setup-station-${_selectedStationId ?? 'none'}',
                          ),
                          initialValue: _selectedStationId,
                          decoration: const InputDecoration(
                            labelText: 'Station',
                          ),
                          items: [
                            for (final station in _stations)
                              DropdownMenuItem<int>(
                                value: station['id'] as int,
                                child: Text(
                                  '${station['name']} (${station['code']})',
                                ),
                              ),
                          ],
                          onChanged: _changeStation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<_SetupSection>(
                          segments: const [
                            ButtonSegment(
                              value: _SetupSection.fuelTypes,
                              label: Text('Fuel Types'),
                              icon: Icon(Icons.opacity_outlined),
                            ),
                            ButtonSegment(
                              value: _SetupSection.invoiceProfile,
                              label: Text('Invoice Profile'),
                              icon: Icon(Icons.receipt_outlined),
                            ),
                          ],
                          selected: {_section},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _section = selection.first;
                              _errorMessage = null;
                              _feedbackMessage = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_section == _SetupSection.fuelTypes)
                    _buildFuelTypesSection(context)
                  else
                    _buildInvoiceProfileSection(context),
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

  Widget _buildFuelTypesSection(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedFuelTypeId == null ? 'Create Fuel Type' : 'Edit Fuel Type',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fuelTypeNameController,
            decoration: const InputDecoration(labelText: 'Fuel Type Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fuelTypeDescriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: _isSubmitting ? null : _createFuelType,
                icon: Icon(
                  _selectedFuelTypeId == null
                      ? Icons.add_circle_outline
                      : Icons.save_outlined,
                ),
                label: Text(
                  _selectedFuelTypeId == null
                      ? 'Create Fuel Type'
                      : 'Save Fuel Type',
                ),
              ),
              if (_selectedFuelTypeId != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _resetFuelTypeForm();
                                _feedbackMessage = 'Fuel type edit cancelled.';
                              });
                            },
                      child: const Text('Cancel Edit'),
                    ),
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : _deleteFuelType,
                      child: const Text('Delete Fuel Type'),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Fuel Types', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_fuelTypes.isEmpty)
                const Text('No fuel types found.')
              else
                for (final fuelType in _fuelTypes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(fuelType['name'] as String? ?? 'Fuel'),
                    subtitle: Text(fuelType['description'] as String? ?? '-'),
                    onTap: () => _selectFuelType(fuelType),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceProfileSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice Profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _businessNameController,
                    decoration: const InputDecoration(
                      labelText: 'Business Name',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _legalNameController,
                    decoration: const InputDecoration(labelText: 'Legal Name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _registrationNoController,
                    decoration: const InputDecoration(
                      labelText: 'Registration No',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _taxRegistrationNoController,
                    decoration: const InputDecoration(
                      labelText: 'Tax Registration No',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _taxRateController,
                    decoration: const InputDecoration(
                      labelText: 'Default Tax Rate',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'setup-compliance-$_selectedComplianceMode',
                    ),
                    initialValue: _selectedComplianceMode,
                    decoration: const InputDecoration(
                      labelText: 'Compliance Mode',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'regulated',
                        child: Text('Regulated'),
                      ),
                      DropdownMenuItem(value: 'strict', child: Text('Strict')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedComplianceMode = value ?? 'standard';
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _regionCodeController,
                    decoration: const InputDecoration(labelText: 'Region Code'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _currencyCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Currency Code',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Email',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _contactPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoicePrefixController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Prefix',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoiceSeriesController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Series',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _invoiceWidthController,
                    decoration: const InputDecoration(
                      labelText: 'Invoice Number Width',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paymentTermsController,
                    decoration: const InputDecoration(
                      labelText: 'Payment Terms',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _footerTextController,
                    decoration: const InputDecoration(labelText: 'Footer Text'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _saleNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Sale Invoice Notes',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _taxInclusive,
                    title: const Text('Tax Inclusive'),
                    onChanged: (value) {
                      setState(() {
                        _taxInclusive = value;
                      });
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enforceTaxRegistration,
                    title: const Text('Enforce Tax Registration'),
                    onChanged: (value) {
                      setState(() {
                        _enforceTaxRegistration = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _saveInvoiceProfile,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Profile'),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'setup-preset-${_selectedPresetCode ?? 'none'}',
                          ),
                          initialValue: _selectedPresetCode,
                          decoration: const InputDecoration(
                            labelText: 'Compliance Preset',
                          ),
                          items: [
                            for (final preset in _compliancePresets)
                              DropdownMenuItem<String>(
                                value: preset['code'] as String?,
                                child: Text(
                                  preset['code'] as String? ?? 'Preset',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedPresetCode = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _applyPreset,
                        icon: const Icon(Icons.rule_folder_outlined),
                        label: const Text('Apply Preset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Profile',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (_invoiceProfile == null)
                        const Text('No invoice profile loaded yet.')
                      else ...[
                        Text(
                          'Business: ${_invoiceProfile?['business_name'] ?? '-'}',
                        ),
                        Text('Legal: ${_invoiceProfile?['legal_name'] ?? '-'}'),
                        Text(
                          'Tax Rate: ${_invoiceProfile?['default_tax_rate'] ?? 0}',
                        ),
                        Text(
                          'Compliance: ${_invoiceProfile?['compliance_mode'] ?? '-'}',
                        ),
                        Text(
                          'Currency: ${_invoiceProfile?['currency_code'] ?? '-'}',
                        ),
                        Text(
                          'Invoice Prefix: ${_invoiceProfile?['invoice_prefix'] ?? '-'}',
                        ),
                        Text(
                          'Invoice Series: ${_invoiceProfile?['invoice_series'] ?? '-'}',
                        ),
                        Text(
                          'Footer: ${_invoiceProfile?['footer_text'] ?? '-'}',
                        ),
                      ],
                      const SizedBox(height: 20),
                      Text(
                        'Available Presets',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (_compliancePresets.isEmpty)
                        const Text('No presets available.')
                      else
                        for (final preset in _compliancePresets)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(preset['code'] as String? ?? 'Preset'),
                            subtitle: Text(
                              preset['label'] as String? ??
                                  preset['description'] as String? ??
                                  '-',
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
