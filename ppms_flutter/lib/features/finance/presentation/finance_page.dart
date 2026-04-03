import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/utils/document_file_actions.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

enum _FinanceSection { purchases, customerPayments, supplierPayments }

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final _purchaseQuantityController = TextEditingController();
  final _purchaseRateController = TextEditingController();
  final _purchaseReferenceController = TextEditingController();
  final _purchaseNotesController = TextEditingController();
  final _customerAmountController = TextEditingController();
  final _customerReferenceController = TextEditingController();
  final _customerNotesController = TextEditingController();
  final _supplierAmountController = TextEditingController();
  final _supplierReferenceController = TextEditingController();
  final _supplierNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isReversing = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _FinanceSection _section = _FinanceSection.purchases;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _tanks = const [];
  List<Map<String, dynamic>> _fuelTypes = const [];
  List<Map<String, dynamic>> _purchases = const [];
  List<Map<String, dynamic>> _customerPayments = const [];
  List<Map<String, dynamic>> _supplierPayments = const [];

  int? _selectedStationId;
  int? _selectedSupplierId;
  int? _selectedCustomerId;
  int? _selectedTankId;
  int? _selectedFuelTypeId;
  int? _selectedPurchaseId;
  int? _selectedCustomerPaymentId;
  int? _selectedSupplierPaymentId;
  String _customerPaymentMethod = 'cash';
  String _supplierPaymentMethod = 'cash';

  @override
  void initState() {
    super.initState();
    _loadFinanceWorkspace();
  }

  @override
  void dispose() {
    _purchaseQuantityController.dispose();
    _purchaseRateController.dispose();
    _purchaseReferenceController.dispose();
    _purchaseNotesController.dispose();
    _customerAmountController.dispose();
    _customerReferenceController.dispose();
    _customerNotesController.dispose();
    _supplierAmountController.dispose();
    _supplierReferenceController.dispose();
    _supplierNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadFinanceWorkspace() async {
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

      final suppliers = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchSuppliers()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final customers = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final tanks = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchTanks(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final fuelTypes = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchFuelTypes()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final purchases = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchPurchases(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final customerPayments = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomerPayments(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final supplierPayments = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchSupplierPayments(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      final defaultTankId = _selectedTankId ?? _firstId(tanks);
      final resolvedFuelTypeId =
          _selectedFuelTypeId ??
          tanks.cast<Map<String, dynamic>?>().firstWhere(
                (tank) => tank?['id'] == defaultTankId,
                orElse: () => null,
              )?['fuel_type_id']
              as int? ??
          _firstId(fuelTypes);

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _suppliers = suppliers;
        _customers = customers;
        _tanks = tanks;
        _fuelTypes = fuelTypes;
        _purchases = purchases;
        _customerPayments = customerPayments;
        _supplierPayments = supplierPayments;
        _selectedSupplierId = _selectedSupplierId ?? _firstId(suppliers);
        _selectedCustomerId = _selectedCustomerId ?? _firstId(customers);
        _selectedTankId = defaultTankId;
        _selectedFuelTypeId = resolvedFuelTypeId;
        _selectedPurchaseId = _selectedPurchaseId ?? _firstId(purchases);
        _selectedCustomerPaymentId =
            _selectedCustomerPaymentId ?? _firstId(customerPayments);
        _selectedSupplierPaymentId =
            _selectedSupplierPaymentId ?? _firstId(supplierPayments);
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

  int? _firstId(List<Map<String, dynamic>> items) {
    if (items.isEmpty) {
      return null;
    }
    return items.first['id'] as int;
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) {
      return;
    }
    setState(() {
      _selectedStationId = stationId;
      _selectedCustomerId = null;
      _selectedTankId = null;
      _selectedPurchaseId = null;
      _selectedCustomerPaymentId = null;
      _selectedSupplierPaymentId = null;
    });
    await _loadFinanceWorkspace();
  }

  Future<void> _submitPurchase() async {
    final supplierId = _selectedSupplierId;
    final tankId = _selectedTankId;
    final fuelTypeId = _selectedFuelTypeId;
    if (supplierId == null || tankId == null || fuelTypeId == null) {
      setState(() {
        _feedbackMessage = 'Select supplier, tank, and fuel type.';
      });
      return;
    }
    final quantity = double.tryParse(_purchaseQuantityController.text.trim());
    final rate = double.tryParse(_purchaseRateController.text.trim());
    if (quantity == null || quantity <= 0 || rate == null || rate <= 0) {
      setState(() {
        _feedbackMessage = 'Enter a valid positive quantity and rate.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final purchase = await widget.sessionController.createPurchase({
        'supplier_id': supplierId,
        'tank_id': tankId,
        'fuel_type_id': fuelTypeId,
        'quantity': quantity,
        'rate_per_liter': rate,
        'reference_no': _emptyToNull(_purchaseReferenceController.text),
        'notes': _emptyToNull(_purchaseNotesController.text),
      });

      if (!mounted) {
        return;
      }

      _purchaseQuantityController.clear();
      _purchaseRateController.clear();
      _purchaseReferenceController.clear();
      _purchaseNotesController.clear();
      await _loadFinanceWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Purchase #${purchase['id']} created with status ${purchase['status']}.';
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

  Future<void> _submitCustomerPayment() async {
    final stationId = _selectedStationId;
    final customerId = _selectedCustomerId;
    if (stationId == null || customerId == null) {
      setState(() {
        _feedbackMessage = 'Select station and customer.';
      });
      return;
    }
    final amount = double.tryParse(_customerAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _feedbackMessage = 'Enter a valid positive customer payment amount.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final payment = await widget.sessionController.createCustomerPayment({
        'customer_id': customerId,
        'station_id': stationId,
        'amount': amount,
        'payment_method': _customerPaymentMethod,
        'reference_no': _emptyToNull(_customerReferenceController.text),
        'notes': _emptyToNull(_customerNotesController.text),
      });

      if (!mounted) {
        return;
      }

      _customerAmountController.clear();
      _customerReferenceController.clear();
      _customerNotesController.clear();
      await _loadFinanceWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Customer payment #${payment['id']} saved successfully.';
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

  Future<void> _submitSupplierPayment() async {
    final stationId = _selectedStationId;
    final supplierId = _selectedSupplierId;
    if (stationId == null || supplierId == null) {
      setState(() {
        _feedbackMessage = 'Select station and supplier.';
      });
      return;
    }
    final amount = double.tryParse(_supplierAmountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _feedbackMessage = 'Enter a valid positive supplier payment amount.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final payment = await widget.sessionController.createSupplierPayment({
        'supplier_id': supplierId,
        'station_id': stationId,
        'amount': amount,
        'payment_method': _supplierPaymentMethod,
        'reference_no': _emptyToNull(_supplierReferenceController.text),
        'notes': _emptyToNull(_supplierNotesController.text),
      });

      if (!mounted) {
        return;
      }

      _supplierAmountController.clear();
      _supplierReferenceController.clear();
      _supplierNotesController.clear();
      await _loadFinanceWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'Supplier payment #${payment['id']} saved successfully.';
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

  Future<void> _reverseCurrentSelection() async {
    setState(() {
      _isReversing = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      switch (_section) {
        case _FinanceSection.purchases:
          final purchaseId = _selectedPurchaseId;
          if (purchaseId == null) {
            throw ApiException('Select a purchase to reverse.');
          }
          final purchase = await widget.sessionController.reversePurchase(
            purchaseId: purchaseId,
            payload: const {'reason': 'Requested from Flutter finance screen'},
          );
          _feedbackMessage =
              'Purchase #${purchase['id']} reversal processed as ${purchase['reversal_request_status'] ?? (purchase['is_reversed'] == true ? 'reversed' : 'requested')}.';
        case _FinanceSection.customerPayments:
          final paymentId = _selectedCustomerPaymentId;
          if (paymentId == null) {
            throw ApiException('Select a customer payment to reverse.');
          }
          final payment = await widget.sessionController.reverseCustomerPayment(
            paymentId: paymentId,
            payload: const {'reason': 'Requested from Flutter finance screen'},
          );
          _feedbackMessage =
              'Customer payment #${payment['id']} reversal processed as ${payment['reversal_request_status'] ?? (payment['is_reversed'] == true ? 'reversed' : 'requested')}.';
        case _FinanceSection.supplierPayments:
          final paymentId = _selectedSupplierPaymentId;
          if (paymentId == null) {
            throw ApiException('Select a supplier payment to reverse.');
          }
          final payment = await widget.sessionController.reverseSupplierPayment(
            paymentId: paymentId,
            payload: const {'reason': 'Requested from Flutter finance screen'},
          );
          _feedbackMessage =
              'Supplier payment #${payment['id']} reversal processed as ${payment['reversal_request_status'] ?? (payment['is_reversed'] == true ? 'reversed' : 'requested')}.';
      }

      if (!mounted) {
        return;
      }

      await _loadFinanceWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _isReversing = false;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isReversing = false;
      });
    }
  }

  Future<void> _previewCustomerPaymentDocument(
    Map<String, dynamic> payment,
  ) async {
    try {
      final document = await widget.sessionController
          .fetchCustomerPaymentDocument(paymentId: payment['id'] as int);
      if (!mounted) return;
      await _showPaymentDocumentDialog(
        title: 'Customer Receipt #${payment['id']}',
        document: document,
        onSave: () async {
          final bytes = await widget.sessionController
              .downloadCustomerPaymentPdf(paymentId: payment['id'] as int);
          return writeBytesToLocalDocumentFile(
            'customer_payment_${payment['id']}.pdf',
            bytes,
          );
        },
        onSend: (payload) =>
            widget.sessionController.sendCustomerPaymentDocument(
              paymentId: payment['id'] as int,
              payload: payload,
            ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _previewSupplierPaymentDocument(
    Map<String, dynamic> payment,
  ) async {
    try {
      final document = await widget.sessionController
          .fetchSupplierPaymentDocument(paymentId: payment['id'] as int);
      if (!mounted) return;
      await _showPaymentDocumentDialog(
        title: 'Supplier Voucher #${payment['id']}',
        document: document,
        onSave: () async {
          final bytes = await widget.sessionController
              .downloadSupplierPaymentPdf(paymentId: payment['id'] as int);
          return writeBytesToLocalDocumentFile(
            'supplier_payment_${payment['id']}.pdf',
            bytes,
          );
        },
        onSend: (payload) =>
            widget.sessionController.sendSupplierPaymentDocument(
              paymentId: payment['id'] as int,
              payload: payload,
            ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _showPaymentDocumentDialog({
    required String title,
    required Map<String, dynamic> document,
    required Future<String> Function() onSave,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic> payload)
    onSend,
  }) async {
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
            title: Text(title),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(document['title'] as String? ?? title),
                    const SizedBox(height: 8),
                    Text('Document #: ${document['document_number'] ?? '-'}'),
                    Text('Recipient: ${document['recipient_name'] ?? '-'}'),
                    if (document['total_amount'] != null)
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
                  final path = await onSave();
                  if (!mounted) return;
                  await Clipboard.setData(ClipboardData(text: path));
                  if (!mounted) return;
                  setState(() {
                    _feedbackMessage = 'Document saved to $path';
                  });
                },
                child: const Text('Save PDF'),
              ),
              FilledButton.tonal(
                onPressed: () async {
                  final path = await onSave();
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
                    final dispatch = await onSend({
                      'channel': channel,
                      'format': 'pdf',
                      'recipient_name': _emptyToNull(
                        recipientNameController.text,
                      ),
                      'recipient_contact': _emptyToNull(
                        recipientContactController.text,
                      ),
                    });
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _stations.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    return RefreshIndicator(
      onRefresh: _loadFinanceWorkspace,
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
                    'Finance Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage fuel purchases, customer receipts, and supplier payments from one shared station workspace.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stationField = DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'finance-station-${_selectedStationId ?? 'none'}',
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
                        onChanged: _changeStation,
                      );
                      final sections = SegmentedButton<_FinanceSection>(
                        segments: const [
                          ButtonSegment(
                            value: _FinanceSection.purchases,
                            label: Text('Purchases'),
                            icon: Icon(Icons.inventory_2_outlined),
                          ),
                          ButtonSegment(
                            value: _FinanceSection.customerPayments,
                            label: Text('Customer'),
                            icon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          ButtonSegment(
                            value: _FinanceSection.supplierPayments,
                            label: Text('Supplier'),
                            icon: Icon(Icons.payments_outlined),
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
                  _buildSectionContent(context),
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

  Widget _buildSectionContent(BuildContext context) {
    switch (_section) {
      case _FinanceSection.purchases:
        return _buildPurchaseSection(context);
      case _FinanceSection.customerPayments:
        return _buildCustomerPaymentSection(context);
      case _FinanceSection.supplierPayments:
        return _buildSupplierPaymentSection(context);
    }
  }

  Widget _buildPurchaseSection(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Purchase',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_suppliers.isEmpty || _tanks.isEmpty) ...[
            _buildHintBanner(
              context,
              'Purchases need both a supplier and a tank. Add missing setup first if these lists are empty.',
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'purchase-supplier-${_selectedSupplierId ?? 'none'}',
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
            onChanged: (value) {
              setState(() {
                _selectedSupplierId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('purchase-tank-${_selectedTankId ?? 'none'}'),
            initialValue: _selectedTankId,
            decoration: const InputDecoration(labelText: 'Tank'),
            items: [
              for (final tank in _tanks)
                DropdownMenuItem<int>(
                  value: tank['id'] as int,
                  child: Text('${tank['code']} - ${tank['name']}'),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedTankId = value;
                final match = _tanks.cast<Map<String, dynamic>?>().firstWhere(
                  (tank) => tank?['id'] == value,
                  orElse: () => null,
                );
                _selectedFuelTypeId = match?['fuel_type_id'] as int?;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'purchase-fuel-${_selectedFuelTypeId ?? 'none'}',
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
            onChanged: (value) {
              setState(() {
                _selectedFuelTypeId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purchaseQuantityController,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              helperText: 'Total liters received in this purchase.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purchaseRateController,
            decoration: const InputDecoration(
              labelText: 'Rate Per Liter',
              helperText: 'Purchase price per liter.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purchaseReferenceController,
            decoration: const InputDecoration(labelText: 'Reference No'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _purchaseNotesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitPurchase,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business_outlined),
            label: const Text('Create Purchase'),
          ),
        ],
      ),
      secondary: _buildPurchaseList(context),
    );
  }

  Widget _buildCustomerPaymentSection(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Receipt',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_customers.isEmpty) ...[
            _buildHintBanner(
              context,
              'No customers found for this station yet. Add one in the Parties workspace to post receipts.',
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'customer-payment-customer-${_selectedCustomerId ?? 'none'}',
            ),
            initialValue: _selectedCustomerId,
            decoration: const InputDecoration(labelText: 'Customer'),
            items: [
              for (final customer in _customers)
                DropdownMenuItem<int>(
                  value: customer['id'] as int,
                  child: Text('${customer['code']} - ${customer['name']}'),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCustomerId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'customer-payment-method-$_customerPaymentMethod',
            ),
            initialValue: _customerPaymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
            ],
            onChanged: (value) {
              setState(() {
                _customerPaymentMethod = value ?? 'cash';
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAmountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              helperText: 'Received amount for the selected customer.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerReferenceController,
            decoration: const InputDecoration(labelText: 'Reference No'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerNotesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitCustomerPayment,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Save Customer Payment'),
          ),
        ],
      ),
      secondary: _buildCustomerPaymentList(context),
    );
  }

  Widget _buildSupplierPaymentSection(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Supplier Payment',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (_suppliers.isEmpty) ...[
            _buildHintBanner(
              context,
              'No suppliers found yet. Add one in the Parties workspace to post supplier payments.',
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'supplier-payment-supplier-${_selectedSupplierId ?? 'none'}',
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
            onChanged: (value) {
              setState(() {
                _selectedSupplierId = value;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'supplier-payment-method-$_supplierPaymentMethod',
            ),
            initialValue: _supplierPaymentMethod,
            decoration: const InputDecoration(labelText: 'Payment Method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'card', child: Text('Card')),
            ],
            onChanged: (value) {
              setState(() {
                _supplierPaymentMethod = value ?? 'cash';
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierAmountController,
            decoration: const InputDecoration(
              labelText: 'Amount',
              helperText: 'Paid amount for the selected supplier.',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierReferenceController,
            decoration: const InputDecoration(labelText: 'Reference No'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierNotesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _submitSupplierPayment,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.payments_outlined),
            label: const Text('Save Supplier Payment'),
          ),
        ],
      ),
      secondary: _buildSupplierPaymentList(context),
    );
  }

  Widget _buildPurchaseList(BuildContext context) {
    final selected = _purchases.cast<Map<String, dynamic>?>().firstWhere(
      (purchase) => purchase?['id'] == _selectedPurchaseId,
      orElse: () => null,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Purchases',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_purchases.isEmpty)
              _buildEmptyState(
                context,
                'No purchases found yet.',
                'Create the first fuel purchase to start purchase history for this station.',
              )
            else
              for (final purchase in _purchases)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '#${purchase['id']} • ${_formatNumber(purchase['total_amount'])}',
                  ),
                  subtitle: Text(
                    '${purchase['status']} • ${_formatDateTime(purchase['created_at'])}',
                  ),
                  trailing: purchase['is_reversed'] == true
                      ? const Chip(label: Text('Reversed'))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedPurchaseId = purchase['id'] as int;
                    });
                  },
                ),
            if (selected != null) ...[
              const Divider(height: 24),
              Text(
                'Selected Purchase #${selected['id']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildDetailWrap([
                _buildDetailItem(
                  'Quantity',
                  _formatNumber(selected['quantity']),
                ),
                _buildDetailItem(
                  'Rate',
                  _formatNumber(selected['rate_per_liter']),
                ),
                _buildDetailItem(
                  'Total',
                  _formatNumber(selected['total_amount']),
                ),
                _buildDetailItem(
                  'Status',
                  selected['status'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Supplier',
                  _lookupName(_suppliers, selected['supplier_id']),
                ),
                _buildDetailItem(
                  'Tank',
                  _lookupName(_tanks, selected['tank_id']),
                ),
                _buildDetailItem(
                  'Reference',
                  selected['reference_no'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Reversal',
                  selected['reversal_request_status'] as String? ??
                      (selected['is_reversed'] == true ? 'reversed' : 'none'),
                ),
              ]),
              if ((selected['notes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Notes: ${selected['notes']}'),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _isReversing ? null : _reverseCurrentSelection,
                icon: _isReversing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo_outlined),
                label: const Text('Reverse / Request Reversal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerPaymentList(BuildContext context) {
    final selected = _customerPayments.cast<Map<String, dynamic>?>().firstWhere(
      (payment) => payment?['id'] == _selectedCustomerPaymentId,
      orElse: () => null,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Customer Payments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_customerPayments.isEmpty)
              _buildEmptyState(
                context,
                'No customer payments found yet.',
                'Customer receipts will appear here after you save the first payment.',
              )
            else
              for (final payment in _customerPayments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '#${payment['id']} • ${_formatNumber(payment['amount'])}',
                  ),
                  subtitle: Text(
                    '${payment['payment_method']} • ${_formatDateTime(payment['created_at'])}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (payment['is_reversed'] == true)
                        const Chip(label: Text('Reversed')),
                      IconButton(
                        tooltip: 'Receipt Actions',
                        onPressed: () =>
                            _previewCustomerPaymentDocument(payment),
                        icon: const Icon(Icons.description_outlined),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedCustomerPaymentId = payment['id'] as int;
                    });
                  },
                ),
            if (selected != null) ...[
              const Divider(height: 24),
              Text(
                'Selected Customer Payment #${selected['id']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildDetailWrap([
                _buildDetailItem('Amount', _formatNumber(selected['amount'])),
                _buildDetailItem(
                  'Method',
                  selected['payment_method'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Customer',
                  _lookupName(_customers, selected['customer_id']),
                ),
                _buildDetailItem(
                  'Reference',
                  selected['reference_no'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Created',
                  _formatDateTime(selected['created_at']),
                ),
                _buildDetailItem(
                  'Reversal',
                  selected['reversal_request_status'] as String? ??
                      (selected['is_reversed'] == true ? 'reversed' : 'none'),
                ),
              ]),
              if ((selected['notes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Notes: ${selected['notes']}'),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _isReversing ? null : _reverseCurrentSelection,
                icon: _isReversing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo_outlined),
                label: const Text('Reverse / Request Reversal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierPaymentList(BuildContext context) {
    final selected = _supplierPayments.cast<Map<String, dynamic>?>().firstWhere(
      (payment) => payment?['id'] == _selectedSupplierPaymentId,
      orElse: () => null,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Supplier Payments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (_supplierPayments.isEmpty)
              _buildEmptyState(
                context,
                'No supplier payments found yet.',
                'Supplier vouchers will appear here after you save the first payment.',
              )
            else
              for (final payment in _supplierPayments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '#${payment['id']} • ${_formatNumber(payment['amount'])}',
                  ),
                  subtitle: Text(
                    '${payment['payment_method']} • ${_formatDateTime(payment['created_at'])}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (payment['is_reversed'] == true)
                        const Chip(label: Text('Reversed')),
                      IconButton(
                        tooltip: 'Voucher Actions',
                        onPressed: () =>
                            _previewSupplierPaymentDocument(payment),
                        icon: const Icon(Icons.description_outlined),
                      ),
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      _selectedSupplierPaymentId = payment['id'] as int;
                    });
                  },
                ),
            if (selected != null) ...[
              const Divider(height: 24),
              Text(
                'Selected Supplier Payment #${selected['id']}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildDetailWrap([
                _buildDetailItem('Amount', _formatNumber(selected['amount'])),
                _buildDetailItem(
                  'Method',
                  selected['payment_method'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Supplier',
                  _lookupName(_suppliers, selected['supplier_id']),
                ),
                _buildDetailItem(
                  'Reference',
                  selected['reference_no'] as String? ?? '-',
                ),
                _buildDetailItem(
                  'Created',
                  _formatDateTime(selected['created_at']),
                ),
                _buildDetailItem(
                  'Reversal',
                  selected['reversal_request_status'] as String? ??
                      (selected['is_reversed'] == true ? 'reversed' : 'none'),
                ),
              ]),
              if ((selected['notes'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Notes: ${selected['notes']}'),
              ],
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: _isReversing ? null : _reverseCurrentSelection,
                icon: _isReversing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo_outlined),
                label: const Text('Reverse / Request Reversal'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
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

  String _formatDateTime(dynamic value) {
    if (value is! String || value.isEmpty) {
      return 'Unknown';
    }
    return value.replaceFirst('T', ' ').substring(0, 16);
  }
}
