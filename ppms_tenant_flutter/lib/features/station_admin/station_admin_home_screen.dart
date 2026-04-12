import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/localization/app_localizations.dart';
import '../../app/session/session_controller.dart';
import '../accountant/accountant_home_screen.dart';
import '../manager/manager_home_screen.dart';
import 'station_admin_repository.dart';

enum StationAdminSection {
  overview,
  operations,
  finance,
  staff,
  forecourt,
  pricing,
  suppliers,
  inventory,
  settings,
  meter,
  tanker,
}

enum StationAdminRangePreset { daily, weekly, monthly, yearly }

class StationAdminHomeScreen extends ConsumerStatefulWidget {
  const StationAdminHomeScreen({
    super.key,
    this.initialSection = StationAdminSection.overview,
  });

  final StationAdminSection initialSection;

  static StationAdminSection fromSlug(String? slug) {
    switch (slug) {
      case 'operations':
        return StationAdminSection.operations;
      case 'finance':
        return StationAdminSection.finance;
      case 'staff':
        return StationAdminSection.staff;
      case 'forecourt':
        return StationAdminSection.forecourt;
      case 'pricing':
        return StationAdminSection.pricing;
      case 'suppliers':
        return StationAdminSection.suppliers;
      case 'inventory':
        return StationAdminSection.inventory;
      case 'settings':
        return StationAdminSection.settings;
      case 'meter':
        return StationAdminSection.meter;
      case 'tanker':
        return StationAdminSection.tanker;
      case 'dashboard':
      case null:
        return StationAdminSection.overview;
      default:
        return StationAdminSection.overview;
    }
  }

  @override
  ConsumerState<StationAdminHomeScreen> createState() =>
      _StationAdminHomeScreenState();
}

class _StationAdminHomeScreenState
    extends ConsumerState<StationAdminHomeScreen> {
  late Future<_StationAdminBundle> _bundleFuture;
  StationAdminSection _selectedSection = StationAdminSection.overview;
  StationAdminRangePreset _selectedRange = StationAdminRangePreset.monthly;
  int? _selectedNozzleId;
  String? _selectedTemplateType;
  int? _selectedPricingFuelTypeId;
  String? _actionMessage;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _bundleFuture = _loadBundle();
  }

  @override
  void didUpdateWidget(covariant StationAdminHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      _selectedSection = widget.initialSection;
    }
  }

  Future<_StationAdminBundle> _loadBundle() async {
    final session = ref.read(sessionControllerProvider).session;
    final stationId = session?.stationId;
    if (stationId == null) {
      throw Exception('Station scope is required for StationAdmin workspace.');
    }
    final repo = ref.read(stationAdminRepositoryProvider);
    final range = _resolveRange(_selectedRange);

    final results = await Future.wait([
      repo.getDashboard(
        stationId: stationId,
        fromDate: range.start,
        toDate: range.end,
      ),
      repo.getStation(stationId),
      repo.listStationModules(stationId),
      repo.listRoles(),
      repo.listUsers(stationId: stationId),
      repo.listCustomers(stationId: stationId),
      repo.listEmployeeProfiles(stationId: stationId),
      repo.listFuelTypes(),
      repo.listTanks(stationId: stationId),
      repo.listDispensers(stationId: stationId),
      repo.listNozzles(stationId: stationId),
      _safeList(() => repo.listSuppliers()),
      _safeList(() => repo.listPurchases(stationId: stationId)),
      _safeList(() => repo.listPosProducts(stationId: stationId)),
      _safeMap(() => repo.getInvoiceProfile(stationId)),
      _safeList(() => repo.listDocumentTemplates(stationId)),
      _safeMap(() => repo.getTankerSummary(stationId: stationId)),
      _safeList(() => repo.listTankers(stationId: stationId)),
      _safeList(() => repo.listTankerTrips(stationId: stationId)),
    ]);

    final bundle = _StationAdminBundle(
      dashboard: results[0] as Map<String, dynamic>,
      station: results[1] as Map<String, dynamic>,
      stationModules: results[2] as List<Map<String, dynamic>>,
      roles: results[3] as List<Map<String, dynamic>>,
      users: results[4] as List<Map<String, dynamic>>,
      customers: results[5] as List<Map<String, dynamic>>,
      employeeProfiles: results[6] as List<Map<String, dynamic>>,
      fuelTypes: results[7] as List<Map<String, dynamic>>,
      tanks: results[8] as List<Map<String, dynamic>>,
      dispensers: results[9] as List<Map<String, dynamic>>,
      nozzles: results[10] as List<Map<String, dynamic>>,
      suppliers: results[11] as List<Map<String, dynamic>>,
      purchases: results[12] as List<Map<String, dynamic>>,
      posProducts: results[13] as List<Map<String, dynamic>>,
      invoiceProfile: results[14] as Map<String, dynamic>,
      documentTemplates: results[15] as List<Map<String, dynamic>>,
      tankerSummary: results[16] as Map<String, dynamic>,
      tankers: results[17] as List<Map<String, dynamic>>,
      tankerTrips: results[18] as List<Map<String, dynamic>>,
    );

    _selectedNozzleId ??=
        bundle.nozzles.isNotEmpty ? bundle.nozzles.first['id'] as int : null;
    _selectedPricingFuelTypeId ??= bundle.fuelTypes.isNotEmpty
        ? bundle.fuelTypes.first['id'] as int
        : null;
    _selectedTemplateType ??= bundle.documentTemplates.isNotEmpty
        ? bundle.documentTemplates.first['document_type'] as String?
        : null;
    return bundle;
  }

  Future<List<Map<String, dynamic>>> _safeList(
    Future<List<Map<String, dynamic>>> Function() loader,
  ) async {
    try {
      return await loader();
    } on DioException {
      return const [];
    }
  }

  Future<Map<String, dynamic>> _safeMap(
    Future<Map<String, dynamic>> Function() loader,
  ) async {
    try {
      return await loader();
    } on DioException {
      return const <String, dynamic>{};
    }
  }

  Future<void> _reloadAll() async {
    setState(() {
      _actionMessage = null;
      _actionError = null;
      _bundleFuture = _loadBundle();
    });
    await _bundleFuture;
  }

  Future<void> _performAction(
    Future<void> Function() action, {
    required String successMessage,
  }) async {
    final saveFailedLabel = context.l10n.text('saveFailed');
    try {
      await action();
      if (!mounted) return;
      setState(() {
        _actionMessage = successMessage;
        _actionError = null;
      });
      await _reloadAll();
    } on DioException catch (error) {
      final detail = error.response?.data is Map<String, dynamic>
          ? ((error.response?.data as Map<String, dynamic>)['detail']
                  ?.toString() ??
              saveFailedLabel)
          : saveFailedLabel;
      if (!mounted) return;
      setState(() {
        _actionError = detail;
        _actionMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _actionError = saveFailedLabel;
        _actionMessage = null;
      });
    }
  }

  _DateRange _resolveRange(StationAdminRangePreset preset) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    switch (preset) {
      case StationAdminRangePreset.daily:
        return _DateRange(
          todayStart,
          todayStart
              .add(const Duration(days: 1))
              .subtract(const Duration(milliseconds: 1)),
        );
      case StationAdminRangePreset.weekly:
        final start = todayStart.subtract(Duration(days: now.weekday - 1));
        return _DateRange(
          start,
          start
              .add(const Duration(days: 7))
              .subtract(const Duration(milliseconds: 1)),
        );
      case StationAdminRangePreset.monthly:
        final start = DateTime(now.year, now.month, 1);
        return _DateRange(
          start,
          DateTime(now.year, now.month + 1, 1)
              .subtract(const Duration(milliseconds: 1)),
        );
      case StationAdminRangePreset.yearly:
        final start = DateTime(now.year, 1, 1);
        return _DateRange(
          start,
          DateTime(now.year + 1, 1, 1)
              .subtract(const Duration(milliseconds: 1)),
        );
    }
  }

  String _money(num? value) => ((value ?? 0).toDouble()).toStringAsFixed(0);

  String _dateLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    return DateFormat('dd MMM yyyy').format(DateTime.parse(raw).toLocal());
  }

  String _rangeLabel(StationAdminRangePreset preset) {
    switch (preset) {
      case StationAdminRangePreset.daily:
        return context.l10n.text('dailySummary');
      case StationAdminRangePreset.weekly:
        return context.l10n.text('weeklySummary');
      case StationAdminRangePreset.monthly:
        return context.l10n.text('monthlySummary');
      case StationAdminRangePreset.yearly:
        return context.l10n.text('yearlySummary');
    }
  }

  String _sectionLabel(StationAdminSection section) {
    switch (section) {
      case StationAdminSection.overview:
        return context.l10n.text('overview');
      case StationAdminSection.operations:
        return 'Operations';
      case StationAdminSection.finance:
        return 'Finance';
      case StationAdminSection.staff:
        return context.l10n.text('staffManagement');
      case StationAdminSection.forecourt:
        return context.l10n.text('forecourtManagement');
      case StationAdminSection.pricing:
        return 'Fuel pricing';
      case StationAdminSection.suppliers:
        return 'Suppliers';
      case StationAdminSection.inventory:
        return 'Inventory pricing';
      case StationAdminSection.settings:
        return context.l10n.text('settingsLabel');
      case StationAdminSection.meter:
        return context.l10n.text('meterAdjustmentLabel');
      case StationAdminSection.tanker:
        return context.l10n.text('tankerWorkspace');
    }
  }

  String _sectionSlug(StationAdminSection section) {
    switch (section) {
      case StationAdminSection.overview:
        return 'dashboard';
      case StationAdminSection.operations:
        return 'operations';
      case StationAdminSection.finance:
        return 'finance';
      case StationAdminSection.staff:
        return 'staff';
      case StationAdminSection.forecourt:
        return 'forecourt';
      case StationAdminSection.pricing:
        return 'pricing';
      case StationAdminSection.suppliers:
        return 'suppliers';
      case StationAdminSection.inventory:
        return 'inventory';
      case StationAdminSection.settings:
        return 'settings';
      case StationAdminSection.meter:
        return 'meter';
      case StationAdminSection.tanker:
        return 'tanker';
    }
  }

  String _sectionDescription(StationAdminSection section) {
    switch (section) {
      case StationAdminSection.overview:
        return context.l10n.text('stationAdminSubtitle');
      case StationAdminSection.operations:
        return 'Run live shift operations, receiving, dips, expenses, credit, and close checks from the station admin side.';
      case StationAdminSection.finance:
        return 'Manage ledgers, payments, expenses, and payroll without leaving the station admin workspace.';
      case StationAdminSection.staff:
        return 'Create staff, assign access roles, update titles, and manage payroll basics.';
      case StationAdminSection.forecourt:
        return 'Manage fuel types, tanks, dispensers, and nozzles with safe structure changes.';
      case StationAdminSection.pricing:
        return 'Update station fuel selling prices and review recent price history with rate-change support for managers.';
      case StationAdminSection.suppliers:
        return 'Manage supplier master records and review recent purchase cost context by supplier and fuel.';
      case StationAdminSection.inventory:
        return 'Manage lubricant and other shop item selling prices, stock, and inventory behavior.';
      case StationAdminSection.settings:
        return 'Update branding, modules, invoice settings, and document templates.';
      case StationAdminSection.meter:
        return 'Record controlled nozzle meter adjustments with full audit history.';
      case StationAdminSection.tanker:
        return 'Review tanker activity and manage tanker master records for this station.';
    }
  }

  void _openSection(StationAdminSection section) {
    final slug = _sectionSlug(section);
    setState(() => _selectedSection = section);
    context.go('/workspace/station-admin/$slug');
  }

  Future<void> _changeRange(StationAdminRangePreset preset) async {
    if (_selectedRange == preset) return;
    setState(() {
      _selectedRange = preset;
      _bundleFuture = _loadBundle();
    });
    await _bundleFuture;
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionControllerProvider).session;
    if (_selectedSection == StationAdminSection.operations) {
      return Column(
        children: [
          _buildEmbeddedWorkflowHeader(),
          const Expanded(child: ManagerHomeScreen()),
        ],
      );
    }
    if (_selectedSection == StationAdminSection.finance) {
      return Column(
        children: [
          _buildEmbeddedWorkflowHeader(),
          const Expanded(child: AccountantHomeScreen()),
        ],
      );
    }
    return FutureBuilder<_StationAdminBundle>(
      future: _bundleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || session == null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.text('loadFailed')),
            ),
          );
        }

        final bundle = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (_selectedSection == StationAdminSection.overview)
              ..._buildDashboardPage(bundle, session.stationId ?? 0)
            else
              ..._buildWorkflowPage(bundle, session.stationId ?? 0),
          ],
        );
      },
    );
  }

  Widget _buildEmbeddedWorkflowHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _openSection(StationAdminSection.overview),
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Back to dashboard'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sectionLabel(_selectedSection),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _sectionDescription(_selectedSection),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDashboardPage(_StationAdminBundle bundle, int stationId) {
    return [
      Text(
        context.l10n.text('stationAdminTitle'),
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 8),
      Text(
        context.l10n.text('stationAdminSubtitle'),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      if (_actionMessage != null) ...[
        const SizedBox(height: 12),
        _MessageBanner(
          message: _actionMessage!,
          color: Colors.green.shade700,
        ),
      ],
      if (_actionError != null) ...[
        const SizedBox(height: 12),
        _MessageBanner(
          message: _actionError!,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
      const SizedBox(height: 20),
      _SectionCard(
        title: 'Workflow pages',
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _WorkflowCard(
              title: _sectionLabel(StationAdminSection.operations),
              description: _sectionDescription(StationAdminSection.operations),
              onOpen: () => _openSection(StationAdminSection.operations),
            ),
            _WorkflowCard(
              title: _sectionLabel(StationAdminSection.finance),
              description: _sectionDescription(StationAdminSection.finance),
              onOpen: () => _openSection(StationAdminSection.finance),
            ),
            for (final section in StationAdminSection.values
                .where(
                  (item) =>
                      item != StationAdminSection.overview &&
                      item != StationAdminSection.operations &&
                      item != StationAdminSection.finance,
                ))
              _WorkflowCard(
                title: _sectionLabel(section),
                description: _sectionDescription(section),
                onOpen: () => _openSection(section),
              ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      _buildOverviewSection(bundle),
    ];
  }

  List<Widget> _buildWorkflowPage(_StationAdminBundle bundle, int stationId) {
    return [
      Row(
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _openSection(StationAdminSection.overview),
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Back to dashboard'),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _sectionLabel(_selectedSection),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  _sectionDescription(_selectedSection),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
      if (_actionMessage != null) ...[
        const SizedBox(height: 12),
        _MessageBanner(
          message: _actionMessage!,
          color: Colors.green.shade700,
        ),
      ],
      if (_actionError != null) ...[
        const SizedBox(height: 12),
        _MessageBanner(
          message: _actionError!,
          color: Theme.of(context).colorScheme.error,
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: StationAdminSection.values.map((section) {
          return ChoiceChip(
            label: Text(_sectionLabel(section)),
            selected: section == _selectedSection,
            onSelected: (_) => _openSection(section),
          );
        }).toList(),
      ),
      const SizedBox(height: 24),
      _buildSectionBody(bundle, stationId),
    ];
  }

  Widget _buildSectionBody(_StationAdminBundle bundle, int stationId) {
    switch (_selectedSection) {
      case StationAdminSection.overview:
        return _buildOverviewSection(bundle);
      case StationAdminSection.operations:
        return const SizedBox.shrink();
      case StationAdminSection.finance:
        return const SizedBox.shrink();
      case StationAdminSection.staff:
        return _buildStaffSection(bundle, stationId);
      case StationAdminSection.forecourt:
        return _buildForecourtSection(bundle, stationId);
      case StationAdminSection.pricing:
        return _buildPricingSection(bundle, stationId);
      case StationAdminSection.suppliers:
        return _buildSuppliersSection(bundle);
      case StationAdminSection.inventory:
        return _buildInventorySection(bundle, stationId);
      case StationAdminSection.settings:
        return _buildSettingsSection(bundle, stationId);
      case StationAdminSection.meter:
        return _buildMeterSection(bundle);
      case StationAdminSection.tanker:
        return _buildTankerSection(bundle, stationId);
    }
  }

  Widget _buildOverviewSection(_StationAdminBundle bundle) {
    final dashboard = bundle.dashboard;
    final sales = Map<String, dynamic>.from(
      dashboard['sales'] as Map? ?? const {},
    );
    final lowStock = (dashboard['low_stock_alerts'] as List<dynamic>? ?? const [])
        .cast<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final creditAlerts =
        (dashboard['credit_limit_alerts'] as List<dynamic>? ?? const [])
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
    final tanker = Map<String, dynamic>.from(
      dashboard['tanker'] as Map? ?? const {},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: StationAdminRangePreset.values.map((preset) {
            return ChoiceChip(
              label: Text(_rangeLabel(preset)),
              selected: preset == _selectedRange,
              onSelected: (_) => _changeRange(preset),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _MetricCard(
              title: context.l10n.text('totalSalesLabel'),
              value: _money(sales['total']),
              subtitle: '${sales['count'] ?? 0} ${context.l10n.text('entries')}',
            ),
            _MetricCard(
              title: context.l10n.text('expenseCard'),
              value: _money(dashboard['expenses']),
              subtitle: _rangeLabel(_selectedRange),
            ),
            _MetricCard(
              title: context.l10n.text('netProfitLabel'),
              value: _money(dashboard['net_profit']),
              subtitle: context.l10n.text('financeSummary'),
            ),
            _MetricCard(
              title: context.l10n.text('remainingFuelLabel'),
              value: _money(dashboard['fuel_stock_liters']),
              subtitle: context.l10n.text('litersLabel'),
            ),
            _MetricCard(
              title: context.l10n.text('overdueCustomers'),
              value: _money(dashboard['receivables']),
              subtitle: context.l10n.text('customerLedger'),
            ),
            _MetricCard(
              title: context.l10n.text('supplierDues'),
              value: _money(dashboard['payables']),
              subtitle: context.l10n.text('supplierLedger'),
            ),
            _MetricCard(
              title: context.l10n.text('tankerWorkspace'),
              value: _money(tanker['net_profit']),
              subtitle:
                  '${tanker['completed_trips'] ?? 0} ${context.l10n.text('completedTripsLabel')}',
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: 'Station control center',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openSection(StationAdminSection.staff),
                icon: const Icon(Icons.groups_outlined),
                label: Text(
                  'Staff ${bundle.users.length}/${bundle.employeeProfiles.length}',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openSection(StationAdminSection.forecourt),
                icon: const Icon(Icons.local_gas_station_outlined),
                label: Text(
                  'Forecourt ${bundle.tanks.length} tanks / ${bundle.nozzles.length} nozzles',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openSection(StationAdminSection.pricing),
                icon: const Icon(Icons.price_change_outlined),
                label: Text('Fuel prices ${bundle.fuelTypes.length} types'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _openSection(StationAdminSection.tanker),
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(
                  'Tanker ${tanker['in_progress_trip_count'] ?? 0} active trips',
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.go('/workspace/manager'),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Open manager operations'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => context.go('/workspace/accountant'),
                icon: const Icon(Icons.account_balance_outlined),
                label: const Text('Open accountant finance'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: context.l10n.text('stationSnapshot'),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InlineInfo(
                label: context.l10n.text('stationName'),
                value: bundle.station['name']?.toString() ?? '-',
              ),
              _InlineInfo(
                label: context.l10n.text('displayName'),
                value: bundle.station['display_name']?.toString() ??
                    bundle.station['name']?.toString() ??
                    '-',
              ),
              _InlineInfo(
                label: context.l10n.text('setupStatusLabel'),
                value: bundle.station['setup_status']?.toString() ?? '-',
              ),
              _InlineInfo(
                label: context.l10n.text('active'),
                value: bundle.station['is_active'] == true
                    ? context.l10n.text('yesLabel')
                    : context.l10n.text('noLabel'),
              ),
              _InlineInfo(
                label: context.l10n.text('moduleToggles'),
                value: '${bundle.stationModules.length}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _SectionCard(
          title: context.l10n.text('financeAlerts'),
          child: (lowStock.isEmpty && creditAlerts.isEmpty)
              ? Text(context.l10n.text('noRecentItems'))
              : Column(
                  children: [
                    ...lowStock.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.local_gas_station_outlined),
                        title: Text(
                          '${item['tank_name']} (${item['fuel_type']})',
                        ),
                        subtitle: Text(
                          '${context.l10n.text('remainingFuelLabel')}: ${_money(item['current_volume'])} / ${_money(item['threshold'])}',
                        ),
                      ),
                    ),
                    ...creditAlerts.map(
                      (item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.account_balance_wallet_outlined),
                        title: Text(item['customer_name']?.toString() ?? '-'),
                        subtitle: Text(
                          '${_money(item['outstanding_balance'])} / ${_money(item['credit_limit'])}',
                        ),
                        trailing:
                            Text('${item['usage_percentage']?.toString() ?? '0'}%'),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Trip operations',
          child: bundle.tankerTrips.isEmpty
              ? const Text('Create a trip to start tanker operations.')
              : Column(
                  children: bundle.tankerTrips.take(10).map((trip) {
                    final deliveries =
                        (trip['deliveries'] as List<dynamic>? ?? const [])
                            .cast<dynamic>();
                    final canComplete =
                        (trip['status']?.toString() ?? '') != 'settled' &&
                            (trip['status']?.toString() ?? '') !=
                                'partially_settled';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${trip['trip_type']} • ${trip['status']} • ${trip['settlement_status'] ?? '-'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                _InlineInfo(
                                  label: 'Loaded',
                                  value:
                                      '${_money(trip['loaded_quantity'])} ${context.l10n.text('litersLabel')}',
                                ),
                                _InlineInfo(
                                  label: 'Delivered',
                                  value:
                                      '${_money(trip['total_quantity'])} ${context.l10n.text('litersLabel')}',
                                ),
                                _InlineInfo(
                                  label: 'Remaining',
                                  value:
                                      '${_money(trip['leftover_quantity'])} ${context.l10n.text('litersLabel')}',
                                ),
                                _InlineInfo(
                                  label: 'Net profit',
                                  value: _money(trip['net_profit']),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () => _showTankerDeliveryDialog(
                                    trip: trip,
                                    bundle: bundle,
                                  ),
                                  icon: const Icon(Icons.local_shipping_outlined),
                                  label: const Text('Add delivery'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: deliveries.isEmpty
                                      ? null
                                      : () => _showTankerPaymentDialog(
                                            trip: trip,
                                            deliveries: deliveries
                                                .map(
                                                  (item) =>
                                                      Map<String, dynamic>.from(
                                                    item as Map,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                  icon: const Icon(Icons.payments_outlined),
                                  label: const Text('Record payment'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _showTankerExpenseDialog(trip: trip),
                                  icon: const Icon(Icons.receipt_long_outlined),
                                  label: const Text('Add expense'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: canComplete
                                      ? () => _showTankerCompleteDialog(
                                            trip: trip,
                                            tanks: bundle.tanks,
                                          )
                                      : null,
                                  icon: const Icon(Icons.task_alt_outlined),
                                  label: const Text('Settle trip'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _buildTankerOperationsCard(bundle),
      ],
    );
  }

  Widget _buildStaffSection(_StationAdminBundle bundle, int stationId) {
    final assignableRoles = bundle.roles.where((role) {
      final name = (role['name']?.toString() ?? '').toLowerCase();
      return name != 'masteradmin' && name != 'headoffice';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.tonalIcon(
              onPressed: () => _showUserDialog(
                stationId: stationId,
                roles: assignableRoles,
              ),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(context.l10n.text('createStaffUser')),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showEmployeeProfileDialog(
                stationId: stationId,
                users: bundle.users,
              ),
              icon: const Icon(Icons.badge_outlined),
              label: Text(context.l10n.text('createStaffProfile')),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('staffUsers'),
          child: bundle.users.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.users.map((user) {
                    final role = bundle.roles.firstWhere(
                      (item) => item['id'] == user['role_id'],
                      orElse: () => const <String, dynamic>{},
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user['full_name']?.toString() ?? '-'),
                      subtitle: Text(
                        '${user['username'] ?? '-'} · ${role['name'] ?? '-'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showUserDialog(
                              stationId: stationId,
                              roles: assignableRoles,
                              existing: user,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(context.l10n.text('editLabel')),
                          ),
                          TextButton.icon(
                            onPressed: () => _performAction(
                              () => ref
                                  .read(stationAdminRepositoryProvider)
                                  .deleteUser(user['id'] as int),
                              successMessage:
                                  context.l10n.text('staffDeletedMessage'),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(context.l10n.text('deleteLabel')),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('staffProfiles'),
          child: bundle.employeeProfiles.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.employeeProfiles.map((profile) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(profile['full_name']?.toString() ?? '-'),
                      subtitle: Text(
                        '${profile['staff_title'] ?? profile['staff_type'] ?? '-'} · ${context.l10n.text('employeeCode')}: ${profile['employee_code'] ?? '-'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Text(_money(profile['monthly_salary'])),
                          TextButton.icon(
                            onPressed: () => _showEmployeeProfileDialog(
                              stationId: stationId,
                              users: bundle.users,
                              existing: profile,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(context.l10n.text('editLabel')),
                          ),
                          TextButton.icon(
                            onPressed: () => _performAction(
                              () => ref
                                  .read(stationAdminRepositoryProvider)
                                  .deleteEmployeeProfile(profile['id'] as int),
                              successMessage:
                                  context.l10n.text('staffDeletedMessage'),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: Text(context.l10n.text('deleteLabel')),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildForecourtSection(_StationAdminBundle bundle, int stationId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: context.l10n.text('fuelTypes'),
          action: FilledButton.tonalIcon(
            onPressed: _showFuelTypeDialog,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.l10n.text('add')),
          ),
          child: bundle.fuelTypes.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.fuelTypes.map((fuelType) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(fuelType['name']?.toString() ?? '-'),
                      subtitle: Text(
                        fuelType['description']?.toString() ??
                            context.l10n.text('notAvailableLabel'),
                      ),
                      trailing: TextButton.icon(
                        onPressed: () => _showFuelTypeDialog(existing: fuelType),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(context.l10n.text('editLabel')),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('tanks'),
          action: FilledButton.tonalIcon(
            onPressed: () => _showTankDialog(
              stationId: stationId,
              fuelTypes: bundle.fuelTypes,
            ),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.l10n.text('add')),
          ),
          child: bundle.tanks.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.tanks.map((tank) {
                    final fuelType = bundle.fuelTypes.firstWhere(
                      (item) => item['id'] == tank['fuel_type_id'],
                      orElse: () => const <String, dynamic>{},
                    );
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${tank['name']} (${tank['code']})'),
                      subtitle: Text(
                        '${fuelType['name'] ?? '-'} · ${_money(tank['current_volume'])}/${_money(tank['capacity'])}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: () => _showTankDialog(
                              stationId: stationId,
                              fuelTypes: bundle.fuelTypes,
                              existing: tank,
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(context.l10n.text('editLabel')),
                          ),
                          TextButton.icon(
                            onPressed: () => _performAction(
                              () => ref
                                  .read(stationAdminRepositoryProvider)
                                  .deleteTank(tank['id'] as int),
                              successMessage:
                                  context.l10n.text('forecourtSavedMessage'),
                            ),
                            icon: const Icon(Icons.power_settings_new, size: 18),
                            label: Text(context.l10n.text('deactivateLabel')),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('dispensersAndNozzles'),
          action: Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _showDispenserDialog(stationId: stationId),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(context.l10n.text('addDispenserLabel')),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _showNozzleDialog(
                  dispensers: bundle.dispensers,
                  tanks: bundle.tanks,
                  fuelTypes: bundle.fuelTypes,
                ),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(context.l10n.text('addNozzle')),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bundle.dispensers.map((dispenser) {
              final dispenserNozzles = bundle.nozzles
                  .where((nozzle) => nozzle['dispenser_id'] == dispenser['id'])
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${dispenser['name']} (${dispenser['code']})',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showDispenserDialog(
                                stationId: stationId,
                                existing: dispenser,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: Text(context.l10n.text('editLabel')),
                            ),
                            TextButton.icon(
                              onPressed: () => _performAction(
                                () => ref
                                    .read(stationAdminRepositoryProvider)
                                    .deleteDispenser(dispenser['id'] as int),
                                successMessage:
                                    context.l10n.text('forecourtSavedMessage'),
                              ),
                              icon: const Icon(
                                Icons.power_settings_new,
                                size: 18,
                              ),
                              label: Text(context.l10n.text('deactivateLabel')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (dispenserNozzles.isEmpty)
                          Text(context.l10n.text('noDataYet'))
                        else
                          ...dispenserNozzles.map((nozzle) {
                            final tank = bundle.tanks.firstWhere(
                              (item) => item['id'] == nozzle['tank_id'],
                              orElse: () => const <String, dynamic>{},
                            );
                            final fuelType = bundle.fuelTypes.firstWhere(
                              (item) => item['id'] == nozzle['fuel_type_id'],
                              orElse: () => const <String, dynamic>{},
                            );
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text('${nozzle['name']} (${nozzle['code']})'),
                              subtitle: Text(
                                '${fuelType['name'] ?? '-'} · ${tank['name'] ?? '-'} · ${context.l10n.text('currentMeter')}: ${_money(nozzle['meter_reading'])}',
                              ),
                              trailing: Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showNozzleDialog(
                                      dispensers: bundle.dispensers,
                                      tanks: bundle.tanks,
                                      fuelTypes: bundle.fuelTypes,
                                      existing: nozzle,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                    ),
                                    label: Text(context.l10n.text('editLabel')),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => _performAction(
                                      () => ref
                                          .read(stationAdminRepositoryProvider)
                                          .deleteNozzle(nozzle['id'] as int),
                                      successMessage: context.l10n
                                          .text('forecourtSavedMessage'),
                                    ),
                                    icon: const Icon(
                                      Icons.power_settings_new,
                                      size: 18,
                                    ),
                                    label: Text(
                                      context.l10n.text('deactivateLabel'),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingSection(_StationAdminBundle bundle, int stationId) {
    final selectedFuelType = bundle.fuelTypes.firstWhere(
      (item) => item['id'] == _selectedPricingFuelTypeId,
      orElse: () => const <String, dynamic>{},
    );
    final currentPrice =
        (selectedFuelType['price_per_liter'] as num?)?.toDouble();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _selectedPricingFuelTypeId == null
          ? Future.value(const [])
          : ref.read(stationAdminRepositoryProvider).listFuelPriceHistory(
                stationId: stationId,
                fuelTypeId: _selectedPricingFuelTypeId!,
              ),
      builder: (context, snapshot) {
        final history = snapshot.data ?? const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: 'Fuel selling prices',
              action: FilledButton.tonalIcon(
                onPressed: _selectedPricingFuelTypeId == null
                    ? null
                    : () => _showFuelPriceDialog(
                          stationId: stationId,
                          fuelType: selectedFuelType,
                        ),
                icon: const Icon(Icons.price_change_outlined),
                label: const Text('Change price'),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _selectedPricingFuelTypeId,
                    items: bundle.fuelTypes
                        .map(
                          (fuelType) => DropdownMenuItem<int>(
                            value: fuelType['id'] as int,
                            child: Text(fuelType['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedPricingFuelTypeId = value),
                    decoration: const InputDecoration(
                      labelText: 'Fuel type',
                      helperText:
                          'Use this page for station selling price changes. Managers already on shift will capture boundary readings when the price changes.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _MetricCard(
                        title: 'Current selling price',
                        value: currentPrice == null ? '-' : _money(currentPrice),
                        subtitle: selectedFuelType['name']?.toString() ?? '',
                      ),
                      _MetricCard(
                        title: 'Recorded price changes',
                        value: '${history.length}',
                        subtitle: 'Recent station price history',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionCard(
              title: 'Recent selling price history',
              child: history.isEmpty
                  ? const Text('No price history recorded yet for this fuel.')
                  : Column(
                      children: history.map((entry) {
                        final notes = entry['notes']?.toString() ?? '';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_outlined),
                          title: Text(
                            '${selectedFuelType['name'] ?? 'Fuel'} • ${_money(entry['price'] as num?)}',
                          ),
                          subtitle: Text(
                            '${entry['reason'] ?? '-'} • ${_dateLabel(entry['effective_at']?.toString())}'
                            '${notes.isEmpty ? '' : '\n$notes'}',
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSuppliersSection(_StationAdminBundle bundle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Supplier records and buying context',
          action: FilledButton.tonalIcon(
            onPressed: _showSupplierDialog,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Add supplier'),
          ),
          child: bundle.suppliers.isEmpty
              ? const Text('No suppliers added yet.')
              : Column(
                  children: bundle.suppliers.map((supplier) {
                    final supplierId = supplier['id'] as int?;
                    final recentPurchases = bundle.purchases
                        .where((item) => item['supplier_id'] == supplierId)
                        .take(5)
                        .toList();
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supplier['name']?.toString() ?? '-',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${supplier['code'] ?? '-'} • Payable ${_money(supplier['payable_balance'] as num?)}',
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _showSupplierDialog(supplier: supplier),
                                  child: Text(context.l10n.text('editLabel')),
                                ),
                                TextButton(
                                  onPressed: supplierId == null
                                      ? null
                                      : () => _performAction(
                                            () async {
                                              await ref
                                                  .read(
                                                    stationAdminRepositoryProvider,
                                                  )
                                                  .deleteSupplier(supplierId);
                                            },
                                            successMessage:
                                                context.l10n.text(
                                                  'deletedLabel',
                                                ),
                                          ),
                                  child:
                                      Text(context.l10n.text('deleteLabel')),
                                ),
                              ],
                            ),
                            if ((supplier['phone']?.toString().isNotEmpty ??
                                    false) ||
                                (supplier['address']?.toString().isNotEmpty ??
                                    false)) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${supplier['phone'] ?? '-'}${(supplier['address']?.toString().isNotEmpty ?? false) ? ' • ${supplier['address']}' : ''}',
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Recent buying rates',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            if (recentPurchases.isEmpty)
                              const Text(
                                'No recent purchases found for this supplier.',
                              )
                            else
                              Column(
                                children: recentPurchases.map((purchase) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      '${purchase['fuel_type_name'] ?? 'Fuel'} • ${purchase['quantity_liters'] ?? 0} liters',
                                    ),
                                    subtitle: Text(
                                      'Buying rate ${_money(purchase['rate_per_liter'] as num?)} • ${_dateLabel(purchase['date']?.toString())}',
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildInventorySection(_StationAdminBundle bundle, int stationId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: 'Lubricant and inventory selling prices',
          action: FilledButton.tonalIcon(
            onPressed: () => _showPosProductDialog(stationId: stationId),
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add item'),
          ),
          child: bundle.posProducts.isEmpty
              ? const Text('No lubricant or inventory items configured yet.')
              : Column(
                  children: bundle.posProducts.map((product) {
                    final productId = product['id'] as int?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        (product['track_inventory'] as bool? ?? false)
                            ? Icons.inventory_2_outlined
                            : Icons.sell_outlined,
                      ),
                      title: Text(product['name']?.toString() ?? '-'),
                      subtitle: Text(
                        '${product['category'] ?? '-'} • ${product['module'] ?? '-'} • Buying ${_money(product['buying_price'] as num?)} • Selling ${_money(product['price'] as num?)} • Stock ${_money(product['stock_quantity'] as num?)} • ${(product['is_active'] as bool? ?? true) ? 'Active' : 'Inactive'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => _showPosProductDialog(
                              stationId: stationId,
                              product: product,
                            ),
                            child: Text(context.l10n.text('editLabel')),
                          ),
                          TextButton(
                            onPressed: productId == null
                                ? null
                                : () => _performAction(
                                      () async {
                                        await ref
                                            .read(
                                              stationAdminRepositoryProvider,
                                            )
                                            .deletePosProduct(productId);
                                      },
                                      successMessage: context.l10n.text(
                                        'deletedLabel',
                                      ),
                                    ),
                            child: Text(context.l10n.text('deleteLabel')),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(_StationAdminBundle bundle, int stationId) {
    final template = bundle.documentTemplates.firstWhere(
      (item) => item['document_type'] == _selectedTemplateType,
      orElse: () => const <String, dynamic>{},
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: context.l10n.text('brandingSettingsLabel'),
          action: FilledButton.tonalIcon(
            onPressed: () => _showStationSettingsDialog(bundle.station),
            icon: const Icon(Icons.edit_outlined),
            label: Text(context.l10n.text('editLabel')),
          ),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _InlineInfo(
                label: context.l10n.text('displayName'),
                value: bundle.station['display_name']?.toString() ??
                    bundle.station['name']?.toString() ??
                    '-',
              ),
              _InlineInfo(
                label: context.l10n.text('legalName'),
                value: bundle.station['legal_name_override']?.toString() ?? '-',
              ),
              _InlineInfo(
                label: context.l10n.text('brand'),
                value: bundle.station['brand_name']?.toString() ?? '-',
              ),
              _InlineInfo(
                label: context.l10n.text('sameAsOrganizationName'),
                value: bundle.station['use_organization_branding'] == true
                    ? context.l10n.text('yesLabel')
                    : context.l10n.text('noLabel'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('moduleToggles'),
          child: bundle.stationModules.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.stationModules.map((setting) {
                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(setting['module_name']?.toString() ?? '-'),
                      subtitle: Text(context.l10n.text('moduleToggleHint')),
                      value: setting['is_enabled'] == true,
                      onChanged: (value) => _performAction(
                        () => ref
                            .read(stationAdminRepositoryProvider)
                            .updateStationModule(
                              stationId,
                              moduleName:
                                  setting['module_name']?.toString() ?? '',
                              isEnabled: value,
                            ),
                        successMessage:
                            context.l10n.text('settingsSavedMessage'),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('invoiceSettingsLabel'),
          action: FilledButton.tonalIcon(
            onPressed: () => _showInvoiceProfileDialog(
              stationId: stationId,
              existing: bundle.invoiceProfile,
            ),
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(context.l10n.text('editLabel')),
          ),
          child: bundle.invoiceProfile.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _InlineInfo(
                      label: context.l10n.text('businessNameLabel'),
                      value: bundle.invoiceProfile['business_name']?.toString() ??
                          '-',
                    ),
                    _InlineInfo(
                      label: context.l10n.text('legalName'),
                      value:
                          bundle.invoiceProfile['legal_name']?.toString() ?? '-',
                    ),
                    _InlineInfo(
                      label: context.l10n.text('registrationNumber'),
                      value: bundle.invoiceProfile['registration_no']
                              ?.toString() ??
                          '-',
                    ),
                    _InlineInfo(
                      label: context.l10n.text('taxNumber'),
                      value: bundle.invoiceProfile['tax_registration_no']
                              ?.toString() ??
                          '-',
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('documentTemplatesLabel'),
          action: Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _performAction(
                  () => ref
                      .read(stationAdminRepositoryProvider)
                      .seedDocumentTemplates(stationId),
                  successMessage: context.l10n.text('settingsSavedMessage'),
                ),
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: Text(context.l10n.text('seedDefaultsLabel')),
              ),
              if (_selectedTemplateType != null)
                FilledButton.tonalIcon(
                  onPressed: template.isEmpty
                      ? null
                      : () => _showDocumentTemplateDialog(
                            stationId: stationId,
                            existing: template,
                          ),
                  icon: const Icon(Icons.edit_note_outlined),
                  label: Text(context.l10n.text('editLabel')),
                ),
            ],
          ),
          child: bundle.documentTemplates.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: bundle.documentTemplates.any(
                        (item) => item['document_type'] == _selectedTemplateType,
                      )
                          ? _selectedTemplateType
                          : bundle.documentTemplates.first['document_type']
                              ?.toString(),
                      items: bundle.documentTemplates
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item['document_type']?.toString(),
                              child: Text(
                                item['document_type']?.toString() ?? '-',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedTemplateType = value);
                      },
                      decoration: InputDecoration(
                        labelText: context.l10n.text('documentTypeLabel'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (template.isNotEmpty) ...[
                      _InlineInfo(
                        label: context.l10n.text('displayName'),
                        value: template['name']?.toString() ?? '-',
                      ),
                      const SizedBox(height: 8),
                      _InlineInfo(
                        label: context.l10n.text('active'),
                        value: template['is_active'] == true
                            ? context.l10n.text('yesLabel')
                            : context.l10n.text('noLabel'),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMeterSection(_StationAdminBundle bundle) {
    final selectedNozzle = bundle.nozzles.firstWhere(
      (item) => item['id'] == _selectedNozzleId,
      orElse: () => const <String, dynamic>{},
    );
    final currentReading =
        (selectedNozzle['meter_reading'] as num?)?.toDouble() ?? 0;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _selectedNozzleId == null
          ? Future.value(const [])
          : ref
              .read(stationAdminRepositoryProvider)
              .listNozzleAdjustments(_selectedNozzleId!),
      builder: (context, snapshot) {
        final adjustments = snapshot.data ?? const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionCard(
              title: context.l10n.text('meterAdjustmentLabel'),
              action: FilledButton.tonalIcon(
                onPressed: _selectedNozzleId == null
                    ? null
                    : () => _showMeterAdjustmentDialog(
                          nozzleId: _selectedNozzleId!,
                          currentReading: currentReading,
                        ),
                icon: const Icon(Icons.tune_outlined),
                label: Text(context.l10n.text('recordMeterAdjustmentLabel')),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: bundle.nozzles.any(
                      (item) => item['id'] == _selectedNozzleId,
                    )
                        ? _selectedNozzleId
                        : null,
                    items: bundle.nozzles
                        .map(
                          (nozzle) => DropdownMenuItem<int>(
                            value: nozzle['id'] as int,
                            child: Text(
                              '${nozzle['name']} (${nozzle['code']})',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedNozzleId = value);
                    },
                    decoration: InputDecoration(
                      labelText: context.l10n.text('nozzleName'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selectedNozzle.isNotEmpty)
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _InlineInfo(
                          label: 'Old / current meter reading',
                          value: _money(currentReading),
                        ),
                        _InlineInfo(
                          label: 'Current segment start',
                          value: _money(
                            selectedNozzle['current_segment_start_reading'],
                          ),
                        ),
                        const _InlineInfo(
                          label: 'New adjusted reading',
                          value: 'Enter below',
                        ),
                        _InlineInfo(
                          label: context.l10n.text('active'),
                          value: selectedNozzle['is_active'] == true
                              ? context.l10n.text('yesLabel')
                              : context.l10n.text('noLabel'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: context.l10n.text('recentAdjustmentsLabel'),
              child: snapshot.connectionState != ConnectionState.done
                  ? const LinearProgressIndicator()
                  : adjustments.isEmpty
                      ? Text(context.l10n.text('noDataYet'))
                      : Column(
                          children: adjustments.map((item) {
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading:
                                  const Icon(Icons.history_toggle_off_outlined),
                              title: Text(
                                '${_money(item['old_reading'])} → ${_money(item['new_reading'])}',
                              ),
                              subtitle: Text(item['reason']?.toString() ?? '-'),
                              trailing:
                                  Text(_dateLabel(item['adjusted_at']?.toString())),
                            );
                          }).toList(),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTankerSection(_StationAdminBundle bundle, int stationId) {
    return _buildTankerSectionV2(bundle, stationId);
  }

  Widget _buildTankerSectionV2(_StationAdminBundle bundle, int stationId) {
    final summary = bundle.tankerSummary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          title: context.l10n.text('tankerWorkspace'),
          action: Wrap(
            spacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: bundle.fuelTypes.isEmpty
                    ? null
                    : () => _showCreateTankerDialog(
                          stationId: stationId,
                          fuelTypes: bundle.fuelTypes,
                        ),
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(context.l10n.text('createTankerLabel')),
              ),
              FilledButton.tonalIcon(
                onPressed: bundle.tankers.isEmpty
                    ? null
                    : () => _showCreateTankerTripDialog(
                          stationId: stationId,
                          bundle: bundle,
                        ),
                icon: const Icon(Icons.route_outlined),
                label: const Text('Create trip'),
              ),
            ],
          ),
          child: summary.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _MetricCard(
                      title: context.l10n.text('tankerCountLabel'),
                      value: '${summary['tanker_count'] ?? 0}',
                      width: 180,
                    ),
                    _MetricCard(
                      title: context.l10n.text('activeTankersLabel'),
                      value: '${summary['active_tanker_count'] ?? 0}',
                      width: 180,
                    ),
                    _MetricCard(
                      title: context.l10n.text('inProgressTripsLabel'),
                      value: '${summary['in_progress_trip_count'] ?? 0}',
                      width: 180,
                    ),
                    _MetricCard(
                      title: context.l10n.text('completedTripsLabel'),
                      value: '${summary['completed_trip_count'] ?? 0}',
                      width: 180,
                    ),
                    _MetricCard(
                      title: 'Remaining tanker fuel',
                      value: _money(summary['total_leftover_quantity']),
                      subtitle: context.l10n.text('litersLabel'),
                      width: 180,
                    ),
                    _MetricCard(
                      title: 'Purchase value',
                      value: _money(summary['total_purchase_value']),
                      subtitle: 'Loaded trip cost',
                      width: 180,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('tankerMasterDataLabel'),
          child: bundle.tankers.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.tankers.map((tanker) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_shipping_outlined),
                      title:
                          Text('${tanker['name']} (${tanker['registration_no']})'),
                      subtitle: Text(
                        '${tanker['ownership_type']} · ${_money(tanker['capacity'])}',
                      ),
                      trailing: Text(tanker['status']?.toString() ?? '-'),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: context.l10n.text('recentTripsLabel'),
          child: bundle.tankerTrips.isEmpty
              ? Text(context.l10n.text('noDataYet'))
              : Column(
                  children: bundle.tankerTrips.take(10).map((trip) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('${trip['trip_type']} · ${trip['status']}'),
                      subtitle: Text(
                        '${context.l10n.text('destinationLabel')}: ${trip['destination_name'] ?? '-'}',
                      ),
                      trailing: Text(_money(trip['net_profit'])),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildTankerOperationsCard(_StationAdminBundle bundle) {
    return _SectionCard(
      title: 'Trip operations',
      child: bundle.tankerTrips.isEmpty
          ? const Text('Create a trip to start tanker operations.')
          : Column(
              children: bundle.tankerTrips.take(10).map((trip) {
                final deliveries =
                    (trip['deliveries'] as List<dynamic>? ?? const [])
                        .cast<dynamic>();
                final canComplete =
                    (trip['status']?.toString() ?? '') != 'settled' &&
                        (trip['status']?.toString() ?? '') !=
                            'partially_settled';
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${trip['trip_type']} • ${trip['status']} • ${trip['settlement_status'] ?? '-'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _InlineInfo(
                              label: 'Loaded',
                              value:
                                  '${_money(trip['loaded_quantity'])} ${context.l10n.text('litersLabel')}',
                            ),
                            _InlineInfo(
                              label: 'Delivered',
                              value:
                                  '${_money(trip['total_quantity'])} ${context.l10n.text('litersLabel')}',
                            ),
                            _InlineInfo(
                              label: 'Remaining',
                              value:
                                  '${_money(trip['leftover_quantity'])} ${context.l10n.text('litersLabel')}',
                            ),
                            _InlineInfo(
                              label: 'Net profit',
                              value: _money(trip['net_profit']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _showTankerDeliveryDialog(
                                trip: trip,
                                bundle: bundle,
                              ),
                              icon: const Icon(Icons.local_shipping_outlined),
                              label: const Text('Add delivery'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: deliveries.isEmpty
                                  ? null
                                  : () => _showTankerPaymentDialog(
                                        trip: trip,
                                        deliveries: deliveries
                                            .map(
                                              (item) =>
                                                  Map<String, dynamic>.from(
                                                item as Map,
                                              ),
                                            )
                                            .toList(),
                                      ),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Record payment'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () =>
                                  _showTankerExpenseDialog(trip: trip),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Add expense'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: canComplete
                                  ? () => _showTankerCompleteDialog(
                                        trip: trip,
                                        tanks: bundle.tanks,
                                      )
                                  : null,
                              icon: const Icon(Icons.task_alt_outlined),
                              label: const Text('Settle trip'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _showCreateTankerTripDialog({
    required int stationId,
    required _StationAdminBundle bundle,
  }) async {
    int? tankerId =
        bundle.tankers.isNotEmpty ? bundle.tankers.first['id'] as int : null;
    int? fuelTypeId =
        bundle.fuelTypes.isNotEmpty ? bundle.fuelTypes.first['id'] as int : null;
    String tripType = 'supplier_to_customer';
    int? supplierId =
        bundle.suppliers.isNotEmpty ? bundle.suppliers.first['id'] as int : null;
    int? linkedTankId =
        bundle.tanks.isNotEmpty ? bundle.tanks.first['id'] as int : null;
    int? driverUserId;
    final destinationController = TextEditingController();
    final notesController = TextEditingController();
    final quantityController = TextEditingController();
    final rateController = TextEditingController();

    if (!mounted || tankerId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Create tanker trip'),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: tankerId,
                    items: bundle.tankers
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => tankerId = value),
                    decoration: const InputDecoration(labelText: 'Tanker'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: tripType,
                    items: const [
                      DropdownMenuItem(
                        value: 'supplier_to_station',
                        child: Text('supplier_to_station'),
                      ),
                      DropdownMenuItem(
                        value: 'supplier_to_customer',
                        child: Text('supplier_to_customer'),
                      ),
                      DropdownMenuItem(
                        value: 'mixed_delivery',
                        child: Text('mixed_delivery'),
                      ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => tripType = value ?? tripType),
                    decoration: const InputDecoration(labelText: 'Trip type'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: bundle.fuelTypes.any(
                      (item) => item['id'] == fuelTypeId,
                    )
                        ? fuelTypeId
                        : null,
                    items: bundle.fuelTypes
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => fuelTypeId = value),
                    decoration: const InputDecoration(labelText: 'Load fuel type'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: supplierId,
                    items: bundle.suppliers
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => supplierId = value),
                    decoration: const InputDecoration(labelText: 'Supplier'),
                  ),
                  const SizedBox(height: 12),
                  if (tripType == 'supplier_to_station')
                    DropdownButtonFormField<int?>(
                      initialValue: linkedTankId,
                      items: bundle.tanks
                          .map(
                            (item) => DropdownMenuItem<int?>(
                              value: item['id'] as int,
                              child: Text(item['name']?.toString() ?? '-'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setLocalState(() => linkedTankId = value),
                      decoration:
                          const InputDecoration(labelText: 'Destination tank'),
                    )
                  else
                    TextField(
                      controller: destinationController,
                      decoration:
                          const InputDecoration(labelText: 'Destination name'),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: driverUserId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('No driver linked'),
                      ),
                      ...bundle.users.map(
                        (user) => DropdownMenuItem<int?>(
                          value: user['id'] as int,
                          child: Text(user['full_name']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => driverUserId = value),
                    decoration: const InputDecoration(labelText: 'Driver'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Loaded quantity',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Purchase rate'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).createTankerTrip({
        'tanker_id': tankerId,
        'station_id': stationId,
        'supplier_id': supplierId,
        'trip_type': tripType,
        'linked_tank_id': linkedTankId,
        'destination_name': destinationController.text.trim().isEmpty
            ? null
            : destinationController.text.trim(),
        'notes': notesController.text.trim().isEmpty
            ? null
            : notesController.text.trim(),
        'fuel_type_id': fuelTypeId,
        'loaded_quantity': double.tryParse(quantityController.text.trim()) ?? 0,
        'purchase_rate': double.tryParse(rateController.text.trim()) ?? 0,
        'driver_assignments': driverUserId == null
            ? <Map<String, dynamic>>[]
            : [
                {
                  'user_id': driverUserId,
                  'assignment_role': 'driver',
                },
              ],
      });
    }, successMessage: 'Tanker trip created.');
  }

  Future<void> _showTankerDeliveryDialog({
    required Map<String, dynamic> trip,
    required _StationAdminBundle bundle,
  }) async {
    int? customerId;
    final destinationController = TextEditingController();
    final quantityController = TextEditingController();
    final rateController = TextEditingController();
    final paidController = TextEditingController(text: '0');
    String saleType = 'cash';
    final loads =
        (trip['compartment_loads'] as List<dynamic>? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
    int? loadId = loads.isNotEmpty ? loads.first['id'] as int : null;
    int? fuelTypeId =
        loads.isNotEmpty ? loads.first['fuel_type_id'] as int : null;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Add tanker delivery'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int?>(
                    initialValue: customerId,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Outside customer / pump'),
                      ),
                      ...bundle.customers.map(
                        (customer) => DropdownMenuItem<int?>(
                          value: customer['id'] as int,
                          child: Text(customer['name']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) => setLocalState(() => customerId = value),
                    decoration: const InputDecoration(labelText: 'Customer'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: destinationController,
                    decoration:
                        const InputDecoration(labelText: 'Destination name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: loadId,
                    items: loads
                        .map(
                          (load) => DropdownMenuItem<int?>(
                            value: load['id'] as int,
                            child: Text(
                              '${load['compartment_id']} • ${_money(load['remaining_quantity'])} remaining',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setLocalState(() {
                        loadId = value;
                        final selected = loads.firstWhere(
                          (item) => item['id'] == value,
                          orElse: () => const <String, dynamic>{},
                        );
                        fuelTypeId = selected['fuel_type_id'] as int?;
                      });
                    },
                    decoration:
                        const InputDecoration(labelText: 'Compartment load'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Sale rate'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: saleType,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('cash')),
                      DropdownMenuItem(value: 'credit', child: Text('credit')),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => saleType = value ?? saleType),
                    decoration: const InputDecoration(labelText: 'Sale type'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: paidController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Paid amount'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).addTankerTripDelivery(
        trip['id'] as int,
        {
          'customer_id': customerId,
          'fuel_type_id': fuelTypeId,
          'compartment_load_id': loadId,
          'destination_name': destinationController.text.trim().isEmpty
              ? null
              : destinationController.text.trim(),
          'quantity': double.tryParse(quantityController.text.trim()) ?? 0,
          'fuel_rate': double.tryParse(rateController.text.trim()) ?? 0,
          'sale_type': saleType,
          'paid_amount': double.tryParse(paidController.text.trim()) ?? 0,
        },
      );
    }, successMessage: 'Tanker delivery added.');
  }

  Future<void> _showTankerPaymentDialog({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> deliveries,
  }) async {
    int? deliveryId =
        deliveries.isNotEmpty ? deliveries.first['id'] as int : null;
    final amountController = TextEditingController();
    final referenceController = TextEditingController();
    if (!mounted || deliveryId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Record tanker payment'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: deliveryId,
                  items: deliveries
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item['id'] as int,
                          child: Text(
                            '${item['destination_name'] ?? 'Customer'} • Outstanding ${_money(item['outstanding_amount'])}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocalState(() => deliveryId = value),
                  decoration: const InputDecoration(labelText: 'Delivery'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: referenceController,
                  decoration: const InputDecoration(labelText: 'Reference'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).addTankerTripPayment(
        trip['id'] as int,
        deliveryId!,
        {
          'amount': double.tryParse(amountController.text.trim()) ?? 0,
          'reference_no': referenceController.text.trim().isEmpty
              ? null
              : referenceController.text.trim(),
        },
      );
    }, successMessage: 'Tanker payment recorded.');
  }

  Future<void> _showTankerExpenseDialog({
    required Map<String, dynamic> trip,
  }) async {
    final typeController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add tanker trip expense'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: typeController,
                decoration: const InputDecoration(labelText: 'Expense type'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).addTankerTripExpense(
        trip['id'] as int,
        {
          'expense_type': typeController.text.trim(),
          'amount': double.tryParse(amountController.text.trim()) ?? 0,
          'notes': notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        },
      );
    }, successMessage: 'Tanker trip expense saved.');
  }

  Future<void> _showTankerCompleteDialog({
    required Map<String, dynamic> trip,
    required List<Map<String, dynamic>> tanks,
  }) async {
    final reasonController = TextEditingController();
    int? tankId = tanks.isNotEmpty ? tanks.first['id'] as int : null;
    final quantityController = TextEditingController(
      text: _money(trip['leftover_quantity'] as num?),
    );
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Settle tanker trip'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 12),
                if ((trip['leftover_quantity'] as num? ?? 0) > 0) ...[
                  DropdownButtonFormField<int?>(
                    initialValue: tankId,
                    items: tanks
                        .map(
                          (item) => DropdownMenuItem<int?>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => tankId = value),
                    decoration: const InputDecoration(
                      labelText: 'Dump leftover to tank',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Transfer quantity',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).completeTankerTrip(
        trip['id'] as int,
        {
          'reason': reasonController.text.trim().isEmpty
              ? null
              : reasonController.text.trim(),
          'transfer_to_tank_id': tankId,
          'transfer_quantity': double.tryParse(quantityController.text.trim()),
        },
      );
    }, successMessage: 'Tanker trip settled.');
  }

  Future<void> _showUserDialog({
    required int stationId,
    required List<Map<String, dynamic>> roles,
    Map<String, dynamic>? existing,
  }) async {
    final staffSavedMessage = context.l10n.text('staffSavedMessage');
    final fullNameController =
        TextEditingController(text: existing?['full_name']?.toString() ?? '');
    final usernameController =
        TextEditingController(text: existing?['username']?.toString() ?? '');
    final emailController =
        TextEditingController(text: existing?['email']?.toString() ?? '');
    final passwordController = TextEditingController();
    final salaryController = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['monthly_salary'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0),
    );
    int? selectedRoleId = existing?['role_id'] as int? ??
        (roles.isNotEmpty ? roles.first['id'] as int : null);
    bool isActive = existing?['is_active'] != false;
    bool payrollEnabled = existing?['payroll_enabled'] != false;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.text('createStaffUser')
                : context.l10n.text('editStaffUser'),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('adminFullName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameController,
                    enabled: existing == null,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('adminUsername'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('contactEmail'),
                    ),
                  ),
                  if (existing == null) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('adminPassword'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedRoleId,
                    items: roles
                        .map(
                          (role) => DropdownMenuItem<int>(
                            value: role['id'] as int,
                            child: Text(role['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => selectedRoleId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('accessRoleLabel'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salaryController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('currentSalary'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: payrollEnabled,
                    title: Text(context.l10n.text('payrollSummary')),
                    onChanged: (value) =>
                        setLocalState(() => payrollEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: Text(context.l10n.text('active')),
                    onChanged: (value) =>
                        setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selectedRoleId == null) return;

    final salary = double.tryParse(salaryController.text.trim()) ?? 0;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createUser({
          'full_name': fullNameController.text.trim(),
          'username': usernameController.text.trim(),
          'email': emailController.text.trim().isEmpty
              ? null
              : emailController.text.trim(),
          'password': passwordController.text.trim(),
          'role_id': selectedRoleId,
          'station_id': stationId,
          'monthly_salary': salary,
          'payroll_enabled': payrollEnabled,
        });
      } else {
        await ref.read(stationAdminRepositoryProvider).updateUser(
          existing['id'] as int,
          {
            'full_name': fullNameController.text.trim(),
            'email': emailController.text.trim().isEmpty
                ? null
                : emailController.text.trim(),
            'role_id': selectedRoleId,
            'station_id': stationId,
            'monthly_salary': salary,
            'payroll_enabled': payrollEnabled,
            'is_active': isActive,
          },
        );
      }
    }, successMessage: staffSavedMessage);
  }

  Future<void> _showEmployeeProfileDialog({
    required int stationId,
    required List<Map<String, dynamic>> users,
    Map<String, dynamic>? existing,
  }) async {
    final staffSavedMessage = context.l10n.text('staffSavedMessage');
    final fullNameController =
        TextEditingController(text: existing?['full_name']?.toString() ?? '');
    final staffTypeController = TextEditingController(
      text: existing?['staff_type']?.toString() ?? 'Staff',
    );
    final staffTitleController =
        TextEditingController(text: existing?['staff_title']?.toString() ?? '');
    final codeController = TextEditingController(
      text: existing?['employee_code']?.toString() ?? '',
    );
    final phoneController =
        TextEditingController(text: existing?['phone']?.toString() ?? '');
    final salaryController = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['monthly_salary'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0),
    );
    final notesController =
        TextEditingController(text: existing?['notes']?.toString() ?? '');
    int? linkedUserId = existing?['linked_user_id'] as int?;
    bool isActive = existing?['is_active'] != false;
    bool payrollEnabled = existing?['payroll_enabled'] != false;
    bool canLogin = existing?['can_login'] == true;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.text('createStaffProfile')
                : context.l10n.text('editStaffProfile'),
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: fullNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('adminFullName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: users.any((item) => item['id'] == linkedUserId)
                        ? linkedUserId
                        : null,
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(context.l10n.text('noLinkedUserLabel')),
                      ),
                      ...users.map(
                        (user) => DropdownMenuItem<int?>(
                          value: user['id'] as int,
                          child: Text(user['full_name']?.toString() ?? '-'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setLocalState(() => linkedUserId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('linkedUserLabel'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: staffTypeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('staffTypeLabel'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: staffTitleController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('staffTitle'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('employeeCode'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('contactPhone'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salaryController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('currentSalary'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('optionalNotes'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: payrollEnabled,
                    title: Text(context.l10n.text('payrollSummary')),
                    onChanged: (value) =>
                        setLocalState(() => payrollEnabled = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: canLogin,
                    title: Text(context.l10n.text('canLoginLabel')),
                    onChanged: (value) =>
                        setLocalState(() => canLogin = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: Text(context.l10n.text('active')),
                    onChanged: (value) =>
                        setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final salary = double.tryParse(salaryController.text.trim()) ?? 0;
    final payload = {
      'station_id': stationId,
      'linked_user_id': linkedUserId,
      'full_name': fullNameController.text.trim(),
      'staff_type': staffTypeController.text.trim(),
      'staff_title': staffTitleController.text.trim().isEmpty
          ? null
          : staffTitleController.text.trim(),
      'employee_code': codeController.text.trim().isEmpty
          ? null
          : codeController.text.trim(),
      'phone': phoneController.text.trim().isEmpty
          ? null
          : phoneController.text.trim(),
      'monthly_salary': salary,
      'payroll_enabled': payrollEnabled,
      'can_login': canLogin,
      'is_active': isActive,
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
    };
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createEmployeeProfile(
              payload,
            );
      } else {
        await ref.read(stationAdminRepositoryProvider).updateEmployeeProfile(
              existing['id'] as int,
              payload,
            );
      }
    }, successMessage: staffSavedMessage);
  }

  Future<void> _showFuelTypeDialog({Map<String, dynamic>? existing}) async {
    final forecourtSavedMessage = context.l10n.text('forecourtSavedMessage');
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null
              ? context.l10n.text('addFuelTypeLabel')
              : context.l10n.text('editFuelTypeLabel'),
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.text('fuelTypeName'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: context.l10n.text('description'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.text('saveLabel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createFuelType({
          'name': nameController.text.trim(),
          'description': descriptionController.text.trim().isEmpty
              ? null
              : descriptionController.text.trim(),
        });
      } else {
        await ref.read(stationAdminRepositoryProvider).updateFuelType(
              existing['id'] as int,
              {
                'name': nameController.text.trim(),
                'description': descriptionController.text.trim().isEmpty
                    ? null
                    : descriptionController.text.trim(),
              },
            );
      }
    }, successMessage: forecourtSavedMessage);
  }

  Future<void> _showTankDialog({
    required int stationId,
    required List<Map<String, dynamic>> fuelTypes,
    Map<String, dynamic>? existing,
  }) async {
    final forecourtSavedMessage = context.l10n.text('forecourtSavedMessage');
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: existing?['code']?.toString() ?? '');
    final capacityController = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['capacity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    final currentController = TextEditingController(
      text: existing == null
          ? ''
          : ((existing['current_volume'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0),
    );
    final thresholdController = TextEditingController(
      text: existing == null
          ? '1000'
          : ((existing['low_stock_threshold'] as num?)?.toDouble() ?? 1000)
              .toStringAsFixed(0),
    );
    int? fuelTypeId = existing?['fuel_type_id'] as int? ??
        (fuelTypes.isNotEmpty ? fuelTypes.first['id'] as int : null);
    bool isActive = existing?['is_active'] != false;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.text('addTankLabel')
                : context.l10n.text('editTankLabel'),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('tankName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('code'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: fuelTypeId,
                    items: fuelTypes
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => fuelTypeId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('fuelType'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: capacityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('capacity'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: currentController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('remainingFuelLabel'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: thresholdController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('lowStockThreshold'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: Text(context.l10n.text('active')),
                    onChanged: (value) =>
                        setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || fuelTypeId == null) return;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createTank({
          'name': nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          'code': codeController.text.trim().isEmpty
              ? null
              : codeController.text.trim(),
          'capacity': double.tryParse(capacityController.text.trim()) ?? 0,
          'current_volume': double.tryParse(currentController.text.trim()) ?? 0,
          'low_stock_threshold':
              double.tryParse(thresholdController.text.trim()) ?? 1000,
          'station_id': stationId,
          'fuel_type_id': fuelTypeId,
          'is_active': isActive,
        });
      } else {
        await ref.read(stationAdminRepositoryProvider).updateTank(
              existing['id'] as int,
              {
                'name': nameController.text.trim().isEmpty
                    ? null
                    : nameController.text.trim(),
                'capacity':
                    double.tryParse(capacityController.text.trim()) ?? 0,
                'current_volume':
                    double.tryParse(currentController.text.trim()) ?? 0,
                'low_stock_threshold':
                    double.tryParse(thresholdController.text.trim()) ?? 1000,
                'is_active': isActive,
              },
            );
      }
    }, successMessage: forecourtSavedMessage);
  }

  Future<void> _showDispenserDialog({
    required int stationId,
    Map<String, dynamic>? existing,
  }) async {
    final forecourtSavedMessage = context.l10n.text('forecourtSavedMessage');
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: existing?['code']?.toString() ?? '');
    final locationController =
        TextEditingController(text: existing?['location']?.toString() ?? '');
    bool isActive = existing?['is_active'] != false;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.text('addDispenserLabel')
                : context.l10n.text('editDispenserLabel'),
          ),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('dispenserName'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('code'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: context.l10n.text('description'),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isActive,
                  title: Text(context.l10n.text('active')),
                  onChanged: (value) =>
                      setLocalState(() => isActive = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createDispenser({
          'name': nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          'code': codeController.text.trim().isEmpty
              ? null
              : codeController.text.trim(),
          'location': locationController.text.trim().isEmpty
              ? null
              : locationController.text.trim(),
          'station_id': stationId,
          'is_active': isActive,
        });
      } else {
        await ref.read(stationAdminRepositoryProvider).updateDispenser(
              existing['id'] as int,
              {
                'name': nameController.text.trim().isEmpty
                    ? null
                    : nameController.text.trim(),
                'location': locationController.text.trim().isEmpty
                    ? null
                    : locationController.text.trim(),
                'is_active': isActive,
              },
            );
      }
    }, successMessage: forecourtSavedMessage);
  }

  Future<void> _showNozzleDialog({
    required List<Map<String, dynamic>> dispensers,
    required List<Map<String, dynamic>> tanks,
    required List<Map<String, dynamic>> fuelTypes,
    Map<String, dynamic>? existing,
  }) async {
    final forecourtSavedMessage = context.l10n.text('forecourtSavedMessage');
    final nameController =
        TextEditingController(text: existing?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: existing?['code']?.toString() ?? '');
    final meterController = TextEditingController(
      text: existing == null
          ? '0'
          : ((existing['meter_reading'] as num?)?.toDouble() ?? 0)
              .toStringAsFixed(0),
    );
    int? dispenserId = existing?['dispenser_id'] as int? ??
        (dispensers.isNotEmpty ? dispensers.first['id'] as int : null);
    int? tankId = existing?['tank_id'] as int? ??
        (tanks.isNotEmpty ? tanks.first['id'] as int : null);
    int? fuelTypeId = existing?['fuel_type_id'] as int? ??
        (fuelTypes.isNotEmpty ? fuelTypes.first['id'] as int : null);
    bool isActive = existing?['is_active'] != false;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(
            existing == null
                ? context.l10n.text('addNozzle')
                : context.l10n.text('editNozzleLabel'),
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('nozzleName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('code'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: dispenserId,
                    items: dispensers
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => dispenserId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('dispenserName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: tankId,
                    items: tanks
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setLocalState(() => tankId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('tank'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: fuelTypeId,
                    items: fuelTypes
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item['id'] as int,
                            child: Text(item['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setLocalState(() => fuelTypeId = value),
                    decoration: InputDecoration(
                      labelText: context.l10n.text('fuelType'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: meterController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? context.l10n.text('startingMeter')
                          : context.l10n.text('currentMeter'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: Text(context.l10n.text('active')),
                    onChanged: (value) =>
                        setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true ||
        dispenserId == null ||
        tankId == null ||
        fuelTypeId == null) {
      return;
    }
    await _performAction(() async {
      if (existing == null) {
        await ref.read(stationAdminRepositoryProvider).createNozzle({
          'name': nameController.text.trim().isEmpty
              ? null
              : nameController.text.trim(),
          'code': codeController.text.trim().isEmpty
              ? null
              : codeController.text.trim(),
          'meter_reading': double.tryParse(meterController.text.trim()) ?? 0,
          'dispenser_id': dispenserId,
          'tank_id': tankId,
          'fuel_type_id': fuelTypeId,
          'is_active': isActive,
        });
      } else {
        await ref.read(stationAdminRepositoryProvider).updateNozzle(
              existing['id'] as int,
              {
                'name': nameController.text.trim().isEmpty
                    ? null
                    : nameController.text.trim(),
                'tank_id': tankId,
                'fuel_type_id': fuelTypeId,
                'is_active': isActive,
              },
            );
      }
    }, successMessage: forecourtSavedMessage);
  }

  Future<void> _showStationSettingsDialog(Map<String, dynamic> existing) async {
    final settingsSavedMessage = context.l10n.text('settingsSavedMessage');
    final displayNameController = TextEditingController(
      text: existing['display_name']?.toString() ?? '',
    );
    final legalNameController = TextEditingController(
      text: existing['legal_name_override']?.toString() ?? '',
    );
    final brandNameController = TextEditingController(
      text: existing['brand_name']?.toString() ?? '',
    );
    final brandCodeController = TextEditingController(
      text: existing['brand_code']?.toString() ?? '',
    );
    final logoUrlController = TextEditingController(
      text: existing['logo_url']?.toString() ?? '',
    );
    bool useOrganizationBranding = existing['use_organization_branding'] == true;
    bool allowMeterAdjustments = existing['allow_meter_adjustments'] != false;
    bool hasPos = existing['has_pos'] == true;
    bool hasTankers = existing['has_tankers'] == true;
    bool hasHardware = existing['has_hardware'] == true;
    bool hasShops = existing['has_shops'] == true;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(context.l10n.text('brandingSettingsLabel')),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: displayNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('displayName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: legalNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('legalName'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandNameController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('brand'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: brandCodeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('code'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: logoUrlController,
                    decoration: InputDecoration(
                      labelText: context.l10n.text('logoUrlLabel'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: useOrganizationBranding,
                    title: Text(context.l10n.text('inheritBrandingToStations')),
                    onChanged: (value) =>
                        setLocalState(() => useOrganizationBranding = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: allowMeterAdjustments,
                    title:
                        Text(context.l10n.text('allowMeterAdjustmentsLabel')),
                    onChanged: (value) =>
                        setLocalState(() => allowMeterAdjustments = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasPos,
                    title: Text(context.l10n.text('hasPosLabel')),
                    onChanged: (value) => setLocalState(() => hasPos = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasTankers,
                    title: Text(context.l10n.text('hasTankersLabel')),
                    onChanged: (value) =>
                        setLocalState(() => hasTankers = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasHardware,
                    title: Text(context.l10n.text('hasHardwareLabel')),
                    onChanged: (value) =>
                        setLocalState(() => hasHardware = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: hasShops,
                    title: Text(context.l10n.text('hasShopsLabel')),
                    onChanged: (value) =>
                        setLocalState(() => hasShops = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).updateStation(
            existing['id'] as int,
            {
              'display_name': displayNameController.text.trim().isEmpty
                  ? null
                  : displayNameController.text.trim(),
              'legal_name_override': legalNameController.text.trim().isEmpty
                  ? null
                  : legalNameController.text.trim(),
              'brand_name': brandNameController.text.trim().isEmpty
                  ? null
                  : brandNameController.text.trim(),
              'brand_code': brandCodeController.text.trim().isEmpty
                  ? null
                  : brandCodeController.text.trim(),
              'logo_url': logoUrlController.text.trim().isEmpty
                  ? null
                  : logoUrlController.text.trim(),
              'use_organization_branding': useOrganizationBranding,
              'allow_meter_adjustments': allowMeterAdjustments,
              'has_pos': hasPos,
              'has_tankers': hasTankers,
              'has_hardware': hasHardware,
              'has_shops': hasShops,
            },
          );
    }, successMessage: settingsSavedMessage);
  }

  Future<void> _showInvoiceProfileDialog({
    required int stationId,
    required Map<String, dynamic> existing,
  }) async {
    final settingsSavedMessage = context.l10n.text('settingsSavedMessage');
    final businessNameController = TextEditingController(
      text: existing['business_name']?.toString() ?? '',
    );
    final legalNameController = TextEditingController(
      text: existing['legal_name']?.toString() ?? '',
    );
    final registrationController = TextEditingController(
      text: existing['registration_no']?.toString() ?? '',
    );
    final taxController = TextEditingController(
      text: existing['tax_registration_no']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: existing['contact_email']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: existing['contact_phone']?.toString() ?? '',
    );
    final footerController = TextEditingController(
      text: existing['footer_text']?.toString() ?? '',
    );
    final prefixController = TextEditingController(
      text: existing['invoice_prefix']?.toString() ?? '',
    );
    final notesController = TextEditingController(
      text: existing['sale_invoice_notes']?.toString() ?? '',
    );

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('invoiceSettingsLabel')),
        content: SizedBox(
          width: 580,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: businessNameController, decoration: InputDecoration(labelText: context.l10n.text('businessNameLabel'))),
                const SizedBox(height: 12),
                TextField(controller: legalNameController, decoration: InputDecoration(labelText: context.l10n.text('legalName'))),
                const SizedBox(height: 12),
                TextField(controller: registrationController, decoration: InputDecoration(labelText: context.l10n.text('registrationNumber'))),
                const SizedBox(height: 12),
                TextField(controller: taxController, decoration: InputDecoration(labelText: context.l10n.text('taxNumber'))),
                const SizedBox(height: 12),
                TextField(controller: emailController, decoration: InputDecoration(labelText: context.l10n.text('contactEmail'))),
                const SizedBox(height: 12),
                TextField(controller: phoneController, decoration: InputDecoration(labelText: context.l10n.text('contactPhone'))),
                const SizedBox(height: 12),
                TextField(controller: prefixController, decoration: InputDecoration(labelText: context.l10n.text('invoicePrefixLabel'))),
                const SizedBox(height: 12),
                TextField(controller: footerController, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: context.l10n.text('footerTextLabel'))),
                const SizedBox(height: 12),
                TextField(controller: notesController, minLines: 2, maxLines: 3, decoration: InputDecoration(labelText: context.l10n.text('invoiceNotesLabel'))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.text('cancelLabel'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.text('saveLabel'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).updateInvoiceProfile(
            stationId,
            {
              'business_name': businessNameController.text.trim(),
              'legal_name': legalNameController.text.trim().isEmpty ? null : legalNameController.text.trim(),
              'registration_no': registrationController.text.trim().isEmpty ? null : registrationController.text.trim(),
              'tax_registration_no': taxController.text.trim().isEmpty ? null : taxController.text.trim(),
              'contact_email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
              'contact_phone': phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
              'footer_text': footerController.text.trim().isEmpty ? null : footerController.text.trim(),
              'invoice_prefix': prefixController.text.trim().isEmpty ? null : prefixController.text.trim(),
              'sale_invoice_notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
            },
          );
    }, successMessage: settingsSavedMessage);
  }

  Future<void> _showDocumentTemplateDialog({
    required int stationId,
    required Map<String, dynamic> existing,
  }) async {
    final settingsSavedMessage = context.l10n.text('settingsSavedMessage');
    final nameController = TextEditingController(text: existing['name']?.toString() ?? '');
    final headerController = TextEditingController(text: existing['header_html']?.toString() ?? '');
    final bodyController = TextEditingController(text: existing['body_html']?.toString() ?? '');
    final footerController = TextEditingController(text: existing['footer_html']?.toString() ?? '');
    bool isActive = existing['is_active'] != false;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(context.l10n.text('documentTemplatesLabel')),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: InputDecoration(labelText: context.l10n.text('displayName'))),
                  const SizedBox(height: 12),
                  TextField(controller: headerController, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: context.l10n.text('headerHtmlLabel'))),
                  const SizedBox(height: 12),
                  TextField(controller: bodyController, minLines: 4, maxLines: 8, decoration: InputDecoration(labelText: context.l10n.text('bodyHtmlLabel'))),
                  const SizedBox(height: 12),
                  TextField(controller: footerController, minLines: 2, maxLines: 4, decoration: InputDecoration(labelText: context.l10n.text('footerHtmlLabel'))),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    title: Text(context.l10n.text('active')),
                    onChanged: (value) => setLocalState(() => isActive = value),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.text('cancelLabel'))),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.text('saveLabel'))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).upsertDocumentTemplate(
            stationId,
            existing['document_type']?.toString() ?? 'invoice',
            {
              'name': nameController.text.trim(),
              'header_html': headerController.text.trim().isEmpty ? null : headerController.text.trim(),
              'body_html': bodyController.text.trim().isEmpty ? null : bodyController.text.trim(),
              'footer_html': footerController.text.trim().isEmpty ? null : footerController.text.trim(),
              'is_active': isActive,
            },
          );
    }, successMessage: settingsSavedMessage);
  }

  Future<void> _showMeterAdjustmentDialog({
    required int nozzleId,
    required double currentReading,
  }) async {
    final meterAdjustmentSavedMessage =
        context.l10n.text('meterAdjustmentSavedMessage');
    final oldReadingController =
        TextEditingController(text: currentReading.toStringAsFixed(0));
    final newReadingController =
        TextEditingController();
    final reasonController = TextEditingController();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.text('recordMeterAdjustmentLabel')),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oldReadingController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Old / current meter reading',
                  helperText:
                      'Enter the reading observed on the meter at the time of reversal.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newReadingController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'New adjusted meter reading',
                  helperText:
                      'Enter the reading that should replace the old/current value.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for adjustment',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.text('cancelLabel'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.text('saveLabel'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).adjustNozzleMeter(
            nozzleId,
            oldReading: double.tryParse(oldReadingController.text.trim()) ?? 0,
            newReading: double.tryParse(newReadingController.text.trim()) ?? 0,
            reason: reasonController.text.trim(),
          );
    }, successMessage: meterAdjustmentSavedMessage);
  }

  Future<void> _showFuelPriceDialog({
    required int stationId,
    required Map<String, dynamic> fuelType,
  }) async {
    final priceController = TextEditingController(
      text: ((fuelType['price_per_liter'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    String? priceError;
    String? reasonError;

    void validate() {
      final parsedPrice = double.tryParse(priceController.text.trim());
      priceError = parsedPrice == null || parsedPrice <= 0
          ? 'Enter a valid selling price.'
          : null;
      reasonError =
          reasonController.text.trim().isEmpty ? 'Reason is required.' : null;
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: Text('Change ${fuelType['name'] ?? 'fuel'} price'),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'New selling price',
                      helperText:
                          'This is the station selling price. If managers are already on shift, they will capture boundary readings after the price change.',
                      errorText: priceError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason',
                      errorText: reasonError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.text('cancelLabel')),
              ),
              FilledButton(
                onPressed: () {
                  setLocalState(validate);
                  if (priceError != null || reasonError != null) {
                    return;
                  }
                  Navigator.of(context).pop(true);
                },
                child: Text(context.l10n.text('saveLabel')),
              ),
            ],
          );
        },
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).createFuelPriceHistory(
            stationId: stationId,
            fuelTypeId: fuelType['id'] as int,
            price: double.tryParse(priceController.text.trim()) ?? 0,
            reason: reasonController.text.trim(),
            notes: notesController.text.trim().isEmpty
                ? null
                : notesController.text.trim(),
          );
    }, successMessage: 'Fuel selling price updated.');
  }

  Future<void> _showSupplierDialog({
    Map<String, dynamic>? supplier,
  }) async {
    final nameController =
        TextEditingController(text: supplier?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: supplier?['code']?.toString() ?? '');
    final phoneController =
        TextEditingController(text: supplier?['phone']?.toString() ?? '');
    final addressController =
        TextEditingController(text: supplier?['address']?.toString() ?? '');
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'Add supplier' : 'Edit supplier'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Supplier name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeController,
                enabled: supplier == null,
                decoration: const InputDecoration(labelText: 'Supplier code'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.text('cancelLabel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.text('saveLabel')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      final repo = ref.read(stationAdminRepositoryProvider);
      if (supplier == null) {
        await repo.createSupplier({
          'name': nameController.text.trim(),
          'code': codeController.text.trim(),
          'phone': phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          'address': addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
        });
      } else {
        await repo.updateSupplier(supplier['id'] as int, {
          'name': nameController.text.trim(),
          'phone': phoneController.text.trim().isEmpty
              ? null
              : phoneController.text.trim(),
          'address': addressController.text.trim().isEmpty
              ? null
              : addressController.text.trim(),
        });
      }
    }, successMessage: 'Supplier details saved.');
  }

  Future<void> _showPosProductDialog({
    required int stationId,
    Map<String, dynamic>? product,
  }) async {
    final nameController =
        TextEditingController(text: product?['name']?.toString() ?? '');
    final codeController =
        TextEditingController(text: product?['code']?.toString() ?? '');
    final categoryController = TextEditingController(
      text: product?['category']?.toString() ?? 'Lubricant',
    );
    final moduleController = TextEditingController(
      text: product?['module']?.toString() ?? 'lubricant',
    );
    final buyingPriceController = TextEditingController(
      text: ((product?['buying_price'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2),
    );
    final priceController = TextEditingController(
      text: ((product?['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
    );
    final stockController = TextEditingController(
      text:
          ((product?['stock_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(0),
    );
    bool trackInventory = product?['track_inventory'] as bool? ?? true;
    bool isActive = product?['is_active'] as bool? ?? true;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(product == null ? 'Add inventory item' : 'Edit inventory item'),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Item name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeController,
                    enabled: product == null,
                    decoration: const InputDecoration(labelText: 'Item code'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: categoryController,
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: moduleController,
                    decoration: const InputDecoration(
                      labelText: 'Module',
                      helperText: 'Use values like lubricant or shop.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Selling price'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyingPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Buying price'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: stockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Stock quantity'),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: trackInventory,
                    onChanged: (value) =>
                        setLocalState(() => trackInventory = value),
                    title: const Text('Track inventory'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isActive,
                    onChanged: (value) => setLocalState(() => isActive = value),
                    title: const Text('Active'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.text('cancelLabel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.text('saveLabel')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    await _performAction(() async {
      final payload = {
        'name': nameController.text.trim(),
        'code': codeController.text.trim(),
        'category': categoryController.text.trim(),
        'module': moduleController.text.trim(),
        'buying_price': double.tryParse(buyingPriceController.text.trim()) ?? 0,
        'price': double.tryParse(priceController.text.trim()) ?? 0,
        'stock_quantity': double.tryParse(stockController.text.trim()) ?? 0,
        'track_inventory': trackInventory,
        'is_active': isActive,
        'station_id': stationId,
      };
      final repo = ref.read(stationAdminRepositoryProvider);
      if (product == null) {
        await repo.createPosProduct(payload);
      } else {
        await repo.updatePosProduct(product['id'] as int, payload);
      }
    }, successMessage: 'Inventory pricing saved.');
  }

  Future<void> _showCreateTankerDialog({
    required int stationId,
    required List<Map<String, dynamic>> fuelTypes,
  }) async {
    final settingsSavedMessage = context.l10n.text('settingsSavedMessage');
    final registrationController = TextEditingController();
    final nameController = TextEditingController();
    final capacityController = TextEditingController();
    final ownerNameController = TextEditingController();
    String ownershipType = 'owned';
    final compartmentCodeControllers = <TextEditingController>[
      TextEditingController(text: 'C1'),
    ];
    final compartmentNameControllers = <TextEditingController>[
      TextEditingController(text: 'Compartment 1'),
    ];
    final compartmentCapacityControllers = <TextEditingController>[
      TextEditingController(),
    ];

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(context.l10n.text('createTankerLabel')),
          content: SizedBox(
            width: 680,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: registrationController, decoration: InputDecoration(labelText: context.l10n.text('registrationNumber'))),
                  const SizedBox(height: 12),
                  TextField(controller: nameController, decoration: InputDecoration(labelText: context.l10n.text('displayName'))),
                  const SizedBox(height: 12),
                  TextField(controller: capacityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: context.l10n.text('capacity'))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: ownershipType,
                    items: const [
                      DropdownMenuItem(value: 'owned', child: Text('owned')),
                      DropdownMenuItem(value: 'hired', child: Text('hired')),
                      DropdownMenuItem(value: 'external', child: Text('external')),
                    ],
                    onChanged: (value) => setLocalState(() => ownershipType = value ?? 'owned'),
                    decoration: InputDecoration(labelText: context.l10n.text('ownershipTypeLabel')),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: ownerNameController, decoration: InputDecoration(labelText: context.l10n.text('ownerNameLabel'))),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.l10n.text('compartmentsLabel'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < compartmentCodeControllers.length; i++) ...[
                    Row(
                      children: [
                        Expanded(child: TextField(controller: compartmentCodeControllers[i], decoration: InputDecoration(labelText: '${context.l10n.text('code')} ${i + 1}'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: compartmentNameControllers[i], decoration: InputDecoration(labelText: '${context.l10n.text('displayName')} ${i + 1}'))),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(controller: compartmentCapacityControllers[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: '${context.l10n.text('capacity')} ${i + 1}'))),
                        IconButton(
                          onPressed: compartmentCodeControllers.length == 1
                              ? null
                              : () {
                                  setLocalState(() {
                                    compartmentCodeControllers.removeAt(i);
                                    compartmentNameControllers.removeAt(i);
                                    compartmentCapacityControllers.removeAt(i);
                                  });
                                },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setLocalState(() {
                          final next = compartmentCodeControllers.length + 1;
                          compartmentCodeControllers.add(TextEditingController(text: 'C$next'));
                          compartmentNameControllers.add(TextEditingController(text: 'Compartment $next'));
                          compartmentCapacityControllers.add(TextEditingController());
                        });
                      },
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(context.l10n.text('addCompartmentLabel')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(context.l10n.text('cancelLabel'))),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(context.l10n.text('saveLabel'))),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    final compartments = <Map<String, dynamic>>[];
    for (var i = 0; i < compartmentCodeControllers.length; i++) {
      compartments.add({
        'code': compartmentCodeControllers[i].text.trim(),
        'name': compartmentNameControllers[i].text.trim(),
        'capacity':
            double.tryParse(compartmentCapacityControllers[i].text.trim()) ?? 0,
        'position': i + 1,
        'is_active': true,
      });
    }

    await _performAction(() async {
      await ref.read(stationAdminRepositoryProvider).createTanker({
        'registration_no': registrationController.text.trim(),
        'name': nameController.text.trim(),
        'capacity': double.tryParse(capacityController.text.trim()) ?? 0,
        'ownership_type': ownershipType,
        'owner_name': ownerNameController.text.trim().isEmpty
            ? null
            : ownerNameController.text.trim(),
        'status': 'active',
        'station_id': stationId,
        'compartments': compartments,
      });
    }, successMessage: settingsSavedMessage);
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final resolvedAction = action;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (resolvedAction != null) ...[
                  resolvedAction,
                ],
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _WorkflowCard extends StatelessWidget {
  const _WorkflowCard({
    required this.title,
    required this.description,
    required this.onOpen,
  });

  final String title;
  final String description;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(description),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Open workflow'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    this.width = 220,
  });

  final String title;
  final String value;
  final String? subtitle;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}

class _StationAdminBundle {
  const _StationAdminBundle({
    required this.dashboard,
    required this.station,
    required this.stationModules,
    required this.roles,
    required this.users,
    required this.customers,
    required this.employeeProfiles,
    required this.fuelTypes,
    required this.tanks,
    required this.dispensers,
    required this.nozzles,
    required this.suppliers,
    required this.purchases,
    required this.posProducts,
    required this.invoiceProfile,
    required this.documentTemplates,
    required this.tankerSummary,
    required this.tankers,
    required this.tankerTrips,
  });

  final Map<String, dynamic> dashboard;
  final Map<String, dynamic> station;
  final List<Map<String, dynamic>> stationModules;
  final List<Map<String, dynamic>> roles;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> customers;
  final List<Map<String, dynamic>> employeeProfiles;
  final List<Map<String, dynamic>> fuelTypes;
  final List<Map<String, dynamic>> tanks;
  final List<Map<String, dynamic>> dispensers;
  final List<Map<String, dynamic>> nozzles;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> purchases;
  final List<Map<String, dynamic>> posProducts;
  final Map<String, dynamic> invoiceProfile;
  final List<Map<String, dynamic>> documentTemplates;
  final Map<String, dynamic> tankerSummary;
  final List<Map<String, dynamic>> tankers;
  final List<Map<String, dynamic>> tankerTrips;
}

class _DateRange {
  const _DateRange(this.start, this.end);

  final DateTime start;
  final DateTime end;
}
