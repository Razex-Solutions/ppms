import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const PpmsTenantApp());
}

class AppConfig {
  static const defaultBaseUrl = String.fromEnvironment(
    'PPMS_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8012',
  );

  static const backgroundColor = Color(0xFFF4FAF8);
}

class PpmsTenantApp extends StatefulWidget {
  const PpmsTenantApp({super.key});

  @override
  State<PpmsTenantApp> createState() => _PpmsTenantAppState();
}

class _PpmsTenantAppState extends State<PpmsTenantApp> {
  late final TenantSessionController _sessionController;

  @override
  void initState() {
    super.initState();
    _sessionController = TenantSessionController(TenantApiClient());
    _sessionController.restore();
  }

  @override
  void dispose() {
    _sessionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PPMS Tenant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        canvasColor: AppConfig.backgroundColor,
        scaffoldBackgroundColor: AppConfig.backgroundColor,
        useMaterial3: true,
      ),
      home: TenantAppRoot(sessionController: _sessionController),
    );
  }
}

class TenantAppRoot extends StatelessWidget {
  const TenantAppRoot({super.key, required this.sessionController});

  final TenantSessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) {
        if (sessionController.isRestoring) {
          return const Scaffold(
            backgroundColor: AppConfig.backgroundColor,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!sessionController.isAuthenticated) {
          return LoginPage(sessionController: sessionController);
        }
        return TenantHomePage(sessionController: sessionController);
      },
    );
  }
}

class TenantApiClient {
  TenantApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Uri _uri(String baseUrl, String path) {
    final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$normalizedBaseUrl$path');
  }

  Future<Map<String, dynamic>> login({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/login',
      body: {'username': username, 'password': password},
    );
  }

  Future<Map<String, dynamic>> currentUser({
    required String baseUrl,
    required String accessToken,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/auth/me',
      accessToken: accessToken,
    );
  }

  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {
    await _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/auth/logout',
      accessToken: accessToken,
    );
  }

  Future<List<Map<String, dynamic>>> stations({
    required String baseUrl,
    required String accessToken,
    int? organizationId,
  }) async {
    final query = organizationId == null
        ? ''
        : '?organization_id=$organizationId';
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/stations/$query',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> _send({
    required String baseUrl,
    required String method,
    required String path,
    String? accessToken,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final uri = _uri(baseUrl, path);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      'POST' => await _httpClient.post(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      _ => throw TenantApiException('Unsupported API method $method'),
    };

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw TenantApiException(
        message ?? 'Request failed with ${response.statusCode}',
      );
    }
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  Future<List<dynamic>> _sendList({
    required String baseUrl,
    required String method,
    required String path,
    String? accessToken,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (accessToken != null) 'Authorization': 'Bearer $accessToken',
    };
    final uri = _uri(baseUrl, path);
    final response = switch (method) {
      'GET' => await _httpClient.get(uri, headers: headers),
      _ => throw TenantApiException('Unsupported API method $method'),
    };

    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map<String, dynamic>
          ? decoded['detail']?.toString()
          : null;
      throw TenantApiException(
        message ?? 'Request failed with ${response.statusCode}',
      );
    }
    return decoded is List ? decoded : const [];
  }
}

class TenantApiException implements Exception {
  TenantApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class TenantWorkspace {
  const TenantWorkspace({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
    required this.purpose,
    required this.nextAction,
  });

  final String id;
  final String label;
  final IconData icon;
  final String category;
  final String purpose;
  final String nextAction;
}

const _contextWorkspace = TenantWorkspace(
  id: 'context',
  label: 'Context',
  icon: Icons.badge_outlined,
  category: 'System',
  purpose: 'Confirm the current user, role, organization, and working station.',
  nextAction: 'Use this first whenever login or station scope looks wrong.',
);

const _settingsWorkspace = TenantWorkspace(
  id: 'settings',
  label: 'Settings',
  icon: Icons.settings_outlined,
  category: 'System',
  purpose: 'Show local app diagnostics and safe tenant settings later.',
  nextAction: 'Keep this simple until the real tenant flows are stable.',
);

List<TenantWorkspace> workspaceDestinationsForRole(String roleName) {
  final normalizedRole = roleName.trim().toLowerCase();
  final roleWorkspaces = switch (normalizedRole) {
    'headoffice' => const [
      TenantWorkspace(
        id: 'tenant_setup',
        label: 'Tenant Setup',
        icon: Icons.business_outlined,
        category: 'Setup',
        purpose:
            'Review organization, legal identity, brand, station count, and tenant setup questions.',
        nextAction:
            'Wire a read-only tenant setup summary before allowing edits.',
      ),
      TenantWorkspace(
        id: 'users',
        label: 'Users',
        icon: Icons.group_add_outlined,
        category: 'Admin',
        purpose:
            'Create and manage tenant workers for this organization and station.',
        nextAction:
            'Next build: create Manager, Accountant, and Operator. StationAdmin stays hidden for one-station tenants.',
      ),
      TenantWorkspace(
        id: 'station_setup',
        label: 'Station Setup',
        icon: Icons.local_gas_station_outlined,
        category: 'Setup',
        purpose:
            'Maintain station defaults, invoice profile, fuel types, tanks, dispensers, and nozzles.',
        nextAction:
            'Next build: read-only setup review first, then edit flows one by one.',
      ),
      TenantWorkspace(
        id: 'inventory',
        label: 'Inventory & Dips',
        icon: Icons.inventory_2_outlined,
        category: 'Setup',
        purpose:
            'Review tanks, stock position, tank dips, and fuel inventory movement.',
        nextAction:
            'Wire tank/nozzle setup summary first, then add dip entry after fuel sale flow.',
      ),
      TenantWorkspace(
        id: 'operations_overview',
        label: 'Operations',
        icon: Icons.route_outlined,
        category: 'Operations',
        purpose:
            'Review tenant shift, sale, cash, purchase, and expense readiness.',
        nextAction:
            'Use this as a HeadOffice oversight page after Manager and Operator flows exist.',
      ),
      TenantWorkspace(
        id: 'finance_overview',
        label: 'Finance Overview',
        icon: Icons.account_balance_wallet_outlined,
        category: 'Finance',
        purpose:
            'Review customer/supplier ledgers, payments, payroll, and finance readiness.',
        nextAction:
            'Wire after Accountant finance and parties flows are accepted.',
      ),
      TenantWorkspace(
        id: 'tankers',
        label: 'Tankers',
        icon: Icons.local_shipping_outlined,
        category: 'Optional Modules',
        purpose:
            'Review tanker ownership, tanker masters, trips, deliveries, expenses, and leftovers.',
        nextAction:
            'Keep module-gated; build after core station sale and purchase flows are stable.',
      ),
      TenantWorkspace(
        id: 'pos',
        label: 'POS / Shop',
        icon: Icons.point_of_sale_outlined,
        category: 'Optional Modules',
        purpose:
            'Review shop/POS product and sale flows when the module is enabled.',
        nextAction:
            'Keep module-gated; build after fuel operations are accepted.',
      ),
      TenantWorkspace(
        id: 'hardware',
        label: 'Hardware',
        icon: Icons.settings_input_component_outlined,
        category: 'Optional Modules',
        purpose:
            'Review hardware devices, vendor context, and meter-related integrations.',
        nextAction:
            'Keep optional; manual meter flows must work without hardware first.',
      ),
      TenantWorkspace(
        id: 'reports',
        label: 'Reports',
        icon: Icons.summarize_outlined,
        category: 'Reporting',
        purpose:
            'Review organization and station reports for this tenant only.',
        nextAction:
            'Build after core actions are working so reports only show proven data.',
      ),
      TenantWorkspace(
        id: 'documents',
        label: 'Documents',
        icon: Icons.description_outlined,
        category: 'Reporting',
        purpose:
            'Review generated financial documents and local dispatch state.',
        nextAction:
            'Build after sales, payments, and finance records are stable.',
      ),
      TenantWorkspace(
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        category: 'Reporting',
        purpose:
            'Review notification preferences, inbox, delivery logs, and local mock dispatch.',
        nextAction:
            'Build after document/report events are stable; real providers come later.',
      ),
    ],
    'manager' => const [
      TenantWorkspace(
        id: 'shifts',
        label: 'Shifts',
        icon: Icons.schedule_outlined,
        category: 'Operations',
        purpose: 'Open, supervise, and close station shifts.',
        nextAction:
            'Next build after users: station shift status and open-shift validation.',
      ),
      TenantWorkspace(
        id: 'fuel_sales',
        label: 'Fuel Sales',
        icon: Icons.local_gas_station_outlined,
        category: 'Operations',
        purpose: 'Review and manage station meter-based fuel sale activity.',
        nextAction: 'Wire after operator fuel-sale entry is stable.',
      ),
      TenantWorkspace(
        id: 'sales_review',
        label: 'Sales Review',
        icon: Icons.receipt_long_outlined,
        category: 'Operations',
        purpose: 'Review station sales entered by operators.',
        nextAction: 'Build after operator fuel-sale entry is stable.',
      ),
      TenantWorkspace(
        id: 'cash',
        label: 'Cash',
        icon: Icons.payments_outlined,
        category: 'Operations',
        purpose: 'Review shift cash submissions and station cash status.',
        nextAction: 'Build after shift and sale flows are stable.',
      ),
      TenantWorkspace(
        id: 'purchases',
        label: 'Purchases',
        icon: Icons.shopping_cart_checkout_outlined,
        category: 'Operations',
        purpose:
            'Record and review operational fuel purchases for the assigned station.',
        nextAction:
            'Wire after setup confirms tanks and suppliers can be selected safely.',
      ),
      TenantWorkspace(
        id: 'expenses',
        label: 'Expenses',
        icon: Icons.request_quote_outlined,
        category: 'Operations',
        purpose: 'Record and review station operating expenses.',
        nextAction: 'Build after the shift flow is accepted.',
      ),
      TenantWorkspace(
        id: 'inventory_dips',
        label: 'Inventory & Dips',
        icon: Icons.inventory_2_outlined,
        category: 'Operations',
        purpose:
            'Review station tank stock and record tank dip checks when needed.',
        nextAction:
            'Wire after fuel sales and purchases are producing stock movement.',
      ),
      TenantWorkspace(
        id: 'tankers',
        label: 'Tankers',
        icon: Icons.local_shipping_outlined,
        category: 'Optional Modules',
        purpose:
            'Manage tanker trips, manual tanker sales, expenses, and leftover transfers.',
        nextAction:
            'Build only for tanker-enabled tenants after core fuel operations.',
      ),
      TenantWorkspace(
        id: 'pos',
        label: 'POS / Shop',
        icon: Icons.point_of_sale_outlined,
        category: 'Optional Modules',
        purpose:
            'Manage POS/shop sales when that module is enabled for the station.',
        nextAction: 'Build only after core fuel sale flow is accepted.',
      ),
      TenantWorkspace(
        id: 'attendance',
        label: 'Attendance',
        icon: Icons.how_to_reg_outlined,
        category: 'People',
        purpose: 'Review station staff attendance.',
        nextAction: 'Build after staff profiles are connected to logins.',
      ),
      TenantWorkspace(
        id: 'reports',
        label: 'Reports',
        icon: Icons.summarize_outlined,
        category: 'Reporting',
        purpose: 'Review station operational reports.',
        nextAction: 'Build after shifts, sales, cash, expenses, and purchases.',
      ),
    ],
    'accountant' => const [
      TenantWorkspace(
        id: 'finance',
        label: 'Finance',
        icon: Icons.account_balance_wallet_outlined,
        category: 'Finance',
        purpose: 'Manage purchases, payments, expenses, and financial review.',
        nextAction: 'Build after users and parties are stable.',
      ),
      TenantWorkspace(
        id: 'purchases',
        label: 'Purchases',
        icon: Icons.shopping_cart_checkout_outlined,
        category: 'Finance',
        purpose: 'Review and process tenant purchase records.',
        nextAction:
            'Wire after suppliers and tank/fuel selection are proven safe.',
      ),
      TenantWorkspace(
        id: 'expenses',
        label: 'Expenses',
        icon: Icons.request_quote_outlined,
        category: 'Finance',
        purpose: 'Review and process tenant expenses.',
        nextAction: 'Wire after Manager expense recording is accepted.',
      ),
      TenantWorkspace(
        id: 'parties',
        label: 'Parties',
        icon: Icons.contacts_outlined,
        category: 'Finance',
        purpose: 'Manage customers, suppliers, and tenant ledger context.',
        nextAction: 'Build before payment and ledger screens.',
      ),
      TenantWorkspace(
        id: 'payments',
        label: 'Payments',
        icon: Icons.currency_exchange_outlined,
        category: 'Finance',
        purpose: 'Record customer and supplier payments.',
        nextAction:
            'Build after customer/supplier records and ledger summaries load.',
      ),
      TenantWorkspace(
        id: 'payroll',
        label: 'Payroll',
        icon: Icons.price_check_outlined,
        category: 'People',
        purpose: 'Review payroll for tenant station workers.',
        nextAction: 'Build after staff profiles are connected.',
      ),
      TenantWorkspace(
        id: 'attendance',
        label: 'Attendance',
        icon: Icons.how_to_reg_outlined,
        category: 'People',
        purpose: 'Review attendance records that affect payroll.',
        nextAction: 'Wire after staff profile linking is stable.',
      ),
      TenantWorkspace(
        id: 'tankers',
        label: 'Tankers',
        icon: Icons.local_shipping_outlined,
        category: 'Optional Modules',
        purpose:
            'Review tanker financial impact, expenses, and purchase value.',
        nextAction: 'Build after tanker operations are accepted for Manager.',
      ),
      TenantWorkspace(
        id: 'documents',
        label: 'Documents',
        icon: Icons.description_outlined,
        category: 'Reporting',
        purpose: 'Generate and inspect tenant financial documents.',
        nextAction: 'Build after finance transactions are stable.',
      ),
      TenantWorkspace(
        id: 'reports',
        label: 'Reports',
        icon: Icons.summarize_outlined,
        category: 'Reporting',
        purpose: 'Review accounting and station reports for this tenant only.',
        nextAction: 'Build after finance flows are accepted.',
      ),
      TenantWorkspace(
        id: 'notifications',
        label: 'Notifications',
        icon: Icons.notifications_outlined,
        category: 'Reporting',
        purpose: 'Review document/report notification delivery state.',
        nextAction: 'Build after documents are connected.',
      ),
    ],
    'operator' => const [
      TenantWorkspace(
        id: 'shift',
        label: 'Shift',
        icon: Icons.timer_outlined,
        category: 'Operations',
        purpose: 'See current shift state and assigned station work.',
        nextAction:
            'Build operator shift start/status after Manager shift rules.',
      ),
      TenantWorkspace(
        id: 'fuel_sale',
        label: 'Fuel Sale',
        icon: Icons.local_gas_station_outlined,
        category: 'Operations',
        purpose: 'Enter meter-based fuel sales for the assigned station only.',
        nextAction:
            'Build after station nozzles are confirmed through setup review.',
      ),
      TenantWorkspace(
        id: 'cash_submission',
        label: 'Cash Submission',
        icon: Icons.payments_outlined,
        category: 'Operations',
        purpose:
            'Submit cash for the operator shift when policy allows operator cash handover.',
        nextAction: 'Wire after shift and fuel sale totals are available.',
      ),
      TenantWorkspace(
        id: 'tank_dips',
        label: 'Tank Dips',
        icon: Icons.straighten_outlined,
        category: 'Operations',
        purpose:
            'Record assigned physical tank dip checks if the station requires it.',
        nextAction: 'Build after Manager inventory/dip rules are accepted.',
      ),
      TenantWorkspace(
        id: 'pos_sale',
        label: 'POS Sale',
        icon: Icons.point_of_sale_outlined,
        category: 'Optional Modules',
        purpose: 'Enter shop/POS sales when the module is enabled.',
        nextAction:
            'Keep hidden when POS module is disabled; build after fuel sale flow.',
      ),
      TenantWorkspace(
        id: 'attendance',
        label: 'Attendance',
        icon: Icons.how_to_reg_outlined,
        category: 'People',
        purpose: 'Record or view operator attendance.',
        nextAction: 'Build after staff profiles are connected.',
      ),
    ],
    _ => const [
      TenantWorkspace(
        id: 'support',
        label: 'Unsupported Role',
        icon: Icons.warning_amber_outlined,
        category: 'System',
        purpose: 'This role is not part of the clean tenant app flow yet.',
        nextAction:
            'Confirm the backend role mapping before adding any screens.',
      ),
    ],
  };

  return [_contextWorkspace, ...roleWorkspaces, _settingsWorkspace];
}

class TenantSessionController extends ChangeNotifier {
  TenantSessionController(this._apiClient);

  static const _storageKey = 'ppms_tenant_session';

  final TenantApiClient _apiClient;

  String _baseUrl = AppConfig.defaultBaseUrl;
  Map<String, dynamic>? _tokens;
  Map<String, dynamic>? _currentUser;
  List<Map<String, dynamic>> _stations = const [];
  bool _isRestoring = true;
  bool _isBusy = false;
  String? _errorMessage;

  bool get isAuthenticated => _tokens != null && _currentUser != null;
  bool get isRestoring => _isRestoring;
  bool get isBusy => _isBusy;
  String get baseUrl => _baseUrl;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get currentUser => _currentUser;
  List<Map<String, dynamic>> get stations => _stations;
  String get roleName => _currentUser?['role_name'] as String? ?? 'Unknown';
  String get scopeLevel => _currentUser?['scope_level'] as String? ?? 'unknown';
  String get username => _currentUser?['username'] as String? ?? '-';
  int? get organizationId => _currentUser?['organization_id'] as int?;
  int? get stationId => _currentUser?['station_id'] as int?;
  Map<String, dynamic>? get workingStation {
    if (_stations.isEmpty) return null;
    if (stationId != null) {
      for (final station in _stations) {
        if (station['id'] == stationId) return station;
      }
    }
    return _stations.length == 1 ? _stations.first : null;
  }

  String get workingStationLabel {
    final station = workingStation;
    if (station == null) {
      return roleName == 'HeadOffice' && stationId == null
          ? 'Organization scope - no single station resolved'
          : '-';
    }
    final name = station['name'] as String? ?? 'Station ${station['id']}';
    final code = station['code'] as String?;
    return code == null || code.isEmpty ? name : '$name ($code)';
  }

  List<String> get creatableRoles =>
      List<String>.from(_currentUser?['creatable_roles'] as List? ?? const []);

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSession = prefs.getString(_storageKey);
    if (rawSession == null) {
      _isRestoring = false;
      notifyListeners();
      return;
    }
    try {
      final saved = jsonDecode(rawSession) as Map<String, dynamic>;
      _baseUrl = saved['baseUrl'] as String? ?? AppConfig.defaultBaseUrl;
      _tokens = Map<String, dynamic>.from(saved['tokens'] as Map);
      await _refreshCurrentUser();
    } on Object {
      await clear();
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> signIn({
    required String baseUrl,
    required String username,
    required String password,
  }) async {
    _setBusy();
    try {
      _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
      _tokens = await _apiClient.login(
        baseUrl: _baseUrl,
        username: username,
        password: password,
      );
      await _refreshCurrentUser();
      await _persist();
      _errorMessage = null;
    } on TenantApiException catch (error) {
      _errorMessage = error.message;
      _tokens = null;
      _currentUser = null;
    } on Object catch (error) {
      _errorMessage = 'Could not connect to backend: $error';
      _tokens = null;
      _currentUser = null;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final accessToken = _tokens?['access_token'] as String?;
    if (accessToken != null) {
      try {
        await _apiClient.logout(baseUrl: _baseUrl, accessToken: accessToken);
      } on Object {
        // Local sign-out must still complete even if the backend rejects logout.
      }
    }
    await clear();
  }

  Future<void> clear() async {
    _tokens = null;
    _currentUser = null;
    _stations = const [];
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _refreshCurrentUser() async {
    final accessToken = _tokens?['access_token'] as String?;
    if (accessToken == null) {
      throw TenantApiException('No access token is available.');
    }
    _currentUser = await _apiClient.currentUser(
      baseUrl: _baseUrl,
      accessToken: accessToken,
    );
    _stations = await _apiClient.stations(
      baseUrl: _baseUrl,
      accessToken: accessToken,
      organizationId: organizationId,
    );
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode({'baseUrl': _baseUrl, 'tokens': _tokens}),
    );
  }

  void _setBusy() {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.sessionController});

  final TenantSessionController sessionController;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController _baseUrlController;
  final _usernameController = TextEditingController(text: 'check');
  final _passwordController = TextEditingController(text: 'office123');

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(
      text: widget.sessionController.baseUrl,
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.sessionController.signIn(
      baseUrl: _baseUrlController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      body: SafeArea(
        child: ColoredBox(
          color: AppConfig.backgroundColor,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'PPMS Tenant Login',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use the Phase 9 test tenant first: check / office123.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _baseUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Backend URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: widget.sessionController.isBusy
                          ? null
                          : _submit,
                      child: widget.sessionController.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                    if (widget.sessionController.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        widget.sessionController.errorMessage!,
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
        ),
      ),
    );
  }
}

class TenantHomePage extends StatefulWidget {
  const TenantHomePage({super.key, required this.sessionController});

  final TenantSessionController sessionController;

  @override
  State<TenantHomePage> createState() => _TenantHomePageState();
}

class _TenantHomePageState extends State<TenantHomePage> {
  String _selectedWorkspaceId = 'context';

  TenantSessionController get sessionController => widget.sessionController;

  @override
  Widget build(BuildContext context) {
    final workspaces = workspaceDestinationsForRole(sessionController.roleName);
    final selectedWorkspace = workspaces.firstWhere(
      (workspace) => workspace.id == _selectedWorkspaceId,
      orElse: () => workspaces.first,
    );

    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        title: Text(
          'PPMS Tenant - ${sessionController.roleName} - ${sessionController.workingStationLabel}',
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: sessionController.signOut,
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: ColoredBox(
        color: AppConfig.backgroundColor,
        child: Row(
          children: [
            SizedBox(
              width: 280,
              child: _WorkspaceSidebar(
                workspaces: workspaces,
                selectedWorkspaceId: selectedWorkspace.id,
                onWorkspaceSelected: (workspaceId) {
                  setState(() => _selectedWorkspaceId = workspaceId);
                },
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: _WorkspaceDetail(
                sessionController: sessionController,
                workspace: selectedWorkspace,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceSidebar extends StatelessWidget {
  const _WorkspaceSidebar({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.onWorkspaceSelected,
  });

  final List<TenantWorkspace> workspaces;
  final String selectedWorkspaceId;
  final ValueChanged<String> onWorkspaceSelected;

  @override
  Widget build(BuildContext context) {
    final workspaceTiles = <Widget>[];
    String? previousCategory;
    for (final workspace in workspaces) {
      if (workspace.category != previousCategory) {
        previousCategory = workspace.category;
        workspaceTiles.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
            child: Text(
              workspace.category.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        );
      }
      workspaceTiles.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            selected: workspace.id == selectedWorkspaceId,
            selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            leading: Icon(workspace.icon),
            title: Text(workspace.label),
            onTap: () => onWorkspaceSelected(workspace.id),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Text(
                'Workspaces',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ...workspaceTiles,
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDetail extends StatelessWidget {
  const _WorkspaceDetail({
    required this.sessionController,
    required this.workspace,
  });

  final TenantSessionController sessionController;
  final TenantWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final isUsersWorkspace = workspace.id == 'users';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          workspace.label,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        Text(
          '${workspace.category} workspace. Clean tenant app rebuild: no dashboards, no fake totals.',
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _ContextChip(label: 'User', value: sessionController.username),
            _ContextChip(label: 'Role', value: sessionController.roleName),
            _ContextChip(label: 'Scope', value: sessionController.scopeLevel),
            _ContextChip(
              label: 'Organization',
              value: sessionController.organizationId?.toString() ?? '-',
            ),
            _ContextChip(
              label: 'Station',
              value: sessionController.workingStationLabel,
            ),
            _ContextChip(
              label: 'Station count',
              value: sessionController.stations.length.toString(),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _SectionCard(title: 'Purpose', body: workspace.purpose),
        const SizedBox(height: 12),
        _SectionCard(title: 'Next planned action', body: workspace.nextAction),
        if (isUsersWorkspace) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Allowed worker roles',
            body: sessionController.creatableRoles.isEmpty
                ? 'No role-creation capabilities returned for this session.'
                : sessionController.creatableRoles.join(', '),
          ),
        ],
        const SizedBox(height: 12),
        const _SectionCard(
          title: 'Leakage rule',
          body:
              'This screen must only use the logged-in tenant organization and station. MasterAdmin and other organizations stay out of this app.',
        ),
      ],
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}
