import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/app_localizations.dart';
import 'models/onboarding_models.dart';
import 'onboarding_repository.dart';

class StationSetupScreen extends ConsumerStatefulWidget {
  const StationSetupScreen({
    super.key,
    required this.stationId,
  });

  final int stationId;

  @override
  ConsumerState<StationSetupScreen> createState() => _StationSetupScreenState();
}

class _StationSetupScreenState extends ConsumerState<StationSetupScreen> {
  bool _initialized = false;
  final _displayNameController = TextEditingController();
  final _fuelTypeCountController = TextEditingController(text: '2');
  final _tankCountController = TextEditingController(text: '2');
  final _dispenserCountController = TextEditingController(text: '2');
  final _nozzlesPerDispenserController = TextEditingController(text: '2');
  String _shiftMode = 'three_8h';
  bool _hasPos = false;
  bool _hasTankers = false;
  bool _hasShops = false;
  bool _hasHardware = false;
  bool _allowMeterAdjustments = true;

  final List<_FuelTypeDraft> _fuelTypes = [];
  final List<_TankDraft> _tanks = [];
  final List<_DispenserDraft> _dispensers = [];

  @override
  void dispose() {
    _displayNameController.dispose();
    _fuelTypeCountController.dispose();
    _tankCountController.dispose();
    _dispenserCountController.dispose();
    _nozzlesPerDispenserController.dispose();
    for (final fuelType in _fuelTypes) {
      fuelType.dispose();
    }
    for (final tank in _tanks) {
      tank.dispose();
    }
    for (final dispenser in _dispensers) {
      dispenser.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final foundationAsync =
        ref.watch(stationSetupFoundationProvider(widget.stationId));
    final actionState = ref.watch(stationSetupActionProvider);

    ref.listen<OnboardingActionState>(stationSetupActionProvider, (previous, next) {
      if (!mounted) {
        return;
      }
      if (next.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.text('stationSetupSaved'))),
        );
        ref.read(stationSetupActionProvider.notifier).clearMessage();
      } else if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return foundationAsync.when(
      data: (foundation) {
        _initializeFromFoundation(foundation);
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              context.l10n.text('stationSetupTitle'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${foundation.stationName} (${foundation.stationCode})'),
            const SizedBox(height: 20),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.text('quickPlanner'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(context.l10n.text('quickPlannerHint')),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _fuelTypeCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('fuelTypeCount'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _tankCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('tankCount'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: TextField(
                            controller: _dispenserCountController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('dispenserCount'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _nozzlesPerDispenserController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.l10n.text('nozzlesPerDispenser'),
                            ),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _generateDefaults,
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: Text(context.l10n.text('generateDefaults')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _displayNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('displayName'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _shiftMode,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('shiftMode'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'single_24h',
                        child: Text(context.l10n.text('hour24')),
                      ),
                      DropdownMenuItem(
                        value: 'two_12h',
                        child: Text(context.l10n.text('twoBy12')),
                      ),
                      DropdownMenuItem(
                        value: 'three_8h',
                        child: Text(context.l10n.text('threeBy8')),
                      ),
                    ],
                    onChanged: (value) => setState(() => _shiftMode = value ?? _shiftMode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.text('startingMeterHint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _toggleChip('POS', _hasPos, (v) => setState(() => _hasPos = v)),
                _toggleChip('Tankers', _hasTankers, (v) => setState(() => _hasTankers = v)),
                _toggleChip('Shops', _hasShops, (v) => setState(() => _hasShops = v)),
                _toggleChip('Hardware', _hasHardware, (v) => setState(() => _hasHardware = v)),
                _toggleChip(
                  'Meter adjustments',
                  _allowMeterAdjustments,
                  (v) => setState(() => _allowMeterAdjustments = v),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionHeader(
              context,
              title: context.l10n.text('fuelTypes'),
              onAdd: () => setState(() => _fuelTypes.add(_FuelTypeDraft())),
            ),
            for (var index = 0; index < _fuelTypes.length; index++)
              _FuelTypeCard(
                draft: _fuelTypes[index],
                onRemove: _fuelTypes.length <= 1
                    ? null
                    : () => setState(() {
                          _fuelTypes[index].dispose();
                          _fuelTypes.removeAt(index);
                        }),
              ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              title: context.l10n.text('tanks'),
              onAdd: () => setState(() => _tanks.add(_TankDraft())),
            ),
            for (var index = 0; index < _tanks.length; index++)
              _TankCard(
                draft: _tanks[index],
                fuelTypes: _fuelTypes,
                onRemove: _tanks.length <= 1
                    ? null
                    : () => setState(() {
                          _tanks[index].dispose();
                          _tanks.removeAt(index);
                        }),
              ),
            const SizedBox(height: 20),
            _sectionHeader(
              context,
              title: context.l10n.text('dispensersAndNozzles'),
              onAdd: () => setState(() => _dispensers.add(_DispenserDraft())),
            ),
            for (var index = 0; index < _dispensers.length; index++)
              _DispenserCard(
                draft: _dispensers[index],
                fuelTypes: _fuelTypes,
                tanks: _tanks,
                onRemove: _dispensers.length <= 1
                    ? null
                    : () => setState(() {
                          _dispensers[index].dispose();
                          _dispensers.removeAt(index);
                        }),
                onChanged: () => setState(() {}),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: actionState.isSaving ? null : () => _save(foundation),
              icon: actionState.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt_outlined),
              label: Text(context.l10n.text('saveStationSetup')),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Station setup failed: $error')),
    );
  }

  FilterChip _toggleChip(String label, bool value, ValueChanged<bool> onChanged) {
    return FilterChip(label: Text(label), selected: value, onSelected: onChanged);
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    required VoidCallback onAdd,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: Text(context.l10n.text('add')),
        ),
      ],
    );
  }

  void _initializeFromFoundation(StationSetupFoundation foundation) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _displayNameController.text = foundation.stationName;
    _fuelTypeCountController.text =
        (foundation.fuelTypes.isEmpty ? 2 : foundation.fuelTypes.length).toString();
    _tankCountController.text =
        (foundation.tanks.isEmpty ? 2 : foundation.tanks.length).toString();
    _dispenserCountController.text =
        (foundation.dispensers.isEmpty ? 2 : foundation.dispensers.length).toString();
    final derivedNozzleCount = foundation.dispensers.isEmpty
        ? 2
        : foundation.dispensers
            .map((item) => item.nozzles.length)
            .reduce((value, element) => value > element ? value : element);
    _nozzlesPerDispenserController.text = derivedNozzleCount.toString();

    if (foundation.fuelTypes.isNotEmpty) {
      _fuelTypes.addAll(
        foundation.fuelTypes.map(
          (item) => _FuelTypeDraft(
            id: item.id,
            name: item.name,
            description: item.description ?? '',
          ),
        ),
      );
    } else {
      _fuelTypes.addAll([
        _FuelTypeDraft(name: 'Petrol'),
        _FuelTypeDraft(name: 'Diesel'),
      ]);
    }

    if (foundation.tanks.isNotEmpty) {
      _tanks.addAll(
        foundation.tanks.map(
          (item) => _TankDraft(
            id: item.id,
            name: item.name,
            code: item.code,
            capacity: item.capacity.toStringAsFixed(0),
            threshold: item.lowStockThreshold.toStringAsFixed(0),
            selectedFuelTypeId: item.fuelTypeId,
            selectedFuelTypeName: _fuelTypeNameById(
              foundation.fuelTypes,
              item.fuelTypeId,
            ),
            isActive: item.isActive,
          ),
        ),
      );
    } else {
      _tanks.add(_TankDraft(name: 'Tank 1', code: 'T1', capacity: '0'));
    }

    if (foundation.dispensers.isNotEmpty) {
      _dispensers.addAll(
        foundation.dispensers.map((item) {
          final draft = _DispenserDraft(
            id: item.id,
            name: item.name,
            code: item.code,
            isActive: item.isActive,
          );
          if (item.nozzles.isNotEmpty) {
            draft.nozzles.addAll(
              item.nozzles.map(
                (nozzle) => _NozzleDraft(
                  id: nozzle.id,
                  name: nozzle.name,
                  code: nozzle.code,
                  selectedFuelTypeId: nozzle.fuelTypeId,
                  selectedFuelTypeName: _fuelTypeNameById(
                    foundation.fuelTypes,
                    nozzle.fuelTypeId,
                  ),
                  selectedTankId: nozzle.tankId,
                  selectedTankCode: _tankCodeById(
                    foundation.tanks,
                    nozzle.tankId,
                  ),
                  meterReading: nozzle.meterReading.toStringAsFixed(0),
                  isActive: nozzle.isActive,
                ),
              ),
            );
          } else {
            draft.nozzles.add(_NozzleDraft());
          }
          return draft;
        }),
      );
    } else {
      _dispensers.add(_DispenserDraft());
    }
  }

  void _generateDefaults() {
    final fuelTypeCount = int.tryParse(_fuelTypeCountController.text) ?? 2;
    final tankCount = int.tryParse(_tankCountController.text) ?? 2;
    final dispenserCount = int.tryParse(_dispenserCountController.text) ?? 2;
    final nozzleCount = int.tryParse(_nozzlesPerDispenserController.text) ?? 2;

    for (final fuelType in _fuelTypes) {
      fuelType.dispose();
    }
    for (final tank in _tanks) {
      tank.dispose();
    }
    for (final dispenser in _dispensers) {
      dispenser.dispose();
    }
    _fuelTypes.clear();
    _tanks.clear();
    _dispensers.clear();

    const defaults = ['Petrol', 'Diesel', 'High Octane', 'AdBlue', 'Kerosene'];
    for (var index = 0; index < fuelTypeCount; index++) {
      _fuelTypes.add(
        _FuelTypeDraft(name: index < defaults.length ? defaults[index] : 'Fuel ${index + 1}'),
      );
    }
    for (var index = 0; index < tankCount; index++) {
      _tanks.add(
        _TankDraft(
          name: 'Tank ${index + 1}',
          code: 'T${index + 1}',
          capacity: '0',
          selectedFuelTypeId: _resolveFuelTypeIdForIndex(index),
          selectedFuelTypeName: _resolveFuelTypeNameForIndex(index),
        ),
      );
    }
    for (var dispenserIndex = 0; dispenserIndex < dispenserCount; dispenserIndex++) {
      final draft = _DispenserDraft(
        name: 'Dispenser ${dispenserIndex + 1}',
        code: 'D${dispenserIndex + 1}',
      );
      draft.nozzles.clear();
      for (var nozzleIndex = 0; nozzleIndex < nozzleCount; nozzleIndex++) {
        final mappingIndex = dispenserIndex * nozzleCount + nozzleIndex;
        draft.nozzles.add(
          _NozzleDraft(
            name: 'Nozzle ${nozzleIndex + 1}',
            code: 'D${dispenserIndex + 1}-N${nozzleIndex + 1}',
            selectedFuelTypeId: _resolveFuelTypeIdForIndex(mappingIndex),
            selectedFuelTypeName: _resolveFuelTypeNameForIndex(mappingIndex),
            selectedTankId: _resolveTankIdForIndex(mappingIndex),
            selectedTankCode: _resolveTankCodeForIndex(mappingIndex),
            meterReading: '0',
          ),
        );
      }
      _dispensers.add(draft);
    }
    setState(() {});
  }

  int? _resolveFuelTypeIdForIndex(int index) {
    if (_fuelTypes.isEmpty) return null;
    final draft = _fuelTypes[index % _fuelTypes.length];
    return draft.id;
  }

  int? _resolveTankIdForIndex(int index) {
    if (_tanks.isEmpty) return null;
    final draft = _tanks[index % _tanks.length];
    return draft.id;
  }

  String? _resolveFuelTypeNameForIndex(int index) {
    if (_fuelTypes.isEmpty) return null;
    return _fuelTypes[index % _fuelTypes.length].nameController.text.trim();
  }

  String? _resolveTankCodeForIndex(int index) {
    if (_tanks.isEmpty) return null;
    return _tanks[index % _tanks.length].codeController.text.trim();
  }

  String? _fuelTypeNameById(List<StationFuelTypeItem> fuelTypes, int fuelTypeId) {
    for (final fuel in fuelTypes) {
      if (fuel.id == fuelTypeId) {
        return fuel.name;
      }
    }
    return null;
  }

  String? _tankCodeById(List<StationTankItem> tanks, int tankId) {
    for (final tank in tanks) {
      if (tank.id == tankId) {
        return tank.code;
      }
    }
    return null;
  }

  Future<void> _save(StationSetupFoundation foundation) async {
    await ref.read(stationSetupActionProvider.notifier).submit(
          stationId: widget.stationId,
          organizationId: foundation.organizationId,
          displayName: _displayNameController.text.trim().isEmpty
              ? null
              : _displayNameController.text.trim(),
          shiftMode: _shiftMode,
          hasPos: _hasPos,
          hasTankers: _hasTankers,
          hasShops: _hasShops,
          hasHardware: _hasHardware,
          allowMeterAdjustments: _allowMeterAdjustments,
          fuelTypes: _fuelTypes
              .map(
                (item) => {
                  if (item.id != null) 'id': item.id,
                  'name': item.nameController.text.trim(),
                  'description': item.descriptionController.text.trim().isEmpty
                      ? null
                      : item.descriptionController.text.trim(),
                },
              )
              .toList(),
          tanks: _tanks
              .map(
                (item) => {
                  if (item.id != null) 'id': item.id,
                  'name': item.nameController.text.trim(),
                  'code': item.codeController.text.trim(),
                  'fuel_type_id': item.selectedFuelTypeId,
                  if (item.selectedFuelTypeId == null &&
                      item.selectedFuelTypeName != null)
                    'fuel_type_name': item.selectedFuelTypeName,
                  'capacity': double.tryParse(item.capacityController.text) ?? 0,
                  'low_stock_threshold':
                      double.tryParse(item.thresholdController.text) ?? 1000,
                  'is_active': item.isActive,
                },
              )
              .toList(),
          dispensers: _dispensers
              .map(
                (item) => {
                  if (item.id != null) 'id': item.id,
                  'name': item.nameController.text.trim(),
                  'code': item.codeController.text.trim(),
                  'is_active': item.isActive,
                  'nozzles': item.nozzles
                      .map(
                        (nozzle) => {
                          if (nozzle.id != null) 'id': nozzle.id,
                          'name': nozzle.nameController.text.trim(),
                          'code': nozzle.codeController.text.trim(),
                          'tank_id': nozzle.selectedTankId,
                          if (nozzle.selectedTankId == null &&
                              nozzle.selectedTankCode != null)
                            'tank_code': nozzle.selectedTankCode,
                          'fuel_type_id': nozzle.selectedFuelTypeId,
                          if (nozzle.selectedFuelTypeId == null &&
                              nozzle.selectedFuelTypeName != null)
                            'fuel_type_name': nozzle.selectedFuelTypeName,
                          'meter_reading':
                              double.tryParse(nozzle.meterController.text) ?? 0,
                          'is_active': nozzle.isActive,
                        },
                      )
                      .toList(),
                },
              )
              .toList(),
        );
  }
}

class _FuelTypeDraft {
  _FuelTypeDraft({
    this.id,
    String name = '',
    String description = '',
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController descriptionController;

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
  }
}

class _TankDraft {
  _TankDraft({
    this.id,
    String name = '',
    String code = '',
    String capacity = '',
    String threshold = '1000',
    this.selectedFuelTypeId,
    this.selectedFuelTypeName,
    this.isActive = true,
  })  : nameController = TextEditingController(text: name),
        codeController = TextEditingController(text: code),
        capacityController = TextEditingController(text: capacity),
        thresholdController = TextEditingController(text: threshold);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController capacityController;
  final TextEditingController thresholdController;
  int? selectedFuelTypeId;
  String? selectedFuelTypeName;
  bool isActive;

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    capacityController.dispose();
    thresholdController.dispose();
  }
}

class _NozzleDraft {
  _NozzleDraft({
    this.id,
    String name = '',
    String code = '',
    String meterReading = '0',
    this.selectedFuelTypeId,
    this.selectedFuelTypeName,
    this.selectedTankId,
    this.selectedTankCode,
    this.isActive = true,
  })  : nameController = TextEditingController(text: name),
        codeController = TextEditingController(text: code),
        meterController = TextEditingController(text: meterReading);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController meterController;
  int? selectedFuelTypeId;
  String? selectedFuelTypeName;
  int? selectedTankId;
  String? selectedTankCode;
  bool isActive;

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    meterController.dispose();
  }
}

class _DispenserDraft {
  _DispenserDraft({
    this.id,
    String name = '',
    String code = '',
    this.isActive = true,
  })  : nameController = TextEditingController(text: name),
        codeController = TextEditingController(text: code);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final List<_NozzleDraft> nozzles = [_NozzleDraft()];
  bool isActive;

  void dispose() {
    nameController.dispose();
    codeController.dispose();
    for (final nozzle in nozzles) {
      nozzle.dispose();
    }
  }
}

class _FuelTypeCard extends StatelessWidget {
  const _FuelTypeCard({required this.draft, this.onRemove});

  final _FuelTypeDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: draft.nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.text('fuelTypeName'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: draft.descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.text('description'),
                ),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 12),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TankCard extends StatelessWidget {
  const _TankCard({
    required this.draft,
    required this.fuelTypes,
    this.onRemove,
  });

  final _TankDraft draft;
  final List<_FuelTypeDraft> fuelTypes;
  final VoidCallback? onRemove;

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
              width: 200,
              child: TextField(
                controller: draft.nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.text('tankName'),
                ),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.codeController,
                decoration: InputDecoration(labelText: context.l10n.text('code')),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                initialValue: draft.selectedFuelTypeId,
                decoration: InputDecoration(
                  labelText: context.l10n.text('fuelType'),
                ),
                items: [
                  for (final fuel in fuelTypes)
                    DropdownMenuItem(
                      value: fuel.id,
                      child: Text(fuel.nameController.text.isEmpty
                          ? 'Unnamed fuel'
                          : fuel.nameController.text),
                    ),
                ],
                onChanged: (value) {
                  draft.selectedFuelTypeId = value;
                  draft.selectedFuelTypeName = fuelTypes
                      .where((fuel) => fuel.id == value)
                      .map((fuel) => fuel.nameController.text)
                      .cast<String?>()
                      .firstWhere((_) => true, orElse: () => null);
                },
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.capacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.text('capacity'),
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: draft.thresholdController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.l10n.text('lowStockThreshold'),
                ),
              ),
            ),
            FilterChip(
              label: Text(context.l10n.text('active')),
              selected: draft.isActive,
              onSelected: (value) => draft.isActive = value,
            ),
            if (onRemove != null)
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
          ],
        ),
      ),
    );
  }
}

class _DispenserCard extends StatelessWidget {
  const _DispenserCard({
    required this.draft,
    required this.fuelTypes,
    required this.tanks,
    required this.onChanged,
    this.onRemove,
  });

  final _DispenserDraft draft;
  final List<_FuelTypeDraft> fuelTypes;
  final List<_TankDraft> tanks;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: draft.nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('dispenserName'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: draft.codeController,
                    decoration: InputDecoration(labelText: context.l10n.text('code')),
                  ),
                ),
                FilterChip(
                  label: Text(context.l10n.text('active')),
                  selected: draft.isActive,
                  onSelected: (value) {
                    draft.isActive = value;
                    onChanged();
                  },
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    draft.nozzles.add(_NozzleDraft());
                    onChanged();
                  },
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.text('addNozzle')),
                ),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < draft.nozzles.length; index++)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _NozzleCard(
                  draft: draft.nozzles[index],
                  fuelTypes: fuelTypes,
                  tanks: tanks,
                  onChanged: onChanged,
                  onRemove: draft.nozzles.length <= 1
                      ? null
                      : () {
                          draft.nozzles[index].dispose();
                          draft.nozzles.removeAt(index);
                          onChanged();
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NozzleCard extends StatelessWidget {
  const _NozzleCard({
    required this.draft,
    required this.fuelTypes,
    required this.tanks,
    required this.onChanged,
    this.onRemove,
  });

  final _NozzleDraft draft;
  final List<_FuelTypeDraft> fuelTypes;
  final List<_TankDraft> tanks;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD5CBB8)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 180,
            child: TextField(
              controller: draft.nameController,
              decoration: InputDecoration(
                labelText: context.l10n.text('nozzleName'),
              ),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: draft.codeController,
              decoration: InputDecoration(labelText: context.l10n.text('code')),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: draft.selectedFuelTypeId,
              decoration: InputDecoration(
                labelText: context.l10n.text('fuelType'),
              ),
              items: [
                for (final fuel in fuelTypes)
                  DropdownMenuItem(
                    value: fuel.id,
                    child: Text(fuel.nameController.text.isEmpty
                        ? 'Unnamed fuel'
                        : fuel.nameController.text),
                  ),
              ],
              onChanged: (value) {
                draft.selectedFuelTypeId = value;
                draft.selectedFuelTypeName = fuelTypes
                    .where((fuel) => fuel.id == value)
                    .map((fuel) => fuel.nameController.text)
                    .cast<String?>()
                    .firstWhere((_) => true, orElse: () => null);
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: draft.selectedTankId,
              decoration: InputDecoration(labelText: context.l10n.text('tank')),
              items: [
                for (final tank in tanks)
                  DropdownMenuItem(
                    value: tank.id,
                    child: Text(tank.nameController.text.isEmpty
                        ? 'Unnamed tank'
                        : tank.nameController.text),
                  ),
              ],
              onChanged: (value) {
                draft.selectedTankId = value;
                draft.selectedTankCode = tanks
                    .where((tank) => tank.id == value)
                    .map((tank) => tank.codeController.text)
                    .cast<String?>()
                    .firstWhere((_) => true, orElse: () => null);
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: draft.meterController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.text('startingMeter'),
              ),
            ),
          ),
          FilterChip(
            label: Text(context.l10n.text('active')),
            selected: draft.isActive,
            onSelected: (value) {
              draft.isActive = value;
              onChanged();
            },
          ),
          if (onRemove != null)
            IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}
