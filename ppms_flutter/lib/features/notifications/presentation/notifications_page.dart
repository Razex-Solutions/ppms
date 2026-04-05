import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

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
          ? await widget.sessionController.fetchNotificationDeliveryDiagnostics()
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
              (await widget.sessionController.fetchNotificationPreferences()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final deliveries = _showNotificationsWorkspace
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchNotificationDeliveries()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
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

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _MetricCard(
                    label: 'Unread',
                    value: '$unreadCount',
                    width: compact ? constraints.maxWidth : 220,
                  ),
                  _MetricCard(
                    label: 'Total',
                    value: '$totalCount',
                    width: compact ? constraints.maxWidth : 220,
                  ),
                  _MetricCard(
                    label: 'Dead Letter',
                    value: '$deadLetterCount',
                    width: compact ? constraints.maxWidth : 220,
                  ),
                  _MetricCard(
                    label: 'Channels',
                    value: byChannel.entries
                        .map((entry) => '${entry.key}:${entry.value}')
                        .join('  '),
                    width: compact ? constraints.maxWidth : 220,
                  ),
                ],
              );
            },
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
                            ? const Chip(label: Text('Retry from backend'))
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.width = 220,
  });

  final String label;
  final String value;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
