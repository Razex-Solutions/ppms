import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/utils/document_file_actions.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _DocumentSelectionType {
  fuelSale,
  customerPayment,
  supplierPayment,
  reportExport,
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _fuelSales = const [];
  List<Map<String, dynamic>> _customerPayments = const [];
  List<Map<String, dynamic>> _supplierPayments = const [];
  List<Map<String, dynamic>> _reportExports = const [];
  List<Map<String, dynamic>> _dispatches = const [];
  Map<String, dynamic>? _dispatchDiagnostics;
  String _dispatchStatusFilter = 'all';
  String _dispatchChannelFilter = 'all';

  Map<String, dynamic>? _selectedDocument;
  String? _selectedExportPreview;
  _DocumentSelectionType? _selectionType;
  int? _selectedEntityId;
  String? _lastSavedPath;

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadDocumentCenter();
  }

  bool _hasAction(String module, String action) {
    final modulePermissions =
        widget.sessionController.permissions[module] as List<dynamic>?;
    if (modulePermissions == null) {
      return false;
    }
    return modulePermissions.contains(action);
  }

  bool get _canViewFuelSaleDocs =>
      _showFuelSaleDocs &&
      (_hasAction('fuel_sales', 'create') ||
          _hasAction('fuel_sales', 'reverse'));
  bool get _canViewCustomerPaymentDocs =>
      _showCustomerPaymentDocs && _hasAction('customer_payments', 'create') ||
      _hasAction('customer_payments', 'reverse');
  bool get _canViewSupplierPaymentDocs =>
      _showSupplierPaymentDocs && _hasAction('supplier_payments', 'create') ||
      _hasAction('supplier_payments', 'reverse');
  bool get _canViewReportExports => _hasAction('reports', 'read');
  bool get _showFuelSaleDocs => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['fuel_sales'],
    permissionModules: const ['fuel_sales'],
    hideWhenModulesOff: true,
  );
  bool get _showCustomerPaymentDocs => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['customer_payments'],
    permissionModules: const ['customer_payments'],
    hideWhenModulesOff: true,
  );
  bool get _showSupplierPaymentDocs => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['supplier_payments'],
    permissionModules: const ['supplier_payments'],
    hideWhenModulesOff: true,
  );
  bool get _canViewAnyDocuments =>
      _canViewFuelSaleDocs ||
      _canViewCustomerPaymentDocs ||
      _canViewSupplierPaymentDocs ||
      _canViewReportExports;

  Future<void> _loadDocumentCenter() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final stationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final fuelSales = _canViewFuelSaleDocs
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchFuelSales(
                stationId: stationId,
                limit: 12,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final customerPayments = _canViewCustomerPaymentDocs
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchCustomerPayments(
                stationId: stationId,
                limit: 12,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final supplierPayments = _canViewSupplierPaymentDocs
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchSupplierPayments(
                stationId: stationId,
                limit: 12,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final reportExports = _canViewReportExports
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchReportExports()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final dispatches = _canViewAnyDocuments
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchFinancialDocumentDispatches(
                status: _dispatchStatusFilter == 'all'
                    ? null
                    : _dispatchStatusFilter,
                channel: _dispatchChannelFilter == 'all'
                    ? null
                    : _dispatchChannelFilter,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final dispatchDiagnostics = _canViewAnyDocuments
          ? await widget.sessionController
                .fetchFinancialDocumentDispatchDiagnostics()
          : null;

      if (!mounted) {
        return;
      }

      setState(() {
        _fuelSales = fuelSales;
        _customerPayments = customerPayments;
        _supplierPayments = supplierPayments;
        _reportExports = reportExports;
        _dispatches = dispatches;
        _dispatchDiagnostics = dispatchDiagnostics;
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

  Future<void> _openFuelSaleDocument(int saleId) async {
    await _loadDocument(
      loader: () =>
          widget.sessionController.fetchFuelSaleDocument(saleId: saleId),
    );
  }

  Future<void> _openCustomerPaymentDocument(int paymentId) async {
    await _loadDocument(
      loader: () => widget.sessionController.fetchCustomerPaymentDocument(
        paymentId: paymentId,
      ),
    );
  }

  Future<void> _openSupplierPaymentDocument(int paymentId) async {
    await _loadDocument(
      loader: () => widget.sessionController.fetchSupplierPaymentDocument(
        paymentId: paymentId,
      ),
    );
  }

  Future<void> _previewExport(int jobId) async {
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    try {
      final text = await widget.sessionController.downloadReportExportText(
        jobId: jobId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedExportPreview = text;
        _selectedDocument = null;
        _selectionType = _DocumentSelectionType.reportExport;
        _selectedEntityId = jobId;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _loadDocument({
    required Future<Map<String, dynamic>> Function() loader,
  }) async {
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    try {
      final document = await loader();
      if (!mounted) {
        return;
      }
      setState(() {
        _selectedDocument = document;
        _selectedExportPreview = null;
        _lastSavedPath = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _saveOrOpenCurrentDocument({required bool openAfterSave}) async {
    if (_selectionType == null || _selectedEntityId == null) {
      setState(() {
        _feedbackMessage = 'Select a document or export first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });

    try {
      late final String fileName;
      late final List<int> bytes;

      switch (_selectionType!) {
        case _DocumentSelectionType.fuelSale:
          fileName = 'fuel_sale_${_selectedEntityId!}.pdf';
          bytes = await widget.sessionController.downloadFuelSalePdf(
            saleId: _selectedEntityId!,
          );
        case _DocumentSelectionType.customerPayment:
          fileName = 'customer_payment_${_selectedEntityId!}.pdf';
          bytes = await widget.sessionController.downloadCustomerPaymentPdf(
            paymentId: _selectedEntityId!,
          );
        case _DocumentSelectionType.supplierPayment:
          fileName = 'supplier_payment_${_selectedEntityId!}.pdf';
          bytes = await widget.sessionController.downloadSupplierPaymentPdf(
            paymentId: _selectedEntityId!,
          );
        case _DocumentSelectionType.reportExport:
          fileName = 'report_export_${_selectedEntityId!}.csv';
          final text = await widget.sessionController.downloadReportExportText(
            jobId: _selectedEntityId!,
          );
          bytes = utf8.encode(text);
      }

      final path = await writeBytesToLocalDocumentFile(fileName, bytes);
      if (!mounted) return;

      if (openAfterSave) {
        await openSavedDocument(path);
        if (!mounted) return;
        setState(() {
          _lastSavedPath = path;
          _feedbackMessage = 'Opened $path';
          _isSubmitting = false;
        });
      } else {
        await Clipboard.setData(ClipboardData(text: path));
        if (!mounted) return;
        setState(() {
          _lastSavedPath = path;
          _feedbackMessage = 'Saved to $path and copied the path.';
          _isSubmitting = false;
        });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isSubmitting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to save file: $error';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _retryDispatch(int dispatchId) async {
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    try {
      final result = await widget.sessionController
          .retryFinancialDocumentDispatch(dispatchId: dispatchId);
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Dispatch ${result['id']} retried with status ${result['status']}.';
      });
      await _loadDocumentCenter();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _processDueDispatches() async {
    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    try {
      final result = await widget.sessionController
          .processDueFinancialDocumentDispatches();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Processed ${result['processed_count'] ?? result['processed'] ?? 0} due document dispatches.';
      });
      await _loadDocumentCenter();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canViewAnyDocuments) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'There are no document modules enabled for this role and scope right now.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading &&
        _fuelSales.isEmpty &&
        _customerPayments.isEmpty &&
        _supplierPayments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null &&
        _fuelSales.isEmpty &&
        _customerPayments.isEmpty &&
        _supplierPayments.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final canViewFuelSaleDocs = _canViewFuelSaleDocs;
    final canViewCustomerPaymentDocs = _canViewCustomerPaymentDocs;
    final canViewSupplierPaymentDocs = _canViewSupplierPaymentDocs;
    final canViewReportExports = _canViewReportExports;
    final canViewAnyDocuments = _canViewAnyDocuments;
    final colorScheme = Theme.of(context).colorScheme;
    final deadLetterDispatches = _dispatchDiagnostics?['dead_letter'] ?? 0;
    final dispatchRetrying = _dispatchDiagnostics?['retrying'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadDocumentCenter,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Document Center',
            title: 'Documents and exports',
            subtitle:
                'Review invoices, receipts, vouchers, exports, and dispatch history from one support-friendly workspace.',
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
                    'Visible streams',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (canViewFuelSaleDocs) 'Invoices',
                      if (canViewCustomerPaymentDocs) 'Receipts',
                      if (canViewSupplierPaymentDocs) 'Vouchers',
                      if (canViewReportExports) 'Exports',
                    ].length.toString(),
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
                if (canViewFuelSaleDocs)
                  DashboardMetricTile(
                    label: 'Fuel sale invoices',
                    value: _fuelSales.length.toString(),
                    caption: 'Recent invoice-capable fuel sales',
                    icon: Icons.receipt_long_outlined,
                    tint: colorScheme.primary,
                  ),
                if (canViewCustomerPaymentDocs)
                  DashboardMetricTile(
                    label: 'Customer receipts',
                    value: _customerPayments.length.toString(),
                    caption: 'Receipt-ready customer payments',
                    icon: Icons.account_balance_wallet_outlined,
                    tint: colorScheme.tertiary,
                  ),
                if (canViewSupplierPaymentDocs)
                  DashboardMetricTile(
                    label: 'Supplier vouchers',
                    value: _supplierPayments.length.toString(),
                    caption: 'Voucher-ready supplier payments',
                    icon: Icons.payments_outlined,
                    tint: colorScheme.error,
                  ),
                if (canViewReportExports)
                  DashboardMetricTile(
                    label: 'Report exports',
                    value: _reportExports.length.toString(),
                    caption: 'Generated export jobs',
                    icon: Icons.table_chart_outlined,
                    tint: colorScheme.secondary,
                  ),
                DashboardMetricTile(
                  label: 'Dispatch dead-letter',
                  value: '$deadLetterDispatches',
                  caption: '$dispatchRetrying retrying',
                  icon: Icons.outbox_outlined,
                  tint: colorScheme.errorContainer,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_feedbackMessage != null)
            Text(
              _feedbackMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              if (canViewFuelSaleDocs)
                _buildListCard(
                  context,
                  title: 'Fuel Sale Invoices',
                  items: _fuelSales,
                  itemBuilder: (sale) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sale #${sale['id']} • ${_formatNumber(sale['total_amount'])}',
                    ),
                    subtitle: Text(
                      '${_formatNumber(sale['quantity'])}L • ${_displayTimestamp(sale['created_at'])}',
                    ),
                    onTap: _isSubmitting
                        ? null
                        : () async {
                            _selectionType = _DocumentSelectionType.fuelSale;
                            _selectedEntityId = sale['id'] as int;
                            await _openFuelSaleDocument(sale['id'] as int);
                          },
                  ),
                ),
              if (canViewCustomerPaymentDocs)
                _buildListCard(
                  context,
                  title: 'Customer Payment Receipts',
                  items: _customerPayments,
                  itemBuilder: (payment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Payment #${payment['id']} • ${_formatNumber(payment['amount'])}',
                    ),
                    subtitle: Text(
                      'Customer ${payment['customer_id']} • ${_displayTimestamp(payment['created_at'])}',
                    ),
                    onTap: _isSubmitting
                        ? null
                        : () async {
                            _selectionType =
                                _DocumentSelectionType.customerPayment;
                            _selectedEntityId = payment['id'] as int;
                            await _openCustomerPaymentDocument(
                              payment['id'] as int,
                            );
                          },
                  ),
                ),
              if (canViewSupplierPaymentDocs)
                _buildListCard(
                  context,
                  title: 'Supplier Payment Vouchers',
                  items: _supplierPayments,
                  itemBuilder: (payment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Payment #${payment['id']} • ${_formatNumber(payment['amount'])}',
                    ),
                    subtitle: Text(
                      'Supplier ${payment['supplier_id']} • ${_displayTimestamp(payment['created_at'])}',
                    ),
                    onTap: _isSubmitting
                        ? null
                        : () async {
                            _selectionType =
                                _DocumentSelectionType.supplierPayment;
                            _selectedEntityId = payment['id'] as int;
                            await _openSupplierPaymentDocument(
                              payment['id'] as int,
                            );
                          },
                  ),
                ),
              if (!canViewAnyDocuments)
                _buildListCard(
                  context,
                  title: 'Documents',
                  items: const [],
                  emptyMessage:
                      'This role does not currently have access to invoices, receipts, vouchers, or export files.',
                  itemBuilder: (_) => const SizedBox.shrink(),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final useColumn = constraints.maxWidth < 1000;
              final previewCard = DashboardSectionCard(
                icon: Icons.preview_outlined,
                title: 'Preview',
                subtitle:
                    'Open a document stream on the left to inspect and save it here.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!canViewAnyDocuments)
                      const Text('No document preview access for this role.')
                    else if (_selectedDocument != null) ...[
                      _buildDocumentSummaryChips(_selectedDocument!),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _saveOrOpenCurrentDocument(
                                    openAfterSave: false,
                                  ),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save'),
                          ),
                          FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _saveOrOpenCurrentDocument(
                                    openAfterSave: true,
                                  ),
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: const Text('Open PDF'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        (_selectedDocument!['rendered_html'] as String? ?? '')
                            .replaceAll(RegExp(r'<[^>]*>'), ' ')
                            .replaceAll('&nbsp;', ' ')
                            .replaceAll(RegExp(r'\s+'), ' ')
                            .trim(),
                      ),
                    ] else if (_selectedExportPreview != null) ...[
                      Text(
                        'Export Preview',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _saveOrOpenCurrentDocument(
                                    openAfterSave: false,
                                  ),
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Save CSV'),
                          ),
                          FilledButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () => _saveOrOpenCurrentDocument(
                                    openAfterSave: true,
                                  ),
                            icon: const Icon(Icons.open_in_new_outlined),
                            label: const Text('Open File'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(_selectedExportPreview!),
                    ] else
                      const Text(
                        'Select an invoice, receipt, voucher, or export job to preview it here.',
                      ),
                  ],
                ),
              );
              final sideColumn = Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Exports',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          if (!canViewReportExports)
                            const Text('No report export access for this role.')
                          else if (_reportExports.isEmpty)
                            const Text('No report exports available.')
                          else
                            for (final job in _reportExports.take(10))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  job['file_name'] as String? ?? 'Export',
                                ),
                                subtitle: Text(
                                  '${job['report_type']} • ${job['status']}',
                                ),
                                onTap: _isSubmitting
                                    ? null
                                    : () async {
                                        _selectionType =
                                            _DocumentSelectionType.reportExport;
                                        _selectedEntityId = job['id'] as int;
                                        await _previewExport(job['id'] as int);
                                      },
                              ),
                        ],
                      ),
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
                            'Dispatch History',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _dispatchStatusFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Status filter',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sent',
                                      child: Text('Sent'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'failed',
                                      child: Text('Failed'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'retrying',
                                      child: Text('Retrying'),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    setState(() {
                                      _dispatchStatusFilter = value ?? 'all';
                                    });
                                    await _loadDocumentCenter();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 170,
                                child: DropdownButtonFormField<String>(
                                  initialValue: _dispatchChannelFilter,
                                  decoration: const InputDecoration(
                                    labelText: 'Channel filter',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'all',
                                      child: Text('All'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'email',
                                      child: Text('Email'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'sms',
                                      child: Text('SMS'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'whatsapp',
                                      child: Text('WhatsApp'),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    setState(() {
                                      _dispatchChannelFilter = value ?? 'all';
                                    });
                                    await _loadDocumentCenter();
                                  },
                                ),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _isSubmitting
                                    ? null
                                    : _processDueDispatches,
                                icon: const Icon(Icons.sync_outlined),
                                label: const Text('Process Due'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (!canViewAnyDocuments)
                            const Text(
                              'No dispatch-history access for this role.',
                            )
                          else if (_dispatches.isEmpty)
                            const Text(
                              'No financial document dispatches found.',
                            )
                          else
                            for (final dispatch in _dispatches.take(10))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${dispatch['document_type']} • ${dispatch['channel']}',
                                ),
                                subtitle: Text(
                                  '${dispatch['status']} • attempts ${dispatch['attempts_count']} • ${_displayTimestamp(dispatch['created_at'])}',
                                ),
                                trailing: dispatch['status'] == 'failed'
                                    ? TextButton(
                                        onPressed: _isSubmitting
                                            ? null
                                            : () => _retryDispatch(
                                                dispatch['id'] as int,
                                              ),
                                        child: const Text('Retry'),
                                      )
                                    : null,
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              );

              if (useColumn) {
                return Column(
                  children: [
                    previewCard,
                    const SizedBox(height: 16),
                    sideColumn,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: previewCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: sideColumn),
                ],
              );
            },
          ),
          if (_lastSavedPath != null) ...[
            const SizedBox(height: 16),
            SelectableText('Last saved file: $_lastSavedPath'),
          ],
        ],
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> items,
    String emptyMessage = 'No items found.',
    required Widget Function(Map<String, dynamic>) itemBuilder,
  }) {
    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              if (items.isEmpty)
                Text(emptyMessage)
              else
                for (final item in items.take(8)) itemBuilder(item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentSummaryChips(Map<String, dynamic> document) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildInfoChip('Title', document['title']?.toString() ?? 'Document'),
        _buildInfoChip(
          'Document #',
          document['document_number']?.toString() ?? '-',
        ),
        _buildInfoChip(
          'Recipient',
          document['recipient_name']?.toString() ?? '-',
        ),
        if (document['total_amount'] != null)
          _buildInfoChip('Total', _formatNumber(document['total_amount'])),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  String _displayTimestamp(dynamic value) {
    if (value == null) {
      return '-';
    }
    final text = value.toString().replaceFirst('T', ' ');
    return text.length >= 19 ? text.substring(0, 19) : text;
  }

  String _formatNumber(dynamic value) {
    if (value is num) {
      return value.toStringAsFixed(2);
    }
    return '0.00';
  }
}
