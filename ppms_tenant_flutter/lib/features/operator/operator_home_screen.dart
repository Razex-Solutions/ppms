import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/localization/app_localizations.dart';
import '../../widgets/info_card.dart';
import 'models/operator_models.dart';
import 'operator_repository.dart';

class OperatorHomeScreen extends ConsumerWidget {
  const OperatorHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(selfProfileProvider);
    final attendanceAsync = ref.watch(selfAttendanceProvider);
    final payrollAsync = ref.watch(selfPayrollProvider);
    final actionState = ref.watch(attendanceActionProvider);

    ref.listen<AttendanceActionState>(attendanceActionProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.successMessage == 'checked_in'
                  ? context.l10n.text('checkIn')
                  : context.l10n.text('checkOut'),
            ),
          ),
        );
        ref.read(attendanceActionProvider.notifier).clearMessages();
      }
    });

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        InfoCard(
          title: context.l10n.text('operatorTitle'),
          body: context.l10n.text('operatorSubtitle'),
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: 360, child: _buildProfileCard(context, profileAsync)),
            SizedBox(
              width: 420,
              child: _buildAttendanceCard(
                context,
                attendanceAsync,
                actionState,
                ref,
              ),
            ),
            SizedBox(width: 420, child: _buildPayrollCard(context, payrollAsync)),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileCard(
    BuildContext context,
    AsyncValue<SelfEmployeeProfile> asyncValue,
  ) {
    return asyncValue.when(
      data: (profile) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.text('employeeDetails'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                profile.fullName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              if (profile.staffTitle != null)
                _kv(context.l10n.text('staffTitle'), profile.staffTitle!),
              if (profile.employeeCode != null)
                _kv(context.l10n.text('employeeCode'), profile.employeeCode!),
              if (profile.stationName != null)
                _kv(context.l10n.text('station'), profile.stationName!),
              if (profile.organizationName != null)
                _kv(context.l10n.text('organization'), profile.organizationName!),
              if (profile.phone != null) _kv(context.l10n.text('contactPhone'), profile.phone!),
              if (profile.email != null) _kv(context.l10n.text('contactEmail'), profile.email!),
              if (profile.address != null && profile.address!.trim().isNotEmpty)
                _kv('Address', profile.address!),
              if (!profile.hasEmployeeProfile) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.text('hasNoEmployeeProfile'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: '${context.l10n.text('loadFailed')}: $error'),
    );
  }

  Widget _buildAttendanceCard(
    BuildContext context,
    AsyncValue<SelfAttendanceSummary> asyncValue,
    AttendanceActionState actionState,
    WidgetRef ref,
  ) {
    return asyncValue.when(
      data: (attendance) {
        final today = attendance.todayRecord;
        final canCheckIn = attendance.enabled && today == null;
        final canCheckOut = attendance.enabled && (today?.isOpen ?? false);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('attendanceCard'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!attendance.enabled)
                  Text(context.l10n.text('attendanceDisabled'))
                else ...[
                  if (attendance.stationName != null)
                    _kv(context.l10n.text('station'), attendance.stationName!),
                  _kv(
                    context.l10n.text('todayStatus'),
                    today?.status ?? 'not checked in',
                  ),
                  if (today?.checkInAt != null)
                    _kv(
                      context.l10n.text('checkedInAt'),
                      _formatDateTime(today!.checkInAt!),
                    ),
                  if (today?.checkOutAt != null)
                    _kv(
                      context.l10n.text('checkedOutAt'),
                      _formatDateTime(today!.checkOutAt!),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton(
                        onPressed: actionState.isSubmitting || !canCheckIn
                            ? null
                            : () => ref.read(attendanceActionProvider.notifier).checkIn(),
                        child: Text(context.l10n.text('checkIn')),
                      ),
                      OutlinedButton(
                        onPressed: actionState.isSubmitting || !canCheckOut
                            ? null
                            : () => ref.read(attendanceActionProvider.notifier).checkOut(),
                        child: Text(context.l10n.text('checkOut')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.text('recentAttendance'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (attendance.recentRecords.isEmpty)
                    const Text('-')
                  else
                    for (final record in attendance.recentRecords.take(6))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(DateFormat('dd MMM yyyy').format(record.attendanceDate)),
                        subtitle: Text(record.status),
                        trailing: Text(
                          record.checkOutAt != null
                              ? _formatTime(record.checkOutAt!)
                              : record.checkInAt != null
                                  ? _formatTime(record.checkInAt!)
                                  : '-',
                        ),
                      ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: '${context.l10n.text('loadFailed')}: $error'),
    );
  }

  Widget _buildPayrollCard(
    BuildContext context,
    AsyncValue<SelfPayrollSummary> asyncValue,
  ) {
    return asyncValue.when(
      data: (payroll) {
        final latest = payroll.latestRun;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.text('payrollSummary'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!payroll.enabled)
                  Text(context.l10n.text('payrollDisabled'))
                else ...[
                  _kv(
                    context.l10n.text('currentSalary'),
                    payroll.currentMonthlySalary.toStringAsFixed(0),
                  ),
                  const SizedBox(height: 12),
                  if (latest == null)
                    Text(context.l10n.text('noPayrollHistory'))
                  else ...[
                    Text(
                      context.l10n.text('latestPayroll'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _kv(
                      'Period',
                      '${DateFormat('dd MMM').format(latest.periodStart)} - ${DateFormat('dd MMM yyyy').format(latest.periodEnd)}',
                    ),
                    _kv(context.l10n.text('grossAmount'), latest.grossAmount.toStringAsFixed(0)),
                    if (latest.hasBonus)
                      _kv(
                        context.l10n.text('bonusAmount'),
                        latest.adjustmentAdditions.toStringAsFixed(0),
                      ),
                    if (latest.attendanceDeductions > 0)
                      _kv(
                        context.l10n.text('attendanceDeduction'),
                        latest.attendanceDeductions.toStringAsFixed(0),
                      ),
                    if (latest.adjustmentDeductions > 0)
                      _kv(
                        context.l10n.text('deductions'),
                        latest.deductions.toStringAsFixed(0),
                      ),
                    _kv(context.l10n.text('netAmount'), latest.netAmount.toStringAsFixed(0)),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.text('recentPayrollHistory'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final item in payroll.history.take(6))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${DateFormat('MMM yyyy').format(item.periodStart)} • ${item.status}',
                        ),
                        subtitle: Text(
                          '${context.l10n.text('grossAmount')}: ${item.grossAmount.toStringAsFixed(0)}',
                        ),
                        trailing: Text(item.netAmount.toStringAsFixed(0)),
                      ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(message: '${context.l10n.text('loadFailed')}: $error'),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    return DateFormat('dd MMM yyyy • hh:mm a').format(value.toLocal());
  }

  static String _formatTime(DateTime value) {
    return DateFormat('hh:mm a').format(value.toLocal());
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
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}
