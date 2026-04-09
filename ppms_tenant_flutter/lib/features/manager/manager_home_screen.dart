import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/app_localizations.dart';
import '../../widgets/info_card.dart';
import 'manager_repository.dart';
import 'models/manager_models.dart';

class ManagerHomeScreen extends ConsumerStatefulWidget {
  const ManagerHomeScreen({super.key});

  @override
  ConsumerState<ManagerHomeScreen> createState() => _ManagerHomeScreenState();
}

class _ManagerHomeScreenState extends ConsumerState<ManagerHomeScreen> {
  final _cashSubmissionController = TextEditingController();
  final _actualCashController = TextEditingController();
  final Map<int, TextEditingController> _closingControllers = {};

  final _dipReadingController = TextEditingController();
  final _dipNotesController = TextEditingController();
  int? _dipTankId;

  final _receiveQuantityController = TextEditingController();
  final _receiveReferenceController = TextEditingController();
  final _receiveNotesController = TextEditingController();
  final _receiveDipBeforeController = TextEditingController();
  final _receiveDipAfterController = TextEditingController();
  int? _receiveSupplierId;
  int? _receiveTankId;
  int? _receiveFuelTypeId;

  final _recoveryAmountController = TextEditingController();
  final _recoveryReferenceController = TextEditingController();
  final _recoveryNotesController = TextEditingController();
  int? _recoveryCustomerId;

  final _creditIncreaseAmountController = TextEditingController();
  final _creditIncreaseReasonController = TextEditingController();
  int? _creditCustomerId;

  final _expenseAmountController = TextEditingController();
  final _expenseNotesController = TextEditingController();
  String _expenseCategory = _expenseCategories.first;

  final _lubricantQuantityController = TextEditingController(text: '1');
  final _lubricantNotesController = TextEditingController();
  int? _lubricantProductId;

  final _internalQuantityController = TextEditingController();
  final _internalPurposeController = TextEditingController();
  final _internalNotesController = TextEditingController();
  int? _internalTankId;
  int? _internalFuelTypeId;

  static const List<String> _expenseCategories = [
    'Food',
    'Tea',
    'Station expense',
    'Shift workers',
    'Maintenance',
    'Utility',
    'Other',
  ];

  @override
  void dispose() {
    _cashSubmissionController.dispose();
    _actualCashController.dispose();
    _dipReadingController.dispose();
    _dipNotesController.dispose();
    _receiveQuantityController.dispose();
    _receiveReferenceController.dispose();
    _receiveNotesController.dispose();
    _receiveDipBeforeController.dispose();
    _receiveDipAfterController.dispose();
    _recoveryAmountController.dispose();
    _recoveryReferenceController.dispose();
    _recoveryNotesController.dispose();
    _creditIncreaseAmountController.dispose();
    _creditIncreaseReasonController.dispose();
    _expenseAmountController.dispose();
    _expenseNotesController.dispose();
    _lubricantQuantityController.dispose();
    _lubricantNotesController.dispose();
    _internalQuantityController.dispose();
    _internalPurposeController.dispose();
    _internalNotesController.dispose();
    for (final controller in _closingControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspaceAsync = ref.watch(managerWorkspaceProvider);
    final actionState = ref.watch(managerActionProvider);

    ref.listen<ManagerActionState>(managerActionProvider, (previous, next) {
      if (!mounted) return;
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      } else if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
        ref.read(managerActionProvider.notifier).clearMessages();
      }
    });

    return workspaceAsync.when(
      data: (workspace) {
        _syncWorkspaceControllers(workspace);
        final supportAsync = ref.watch(managerSupportProvider(workspace.stationId));
        final dashboardRequest = ManagerDashboardRequest(
          stationId: workspace.stationId,
          shiftId: workspace.activeShift?.id,
        );
        final dashboardAsync = ref.watch(managerDashboardProvider(dashboardRequest));
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            InfoCard(
              title: context.l10n.text('managerTitle'),
              body: context.l10n.text('managerSubtitle'),
              icon: Icons.local_gas_station_outlined,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 380,
                  child: _workspaceStatusCard(context, workspace, actionState),
                ),
                SizedBox(
                  width: 380,
                  child: _cashCard(context, workspace, actionState),
                ),
                SizedBox(
                  width: 420,
                  child: _validationCard(context, actionState.validation),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _nozzleChecklistCard(context, workspace, actionState),
            const SizedBox(height: 16),
            supportAsync.when(
              data: (support) {
                _syncSupportDefaults(support);
                return dashboardAsync.when(
                  data: (dashboard) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summarySection(context, dashboard),
                      const SizedBox(height: 16),
                      _taskSection(context, dashboard),
                      const SizedBox(height: 16),
                      _actionsSection(
                        context,
                        workspace,
                        support,
                        dashboard,
                        actionState,
                      ),
                    ],
                  ),
                  loading: () => const _LoadingCard(),
                  error: (error, _) => _ErrorCard(message: '$error'),
                );
              },
              loading: () => const _LoadingCard(),
              error: (error, _) => _ErrorCard(message: '$error'),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          Center(child: Text('${context.l10n.text('loadFailed')}: $error')),
    );
  }

  void _syncWorkspaceControllers(ManagerCurrentWorkspace workspace) {
    for (final group in workspace.openingNozzleGroups) {
      for (final nozzle in group.nozzles) {
        final controller = _closingControllers.putIfAbsent(
          nozzle.nozzleId,
          () => TextEditingController(text: nozzle.currentMeter.toStringAsFixed(0)),
        );
        if (controller.text.trim().isEmpty) {
          controller.text = nozzle.currentMeter.toStringAsFixed(0);
        }
      }
    }
  }

  void _syncSupportDefaults(ManagerSupportData support) {
    _dipTankId ??= support.tanks.isNotEmpty ? support.tanks.first.id : null;
    _receiveSupplierId ??=
        support.suppliers.isNotEmpty ? support.suppliers.first.id : null;
    _receiveTankId ??= support.tanks.isNotEmpty ? support.tanks.first.id : null;
    _receiveFuelTypeId ??= _fuelTypeForTank(support, _receiveTankId);
    _recoveryCustomerId ??=
        support.customers.isNotEmpty ? support.customers.first.id : null;
    _creditCustomerId ??=
        support.customers.isNotEmpty ? support.customers.first.id : null;
    _lubricantProductId ??=
        support.lubricants.isNotEmpty ? support.lubricants.first.id : null;
    _internalTankId ??=
        support.tanks.isNotEmpty ? support.tanks.first.id : null;
    _internalFuelTypeId ??= _fuelTypeForTank(support, _internalTankId);
  }

  int? _fuelTypeForTank(ManagerSupportData support, int? tankId) {
    if (tankId == null) return null;
    for (final tank in support.tanks) {
      if (tank.id == tankId) {
        return tank.fuelTypeId;
      }
    }
    return null;
  }

  Widget _workspaceStatusCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerActionState actionState,
  ) {
    final statusLabel = switch (workspace.status) {
      'open' => context.l10n.text('shiftOpen'),
      'prepared' => context.l10n.text('shiftPrepared'),
      _ => context.l10n.text('shiftMissingTemplate'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(statusLabel, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            _kv(context.l10n.text('shiftMessage'), workspace.message),
            if (workspace.matchedTemplate != null)
              _kv(
                context.l10n.text('shiftTemplate'),
                '${workspace.matchedTemplate!.name} • ${workspace.matchedTemplate!.windowLabel}',
              ),
            if (workspace.openingCashPreview != null)
              _kv(
                context.l10n.text('openingCash'),
                workspace.openingCashPreview!.toStringAsFixed(0),
              ),
            if (workspace.activeShift != null)
              _kv(
                context.l10n.text('shiftStartedAt'),
                DateFormat('dd MMM yyyy • hh:mm a')
                    .format(workspace.activeShift!.startTime.toLocal()),
              ),
            const SizedBox(height: 12),
            if (workspace.isPrepared)
              FilledButton.icon(
                onPressed: actionState.isBusy
                    ? null
                    : () => ref.read(managerActionProvider.notifier).startShift(
                          stationId: workspace.stationId,
                          shiftTemplateId: workspace.matchedTemplate?.id,
                        ),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(context.l10n.text('startCurrentShift')),
              )
            else if (workspace.activeShift == null)
              Text(context.l10n.text('managerNoShift')),
          ],
        ),
      ),
    );
  }

  Widget _cashCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerActionState actionState,
  ) {
    final activeShift = workspace.activeShift;
    if (activeShift == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(context.l10n.text('managerNoShift')),
        ),
      );
    }
    final cashAsync = ref.watch(shiftCashProvider(activeShift.id));
    final submissionsAsync = ref.watch(cashSubmissionsProvider(activeShift.id));
    return cashAsync.when(
      data: (cash) {
        if (_actualCashController.text.trim().isEmpty) {
          _actualCashController.text = cash.cashInHand.toStringAsFixed(0);
        }
        return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.text('cashInHand'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              _kv(
                context.l10n.text('openingCashCarryForward'),
                cash.openingCash.toStringAsFixed(0),
              ),
              _kv(context.l10n.text('expectedCash'), cash.expectedCash.toStringAsFixed(0)),
              _kv(
                context.l10n.text('cashSubmittedSoFar'),
                cash.cashSubmitted.toStringAsFixed(0),
              ),
              _kv(
                context.l10n.text('remainingCashInHand'),
                cash.cashInHand.toStringAsFixed(0),
              ),
              _kv(
                context.l10n.text('nextShiftCarryForward'),
                (cash.closingCash ?? cash.cashInHand).toStringAsFixed(0),
              ),
              if (cash.difference != null)
                _kv(
                  context.l10n.text('cashVarianceLabel'),
                  cash.difference!.toStringAsFixed(0),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cashSubmissionController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('submissionAmount'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: actionState.isBusy
                        ? null
                        : () {
                            final amount =
                                double.tryParse(_cashSubmissionController.text) ?? 0;
                            if (amount <= 0) return;
                            ref.read(managerActionProvider.notifier).submitCash(
                                  stationId: workspace.stationId,
                                  shiftId: activeShift.id,
                                  amount: amount,
                                );
                            _cashSubmissionController.clear();
                          },
                    child: Text(context.l10n.text('submitCash')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.text('recentCashSubmissions'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              submissionsAsync.when(
                data: (items) => items.isEmpty
                    ? Text(context.l10n.text('noRecentItems'))
                    : Column(
                        children: [
                          for (final item in items.take(5))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.amount.toStringAsFixed(0)),
                              subtitle: Text(
                                DateFormat('dd MMM • hh:mm a')
                                    .format(item.submittedAt.toLocal()),
                              ),
                            ),
                        ],
                      ),
                loading: () => const CircularProgressIndicator(),
                error: (error, _) => Text('$error'),
              ),
            ],
          ),
        ),
      );
      },
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: '$error'),
    );
  }

  Widget _validationCard(BuildContext context, ShiftCloseValidation? validation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.text('closeValidation'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (validation == null)
              Text(context.l10n.text('runCloseHint'))
            else ...[
              _kv(context.l10n.text('blockingIssues'),
                  '${validation.blockingIssueCount}'),
              _kv(context.l10n.text('warnings'), '${validation.warningCount}'),
              const SizedBox(height: 8),
              for (final issue in validation.issues)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    issue.blocking
                        ? Icons.error_outline
                        : Icons.warning_amber_outlined,
                  ),
                  title: Text(issue.title),
                  subtitle: Text(issue.detail),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nozzleChecklistCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerActionState actionState,
  ) {
    if (workspace.openingNozzleGroups.isEmpty) {
      return const SizedBox.shrink();
    }
    final activeShift = workspace.activeShift;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.text('dispenserChecklist'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            if (activeShift != null)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _actualCashController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: context.l10n.text('closingCashLeftInHand'),
                        helperText: context.l10n.text('closingCashLeftInHandHint'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonal(
                    onPressed: actionState.isBusy
                        ? null
                        : () => ref.read(managerActionProvider.notifier).runCloseCheck(
                              shiftId: activeShift.id,
                              actualCashCollected:
                                  double.tryParse(_actualCashController.text) ?? 0,
                              nozzleReadings: _buildNozzlePayload(workspace),
                            ),
                    child: Text(context.l10n.text('runCloseCheck')),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: actionState.isBusy
                        ? null
                        : () => ref.read(managerActionProvider.notifier).closeShift(
                              stationId: workspace.stationId,
                              shiftId: activeShift.id,
                              actualCashCollected:
                                  double.tryParse(_actualCashController.text) ?? 0,
                              nozzleReadings: _buildNozzlePayload(workspace),
                            ),
                    child: Text(context.l10n.text('closeShift')),
                  ),
                ],
              ),
            if (activeShift != null) const SizedBox(height: 16),
            for (final group in workspace.openingNozzleGroups)
              ExpansionTile(
                initiallyExpanded: workspace.openingNozzleGroups.length == 1,
                title: Text('${group.dispenserName} (${group.dispenserCode})'),
                children: [
                  for (final nozzle in group.nozzles)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${nozzle.nozzleName} (${nozzle.nozzleCode})',
                                      ),
                                    ),
                                    if (nozzle.hasMeterAdjustmentHistory)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .tertiaryContainer,
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          context.l10n.text('meterAdjustedFlag'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${nozzle.fuelTypeName ?? '-'} • ${context.l10n.text('mappedTank')}: ${nozzle.tankName ?? nozzle.tankId}',
                                ),
                                Text(
                                  '${context.l10n.text('openingMeter')}: ${nozzle.openingMeter.toStringAsFixed(0)} • ${context.l10n.text('currentMeter')}: ${nozzle.currentMeter.toStringAsFixed(0)}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: _closingControllers[nozzle.nozzleId],
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: context.l10n.text('closingMeter'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _summarySection(BuildContext context, ManagerDashboardData dashboard) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('managerTotals'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metricCard(
              context,
              context.l10n.text('fuelSalesCard'),
              dashboard.fuelSalesAmount.toStringAsFixed(0),
              '${dashboard.fuelSalesLiters.toStringAsFixed(0)} ${context.l10n.text('liters')}',
            ),
            _metricCard(
              context,
              context.l10n.text('lubricantSalesCard'),
              dashboard.lubricantSalesAmount.toStringAsFixed(0),
              '${dashboard.lubricantSales.length} ${context.l10n.text('entries')}',
            ),
            _metricCard(
              context,
              context.l10n.text('receivingCard'),
              dashboard.receivingAmount.toStringAsFixed(0),
              '${dashboard.receivingLiters.toStringAsFixed(0)} ${context.l10n.text('liters')}',
            ),
            _metricCard(
              context,
              context.l10n.text('expenseCard'),
              dashboard.expenseAmount.toStringAsFixed(0),
              '${dashboard.expenses.length} ${context.l10n.text('entries')}',
            ),
            _metricCard(
              context,
              context.l10n.text('recoveryCard'),
              dashboard.recoveryAmount.toStringAsFixed(0),
              '${dashboard.recoveries.length} ${context.l10n.text('entries')}',
            ),
            _metricCard(
              context,
              context.l10n.text('internalUsageCard'),
              dashboard.internalUsageLiters.toStringAsFixed(0),
              context.l10n.text('liters'),
            ),
            _metricCard(
              context,
              context.l10n.text('managerNotifications'),
              '${dashboard.notificationSummary.unread}',
              '${dashboard.notificationSummary.total} ${context.l10n.text('totalLabel')}',
            ),
          ],
        ),
      ],
    );
  }

  Widget _taskSection(BuildContext context, ManagerDashboardData dashboard) {
    final followUps = dashboard.outstandingCustomers.take(5).toList();
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.text('creditFollowUps'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (followUps.isEmpty)
                    Text(context.l10n.text('noPendingFollowUps'))
                  else
                    for (final customer in followUps)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${customer.name} (${customer.code})'),
                        subtitle: Text(
                          '${context.l10n.text('outstandingLabel')}: ${customer.outstandingBalance.toStringAsFixed(0)} • ${context.l10n.text('creditLimitLabel')}: ${customer.creditLimit.toStringAsFixed(0)}',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.text('recentDipActivity'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (dashboard.recentDips.isEmpty)
                    Text(context.l10n.text('noRecentItems'))
                  else
                    for (final dip in dashboard.recentDips.take(5))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${context.l10n.text('tank')} #${dip.tankId} • ${dip.dipReadingMm.toStringAsFixed(0)} mm',
                        ),
                        subtitle: Text(
                          '${dip.calculatedVolume.toStringAsFixed(0)} ${context.l10n.text('liters')} • ${DateFormat('dd MMM • hh:mm a').format(dip.createdAt.toLocal())}',
                        ),
                      ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionsSection(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerDashboardData dashboard,
    ManagerActionState actionState,
  ) {
    final activeShiftId = workspace.activeShift?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.text('managerActions'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 420,
              child: _dipActionCard(
                context,
                workspace,
                support,
                actionState,
                activeShiftId,
              ),
            ),
            SizedBox(
              width: 420,
              child: _receivingActionCard(
                context,
                workspace,
                support,
                actionState,
                activeShiftId,
              ),
            ),
            SizedBox(
              width: 420,
              child: _recoveryActionCard(
                context,
                workspace,
                support,
                dashboard,
                actionState,
                activeShiftId,
              ),
            ),
            SizedBox(
              width: 420,
              child: _expenseActionCard(
                context,
                workspace,
                actionState,
                activeShiftId,
              ),
            ),
            SizedBox(
              width: 420,
              child: _lubricantActionCard(
                context,
                workspace,
                support,
                actionState,
                activeShiftId,
              ),
            ),
            SizedBox(
              width: 420,
              child: _internalUsageActionCard(
                context,
                workspace,
                support,
                actionState,
                activeShiftId,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _dipActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    return _actionCard(
      context,
      title: context.l10n.text('recordDipAction'),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _dipTankId,
            decoration: InputDecoration(labelText: context.l10n.text('tank')),
            items: [
              for (final tank in support.tanks)
                DropdownMenuItem(
                  value: tank.id,
                  child: Text('${tank.name} (${tank.code})'),
                ),
            ],
            onChanged: (value) => setState(() => _dipTankId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dipReadingController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('dipReadingMm')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dipNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final reading = double.tryParse(_dipReadingController.text) ?? 0;
                      if ((_dipTankId ?? 0) <= 0 || reading <= 0) return;
                      ref.read(managerActionProvider.notifier).recordDip(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            tankId: _dipTankId!,
                            dipReadingMm: reading,
                            notes: _emptyToNull(_dipNotesController.text),
                          );
                      _dipReadingController.clear();
                      _dipNotesController.clear();
                    },
              child: Text(context.l10n.text('recordDipAction')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receivingActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    return _actionCard(
      context,
      title: context.l10n.text('recordReceivingAction'),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _receiveSupplierId,
            decoration: InputDecoration(labelText: context.l10n.text('supplier')),
            items: [
              for (final supplier in support.suppliers)
                DropdownMenuItem(
                  value: supplier.id,
                  child: Text('${supplier.name} (${supplier.code})'),
                ),
            ],
            onChanged: (value) => setState(() => _receiveSupplierId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _receiveTankId,
            decoration: InputDecoration(labelText: context.l10n.text('tank')),
            items: [
              for (final tank in support.tanks)
                DropdownMenuItem(
                  value: tank.id,
                  child: Text('${tank.name} (${tank.code})'),
                ),
            ],
            onChanged: (value) => setState(() {
              _receiveTankId = value;
              _receiveFuelTypeId = _fuelTypeForTank(support, value);
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _receiveFuelTypeId,
            decoration: InputDecoration(labelText: context.l10n.text('fuelType')),
            items: [
              for (final fuelType in support.fuelTypes)
                DropdownMenuItem(
                  value: fuelType.id,
                  child: Text(fuelType.name),
                ),
            ],
            onChanged: (value) => setState(() => _receiveFuelTypeId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiveQuantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('quantity')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _receiveDipBeforeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.l10n.text('dipBefore')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _receiveDipAfterController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: context.l10n.text('dipAfter')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiveReferenceController,
            decoration: InputDecoration(labelText: context.l10n.text('referenceGrn')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _receiveNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final quantity = double.tryParse(_receiveQuantityController.text) ?? 0;
                      if ((_receiveSupplierId ?? 0) <= 0 ||
                          (_receiveTankId ?? 0) <= 0 ||
                          (_receiveFuelTypeId ?? 0) <= 0 ||
                          quantity <= 0) {
                        return;
                      }
                      ref.read(managerActionProvider.notifier).createReceiving(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            supplierId: _receiveSupplierId!,
                            tankId: _receiveTankId!,
                            fuelTypeId: _receiveFuelTypeId!,
                            quantity: quantity,
                            referenceNo: _emptyToNull(_receiveReferenceController.text),
                            notes: _emptyToNull(_receiveNotesController.text),
                            dipBeforeMm:
                                double.tryParse(_receiveDipBeforeController.text),
                            dipAfterMm:
                                double.tryParse(_receiveDipAfterController.text),
                          );
                      _receiveQuantityController.clear();
                      _receiveReferenceController.clear();
                      _receiveNotesController.clear();
                      _receiveDipBeforeController.clear();
                      _receiveDipAfterController.clear();
                    },
              child: Text(context.l10n.text('recordReceivingAction')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recoveryActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerDashboardData dashboard,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    CustomerSummary? selectedCustomer;
    CustomerSummary? selectedCreditCustomer;
    for (final customer in support.customers) {
      if (customer.id == _recoveryCustomerId) {
        selectedCustomer = customer;
      }
      if (customer.id == _creditCustomerId) {
        selectedCreditCustomer = customer;
      }
    }
    return _actionCard(
      context,
      title: context.l10n.text('creditRecoveryAction'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<int>(
            initialValue: _recoveryCustomerId,
            decoration: InputDecoration(labelText: context.l10n.text('customer')),
            items: [
              for (final customer in support.customers)
                DropdownMenuItem(
                  value: customer.id,
                  child: Text('${customer.name} (${customer.code})'),
                ),
            ],
            onChanged: (value) => setState(() => _recoveryCustomerId = value),
          ),
          if (selectedCustomer != null) ...[
            const SizedBox(height: 8),
            Text(
              '${context.l10n.text('outstandingLabel')}: ${selectedCustomer.outstandingBalance.toStringAsFixed(0)}',
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _recoveryAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('recoveredAmount')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recoveryReferenceController,
            decoration: InputDecoration(labelText: context.l10n.text('referenceNumber')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recoveryNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final amount = double.tryParse(_recoveryAmountController.text) ?? 0;
                      if ((_recoveryCustomerId ?? 0) <= 0 || amount <= 0) return;
                      ref.read(managerActionProvider.notifier).recoverCustomerCredit(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            customerId: _recoveryCustomerId!,
                            amount: amount,
                            referenceNo: _emptyToNull(_recoveryReferenceController.text),
                            notes: _emptyToNull(_recoveryNotesController.text),
                          );
                      _recoveryAmountController.clear();
                      _recoveryReferenceController.clear();
                      _recoveryNotesController.clear();
                    },
              child: Text(context.l10n.text('recoverNow')),
            ),
          ),
          const Divider(height: 24),
          Text(
            context.l10n.text('increaseCreditAction'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _creditCustomerId,
            decoration: InputDecoration(labelText: context.l10n.text('customer')),
            items: [
              for (final customer in support.customers)
                DropdownMenuItem(
                  value: customer.id,
                  child: Text('${customer.name} (${customer.code})'),
                ),
            ],
            onChanged: (value) => setState(() => _creditCustomerId = value),
          ),
          if (selectedCreditCustomer != null) ...[
            const SizedBox(height: 8),
            Text(
              '${context.l10n.text('creditLimitLabel')}: ${selectedCreditCustomer.creditLimit.toStringAsFixed(0)}',
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _creditIncreaseAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('increaseBy')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _creditIncreaseReasonController,
            decoration: InputDecoration(labelText: context.l10n.text('reasonOptional')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonal(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final amount =
                          double.tryParse(_creditIncreaseAmountController.text) ?? 0;
                      if ((_creditCustomerId ?? 0) <= 0 || amount <= 0) return;
                      ref.read(managerActionProvider.notifier).increaseCustomerCredit(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            customerId: _creditCustomerId!,
                            amount: amount,
                            reason: _emptyToNull(_creditIncreaseReasonController.text),
                          );
                      _creditIncreaseAmountController.clear();
                      _creditIncreaseReasonController.clear();
                    },
              child: Text(context.l10n.text('increaseCreditAction')),
            ),
          ),
          if (dashboard.outstandingCustomers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.text('topCreditList'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final customer in dashboard.outstandingCustomers.take(3))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(customer.name),
                subtitle: Text(
                  '${context.l10n.text('outstandingLabel')}: ${customer.outstandingBalance.toStringAsFixed(0)}',
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _expenseActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    return _actionCard(
      context,
      title: context.l10n.text('recordExpenseAction'),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _expenseCategory,
            decoration: InputDecoration(labelText: context.l10n.text('expenseCategory')),
            items: [
              for (final category in _expenseCategories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _expenseCategory = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expenseAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('amount')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _expenseNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final amount = double.tryParse(_expenseAmountController.text) ?? 0;
                      if (amount <= 0) return;
                      ref.read(managerActionProvider.notifier).createExpense(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            category: _expenseCategory,
                            amount: amount,
                            notes: _emptyToNull(_expenseNotesController.text),
                          );
                      _expenseAmountController.clear();
                      _expenseNotesController.clear();
                    },
              child: Text(context.l10n.text('recordExpenseAction')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lubricantActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    return _actionCard(
      context,
      title: context.l10n.text('sellLubricantAction'),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _lubricantProductId,
            decoration: InputDecoration(labelText: context.l10n.text('product')),
            items: [
              for (final product in support.lubricants)
                DropdownMenuItem(
                  value: product.id,
                  child: Text(
                    '${product.name} (${product.stockQuantity.toStringAsFixed(0)} ${context.l10n.text('stockLabel')})',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _lubricantProductId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lubricantQuantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('quantity')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lubricantNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final quantity =
                          double.tryParse(_lubricantQuantityController.text) ?? 0;
                      if ((_lubricantProductId ?? 0) <= 0 || quantity <= 0) return;
                      ref.read(managerActionProvider.notifier).createLubricantSale(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            productId: _lubricantProductId!,
                            quantity: quantity,
                            notes: _emptyToNull(_lubricantNotesController.text),
                          );
                      _lubricantQuantityController.text = '1';
                      _lubricantNotesController.clear();
                    },
              child: Text(context.l10n.text('sellLubricantAction')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _internalUsageActionCard(
    BuildContext context,
    ManagerCurrentWorkspace workspace,
    ManagerSupportData support,
    ManagerActionState actionState,
    int? activeShiftId,
  ) {
    return _actionCard(
      context,
      title: context.l10n.text('internalUsageAction'),
      child: Column(
        children: [
          DropdownButtonFormField<int>(
            initialValue: _internalTankId,
            decoration: InputDecoration(labelText: context.l10n.text('tank')),
            items: [
              for (final tank in support.tanks)
                DropdownMenuItem(
                  value: tank.id,
                  child: Text('${tank.name} (${tank.code})'),
                ),
            ],
            onChanged: (value) => setState(() {
              _internalTankId = value;
              _internalFuelTypeId = _fuelTypeForTank(support, value);
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _internalFuelTypeId,
            decoration: InputDecoration(labelText: context.l10n.text('fuelType')),
            items: [
              for (final fuelType in support.fuelTypes)
                DropdownMenuItem(
                  value: fuelType.id,
                  child: Text(fuelType.name),
                ),
            ],
            onChanged: (value) => setState(() => _internalFuelTypeId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _internalQuantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: context.l10n.text('quantity')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _internalPurposeController,
            decoration: InputDecoration(labelText: context.l10n.text('vehiclePurpose')),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _internalNotesController,
            decoration: InputDecoration(labelText: context.l10n.text('optionalNotes')),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: actionState.isBusy
                  ? null
                  : () {
                      final quantity =
                          double.tryParse(_internalQuantityController.text) ?? 0;
                      if ((_internalTankId ?? 0) <= 0 ||
                          (_internalFuelTypeId ?? 0) <= 0 ||
                          quantity <= 0 ||
                          _internalPurposeController.text.trim().length < 3) {
                        return;
                      }
                      ref.read(managerActionProvider.notifier).createInternalUsage(
                            stationId: workspace.stationId,
                            shiftId: activeShiftId,
                            tankId: _internalTankId!,
                            fuelTypeId: _internalFuelTypeId!,
                            quantity: quantity,
                            purpose: _internalPurposeController.text.trim(),
                            notes: _emptyToNull(_internalNotesController.text),
                          );
                      _internalQuantityController.clear();
                      _internalPurposeController.clear();
                      _internalNotesController.clear();
                    },
              child: Text(context.l10n.text('internalUsageAction')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context,
    String title,
    String value,
    String subtitle,
  ) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _buildNozzlePayload(
    ManagerCurrentWorkspace workspace,
  ) {
    return [
      for (final group in workspace.openingNozzleGroups)
        for (final nozzle in group.nozzles)
          {
            'nozzle_id': nozzle.nozzleId,
            'closing_meter':
                double.tryParse(_closingControllers[nozzle.nozzleId]?.text ?? '') ??
                    nozzle.currentMeter,
          },
    ];
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 130, child: Text(label)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message),
      ),
    );
  }
}
