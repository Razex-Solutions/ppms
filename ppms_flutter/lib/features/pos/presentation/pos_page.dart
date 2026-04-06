import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final _customerNameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isReversing = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _sales = const [];
  final Map<int, double> _cart = {};

  int? _selectedStationId;
  String _selectedModule = 'mart';
  String _paymentMethod = 'cash';
  int? _selectedSaleId;

  static const _modules = <String>[
    'mart',
    'service_station',
    'tyre_shop',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _loadPosWorkspace();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadPosWorkspace() async {
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

      final products = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchPosProducts(
                stationId: stationId,
                module: _selectedModule,
                isActive: true,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );
      final sales = stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchPosSales(
                stationId: stationId,
                module: _selectedModule,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _stations = stations;
        _selectedStationId = stationId;
        _products = products;
        _sales = sales;
        _selectedSaleId = _resolveSelectedSaleId(sales);
        _pruneCart(products);
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

  void _pruneCart(List<Map<String, dynamic>> products) {
    final validIds = products.map((product) => product['id'] as int).toSet();
    _cart.removeWhere((productId, _) => !validIds.contains(productId));
  }

  int? _resolveSelectedSaleId(List<Map<String, dynamic>> sales) {
    if (_selectedSaleId != null &&
        sales.any((sale) => sale['id'] == _selectedSaleId)) {
      return _selectedSaleId;
    }
    if (sales.isNotEmpty) {
      return sales.first['id'] as int;
    }
    return null;
  }

  Future<void> _changeStation(int? stationId) async {
    if (stationId == null) {
      return;
    }
    setState(() {
      _selectedStationId = stationId;
    });
    await _loadPosWorkspace();
  }

  Future<void> _changeModule(String? module) async {
    if (module == null) {
      return;
    }
    setState(() {
      _selectedModule = module;
    });
    await _loadPosWorkspace();
  }

  void _updateQuantity(int productId, double quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = quantity;
      }
    });
  }

  Future<void> _submitSale() async {
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station before creating a POS sale.';
      });
      return;
    }

    final items = _cart.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'product_id': entry.key, 'quantity': entry.value})
        .toList();

    if (items.isEmpty) {
      setState(() {
        _feedbackMessage = 'Add at least one product to the cart.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final sale = await widget.sessionController.createPosSale({
        'station_id': stationId,
        'module': _selectedModule,
        'payment_method': _paymentMethod,
        'customer_name': _emptyToNull(_customerNameController.text),
        'notes': _emptyToNull(_notesController.text),
        'items': items,
      });

      if (!mounted) {
        return;
      }

      _cart.clear();
      _customerNameController.clear();
      _notesController.clear();
      await _loadPosWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage =
            'POS sale #${sale['id']} saved for ${_formatNumber(sale['total_amount'])}.';
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

  Future<void> _reverseSelectedSale() async {
    final sale = _selectedSale;
    if (sale == null) {
      setState(() {
        _feedbackMessage = 'Select a POS sale to reverse.';
      });
      return;
    }

    setState(() {
      _isReversing = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final reversed = await widget.sessionController.reversePosSale(
        saleId: sale['id'] as int,
      );
      if (!mounted) {
        return;
      }
      await _loadPosWorkspace();
      if (!mounted) {
        return;
      }
      setState(() {
        _feedbackMessage = 'POS sale #${reversed['id']} reversed successfully.';
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

  Map<String, dynamic>? get _selectedSale {
    for (final sale in _sales) {
      if (sale['id'] == _selectedSaleId) {
        return sale;
      }
    }
    return null;
  }

  double get _cartTotal {
    double total = 0;
    for (final product in _products) {
      final productId = product['id'] as int;
      final quantity = _cart[productId] ?? 0;
      total += quantity * ((product['price'] as num?)?.toDouble() ?? 0);
    }
    return total;
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

    final selectedSale = _selectedSale;
    final selectedStationLabel = _selectedStationLabel();
    final cartItemCount = _cart.values.fold<double>(0, (sum, qty) => sum + qty);
    final visibleSalesTotal = _sales.fold<double>(
      0,
      (sum, sale) => sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0),
    );
    final reversedCount = _sales.where((sale) {
      return sale['is_reversed'] == true;
    }).length;

    return RefreshIndicator(
      onRefresh: _loadPosWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'POS',
            title: 'POS Sales Review',
            subtitle:
                'Review the station, module, cart, and latest sale state before saving or reversing non-fuel station sales.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DashboardMetricTile(
                  label: 'Products',
                  value: '${_products.length}',
                  caption: _moduleLabel(_selectedModule),
                  icon: Icons.inventory_2_outlined,
                  tint: Theme.of(context).colorScheme.primaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Cart Qty',
                  value: _formatNumber(cartItemCount),
                  caption: 'Current ticket',
                  icon: Icons.shopping_cart_outlined,
                  tint: Theme.of(context).colorScheme.tertiaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Cart Total',
                  value: _formatNumber(_cartTotal),
                  caption: _paymentMethod,
                  icon: Icons.point_of_sale_outlined,
                  tint: Theme.of(context).colorScheme.secondaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Recent Value',
                  value: _formatNumber(visibleSalesTotal),
                  caption: '$reversedCount reversed',
                  icon: Icons.receipt_long_outlined,
                  tint: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: 'Workspace Focus',
            subtitle:
                'Keep the shop/service counter flow guided: confirm scope, build the cart, then review the latest sale before any reversal.',
            icon: Icons.fact_check_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip(
                  context,
                  icon: Icons.store_outlined,
                  label: selectedStationLabel ?? 'No station selected',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.apps_outlined,
                  label: 'Module: ${_moduleLabel(_selectedModule)}',
                ),
                _buildInfoChip(
                  context,
                  icon: cartItemCount > 0
                      ? Icons.check_circle_outline
                      : Icons.add_shopping_cart_outlined,
                  label: cartItemCount > 0
                      ? 'Next: save ticket'
                      : 'Next: add products',
                ),
                _buildInfoChip(
                  context,
                  icon: selectedSale == null
                      ? Icons.receipt_long_outlined
                      : Icons.manage_search_outlined,
                  label: selectedSale == null
                      ? 'No sale selected'
                      : 'Selected sale #${selectedSale['id']}',
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
                          'POS Workspace',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create non-fuel station sales for marts, service counters, and tyre operations.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey<String>(
                                  'pos-station-${_selectedStationId ?? 'none'}',
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
                                onChanged: _changeStation,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey<String>(
                                  'pos-module-$_selectedModule',
                                ),
                                initialValue: _selectedModule,
                                decoration: const InputDecoration(
                                  labelText: 'POS Module',
                                ),
                                items: [
                                  for (final module in _modules)
                                    DropdownMenuItem<String>(
                                      value: module,
                                      child: Text(_moduleLabel(module)),
                                    ),
                                ],
                                onChanged: _changeModule,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          key: ValueKey<String>('pos-payment-$_paymentMethod'),
                          initialValue: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Payment Method',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('Cash'),
                            ),
                            DropdownMenuItem(
                              value: 'card',
                              child: Text('Card'),
                            ),
                            DropdownMenuItem(
                              value: 'credit',
                              child: Text('Credit'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _paymentMethod = value ?? 'cash';
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Sale Notes (optional)',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Products',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (_products.isEmpty)
                          const Text(
                            'No active POS products found for this station/module yet.',
                          )
                        else
                          for (final product in _products)
                            _buildProductTile(context, product),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cart Total',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatNumber(_cartTotal),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ],
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
                          onPressed: _isSubmitting ? null : _submitSale,
                          icon: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.point_of_sale_outlined),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Save POS Sale'),
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
                          'Recent POS Sales',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Latest POS activity for the selected station and module.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_sales.isEmpty)
                          const Text('No POS sales found yet.')
                        else
                          for (final sale in _sales)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                sale['is_reversed'] == true
                                    ? Icons.undo_outlined
                                    : Icons.receipt_long_outlined,
                              ),
                              title: Text(
                                '#${sale['id']} • ${_formatNumber(sale['total_amount'])}',
                              ),
                              subtitle: Text(
                                '${_moduleLabel(sale['module'] as String? ?? 'other')} • ${sale['payment_method']} • ${_formatDateTime(sale['created_at'])}',
                              ),
                              trailing: sale['is_reversed'] == true
                                  ? const Chip(label: Text('Reversed'))
                                  : null,
                              onTap: () {
                                setState(() {
                                  _selectedSaleId = sale['id'] as int;
                                });
                              },
                            ),
                        if (selectedSale != null) ...[
                          const Divider(height: 32),
                          Text(
                            'Selected Sale',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sale #${selectedSale['id']} • ${_formatNumber(selectedSale['total_amount'])}',
                          ),
                          const SizedBox(height: 8),
                          for (final item in List<Map<String, dynamic>>.from(
                            (selectedSale['items'] as List<dynamic>? ??
                                    const [])
                                .map(
                                  (item) =>
                                      Map<String, dynamic>.from(item as Map),
                                ),
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Product ${item['product_id']} • Qty ${_formatNumber(item['quantity'])} • ${_formatNumber(item['line_total'])}',
                              ),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed:
                                _isReversing ||
                                    selectedSale['is_reversed'] == true
                                ? null
                                : _reverseSelectedSale,
                            icon: _isReversing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.undo_outlined),
                            label: const Text('Reverse Selected Sale'),
                          ),
                        ],
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

  Widget _buildProductTile(BuildContext context, Map<String, dynamic> product) {
    final productId = product['id'] as int;
    final quantity = _cart[productId] ?? 0;
    final trackInventory = product['track_inventory'] == true;
    final stock = (product['stock_quantity'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${product['name']} (${product['code']})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product['category']} • ${_formatNumber(product['price'])}'
                    '${trackInventory ? ' • Stock ${_formatNumber(stock)}' : ' • Non-stock item'}',
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: quantity <= 0
                  ? null
                  : () => _updateQuantity(productId, quantity - 1),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 52,
              child: Center(
                child: Text(
                  quantity == quantity.roundToDouble()
                      ? quantity.toInt().toString()
                      : quantity.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              onPressed: trackInventory && quantity >= stock
                  ? null
                  : () => _updateQuantity(productId, quantity + 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  String _moduleLabel(String module) {
    switch (module) {
      case 'mart':
        return 'Mart';
      case 'service_station':
        return 'Service Station';
      case 'tyre_shop':
        return 'Tyre Shop';
      default:
        return 'Other';
    }
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

  String? _selectedStationLabel() {
    for (final station in _stations) {
      if (station['id'] == _selectedStationId) {
        return '${station['name']} (${station['code']})';
      }
    }
    return null;
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
