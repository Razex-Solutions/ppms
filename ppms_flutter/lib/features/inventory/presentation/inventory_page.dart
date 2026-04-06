import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

enum _InventorySection { tanks, dispensers, nozzles }

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final _tankNameController = TextEditingController();
  final _tankCodeController = TextEditingController();
  final _tankCapacityController = TextEditingController();
  final _tankCurrentVolumeController = TextEditingController(text: '0');
  final _tankLowStockController = TextEditingController(text: '1000');
  final _tankLocationController = TextEditingController();
  final _internalUsageQuantityController = TextEditingController(text: '0');
  final _internalUsagePurposeController = TextEditingController();
  final _internalUsageNotesController = TextEditingController();
  final _dispenserNameController = TextEditingController();
  final _dispenserCodeController = TextEditingController();
  final _dispenserLocationController = TextEditingController();
  final _nozzleNameController = TextEditingController();
  final _nozzleCodeController = TextEditingController();
  final _nozzleMeterController = TextEditingController(text: '0');
  final _searchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _InventorySection _section = _InventorySection.tanks;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _tanks = const [];
  List<Map<String, dynamic>> _dispensers = const [];
  List<Map<String, dynamic>> _nozzles = const [];
  List<Map<String, dynamic>> _internalUsageRecords = const [];
  int? _selectedStationId;
  int? _selectedTankId;
  int? _selectedDispenserId;
  int? _selectedNozzleId;
  int? _selectedTankFuelTypeId;
  int? _selectedNozzleFuelTypeId;
  int? _selectedNozzleTankId;
  int? _selectedNozzleDispenserId;

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _tankNameController.dispose();
    _tankCodeController.dispose();
    _tankCapacityController.dispose();
    _tankCurrentVolumeController.dispose();
    _tankLowStockController.dispose();
    _tankLocationController.dispose();
    _internalUsageQuantityController.dispose();
    _internalUsagePurposeController.dispose();
    _internalUsageNotesController.dispose();
    _dispenserNameController.dispose();
    _dispenserCodeController.dispose();
    _dispenserLocationController.dispose();
    _nozzleNameController.dispose();
    _nozzleCodeController.dispose();
    _nozzleMeterController.dispose();
    _searchController.dispose();
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
      final preferredStationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final stationId =
          _selectedStationId ??
          preferredStationId ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      final fuelTypes = _showInventoryWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchFuelTypes()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final tanks = !_showInventoryWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTanks(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final dispensers = !_showInventoryWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchDispensers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final nozzles = !_showInventoryWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNozzles(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final internalUsageRecords = !_showInventoryWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchInternalFuelUsage(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) return;

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _fuelTypes = fuelTypes;
        _tanks = tanks;
        _dispensers = dispensers;
        _nozzles = nozzles;
        _internalUsageRecords = internalUsageRecords;
        _selectedTankFuelTypeId =
            _selectedTankFuelTypeId ?? _firstId(fuelTypes);
        _selectedNozzleFuelTypeId =
            _selectedNozzleFuelTypeId ?? _firstId(fuelTypes);
        _selectedNozzleTankId =
            _selectedNozzleTankId ?? _resolveSelectedId(_selectedTankId, tanks);
        _selectedNozzleDispenserId =
            _selectedNozzleDispenserId ??
            _resolveSelectedId(_selectedDispenserId, dispensers);
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

  int? _firstId(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    return items.first['id'] as int;
  }

  int? _resolveSelectedId(int? current, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return null;
    if (current != null && items.any((item) => item['id'] == current)) {
      return current;
    }
    return items.first['id'] as int;
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
      _selectedTankId = null;
      _selectedDispenserId = null;
      _selectedNozzleId = null;
      _selectedNozzleTankId = null;
      _selectedNozzleDispenserId = null;
    });
    _resetTankForm();
    _resetDispenserForm();
    _resetNozzleForm();
    await _loadWorkspace();
  }

  Future<void> _saveTank() async {
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
      final payload = {
        'name': _tankNameController.text.trim(),
        'code': _tankCodeController.text.trim(),
        'capacity': double.parse(_tankCapacityController.text.trim()),
        'current_volume': double.parse(
          _tankCurrentVolumeController.text.trim(),
        ),
        'low_stock_threshold': double.parse(
          _tankLowStockController.text.trim(),
        ),
        'location': _emptyToNull(_tankLocationController.text),
        'station_id': stationId,
        'fuel_type_id': fuelTypeId,
      };
      final isEditing = _selectedTankId != null;
      final tank = isEditing
          ? await widget.sessionController.updateTank(
              tankId: _selectedTankId!,
              payload: payload,
            )
          : await widget.sessionController.createTank(payload);

      if (!mounted) return;

      _resetTankForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Tank ${tank['name']} ${isEditing ? 'updated' : 'created'} successfully.';
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

  Future<void> _recordInternalFuelUsage() async {
    final selectedTank = _tanks.cast<Map<String, dynamic>?>().firstWhere(
      (tank) => tank?['id'] == _selectedTankId,
      orElse: () => null,
    );
    if (selectedTank == null) {
      setState(() {
        _feedbackMessage =
            'Select a tank before recording internal fuel usage.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final usage = await widget.sessionController.createInternalFuelUsage({
        'tank_id': selectedTank['id'] as int,
        'fuel_type_id': selectedTank['fuel_type_id'] as int,
        'quantity': double.parse(_internalUsageQuantityController.text.trim()),
        'purpose': _internalUsagePurposeController.text.trim(),
        'notes': _emptyToNull(_internalUsageNotesController.text),
      });
      if (!mounted) return;

      _internalUsageQuantityController.text = '0';
      _internalUsagePurposeController.clear();
      _internalUsageNotesController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Internal fuel usage of ${_formatNumber(usage['quantity'] as num?)} recorded.';
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

  Future<void> _saveDispenser() async {
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
      final payload = {
        'name': _dispenserNameController.text.trim(),
        'code': _dispenserCodeController.text.trim(),
        'location': _emptyToNull(_dispenserLocationController.text),
        'station_id': stationId,
      };
      final isEditing = _selectedDispenserId != null;
      final dispenser = isEditing
          ? await widget.sessionController.updateDispenser(
              dispenserId: _selectedDispenserId!,
              payload: payload,
            )
          : await widget.sessionController.createDispenser(payload);

      if (!mounted) return;

      _resetDispenserForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Dispenser ${dispenser['name']} ${isEditing ? 'updated' : 'created'} successfully.';
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

  Future<void> _saveNozzle() async {
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
            'Select a station, tank, dispenser, and fuel type first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final isEditing = _selectedNozzleId != null;
      final payload = <String, dynamic>{
        'name': _nozzleNameController.text.trim(),
        'code': _nozzleCodeController.text.trim(),
        'station_id': stationId,
        'tank_id': tankId,
        'dispenser_id': dispenserId,
        'fuel_type_id': fuelTypeId,
      };
      if (!isEditing) {
        payload['meter_reading'] = double.parse(_nozzleMeterController.text);
      }

      final nozzle = isEditing
          ? await widget.sessionController.updateNozzle(
              nozzleId: _selectedNozzleId!,
              payload: payload,
            )
          : await widget.sessionController.createNozzle(payload);

      if (!mounted) return;

      _resetNozzleForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Nozzle ${nozzle['name']} ${isEditing ? 'updated' : 'created'} successfully.';
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

  Future<void> _deleteTank() async {
    final tankId = _selectedTankId;
    if (tankId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Tank',
      message:
          'Delete this tank only if it has no dependent nozzles, purchases, or tank dips.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteTank(
        tankId: tankId,
      );
      if (!mounted) return;
      _resetTankForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Tank deleted successfully.';
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

  Future<void> _deleteDispenser() async {
    final dispenserId = _selectedDispenserId;
    if (dispenserId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Dispenser',
      message: 'Delete this dispenser if it is no longer needed.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteDispenser(
        dispenserId: dispenserId,
      );
      if (!mounted) return;
      _resetDispenserForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Dispenser deleted successfully.';
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

  Future<void> _deleteNozzle() async {
    final nozzleId = _selectedNozzleId;
    if (nozzleId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Nozzle',
      message:
          'Delete this nozzle only if removing it will not disrupt active operations.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteNozzle(
        nozzleId: nozzleId,
      );
      if (!mounted) return;
      _resetNozzleForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Nozzle deleted successfully.';
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

  void _selectTank(Map<String, dynamic> tank) {
    setState(() {
      _selectedTankId = tank['id'] as int;
      _tankNameController.text = tank['name'] as String? ?? '';
      _tankCodeController.text = tank['code'] as String? ?? '';
      _tankCapacityController.text = ((tank['capacity'] as num?) ?? 0)
          .toString();
      _tankCurrentVolumeController.text =
          ((tank['current_volume'] as num?) ?? 0).toString();
      _tankLowStockController.text =
          ((tank['low_stock_threshold'] as num?) ?? 0).toString();
      _tankLocationController.text = tank['location'] as String? ?? '';
      _selectedTankFuelTypeId = tank['fuel_type_id'] as int?;
      _feedbackMessage = 'Editing tank ${tank['name']}.';
      _errorMessage = null;
    });
  }

  void _selectDispenser(Map<String, dynamic> dispenser) {
    setState(() {
      _selectedDispenserId = dispenser['id'] as int;
      _dispenserNameController.text = dispenser['name'] as String? ?? '';
      _dispenserCodeController.text = dispenser['code'] as String? ?? '';
      _dispenserLocationController.text =
          dispenser['location'] as String? ?? '';
      _feedbackMessage = 'Editing dispenser ${dispenser['name']}.';
      _errorMessage = null;
    });
  }

  void _selectNozzle(Map<String, dynamic> nozzle) {
    setState(() {
      _selectedNozzleId = nozzle['id'] as int;
      _nozzleNameController.text = nozzle['name'] as String? ?? '';
      _nozzleCodeController.text = nozzle['code'] as String? ?? '';
      _nozzleMeterController.text = ((nozzle['meter_reading'] as num?) ?? 0)
          .toString();
      _selectedNozzleFuelTypeId = nozzle['fuel_type_id'] as int?;
      _selectedNozzleTankId = nozzle['tank_id'] as int?;
      _selectedNozzleDispenserId = nozzle['dispenser_id'] as int?;
      _feedbackMessage =
          'Editing nozzle ${nozzle['name']}. Use Hardware for meter adjustments.';
      _errorMessage = null;
    });
  }

  void _resetTankForm() {
    _selectedTankId = null;
    _tankNameController.clear();
    _tankCodeController.clear();
    _tankCapacityController.clear();
    _tankCurrentVolumeController.text = '0';
    _tankLowStockController.text = '1000';
    _tankLocationController.clear();
    _selectedTankFuelTypeId = _firstId(_fuelTypes);
  }

  void _resetDispenserForm() {
    _selectedDispenserId = null;
    _dispenserNameController.clear();
    _dispenserCodeController.clear();
    _dispenserLocationController.clear();
  }

  void _resetNozzleForm() {
    _selectedNozzleId = null;
    _nozzleNameController.clear();
    _nozzleCodeController.clear();
    _nozzleMeterController.text = '0';
    _selectedNozzleFuelTypeId = _firstId(_fuelTypes);
    _selectedNozzleTankId = _resolveSelectedId(null, _tanks);
    _selectedNozzleDispenserId = _resolveSelectedId(null, _dispensers);
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _formatNumber(num? value) {
    final safe = value ?? 0;
    return safe % 1 == 0 ? safe.toStringAsFixed(0) : safe.toStringAsFixed(2);
  }

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      final haystack = item.values.join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  bool _hasAction(String module, String action) {
    final modulePermissions =
        widget.sessionController.permissions[module] as List<dynamic>?;
    if (modulePermissions == null) {
      return false;
    }
    return modulePermissions.contains(action);
  }

  bool get _canReadTanks =>
      _hasAction('tanks', 'create') ||
      _hasAction('tanks', 'update') ||
      _hasAction('tanks', 'delete') ||
      _hasAction('internal_fuel_usage', 'read');
  bool get _canManageTanks =>
      _hasAction('tanks', 'create') || _hasAction('tanks', 'update');
  bool get _canDeleteTanks => _hasAction('tanks', 'delete');
  bool get _canReadInternalFuelUsage =>
      _hasAction('internal_fuel_usage', 'read');
  bool get _canRecordInternalFuelUsage =>
      _hasAction('internal_fuel_usage', 'create');
  bool get _canReadDispensers =>
      _hasAction('dispensers', 'create') ||
      _hasAction('dispensers', 'update') ||
      _hasAction('dispensers', 'delete');
  bool get _canManageDispensers =>
      _hasAction('dispensers', 'create') || _hasAction('dispensers', 'update');
  bool get _canDeleteDispensers => _hasAction('dispensers', 'delete');
  bool get _canReadNozzles =>
      _hasAction('nozzles', 'create') ||
      _hasAction('nozzles', 'update') ||
      _hasAction('nozzles', 'delete') ||
      _hasAction('nozzles', 'read_meter_history') ||
      _hasAction('nozzles', 'adjust_meter');
  bool get _canManageNozzles =>
      _hasAction('nozzles', 'create') || _hasAction('nozzles', 'update');
  bool get _canDeleteNozzles => _hasAction('nozzles', 'delete');
  bool get _showInventoryWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['tanks', 'dispensers', 'nozzles'],
    permissionModules: const ['tanks', 'dispensers', 'nozzles'],
    hideWhenModulesOff: true,
  );

  Map<String, dynamic>? get _selectedTank {
    for (final tank in _tanks) {
      if (tank['id'] == _selectedTankId) {
        return tank;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedDispenser {
    for (final dispenser in _dispensers) {
      if (dispenser['id'] == _selectedDispenserId) {
        return dispenser;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedNozzle {
    for (final nozzle in _nozzles) {
      if (nozzle['id'] == _selectedNozzleId) {
        return nozzle;
      }
    }
    return null;
  }

  String get _selectedStationLabel {
    for (final station in _stations) {
      if (station['id'] == _selectedStationId) {
        final name = station['name'] as String? ?? 'Station';
        final code = station['code'] as String? ?? '-';
        return '$name ($code)';
      }
    }
    return 'No station selected';
  }

  Widget _buildPermissionNotice(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showInventoryWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Inventory controls are turned off for this scope, so tanks, dispensers, and nozzles stay hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    final stationItems = _stations
        .map(
          (station) => DropdownMenuItem<int>(
            value: station['id'] as int,
            child: Text(station['name'] as String? ?? 'Station'),
          ),
        )
        .toList();

    final availableSections = <_InventorySection>[
      if (_canReadTanks) _InventorySection.tanks,
      if (_canReadDispensers) _InventorySection.dispensers,
      if (_canReadNozzles) _InventorySection.nozzles,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }

    Widget content;
    switch (_section) {
      case _InventorySection.tanks:
        content = _buildTanks();
      case _InventorySection.dispensers:
        content = _buildDispensers();
      case _InventorySection.nozzles:
        content = _buildNozzles();
    }

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Inventory', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            availableSections.isEmpty
                ? 'This role does not currently have access to inventory management.'
                : 'Manage tanks, dispensers, and nozzles for the selected station.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: DropdownButtonFormField<int>(
                  key: ValueKey<String>(
                    'inventory-station-${_selectedStationId ?? 'none'}',
                  ),
                  initialValue: _selectedStationId,
                  items: stationItems,
                  onChanged: _isLoading || availableSections.isEmpty
                      ? null
                      : _changeStation,
                  decoration: const InputDecoration(labelText: 'Station'),
                ),
              ),
              if (availableSections.isNotEmpty)
                SegmentedButton<_InventorySection>(
                  segments: [
                    if (_canReadTanks)
                      const ButtonSegment(
                        value: _InventorySection.tanks,
                        label: Text('Tanks'),
                      ),
                    if (_canReadDispensers)
                      const ButtonSegment(
                        value: _InventorySection.dispensers,
                        label: Text('Dispensers'),
                      ),
                    if (_canReadNozzles)
                      const ButtonSegment(
                        value: _InventorySection.nozzles,
                        label: Text('Nozzles'),
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
            ],
          ),
          const SizedBox(height: 16),
          if (availableSections.isEmpty) ...[
            _buildPermissionNotice(
              context,
              'This role cannot view inventory master data. Ask an administrator for tank, dispenser, or nozzle access.',
            ),
            const SizedBox(height: 12),
          ],
          _buildWorkspaceReview(context),
          const SizedBox(height: 12),
          if (_feedbackMessage != null) ...[
            Text(
              _feedbackMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
          ],
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            content,
        ],
      ),
    );
  }

  Widget _buildWorkspaceReview(BuildContext context) {
    final selectedTitle = switch (_section) {
      _InventorySection.tanks =>
        _selectedTank == null
            ? 'No tank selected yet'
            : 'Tank ${_selectedTank!['name']} is selected',
      _InventorySection.dispensers =>
        _selectedDispenser == null
            ? 'No dispenser selected yet'
            : 'Dispenser ${_selectedDispenser!['name']} is selected',
      _InventorySection.nozzles =>
        _selectedNozzle == null
            ? 'No nozzle selected yet'
            : 'Nozzle ${_selectedNozzle!['name']} is selected',
    };
    final nextAction = switch (_section) {
      _InventorySection.tanks =>
        'Review tank volume, fuel type, and low-stock limits before editing or recording internal usage.',
      _InventorySection.dispensers =>
        'Review the selected dispenser location and attached nozzles before editing.',
      _InventorySection.nozzles =>
        'Review the selected nozzle tank, dispenser, and meter context before editing.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review First',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(selectedTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(nextAction, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                context,
                icon: Icons.store_outlined,
                label: _selectedStationLabel,
              ),
              _buildInfoChip(
                context,
                icon: Icons.storage_outlined,
                label: 'Tanks ${_tanks.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.local_gas_station_outlined,
                label: 'Dispensers ${_dispensers.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.tune_outlined,
                label: 'Nozzles ${_nozzles.length}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTanks() {
    final canManageTanks = _canManageTanks;
    final canDeleteTanks = _canDeleteTanks;
    final canRecordInternalFuelUsage = _canRecordInternalFuelUsage;
    final canReadInternalFuelUsage = _canReadInternalFuelUsage;
    final fuelTypeItems = _fuelTypes
        .map(
          (fuelType) => DropdownMenuItem<int>(
            value: fuelType['id'] as int,
            child: Text(fuelType['name'] as String? ?? 'Fuel Type'),
          ),
        )
        .toList();

    final selectedTank = _selectedTank;
    final selectedTankUsage = selectedTank == null
        ? const <Map<String, dynamic>>[]
        : _internalUsageRecords
              .where((record) => record['tank_id'] == selectedTank['id'])
              .toList();
    return ResponsiveSplit(
      primary: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tank Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedTank == null)
                _buildEmptyState(
                  context,
                  'No tank selected yet.',
                  canManageTanks
                      ? 'Choose a tank from the list to review before editing, or use the form below to create a new one.'
                      : 'Choose a tank from the list to inspect inventory position and usage history.',
                )
              else ...[
                _buildSummaryBanner(
                  context,
                  title:
                      '${selectedTank['code'] ?? '-'} - ${selectedTank['name'] ?? 'Tank'}',
                  subtitle:
                      '${_lookupName(_fuelTypes, selectedTank['fuel_type_id'])} • ${_formatNumber(selectedTank['current_volume'] as num?)} / ${_formatNumber(selectedTank['capacity'] as num?)}',
                ),
                const SizedBox(height: 12),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Low Stock',
                    _formatNumber(selectedTank['low_stock_threshold'] as num?),
                  ),
                  _buildDetailItem(
                    'Location',
                    selectedTank['location'] as String? ?? '-',
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              Text(
                _selectedTankId == null ? 'Create Tank' : 'Edit Tank',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!canManageTanks) ...[
                const SizedBox(height: 12),
                _buildPermissionNotice(
                  context,
                  'This role can review tanks but cannot create or edit them.',
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _tankNameController,
                enabled: canManageTanks,
                decoration: const InputDecoration(labelText: 'Tank Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tankCodeController,
                enabled: canManageTanks,
                decoration: const InputDecoration(labelText: 'Tank Code'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'tank-fuel-${_selectedTankFuelTypeId ?? 'none'}',
                ),
                initialValue: _selectedTankFuelTypeId,
                items: fuelTypeItems,
                onChanged: canManageTanks
                    ? (value) {
                        setState(() => _selectedTankFuelTypeId = value);
                      }
                    : null,
                decoration: const InputDecoration(labelText: 'Fuel Type'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tankCapacityController,
                enabled: canManageTanks,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tankCurrentVolumeController,
                enabled: canManageTanks,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Current Volume'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tankLowStockController,
                enabled: canManageTanks,
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
                enabled: canManageTanks,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _isSubmitting || !canManageTanks
                        ? null
                        : _saveTank,
                    child: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : _selectedTankId == null
                          ? 'Create Tank'
                          : 'Save Changes',
                    ),
                  ),
                  if (_selectedTankId != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _resetTankForm();
                                    _feedbackMessage = 'Tank edit cancelled.';
                                  });
                                },
                          child: const Text('Cancel Edit'),
                        ),
                        OutlinedButton(
                          onPressed: _isSubmitting || !canDeleteTanks
                              ? null
                              : _deleteTank,
                          child: const Text('Delete Tank'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tanks', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Tanks',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_filterItems(_tanks).isEmpty)
                const Text('No tanks found for this station.')
              else
                ..._filterItems(_tanks).map(
                  (tank) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(tank['name'] as String? ?? 'Tank'),
                      subtitle: Text(
                        '${tank['code'] ?? '-'} - ${_formatNumber(tank['current_volume'] as num?)} / ${_formatNumber(tank['capacity'] as num?)}',
                      ),
                      trailing: Text(
                        _fuelTypes.firstWhere(
                                  (item) => item['id'] == tank['fuel_type_id'],
                                  orElse: () => const <String, dynamic>{},
                                )['name']
                                as String? ??
                            'Fuel',
                      ),
                      onTap: () => _selectTank(tank),
                    ),
                  ),
                ),
              if (selectedTank != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Tank Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Code',
                    selectedTank['code'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Fuel Type',
                    _lookupName(_fuelTypes, selectedTank['fuel_type_id']),
                  ),
                  _buildDetailItem(
                    'Current Volume',
                    _formatNumber(selectedTank['current_volume'] as num?),
                  ),
                  _buildDetailItem(
                    'Capacity',
                    _formatNumber(selectedTank['capacity'] as num?),
                  ),
                  _buildDetailItem(
                    'Low Stock',
                    _formatNumber(selectedTank['low_stock_threshold'] as num?),
                  ),
                  _buildDetailItem(
                    'Location',
                    selectedTank['location'] as String? ?? '-',
                  ),
                ]),
                const SizedBox(height: 16),
                Text(
                  'Internal Fuel Usage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (!canRecordInternalFuelUsage)
                  _buildPermissionNotice(
                    context,
                    canReadInternalFuelUsage
                        ? 'This role can review internal fuel usage but cannot record it.'
                        : 'Internal fuel usage is not available for this role.',
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _internalUsageQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Usage Quantity',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _internalUsagePurposeController,
                        decoration: const InputDecoration(labelText: 'Purpose'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _internalUsageNotesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _isSubmitting
                            ? null
                            : _recordInternalFuelUsage,
                        child: Text(
                          _isSubmitting
                              ? 'Recording...'
                              : 'Record Internal Usage',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                if (!canReadInternalFuelUsage)
                  const SizedBox.shrink()
                else if (selectedTankUsage.isEmpty)
                  const Text(
                    'No internal fuel usage recorded for this tank yet.',
                  )
                else
                  ...selectedTankUsage
                      .take(5)
                      .map(
                        (record) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.local_shipping_outlined),
                          title: Text(
                            '${_formatNumber(record['quantity'] as num?)} used for ${record['purpose']}',
                          ),
                          subtitle: Text(
                            record['notes'] as String? ??
                                'Internal consumption record',
                          ),
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDispensers() {
    final canManageDispensers = _canManageDispensers;
    final canDeleteDispensers = _canDeleteDispensers;
    final selectedDispenser = _selectedDispenser;
    return ResponsiveSplit(
      primary: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dispenser Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedDispenser == null)
                _buildEmptyState(
                  context,
                  'No dispenser selected yet.',
                  canManageDispensers
                      ? 'Choose a dispenser from the list to review before editing, or use the form below to create a new one.'
                      : 'Choose a dispenser from the list to inspect location and attached nozzle count.',
                )
              else ...[
                _buildSummaryBanner(
                  context,
                  title:
                      '${selectedDispenser['code'] ?? '-'} - ${selectedDispenser['name'] ?? 'Dispenser'}',
                  subtitle:
                      '${selectedDispenser['location'] ?? 'No location'} • ${_nozzles.where((nozzle) => nozzle['dispenser_id'] == selectedDispenser['id']).length} attached nozzles',
                ),
                const SizedBox(height: 12),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Station',
                    _lookupName(_stations, selectedDispenser['station_id']),
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              Text(
                _selectedDispenserId == null
                    ? 'Create Dispenser'
                    : 'Edit Dispenser',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!canManageDispensers) ...[
                const SizedBox(height: 12),
                _buildPermissionNotice(
                  context,
                  'This role can review dispensers but cannot create or edit them.',
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _dispenserNameController,
                enabled: canManageDispensers,
                decoration: const InputDecoration(labelText: 'Dispenser Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dispenserCodeController,
                enabled: canManageDispensers,
                decoration: const InputDecoration(labelText: 'Dispenser Code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dispenserLocationController,
                enabled: canManageDispensers,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _isSubmitting || !canManageDispensers
                        ? null
                        : _saveDispenser,
                    child: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : _selectedDispenserId == null
                          ? 'Create Dispenser'
                          : 'Save Changes',
                    ),
                  ),
                  if (_selectedDispenserId != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _resetDispenserForm();
                                    _feedbackMessage =
                                        'Dispenser edit cancelled.';
                                  });
                                },
                          child: const Text('Cancel Edit'),
                        ),
                        OutlinedButton(
                          onPressed: _isSubmitting || !canDeleteDispensers
                              ? null
                              : _deleteDispenser,
                          child: const Text('Delete Dispenser'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dispensers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Dispensers',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_filterItems(_dispensers).isEmpty)
                const Text('No dispensers found for this station.')
              else
                ..._filterItems(_dispensers).map(
                  (dispenser) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(dispenser['name'] as String? ?? 'Dispenser'),
                      subtitle: Text(
                        '${dispenser['code'] ?? '-'} - ${dispenser['location'] ?? 'No location'}',
                      ),
                      onTap: () => _selectDispenser(dispenser),
                    ),
                  ),
                ),
              if (selectedDispenser != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Dispenser Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Code',
                    selectedDispenser['code'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Location',
                    selectedDispenser['location'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Station',
                    _lookupName(_stations, selectedDispenser['station_id']),
                  ),
                  _buildDetailItem(
                    'Attached Nozzles',
                    _nozzles
                        .where(
                          (nozzle) =>
                              nozzle['dispenser_id'] == selectedDispenser['id'],
                        )
                        .length
                        .toString(),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNozzles() {
    final canManageNozzles = _canManageNozzles;
    final canDeleteNozzles = _canDeleteNozzles;
    final fuelTypeItems = _fuelTypes
        .map(
          (fuelType) => DropdownMenuItem<int>(
            value: fuelType['id'] as int,
            child: Text(fuelType['name'] as String? ?? 'Fuel Type'),
          ),
        )
        .toList();
    final tankItems = _tanks
        .map(
          (tank) => DropdownMenuItem<int>(
            value: tank['id'] as int,
            child: Text(tank['name'] as String? ?? 'Tank'),
          ),
        )
        .toList();
    final dispenserItems = _dispensers
        .map(
          (dispenser) => DropdownMenuItem<int>(
            value: dispenser['id'] as int,
            child: Text(dispenser['name'] as String? ?? 'Dispenser'),
          ),
        )
        .toList();

    final selectedNozzle = _selectedNozzle;
    return ResponsiveSplit(
      primary: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nozzle Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedNozzle == null)
                _buildEmptyState(
                  context,
                  'No nozzle selected yet.',
                  canManageNozzles
                      ? 'Choose a nozzle from the list to review before editing, or use the form below to create a new one.'
                      : 'Choose a nozzle from the list to inspect fuel mapping and meter context.',
                )
              else ...[
                _buildSummaryBanner(
                  context,
                  title:
                      '${selectedNozzle['code'] ?? '-'} - ${selectedNozzle['name'] ?? 'Nozzle'}',
                  subtitle:
                      '${_lookupName(_fuelTypes, selectedNozzle['fuel_type_id'])} • Meter ${_formatNumber(selectedNozzle['meter_reading'] as num?)}',
                ),
                const SizedBox(height: 12),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Tank',
                    _lookupName(_tanks, selectedNozzle['tank_id']),
                  ),
                  _buildDetailItem(
                    'Dispenser',
                    _lookupName(_dispensers, selectedNozzle['dispenser_id']),
                  ),
                  _buildDetailItem(
                    'Status',
                    selectedNozzle['is_active'] == false
                        ? 'inactive'
                        : 'active',
                  ),
                ]),
              ],
              const SizedBox(height: 18),
              Text(
                _selectedNozzleId == null ? 'Create Nozzle' : 'Edit Nozzle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (!canManageNozzles) ...[
                const SizedBox(height: 12),
                _buildPermissionNotice(
                  context,
                  'This role can review nozzles but cannot create or edit them. Meter changes still belong in Hardware.',
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _nozzleNameController,
                enabled: canManageNozzles,
                decoration: const InputDecoration(labelText: 'Nozzle Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nozzleCodeController,
                enabled: canManageNozzles,
                decoration: const InputDecoration(labelText: 'Nozzle Code'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'nozzle-fuel-${_selectedNozzleFuelTypeId ?? 'none'}',
                ),
                initialValue: _selectedNozzleFuelTypeId,
                items: fuelTypeItems,
                onChanged: canManageNozzles
                    ? (value) {
                        setState(() => _selectedNozzleFuelTypeId = value);
                      }
                    : null,
                decoration: const InputDecoration(labelText: 'Fuel Type'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'nozzle-tank-${_selectedNozzleTankId ?? 'none'}',
                ),
                initialValue: _selectedNozzleTankId,
                items: tankItems,
                onChanged: canManageNozzles
                    ? (value) {
                        setState(() => _selectedNozzleTankId = value);
                      }
                    : null,
                decoration: const InputDecoration(labelText: 'Tank'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'nozzle-dispenser-${_selectedNozzleDispenserId ?? 'none'}',
                ),
                initialValue: _selectedNozzleDispenserId,
                items: dispenserItems,
                onChanged: canManageNozzles
                    ? (value) {
                        setState(() => _selectedNozzleDispenserId = value);
                      }
                    : null,
                decoration: const InputDecoration(labelText: 'Dispenser'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nozzleMeterController,
                enabled: canManageNozzles && _selectedNozzleId == null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Opening Meter',
                  helperText: _selectedNozzleId == null
                      ? 'Used only when creating a nozzle.'
                      : 'Use the Hardware tab to adjust nozzle meters.',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: _isSubmitting || !canManageNozzles
                        ? null
                        : _saveNozzle,
                    child: Text(
                      _isSubmitting
                          ? 'Saving...'
                          : _selectedNozzleId == null
                          ? 'Create Nozzle'
                          : 'Save Changes',
                    ),
                  ),
                  if (_selectedNozzleId != null)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  setState(() {
                                    _resetNozzleForm();
                                    _feedbackMessage = 'Nozzle edit cancelled.';
                                  });
                                },
                          child: const Text('Cancel Edit'),
                        ),
                        OutlinedButton(
                          onPressed: _isSubmitting || !canDeleteNozzles
                              ? null
                              : _deleteNozzle,
                          child: const Text('Delete Nozzle'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nozzles', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Nozzles',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_filterItems(_nozzles).isEmpty)
                const Text('No nozzles found for this station.')
              else
                ..._filterItems(_nozzles).map(
                  (nozzle) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text(nozzle['name'] as String? ?? 'Nozzle'),
                      subtitle: Text(
                        '${nozzle['code'] ?? '-'} - Meter ${_formatNumber(nozzle['meter_reading'] as num?)}',
                      ),
                      trailing: Text(
                        _dispensers.firstWhere(
                                  (item) =>
                                      item['id'] == nozzle['dispenser_id'],
                                  orElse: () => const <String, dynamic>{},
                                )['name']
                                as String? ??
                            'Dispenser',
                      ),
                      onTap: () => _selectNozzle(nozzle),
                    ),
                  ),
                ),
              if (selectedNozzle != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Nozzle Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Code',
                    selectedNozzle['code'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Fuel Type',
                    _lookupName(_fuelTypes, selectedNozzle['fuel_type_id']),
                  ),
                  _buildDetailItem(
                    'Tank',
                    _lookupName(_tanks, selectedNozzle['tank_id']),
                  ),
                  _buildDetailItem(
                    'Dispenser',
                    _lookupName(_dispensers, selectedNozzle['dispenser_id']),
                  ),
                  _buildDetailItem(
                    'Meter',
                    _formatNumber(selectedNozzle['meter_reading'] as num?),
                  ),
                  _buildDetailItem(
                    'Status',
                    selectedNozzle['is_active'] == false
                        ? 'inactive'
                        : 'active',
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
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

  Widget _buildDetailWrap(List<Widget> children) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}
