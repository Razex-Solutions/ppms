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
  List<Map<String, dynamic>> _organizationModules = const [];
  List<Map<String, dynamic>> _stationModules = const [];
  List<Map<String, dynamic>> _subscriptionPlans = const [];
  Map<String, dynamic>? _organizationSubscription;
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

  bool _sameId(dynamic left, dynamic right) =>
      left != null && right != null && left.toString() == right.toString();

  int? _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

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
      _hasAction('organization_modules', 'read') ||
      _hasAction('organization_modules', 'update') ||
      _hasAction('station_modules', 'read') ||
      _hasAction('station_modules', 'update') ||
      _hasAction('saas', 'read') ||
      _hasAction('saas', 'manage');
  bool get _canReadOrganizationModules =>
      _hasAction('organization_modules', 'read') ||
      _hasAction('organization_modules', 'update');
  bool get _canManageOrganizationModules =>
      _hasAction('organization_modules', 'update');
  bool get _canReadStationModules =>
      _hasAction('station_modules', 'read') ||
      _hasAction('station_modules', 'update');
  bool get _canManageStationModules => _hasAction('station_modules', 'update');
  bool get _canReadSubscription =>
      _hasAction('saas', 'read') || _hasAction('saas', 'manage');
  bool get _canManageSubscription => _hasAction('saas', 'manage');

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
      final shouldLoadOrganizations =
          _canReadStations ||
          _canReadUsers ||
          _canReadEmployeeProfiles ||
          _canReadModules;
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

      final preferredOrganizationId =
          _selectedOrganizationId ??
          widget.sessionController.currentUser?['organization_id'] as int?;
      final preferredStationId =
          widget.sessionController.currentUser?['station_id'] as int?;
      final organizationId =
          preferredOrganizationId ??
          (organizations.isNotEmpty ? organizations.first['id'] as int : null);
      final scopedStations = organizationId == null
          ? stations
          : stations
                .where(
                  (station) =>
                      _sameId(station['organization_id'], organizationId),
                )
                .toList();
      final stationId =
          (_selectedStationId != null &&
              scopedStations.any(
                (station) => _sameId(station['id'], _selectedStationId),
              ))
          ? _selectedStationId
          : (preferredStationId != null &&
                scopedStations.any(
                  (station) => _sameId(station['id'], preferredStationId),
                ))
          ? preferredStationId
          : (scopedStations.isNotEmpty
                ? _asInt(scopedStations.first['id'])
                : null);

      final userListStationId = widget.sessionController.scopeLevel == 'station'
          ? stationId
          : null;
      final users = _canReadUsers
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchUsers(
                stationId: userListStationId,
                organizationId: organizationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      final employeeProfiles = _canReadEmployeeProfiles
          ? List<Map<String, dynamic>>.from(
              (await widget.sessionController.fetchEmployeeProfiles(
                stationId: stationId,
                organizationId: organizationId,
              )).map((item) => Map<String, dynamic>.from(item as Map)),
            )
          : const <Map<String, dynamic>>[];
      List<Map<String, dynamic>> organizationModules = const [];
      if (_canReadOrganizationModules && organizationId != null) {
        try {
          organizationModules = List<Map<String, dynamic>>.from(
            (await widget.sessionController.fetchOrganizationModules(
              organizationId: organizationId,
            )).map((item) => Map<String, dynamic>.from(item as Map)),
          );
        } on ApiException {
          organizationModules = const [];
        }
      }

      List<Map<String, dynamic>> stationModules = const [];
      if (_canReadStationModules &&
          stationId != null &&
          widget.sessionController.scopeLevel == 'station') {
        try {
          stationModules = List<Map<String, dynamic>>.from(
            (await widget.sessionController.fetchStationModules(
              stationId: stationId,
            )).map((item) => Map<String, dynamic>.from(item as Map)),
          );
        } on ApiException {
          stationModules = const [];
        }
      }

      List<Map<String, dynamic>> subscriptionPlans = const [];
      if (_canManageSubscription) {
        try {
          subscriptionPlans = List<Map<String, dynamic>>.from(
            (await widget.sessionController.fetchSubscriptionPlans()).map(
              (item) => Map<String, dynamic>.from(item as Map),
            ),
          );
        } on ApiException {
          subscriptionPlans = const [];
        }
      }

      Map<String, dynamic>? organizationSubscription;
      if (_canReadSubscription && organizationId != null) {
        try {
          organizationSubscription = await widget.sessionController
              .fetchOrganizationSubscription(organizationId: organizationId);
        } on ApiException {
          organizationSubscription = null;
        }
      }

      if (!mounted) return;

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
          : _preferredWorkerRoleId(creatableRoles);

      setState(() {
        _stations = stations;
        _organizations = organizations;
        _roles = roles;
        _users = users;
        _employeeProfiles = employeeProfiles;
        _organizationModules = organizationModules;
        _stationModules = stationModules;
        _subscriptionPlans = subscriptionPlans;
        _organizationSubscription = organizationSubscription;
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

  Future<void> _changeOrganization(int? organizationId) async {
    if (organizationId == null) return;
    setState(() {
      _selectedOrganizationId = organizationId;
      _selectedStationId = null;
    });
    await _loadWorkspace();
  }

  List<Map<String, dynamic>> get _creatableRoleOptions {
    final allowedNames = widget.sessionController.creatableRoles;
    final allowedRoles = allowedNames.isEmpty
        ? _roles
        : _roles.where((role) => allowedNames.contains(role['name'])).toList();
    final selectedOrganizationId =
        _selectedOrganizationId ?? widget.sessionController.organizationId;
    final stationCount = selectedOrganizationId == null
        ? _stations.length
        : _stations
              .where(
                (station) =>
                    _sameId(station['organization_id'], selectedOrganizationId),
              )
              .length;
    if (stationCount <= 1) {
      return allowedRoles
          .where((role) => role['name'] != 'StationAdmin')
          .toList();
    }
    return allowedRoles;
  }

  int? _preferredWorkerRoleId([List<Map<String, dynamic>>? roleOptions]) {
    final options = roleOptions ?? _creatableRoleOptions;
    const preferredNames = [
      'Manager',
      'StationAdmin',
      'Accountant',
      'Operator',
    ];
    for (final preferredName in preferredNames) {
      for (final role in options) {
        if (role['name'] == preferredName) {
          return _asInt(role['id']);
        }
      }
    }
    return options.isNotEmpty ? _asInt(options.first['id']) : null;
  }

  int? get _defaultStationId {
    if (_selectedStationId != null) return _selectedStationId;
    final organizationId =
        _selectedOrganizationId ?? widget.sessionController.organizationId;
    final scopedStations = organizationId == null
        ? _stations
        : _stations
              .where(
                (station) =>
                    _sameId(station['organization_id'], organizationId),
              )
              .toList();
    final sessionStationId = widget.sessionController.stationId;
    if (sessionStationId != null &&
        scopedStations.any(
          (station) => _sameId(station['id'], sessionStationId),
        )) {
      return sessionStationId;
    }
    if (scopedStations.length == 1) {
      return _asInt(scopedStations.first['id']);
    }
    return null;
  }

  bool _roleRequiresStation(int? roleId) {
    final role = _roles.cast<Map<String, dynamic>?>().firstWhere(
      (item) => _sameId(item?['id'], roleId),
      orElse: () => null,
    );
    final roleName = role?['name'] as String?;
    if (roleName == null) return true;
    final rules = _permissionCatalog?['role_scope_rules'] as Map?;
    final rule = rules?[roleName] as Map?;
    return rule?['requires_station'] as bool? ?? true;
  }

  Future<void> _createUser() async {
    final roleId = _selectedRoleId;
    if (roleId == null) {
      setState(() {
        _feedbackMessage = 'Select a role first.';
      });
      return;
    }
    final isEditing = _selectedUserId != null;
    final roleNeedsStation = _roleRequiresStation(roleId);
    final stationId = roleNeedsStation ? _defaultStationId : null;
    final organizationId =
        _selectedOrganizationId ?? widget.sessionController.organizationId;
    if (organizationId == null) {
      setState(() {
        _feedbackMessage = 'Organization scope is not loaded yet.';
      });
      return;
    }
    if (roleNeedsStation && stationId == null) {
      setState(() {
        _feedbackMessage =
            'A station is required for this worker role. Reload Admin or create/select the tenant station first.';
      });
      return;
    }
    if (_userFullNameController.text.trim().isEmpty ||
        _userUsernameController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Enter the worker full name and username first.';
      });
      return;
    }
    if (!isEditing && _userPasswordController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Enter a password for the new worker login.';
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
        'organization_id': organizationId,
        'station_id': stationId,
        'scope_level': roleNeedsStation ? 'station' : 'organization',
        'monthly_salary': double.parse(_userSalaryController.text.trim()),
        'payroll_enabled': _userPayrollEnabled,
      };
      final password = _userPasswordController.text.trim();
      if (password.isNotEmpty) {
        payload['password'] = password;
      }
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
    if (_sameId(user['id'], widget.sessionController.currentUser?['id'])) {
      setState(() {
        _resetUserForm();
        _feedbackMessage =
            'The HeadOffice owner account is read-only here. Use the form to create a new Manager, Accountant, or Operator login.';
        _errorMessage = null;
      });
      return;
    }
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

  void _startNewWorker() {
    final creatableRoles = _creatableRoleOptions;
    setState(() {
      _resetUserForm();
      if (creatableRoles.isNotEmpty) {
        _selectedRoleId = _preferredWorkerRoleId(creatableRoles);
      }
      _feedbackMessage = 'Ready to create a new tenant worker login.';
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
    _selectedRoleId = _preferredWorkerRoleId();
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

  Future<void> _toggleOrganizationModule(
    String moduleName,
    bool isEnabled,
  ) async {
    final organizationId = _selectedOrganizationId;
    if (organizationId == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      await widget.sessionController.updateOrganizationModule(
        organizationId: organizationId,
        payload: {'module_name': moduleName, 'is_enabled': isEnabled},
      );
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage =
            'Organization module $moduleName ${isEnabled ? 'enabled' : 'disabled'}.';
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

  Future<void> _saveSubscription({
    required int? planId,
    required String status,
    required String billingCycle,
    required bool autoRenew,
  }) async {
    final organizationId = _selectedOrganizationId;
    if (organizationId == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _feedbackMessage = null;
    });

    try {
      await widget.sessionController.updateOrganizationSubscription(
        organizationId: organizationId,
        payload: {
          'plan_id': planId,
          'status': status,
          'billing_cycle': billingCycle,
          'auto_renew': autoRenew,
          'price_override': _organizationSubscription?['price_override'],
          'notes': _organizationSubscription?['notes'],
          'start_date': _organizationSubscription?['start_date'],
          'end_date': _organizationSubscription?['end_date'],
          'trial_ends_at': _organizationSubscription?['trial_ends_at'],
        },
      );
      if (!mounted) return;
      await _loadWorkspace();
      if (!mounted) return;
      setState(() {
        _feedbackMessage = 'Subscription settings updated.';
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

  Map<String, dynamic>? get _selectedOrganization {
    for (final organization in _organizations) {
      if (_sameId(organization['id'], _selectedOrganizationId)) {
        return organization;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedStation {
    for (final station in _stations) {
      if (_sameId(station['id'], _selectedStationId)) {
        return station;
      }
    }
    return null;
  }

  String get _scopeOrganizationLabel {
    final organization = _selectedOrganization;
    if (organization != null) {
      return '${organization['name']} (${organization['code']})';
    }
    final organizationId =
        _selectedOrganizationId ?? widget.sessionController.organizationId;
    return organizationId == null
        ? 'No organization selected'
        : 'Org $organizationId (session scope)';
  }

  String get _scopeStationLabel {
    final station = _selectedStation;
    if (station != null) {
      return '${station['name']} (${station['code']})';
    }
    final stationId = _selectedStationId ?? widget.sessionController.stationId;
    if (stationId != null) {
      return 'Station $stationId (session scope)';
    }
    if (widget.sessionController.scopeLevel == 'organization') {
      return 'Organization scope - station optional here';
    }
    return 'No station selected';
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
                      final stationField = _buildAdminScopeSelector(context);
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
                  _buildWorkspaceReview(context),
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

  Widget _buildAdminScopeSelector(BuildContext context) {
    if (widget.sessionController.scopeLevel == 'organization') {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Tenant scope'),
        child: Text('$_scopeOrganizationLabel - $_scopeStationLabel'),
      );
    }
    return DropdownButtonFormField<int>(
      key: ValueKey<String>('admin-station-${_selectedStationId ?? 'none'}'),
      initialValue:
          _stations.any((station) => _sameId(station['id'], _selectedStationId))
          ? _selectedStationId
          : null,
      decoration: const InputDecoration(labelText: 'Station'),
      items: [
        for (final station in _stations)
          DropdownMenuItem<int>(
            value: _asInt(station['id']),
            child: Text('${station['name']} (${station['code']})'),
          ),
      ],
      onChanged: _changeStation,
    );
  }

  Widget _buildUsersSection(BuildContext context) {
    final creatableRoles = [..._creatableRoleOptions];
    final selectedUser = _users.cast<Map<String, dynamic>?>().firstWhere(
      (user) => user?['id'] == _selectedUserId,
      orElse: () => null,
    );
    if (_selectedRoleId != null &&
        selectedUser != null &&
        !creatableRoles.any((role) => role['id'] == _selectedRoleId)) {
      final currentRole = _roles.cast<Map<String, dynamic>?>().firstWhere(
        (role) => role?['id'] == _selectedRoleId,
        orElse: () => null,
      );
      if (currentRole != null) {
        creatableRoles.add(currentRole);
      }
    }
    final isEditingSelf =
        selectedUser != null &&
        _sameId(
          selectedUser['id'],
          widget.sessionController.currentUser?['id'],
        );
    final roleDropdownValue =
        _selectedRoleId != null &&
            creatableRoles.any((role) => _sameId(role['id'], _selectedRoleId))
        ? _selectedRoleId
        : null;
    final selectedRoleNeedsStation = _roleRequiresStation(roleDropdownValue);
    final defaultStation = _stations.cast<Map<String, dynamic>?>().firstWhere(
      (station) => _sameId(station?['id'], _defaultStationId),
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.tonalIcon(
                onPressed: _isSubmitting ? null : _startNewWorker,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('New Worker Login'),
              ),
              Text(
                _selectedUserId == null
                    ? 'Fill the worker details below.'
                    : isEditingSelf
                    ? 'You are viewing the current HeadOffice owner account. Use New Worker Login for manager/operator/accountant users.'
                    : 'Editing selected tenant user.',
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userFullNameController,
            enabled: _canManageUsers && !isEditingSelf,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userUsernameController,
            enabled: _canManageUsers && _selectedUserId == null,
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userEmailController,
            enabled: _canManageUsers && !isEditingSelf,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userPasswordController,
            enabled: _canManageUsers && !isEditingSelf,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: ValueKey<String>('admin-role-${_selectedRoleId ?? 'none'}'),
            initialValue: roleDropdownValue,
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
            onChanged: _canManageUsers && !isEditingSelf
                ? (value) {
                    setState(() {
                      _selectedRoleId = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Worker Assignment'),
            child: Text(
              selectedRoleNeedsStation
                  ? defaultStation == null
                        ? 'Station role selected, but no tenant station is loaded yet.'
                        : 'Will assign to ${defaultStation['name']} (${defaultStation['code']}).'
                  : 'Organization-level role for $_scopeOrganizationLabel.',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _userSalaryController,
            enabled: _canManageUsers && !isEditingSelf,
            decoration: const InputDecoration(labelText: 'Monthly Salary'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _userPayrollEnabled,
            title: const Text('Payroll Enabled'),
            onChanged: _canManageUsers && !isEditingSelf
                ? (value) {
                    setState(() {
                      _userPayrollEnabled = value;
                    });
                  }
                : null,
          ),
          const SizedBox(height: 16),
          if (_canManageUsers && !isEditingSelf)
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
                if (!isEditingSelf)
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
                    trailing:
                        _sameId(
                          user['id'],
                          widget.sessionController.currentUser?['id'],
                        )
                        ? const Chip(label: Text('Current HeadOffice'))
                        : const Icon(Icons.edit_outlined),
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
    final selectedOrganization = _organizations
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['id'] == _selectedOrganizationId,
          orElse: () => null,
        );
    final selectedStation = _stations.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['id'] == _selectedStationId,
      orElse: () => null,
    );
    final subscription = _organizationSubscription ?? const <String, dynamic>{};
    final planId = subscription['plan_id'] as int?;
    final subscriptionStatus = subscription['status'] as String? ?? 'inactive';
    final billingCycle = subscription['billing_cycle'] as String? ?? 'monthly';
    final autoRenew = subscription['auto_renew'] as bool? ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capability Controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            if (!_canManageOrganizationModules &&
                !_canManageStationModules &&
                !_canManageSubscription) ...[
              _buildReadOnlyNotice(
                'This role can review package and module state but cannot change these controls.',
              ),
              const SizedBox(height: 12),
            ],
            if (_organizations.isNotEmpty)
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'admin-module-organization-${_selectedOrganizationId ?? 'none'}',
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
                onChanged: _changeOrganization,
              ),
            if (_stations.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey<String>(
                  'admin-module-station-${_selectedStationId ?? 'none'}',
                ),
                initialValue: _selectedStationId,
                decoration: const InputDecoration(labelText: 'Station'),
                items: [
                  for (final station in _stations)
                    if (_selectedOrganizationId == null ||
                        station['organization_id'] == _selectedOrganizationId)
                      DropdownMenuItem<int>(
                        value: station['id'] as int,
                        child: Text('${station['name']} (${station['code']})'),
                      ),
                ],
                onChanged: _changeStation,
              ),
            ],
            if (_selectedOrganizationId == null) ...[
              const SizedBox(height: 16),
              const Text(
                'Select an organization to review capability controls.',
              ),
            ] else ...[
              const SizedBox(height: 20),
              Text(
                'Subscription',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!_canReadSubscription)
                const Text('This role cannot review subscription state.')
              else ...[
                _buildDetailWrap([
                  _buildDetailItem(
                    'Organization',
                    selectedOrganization?['name'] as String? ?? '-',
                  ),
                  _buildDetailItem(
                    'Plan',
                    _lookupName(_subscriptionPlans, planId),
                  ),
                  _buildDetailItem('Status', subscriptionStatus),
                  _buildDetailItem('Billing', billingCycle),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  key: ValueKey<String>(
                    'admin-module-plan-${planId ?? 'none'}',
                  ),
                  initialValue: planId,
                  decoration: const InputDecoration(labelText: 'Plan'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('No plan'),
                    ),
                    for (final plan in _subscriptionPlans)
                      DropdownMenuItem<int?>(
                        value: plan['id'] as int,
                        child: Text('${plan['name']} (${plan['code']})'),
                      ),
                  ],
                  onChanged: !_canManageSubscription || _isSubmitting
                      ? null
                      : (value) => _saveSubscription(
                          planId: value,
                          status: subscriptionStatus,
                          billingCycle: billingCycle,
                          autoRenew: autoRenew,
                        ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'admin-module-status-$subscriptionStatus',
                  ),
                  initialValue: subscriptionStatus,
                  decoration: const InputDecoration(
                    labelText: 'Subscription status',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text('Inactive'),
                    ),
                    DropdownMenuItem(value: 'trial', child: Text('Trial')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                  ],
                  onChanged: !_canManageSubscription || _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          _saveSubscription(
                            planId: planId,
                            status: value,
                            billingCycle: billingCycle,
                            autoRenew: autoRenew,
                          );
                        },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: autoRenew,
                  title: const Text('Auto renew'),
                  subtitle: const Text(
                    'Keep the organization on its current subscription cycle automatically.',
                  ),
                  onChanged: !_canManageSubscription || _isSubmitting
                      ? null
                      : (value) => _saveSubscription(
                          planId: planId,
                          status: subscriptionStatus,
                          billingCycle: billingCycle,
                          autoRenew: value,
                        ),
                ),
              ],
              const Divider(height: 32),
              Text(
                'Organization Modules',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!_canReadOrganizationModules)
                const Text('This role cannot review organization module state.')
              else if (_organizationModules.isEmpty)
                const Text('No organization module settings found yet.')
              else
                for (final module in _organizationModules)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: module['is_enabled'] as bool? ?? false,
                    title: Text(module['module_name'] as String? ?? 'Module'),
                    subtitle: Text(
                      selectedOrganization?['name'] as String? ??
                          'Organization',
                    ),
                    onChanged: !_canManageOrganizationModules || _isSubmitting
                        ? null
                        : (value) => _toggleOrganizationModule(
                            module['module_name'] as String,
                            value,
                          ),
                  ),
              const Divider(height: 32),
              Text(
                'Station Modules',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (!_canReadStationModules)
                const Text('This role cannot review station module state.')
              else if (_selectedStationId == null)
                const Text('Select a station to manage station modules.')
              else if (_stationModules.isEmpty)
                const Text(
                  'No station module settings found for this station yet.',
                )
              else
                for (final module in _stationModules)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: module['is_enabled'] as bool? ?? false,
                    title: Text(module['module_name'] as String? ?? 'Module'),
                    subtitle: Text(
                      selectedStation?['name'] as String? ??
                          'Station ${module['station_id']}',
                    ),
                    onChanged: !_canManageStationModules || _isSubmitting
                        ? null
                        : (value) => _toggleStationModule(
                            module['module_name'] as String,
                            value,
                          ),
                  ),
            ],
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
          'Manage package state, organization visibility, and station-level toggles so the app matches the tenant setup immediately.',
          Icons.toggle_on_outlined,
        );
    }
  }

  Widget _buildWorkspaceReview(BuildContext context) {
    final subscription = _organizationSubscription;
    final planName = _lookupName(_subscriptionPlans, subscription?['plan_id']);
    final sectionMeta = _sectionMeta(_section);
    final nextAction = switch (_section) {
      _AdminSection.users =>
        'Review station scope, role options, and existing users before creating or updating login access.',
      _AdminSection.employeeProfiles =>
        'Review staff profile counts and payroll state before creating profile-only or login-linked staff records.',
      _AdminSection.stations =>
        'Review organization context before creating or editing station structure.',
      _AdminSection.roles =>
        'Review protected roles and assigned user counts before changing role governance.',
      _AdminSection.modules =>
        'Review subscription, organization modules, and station module overrides before toggling capability visibility.',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Review',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(sectionMeta.$1, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(nextAction, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(
                context,
                icon: Icons.business_outlined,
                label: _scopeOrganizationLabel,
              ),
              _buildInfoChip(
                context,
                icon: Icons.store_outlined,
                label: _scopeStationLabel,
              ),
              _buildInfoChip(
                context,
                icon: Icons.group_outlined,
                label: 'Users ${_users.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.badge_outlined,
                label: 'Staff ${_employeeProfiles.length}',
              ),
              _buildInfoChip(
                context,
                icon: Icons.toggle_on_outlined,
                label:
                    'Modules ${_organizationModules.length}/${_stationModules.length}',
              ),
              if (_canReadSubscription)
                _buildInfoChip(
                  context,
                  icon: Icons.workspace_premium_outlined,
                  label: '$planName • ${subscription?['status'] ?? 'inactive'}',
                ),
            ],
          ),
        ],
      ),
    );
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

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 8), Text(label)],
      ),
    );
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
