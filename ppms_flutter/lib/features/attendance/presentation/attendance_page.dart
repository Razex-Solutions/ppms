import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _manualFormKey = GlobalKey<FormState>();
  final _checkInNotesController = TextEditingController();
  final _checkOutNotesController = TextEditingController();
  final _manualNotesController = TextEditingController();
  final _manualDateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  List<Map<String, dynamic>> _attendance = const [];
  List<Map<String, dynamic>> _users = const [];

  int? _selectedUserId;
  String _manualStatus = 'present';

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  @override
  void dispose() {
    _checkInNotesController.dispose();
    _checkOutNotesController.dispose();
    _manualNotesController.dispose();
    _manualDateController.dispose();
    super.dispose();
  }

  Future<void> _loadAttendance() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final attendance = List<Map<String, dynamic>>.from(
        (await widget.sessionController.fetchAttendance()).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );

      List<Map<String, dynamic>> users = const [];
      final permissions =
          widget.sessionController.currentUser?['permissions']
              as Map<String, dynamic>? ??
          const {};
      if (permissions.containsKey('users')) {
        try {
          users = List<Map<String, dynamic>>.from(
            (await widget.sessionController.fetchUsers(
              stationId:
                  widget.sessionController.currentUser?['station_id'] as int?,
            )).map((item) => Map<String, dynamic>.from(item as Map)),
          );
        } on ApiException {
          users = const [];
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _attendance = attendance;
        _users = users;
        _selectedUserId = users.isNotEmpty ? users.first['id'] as int : null;
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

  Future<void> _performCheckIn() async {
    final stationId =
        widget.sessionController.currentUser?['station_id'] as int?;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Your account is not assigned to a station.';
      });
      return;
    }
    await _submitAction(() async {
      final record = await widget.sessionController.checkIn(
        stationId: stationId,
        notes: _checkInNotesController.text.trim().isEmpty
            ? null
            : _checkInNotesController.text.trim(),
      );
      _checkInNotesController.clear();
      _feedbackMessage = 'Checked in successfully for record #${record['id']}.';
      await _loadAttendance();
    });
  }

  Future<void> _performCheckOut() async {
    final record = _todayOpenRecord;
    if (record == null) {
      setState(() {
        _feedbackMessage = 'No open attendance record found for today.';
      });
      return;
    }
    await _submitAction(() async {
      final updatedRecord = await widget.sessionController.checkOut(
        attendanceId: record['id'] as int,
        notes: _checkOutNotesController.text.trim().isEmpty
            ? null
            : _checkOutNotesController.text.trim(),
      );
      _checkOutNotesController.clear();
      _feedbackMessage =
          'Checked out successfully for record #${updatedRecord['id']}.';
      await _loadAttendance();
    });
  }

  Future<void> _createManualRecord() async {
    if (!_manualFormKey.currentState!.validate()) {
      return;
    }
    final stationId =
        widget.sessionController.currentUser?['station_id'] as int?;
    if (stationId == null || _selectedUserId == null) {
      setState(() {
        _feedbackMessage =
            'Select a valid user and station for manual attendance.';
      });
      return;
    }
    await _submitAction(() async {
      final record = await widget.sessionController.createAttendanceRecord({
        'user_id': _selectedUserId,
        'station_id': stationId,
        'attendance_date': _manualDateController.text.trim(),
        'status': _manualStatus,
        'notes': _manualNotesController.text.trim().isEmpty
            ? null
            : _manualNotesController.text.trim(),
      });
      _manualNotesController.clear();
      _feedbackMessage = 'Manual attendance record #${record['id']} created.';
      await _loadAttendance();
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

  Map<String, dynamic>? get _todayOpenRecord {
    final currentUserId = widget.sessionController.currentUser?['id'];
    final today = DateTime.now().toIso8601String().split('T').first;
    for (final record in _attendance) {
      if (record['user_id'] == currentUserId &&
          record['attendance_date'].toString() == today &&
          record['check_out_at'] == null) {
        return record;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _attendance.isEmpty) {
      return Center(child: Text(_errorMessage!));
    }

    final todayOpenRecord = _todayOpenRecord;
    final canManualCreate = _users.isNotEmpty;

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
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
                          'Today\'s Attendance',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          todayOpenRecord == null
                              ? 'No open attendance record found for today.'
                              : 'Open record #${todayOpenRecord['id']} • status ${todayOpenRecord['status']}',
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _checkInNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Check-in notes',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _isSubmitting ? null : _performCheckIn,
                          icon: const Icon(Icons.login),
                          label: const Text('Check In'),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _checkOutNotesController,
                          decoration: const InputDecoration(
                            labelText: 'Check-out notes',
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonalIcon(
                          onPressed: _isSubmitting || todayOpenRecord == null
                              ? null
                              : _performCheckOut,
                          icon: const Icon(Icons.logout),
                          label: const Text('Check Out'),
                        ),
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
                    child: Form(
                      key: _manualFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Attendance',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            canManualCreate
                                ? 'Create corrected attendance records for staff users available to your role.'
                                : 'Manual attendance creation needs user-directory access from the backend. Self-service check-in/check-out is still available.',
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            key: ValueKey<int?>(_selectedUserId),
                            initialValue: _selectedUserId,
                            decoration: const InputDecoration(
                              labelText: 'User',
                            ),
                            items: [
                              for (final user in _users)
                                DropdownMenuItem<int>(
                                  value: user['id'] as int,
                                  child: Text(
                                    '${user['full_name']} (${user['username']})',
                                  ),
                                ),
                            ],
                            onChanged: canManualCreate
                                ? (value) {
                                    setState(() {
                                      _selectedUserId = value;
                                    });
                                  }
                                : null,
                            validator: (value) {
                              if (!canManualCreate) {
                                return null;
                              }
                              return value == null ? 'Select a user' : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _manualDateController,
                            decoration: const InputDecoration(
                              labelText: 'Attendance Date (YYYY-MM-DD)',
                            ),
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the attendance date'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            key: ValueKey<String>(_manualStatus),
                            initialValue: _manualStatus,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'present',
                                child: Text('Present'),
                              ),
                              DropdownMenuItem(
                                value: 'absent',
                                child: Text('Absent'),
                              ),
                              DropdownMenuItem(
                                value: 'leave',
                                child: Text('Leave'),
                              ),
                              DropdownMenuItem(
                                value: 'half_day',
                                child: Text('Half Day'),
                              ),
                            ],
                            onChanged: canManualCreate
                                ? (value) {
                                    setState(() {
                                      _manualStatus = value ?? 'present';
                                    });
                                  }
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _manualNotesController,
                            decoration: const InputDecoration(
                              labelText: 'Notes',
                            ),
                            enabled: canManualCreate,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isSubmitting || !canManualCreate
                                ? null
                                : _createManualRecord,
                            child: const Text('Create Attendance Record'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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
                  Text(
                    'Recent Attendance Records',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  if (_attendance.isEmpty)
                    const Text('No attendance records found yet.')
                  else
                    for (final record in _attendance.take(20))
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.badge_outlined),
                        title: Text(
                          'User #${record['user_id']} • ${record['status']} • ${record['attendance_date']}',
                        ),
                        subtitle: Text(
                          'Check-in ${_displayTimestamp(record['check_in_at'])} • Check-out ${_displayTimestamp(record['check_out_at'])}',
                        ),
                        trailing: record['approved_by_user_id'] != null
                            ? Chip(label: Text('Approved'))
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
