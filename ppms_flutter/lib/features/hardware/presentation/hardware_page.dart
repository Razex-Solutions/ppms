import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _HardwareSection { devices, events, meterOps }

class HardwarePage extends StatefulWidget {
  const HardwarePage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<HardwarePage> createState() => _HardwarePageState();
}

class _HardwarePageState extends State<HardwarePage> {
  final _deviceNameController = TextEditingController();
  final _deviceCodeController = TextEditingController();
  final _deviceIdentifierController = TextEditingController();
  final _meterReadingController = TextEditingController(text: '0');
  final _meterReasonController = TextEditingController();
  final _simulatedMeterController = TextEditingController(text: '0');
  final _simulatedVolumeController = TextEditingController(text: '0');
  final _tankProbeVolumeController = TextEditingController(text: '0');

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _HardwareSection _section = _HardwareSection.devices;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _dispensers = const [];
  List<Map<String, dynamic>> _tanks = const [];
  List<Map<String, dynamic>> _nozzles = const [];
  List<Map<String, dynamic>> _devices = const [];
  List<Map<String, dynamic>> _events = const [];
  List<Map<String, dynamic>> _adjustments = const [];

  int? _selectedStationId;
  int? _selectedDeviceId;
  int? _selectedDispenserId;
  int? _selectedTankId;
  int? _selectedNozzleId;
  String _deviceType = 'dispenser_controller';

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _deviceNameController.dispose();
    _deviceCodeController.dispose();
    _deviceIdentifierController.dispose();
    _meterReadingController.dispose();
    _meterReasonController.dispose();
    _simulatedMeterController.dispose();
    _simulatedVolumeController.dispose();
    _tankProbeVolumeController.dispose();
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

      final dispensers = !_showHardwareWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchDispensers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final tanks = !_showHardwareWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTanks(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final nozzles = !_showHardwareWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNozzles(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final devices = !_showHardwareWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchHardwareDevices(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final events = !_showHardwareWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchHardwareEvents(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      final nozzleId = _selectedNozzleId ?? _firstId(nozzles);
      final adjustments = !_showHardwareWorkspace || nozzleId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNozzleAdjustments(
                nozzleId: nozzleId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) return;

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _dispensers = dispensers;
        _tanks = tanks;
        _nozzles = nozzles;
        _devices = devices;
        _events = events;
        _selectedDeviceId = _selectedDeviceId ?? _firstId(devices);
        _selectedDispenserId = _selectedDispenserId ?? _firstId(dispensers);
        _selectedTankId = _selectedTankId ?? _firstId(tanks);
        _selectedNozzleId = nozzleId;
        _adjustments = adjustments;
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

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
      _selectedDeviceId = null;
      _selectedDispenserId = null;
      _selectedTankId = null;
      _selectedNozzleId = null;
    });
    await _loadWorkspace();
  }

  Future<void> _createDevice() async {
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
      final payload = <String, dynamic>{
        'name': _deviceNameController.text.trim(),
        'code': _deviceCodeController.text.trim(),
        'device_type': _deviceType,
        'integration_mode': 'simulated',
        'device_identifier': _emptyToNull(_deviceIdentifierController.text),
        'station_id': stationId,
      };
      if (_deviceType == 'dispenser_controller' &&
          _selectedDispenserId != null) {
        payload['dispenser_id'] = _selectedDispenserId;
      }
      if (_deviceType == 'tank_probe' && _selectedTankId != null) {
        payload['tank_id'] = _selectedTankId;
      }

      final device = await widget.sessionController.createHardwareDevice(
        payload,
      );
      if (!mounted) return;

      _deviceNameController.clear();
      _deviceCodeController.clear();
      _deviceIdentifierController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Hardware device ${device['name']} created.';
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

  Future<void> _adjustMeter() async {
    final nozzleId = _selectedNozzleId;
    if (nozzleId == null) {
      setState(() {
        _feedbackMessage = 'Select a nozzle first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final adjustment = await widget.sessionController.adjustNozzleMeter(
        nozzleId: nozzleId,
        payload: {
          'new_reading': double.parse(_meterReadingController.text.trim()),
          'reason': _meterReasonController.text.trim(),
        },
      );
      if (!mounted) return;
      _meterReasonController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Nozzle meter adjusted to ${_formatNumber(adjustment['new_reading'])}.';
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

  Future<void> _simulateDispenser() async {
    final deviceId = _selectedDeviceId;
    final nozzleId = _selectedNozzleId;
    if (deviceId == null || nozzleId == null) {
      setState(() {
        _feedbackMessage = 'Select a dispenser-side device and nozzle first.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final event = await widget.sessionController.simulateDispenserReading({
        'device_id': deviceId,
        'nozzle_id': nozzleId,
        'meter_reading': double.parse(_simulatedMeterController.text.trim()),
        'volume': double.parse(_simulatedVolumeController.text.trim()),
      });
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Simulated dispenser event #${event['id']} recorded.';
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

  Future<void> _simulateTankProbe() async {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      setState(() {
        _feedbackMessage = 'Select a hardware device first.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final event = await widget.sessionController.simulateTankProbeReading({
        'device_id': deviceId,
        'volume': double.parse(_tankProbeVolumeController.text.trim()),
      });
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Simulated tank probe event #${event['id']} recorded.';
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

  Future<void> _pollSelectedDevice() async {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) {
      setState(() {
        _feedbackMessage = 'Select a hardware device first.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final event = await widget.sessionController.pollHardwareDevice(
        deviceId: deviceId,
      );
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Vendor poll completed with event #${event['id']}.';
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

  bool _hasAction(String module, String action) {
    final modulePermissions =
        widget.sessionController.permissions[module] as List<dynamic>?;
    if (modulePermissions == null) {
      return false;
    }
    return modulePermissions.contains(action);
  }

  bool get _canReadHardware => _hasAction('hardware', 'read');
  bool get _canManageHardware =>
      _hasAction('hardware', 'create') || _hasAction('hardware', 'update');
  bool get _canAdjustMeters => _hasAction('nozzles', 'adjust_meter');
  bool get _canReadMeterHistory =>
      _hasAction('nozzles', 'read_meter_history') || _canAdjustMeters;
  bool get _showHardwareWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['hardware'],
    permissionModules: const ['hardware', 'nozzles'],
    hideWhenModulesOff: true,
  );

  Map<String, String> _sectionMeta(_HardwareSection section) {
    switch (section) {
      case _HardwareSection.devices:
        return const {
          'title': 'Device Control',
          'subtitle':
              'Register controllers and probes, keep the station hardware list current, and trigger live polls from here.',
        };
      case _HardwareSection.events:
        return const {
          'title': 'Hardware Timeline',
          'subtitle':
              'Review the most recent telemetry and hardware-side activity without jumping into raw logs.',
        };
      case _HardwareSection.meterOps:
        return const {
          'title': 'Meter Operations',
          'subtitle':
              'Handle meter adjustments, meter history, and controlled simulation flows from one operational panel.',
        };
    }
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
    if (!_showHardwareWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Hardware and meter operations are turned off for this scope, so this workspace stays hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableSections = <_HardwareSection>[
      if (_canReadHardware) _HardwareSection.devices,
      if (_canReadHardware) _HardwareSection.events,
      if (_canReadMeterHistory || _canAdjustMeters) _HardwareSection.meterOps,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }
    final sectionMeta = _sectionMeta(_section);
    final activeDevices = _devices
        .where((device) => device['status'] == 'active')
        .length;
    final recentEvents = _events.length;
    final linkedNozzles = _nozzles.length;
    final recentAdjustments = _adjustments.length;

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Field Devices',
            title: availableSections.isEmpty
                ? 'Hardware Access'
                : 'Hardware Operations Board',
            subtitle: availableSections.isEmpty
                ? 'This role does not currently have hardware or meter-operation access for the selected scope.'
                : sectionMeta['subtitle']!,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                DashboardMetricTile(
                  label: 'Devices',
                  value: '${_devices.length}',
                  caption: '$activeDevices active',
                  icon: Icons.memory_outlined,
                ),
                DashboardMetricTile(
                  label: 'Recent Events',
                  value: '$recentEvents',
                  caption: 'Loaded hardware timeline',
                  icon: Icons.timeline_outlined,
                ),
                DashboardMetricTile(
                  label: 'Nozzles',
                  value: '$linkedNozzles',
                  caption: 'Available for meter ops',
                  icon: Icons.local_gas_station_outlined,
                ),
                DashboardMetricTile(
                  label: 'Adjustments',
                  value: '$recentAdjustments',
                  caption: 'Current nozzle history',
                  icon: Icons.speed_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: sectionMeta['title']!,
            subtitle:
                'This workspace keeps hardware registration, live telemetry review, and meter-side actions in one place so station support stays practical.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildInfoChip(
                  context,
                  icon: Icons.store_outlined,
                  label: _selectedStationId == null
                      ? 'No station selected'
                      : 'Station #$_selectedStationId',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.usb_outlined,
                  label: '${_devices.length} registered devices',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.sensors_outlined,
                  label: _canManageHardware
                      ? 'Device actions enabled'
                      : 'Read-only device access',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.tune_outlined,
                  label: _canAdjustMeters
                      ? 'Meter controls enabled'
                      : (_canReadMeterHistory
                            ? 'Meter history only'
                            : 'No meter controls'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    availableSections.isEmpty
                        ? 'This role does not currently have access to hardware or meter operations.'
                        : 'Manage hardware devices, inspect recent events, and run nozzle meter operations.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (availableSections.isEmpty) ...[
                    _buildPermissionNotice(
                      context,
                      'Ask an administrator for hardware or nozzle meter permissions if this workspace should be available.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'hardware-station-${_selectedStationId ?? 'none'}',
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
                          onChanged: availableSections.isEmpty
                              ? null
                              : _changeStation,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (availableSections.isNotEmpty)
                        Expanded(
                          child: SegmentedButton<_HardwareSection>(
                            segments: [
                              if (_canReadHardware)
                                const ButtonSegment(
                                  value: _HardwareSection.devices,
                                  label: Text('Devices'),
                                  icon: Icon(Icons.memory_outlined),
                                ),
                              if (_canReadHardware)
                                const ButtonSegment(
                                  value: _HardwareSection.events,
                                  label: Text('Events'),
                                  icon: Icon(Icons.timeline_outlined),
                                ),
                              if (_canReadMeterHistory || _canAdjustMeters)
                                const ButtonSegment(
                                  value: _HardwareSection.meterOps,
                                  label: Text('Meter Ops'),
                                  icon: Icon(Icons.speed_outlined),
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
                  if (_section == _HardwareSection.devices)
                    _buildDevices(context)
                  else if (_section == _HardwareSection.events)
                    _buildEvents(context)
                  else
                    _buildMeterOps(context),
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

  Widget _buildDevices(BuildContext context) {
    final canManageHardware = _canManageHardware;
    return ResponsiveSplit(
      breakpoint: 1180,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register Device',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!canManageHardware) ...[
            const SizedBox(height: 12),
            _buildPermissionNotice(
              context,
              'This role can review hardware devices but cannot register or poll them.',
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _deviceNameController,
            enabled: canManageHardware,
            decoration: const InputDecoration(labelText: 'Device Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deviceCodeController,
            enabled: canManageHardware,
            decoration: const InputDecoration(labelText: 'Device Code'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('hardware-type-$_deviceType'),
            initialValue: _deviceType,
            decoration: const InputDecoration(labelText: 'Device Type'),
            items: const [
              DropdownMenuItem(
                value: 'dispenser_controller',
                child: Text('Dispenser Controller'),
              ),
              DropdownMenuItem(value: 'tank_probe', child: Text('Tank Probe')),
            ],
            onChanged: canManageHardware
                ? (value) {
                    setState(() {
                      _deviceType = value ?? 'dispenser_controller';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          if (_deviceType == 'dispenser_controller')
            DropdownButtonFormField<int>(
              key: ValueKey<String>(
                'hardware-dispenser-${_selectedDispenserId ?? 'none'}',
              ),
              initialValue: _selectedDispenserId,
              decoration: const InputDecoration(labelText: 'Dispenser'),
              items: [
                for (final dispenser in _dispensers)
                  DropdownMenuItem<int>(
                    value: dispenser['id'] as int,
                    child: Text('${dispenser['code']} - ${dispenser['name']}'),
                  ),
              ],
              onChanged: canManageHardware
                  ? (value) {
                      setState(() {
                        _selectedDispenserId = value;
                      });
                    }
                  : null,
            ),
          if (_deviceType == 'tank_probe')
            DropdownButtonFormField<int>(
              key: ValueKey<String>(
                'hardware-tank-${_selectedTankId ?? 'none'}',
              ),
              initialValue: _selectedTankId,
              decoration: const InputDecoration(labelText: 'Tank'),
              items: [
                for (final tank in _tanks)
                  DropdownMenuItem<int>(
                    value: tank['id'] as int,
                    child: Text('${tank['code']} - ${tank['name']}'),
                  ),
              ],
              onChanged: canManageHardware
                  ? (value) {
                      setState(() {
                        _selectedTankId = value;
                      });
                    }
                  : null,
            ),
          if (_deviceType == 'dispenser_controller' ||
              _deviceType == 'tank_probe')
            const SizedBox(height: 12),
          TextFormField(
            controller: _deviceIdentifierController,
            enabled: canManageHardware,
            decoration: const InputDecoration(
              labelText: 'Device Identifier (optional)',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _isSubmitting || !canManageHardware
                    ? null
                    : _createDevice,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: const Text('Create Device'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _isSubmitting || !canManageHardware
                    ? null
                    : _pollSelectedDevice,
                icon: const Icon(Icons.sync_outlined),
                label: const Text('Poll Selected'),
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
              Text('Devices', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_devices.isEmpty)
                const Text('No hardware devices registered yet.')
              else
                for (final device in _devices)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: device['id'] == _selectedDeviceId,
                    title: Text('${device['code']} - ${device['name']}'),
                    subtitle: Text(
                      '${device['device_type']} • ${device['status']} • ${device['integration_mode']}',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedDeviceId = device['id'] as int;
                      });
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvents(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Hardware Events',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_events.isEmpty)
              const Text('No hardware events recorded yet.')
            else
              for (final event in _events)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${event['event_type']} • ${event['status']} • device ${event['device_id']}',
                  ),
                  subtitle: Text(
                    '${_formatDateTime(event['recorded_at'])}'
                    '${event['meter_reading'] != null ? ' • meter ${_formatNumber(event['meter_reading'])}' : ''}'
                    '${event['volume'] != null ? ' • volume ${_formatNumber(event['volume'])}' : ''}',
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeterOps(BuildContext context) {
    final canAdjustMeters = _canAdjustMeters;
    final canReadMeterHistory = _canReadMeterHistory;
    final canManageHardware = _canManageHardware;
    return ResponsiveSplit(
      breakpoint: 1180,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nozzle Meter Operations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!canAdjustMeters) ...[
            const SizedBox(height: 12),
            _buildPermissionNotice(
              context,
              canReadMeterHistory
                  ? 'This role can review meter history but cannot post adjustments or simulations.'
                  : 'This role does not currently have meter-operation permissions.',
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'hardware-nozzle-${_selectedNozzleId ?? 'none'}',
            ),
            initialValue: _selectedNozzleId,
            decoration: const InputDecoration(labelText: 'Nozzle'),
            items: [
              for (final nozzle in _nozzles)
                DropdownMenuItem<int>(
                  value: nozzle['id'] as int,
                  child: Text('${nozzle['code']} - ${nozzle['name']}'),
                ),
            ],
            onChanged: canReadMeterHistory || canAdjustMeters
                ? (value) async {
                    setState(() {
                      _selectedNozzleId = value;
                    });
                    await _loadWorkspace();
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _meterReadingController,
            enabled: canAdjustMeters,
            decoration: const InputDecoration(labelText: 'New Meter Reading'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _meterReasonController,
            enabled: canAdjustMeters,
            decoration: const InputDecoration(labelText: 'Adjustment Reason'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting || !canAdjustMeters ? null : _adjustMeter,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.tune_outlined),
            label: const Text('Adjust Meter'),
          ),
          const SizedBox(height: 24),
          Text('Simulation', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _simulatedMeterController,
            enabled: canManageHardware,
            decoration: const InputDecoration(
              labelText: 'Simulated Meter Reading',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _simulatedVolumeController,
            enabled: canManageHardware,
            decoration: const InputDecoration(labelText: 'Simulated Volume'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankProbeVolumeController,
            enabled: canManageHardware,
            decoration: const InputDecoration(labelText: 'Tank Probe Volume'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _isSubmitting || !canManageHardware
                    ? null
                    : _simulateDispenser,
                icon: const Icon(Icons.sensors_outlined),
                label: const Text('Simulate Dispenser'),
              ),
              const SizedBox(width: 12),
              FilledButton.tonalIcon(
                onPressed: _isSubmitting || !canManageHardware
                    ? null
                    : _simulateTankProbe,
                icon: const Icon(Icons.waterfall_chart_outlined),
                label: const Text('Simulate Tank Probe'),
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
              Text(
                'Recent Meter Adjustments',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (!canReadMeterHistory)
                const Text('No meter-history access for this role.')
              else if (_adjustments.isEmpty)
                const Text('No meter adjustments found for this nozzle yet.')
              else
                for (final adjustment in _adjustments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${_formatNumber(adjustment['old_reading'])} → ${_formatNumber(adjustment['new_reading'])}',
                    ),
                    subtitle: Text(
                      '${adjustment['reason']} • ${_formatDateTime(adjustment['adjusted_at'])}',
                    ),
                  ),
            ],
          ),
        ),
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

  String _formatNumber(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return '0.00';
  }

  String _formatDateTime(dynamic value) {
    if (value is! String || value.isEmpty) return 'Unknown';
    return value.replaceFirst('T', ' ').substring(0, 16);
  }
}
