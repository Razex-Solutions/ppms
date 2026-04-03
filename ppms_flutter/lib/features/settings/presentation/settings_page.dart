import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _baseUrlController;
  bool _isSubmitting = false;
  String? _feedbackMessage;
  String? _errorMessage;
  Map<String, dynamic>? _notificationSummary;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.sessionController.baseUrl,
    );
    _loadSupportData();
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSupportData() async {
    try {
      final summary = await widget.sessionController.fetchNotificationSummary();
      if (!mounted) {
        return;
      }
      setState(() {
        _notificationSummary = summary;
      });
    } on ApiException {
      // Keep settings page usable even if the summary is unavailable.
    }
  }

  Future<void> _saveBaseUrl() async {
    final newBaseUrl = _baseUrlController.text.trim();
    if (newBaseUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a backend URL.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _feedbackMessage = null;
      _errorMessage = null;
    });
    try {
      await widget.sessionController.updateBaseUrl(newBaseUrl);
      setState(() {
        _feedbackMessage = 'Backend URL saved locally for this device.';
      });
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
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
    final user = widget.sessionController.currentUser ?? const {};
    final rootInfo = widget.sessionController.rootInfo ?? const {};
    final modules = List<String>.from(rootInfo['enabled_modules'] ?? const []);
    final permissions = Map<String, dynamic>.from(
      user['permissions'] ?? const {},
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 460,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connection',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Backend URL',
                          hintText: 'http://127.0.0.1:8012',
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _isSubmitting ? null : _saveBaseUrl,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save Backend URL'),
                      ),
                      if (_feedbackMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(
              width: 460,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signed-in Context',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text('Name: ${user['full_name'] ?? '-'}'),
                      Text('Username: ${user['username'] ?? '-'}'),
                      Text('Role: ${user['role_name'] ?? '-'}'),
                      Text('Station: ${user['station_id'] ?? '-'}'),
                      Text('Organization: ${user['organization_id'] ?? '-'}'),
                      const SizedBox(height: 12),
                      Text(
                        'Unread notifications: ${_notificationSummary?['unread'] ?? '-'} / ${_notificationSummary?['total'] ?? '-'}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enabled Modules',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (modules.isEmpty)
                  const Text('No enabled modules reported by the backend.')
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final module in modules) Chip(label: Text(module)),
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
                  'Effective Permissions',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (permissions.isEmpty)
                  const Text('No permissions reported by the backend.')
                else
                  for (final entry in permissions.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.key),
                      subtitle: Text((entry.value as List<dynamic>).join(', ')),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
