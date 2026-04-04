import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

enum _StationSetupSection {
  stationProfile,
  fuelTypes,
  inventory,
  invoiceProfile,
}

class StationSetupPage extends StatefulWidget {
  const StationSetupPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<StationSetupPage> createState() => _StationSetupPageState();
}

class _StationSetupPageState extends State<StationSetupPage> {
  final _displayNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _fuelTypeNameController = TextEditingController();
  final _fuelTypeDescriptionController = TextEditingController();
  final _tankNameController = TextEditingController();
  final _tankCodeController = TextEditingController();
  final _tankCapacityController = TextEditingController();
  final _tankCurrentVolumeController = TextEditingController(text: '0');
  final _tankThresholdController = TextEditingController(text: '1000');
  final _tankLocationController = TextEditingController();
  final _dispenserNameController = TextEditingController();
  final _dispenserCodeController = TextEditingController();
  final _dispenserLocationController = TextEditingController();
  final _nozzleNameController = TextEditingController();
  final _nozzleCodeController = TextEditingController();
  final _nozzleMeterController = TextEditingController(text: '0');
  final _businessNameController = TextEditingController();
  final _invoicePrefixController = TextEditingController();
  final _footerTextController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _useOrganizationBranding = true;
  bool _hasShops = false;
  bool _hasPos = false;
  bool _hasTankers = false;
  bool _hasHardware = false;
  bool _allowMeterAdjustments = true;
  bool _stationIsActive = true;

  String? _errorMessage;
  String? _feedbackMessage;
  _StationSetupSection _section = _StationSetupSection.stationProfile;

  List<Map<String, dynamic>> _organizations = const [];
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _tanks = const [];
  List<Map<String, dynamic>> _dispensers = const [];
  List<Map<String, dynamic>> _nozzles = const [];

  Map<String, dynamic>? _selectedStation;
  Map<String, dynamic>? _invoiceProfile;

  int? _selectedOrganizationId;
  int? _selectedStationId;
  int? _selectedTankFuelTypeId;
  int? _selectedNozzleFuelTypeId;
  int? _selectedNozzleTankId;
  int? _selectedNozzleDispenserId;

  List<Map<String, dynamic>> _dedupeById(List<Map<String, dynamic>> items) {
    final seen = <Object?>{};
    final result = <Map<String, dynamic>>[];
    for (final item in items) {
      final id = item['id'];
      if (seen.add(id)) {
        result.add(item);
      }
    }
    return result;
  }

  int? _validSelection(int? selectedId, List<Map<String, dynamic>> items) {
    if (selectedId == null) return null;
    for (final item in items) {
      if (item['id'] == selectedId) {
        return selectedId;
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _logoUrlController.dispose();
    _fuelTypeNameController.dispose();
    _fuelTypeDescriptionController.dispose();
    _tankNameController.dispose();
    _tankCodeController.dispose();
    _tankCapacityController.dispose();
    _tankCurrentVolumeController.dispose();
    _tankThresholdController.dispose();
    _tankLocationController.dispose();
    _dispenserNameController.dispose();
    _dispenserCodeController.dispose();
    _dispenserLocationController.dispose();
    _nozzleNameController.dispose();
    _nozzleCodeController.dispose();
    _nozzleMeterController.dispose();
    _businessNameController.dispose();
    _invoicePrefixController.dispose();
    _footerTextController.dispose();
    super.dispose();
  }

  int? _firstId(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    return items.first['id'] as int;
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final organizations = _dedupeById(
        List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchOrganizations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      );
      final allStations = _dedupeById(
        List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchStations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      );
      final fuelTypes = _dedupeById(
        List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelTypes()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      );

      final organizationId =
          _validSelection(_selectedOrganizationId, organizations) ??
          (organizations.isNotEmpty ? organizations.first['id'] as int : null);
      final stations = organizationId == null
          ? allStations
          : _dedupeById(
              allStations
                .where(
                  (station) => station['organization_id'] == organizationId,
                )
                .toList(),
            );
      final stationId =
          _validSelection(_selectedStationId, stations) ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      final tanks = stationId == null
          ? const <Map<String, dynamic>>[]
          : _dedupeById(List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTanks(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            ));
      final dispensers = stationId == null
          ? const <Map<String, dynamic>>[]
          : _dedupeById(List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchDispensers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            ));
      final nozzles = stationId == null
          ? const <Map<String, dynamic>>[]
          : _dedupeById(List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNozzles(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            ));
      final selectedStation = stations.cast<Map<String, dynamic>?>().firstWhere(
        (station) => station?['id'] == stationId,
        orElse: () => null,
      );
      final invoiceProfile = stationId == null
          ? null
          : await widget.sessionController.fetchInvoiceProfile(
              stationId: stationId,
            );

      if (!mounted) return;

      _hydrateStation(selectedStation);
      _hydrateInvoice(invoiceProfile);

      final selectedTankFuelTypeId =
          _validSelection(_selectedTankFuelTypeId, fuelTypes) ??
          _firstId(fuelTypes);
      final selectedNozzleFuelTypeId =
          _validSelection(_selectedNozzleFuelTypeId, fuelTypes) ??
          _firstId(fuelTypes);
      final selectedNozzleTankId =
          _validSelection(_selectedNozzleTankId, tanks) ?? _firstId(tanks);
      final selectedNozzleDispenserId =
          _validSelection(_selectedNozzleDispenserId, dispensers) ??
          _firstId(dispensers);

      setState(() {
        _organizations = organizations;
        _stations = stations;
        _fuelTypes = fuelTypes;
        _tanks = tanks;
        _dispensers = dispensers;
        _nozzles = nozzles;
        _selectedOrganizationId = organizationId;
        _selectedStationId = stationId;
        _selectedStation = selectedStation;
        _invoiceProfile = invoiceProfile;
        _selectedTankFuelTypeId = selectedTankFuelTypeId;
        _selectedNozzleFuelTypeId = selectedNozzleFuelTypeId;
        _selectedNozzleTankId = selectedNozzleTankId;
        _selectedNozzleDispenserId = selectedNozzleDispenserId;
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

  void _hydrateStation(Map<String, dynamic>? station) {
    _displayNameController.text = station?['display_name'] as String? ?? '';
    _logoUrlController.text = station?['logo_url'] as String? ?? '';
    _useOrganizationBranding =
        station?['use_organization_branding'] as bool? ?? true;
    _hasShops = station?['has_shops'] as bool? ?? false;
    _hasPos = station?['has_pos'] as bool? ?? false;
    _hasTankers = station?['has_tankers'] as bool? ?? false;
    _hasHardware = station?['has_hardware'] as bool? ?? false;
    _allowMeterAdjustments =
        station?['allow_meter_adjustments'] as bool? ?? true;
    _stationIsActive = station?['is_active'] as bool? ?? true;
  }

  void _hydrateInvoice(Map<String, dynamic>? invoice) {
    _businessNameController.text = invoice?['business_name'] as String? ?? '';
    _invoicePrefixController.text = invoice?['invoice_prefix'] as String? ?? '';
    _footerTextController.text = invoice?['footer_text'] as String? ?? '';
  }

  Map<String, dynamic>? get _selectedOrganization =>
      _organizations.cast<Map<String, dynamic>?>().firstWhere(
        (organization) => organization?['id'] == _selectedOrganizationId,
        orElse: () => null,
      );

  Future<void> _changeOrganization(int? organizationId) async {
    if (organizationId == null) return;
    setState(() {
      _selectedOrganizationId = organizationId;
      _selectedStationId = null;
    });
    await _loadWorkspace();
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
    });
    await _loadWorkspace();
  }

  Future<void> _saveStationProfile() async {
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
      final station = await widget.sessionController.updateStation(
        stationId: stationId,
        payload: {
          'display_name': _emptyToNull(_displayNameController.text),
          'logo_url': _emptyToNull(_logoUrlController.text),
          'use_organization_branding': _useOrganizationBranding,
          'has_shops': _hasShops,
          'has_pos': _hasPos,
          'has_tankers': _hasTankers,
          'has_hardware': _hasHardware,
          'allow_meter_adjustments': _allowMeterAdjustments,
          'is_active': _stationIsActive,
          'setup_status': 'in_progress',
        },
      );
      if (!mounted) return;
      _hydrateStation(station);
      setState(() {
        _selectedStation = station;
        _feedbackMessage = 'Station profile updated.';
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

  Future<void> _createFuelType() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final fuelType = await widget.sessionController.createFuelType({
        'name': _fuelTypeNameController.text.trim(),
        'description': _emptyToNull(_fuelTypeDescriptionController.text),
      });
      if (!mounted) return;
      _fuelTypeNameController.clear();
      _fuelTypeDescriptionController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Fuel type ${fuelType['name']} created.';
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

  Future<void> _createTank() async {
    final stationId = _selectedStationId;
    final fuelTypeId = _selectedTankFuelTypeId;
    if (stationId == null || fuelTypeId == null) {
      setState(() {
        _feedbackMessage = 'Select a station and fuel type first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final tank = await widget.sessionController.createTank({
        'name': _tankNameController.text.trim(),
        'code': _tankCodeController.text.trim(),
        'capacity': double.parse(_tankCapacityController.text.trim()),
        'current_volume': double.parse(
          _tankCurrentVolumeController.text.trim(),
        ),
        'low_stock_threshold': double.parse(
          _tankThresholdController.text.trim(),
        ),
        'location': _emptyToNull(_tankLocationController.text),
        'station_id': stationId,
        'fuel_type_id': fuelTypeId,
      });
      if (!mounted) return;
      _resetTankForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Tank ${tank['name']} created.';
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

  Future<void> _createDispenser() async {
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
      final dispenser = await widget.sessionController.createDispenser({
        'name': _dispenserNameController.text.trim(),
        'code': _dispenserCodeController.text.trim(),
        'location': _emptyToNull(_dispenserLocationController.text),
        'station_id': stationId,
      });
      if (!mounted) return;
      _resetDispenserForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Dispenser ${dispenser['name']} created.';
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

  Future<void> _createNozzle() async {
    final stationId = _selectedStationId;
    final fuelTypeId = _selectedNozzleFuelTypeId;
    final tankId = _selectedNozzleTankId;
    final dispenserId = _selectedNozzleDispenserId;
    if (stationId == null ||
        fuelTypeId == null ||
        tankId == null ||
        dispenserId == null) {
      setState(() {
        _feedbackMessage =
            'Select a station, fuel type, tank, and dispenser first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final nozzle = await widget.sessionController.createNozzle({
        'name': _nozzleNameController.text.trim(),
        'code': _nozzleCodeController.text.trim(),
        'station_id': stationId,
        'fuel_type_id': fuelTypeId,
        'tank_id': tankId,
        'dispenser_id': dispenserId,
        'meter_reading': double.parse(_nozzleMeterController.text.trim()),
      });
      if (!mounted) return;
      _resetNozzleForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Nozzle ${nozzle['name']} created.';
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
          'invoice_prefix': _emptyToNull(_invoicePrefixController.text),
          'footer_text': _emptyToNull(_footerTextController.text),
        },
      );
      if (!mounted) return;
      _hydrateInvoice(profile);
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

  void _resetTankForm() {
    _tankNameController.clear();
    _tankCodeController.clear();
    _tankCapacityController.clear();
    _tankCurrentVolumeController.text = '0';
    _tankThresholdController.text = '1000';
    _tankLocationController.clear();
    _selectedTankFuelTypeId = _firstId(_fuelTypes);
  }

  void _resetDispenserForm() {
    _dispenserNameController.clear();
    _dispenserCodeController.clear();
    _dispenserLocationController.clear();
  }

  void _resetNozzleForm() {
    _nozzleNameController.clear();
    _nozzleCodeController.clear();
    _nozzleMeterController.text = '0';
    _selectedNozzleFuelTypeId = _firstId(_fuelTypes);
    _selectedNozzleTankId = _firstId(_tanks);
    _selectedNozzleDispenserId = _firstId(_dispensers);
  }

  String _lookupName(List<Map<String, dynamic>> items, dynamic id) {
    final match = items.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == id,
      orElse: () => null,
    );
    return match?['name'] as String? ??
        match?['code'] as String? ??
        (id?.toString() ?? '-');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Station Setup',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Move from organization onboarding into practical station configuration: operational flags, fuel setup, forecourt mapping, and invoice basics.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'station-setup-org-${_selectedOrganizationId ?? 'none'}',
                          ),
                          initialValue: _selectedOrganizationId,
                          decoration: const InputDecoration(
                            labelText: 'Organization',
                          ),
                          items: [
                            for (final organization in _organizations)
                              DropdownMenuItem<int>(
                                value: organization['id'] as int,
                                child: Text(
                                  organization['name'] as String? ??
                                      'Organization',
                                ),
                              ),
                          ],
                          onChanged: _changeOrganization,
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'station-setup-station-${_selectedStationId ?? 'none'}',
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_StationSetupSection>(
                      segments: const [
                        ButtonSegment(
                          value: _StationSetupSection.stationProfile,
                          label: Text('Station'),
                          icon: Icon(Icons.store_outlined),
                        ),
                        ButtonSegment(
                          value: _StationSetupSection.fuelTypes,
                          label: Text('Fuel Types'),
                          icon: Icon(Icons.opacity_outlined),
                        ),
                        ButtonSegment(
                          value: _StationSetupSection.inventory,
                          label: Text('Forecourt'),
                          icon: Icon(Icons.local_gas_station_outlined),
                        ),
                        ButtonSegment(
                          value: _StationSetupSection.invoiceProfile,
                          label: Text('Invoice'),
                          icon: Icon(Icons.receipt_long_outlined),
                        ),
                      ],
                      selected: {_section},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _section = selection.first;
                          _feedbackMessage = null;
                          _errorMessage = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_selectedStation == null)
                    const Text(
                      'No station found for this organization yet. Complete onboarding first.',
                    )
                  else ...[
                    switch (_section) {
                      _StationSetupSection.stationProfile =>
                        _buildStationProfileSection(context),
                      _StationSetupSection.fuelTypes => _buildFuelTypeSection(
                        context,
                      ),
                      _StationSetupSection.inventory => _buildInventorySection(
                        context,
                      ),
                      _StationSetupSection.invoiceProfile =>
                        _buildInvoiceSection(context),
                    },
                  ],
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

  Widget _buildStationProfileSection(BuildContext context) {
    final organization = _organizations
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['id'] == _selectedOrganizationId,
          orElse: () => null,
        );
    return ResponsiveSplit(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Station Profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _displayNameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              helperText:
                  'How this station should appear in the app and documents.',
            ),
          ),
          const SizedBox(height: 12),
          _SetupBrandPreviewCard(
            brandName: _useOrganizationBranding
                ? (_selectedOrganization?['brand_name'] as String? ??
                      _selectedOrganization?['name'] as String? ??
                      'Organization Brand')
                : (_selectedStation?['brand_name'] as String? ??
                      _selectedStation?['name'] as String? ??
                      'Station Brand'),
            logoUrl: _useOrganizationBranding
                ? (_selectedOrganization?['logo_url'] as String?)
                : _logoUrlController.text.trim(),
            helperText: _useOrganizationBranding
                ? 'This station is inheriting the organization brand automatically.'
                : 'This station is using its own custom branding.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _logoUrlController,
            enabled: !_useOrganizationBranding,
            decoration: InputDecoration(
              labelText: 'Station Logo URL',
              helperText: _useOrganizationBranding
                  ? 'Using the organization branding right now.'
                  : 'Optional station-specific branding override.',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useOrganizationBranding,
            title: const Text('Use Organization Branding'),
            subtitle: const Text(
              'Keep station branding inherited from the parent company.',
            ),
            onChanged: (value) {
              setState(() {
                _useOrganizationBranding = value;
              });
            },
          ),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _buildFlagTile(
                label: 'Shops',
                value: _hasShops,
                onChanged: (value) => setState(() => _hasShops = value),
              ),
              _buildFlagTile(
                label: 'POS',
                value: _hasPos,
                onChanged: (value) => setState(() => _hasPos = value),
              ),
              _buildFlagTile(
                label: 'Tankers',
                value: _hasTankers,
                onChanged: (value) => setState(() => _hasTankers = value),
              ),
              _buildFlagTile(
                label: 'Hardware',
                value: _hasHardware,
                onChanged: (value) => setState(() => _hasHardware = value),
              ),
              _buildFlagTile(
                label: 'Meter Adjustments',
                value: _allowMeterAdjustments,
                onChanged: (value) =>
                    setState(() => _allowMeterAdjustments = value),
              ),
              _buildFlagTile(
                label: 'Active',
                value: _stationIsActive,
                onChanged: (value) => setState(() => _stationIsActive = value),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _saveStationProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isSubmitting ? 'Saving...' : 'Save Station Setup'),
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Station Context',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text('Organization: ${organization?['name'] ?? '-'}'),
              Text('Brand: ${organization?['brand_name'] ?? '-'}'),
              Text('Station: ${_selectedStation?['name'] ?? '-'}'),
              Text('Code: ${_selectedStation?['code'] ?? '-'}'),
              Text('Setup Status: ${_selectedStation?['setup_status'] ?? '-'}'),
              Text(
                'Head Office: ${_selectedStation?['is_head_office'] == true ? 'yes' : 'no'}',
              ),
              const SizedBox(height: 16),
              Text(
                'Recommended next order',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text('1. Confirm flags and branding'),
              const Text('2. Add fuel types if needed'),
              const Text('3. Map tanks, dispensers, and nozzles'),
              const Text('4. Save invoice basics'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFuelTypeSection(BuildContext context) {
    return ResponsiveSplit(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Fuel Types', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fuelTypeNameController,
            decoration: const InputDecoration(
              labelText: 'Fuel Type Name',
              helperText: 'Examples: Petrol, Diesel, HOBC, Engine Oil.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _fuelTypeDescriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _createFuelType,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(_isSubmitting ? 'Saving...' : 'Add Fuel Type'),
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available Fuel Types',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_fuelTypes.isEmpty)
                const Text('No fuel types have been added yet.')
              else
                for (final fuelType in _fuelTypes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(fuelType['name'] as String? ?? 'Fuel Type'),
                    subtitle: Text(fuelType['description'] as String? ?? '-'),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInventorySection(BuildContext context) {
    final fuelTypeItems = [
      for (final fuelType in _fuelTypes)
        DropdownMenuItem<int>(
          value: fuelType['id'] as int,
          child: Text(fuelType['name'] as String? ?? 'Fuel Type'),
        ),
    ];
    final tankItems = [
      for (final tank in _tanks)
        DropdownMenuItem<int>(
          value: tank['id'] as int,
          child: Text(tank['name'] as String? ?? 'Tank'),
        ),
    ];
    final dispenserItems = [
      for (final dispenser in _dispensers)
        DropdownMenuItem<int>(
          value: dispenser['id'] as int,
          child: Text(dispenser['name'] as String? ?? 'Dispenser'),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Forecourt Mapping',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Text(
          'Create tanks, dispensers, and nozzles in sequence so later sales and meter logic map correctly.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        ResponsiveSplit(
          breakpoint: 1200,
          primary: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInventoryCard(
                context: context,
                title: 'Add Tank',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _tankNameController,
                      decoration: const InputDecoration(labelText: 'Tank Name'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tankCodeController,
                      decoration: const InputDecoration(labelText: 'Tank Code'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'setup-tank-fuel-${_selectedTankFuelTypeId ?? 'none'}',
                      ),
                      initialValue: _selectedTankFuelTypeId,
                      decoration: const InputDecoration(labelText: 'Fuel Type'),
                      items: fuelTypeItems,
                      onChanged: (value) {
                        setState(() {
                          _selectedTankFuelTypeId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tankCapacityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Capacity'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tankCurrentVolumeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Current Volume',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tankThresholdController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Low Stock Threshold',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tankLocationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _createTank,
                      child: Text(_isSubmitting ? 'Saving...' : 'Create Tank'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildInventoryCard(
                context: context,
                title: 'Add Dispenser',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dispenserNameController,
                      decoration: const InputDecoration(
                        labelText: 'Dispenser Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dispenserCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Dispenser Code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dispenserLocationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _createDispenser,
                      child: Text(
                        _isSubmitting ? 'Saving...' : 'Create Dispenser',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildInventoryCard(
                context: context,
                title: 'Add Nozzle',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nozzleNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nozzle Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nozzleCodeController,
                      decoration: const InputDecoration(
                        labelText: 'Nozzle Code',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'setup-nozzle-fuel-${_selectedNozzleFuelTypeId ?? 'none'}',
                      ),
                      initialValue: _selectedNozzleFuelTypeId,
                      decoration: const InputDecoration(labelText: 'Fuel Type'),
                      items: fuelTypeItems,
                      onChanged: (value) {
                        setState(() {
                          _selectedNozzleFuelTypeId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'setup-nozzle-tank-${_selectedNozzleTankId ?? 'none'}',
                      ),
                      initialValue: _selectedNozzleTankId,
                      decoration: const InputDecoration(labelText: 'Tank'),
                      items: tankItems,
                      onChanged: (value) {
                        setState(() {
                          _selectedNozzleTankId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      key: ValueKey<String>(
                        'setup-nozzle-dispenser-${_selectedNozzleDispenserId ?? 'none'}',
                      ),
                      initialValue: _selectedNozzleDispenserId,
                      decoration: const InputDecoration(labelText: 'Dispenser'),
                      items: dispenserItems,
                      onChanged: (value) {
                        setState(() {
                          _selectedNozzleDispenserId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nozzleMeterController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Opening Meter',
                        helperText:
                            'Later meter adjustments still go through the Hardware workspace.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _createNozzle,
                      child: Text(
                        _isSubmitting ? 'Saving...' : 'Create Nozzle',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          secondary: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Mapping Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryLine('Tanks', _tanks.length.toString()),
                  _buildSummaryLine(
                    'Dispensers',
                    _dispensers.length.toString(),
                  ),
                  _buildSummaryLine('Nozzles', _nozzles.length.toString()),
                  const Divider(height: 24),
                  Text('Tanks', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_tanks.isEmpty)
                    const Text('No tanks configured yet.')
                  else
                    for (final tank in _tanks)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(tank['name'] as String? ?? 'Tank'),
                        subtitle: Text(
                          '${tank['code'] ?? '-'} • ${_lookupName(_fuelTypes, tank['fuel_type_id'])}',
                        ),
                      ),
                  const Divider(height: 24),
                  Text(
                    'Nozzle Mapping',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_nozzles.isEmpty)
                    const Text('No nozzle mapping configured yet.')
                  else
                    for (final nozzle in _nozzles)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(nozzle['name'] as String? ?? 'Nozzle'),
                        subtitle: Text(
                          '${_lookupName(_dispensers, nozzle['dispenser_id'])} -> ${_lookupName(_tanks, nozzle['tank_id'])} • ${_lookupName(_fuelTypes, nozzle['fuel_type_id'])}',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSection(BuildContext context) {
    return ResponsiveSplit(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice Basics', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _businessNameController,
            decoration: const InputDecoration(
              labelText: 'Business Name',
              helperText: 'Shown on receipts, statements, and invoices.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _invoicePrefixController,
            decoration: const InputDecoration(labelText: 'Invoice Prefix'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _footerTextController,
            decoration: const InputDecoration(labelText: 'Footer Text'),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _saveInvoiceProfile,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isSubmitting ? 'Saving...' : 'Save Invoice Basics'),
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Invoice Profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildSummaryLine(
                'Business Name',
                _invoiceProfile?['business_name'] as String? ?? '-',
              ),
              _buildSummaryLine(
                'Prefix',
                _invoiceProfile?['invoice_prefix'] as String? ?? '-',
              ),
              _buildSummaryLine(
                'Footer',
                _invoiceProfile?['footer_text'] as String? ?? '-',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlagTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SizedBox(
      width: 200,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: value,
        title: Text(label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInventoryCard({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupBrandPreviewCard extends StatelessWidget {
  const _SetupBrandPreviewCard({
    required this.brandName,
    required this.logoUrl,
    required this.helperText,
  });

  final String brandName;
  final String? logoUrl;
  final String helperText;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: _SetupBrandAvatar(brandName: brandName, logoUrl: logoUrl),
        title: Text(brandName),
        subtitle: Text(helperText),
      ),
    );
  }
}

class _SetupBrandAvatar extends StatelessWidget {
  const _SetupBrandAvatar({required this.brandName, required this.logoUrl});

  final String brandName;
  final String? logoUrl;

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
          errorBuilder: (_, _, _) => _fallbackAvatar(context),
        ),
      );
    }
    return _fallbackAvatar(context);
  }

  Widget _fallbackAvatar(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
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
