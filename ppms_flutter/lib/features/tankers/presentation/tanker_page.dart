import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _TankerSection { tankers, trips, tripOps }

class TankerPage extends StatefulWidget {
  const TankerPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<TankerPage> createState() => _TankerPageState();
}

class _TankerPageState extends State<TankerPage> {
  final _tankerRegistrationController = TextEditingController();
  final _tankerNameController = TextEditingController();
  final _tankerCapacityController = TextEditingController();
  final _tankerOwnerNameController = TextEditingController();
  final _tankerDriverNameController = TextEditingController();
  final _tankerDriverPhoneController = TextEditingController();
  final _tripDestinationController = TextEditingController();
  final _tripNotesController = TextEditingController();
  final _deliveryDestinationController = TextEditingController();
  final _deliveryQuantityController = TextEditingController();
  final _deliveryFuelRateController = TextEditingController();
  final _deliveryChargeController = TextEditingController(text: '0');
  final _deliveryPaidAmountController = TextEditingController(text: '0');
  final _expenseTypeController = TextEditingController(text: 'driver');
  final _expenseAmountController = TextEditingController();
  final _expenseNotesController = TextEditingController();
  final _completeReasonController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _TankerSection _section = _TankerSection.tankers;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _tanks = const [];
  List<Map<String, dynamic>> _tankers = const [];
  List<Map<String, dynamic>> _trips = const [];

  int? _selectedStationId;
  int? _selectedTankerId;
  int? _selectedTripId;
  int? _selectedFuelTypeId;
  int? _selectedSupplierId;
  int? _selectedLinkedTankId;
  int? _selectedDeliveryCustomerId;
  String _tankerOwnershipType = 'owned';
  String _tripType = 'supplier_to_station';
  String _tripStatusFilter = 'all';
  String _deliverySaleType = 'cash';

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _tankerRegistrationController.dispose();
    _tankerNameController.dispose();
    _tankerCapacityController.dispose();
    _tankerOwnerNameController.dispose();
    _tankerDriverNameController.dispose();
    _tankerDriverPhoneController.dispose();
    _tripDestinationController.dispose();
    _tripNotesController.dispose();
    _deliveryDestinationController.dispose();
    _deliveryQuantityController.dispose();
    _deliveryFuelRateController.dispose();
    _deliveryChargeController.dispose();
    _deliveryPaidAmountController.dispose();
    _expenseTypeController.dispose();
    _expenseAmountController.dispose();
    _expenseNotesController.dispose();
    _completeReasonController.dispose();
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

      final suppliers = _showTankerWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchSuppliers()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final customers = !_showTankerWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final fuelTypes = _showTankerWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchFuelTypes()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final tanks = !_showTankerWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTanks(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final tankers = !_showTankerWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTankers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final trips = !_showTankerWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTankerTrips(
                stationId: stationId,
                status: _tripStatusFilter == 'all' ? null : _tripStatusFilter,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) return;

      final selectedTankerId = _resolveSelectedId(_selectedTankerId, tankers);
      final selectedTripId = _resolveSelectedId(_selectedTripId, trips);
      final selectedSupplierId = _resolveSelectedId(
        _selectedSupplierId,
        suppliers,
      );
      final selectedDeliveryCustomerId = _resolveSelectedId(
        _selectedDeliveryCustomerId,
        customers,
      );
      final selectedLinkedTankId = _resolveSelectedId(
        _selectedLinkedTankId,
        tanks,
      );

      int? selectedFuelTypeId = _resolveSelectedId(
        _selectedFuelTypeId,
        fuelTypes,
      );
      if (selectedFuelTypeId == null && selectedLinkedTankId != null) {
        final linkedTank = tanks.cast<Map<String, dynamic>?>().firstWhere(
          (tank) => tank?['id'] == selectedLinkedTankId,
          orElse: () => null,
        );
        selectedFuelTypeId = linkedTank?['fuel_type_id'] as int?;
      }

      setState(() {
        _stations = stations;
        _suppliers = suppliers;
        _customers = customers;
        _fuelTypes = fuelTypes;
        _tanks = tanks;
        _tankers = tankers;
        _trips = trips;
        _selectedStationId = stationId;
        _selectedTankerId = selectedTankerId;
        _selectedTripId = selectedTripId;
        _selectedSupplierId = selectedSupplierId;
        _selectedDeliveryCustomerId = selectedDeliveryCustomerId;
        _selectedLinkedTankId = selectedLinkedTankId;
        _selectedFuelTypeId = selectedFuelTypeId;
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
      _selectedTankerId = null;
      _selectedTripId = null;
      _selectedSupplierId = null;
      _selectedDeliveryCustomerId = null;
      _selectedLinkedTankId = null;
      _selectedFuelTypeId = null;
    });
    await _loadWorkspace();
  }

  Future<void> _changeTripStatus(String? status) async {
    setState(() {
      _tripStatusFilter = status ?? 'all';
    });
    await _loadWorkspace();
  }

  Future<void> _createTanker() async {
    final stationId = _selectedStationId;
    final fuelTypeId = _selectedFuelTypeId;
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
      final tanker = await widget.sessionController.createTanker({
        'registration_no': _tankerRegistrationController.text.trim(),
        'name': _tankerNameController.text.trim(),
        'capacity': double.parse(_tankerCapacityController.text.trim()),
        'ownership_type': _tankerOwnershipType,
        'owner_name': _emptyToNull(_tankerOwnerNameController.text),
        'driver_name': _emptyToNull(_tankerDriverNameController.text),
        'driver_phone': _emptyToNull(_tankerDriverPhoneController.text),
        'station_id': stationId,
        'fuel_type_id': fuelTypeId,
      });
      if (!mounted) return;
      _tankerRegistrationController.clear();
      _tankerNameController.clear();
      _tankerCapacityController.clear();
      _tankerOwnerNameController.clear();
      _tankerDriverNameController.clear();
      _tankerDriverPhoneController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Tanker ${tanker['name']} created.';
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

  Future<void> _createTrip() async {
    final tankerId = _selectedTankerId;
    final fuelTypeId = _selectedFuelTypeId;
    if (tankerId == null || fuelTypeId == null) {
      setState(() {
        _feedbackMessage = 'Select a tanker and fuel type first.';
      });
      return;
    }
    if (_tripType == 'supplier_to_station' && _selectedLinkedTankId == null) {
      setState(() {
        _feedbackMessage = 'Supplier-to-station trips require a linked tank.';
      });
      return;
    }
    if (_tripType == 'supplier_to_customer' &&
        _tripDestinationController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage =
            'Supplier-to-customer trips require a destination name.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final trip = await widget.sessionController.createTankerTrip({
        'tanker_id': tankerId,
        'supplier_id': _selectedSupplierId,
        'fuel_type_id': fuelTypeId,
        'trip_type': _tripType,
        'linked_tank_id': _tripType == 'supplier_to_station'
            ? _selectedLinkedTankId
            : null,
        'destination_name': _tripType == 'supplier_to_customer'
            ? _tripDestinationController.text.trim()
            : null,
        'notes': _emptyToNull(_tripNotesController.text),
      });
      if (!mounted) return;
      _tripDestinationController.clear();
      _tripNotesController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _selectedTripId = trip['id'] as int?;
        _feedbackMessage = 'Trip #${trip['id']} created.';
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

  Future<void> _addDelivery() async {
    final tripId = _selectedTripId;
    if (tripId == null) {
      setState(() {
        _feedbackMessage = 'Select a trip first.';
      });
      return;
    }
    if (_deliverySaleType == 'credit' && _selectedDeliveryCustomerId == null) {
      setState(() {
        _feedbackMessage = 'Credit deliveries require a customer.';
      });
      return;
    }
    if (_deliveryDestinationController.text.trim().isEmpty &&
        _selectedDeliveryCustomerId == null) {
      setState(() {
        _feedbackMessage =
            'Provide a destination name or choose a customer for the delivery.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final trip = await widget.sessionController.addTankerTripDelivery(
        tripId: tripId,
        payload: {
          'customer_id': _selectedDeliveryCustomerId,
          'destination_name': _emptyToNull(_deliveryDestinationController.text),
          'quantity': double.parse(_deliveryQuantityController.text.trim()),
          'fuel_rate': double.parse(_deliveryFuelRateController.text.trim()),
          'delivery_charge': double.parse(
            _deliveryChargeController.text.trim(),
          ),
          'sale_type': _deliverySaleType,
          'paid_amount': double.parse(
            _deliveryPaidAmountController.text.trim(),
          ),
        },
      );
      if (!mounted) return;
      _deliveryDestinationController.clear();
      _deliveryQuantityController.clear();
      _deliveryFuelRateController.clear();
      _deliveryChargeController.text = '0';
      _deliveryPaidAmountController.text = '0';
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Delivery added. Trip quantity is ${_formatNumber(trip['total_quantity'])}.';
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

  Future<void> _addExpense() async {
    final tripId = _selectedTripId;
    if (tripId == null) {
      setState(() {
        _feedbackMessage = 'Select a trip first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final trip = await widget.sessionController.addTankerTripExpense(
        tripId: tripId,
        payload: {
          'expense_type': _expenseTypeController.text.trim(),
          'amount': double.parse(_expenseAmountController.text.trim()),
          'notes': _emptyToNull(_expenseNotesController.text),
        },
      );
      if (!mounted) return;
      _expenseAmountController.clear();
      _expenseNotesController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Expense added. Trip expense total is ${_formatNumber(trip['expense_total'])}.';
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

  Future<void> _completeTrip() async {
    final tripId = _selectedTripId;
    if (tripId == null) {
      setState(() {
        _feedbackMessage = 'Select a trip first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final trip = await widget.sessionController.completeTankerTrip(
        tripId: tripId,
        payload: {'reason': _emptyToNull(_completeReasonController.text)},
      );
      if (!mounted) return;
      _completeReasonController.clear();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Trip #${trip['id']} completed with net profit ${_formatNumber(trip['net_profit'])}.';
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

  bool get _canReadTankers => _hasAction('tankers', 'read');
  bool get _canManageTankers =>
      _hasAction('tankers', 'create') || _hasAction('tankers', 'update');
  bool get _canCreateTrips => _hasAction('tankers', 'trip_create');
  bool get _canCreateTripDeliveries => _hasAction('tankers', 'delivery_create');
  bool get _canCreateTripExpenses => _hasAction('tankers', 'expense_create');
  bool get _canCompleteTrips => _hasAction('tankers', 'complete');
  bool get _showTankerWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['tankers'],
    permissionModules: const ['tankers'],
    hideWhenModulesOff: true,
  );

  Map<String, String> _sectionMeta() {
    switch (_section) {
      case _TankerSection.tankers:
        return {
          'title': 'Fleet Control',
          'subtitle':
              'Register fuel tankers, check ownership mix, and keep vehicle readiness visible.',
        };
      case _TankerSection.trips:
        return {
          'title': 'Trip Planning',
          'subtitle':
              'Create supply and delivery runs while keeping tanker, supplier, and fuel context aligned.',
        };
      case _TankerSection.tripOps:
        return {
          'title': 'Trip Operations',
          'subtitle':
              'Post deliveries, record trip expenses, and close runs with a clear profitability view.',
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

  Map<String, dynamic>? get _selectedTrip {
    return _trips.cast<Map<String, dynamic>?>().firstWhere(
      (trip) => trip?['id'] == _selectedTripId,
      orElse: () => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showTankerWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Tanker operations are turned off for this scope, so this workspace stays hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final availableSections = <_TankerSection>[
      if (_canReadTankers) _TankerSection.tankers,
      if (_canReadTankers) _TankerSection.trips,
      if (_canReadTankers) _TankerSection.tripOps,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }
    final meta = _sectionMeta();
    final activeTrips = _trips.where((trip) {
      return trip['status']?.toString() != 'completed';
    }).length;
    final totalQuantity = _trips.fold<double>(
      0,
      (sum, trip) => sum + ((trip['total_quantity'] as num?)?.toDouble() ?? 0),
    );
    final totalProfit = _trips.fold<double>(
      0,
      (sum, trip) => sum + ((trip['net_profit'] as num?)?.toDouble() ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Tanker Operations',
            title: meta['title']!,
            subtitle: meta['subtitle']!,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DashboardMetricTile(
                  label: 'Tankers',
                  value: '${_tankers.length}',
                  caption: 'Fleet records',
                  icon: Icons.local_shipping_outlined,
                  tint: Theme.of(context).colorScheme.primaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Trips',
                  value: '${_trips.length}',
                  caption: '$activeTrips active',
                  icon: Icons.route_outlined,
                  tint: Theme.of(context).colorScheme.secondaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Volume',
                  value: _formatNumber(totalQuantity),
                  caption: 'Across visible trips',
                  icon: Icons.water_drop_outlined,
                  tint: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Net Profit',
                  value: _formatNumber(totalProfit),
                  caption: 'Visible trip set',
                  icon: Icons.trending_up_outlined,
                  tint: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: 'Operations Context',
            subtitle:
                'Keep fleet setup, trip creation, and field posting tied to the selected station and current tanker permissions.',
            icon: Icons.alt_route_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
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
                  icon: Icons.view_agenda_outlined,
                  label: meta['title']!,
                ),
                _buildInfoChip(
                  context,
                  icon: _canManageTankers
                      ? Icons.edit_note_outlined
                      : Icons.visibility_outlined,
                  label: _canManageTankers
                      ? 'Managed workspace'
                      : 'Review-first',
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
                    'Tanker Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    availableSections.isEmpty
                        ? 'This role does not currently have access to tanker operations.'
                        : 'Manage tanker vehicles, create trips, post deliveries and expenses, and complete tanker runs.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  if (availableSections.isEmpty) ...[
                    _buildPermissionNotice(
                      context,
                      'Ask an administrator for tanker permissions if this workspace should be available.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stationField = DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'tankers-station-${_selectedStationId ?? 'none'}',
                        ),
                        initialValue: _selectedStationId,
                        decoration: const InputDecoration(labelText: 'Station'),
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
                      );
                      final sections = availableSections.isEmpty
                          ? const SizedBox.shrink()
                          : SegmentedButton<_TankerSection>(
                              segments: const [
                                ButtonSegment(
                                  value: _TankerSection.tankers,
                                  label: Text('Tankers'),
                                  icon: Icon(Icons.local_shipping_outlined),
                                ),
                                ButtonSegment(
                                  value: _TankerSection.trips,
                                  label: Text('Trips'),
                                  icon: Icon(Icons.route_outlined),
                                ),
                                ButtonSegment(
                                  value: _TankerSection.tripOps,
                                  label: Text('Trip Ops'),
                                  icon: Icon(Icons.fact_check_outlined),
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
                            );
                      if (constraints.maxWidth < 900) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            stationField,
                            const SizedBox(height: 12),
                            sections,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: stationField),
                          const SizedBox(width: 12),
                          Expanded(child: sections),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  if (availableSections.isEmpty)
                    const SizedBox.shrink()
                  else if (_section == _TankerSection.tankers)
                    _buildTankersSection(context)
                  else if (_section == _TankerSection.trips)
                    _buildTripsSection(context)
                  else
                    _buildTripOpsSection(context),
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

  Widget _buildTankersSection(BuildContext context) {
    final canManageTankers = _canManageTankers;
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Register Tanker',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!canManageTankers) ...[
            const SizedBox(height: 12),
            _buildPermissionNotice(
              context,
              'This role can review tankers but cannot register or edit them.',
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerRegistrationController,
            enabled: canManageTankers,
            decoration: const InputDecoration(labelText: 'Registration Number'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerNameController,
            enabled: canManageTankers,
            decoration: const InputDecoration(labelText: 'Tanker Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerCapacityController,
            enabled: canManageTankers,
            decoration: const InputDecoration(labelText: 'Capacity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('tanker-ownership-$_tankerOwnershipType'),
            initialValue: _tankerOwnershipType,
            decoration: const InputDecoration(labelText: 'Ownership Type'),
            items: const [
              DropdownMenuItem(value: 'owned', child: Text('Owned')),
              DropdownMenuItem(
                value: 'third_party',
                child: Text('Third Party'),
              ),
              DropdownMenuItem(value: 'leased', child: Text('Leased')),
            ],
            onChanged: canManageTankers
                ? (value) {
                    setState(() {
                      _tankerOwnershipType = value ?? 'owned';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'tanker-fuel-${_selectedFuelTypeId ?? 'none'}',
            ),
            initialValue: _selectedFuelTypeId,
            decoration: const InputDecoration(labelText: 'Fuel Type'),
            items: [
              for (final fuelType in _fuelTypes)
                DropdownMenuItem<int>(
                  value: fuelType['id'] as int,
                  child: Text(fuelType['name'] as String? ?? 'Fuel'),
                ),
            ],
            onChanged: canManageTankers
                ? (value) {
                    setState(() {
                      _selectedFuelTypeId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerOwnerNameController,
            enabled: canManageTankers,
            decoration: const InputDecoration(
              labelText: 'Owner Name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerDriverNameController,
            enabled: canManageTankers,
            decoration: const InputDecoration(
              labelText: 'Driver Name (optional)',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tankerDriverPhoneController,
            enabled: canManageTankers,
            decoration: const InputDecoration(
              labelText: 'Driver Phone (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting || !canManageTankers
                ? null
                : _createTanker,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_shipping_outlined),
            label: const Text('Create Tanker'),
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tankers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_tankers.isEmpty)
                const Text('No tankers registered yet.')
              else
                for (final tanker in _tankers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: tanker['id'] == _selectedTankerId,
                    title: Text(
                      '${tanker['registration_no']} - ${tanker['name']}',
                    ),
                    subtitle: Text(
                      '${tanker['ownership_type']} - capacity ${_formatNumber(tanker['capacity'])} - ${tanker['status']}',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedTankerId = tanker['id'] as int;
                        _selectedFuelTypeId = tanker['fuel_type_id'] as int?;
                      });
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripsSection(BuildContext context) {
    final canCreateTrips = _canCreateTrips;
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Trip', style: Theme.of(context).textTheme.titleLarge),
          if (!canCreateTrips) ...[
            const SizedBox(height: 12),
            _buildPermissionNotice(
              context,
              'This role can review trips but cannot create new tanker trips.',
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('trip-tanker-${_selectedTankerId ?? 'none'}'),
            initialValue: _selectedTankerId,
            decoration: const InputDecoration(labelText: 'Tanker'),
            items: [
              for (final tanker in _tankers)
                DropdownMenuItem<int>(
                  value: tanker['id'] as int,
                  child: Text(
                    '${tanker['registration_no']} - ${tanker['name']}',
                  ),
                ),
            ],
            onChanged: canCreateTrips
                ? (value) {
                    setState(() {
                      _selectedTankerId = value;
                      final selected = _tankers
                          .cast<Map<String, dynamic>?>()
                          .firstWhere(
                            (tanker) => tanker?['id'] == value,
                            orElse: () => null,
                          );
                      _selectedFuelTypeId = selected?['fuel_type_id'] as int?;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('trip-type-$_tripType'),
            initialValue: _tripType,
            decoration: const InputDecoration(labelText: 'Trip Type'),
            items: const [
              DropdownMenuItem(
                value: 'supplier_to_station',
                child: Text('Supplier to Station'),
              ),
              DropdownMenuItem(
                value: 'supplier_to_customer',
                child: Text('Supplier to Customer'),
              ),
            ],
            onChanged: canCreateTrips
                ? (value) {
                    setState(() {
                      _tripType = value ?? 'supplier_to_station';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'trip-supplier-${_selectedSupplierId ?? 'none'}',
            ),
            initialValue: _selectedSupplierId,
            decoration: const InputDecoration(labelText: 'Supplier'),
            items: [
              for (final supplier in _suppliers)
                DropdownMenuItem<int>(
                  value: supplier['id'] as int,
                  child: Text('${supplier['code']} - ${supplier['name']}'),
                ),
            ],
            onChanged: canCreateTrips
                ? (value) {
                    setState(() {
                      _selectedSupplierId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('trip-fuel-${_selectedFuelTypeId ?? 'none'}'),
            initialValue: _selectedFuelTypeId,
            decoration: const InputDecoration(labelText: 'Fuel Type'),
            items: [
              for (final fuelType in _fuelTypes)
                DropdownMenuItem<int>(
                  value: fuelType['id'] as int,
                  child: Text(fuelType['name'] as String? ?? 'Fuel'),
                ),
            ],
            onChanged: canCreateTrips
                ? (value) {
                    setState(() {
                      _selectedFuelTypeId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          if (_tripType == 'supplier_to_station')
            DropdownButtonFormField<int>(
              key: ValueKey<String>(
                'trip-tank-${_selectedLinkedTankId ?? 'none'}',
              ),
              initialValue: _selectedLinkedTankId,
              decoration: const InputDecoration(labelText: 'Linked Tank'),
              items: [
                for (final tank in _tanks)
                  DropdownMenuItem<int>(
                    value: tank['id'] as int,
                    child: Text('${tank['code']} - ${tank['name']}'),
                  ),
              ],
              onChanged: canCreateTrips
                  ? (value) {
                      setState(() {
                        _selectedLinkedTankId = value;
                      });
                    }
                  : null,
            ),
          if (_tripType == 'supplier_to_customer')
            TextFormField(
              controller: _tripDestinationController,
              enabled: canCreateTrips,
              decoration: const InputDecoration(labelText: 'Destination Name'),
            ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tripNotesController,
            enabled: canCreateTrips,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting || !canCreateTrips ? null : _createTrip,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.route_outlined),
            label: const Text('Create Trip'),
          ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Trips',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey<String>(
                        'trip-status-filter-$_tripStatusFilter',
                      ),
                      initialValue: _tripStatusFilter,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: _canReadTankers ? _changeTripStatus : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_trips.isEmpty)
                const Text('No tanker trips found for this station.')
              else
                for (final trip in _trips)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: trip['id'] == _selectedTripId,
                    title: Text(
                      '#${trip['id']} - ${trip['trip_type']} - ${trip['status']}',
                    ),
                    subtitle: Text(
                      'Qty ${_formatNumber(trip['total_quantity'])} - Profit ${_formatNumber(trip['net_profit'])}',
                    ),
                    onTap: () {
                      setState(() {
                        _selectedTripId = trip['id'] as int;
                      });
                    },
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripOpsSection(BuildContext context) {
    final selectedTrip = _selectedTrip;
    final canCreateTripDeliveries = _canCreateTripDeliveries;
    final canCreateTripExpenses = _canCreateTripExpenses;
    final canCompleteTrips = _canCompleteTrips;
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Operations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (!canCreateTripDeliveries &&
              !canCreateTripExpenses &&
              !canCompleteTrips) ...[
            const SizedBox(height: 12),
            _buildPermissionNotice(
              context,
              'This role can review trip summaries but cannot post deliveries, expenses, or trip completion.',
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('trip-ops-${_selectedTripId ?? 'none'}'),
            initialValue: _selectedTripId,
            decoration: const InputDecoration(labelText: 'Trip'),
            items: [
              for (final trip in _trips)
                DropdownMenuItem<int>(
                  value: trip['id'] as int,
                  child: Text(
                    '#${trip['id']} - ${trip['trip_type']} - ${trip['status']}',
                  ),
                ),
            ],
            onChanged: _canReadTankers
                ? (value) {
                    setState(() {
                      _selectedTripId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 20),
          Text('Add Delivery', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            key: ValueKey<String>(
              'trip-delivery-customer-${_selectedDeliveryCustomerId ?? 'none'}',
            ),
            initialValue: _selectedDeliveryCustomerId,
            decoration: const InputDecoration(labelText: 'Customer (optional)'),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('No customer'),
              ),
              for (final customer in _customers)
                DropdownMenuItem<int?>(
                  value: customer['id'] as int,
                  child: Text('${customer['code']} - ${customer['name']}'),
                ),
            ],
            onChanged: canCreateTripDeliveries
                ? (value) {
                    setState(() {
                      _selectedDeliveryCustomerId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryDestinationController,
            enabled: canCreateTripDeliveries,
            decoration: const InputDecoration(
              labelText: 'Delivery Destination',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryQuantityController,
            enabled: canCreateTripDeliveries,
            decoration: const InputDecoration(labelText: 'Quantity'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryFuelRateController,
            enabled: canCreateTripDeliveries,
            decoration: const InputDecoration(labelText: 'Fuel Rate'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryChargeController,
            enabled: canCreateTripDeliveries,
            decoration: const InputDecoration(labelText: 'Delivery Charge'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('delivery-sale-type-$_deliverySaleType'),
            initialValue: _deliverySaleType,
            decoration: const InputDecoration(labelText: 'Sale Type'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'credit', child: Text('Credit')),
            ],
            onChanged: canCreateTripDeliveries
                ? (value) {
                    setState(() {
                      _deliverySaleType = value ?? 'cash';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryPaidAmountController,
            enabled: canCreateTripDeliveries,
            decoration: const InputDecoration(labelText: 'Paid Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _isSubmitting || !canCreateTripDeliveries
                ? null
                : _addDelivery,
            icon: const Icon(Icons.add_road_outlined),
            label: const Text('Add Delivery'),
          ),
          const SizedBox(height: 24),
          Text('Add Expense', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expenseTypeController,
            enabled: canCreateTripExpenses,
            decoration: const InputDecoration(labelText: 'Expense Type'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expenseAmountController,
            enabled: canCreateTripExpenses,
            decoration: const InputDecoration(labelText: 'Amount'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _expenseNotesController,
            enabled: canCreateTripExpenses,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _isSubmitting || !canCreateTripExpenses
                ? null
                : _addExpense,
            icon: const Icon(Icons.money_off_csred_outlined),
            label: const Text('Add Expense'),
          ),
          const SizedBox(height: 24),
          Text('Complete Trip', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextFormField(
            controller: _completeReasonController,
            enabled: canCompleteTrips,
            decoration: const InputDecoration(
              labelText: 'Completion Reason (optional)',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isSubmitting || !canCompleteTrips
                ? null
                : _completeTrip,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Complete Trip'),
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
                selectedTrip == null
                    ? 'Trip Summary'
                    : 'Trip #${selectedTrip['id']} Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedTrip == null)
                const Text('Select a trip to view delivery and expense totals.')
              else ...[
                Text('Type: ${selectedTrip['trip_type']}'),
                Text('Status: ${selectedTrip['status']}'),
                Text(
                  'Quantity: ${_formatNumber(selectedTrip['total_quantity'])}',
                ),
                Text(
                  'Fuel Revenue: ${_formatNumber(selectedTrip['fuel_revenue'])}',
                ),
                Text(
                  'Delivery Revenue: ${_formatNumber(selectedTrip['delivery_revenue'])}',
                ),
                Text(
                  'Expense Total: ${_formatNumber(selectedTrip['expense_total'])}',
                ),
                Text(
                  'Net Profit: ${_formatNumber(selectedTrip['net_profit'])}',
                ),
                const Divider(height: 24),
                Text(
                  'Deliveries',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if ((selectedTrip['deliveries'] as List<dynamic>? ?? const [])
                    .isEmpty)
                  const Text('No deliveries posted yet.')
                else
                  for (final rawDelivery
                      in selectedTrip['deliveries'] as List<dynamic>)
                    Builder(
                      builder: (context) {
                        final delivery = Map<String, dynamic>.from(
                          rawDelivery as Map,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${_formatNumber(delivery['quantity'])} at ${_formatNumber(delivery['fuel_rate'])}',
                          ),
                          subtitle: Text(
                            '${delivery['sale_type']} - charge ${_formatNumber(delivery['delivery_charge'])}',
                          ),
                        );
                      },
                    ),
                const Divider(height: 24),
                Text(
                  'Expenses',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if ((selectedTrip['expenses'] as List<dynamic>? ?? const [])
                    .isEmpty)
                  const Text('No trip expenses posted yet.')
                else
                  for (final rawExpense
                      in selectedTrip['expenses'] as List<dynamic>)
                    Builder(
                      builder: (context) {
                        final expense = Map<String, dynamic>.from(
                          rawExpense as Map,
                        );
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${expense['expense_type']} - ${_formatNumber(expense['amount'])}',
                          ),
                          subtitle: Text(expense['notes'] as String? ?? '-'),
                        );
                      },
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return '0.00';
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
  }
}
