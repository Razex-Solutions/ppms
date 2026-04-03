import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';

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

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) return;
    setState(() {
      _selectedStationId = stationId;
      _selectedCustomerId = null;
    });
    _resetCustomerForm();
    await _loadWorkspace();
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _stations.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
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
                    'Parties Workspace',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage customers and suppliers that drive fuel sales, purchases, and payment workflows.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
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
                        onChanged: _changeStation,
                      );
                      final sections = SegmentedButton<_PartySection>(
                        segments: const [
                          ButtonSegment(
                            value: _PartySection.customers,
                            label: Text('Customers'),
                            icon: Icon(Icons.groups_outlined),
                          ),
                          ButtonSegment(
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
                  if (_section == _PartySection.customers)
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

  Widget _buildCustomers(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedCustomerId == null ? 'Create Customer' : 'Edit Customer',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerNameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerCodeController,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('customer-type-$_customerType'),
            initialValue: _customerType,
            decoration: const InputDecoration(labelText: 'Customer Type'),
            items: const [
              DropdownMenuItem(value: 'individual', child: Text('Individual')),
              DropdownMenuItem(value: 'company', child: Text('Company')),
              DropdownMenuItem(value: 'pump', child: Text('Pump')),
            ],
            onChanged: (value) {
              setState(() {
                _customerType = value ?? 'individual';
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerPhoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerAddressController,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _customerCreditLimitController,
            decoration: const InputDecoration(labelText: 'Credit Limit'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _saveCustomer,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: Text(
              _selectedCustomerId == null ? 'Create Customer' : 'Save Customer',
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
                  onPressed: _isSubmitting ? null : _deleteCustomer,
                  child: const Text('Delete Customer'),
                ),
              ],
            ),
          ],
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customers', style: Theme.of(context).textTheme.titleLarge),
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
                for (final customer in _filteredCustomers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: customer['id'] == _selectedCustomerId,
                    title: Text('${customer['code']} - ${customer['name']}'),
                    subtitle: Text(
                      '${customer['customer_type']} - Balance ${_formatNumber(customer['outstanding_balance'])} - Limit ${_formatNumber(customer['credit_limit'])}',
                    ),
                    onTap: () => _selectCustomer(customer),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuppliers(BuildContext context) {
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedSupplierId == null ? 'Create Supplier' : 'Edit Supplier',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierNameController,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierCodeController,
            decoration: const InputDecoration(labelText: 'Code'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierPhoneController,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _supplierAddressController,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _saveSupplier,
            icon: _isSubmitting
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_business_outlined),
            label: Text(
              _selectedSupplierId == null ? 'Create Supplier' : 'Save Supplier',
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
                  onPressed: _isSubmitting ? null : _deleteSupplier,
                  child: const Text('Delete Supplier'),
                ),
              ],
            ),
          ],
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suppliers', style: Theme.of(context).textTheme.titleLarge),
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
                for (final supplier in _filteredSuppliers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: supplier['id'] == _selectedSupplierId,
                    title: Text('${supplier['code']} - ${supplier['name']}'),
                    subtitle: Text(
                      'Payable ${_formatNumber(supplier['payable_balance'])}',
                    ),
                    onTap: () => _selectSupplier(supplier),
                  ),
            ],
          ),
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
}
