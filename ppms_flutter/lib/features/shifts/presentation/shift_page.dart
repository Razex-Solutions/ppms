import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

class ShiftPage extends StatefulWidget {
  const ShiftPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<ShiftPage> createState() => _ShiftPageState();
}

class _ShiftPageState extends State<ShiftPage> {
  final _openFormKey = GlobalKey<FormState>();
  final _closeFormKey = GlobalKey<FormState>();
  final _initialCashController = TextEditingController(text: '0');
  final _openNotesController = TextEditingController();
  final _actualCashController = TextEditingController();
  final _closeNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isOpening = false;
  bool _isClosing = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _shifts = const [];
  int? _selectedStationId;
  String _statusFilter = 'all';
  int? _selectedShiftId;

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadShiftWorkspace();
  }

  @override
  void dispose() {
    _initialCashController.dispose();
    _openNotesController.dispose();
    _actualCashController.dispose();
    _closeNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadShiftWorkspace() async {
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

      final shifts = !_showShiftWorkspace || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchShifts(
                stationId: stationId,
                status: _statusFilter == 'all' ? null : _statusFilter,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _shifts = shifts;
        _selectedShiftId = _resolveSelectedShiftId(shifts);
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

  int? _resolveSelectedShiftId(List<Map<String, dynamic>> shifts) {
    if (_selectedShiftId != null &&
        shifts.any((shift) => shift['id'] == _selectedShiftId)) {
      return _selectedShiftId;
    }
    final openShift = _currentOpenShiftFrom(shifts);
    if (openShift != null) {
      return openShift['id'] as int;
    }
    if (shifts.isNotEmpty) {
      return shifts.first['id'] as int;
    }
    return null;
  }

  Map<String, dynamic>? _currentOpenShiftFrom(
    List<Map<String, dynamic>> shifts,
  ) {
    final currentUserId = widget.sessionController.currentUser?['id'];
    for (final shift in shifts) {
      if (shift['status'] == 'open' && shift['user_id'] == currentUserId) {
        return shift;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedShift {
    for (final shift in _shifts) {
      if (shift['id'] == _selectedShiftId) {
        return shift;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _currentOpenShift => _currentOpenShiftFrom(_shifts);

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) {
      return;
    }
    setState(() {
      _selectedStationId = stationId;
    });
    await _loadShiftWorkspace();
  }

  Future<void> _changeStatusFilter(String? value) async {
    setState(() {
      _statusFilter = value ?? 'all';
    });
    await _loadShiftWorkspace();
  }

  Future<void> _openShift() async {
    if (!_openFormKey.currentState!.validate()) {
      return;
    }
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station before opening a shift.';
      });
      return;
    }

    setState(() {
      _isOpening = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final shift = await widget.sessionController.openShift({
        'station_id': stationId,
        'initial_cash': double.parse(_initialCashController.text.trim()),
        'notes': _emptyToNull(_openNotesController.text),
      });

      if (!mounted) {
        return;
      }

      _openNotesController.clear();
      _initialCashController.text = '0';
      await _loadShiftWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Shift #${shift['id']} opened successfully for station $stationId.';
        _isOpening = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isOpening = false;
      });
    }
  }

  Future<void> _closeShift() async {
    if (!_closeFormKey.currentState!.validate()) {
      return;
    }
    final shift = _selectedShift;
    if (shift == null) {
      setState(() {
        _feedbackMessage = 'Select a shift to close.';
      });
      return;
    }

    setState(() {
      _isClosing = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final updatedShift = await widget.sessionController.closeShift(
        shiftId: shift['id'] as int,
        payload: {
          'actual_cash_collected': double.parse(
            _actualCashController.text.trim(),
          ),
          'notes': _emptyToNull(_closeNotesController.text),
        },
      );

      if (!mounted) {
        return;
      }

      _actualCashController.clear();
      _closeNotesController.clear();
      await _loadShiftWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Shift #${updatedShift['id']} closed with variance ${_formatNumber(updatedShift['difference'])}.';
        _isClosing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isClosing = false;
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

  bool get _canOpenShifts => _hasAction('shifts', 'open');
  bool get _canCloseShifts => _hasAction('shifts', 'close');
  bool get _canReadShifts => _canOpenShifts || _canCloseShifts;
  bool get _showShiftWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['shifts'],
    permissionModules: const ['shifts'],
    hideWhenModulesOff: true,
  );

  Map<String, String> _sectionMeta({
    required bool canOpenShifts,
    required bool canCloseShifts,
  }) {
    if (canOpenShifts || canCloseShifts) {
      return const {
        'title': 'Shift Operations',
        'subtitle':
            'Run shift openings, cash expectations, and closeouts from a single console built for station operations.',
      };
    }
    return const {
      'title': 'Shift Review',
      'subtitle':
          'Inspect shift performance and cash expectations without changing operational state.',
    };
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
    if (!_showShiftWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Shifts are turned off for this scope, so the shift console stays hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _stations.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final openShift = _currentOpenShift;
    final selectedShift = _selectedShift;
    final canOpenShifts = _canOpenShifts;
    final canCloseShifts = _canCloseShifts;
    final canReadShifts = _canReadShifts;
    final sectionMeta = _sectionMeta(
      canOpenShifts: canOpenShifts,
      canCloseShifts: canCloseShifts,
    );
    final openCount = _shifts
        .where((shift) => shift['status'] == 'open')
        .length;
    final closedCount = _shifts
        .where((shift) => shift['status'] == 'closed')
        .length;
    final expectedCash = _shifts.fold<double>(0, (total, shift) {
      final value = shift['expected_cash'];
      return total + (value is num ? value.toDouble() : 0);
    });
    final cashSales = _shifts.fold<double>(0, (total, shift) {
      final value = shift['total_sales_cash'];
      return total + (value is num ? value.toDouble() : 0);
    });

    return RefreshIndicator(
      onRefresh: _loadShiftWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Daily Control',
            title: canOpenShifts || canCloseShifts
                ? 'Shift Command Center'
                : 'Shift Review Board',
            subtitle: sectionMeta['subtitle']!,
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                DashboardMetricTile(
                  label: 'Open Shifts',
                  value: '$openCount',
                  caption: 'Current selection',
                  icon: Icons.schedule_outlined,
                ),
                DashboardMetricTile(
                  label: 'Closed Shifts',
                  value: '$closedCount',
                  caption: 'Loaded history',
                  icon: Icons.task_alt_outlined,
                ),
                DashboardMetricTile(
                  label: 'Expected Cash',
                  value: _formatNumber(expectedCash),
                  caption: 'Across loaded shifts',
                  icon: Icons.account_balance_wallet_outlined,
                ),
                DashboardMetricTile(
                  label: 'Cash Sales',
                  value: _formatNumber(cashSales),
                  caption: 'Loaded shift totals',
                  icon: Icons.point_of_sale_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: sectionMeta['title']!,
            subtitle:
                'Use this console to hand over cash cleanly, monitor live shift state, and review station-level activity without leaving the workflow.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildStatusChip(
                  context,
                  Icons.store_outlined,
                  _selectedStationId == null
                      ? 'No station selected'
                      : 'Station #$_selectedStationId',
                ),
                _buildStatusChip(
                  context,
                  Icons.lock_open_outlined,
                  openShift == null
                      ? 'No open shift for this user'
                      : 'Open shift #${openShift['id']}',
                ),
                _buildStatusChip(
                  context,
                  Icons.visibility_outlined,
                  canReadShifts ? 'History visible' : 'No history access',
                ),
                _buildStatusChip(
                  context,
                  Icons.manage_accounts_outlined,
                  canOpenShifts || canCloseShifts
                      ? 'Operational controls enabled'
                      : 'Review mode only',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Console',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canOpenShifts || canCloseShifts
                              ? 'Open, monitor, and close station shifts against the live PPMS backend.'
                              : 'Review station shifts and their cash expectations for the selected station.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (!canOpenShifts && !canCloseShifts) ...[
                          _buildPermissionNotice(
                            context,
                            'This role can review shifts but cannot open or close them.',
                          ),
                          const SizedBox(height: 20),
                        ],
                        DropdownButtonFormField<int>(
                          key: ValueKey<String>(
                            'shift-station-${_selectedStationId ?? 'none'}',
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
                          onChanged: canReadShifts ? _changeStation : null,
                        ),
                        const SizedBox(height: 20),
                        if (openShift != null) ...[
                          _buildOpenShiftSummary(context, openShift),
                          const SizedBox(height: 20),
                        ],
                        Form(
                          key: _openFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Open New Shift',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (!canOpenShifts) ...[
                                const SizedBox(height: 8),
                                _buildPermissionNotice(
                                  context,
                                  'Opening shifts is disabled for this role.',
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _initialCashController,
                                enabled: canOpenShifts,
                                decoration: const InputDecoration(
                                  labelText: 'Initial Cash',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter the initial cash amount';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Enter a valid cash amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _openNotesController,
                                enabled: canOpenShifts,
                                decoration: const InputDecoration(
                                  labelText: 'Open Notes (optional)',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _isOpening || !canOpenShifts
                                    ? null
                                    : _openShift,
                                icon: _isOpening
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_open_outlined),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Open Shift'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _closeFormKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Close Shift',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              if (!canCloseShifts) ...[
                                const SizedBox(height: 8),
                                _buildPermissionNotice(
                                  context,
                                  'Closing shifts is disabled for this role.',
                                ),
                              ],
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                key: ValueKey<String>(
                                  'close-shift-${_selectedShiftId ?? 'none'}',
                                ),
                                initialValue: _selectedShiftId,
                                decoration: const InputDecoration(
                                  labelText: 'Shift',
                                ),
                                items: [
                                  for (final shift in _shifts)
                                    DropdownMenuItem<int>(
                                      value: shift['id'] as int,
                                      child: Text(
                                        '#${shift['id']} • ${shift['status']} • ${_formatDateTime(shift['start_time'])}',
                                      ),
                                    ),
                                ],
                                onChanged: canReadShifts
                                    ? (value) {
                                        setState(() {
                                          _selectedShiftId = value;
                                        });
                                      }
                                    : null,
                              ),
                              if (selectedShift != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Expected cash: ${_formatNumber(selectedShift['expected_cash'])} • '
                                  'Cash sales: ${_formatNumber(selectedShift['total_sales_cash'])} • '
                                  'Credit sales: ${_formatNumber(selectedShift['total_sales_credit'])}',
                                ),
                              ],
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _actualCashController,
                                enabled: canCloseShifts,
                                decoration: const InputDecoration(
                                  labelText: 'Actual Cash Collected',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Enter the actual cash collected';
                                  }
                                  if (double.tryParse(value.trim()) == null) {
                                    return 'Enter a valid cash amount';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _closeNotesController,
                                enabled: canCloseShifts,
                                decoration: const InputDecoration(
                                  labelText: 'Close Notes (optional)',
                                ),
                                maxLines: 2,
                              ),
                              const SizedBox(height: 16),
                              FilledButton.tonalIcon(
                                onPressed:
                                    _isClosing ||
                                        !canCloseShifts ||
                                        selectedShift == null ||
                                        selectedShift['status'] != 'open'
                                    ? null
                                    : _closeShift,
                                icon: _isClosing
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.task_alt_outlined),
                                label: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text('Close Selected Shift'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null || _feedbackMessage != null)
                          const SizedBox(height: 20),
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
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shift Activity',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          canReadShifts
                              ? 'Recent shifts for the selected station with quick operational totals.'
                              : 'This role does not have access to shift history.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('shift-filter-$_statusFilter'),
                          initialValue: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status Filter',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'all',
                              child: Text('All shifts'),
                            ),
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('Open shifts'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('Closed shifts'),
                            ),
                          ],
                          onChanged: canReadShifts ? _changeStatusFilter : null,
                        ),
                        const SizedBox(height: 16),
                        if (!canReadShifts)
                          const Text('No shift access for this role.')
                        else if (_shifts.isEmpty)
                          const Text('No shifts found for this filter yet.')
                        else
                          for (final shift in _shifts)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                shift['status'] == 'open'
                                    ? Icons.schedule_outlined
                                    : Icons.check_circle_outline,
                              ),
                              title: Text(
                                '#${shift['id']} • ${shift['status']} • ${_formatDateTime(shift['start_time'])}',
                              ),
                              subtitle: Text(
                                'Expected ${_formatNumber(shift['expected_cash'])} • '
                                'Cash ${_formatNumber(shift['total_sales_cash'])} • '
                                'Credit ${_formatNumber(shift['total_sales_credit'])}',
                              ),
                              trailing: shift['difference'] != null
                                  ? Chip(
                                      label: Text(
                                        _formatNumber(shift['difference']),
                                      ),
                                    )
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedShiftId = shift['id'] as int;
                                });
                              },
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpenShiftSummary(
    BuildContext context,
    Map<String, dynamic> shift,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current Open Shift',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Shift #${shift['id']} • Started ${_formatDateTime(shift['start_time'])}',
          ),
          const SizedBox(height: 4),
          Text(
            'Initial cash ${_formatNumber(shift['initial_cash'])} • '
            'Expected cash ${_formatNumber(shift['expected_cash'])}',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, IconData icon, String label) {
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
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  String _formatDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return 'Unknown';
    }
    return value.replaceFirst('T', ' ').substring(0, 16);
  }
}
