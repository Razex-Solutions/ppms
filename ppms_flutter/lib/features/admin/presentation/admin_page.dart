import 'package:flutter/material.dart';
import 'package:ppms_flutter/core/network/api_exception.dart';
import 'package:ppms_flutter/core/session/session_capabilities.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/core/widgets/responsive_split.dart';
import 'package:ppms_flutter/features/dashboard/presentation/dashboard_widgets.dart';

enum _AdminSection { users, employeeProfiles, stations, roles, modules }

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _userFullNameController = TextEditingController();
  final _userUsernameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPasswordController = TextEditingController(text: 'admin123');
  final _userSalaryController = TextEditingController(text: '0');
  final _stationNameController = TextEditingController();
  final _stationCodeController = TextEditingController();
  final _stationAddressController = TextEditingController();
  final _stationCityController = TextEditingController();
  final _roleNameController = TextEditingController();
  final _roleDescriptionController = TextEditingController();
  final _employeeFullNameController = TextEditingController();
  final _employeeCodeController = TextEditingController();
  final _employeePhoneController = TextEditingController();
  final _employeeNationalIdController = TextEditingController();
  final _employeeAddressController = TextEditingController();
  final _employeeSalaryController = TextEditingController(text: '0');
  final _employeeNotesController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _feedbackMessage;

  _AdminSection _section = _AdminSection.users;
  List<Map<String, dynamic>> _stations = const [];
  List<Map<String, dynamic>> _organizations = const [];
  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _employeeProfiles = const [];
  List<Map<String, dynamic>> _stationModules = const [];
  Map<String, dynamic>? _permissionCatalog;

  int? _selectedStationId;
  int? _selectedOrganizationId;
  int? _selectedRoleId;
  int? _selectedUserId;
  int? _selectedEmployeeProfileId;
  int? _selectedRoleEditId;
  int? _selectedStationEditId;
  bool _userPayrollEnabled = true;
  bool _employeeIsActive = true;
  bool _employeePayrollEnabled = true;
  bool _employeeCanLogin = false;
  bool _stationIsHeadOffice = false;
  String _selectedStaffType = 'attendant';

  bool _hasAction(String module, String action) {
    return _capabilities.hasPermission(module, action);
  }

  SessionCapabilities get _capabilities =>
      SessionCapabilities(widget.sessionController);

  bool get _canReadUsers =>
      _hasAction('users', 'read') || _hasAction('users', 'create');
  bool get _canManageUsers =>
      _hasAction('users', 'create') ||
      _hasAction('users', 'update') ||
      _hasAction('users', 'delete');
  bool get _canReadEmployeeProfiles =>
      _hasAction('employee_profiles', 'read') ||
      _hasAction('employee_profiles', 'create');
  bool get _canManageEmployeeProfiles =>
      _hasAction('employee_profiles', 'create') ||
      _hasAction('employee_profiles', 'update') ||
      _hasAction('employee_profiles', 'delete');
  bool get _canReadStations =>
      _hasAction('stations', 'read') || _hasAction('stations', 'create');
  bool get _canManageStations =>
      _hasAction('stations', 'create') ||
      _hasAction('stations', 'update') ||
      _hasAction('stations', 'delete');
  bool get _canReadRoles =>
      _hasAction('roles', 'read') || _hasAction('roles', 'create');
  bool get _canManageRoles =>
      _hasAction('roles', 'create') ||
      _hasAction('roles', 'update') ||
      _hasAction('roles', 'delete');
  bool get _canReadModules =>
      _hasAction('station_modules', 'read') ||
      _hasAction('station_modules', 'update');
  bool get _canManageModules => _hasAction('station_modules', 'update');

  @override
  void initState() {
    super.initState();
    _loadWorkspace();
  }

  @override
  void dispose() {
    _userFullNameController.dispose();
    _userUsernameController.dispose();
    _userEmailController.dispose();
    _userPasswordController.dispose();
    _userSalaryController.dispose();
    _stationNameController.dispose();
    _stationCodeController.dispose();
    _stationAddressController.dispose();
    _stationCityController.dispose();
    _roleNameController.dispose();
    _roleDescriptionController.dispose();
    _employeeFullNameController.dispose();
    _employeeCodeController.dispose();
    _employeePhoneController.dispose();
    _employeeNationalIdController.dispose();
    _employeeAddressController.dispose();
    _employeeSalaryController.dispose();
    _employeeNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkspace() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final shouldLoadStations =
          _canReadStations ||
          _canReadUsers ||
          _canReadEmployeeProfiles ||
          _canReadModules;
      final shouldLoadOrganizations = _canReadStations;
      final shouldLoadRoles = _canReadRoles || _canManageUsers;
      final shouldLoadPermissionCatalog = _canReadRoles || _canManageUsers;

      final stations = shouldLoadStations
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchStations()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final organizations = shouldLoadOrganizations
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchOrganizations()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final roles = shouldLoadRoles
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchRoles()).map(
                (item) => Map<String, dynamic>.from(item as Map),
              ),
            )
          : const <Map<String, dynamic>>[];
      final permissionCatalog = shouldLoadPermissionCatalog
          ? await widget.sessionController.fetchPermissionCatalog()
          : null;

      final preferredStationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final stationId =
          _selectedStationId ??
          preferredStationId ??
          (stations.isNotEmpty ? stations.first['id'] as int : null);

      final users = _canReadUsers
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchUsers(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final employeeProfiles = _canReadEmployeeProfiles
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchEmployeeProfiles(
                stationId: stationId,
                organizationId: _selectedOrganizationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final stationModules = !_canReadModules || stationId == null
          ? const <Map<String, dynamic>>[]
          : List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchStationModules(
                stationId: stationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            );

      if (!mounted) return;

      final organizationId =
          _selectedOrganizationId ??
          widget.sessionController.currentUser?['organization_id'] as int? ??
          (organizations.isNotEmpty ? organizations.first['id'] as int : null);
      final creatableRoleNames = widget.sessionController.creatableRoles;
      final creatableRoles = creatableRoleNames.isEmpty
          ? roles
          : roles
                .where(
                  (role) =>
                      creatableRoleNames.contains(role['name'] as String?),
                )
                .toList();
      final roleId =
          (_selectedRoleId != null &&
              creatableRoles.any((role) => role['id'] == _selectedRoleId))
          ? _selectedRoleId
          : (creatableRoles.isNotEmpty
                ? creatableRoles.first['id'] as int
                : null);

      setState(() {
        _stations = stations;
        _organizations = organizations;
        _roles = roles;
        _users = users;
        _employeeProfiles = employeeProfiles;
        _stationModules = stationModules;
        _permissionCatalog = permissionCatalog;
        _selectedStationId = stationId;
        _selectedOrganizationId = organizationId;
        _selectedRoleId = roleId;
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
    });
    await _loadWorkspace();
  }

  List<Map<String, dynamic>> get _creatableRoleOptions {
    final allowedNames = widget.sessionController.creatableRoles;
    if (allowedNames.isEmpty) {
      return _roles;
    }
    return _roles.where((role) => allowedNames.contains(role['name'])).toList();
  }

  Future<void> _createUser() async {
    final roleId = _selectedRoleId;
    if (roleId == null) {
      setState(() {
        _feedbackMessage = 'Select a role first.';
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
        'full_name': _userFullNameController.text.trim(),
        'username': _userUsernameController.text.trim(),
        'email': _emptyToNull(_userEmailController.text),
        'role_id': roleId,
        'station_id': _selectedStationId,
        'monthly_salary': double.parse(_userSalaryController.text.trim()),
        'payroll_enabled': _userPayrollEnabled,
      };
      final password = _userPasswordController.text.trim();
      if (password.isNotEmpty) {
        payload['password'] = password;
      }
      final isEditing = _selectedUserId != null;
      final user = isEditing
          ? await widget.sessionController.updateUser(
              userId: _selectedUserId!,
              payload: payload,
            )
          : await widget.sessionController.createUser(payload);
      if (!mounted) return;
      _resetUserForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'User ${user['username']} ${isEditing ? 'updated' : 'created'}.';
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

  Future<void> _createEmployeeProfile() async {
    final stationId = _selectedStationId;
    if (stationId == null) {
      setState(() {
        _feedbackMessage = 'Select a station first.';
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
        'station_id': stationId,
        'full_name': _employeeFullNameController.text.trim(),
        'staff_type': _selectedStaffType,
        'employee_code': _emptyToNull(_employeeCodeController.text),
        'phone': _emptyToNull(_employeePhoneController.text),
        'national_id': _emptyToNull(_employeeNationalIdController.text),
        'address': _emptyToNull(_employeeAddressController.text),
        'is_active': _employeeIsActive,
        'payroll_enabled': _employeePayrollEnabled,
        'monthly_salary': double.parse(_employeeSalaryController.text.trim()),
        'can_login': _employeeCanLogin,
        'notes': _emptyToNull(_employeeNotesController.text),
      };
      final isEditing = _selectedEmployeeProfileId != null;
      final profile = isEditing
          ? await widget.sessionController.updateEmployeeProfile(
              profileId: _selectedEmployeeProfileId!,
              payload: payload,
            )
          : await widget.sessionController.createEmployeeProfile(payload);
      if (!mounted) return;
      _resetEmployeeProfileForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Employee profile ${profile['full_name']} ${isEditing ? 'updated' : 'created'}.';
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

  Future<void> _createStation() async {
    final organizationId = _selectedOrganizationId;
    if (organizationId == null) {
      setState(() {
        _feedbackMessage = 'Select an organization first.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final isEditing = _selectedStationEditId != null;
      final station = isEditing
          ? await widget.sessionController.updateStation(
              stationId: _selectedStationEditId!,
              payload: {
                'name': _stationNameController.text.trim(),
                'code': _stationCodeController.text.trim(),
                'address': _emptyToNull(_stationAddressController.text),
                'city': _emptyToNull(_stationCityController.text),
                'organization_id': organizationId,
                'is_head_office': _stationIsHeadOffice,
              },
            )
          : await widget.sessionController.createStation({
              'name': _stationNameController.text.trim(),
              'code': _stationCodeController.text.trim(),
              'address': _emptyToNull(_stationAddressController.text),
              'city': _emptyToNull(_stationCityController.text),
              'organization_id': organizationId,
              'is_head_office': _stationIsHeadOffice,
            });
      if (!mounted) return;
      _resetStationForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Station ${station['name']} ${isEditing ? 'updated' : 'created'}.';
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

  Future<void> _createRole() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      final isEditing = _selectedRoleEditId != null;
      final role = isEditing
          ? await widget.sessionController.updateRole(
              roleId: _selectedRoleEditId!,
              payload: {
                'name': _roleNameController.text.trim(),
                'description': _emptyToNull(_roleDescriptionController.text),
              },
            )
          : await widget.sessionController.createRole({
              'name': _roleNameController.text.trim(),
              'description': _emptyToNull(_roleDescriptionController.text),
            });
      if (!mounted) return;
      _resetRoleForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Role ${role['name']} ${isEditing ? 'updated' : 'created'}.';
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

  Future<void> _deleteUser() async {
    final userId = _selectedUserId;
    if (userId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete User',
      message: 'Delete this user account? This cannot be undone.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteUser(
        userId: userId,
      );
      if (!mounted) return;
      _resetUserForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'User deleted successfully.';
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

  Future<void> _deleteEmployeeProfile() async {
    final profileId = _selectedEmployeeProfileId;
    if (profileId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Employee Profile',
      message:
          'Delete this staff profile only if it is not needed for payroll or operational assignment anymore.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteEmployeeProfile(
        profileId: profileId,
      );
      if (!mounted) return;
      _resetEmployeeProfileForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ??
            'Employee profile deleted successfully.';
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

  Future<void> _deleteStation() async {
    final stationId = _selectedStationEditId;
    if (stationId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Station',
      message:
          'Delete this station only if it has no users or dependent operational records.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteStation(
        stationId: stationId,
      );
      if (!mounted) return;
      _resetStationForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Station deleted successfully.';
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

  Future<void> _deleteRole() async {
    final roleId = _selectedRoleEditId;
    if (roleId == null) return;
    final confirmed = await _confirmDelete(
      title: 'Delete Role',
      message:
          'Delete this role only if it is not a protected core role and no users are assigned to it.',
    );
    if (!confirmed) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });
    try {
      final response = await widget.sessionController.deleteRole(
        roleId: roleId,
      );
      if (!mounted) return;
      _resetRoleForm();
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            response['message'] as String? ?? 'Role deleted successfully.';
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

  void _selectUser(Map<String, dynamic> user) {
    setState(() {
      _selectedUserId = user['id'] as int;
      _userFullNameController.text = user['full_name'] as String? ?? '';
      _userUsernameController.text = user['username'] as String? ?? '';
      _userEmailController.text = user['email'] as String? ?? '';
      _userPasswordController.clear();
      _userSalaryController.text = ((user['monthly_salary'] as num?) ?? 0)
          .toString();
      _selectedRoleId = user['role_id'] as int?;
      _userPayrollEnabled = user['payroll_enabled'] as bool? ?? true;
      _feedbackMessage = 'Editing user ${user['username']}.';
      _errorMessage = null;
    });
  }

  void _selectStation(Map<String, dynamic> station) {
    setState(() {
      _selectedStationEditId = station['id'] as int;
      _selectedOrganizationId = station['organization_id'] as int?;
      _stationNameController.text = station['name'] as String? ?? '';
      _stationCodeController.text = station['code'] as String? ?? '';
      _stationAddressController.text = station['address'] as String? ?? '';
      _stationCityController.text = station['city'] as String? ?? '';
      _stationIsHeadOffice = station['is_head_office'] as bool? ?? false;
      _feedbackMessage = 'Editing station ${station['name']}.';
      _errorMessage = null;
    });
  }

  void _selectEmployeeProfile(Map<String, dynamic> profile) {
    setState(() {
      _selectedEmployeeProfileId = profile['id'] as int;
      _employeeFullNameController.text = profile['full_name'] as String? ?? '';
      _employeeCodeController.text = profile['employee_code'] as String? ?? '';
      _employeePhoneController.text = profile['phone'] as String? ?? '';
      _employeeNationalIdController.text =
          profile['national_id'] as String? ?? '';
      _employeeAddressController.text = profile['address'] as String? ?? '';
      _employeeSalaryController.text =
          ((profile['monthly_salary'] as num?) ?? 0).toString();
      _employeeNotesController.text = profile['notes'] as String? ?? '';
      _selectedStaffType = profile['staff_type'] as String? ?? 'attendant';
      _employeeIsActive = profile['is_active'] as bool? ?? true;
      _employeePayrollEnabled = profile['payroll_enabled'] as bool? ?? true;
      _employeeCanLogin = profile['can_login'] as bool? ?? false;
      _feedbackMessage = 'Editing employee profile ${profile['full_name']}.';
      _errorMessage = null;
    });
  }

  void _selectRole(Map<String, dynamic> role) {
    setState(() {
      _selectedRoleEditId = role['id'] as int;
      _roleNameController.text = role['name'] as String? ?? '';
      _roleDescriptionController.text = role['description'] as String? ?? '';
      _feedbackMessage = 'Editing role ${role['name']}.';
      _errorMessage = null;
    });
  }

  void _resetUserForm() {
    _selectedUserId = null;
    _userFullNameController.clear();
    _userUsernameController.clear();
    _userEmailController.clear();
    _userPasswordController.text = 'admin123';
    _userSalaryController.text = '0';
    _userPayrollEnabled = true;
  }

  void _resetStationForm() {
    _selectedStationEditId = null;
    _stationNameController.clear();
    _stationCodeController.clear();
    _stationAddressController.clear();
    _stationCityController.clear();
    _stationIsHeadOffice = false;
  }

  void _resetRoleForm() {
    _selectedRoleEditId = null;
    _roleNameController.clear();
    _roleDescriptionController.clear();
  }

  void _resetEmployeeProfileForm() {
    _selectedEmployeeProfileId = null;
    _employeeFullNameController.clear();
    _employeeCodeController.clear();
    _employeePhoneController.clear();
    _employeeNationalIdController.clear();
    _employeeAddressController.clear();
    _employeeSalaryController.text = '0';
    _employeeNotesController.clear();
    _selectedStaffType = 'attendant';
    _employeeIsActive = true;
    _employeePayrollEnabled = true;
    _employeeCanLogin = false;
  }

  Future<void> _toggleStationModule(String moduleName, bool isEnabled) async {
    final stationId = _selectedStationId;
    if (stationId == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      await widget.sessionController.updateStationModule(
        stationId: stationId,
        payload: {'module_name': moduleName, 'is_enabled': isEnabled},
      );
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Module $moduleName ${isEnabled ? 'enabled' : 'disabled'}.';
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

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;

    final availableSections = <_AdminSection>[
      if (_canReadUsers) _AdminSection.users,
      if (_canReadEmployeeProfiles) _AdminSection.employeeProfiles,
      if (_canReadStations) _AdminSection.stations,
      if (_canReadRoles) _AdminSection.roles,
      if (_canReadModules) _AdminSection.modules,
    ];
    if (availableSections.isNotEmpty && !availableSections.contains(_section)) {
      _section = availableSections.first;
    }

    final sectionMeta = _sectionMeta(_section);

    return RefreshIndicator(
      onRefresh: _loadWorkspace,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DashboardHeroCard(
            eyebrow: 'Admin Workspace',
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
                    'Active section',
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
                if (_canReadUsers)
                  DashboardMetricTile(
                    label: 'Users',
                    value: _users.length.toString(),
                    caption: 'Accounts visible in the current scope',
                    icon: Icons.group_outlined,
                    tint: colorScheme.primary,
                  ),
                if (_canReadEmployeeProfiles)
                  DashboardMetricTile(
                    label: 'Staff profiles',
                    value: _employeeProfiles.length.toString(),
                    caption: 'Profile-only or login-linked staff records',
                    icon: Icons.badge_outlined,
                    tint: colorScheme.secondary,
                  ),
                if (_canReadStations)
                  DashboardMetricTile(
                    label: 'Stations',
                    value: _stations.length.toString(),
                    caption: 'Stations available to this admin scope',
                    icon: Icons.store_outlined,
                    tint: colorScheme.tertiary,
                  ),
                if (_canReadRoles)
                  DashboardMetricTile(
                    label: 'Roles',
                    value: _roles.length.toString(),
                    caption: 'Visible role definitions in the workspace',
                    icon: Icons.admin_panel_settings_outlined,
                    tint: colorScheme.error,
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stationField = DropdownButtonFormField<int>(
                        key: ValueKey<String>(
                          'admin-station-${_selectedStationId ?? 'none'}',
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
                      final sections = SegmentedButton<_AdminSection>(
                        segments: [
                          if (_canReadUsers)
                            const ButtonSegment(
                              value: _AdminSection.users,
                              label: Text('Users'),
                              icon: Icon(Icons.group_outlined),
                            ),
                          if (_canReadEmployeeProfiles)
                            const ButtonSegment(
                              value: _AdminSection.employeeProfiles,
                              label: Text('Staff'),
                              icon: Icon(Icons.badge_outlined),
                            ),
                          if (_canReadStations)
                            const ButtonSegment(
                              value: _AdminSection.stations,
                              label: Text('Stations'),
                              icon: Icon(Icons.store_outlined),
                            ),
                          if (_canReadRoles)
                            const ButtonSegment(
                              value: _AdminSection.roles,
                              label: Text('Roles'),
                              icon: Icon(Icons.admin_panel_settings_outlined),
                            ),
                          if (_canReadModules)
                            const ButtonSegment(
                              value: _AdminSection.modules,
                              label: Text('Modules'),
                              icon: Icon(Icons.toggle_on_outlined),
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
                      if (constraints.maxWidth < 950) {
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
                          Expanded(child: sections),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildSection(context),
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

  Widget _buildSection(BuildContext context) {
    switch (_section) {
      case _AdminSection.users:
        return _buildUsersSection(context);
      case _AdminSection.employeeProfiles:
        return _buildEmployeeProfilesSection(context);
      case _AdminSection.stations:
        return _buildStationsSection(context);
      case _AdminSection.roles:
        return _buildRolesSection(context);
      case _AdminSection.modules:
        return _buildModulesSection(context);
    }
  }

  Widget _buildUsersSection(BuildContext context) {
    final creatableRoles = [..._creatableRoleOptions];
    if (_selectedRoleId != null &&
        !creatableRoles.any((role) => role['id'] == _selectedRoleId)) {
      final currentRole = _roles.cast<Map<String, dynamic>?>().firstWhere(
        (role) => role?['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (currentRole != null) {
        creatableRoles.add(currentRole);
      }
    }
    final selectedUser = _users.cast<Map<String, dynamic>?>().firstWhere(
      (user) => user?['id'] == _selectedUserId,
      orElse: () => null,
    );
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_canManageUsers) ...[
            _buildReadOnlyNotice(
              'This role can review user records but cannot create, update, or delete users.',
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _selectedUserId == null ? 'Create User' : 'Edit User',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userFullNameController,
            enabled: _canManageUsers,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userUsernameController,
            enabled: _canManageUsers,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userEmailController,
            enabled: _canManageUsers,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userPasswordController,
            enabled: _canManageUsers,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('admin-role-${_selectedRoleId ?? 'none'}'),
            initialValue: _selectedRoleId,
            decoration: const InputDecoration(
              labelText: 'Role',
              helperText: 'Only roles allowed by your current scope are shown.',
            ),
            items: [
              for (final role in creatableRoles)
                DropdownMenuItem<int>(
                  value: role['id'] as int,
                  child: Text(role['name'] as String? ?? 'Role'),
                ),
            ],
            onChanged: _canManageUsers
                ? (value) {
                    setState(() {
                      _selectedRoleId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userSalaryController,
            enabled: _canManageUsers,
            decoration: const InputDecoration(labelText: 'Monthly Salary'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _userPayrollEnabled,
            title: const Text('Payroll Enabled'),
            onChanged: _canManageUsers
                ? (value) {
                    setState(() {
                      _userPayrollEnabled = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (_canManageUsers)
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createUser,
              icon: Icon(
                _selectedUserId == null
                    ? Icons.person_add_alt_1_outlined
                    : Icons.save_outlined,
              ),
              label: Text(
                _selectedUserId == null ? 'Create User' : 'Save User',
              ),
            ),
          if (_selectedUserId != null && _canManageUsers) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _resetUserForm();
                            _feedbackMessage = 'User edit cancelled.';
                          });
                        },
                  child: const Text('Cancel Edit'),
                ),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _deleteUser,
                  child: const Text('Delete User'),
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
              Text('Users', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_users.isEmpty)
                const Text('No users found for this scope.')
              else
                for (final user in _users)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${user['username']} - ${user['full_name']}'),
                    subtitle: Text(
                      'role ${user['role_id']} - salary ${_formatNumber(user['monthly_salary'])}',
                    ),
                    onTap: () => _selectUser(user),
                  ),
              if (selectedUser != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected User Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Full Name',
                    selectedUser['full_name'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Username',
                    selectedUser['username'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Email',
                    selectedUser['email'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Role',
                    _lookupName(_roles, selectedUser['role_id']),
                  ),
                  _buildDetailItem(
                    'Station',
                    _lookupName(_stations, selectedUser['station_id']),
                  ),
                  _buildDetailItem(
                    'Payroll',
                    selectedUser['payroll_enabled'] == true
                        ? 'enabled'
                        : 'disabled',
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationsSection(BuildContext context) {
    final selectedStation = _stations.cast<Map<String, dynamic>?>().firstWhere(
      (station) => station?['id'] == _selectedStationEditId,
      orElse: () => null,
    );
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_canManageStations) ...[
            _buildReadOnlyNotice(
              'This role can review station records but cannot create, update, or delete stations.',
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _selectedStationEditId == null ? 'Create Station' : 'Edit Station',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>(
              'admin-organization-${_selectedOrganizationId ?? 'none'}',
            ),
            initialValue: _selectedOrganizationId,
            decoration: const InputDecoration(labelText: 'Organization'),
            items: [
              for (final organization in _organizations)
                DropdownMenuItem<int>(
                  value: organization['id'] as int,
                  child: Text(
                    '${organization['name']} (${organization['code']})',
                  ),
                ),
            ],
            onChanged: _canManageStations
                ? (value) {
                    setState(() {
                      _selectedOrganizationId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stationNameController,
            enabled: _canManageStations,
            decoration: const InputDecoration(labelText: 'Station Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stationCodeController,
            enabled: _canManageStations,
            decoration: const InputDecoration(labelText: 'Station Code'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stationAddressController,
            enabled: _canManageStations,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _stationCityController,
            enabled: _canManageStations,
            decoration: const InputDecoration(labelText: 'City'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _stationIsHeadOffice,
            title: const Text('Head Office Station'),
            onChanged: _canManageStations
                ? (value) {
                    setState(() {
                      _stationIsHeadOffice = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (_canManageStations)
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createStation,
              icon: Icon(
                _selectedStationEditId == null
                    ? Icons.add_business_outlined
                    : Icons.save_outlined,
              ),
              label: Text(
                _selectedStationEditId == null
                    ? 'Create Station'
                    : 'Save Station',
              ),
            ),
          if (_selectedStationEditId != null && _canManageStations) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _resetStationForm();
                            _feedbackMessage = 'Station edit cancelled.';
                          });
                        },
                  child: const Text('Cancel Edit'),
                ),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _deleteStation,
                  child: const Text('Delete Station'),
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
              Text('Stations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_stations.isEmpty)
                const Text('No stations found.')
              else
                for (final station in _stations)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${station['name']} (${station['code']})'),
                    subtitle: Text(
                      '${station['city'] ?? '-'} - org ${station['organization_id']}'
                      '${station['is_head_office'] == true ? ' - head office' : ''}',
                    ),
                    onTap: () => _selectStation(station),
                  ),
              if (selectedStation != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Station Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Code',
                    selectedStation['code'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Organization',
                    _lookupName(
                      _organizations,
                      selectedStation['organization_id'],
                    ),
                  ),
                  _buildDetailItem(
                    'City',
                    selectedStation['city'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Address',
                    selectedStation['address'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Head Office',
                    selectedStation['is_head_office'] == true ? 'yes' : 'no',
                  ),
                  _buildDetailItem(
                    'Users',
                    _users
                        .where(
                          (user) => user['station_id'] == selectedStation['id'],
                        )
                        .length
                        .toString(),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeProfilesSection(BuildContext context) {
    const staffTypes = [
      'attendant',
      'tanker_driver',
      'manager',
      'cashier',
      'mechanic',
      'helper',
      'security',
      'other',
    ];
    final selectedProfile = _employeeProfiles
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (profile) => profile?['id'] == _selectedEmployeeProfileId,
          orElse: () => null,
        );
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_canManageEmployeeProfiles) ...[
            _buildReadOnlyNotice(
              'This role can review staff profiles but cannot create, update, or delete them.',
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _selectedEmployeeProfileId == null
                ? 'Create Staff Profile'
                : 'Edit Staff Profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeFullNameController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>('staff-type-$_selectedStaffType'),
            initialValue: _selectedStaffType,
            decoration: const InputDecoration(labelText: 'Staff Type'),
            items: [
              for (final staffType in staffTypes)
                DropdownMenuItem<String>(
                  value: staffType,
                  child: Text(staffType.replaceAll('_', ' ')),
                ),
            ],
            onChanged: _canManageEmployeeProfiles
                ? (value) {
                    setState(() {
                      _selectedStaffType = value ?? 'attendant';
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeCodeController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Employee Code'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeePhoneController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeNationalIdController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'National ID'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeAddressController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeSalaryController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Monthly Salary'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _employeeNotesController,
            enabled: _canManageEmployeeProfiles,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _employeeIsActive,
            title: const Text('Active'),
            onChanged: _canManageEmployeeProfiles
                ? (value) {
                    setState(() {
                      _employeeIsActive = value;
                    });
                  }
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _employeePayrollEnabled,
            title: const Text('Payroll Enabled'),
            onChanged: _canManageEmployeeProfiles
                ? (value) {
                    setState(() {
                      _employeePayrollEnabled = value;
                    });
                  }
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _employeeCanLogin,
            title: const Text('Can Login'),
            subtitle: const Text(
              'Keep this off for profile-only staff unless a linked login user will exist.',
            ),
            onChanged: _canManageEmployeeProfiles
                ? (value) {
                    setState(() {
                      _employeeCanLogin = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (_canManageEmployeeProfiles)
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createEmployeeProfile,
              icon: Icon(
                _selectedEmployeeProfileId == null
                    ? Icons.person_add_alt_1_outlined
                    : Icons.save_outlined,
              ),
              label: Text(
                _selectedEmployeeProfileId == null
                    ? 'Create Staff Profile'
                    : 'Save Staff Profile',
              ),
            ),
          if (_selectedEmployeeProfileId != null &&
              _canManageEmployeeProfiles) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _resetEmployeeProfileForm();
                            _feedbackMessage = 'Staff profile edit cancelled.';
                          });
                        },
                  child: const Text('Cancel Edit'),
                ),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _deleteEmployeeProfile,
                  child: const Text('Delete Staff Profile'),
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
              Text(
                'Staff Profiles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (_employeeProfiles.isEmpty)
                const Text('No staff profiles found for this scope.')
              else
                for (final profile in _employeeProfiles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(profile['full_name'] as String? ?? 'Staff'),
                    subtitle: Text(
                      '${profile['staff_type'] ?? '-'} • ${profile['employee_code'] ?? 'no code'}',
                    ),
                    trailing: Text(
                      profile['can_login'] == true ? 'login' : 'profile-only',
                    ),
                    onTap: () => _selectEmployeeProfile(profile),
                  ),
              if (selectedProfile != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Staff Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Name',
                    selectedProfile['full_name'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Type',
                    selectedProfile['staff_type'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Code',
                    selectedProfile['employee_code'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Phone',
                    selectedProfile['phone'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Payroll',
                    selectedProfile['payroll_enabled'] == true
                        ? 'enabled'
                        : 'disabled',
                  ),
                  _buildDetailItem(
                    'Access',
                    selectedProfile['can_login'] == true
                        ? 'login-enabled'
                        : 'profile-only',
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRolesSection(BuildContext context) {
    final roleSummaries = Map<String, dynamic>.from(
      _permissionCatalog?['role_summaries'] as Map? ?? const {},
    );
    final selectedRole = _roles.cast<Map<String, dynamic>?>().firstWhere(
      (role) => role?['id'] == _selectedRoleEditId,
      orElse: () => null,
    );
    return ResponsiveSplit(
      breakpoint: 1150,
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_canManageRoles) ...[
            _buildReadOnlyNotice(
              'This role can review the role catalog but cannot create, update, or delete roles.',
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _selectedRoleEditId == null ? 'Create Role' : 'Edit Role',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _roleNameController,
            enabled: _canManageRoles,
            decoration: const InputDecoration(labelText: 'Role Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _roleDescriptionController,
            enabled: _canManageRoles,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          if (_canManageRoles)
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createRole,
              icon: Icon(
                _selectedRoleEditId == null
                    ? Icons.shield_outlined
                    : Icons.save_outlined,
              ),
              label: Text(
                _selectedRoleEditId == null ? 'Create Role' : 'Save Role',
              ),
            ),
          if (_selectedRoleEditId != null && _canManageRoles) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _resetRoleForm();
                            _feedbackMessage = 'Role edit cancelled.';
                          });
                        },
                  child: const Text('Cancel Edit'),
                ),
                OutlinedButton(
                  onPressed: _isSubmitting ? null : _deleteRole,
                  child: const Text('Delete Role'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('Core Roles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final roleName in List<String>.from(
            _permissionCatalog?['core_roles'] ?? const [],
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(roleName),
              subtitle: Text(
                (roleSummaries[roleName] as Map?)?.values.join(' • ') ?? '-',
              ),
            ),
        ],
      ),
      secondary: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roles', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (_roles.isEmpty)
                const Text('No roles found.')
              else
                for (final role in _roles)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(role['name'] as String? ?? 'Role'),
                    subtitle: Text(role['description'] as String? ?? '-'),
                    onTap: () => _selectRole(role),
                  ),
              if (selectedRole != null) ...[
                const Divider(height: 24),
                Text(
                  'Selected Role Details',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildDetailWrap([
                  _buildDetailItem(
                    'Role',
                    selectedRole['name'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Protected',
                    List<String>.from(
                          _permissionCatalog?['core_roles'] ?? const [],
                        ).contains(selectedRole['name'])
                        ? 'yes'
                        : 'no',
                  ),
                  _buildDetailItem(
                    'Assigned Users',
                    _users
                        .where((user) => user['role_id'] == selectedRole['id'])
                        .length
                        .toString(),
                  ),
                  _buildDetailItem(
                    'Summary',
                    (roleSummaries[selectedRole['name']] as Map?)?.values
                            .take(2)
                            .join(' • ') ??
                        'custom role',
                  ),
                ]),
                if ((selectedRole['description'] as String?)?.isNotEmpty ==
                    true) ...[
                  const SizedBox(height: 8),
                  Text('Description: ${selectedRole['description']}'),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModulesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Station Modules',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!_canManageModules) ...[
              _buildReadOnlyNotice(
                'This role can review module state but cannot change module toggles.',
              ),
              const SizedBox(height: 12),
            ],
            if (_selectedStationId == null)
              const Text('Select a station to manage modules.')
            else if (_stationModules.isEmpty)
              const Text('No module settings found for this station yet.')
            else
              for (final module in _stationModules)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: module['is_enabled'] as bool? ?? false,
                  title: Text(module['module_name'] as String? ?? 'Module'),
                  subtitle: Text('Station ${module['station_id']}'),
                  onChanged: !_canManageModules || _isSubmitting
                      ? null
                      : (value) => _toggleStationModule(
                          module['module_name'] as String,
                          value,
                        ),
                ),
          ],
        ),
      ),
    );
  }

  (String, String, IconData) _sectionMeta(_AdminSection section) {
    switch (section) {
      case _AdminSection.users:
        return (
          'User access control',
          'Create and review login users based on hierarchy, station scope, and allowed roles.',
          Icons.group_outlined,
        );
      case _AdminSection.employeeProfiles:
        return (
          'Staff profile control',
          'Manage profile-only staff records, payroll state, and operational personnel details without forcing logins.',
          Icons.badge_outlined,
        );
      case _AdminSection.stations:
        return (
          'Station management',
          'Review and maintain station definitions, ownership, and structural placement inside the organization.',
          Icons.store_outlined,
        );
      case _AdminSection.roles:
        return (
          'Role governance',
          'Inspect role definitions, protected core roles, and visibility rules for controlled delegation.',
          Icons.admin_panel_settings_outlined,
        );
      case _AdminSection.modules:
        return (
          'Module switches',
          'Turn station services on or off so users only see what the business actually uses.',
          Icons.toggle_on_outlined,
        );
    }
  }

  String _formatNumber(dynamic value) {
    if (value is num) return value.toStringAsFixed(2);
    return '0.00';
  }

  String _lookupName(List<Map<String, dynamic>> items, dynamic id) {
    final match = items.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == id,
      orElse: () => null,
    );
    return match?['name'] as String? ??
        match?['code'] as String? ??
        (id?.toString() ?? '-');
  }

  Widget _buildDetailWrap(List<Widget> children) {
    return Wrap(spacing: 12, runSpacing: 12, children: children);
  }

  Widget _buildReadOnlyNotice(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
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
}
