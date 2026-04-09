import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          const SnackBar(content: Text('Station setup saved.')),
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
              'Station setup wizard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text('${foundation.stationName} (${foundation.stationCode})'),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(labelText: 'Display name'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _shiftMode,
                    decoration: const InputDecoration(labelText: 'Shift mode'),
                    items: const [
                      DropdownMenuItem(value: 'single_24h', child: Text('24 hour')),
                      DropdownMenuItem(value: 'two_12h', child: Text('2 x 12 hour')),
                      DropdownMenuItem(value: 'three_8h', child: Text('3 x 8 hour')),
                    ],
                    onChanged: (value) => setState(() => _shiftMode = value ?? _shiftMode),
                  ),
                ),
              ],
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
              title: 'Fuel types',
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
              title: 'Tanks',
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
              title: 'Dispensers and nozzles',
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
              label: const Text('Save station setup'),
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
          label: const Text('Add'),
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
                  selectedTankId: nozzle.tankId,
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
                          'fuel_type_id': nozzle.selectedFuelTypeId,
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
    this.selectedTankId,
    this.isActive = true,
  })  : nameController = TextEditingController(text: name),
        codeController = TextEditingController(text: code),
        meterController = TextEditingController(text: meterReading);

  final int? id;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController meterController;
  int? selectedFuelTypeId;
  int? selectedTankId;
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
                decoration: const InputDecoration(labelText: 'Fuel type name'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: draft.descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
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
                decoration: const InputDecoration(labelText: 'Tank name'),
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
            ),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<int>(
                initialValue: draft.selectedFuelTypeId,
                decoration: const InputDecoration(labelText: 'Fuel type'),
                items: [
                  for (final fuel in fuelTypes)
                    DropdownMenuItem(
                      value: fuel.id,
                      child: Text(fuel.nameController.text.isEmpty
                          ? 'Unnamed fuel'
                          : fuel.nameController.text),
                    ),
                ],
                onChanged: (value) => draft.selectedFuelTypeId = value,
              ),
            ),
            SizedBox(
              width: 160,
              child: TextField(
                controller: draft.capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Capacity'),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: draft.thresholdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Low stock threshold'),
              ),
            ),
            FilterChip(
              label: const Text('Active'),
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
                    decoration: const InputDecoration(labelText: 'Dispenser name'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: draft.codeController,
                    decoration: const InputDecoration(labelText: 'Code'),
                  ),
                ),
                FilterChip(
                  label: const Text('Active'),
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
                  label: const Text('Add nozzle'),
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
              decoration: const InputDecoration(labelText: 'Nozzle name'),
            ),
          ),
          SizedBox(
            width: 140,
            child: TextField(
              controller: draft.codeController,
              decoration: const InputDecoration(labelText: 'Code'),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: draft.selectedFuelTypeId,
              decoration: const InputDecoration(labelText: 'Fuel type'),
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
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<int>(
              initialValue: draft.selectedTankId,
              decoration: const InputDecoration(labelText: 'Tank'),
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
                onChanged();
              },
            ),
          ),
          SizedBox(
            width: 160,
            child: TextField(
              controller: draft.meterController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Start meter'),
            ),
          ),
          FilterChip(
            label: const Text('Active'),
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
