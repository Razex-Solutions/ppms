import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  Map<String, dynamic>? _summary;
  Map<String, dynamic>? _diagnostics;
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _preferences = const [];
  List<Map<String, dynamic>> _deliveries = const [];
  String _deliveryStatusFilter = 'all';
  String _deliveryChannelFilter = 'all';

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final summary = _showNotificationsWorkspace
          ? await widget.sessionController.fetchNotificationSummary()
          : <String, dynamic>{};
      final diagnostics = _showNotificationsWorkspace
          ? await widget.sessionController
                .fetchNotificationDeliveryDiagnostics()
          : <String, dynamic>{};
      final notifications = _showNotificationsWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNotifications()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final preferences = _showNotificationsWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNotificationPreferences())
                  .map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final deliveries = _showNotificationsWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNotificationDeliveries(
                status: _deliveryStatusFilter == 'all'
                    ? null
                    : _deliveryStatusFilter,
                channel: _deliveryChannelFilter == 'all'
                    ? null
                    : _deliveryChannelFilter,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];

      if (!mounted) {
        return;
      }

      setState(() {
        _summary = summary;
        _diagnostics = diagnostics;
        _notifications = notifications;
        _preferences = preferences;
        _deliveries = deliveries;
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

  Future<void> _markRead(int notificationId) async {
    await _submitAction(() async {
      await widget.sessionController.markNotificationRead(
        notificationId: notificationId,
      );
      _feedbackMessage = 'Notification marked as read.';
      await _loadNotifications();
    });
  }

  Future<void> _markAllRead() async {
    await _submitAction(() async {
      final result = await widget.sessionController.markAllNotificationsRead();
      _feedbackMessage =
          '${result['marked_read']} notifications marked as read.';
      await _loadNotifications();
    });
  }

  Future<void> _togglePreference(
    Map<String, dynamic> preference,
    String field,
    bool value,
  ) async {
    final payload = {
      'event_type': preference['event_type'],
      'in_app_enabled': preference['in_app_enabled'],
      'email_enabled': preference['email_enabled'],
      'sms_enabled': preference['sms_enabled'],
      'whatsapp_enabled': preference['whatsapp_enabled'],
      field: value,
    };
    await _submitAction(() async {
      await widget.sessionController.updateNotificationPreference(
        eventType: preference['event_type'] as String,
        payload: payload,
      );
      _feedbackMessage = 'Preference updated for ${preference['event_type']}.';
      await _loadNotifications();
    });
  }

  Future<void> _retryDelivery(int deliveryId) async {
    await _submitAction(() async {
      final result = await widget.sessionController.retryNotificationDelivery(
        deliveryId: deliveryId,
      );
      _feedbackMessage =
          'Notification delivery ${result['id']} retried with status ${result['status']}.';
      await _loadNotifications();
    });
  }

  Future<void> _processDueDeliveries() async {
    await _submitAction(() async {
      final result = await widget.sessionController
          .processDueNotificationDeliveries();
      _feedbackMessage =
          'Processed ${result['processed_count'] ?? result['processed'] ?? 0} due notification deliveries.';
      await _loadNotifications();
    });
  }

  Future<void> _submitAction(Future<void> Function() action) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      await action();
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

  bool get _showNotificationsWorkspace => _capabilities.featureVisible(
    platformFeature: false,
    modules: const ['notifications'],
    permissionModules: const ['notifications'],
    hideWhenModulesOff: true,
  );

  int _countDeliveriesByStatus(String status) {
    return _deliveries.where((delivery) {
      return delivery['status']?.toString() == status;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (!_showNotificationsWorkspace) {
      return Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Notifications are turned off for this scope, so the inbox stays hidden.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }
    if (_isLoading && _summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _summary == null) {
      return Center(child: Text(_errorMessage!));
    }

    final unreadCount = _summary?['unread'] ?? 0;
    final totalCount = _summary?['total'] ?? 0;
    final deadLetterCount = _diagnostics?['dead_letter'] ?? 0;
    final byChannel = Map<String, dynamic>.from(
      _diagnostics?['by_channel'] ?? const {},
    );
    final failedDeliveries = _countDeliveriesByStatus('failed');
    final sentDeliveries = _countDeliveriesByStatus('sent');

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Notification Center',
            title: unreadCount > 0
                ? 'Inbox Needs Attention'
                : 'Notification Flow Stable',
            subtitle:
                'Track inbox pressure, delivery health, and preference coverage without leaving the support workspace.',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DashboardMetricTile(
                  label: 'Unread',
                  value: '$unreadCount',
                  caption: 'Actionable inbox items',
                  icon: Icons.mark_email_unread_outlined,
                  tint: Theme.of(context).colorScheme.primaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Total',
                  value: '$totalCount',
                  caption: 'Visible notifications',
                  icon: Icons.notifications_active_outlined,
                  tint: Theme.of(context).colorScheme.secondaryContainer,
                ),
                DashboardMetricTile(
                  label: 'Dead Letter',
                  value: '$deadLetterCount',
                  caption: '$failedDeliveries failed deliveries',
                  icon: Icons.report_problem_outlined,
                  tint: Theme.of(context).colorScheme.errorContainer,
                ),
                DashboardMetricTile(
                  label: 'Sent',
                  value: '$sentDeliveries',
                  caption: byChannel.entries
                      .map((entry) => '${entry.key}:${entry.value}')
                      .join('  '),
                  icon: Icons.send_outlined,
                  tint: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DashboardSectionCard(
            title: 'Support Focus',
            subtitle:
                'Monitor the inbox, adjust channel preferences, and watch delivery reliability from a single communications surface.',
            icon: Icons.support_agent_outlined,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildInfoChip(
                  context,
                  icon: Icons.inbox_outlined,
                  label: '$unreadCount unread',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.settings_input_component_outlined,
                  label: '${_preferences.length} preference sets',
                ),
                _buildInfoChip(
                  context,
                  icon: Icons.local_post_office_outlined,
                  label: '${_deliveries.length} delivery records',
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
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Inbox',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _markAllRead,
                        icon: const Icon(Icons.done_all_outlined),
                        label: const Text('Mark All Read'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_notifications.isEmpty)
                    const Text('No notifications found.')
                  else
                    for (final notification in _notifications.take(20))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          notification['is_read'] == true
                              ? Icons.mark_email_read_outlined
                              : Icons.mark_email_unread_outlined,
                        ),
                        title: Text(
                          notification['title'] as String? ?? 'Notification',
                        ),
                        subtitle: Text(
                          '${notification['message']}\n${_displayTimestamp(notification['created_at'])}',
                        ),
                        isThreeLine: true,
                        trailing: notification['is_read'] == true
                            ? const Chip(label: Text('Read'))
                            : TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () =>
                                          _markRead(notification['id'] as int),
                                child: const Text('Mark Read'),
                              ),
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
                    'Preferences',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_preferences.isEmpty)
                    const Text('No notification preferences found yet.')
                  else
                    for (final preference in _preferences)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          preference['event_type'] as String? ?? 'Event',
                        ),
                        childrenPadding: const EdgeInsets.only(bottom: 12),
                        children: [
                          SwitchListTile(
                            value:
                                preference['in_app_enabled'] as bool? ?? false,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => _togglePreference(
                                    preference,
                                    'in_app_enabled',
                                    value,
                                  ),
                            title: const Text('In-app'),
                          ),
                          SwitchListTile(
                            value:
                                preference['email_enabled'] as bool? ?? false,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => _togglePreference(
                                    preference,
                                    'email_enabled',
                                    value,
                                  ),
                            title: const Text('Email'),
                          ),
                          SwitchListTile(
                            value: preference['sms_enabled'] as bool? ?? false,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => _togglePreference(
                                    preference,
                                    'sms_enabled',
                                    value,
                                  ),
                            title: const Text('SMS'),
                          ),
                          SwitchListTile(
                            value:
                                preference['whatsapp_enabled'] as bool? ??
                                false,
                            onChanged: _isSubmitting
                                ? null
                                : (value) => _togglePreference(
                                    preference,
                                    'whatsapp_enabled',
                                    value,
                                  ),
                            title: const Text('WhatsApp'),
                          ),
                        ],
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
                    'Delivery Activity',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _deliveryStatusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status filter',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
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
                              _deliveryStatusFilter = value ?? 'all';
                            });
                            await _loadNotifications();
                          },
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          initialValue: _deliveryChannelFilter,
                          decoration: const InputDecoration(
                            labelText: 'Channel filter',
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                              value: 'email',
                              child: Text('Email'),
                            ),
                            DropdownMenuItem(value: 'sms', child: Text('SMS')),
                            DropdownMenuItem(
                              value: 'whatsapp',
                              child: Text('WhatsApp'),
                            ),
                            DropdownMenuItem(
                              value: 'in_app',
                              child: Text('In-app'),
                            ),
                          ],
                          onChanged: (value) async {
                            setState(() {
                              _deliveryChannelFilter = value ?? 'all';
                            });
                            await _loadNotifications();
                          },
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isSubmitting ? null : _processDueDeliveries,
                        icon: const Icon(Icons.sync_outlined),
                        label: const Text('Process Due'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_deliveries.isEmpty)
                    const Text('No notification deliveries found.')
                  else
                    for (final delivery in _deliveries.take(20))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.send_outlined),
                        title: Text(
                          '${delivery['channel']} • ${delivery['status']}',
                        ),
                        subtitle: Text(
                          '${delivery['destination'] ?? '-'}\nAttempts ${delivery['attempts_count']} • ${_displayTimestamp(delivery['created_at'])}',
                        ),
                        isThreeLine: true,
                        trailing: delivery['status'] == 'failed'
                            ? TextButton(
                                onPressed: _isSubmitting
                                    ? null
                                    : () =>
                                          _retryDelivery(delivery['id'] as int),
                                child: const Text('Retry'),
                              )
                            : null,
                      ),
                ],
              ),
            ),
          ),
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
