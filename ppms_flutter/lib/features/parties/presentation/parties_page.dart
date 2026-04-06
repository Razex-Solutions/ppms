import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _PartySection { customers, suppliers }

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  final _customerNameController = TextEditingController();
  final _customerCodeController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _customerCreditLimitController = TextEditingController(text: '0');
  final _supplierNameController = TextEditingController();
  final _supplierCodeController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _supplierAddressController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _supplierSearchController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _PartySection _section = _PartySection.customers;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _customers = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  Map<String, dynamic>? _selectedCustomerLedgerSummary;
  Map<String, dynamic>? _selectedCustomerLedger;
  Map<String, dynamic>? _selectedSupplierLedgerSummary;
  Map<String, dynamic>? _selectedSupplierLedger;
  int? _selectedStationId;
  int? _selectedCustomerId;
  int? _selectedSupplierId;
  String _customerType = 'individual';

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerCodeController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _customerCreditLimitController.dispose();
    _supplierNameController.dispose();
    _supplierCodeController.dispose();
    _supplierPhoneController.dispose();
    _supplierAddressController.dispose();
    _customerSearchController.dispose();
    _supplierSearchController.dispose();
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

      final customers = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final suppliers = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchSuppliers()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      if (!mounted) return;

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _customers = customers;
        _suppliers = suppliers;
        _selectedCustomerId ??= customers.isNotEmpty
            ? customers.first['id'] as int
            : null;
        _selectedSupplierId ??= suppliers.isNotEmpty
            ? suppliers.first['id'] as int
            : null;
        _isLoading = false;
      });
      await _loadSelectedLedgerData();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
      _selectedCustomerId = null;
      _selectedSupplierId = null;
      _selectedCustomerLedgerSummary = null;
      _selectedCustomerLedger = null;
      _selectedSupplierLedgerSummary = null;
      _selectedSupplierLedger = null;
    });
    _resetCustomerForm();
    await _loadWorkspace();
  }

  Future<void> _loadSelectedLedgerData() async {
    if (!_canReadLedger) {
      return;
    }
    try {
      final customerId = _selectedCustomerId;
      final supplierId = _selectedSupplierId;
      final stationId = _selectedStationId;
      final customerSummary = customerId == null
          ? null
          : await widget.sessionController.fetchCustomerLedgerSummary(
              customerId: customerId,
            );
      final customerLedger = customerId == null
          ? null
          : await widget.sessionController.fetchCustomerLedger(
              customerId: customerId,
            );
      final supplierSummary = supplierId == null
          ? null
          : await widget.sessionController.fetchSupplierLedgerSummary(
              supplierId: supplierId,
              stationId: stationId,
            );
      final supplierLedger = supplierId == null
          ? null
          : await widget.sessionController.fetchSupplierLedger(
              supplierId: supplierId,
              stationId: stationId,
            );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedCustomerLedgerSummary = customerSummary;
        _selectedCustomerLedger = customerLedger;
        _selectedSupplierLedgerSummary = supplierSummary;
        _selectedSupplierLedger = supplierLedger;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<void> _saveCustomer() async {
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station before saving a customer.';
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
        'name': _customerNameController.text.trim(),
        'code': _customerCodeController.text.trim(),
        'customer_type': _customerType,
        'phone': _emptyToNull(_customerPhoneController.text),
        'address': _emptyToNull(_customerAddressController.text),
        'credit_limit': double.parse(
          _customerCreditLimitController.text.trim(),
        ),
        'station_id': stationId,
      };
      final isEditing = _selectedCustomerId != null;
      final customer = isEditing
          ? await widget.sessionController.updateCustomer(
              customerId: _selectedCustomerId!,
              payload: payload,
            )
          : await widget.sessionController.createCustomer(payload);

      if (!mounted) return;

      _resetCustomerForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Customer ${customer['name']} ${isEditing ? 'updated' : 'created'} successfully.';
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

  Future<void> _saveSupplier() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final payload = {
        'name': _supplierNameController.text.trim(),
        'code': _supplierCodeController.text.trim(),
        'phone': _emptyToNull(_supplierPhoneController.text),
        'address': _emptyToNull(_supplierAddressController.text),
      };
      final isEditing = _selectedSupplierId != null;
      final supplier = isEditing
          ? await widget.sessionController.updateSupplier(
              supplierId: _selectedSupplierId!,
              payload: payload,
            )
          : await widget.sessionController.createSupplier(payload);

      if (!mounted) return;

      _resetSupplierForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Supplier ${supplier['name']} ${isEditing ? 'updated' : 'created'} successfully.';
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

  Future<void> _deleteCustomer() async {
    final customerId = _selectedCustomerId;
    if (customerId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Customer',
      message:
          'Delete this customer only if it has no transaction history. This cannot be undone.',
    );
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final response = await widget.sessionController.deleteCustomer(
        customerId: customerId,
      );
      if (!mounted) return;
      _resetCustomerForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Customer deleted successfully.';
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

  Future<void> _deleteSupplier() async {
    final supplierId = _selectedSupplierId;
    if (supplierId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Supplier',
      message:
          'Delete this supplier only if it has no purchase or payment history. This cannot be undone.',
    );
    if (!confirmed) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final response = await widget.sessionController.deleteSupplier(
        supplierId: supplierId,
      );
      if (!mounted) return;
      _resetSupplierForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Supplier deleted successfully.';
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

  void _selectCustomer(Map<String, dynamic> customer) {
    setState(() {
      _selectedCustomerId = customer['id'] as int;
      _customerNameController.text = customer['name'] as String? ?? '';
      _customerCodeController.text = customer['code'] as String? ?? '';
      _customerPhoneController.text = customer['phone'] as String? ?? '';
      _customerAddressController.text = customer['address'] as String? ?? '';
      _customerCreditLimitController.text =
          ((customer['credit_limit'] as num?) ?? 0).toString();
      _customerType = customer['customer_type'] as String? ?? 'individual';
      _feedbackMessage = 'Editing customer ${customer['name']}.';
      _errorMessage = null;
    });
    _loadSelectedLedgerData();
  }

  void _selectSupplier(Map<String, dynamic> supplier) {
    setState(() {
      _selectedSupplierId = supplier['id'] as int;
      _supplierNameController.text = supplier['name'] as String? ?? '';
      _supplierCodeController.text = supplier['code'] as String? ?? '';
      _supplierPhoneController.text = supplier['phone'] as String? ?? '';
      _supplierAddressController.text = supplier['address'] as String? ?? '';
      _feedbackMessage = 'Editing supplier ${supplier['name']}.';
      _errorMessage = null;
    });
    _loadSelectedLedgerData();
  }

  void _resetCustomerForm() {
    _selectedCustomerId = null;
    _customerNameController.clear();
    _customerCodeController.clear();
    _customerPhoneController.clear();
    _customerAddressController.clear();
    _customerCreditLimitController.text = '0';
    _customerType = 'individual';
  }

  void _resetSupplierForm() {
    _selectedSupplierId = null;
    _supplierNameController.clear();
    _supplierCodeController.clear();
    _supplierPhoneController.clear();
    _supplierAddressController.clear();
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<Map<String, dynamic>> get _filteredCustomers {
    final query = _customerSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _customers;
    return _customers.where((customer) {
      final haystack = [
        customer['name'],
        customer['code'],
        customer['phone'],
        customer['customer_type'],
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredSuppliers {
    final query = _supplierSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return _suppliers;
    return _suppliers.where((supplier) {
      final haystack = [
        supplier['name'],
        supplier['code'],
        supplier['phone'],
        supplier['address'],
      ].join(' ').toLowerCase();
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

  bool get _canReadCustomers =>
      _hasAction('customers', 'create') ||
      _hasAction('customers', 'update') ||
      _hasAction('customers', 'delete') ||
      _hasAction('customers', 'request_credit_override') ||
      _hasAction('customers', 'approve_credit_override') ||
      _hasAction('customers', 'reject_credit_override');
  bool get _canManageCustomers =>
      _hasAction('customers', 'create') || _hasAction('customers', 'update');
  bool get _canDeleteCustomers => _hasAction('customers', 'delete');
  bool get _canReadSuppliers =>
      _hasAction('suppliers', 'create') ||
      _hasAction('suppliers', 'update') ||
      _hasAction('suppliers', 'delete');
  bool get _canManageSuppliers =>
      _hasAction('suppliers', 'create') || _hasAction('suppliers', 'update');
  bool get _canDeleteSuppliers => _hasAction('suppliers', 'delete');
  bool get _canReadLedger => _hasAction('ledger', 'read');

  Map<String, dynamic>? get _selectedCustomer {
    for (final customer in _customers) {
      if (customer['id'] == _selectedCustomerId) {
        return customer;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedSupplier {
    for (final supplier in _suppliers) {
      if (supplier['id'] == _selectedSupplierId) {
        return supplier;
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

  String get _currentFocusTitle {
    switch (_section) {
      case _PartySection.customers:
        final customer = _selectedCustomer;
        if (customer != null) {
          return 'Customer ${customer['name']} is selected for review';
        }
        return _canManageCustomers
            ? 'No customer selected yet'
            : 'Customer review mode';
      case _PartySection.suppliers:
        final supplier = _selectedSupplier;
        if (supplier != null) {
          return 'Supplier ${supplier['name']} is selected for review';
        }
        return _canManageSuppliers
            ? 'No supplier selected yet'
            : 'Supplier review mode';
    }
  }

  String get _currentFocusSubtitle {
    switch (_section) {
      case _PartySection.customers:
        if (_selectedCustomer != null) {
          return 'Review balance, contact details, and ledger movement before editing the customer record.';
        }
        return _canManageCustomers
            ? 'Pick a customer from the list to review first, or use the form to create a new one for this station.'
            : 'Pick a customer from the list to inspect balances and ledger movement.';
      case _PartySection.suppliers:
        if (_selectedSupplier != null) {
          return 'Review payable exposure, contact details, and recent ledger movement before editing the supplier record.';
        }
        return _canManageSuppliers
            ? 'Pick a supplier from the list to review first, or use the form to create a new supplier.'
            : 'Pick a supplier from the list to inspect payable position and ledger movement.';
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _stations.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final availableSections = <_PartySection>[
      if (_canReadCustomers) _PartySection.customers,
      if (_canReadSuppliers) _PartySection.suppliers,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }

    final colorScheme = Theme.of(context).colorScheme;
    final sectionMeta = _sectionMeta();

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Parties Workspace',
            title: sectionMeta.$1,
            subtitle: sectionMeta.$2,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Visible section',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    sectionMeta.$1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                if (_canReadCustomers)
                  DashboardMetricTile(
                    label: 'Customers',
                    value: _customers.length.toString(),
                    caption: 'Customers visible in the selected station scope',
                    icon: Icons.groups_outlined,
                    tint: colorScheme.primary,
                  ),
                if (_canReadSuppliers)
                  DashboardMetricTile(
                    label: 'Suppliers',
                    value: _suppliers.length.toString(),
                    caption:
                        'Suppliers available to finance and purchase flows',
                    icon: Icons.local_shipping_outlined,
                    tint: colorScheme.tertiary,
                  ),
                if (_canReadCustomers)
                  DashboardMetricTile(
                    label: 'Customer exposure',
                    value: _formatNumber(
                      _sumOf(_customers, 'outstanding_balance'),
                    ),
                    caption: 'Visible outstanding customer balance',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: colorScheme.error,
                  ),
                if (_canReadSuppliers)
                  DashboardMetricTile(
                    label: 'Supplier payable',
                    value: _formatNumber(_sumOf(_suppliers, 'payable_balance')),
                    caption: 'Visible supplier payable balance',
                    icon: Icons.payments_outlined,
                    tint: colorScheme.secondary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DashboardSectionCard(
                    icon: sectionMeta.$3,
                    title: sectionMeta.$1,
                    subtitle: sectionMeta.$2,
                    child: const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  if (availableSections.isEmpty) ...[
                    _buildPermissionNotice(
                      context,
                      'Ask an administrator for customer or supplier permissions if this workspace should be available.',
                    ),
                    const SizedBox(height: 16),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stationField = DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'parties-station-${_selectedStationId ?? 'none'}',
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
                          : SegmentedButton<_PartySection>(
                              segments: [
                                if (_canReadCustomers)
                                  const ButtonSegment(
                                    value: _PartySection.customers,
                                    label: Text('Customers'),
                                    icon: Icon(Icons.groups_outlined),
                                  ),
                                if (_canReadSuppliers)
                                  const ButtonSegment(
                                    value: _PartySection.suppliers,
                                    label: Text('Suppliers'),
                                    icon: Icon(Icons.local_shipping_outlined),
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
                          sections,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildWorkspaceReview(context),
                  const SizedBox(height: 20),
                  if (availableSections.isEmpty)
                    const SizedBox.shrink()
                  else if (_section == _PartySection.customers)
                    _buildCustomers(context)
                  else
                    _buildSuppliers(context),
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

  (String, String, IconData) _sectionMeta() {
    switch (_section) {
      case _PartySection.customers:
        return (
          'Customer control',
          _canReadCustomers
              ? 'Review and manage customers who drive credit exposure, fuel sales, and collection follow-up.'
              : 'This role does not currently have access to customer management.',
          Icons.groups_outlined,
        );
      case _PartySection.suppliers:
        return (
          'Supplier control',
          _canReadSuppliers
              ? 'Review and manage suppliers who drive purchase and payment workflows.'
              : 'This role does not currently have access to supplier management.',
          Icons.local_shipping_outlined,
        );
    }
  }

  double _sumOf(List<Map<String, dynamic>> items, String key) {
    var total = 0.0;
    for (final item in items) {
      final value = item[key];
      if (value is num) {
        total += value.toDouble();
      }
    }
    return total;
  }

  Widget _buildWorkspaceReview(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedSummary = _section == _PartySection.customers
        ? _selectedCustomer
        : _selectedSupplier;
    final sectionCount = _section == _PartySection.customers
        ? _customers.length
        : _suppliers.length;
    final canManageCurrentSection = _section == _PartySection.customers
        ? _canManageCustomers
        : _canManageSuppliers;
    final countLabel = _section == _PartySection.customers
        ? '$sectionCount customers visible in this station scope'
        : '$sectionCount suppliers visible in this workspace';
    final reviewLabel = selectedSummary == null
        ? 'No record selected yet'
        : '${selectedSummary['code'] ?? '-'} • ${selectedSummary['name'] ?? 'Selected record'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
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
          Text(
            _currentFocusTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            _currentFocusSubtitle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
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
                icon: Icons.visibility_outlined,
                label: reviewLabel,
              ),
              _buildInfoChip(
                context,
                icon: Icons.format_list_bulleted_outlined,
                label: countLabel,
              ),
              _buildInfoChip(
                context,
                icon: canManageCurrentSection
                    ? Icons.edit_note_outlined
                    : Icons.lock_outline,
                label: canManageCurrentSection
                    ? 'This role can update this section'
                    : 'This role can review only',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomers(BuildContext context) {
    final canManageCustomers = _canManageCustomers;
    final canDeleteCustomers = _canDeleteCustomers;
    final selectedCustomer = _selectedCustomer;
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedCustomer == null)
                _buildEmptyState(
                  context,
                  'No customer selected yet.',
                  canManageCustomers
                      ? 'Choose a customer from the list to review before editing, or use the form below to create a new one.'
                      : 'Choose a customer from the list to inspect balances and contact details.',
                )
              else ...[
                _buildSummaryBanner(
                  context,
                  title:
                      '${selectedCustomer['code'] ?? '-'} - ${selectedCustomer['name'] ?? 'Customer'}',
                  subtitle:
                      '${selectedCustomer['customer_type'] ?? 'customer'} • Phone ${selectedCustomer['phone'] ?? '-'}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricChip(
                      'Outstanding',
                      _formatNumber(selectedCustomer['outstanding_balance']),
                    ),
                    _buildMetricChip(
                      'Credit Limit',
                      _formatNumber(selectedCustomer['credit_limit']),
                    ),
                    _buildMetricChip(
                      'Address',
                      (selectedCustomer['address'] as String?)?.isNotEmpty ==
                              true
                          ? selectedCustomer['address'] as String
                          : '-',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                _selectedCustomerId == null
                    ? 'Create Customer'
                    : 'Update Customer Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use the form after reviewing the selected customer state and ledger snapshot.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!canManageCustomers) ...[
                const SizedBox(height: 12),
                _buildPermissionNotice(
                  context,
                  'This role can review customers but cannot create or edit them.',
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerNameController,
                enabled: canManageCustomers,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerCodeController,
                enabled: canManageCustomers,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey<String>('customer-type-$_customerType'),
                initialValue: _customerType,
                decoration: const InputDecoration(labelText: 'Customer Type'),
                items: const [
                  DropdownMenuItem(
                    value: 'individual',
                    child: Text('Individual'),
                  ),
                  DropdownMenuItem(value: 'company', child: Text('Company')),
                  DropdownMenuItem(value: 'pump', child: Text('Pump')),
                ],
                onChanged: canManageCustomers
                    ? (value) {
                        setState(() {
                          _customerType = value ?? 'individual';
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerPhoneController,
                enabled: canManageCustomers,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerAddressController,
                enabled: canManageCustomers,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerCreditLimitController,
                enabled: canManageCustomers,
                decoration: const InputDecoration(labelText: 'Credit Limit'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSubmitting || !canManageCustomers
                    ? null
                    : _saveCustomer,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1_outlined),
                label: Text(
                  _selectedCustomerId == null
                      ? 'Create Customer'
                      : 'Save Customer',
                ),
              ),
              if (_selectedCustomerId != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _resetCustomerForm();
                                _feedbackMessage = 'Customer form cleared.';
                              });
                            },
                      child: const Text('Cancel Edit'),
                    ),
                    OutlinedButton(
                      onPressed: _isSubmitting || !canDeleteCustomers
                          ? null
                          : _deleteCustomer,
                      child: const Text('Delete Customer'),
                    ),
                  ],
                ),
              ],
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
              Text('Customers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Review the station customer list first, then open the selected record for edits or ledger review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _customerSearchController,
                decoration: InputDecoration(
                  labelText: 'Search Customers',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _customerSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _customerSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_filteredCustomers.isEmpty)
                const Text('No customers found for this station yet.')
              else
                ..._filteredCustomers.map(
                  (customer) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      selected: customer['id'] == _selectedCustomerId,
                      title: Text('${customer['code']} - ${customer['name']}'),
                      subtitle: Text(
                        '${customer['customer_type']} • Balance ${_formatNumber(customer['outstanding_balance'])} • Limit ${_formatNumber(customer['credit_limit'])}',
                      ),
                      trailing: customer['id'] == _selectedCustomerId
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                      onTap: () => _selectCustomer(customer),
                    ),
                  ),
                ),
              if (_canReadLedger && _selectedCustomerLedgerSummary != null) ...[
                const Divider(height: 24),
                Text(
                  'Ledger Snapshot',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildLedgerSummaryCard(
                  summary: _selectedCustomerLedgerSummary!,
                  entries: List<Map<String, dynamic>>.from(
                    (_selectedCustomerLedger?['ledger'] as List? ?? const [])
                        .map((item) => Map<String, dynamic>.from(item as Map)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuppliers(BuildContext context) {
    final canManageSuppliers = _canManageSuppliers;
    final canDeleteSuppliers = _canDeleteSuppliers;
    final selectedSupplier = _selectedSupplier;
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supplier Summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (selectedSupplier == null)
                _buildEmptyState(
                  context,
                  'No supplier selected yet.',
                  canManageSuppliers
                      ? 'Choose a supplier from the list to review before editing, or use the form below to create a new supplier.'
                      : 'Choose a supplier from the list to inspect payable position and contact details.',
                )
              else ...[
                _buildSummaryBanner(
                  context,
                  title:
                      '${selectedSupplier['code'] ?? '-'} - ${selectedSupplier['name'] ?? 'Supplier'}',
                  subtitle: 'Phone ${selectedSupplier['phone'] ?? '-'}',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricChip(
                      'Payable',
                      _formatNumber(selectedSupplier['payable_balance']),
                    ),
                    _buildMetricChip(
                      'Address',
                      (selectedSupplier['address'] as String?)?.isNotEmpty ==
                              true
                          ? selectedSupplier['address'] as String
                          : '-',
                    ),
                    _buildMetricChip(
                      'Phone',
                      (selectedSupplier['phone'] as String?)?.isNotEmpty == true
                          ? selectedSupplier['phone'] as String
                          : '-',
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                _selectedSupplierId == null
                    ? 'Create Supplier'
                    : 'Update Supplier Details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Use the form after reviewing supplier balance and recent ledger movement.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (!canManageSuppliers) ...[
                const SizedBox(height: 12),
                _buildPermissionNotice(
                  context,
                  'This role can review suppliers but cannot create or edit them.',
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierNameController,
                enabled: canManageSuppliers,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierCodeController,
                enabled: canManageSuppliers,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierPhoneController,
                enabled: canManageSuppliers,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierAddressController,
                enabled: canManageSuppliers,
                decoration: const InputDecoration(labelText: 'Address'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSubmitting || !canManageSuppliers
                    ? null
                    : _saveSupplier,
                icon: _isSubmitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_business_outlined),
                label: Text(
                  _selectedSupplierId == null
                      ? 'Create Supplier'
                      : 'Save Supplier',
                ),
              ),
              if (_selectedSupplierId != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonal(
                      onPressed: _isSubmitting
                          ? null
                          : () {
                              setState(() {
                                _resetSupplierForm();
                                _feedbackMessage = 'Supplier form cleared.';
                              });
                            },
                      child: const Text('Cancel Edit'),
                    ),
                    OutlinedButton(
                      onPressed: _isSubmitting || !canDeleteSuppliers
                          ? null
                          : _deleteSupplier,
                      child: const Text('Delete Supplier'),
                    ),
                  ],
                ),
              ],
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
              Text('Suppliers', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Review supplier exposure first, then open the selected record for edits or ledger review.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _supplierSearchController,
                decoration: InputDecoration(
                  labelText: 'Search Suppliers',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _supplierSearchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _supplierSearchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_filteredSuppliers.isEmpty)
                const Text('No suppliers found yet.')
              else
                ..._filteredSuppliers.map(
                  (supplier) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      selected: supplier['id'] == _selectedSupplierId,
                      title: Text('${supplier['code']} - ${supplier['name']}'),
                      subtitle: Text(
                        'Payable ${_formatNumber(supplier['payable_balance'])} • ${supplier['phone'] ?? 'No phone'}',
                      ),
                      trailing: supplier['id'] == _selectedSupplierId
                          ? const Icon(Icons.check_circle_outline)
                          : null,
                      onTap: () => _selectSupplier(supplier),
                    ),
                  ),
                ),
              if (_canReadLedger && _selectedSupplierLedgerSummary != null) ...[
                const Divider(height: 24),
                Text(
                  'Ledger Snapshot',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildLedgerSummaryCard(
                  summary: _selectedSupplierLedgerSummary!,
                  entries: List<Map<String, dynamic>>.from(
                    (_selectedSupplierLedger?['ledger'] as List? ?? const [])
                        .map((item) => Map<String, dynamic>.from(item as Map)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLedgerSummaryCard({
    required Map<String, dynamic> summary,
    required List<Map<String, dynamic>> entries,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricChip(
              'Current Balance',
              _formatNumber(summary['current_balance']),
            ),
            _buildMetricChip(
              'Charges',
              _formatNumber(summary['total_charges']),
            ),
            _buildMetricChip(
              'Payments',
              _formatNumber(summary['total_payments']),
            ),
            _buildMetricChip(
              'Transactions',
              '${summary['transaction_count'] ?? 0}',
            ),
          ],
        ),
        if ((summary['last_activity_at'] as String?)?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            'Last activity: ${_formatDateTime(summary['last_activity_at'])}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Text('No ledger entries found yet.')
        else
          for (final entry in entries.take(5))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                (entry['amount'] as num? ?? 0) < 0
                    ? Icons.south_west_outlined
                    : Icons.north_east_outlined,
              ),
              title: Text(entry['description'] as String? ?? 'Ledger entry'),
              subtitle: Text(_formatDateTime(entry['date'])),
              trailing: Text(_formatNumber(entry['balance'])),
            ),
      ],
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
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
