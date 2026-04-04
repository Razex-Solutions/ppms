import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/utils/document_file_actions.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _formKey = GlobalKey<FormState>();
  final _rateController = TextEditingController();
  final _closingMeterController = TextEditingController();
  final _shiftNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _nozzles = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _recentSales = const [];

  int? _selectedStationId;
  int? _selectedNozzleId;
  int? _selectedCustomerId;
  String _saleType = 'cash';

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

  int? _validSelection(
    int? selectedId,
    List<Map<String, dynamic>> items,
  ) {
    if (selectedId == null) {
      return null;
    }
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
    _loadInitialData();
  }

  @override
  void dispose() {
    _rateController.dispose();
    _closingMeterController.dispose();
    _shiftNameController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stations = _dedupeById(
        List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchStations()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ),
      );

      final preferredStationId = _validSelection(
        _selectedStationId ??
            widget.sessionController.currentUser?['station_id'] as int?,
        stations,
      );
      final stationId =
          preferredStationId ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      final nozzles = stationId == null
          ? const <Map<String, dynamic>>[]
          : _dedupeById(List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNozzles(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            ));
      final customers = stationId == null
          ? const <Map<String, dynamic>>[]
          : _dedupeById(List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            ));
      final fuelTypes = _dedupeById(List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelTypes()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      ));
      final recentSales = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchFuelSales(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      final selectedNozzleId = _validSelection(_selectedNozzleId, nozzles) ??
          (nozzles.isNotEmpty ? nozzles.first['id'] as int : null);
      final selectedCustomerId =
          _saleType == 'credit'
              ? _validSelection(_selectedCustomerId, customers)
              : null;

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _nozzles = nozzles;
        _customers = customers;
        _fuelTypes = fuelTypes;
        _recentSales = recentSales;
        _selectedNozzleId = selectedNozzleId;
        _selectedCustomerId = selectedCustomerId;
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

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) {
      return;
    }
    setState(() {
      _isLoading = true;
      _selectedStationId = stationId;
      _errorMessage = null;
    });
    try {
      final nozzles = _dedupeById(List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchNozzles(
          stationId: stationId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      ));
      final customers = _dedupeById(List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchCustomers(
          stationId: stationId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      ));
      final recentSales = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelSales(
          stationId: stationId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      );
      if (!mounted) {
        return;
      }
      final selectedNozzleId = _validSelection(_selectedNozzleId, nozzles) ??
          (nozzles.isNotEmpty ? nozzles.first['id'] as int : null);
      final selectedCustomerId =
          _saleType == 'credit'
              ? _validSelection(_selectedCustomerId, customers)
              : null;

      setState(() {
        _nozzles = nozzles;
        _customers = customers;
        _recentSales = recentSales;
        _selectedNozzleId = selectedNozzleId;
        _selectedCustomerId = selectedCustomerId;
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

  Future<void> _submitSale() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedNozzle = _selectedNozzle;
    final stationId = _selectedStationId;
    if (selectedNozzle == null || stationId == null) {
      setState(() {
        _feedbackMessage =
            'Select a station and nozzle before submitting a sale.';
      });
      return;
    }
    if (_saleType == 'credit' && _selectedCustomerId == null) {
      setState(() {
        _feedbackMessage = 'Select a customer for credit sales.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    try {
      final payload = <String, dynamic>{
        'station_id': stationId,
        'nozzle_id': selectedNozzle['id'],
        'fuel_type_id': selectedNozzle['fuel_type_id'],
        'closing_meter': double.parse(_closingMeterController.text.trim()),
        'rate_per_liter': double.parse(_rateController.text.trim()),
        'sale_type': _saleType,
        'shift_name': _shiftNameController.text.trim().isEmpty
            ? null
            : _shiftNameController.text.trim(),
      };
      if (_selectedCustomerId != null) {
        payload['customer_id'] = _selectedCustomerId;
      }

      final createdSale = await widget.sessionController.createFuelSale(
        payload,
      );
      final recentSales = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelSales(
          stationId: stationId,
        )).map((item) => Map<String, dynamic>.from(item as Map)),
      );

      if (!mounted) {
        return;
      }

      _closingMeterController.clear();
      _shiftNameController.clear();
      setState(() {
        _recentSales = recentSales;
        _feedbackMessage =
            'Sale #${createdSale['id']} saved: ${_formatNumber(createdSale['quantity'])}L for ${_formatNumber(createdSale['total_amount'])}.';
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

  Future<void> _previewSaleDocument(Map<String, dynamic> sale) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final document = await widget.sessionController.fetchFuelSaleDocument(
        saleId: sale['id'] as int,
      );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      await _showSaleDocumentDialog(sale, document);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showSaleDocumentDialog(
    Map<String, dynamic> sale,
    Map<String, dynamic> document,
  ) async {
    final recipientNameController = TextEditingController(
      text: document['recipient_name'] as String? ?? '',
    );
    final recipientContactController = TextEditingController(
      text: document['recipient_contact'] as String? ?? '',
    );
    var channel = 'print';
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Sale Invoice #${sale['id']}'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(document['title'] as String? ?? 'Fuel Sale Invoice'),
                    const SizedBox(height: 8),
                    Text('Document #: ${document['document_number'] ?? '-'}'),
                    Text('Recipient: ${document['recipient_name'] ?? '-'}'),
                    Text('Total: ${_formatNumber(document['total_amount'])}'),
                    const SizedBox(height: 12),
                    SelectableText(
                      (document['rendered_html'] as String? ?? '')
                          .replaceAll(RegExp(r'<[^>]*>'), ' ')
                          .replaceAll('&nbsp;', ' ')
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: recipientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: recipientContactController,
                      decoration: const InputDecoration(
                        labelText: 'Recipient Contact',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: channel,
                      decoration: const InputDecoration(labelText: 'Channel'),
                      items: const [
                        DropdownMenuItem(value: 'print', child: Text('Print')),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(value: 'sms', child: Text('SMS')),
                        DropdownMenuItem(
                          value: 'whatsapp',
                          child: Text('WhatsApp'),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          channel = value ?? 'print';
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
              TextButton(
                onPressed: () async {
                  final bytes = await widget.sessionController
                      .downloadFuelSalePdf(saleId: sale['id'] as int);
                  final path = await writeBytesToLocalDocumentFile(
                    'fuel_sale_${sale['id']}.pdf',
                    bytes,
                  );
                  if (!mounted) return;
                  await Clipboard.setData(ClipboardData(text: path));
                  if (!mounted) return;
                  setState(() {
                    _feedbackMessage = 'Sale invoice saved to $path';
                  });
                },
                child: const Text('Save PDF'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final bytes = await widget.sessionController
                      .downloadFuelSalePdf(saleId: sale['id'] as int);
                  final path = await writeBytesToLocalDocumentFile(
                    'fuel_sale_${sale['id']}.pdf',
                    bytes,
                  );
                  if (!mounted) return;
                  await openSavedDocument(path);
                  if (!mounted) return;
                  setState(() {
                    _feedbackMessage = 'Opened $path';
                  });
                },
                child: const Text('Open PDF'),
              ),
              FilledButton(
                onPressed: () async {
                  final navigator = Navigator.of(dialogContext);
                  try {
                    final dispatch = await widget.sessionController
                        .sendFuelSaleDocument(
                          saleId: sale['id'] as int,
                          payload: {
                            'channel': channel,
                            'format': 'pdf',
                            'recipient_name': _emptyToNull(
                              recipientNameController.text,
                            ),
                            'recipient_contact': _emptyToNull(
                              recipientContactController.text,
                            ),
                          },
                        );
                    if (!mounted) return;
                    navigator.pop();
                    setState(() {
                      _feedbackMessage =
                          'Dispatch queued via ${dispatch['channel']} with status ${dispatch['status']}.';
                    });
                  } on ApiException catch (error) {
                    if (!mounted) return;
                    setState(() {
                      _errorMessage = error.message;
                    });
                  }
                },
                child: const Text('Send'),
              ),
            ],
          ),
        ),
      );
    } finally {
      recipientNameController.dispose();
      recipientContactController.dispose();
    }
  }

  Map<String, dynamic>? get _selectedNozzle {
    for (final nozzle in _nozzles) {
      if (nozzle['id'] == _selectedNozzleId) {
        return nozzle;
      }
    }
    return null;
  }

  String _fuelTypeName(int fuelTypeId) {
    final match = _fuelTypes.where((fuelType) => fuelType['id'] == fuelTypeId);
    if (match.isEmpty) {
      return 'Fuel $fuelTypeId';
    }
    return match.first['name'] as String? ?? 'Fuel $fuelTypeId';
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

  bool get _canCreateSales => _hasAction('fuel_sales', 'create');
  bool get _canReadSales =>
      _canCreateSales || _hasAction('fuel_sales', 'reverse');

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _stations.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final selectedNozzle = _selectedNozzle;
    final isCreditSale = _saleType == 'credit';
    final canCreateSales = _canCreateSales;
    final canReadSales = _canReadSales;

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ResponsiveSplit(
            breakpoint: 1150,
            primary: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forecourt Sales',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        canCreateSales
                            ? 'Create fuel sales directly against the live PPMS backend. This screen is shared for desktop and mobile growth.'
                            : 'Review recent forecourt sales for the selected station. This role can inspect sales activity but cannot post new sales.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      if (!canCreateSales) ...[
                        _buildHintBanner(
                          context,
                          'This role has read access to sales only. Use a Manager, Operator, or Admin login to create new fuel sales.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_stations.isEmpty) ...[
                        _buildHintBanner(
                          context,
                          'No stations are available for this user yet.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final field = DropdownButtonFormField<int>(
                            key: ValueKey<String>(
                              'station-${_selectedStationId ?? 'none'}',
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
                            onChanged: canReadSales
                                ? (value) => _changeStation(value)
                                : null,
                          );
                          return constraints.maxWidth < 500
                              ? field
                              : SizedBox(width: 420, child: field);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'nozzle-${_selectedNozzleId ?? 'none'}',
                        ),
                        initialValue: _selectedNozzleId,
                        decoration: const InputDecoration(labelText: 'Nozzle'),
                        items: [
                          for (final nozzle in _nozzles)
                            DropdownMenuItem<int>(
                              value: nozzle['id'] as int,
                              child: Text(
                                '${nozzle['code']} - ${nozzle['name']}',
                              ),
                            ),
                        ],
                        onChanged: canCreateSales
                            ? (value) {
                                setState(() {
                                  _selectedNozzleId = value;
                                });
                              }
                            : null,
                        validator: (value) =>
                            value == null ? 'Select a nozzle' : null,
                      ),
                      if (_nozzles.isEmpty) ...[
                        const SizedBox(height: 8),
                        _buildHintBanner(
                          context,
                          'No nozzles found for this station. Create inventory first in the Inventory workspace.',
                        ),
                      ],
                      if (selectedNozzle != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Fuel: ${_fuelTypeName(selectedNozzle['fuel_type_id'] as int)} • '
                          'Current meter: ${_formatNumber(selectedNozzle['meter_reading'])} • '
                          'Segment start: ${_formatNumber(selectedNozzle['current_segment_start_reading'])}',
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        key: ValueKey<String>('sale-type-$_saleType'),
                        initialValue: _saleType,
                        decoration: const InputDecoration(
                          labelText: 'Sale Type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'cash', child: Text('Cash')),
                          DropdownMenuItem(
                            value: 'credit',
                            child: Text('Credit'),
                          ),
                        ],
                        onChanged: canCreateSales
                            ? (value) {
                                setState(() {
                                  _saleType = value ?? 'cash';
                                  if (_saleType != 'credit') {
                                    _selectedCustomerId = null;
                                  }
                                });
                              }
                            : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int?>(
                        key: ValueKey<String>(
                          'customer-${_selectedCustomerId ?? 'none'}',
                        ),
                        initialValue: _selectedCustomerId,
                        decoration: const InputDecoration(
                          labelText: 'Customer',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Walk-in / cash customer'),
                          ),
                          for (final customer in _customers)
                            DropdownMenuItem<int?>(
                              value: customer['id'] as int,
                              child: Text(
                                '${customer['code']} - ${customer['name']}',
                              ),
                            ),
                        ],
                        onChanged: canCreateSales && isCreditSale
                            ? (value) {
                                setState(() {
                                  _selectedCustomerId = value;
                                });
                              }
                            : null,
                      ),
                      if (isCreditSale && _customers.isEmpty) ...[
                        const SizedBox(height: 8),
                        _buildHintBanner(
                          context,
                          'No customers exist for credit sales yet. Add one in the Parties workspace.',
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _rateController,
                        enabled: canCreateSales,
                        decoration: const InputDecoration(
                          labelText: 'Rate Per Liter',
                          helperText: 'Enter the selling rate for this sale.',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the rate per liter';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Enter a valid rate';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _closingMeterController,
                        enabled: canCreateSales,
                        decoration: const InputDecoration(
                          labelText: 'Closing Meter',
                          helperText:
                              'Must be greater than the nozzle’s current segment start.',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter the closing meter';
                          }
                          if (double.tryParse(value.trim()) == null) {
                            return 'Enter a valid closing meter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _shiftNameController,
                        enabled: canCreateSales,
                        decoration: const InputDecoration(
                          labelText: 'Shift Name (optional)',
                        ),
                      ),
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
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting || !canCreateSales
                            ? null
                            : _submitSale,
                        icon: _isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Save Fuel Sale'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            secondary: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Sales',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      canReadSales
                          ? 'Latest sales for the selected station. Pull to refresh or save a new sale to update this list.'
                          : 'This role does not have access to sales history.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    if (!canReadSales)
                      _buildEmptyState(
                        context,
                        'No sales access for this role.',
                        'Ask an administrator to grant fuel sales read access if this screen should show station sales.',
                      )
                    else if (_recentSales.isEmpty)
                      _buildEmptyState(
                        context,
                        'No fuel sales found for this station yet.',
                        'Create the first sale from the form to start the daily sales history.',
                      )
                    else
                      for (final sale in _recentSales)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.receipt_long_outlined),
                          title: Text(
                            '${_formatNumber(sale['quantity'])}L • ${_formatNumber(sale['total_amount'])}',
                          ),
                          subtitle: Text(
                            'Nozzle ${sale['nozzle_id']} • ${sale['sale_type']} • '
                            '${(sale['created_at'] as String?)?.replaceFirst('T', ' ').substring(0, 19) ?? ''}',
                          ),
                          trailing: Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (sale['shift_name'] != null)
                                Chip(label: Text(sale['shift_name'] as String)),
                              IconButton(
                                tooltip: 'Invoice Actions',
                                onPressed: _isSubmitting
                                    ? null
                                    : () => _previewSaleDocument(sale),
                                icon: const Icon(Icons.description_outlined),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }

  Widget _buildHintBanner(BuildContext context, String message) {
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
}
