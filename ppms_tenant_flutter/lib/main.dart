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

  Future<List<Map<String, dynamic>>> stationModules({
    required String baseUrl,
    required String accessToken,
    required int stationId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/station-modules/$stationId',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> organizationSetupFoundation({
    required String baseUrl,
    required String accessToken,
    required int organizationId,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/organizations/$organizationId/setup-foundation',
      accessToken: accessToken,
    );
  }

  Future<Map<String, dynamic>> stationSetupFoundation({
    required String baseUrl,
    required String accessToken,
    required int stationId,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/stations/$stationId/setup-foundation',
      accessToken: accessToken,
    );
  }

  Future<List<Map<String, dynamic>>> roles({
    required String baseUrl,
    required String accessToken,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/roles/',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<List<Map<String, dynamic>>> users({
    required String baseUrl,
    required String accessToken,
    int? organizationId,
    int? stationId,
  }) async {
    final query = <String>[
      if (organizationId != null) 'organization_id=$organizationId',
      if (stationId != null) 'station_id=$stationId',
    ].join('&');
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: query.isEmpty ? '/users/' : '/users/?$query',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createUser({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/users/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<Map<String, dynamic>> updateUser({
    required String baseUrl,
    required String accessToken,
    required int userId,
    required Map<String, dynamic> body,
  }) async {
    return _send(
      baseUrl: baseUrl,
      method: 'PUT',
      path: '/users/$userId',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<void> deleteUser({
    required String baseUrl,
    required String accessToken,
    required int userId,
  }) async {
    await _send(
      baseUrl: baseUrl,
      method: 'DELETE',
      path: '/users/$userId',
      accessToken: accessToken,
    );
  }

  Future<List<Map<String, dynamic>>> shifts({
    required String baseUrl,
    required String accessToken,
    int? stationId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: stationId == null ? '/shifts/' : '/shifts/?station_id=$stationId',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> openShift({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/shifts/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<Map<String, dynamic>> closeShift({
    required String baseUrl,
    required String accessToken,
    required int shiftId,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/shifts/$shiftId/close',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<Map<String, dynamic>> shiftCash({
    required String baseUrl,
    required String accessToken,
    required int shiftId,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/shifts/$shiftId/cash',
      accessToken: accessToken,
    );
  }

  Future<List<Map<String, dynamic>>> cashSubmissions({
    required String baseUrl,
    required String accessToken,
    required int shiftId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/shifts/$shiftId/cash-submissions',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createCashSubmission({
    required String baseUrl,
    required String accessToken,
    required int shiftId,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/shifts/$shiftId/cash-submissions',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> expenses({
    required String baseUrl,
    required String accessToken,
    int? stationId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: stationId == null
          ? '/expenses/'
          : '/expenses/?station_id=$stationId',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createExpense({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/expenses/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> tankDips({
    required String baseUrl,
    required String accessToken,
    int? stationId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: stationId == null
          ? '/tank-dips/'
          : '/tank-dips/?station_id=$stationId',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createTankDip({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/tank-dips/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> suppliers({
    required String baseUrl,
    required String accessToken,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: '/suppliers/',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createSupplier({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/suppliers/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> purchases({
    required String baseUrl,
    required String accessToken,
    int? stationId,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: stationId == null
          ? '/purchases/'
          : '/purchases/?station_id=$stationId',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createPurchase({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/purchases/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> fuelSales({
    required String baseUrl,
    required String accessToken,
    int? stationId,
    int? shiftId,
  }) async {
    final query = <String>[
      if (stationId != null) 'station_id=$stationId',
      if (shiftId != null) 'shift_id=$shiftId',
    ].join('&');
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: query.isEmpty ? '/fuel-sales/' : '/fuel-sales/?$query',
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> createFuelSale({
    required String baseUrl,
    required String accessToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'POST',
      path: '/fuel-sales/',
      accessToken: accessToken,
      body: body,
    );
  }

  Future<List<Map<String, dynamic>>> listApiPath({
    required String baseUrl,
    required String accessToken,
    required String path,
  }) async {
    final payload = await _sendList(
      baseUrl: baseUrl,
      method: 'GET',
      path: path,
      accessToken: accessToken,
    );
    return payload
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> getApiPath({
    required String baseUrl,
    required String accessToken,
    required String path,
  }) {
    return _send(
      baseUrl: baseUrl,
      method: 'GET',
      path: path,
      accessToken: accessToken,
    );
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
      'PUT' => await _httpClient.put(
        uri,
        headers: headers,
        body: body == null ? null : jsonEncode(body),
      ),
      'DELETE' => await _httpClient.delete(uri, headers: headers),
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
    this.requiredModules = const [],
  });

  final String id;
  final String label;
  final IconData icon;
  final String category;
  final String purpose;
  final String nextAction;
  final List<String> requiredModules;
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
        requiredModules: ['tanker_operations'],
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
        requiredModules: ['pos', 'mart'],
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
        requiredModules: ['hardware'],
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
    'stationadmin' => const [
      TenantWorkspace(
        id: 'users',
        label: 'Users',
        icon: Icons.group_add_outlined,
        category: 'Admin',
        purpose:
            'Create and manage worker users for this assigned station only.',
        nextAction:
            'StationAdmin exists only for multi-station tenants and cannot see other stations.',
      ),
      TenantWorkspace(
        id: 'station_setup',
        label: 'Station Setup',
        icon: Icons.local_gas_station_outlined,
        category: 'Setup',
        purpose:
            'Maintain assigned-station setup, fuel types, tanks, dispensers, and nozzles.',
        nextAction:
            'Keep station-scoped; no cross-station setup access is allowed.',
      ),
      TenantWorkspace(
        id: 'inventory_dips',
        label: 'Inventory & Dips',
        icon: Icons.inventory_2_outlined,
        category: 'Operations',
        purpose: 'Review station stock and record tank dip checks.',
        nextAction:
            'Use the same stock/dip flow as Manager, scoped to the assigned station.',
      ),
      TenantWorkspace(
        id: 'shifts',
        label: 'Shifts',
        icon: Icons.schedule_outlined,
        category: 'Operations',
        purpose: 'Open, supervise, and close assigned-station shifts.',
        nextAction: 'Use station-scoped shift operations only.',
      ),
      TenantWorkspace(
        id: 'fuel_sales',
        label: 'Fuel Sales',
        icon: Icons.local_gas_station_outlined,
        category: 'Operations',
        purpose: 'Review and manage assigned-station meter sales.',
        nextAction: 'Keep cross-station sales hidden.',
      ),
      TenantWorkspace(
        id: 'cash',
        label: 'Cash',
        icon: Icons.payments_outlined,
        category: 'Operations',
        purpose: 'Review shift cash submissions for the assigned station.',
        nextAction: 'Keep cash visibility station-scoped.',
      ),
      TenantWorkspace(
        id: 'purchases',
        label: 'Purchases',
        icon: Icons.shopping_cart_checkout_outlined,
        category: 'Operations',
        purpose: 'Record and review assigned-station fuel purchases.',
        nextAction: 'Use approval rules from the backend scenario runner.',
      ),
      TenantWorkspace(
        id: 'expenses',
        label: 'Expenses',
        icon: Icons.request_quote_outlined,
        category: 'Operations',
        purpose: 'Record and review assigned-station expenses.',
        nextAction: 'Keep expense visibility station-scoped.',
      ),
      TenantWorkspace(
        id: 'tankers',
        label: 'Tankers',
        icon: Icons.local_shipping_outlined,
        category: 'Optional Modules',
        purpose: 'Manage tanker flows only when enabled for this station.',
        nextAction: 'Hide when tanker module is disabled.',
        requiredModules: ['tanker_operations'],
      ),
      TenantWorkspace(
        id: 'pos',
        label: 'POS / Shop',
        icon: Icons.point_of_sale_outlined,
        category: 'Optional Modules',
        purpose: 'Manage POS/shop flows only when enabled for this station.',
        nextAction: 'Hide when POS/mart module is disabled.',
        requiredModules: ['pos', 'mart'],
      ),
      TenantWorkspace(
        id: 'attendance',
        label: 'Attendance',
        icon: Icons.how_to_reg_outlined,
        category: 'People',
        purpose: 'Review assigned-station staff attendance.',
        nextAction: 'Keep staff scope tied to the assigned station.',
      ),
      TenantWorkspace(
        id: 'reports',
        label: 'Reports',
        icon: Icons.summarize_outlined,
        category: 'Reporting',
        purpose: 'Review assigned-station reports only.',
        nextAction: 'No organization-wide report access from StationAdmin.',
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
        requiredModules: ['tanker_operations'],
      ),
      TenantWorkspace(
        id: 'pos',
        label: 'POS / Shop',
        icon: Icons.point_of_sale_outlined,
        category: 'Optional Modules',
        purpose:
            'Manage POS/shop sales when that module is enabled for the station.',
        nextAction: 'Build only after core fuel sale flow is accepted.',
        requiredModules: ['pos', 'mart'],
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
        requiredModules: ['tanker_operations'],
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
        requiredModules: ['pos', 'mart'],
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
  Map<int, Map<String, bool>> _stationModulesByStationId = const {};
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
  Map<int, Map<String, bool>> get stationModulesByStationId =>
      _stationModulesByStationId;
  String get roleName => _currentUser?['role_name'] as String? ?? 'Unknown';
  String get scopeLevel => _currentUser?['scope_level'] as String? ?? 'unknown';
  String get username => _currentUser?['username'] as String? ?? '-';
  int? get currentUserId => _currentUser?['id'] as int?;
  int? get organizationId => _currentUser?['organization_id'] as int?;
  int? get stationId => _currentUser?['station_id'] as int?;
  int? get workingStationId => workingStation?['id'] as int?;
  Map<String, dynamic>? get workingStation {
    if (_stations.isEmpty) return null;
    if (stationId != null) {
      for (final station in _stations) {
        if (station['id'] == stationId) return station;
      }
    }
    return _stations.length == 1 ? _stations.first : null;
  }

  bool get isSingleStationTenant => _stations.length == 1;
  bool get isMultiStationTenant => _stations.length > 1;

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

  bool isModuleEnabledForNavigation(List<String> moduleNames) {
    if (moduleNames.isEmpty) return true;
    if (_stationModulesByStationId.isEmpty) return false;
    final station = workingStation;
    if (station != null) {
      final stationId = station['id'] as int?;
      final modules = stationId == null ? null : _stationModulesByStationId[stationId];
      return moduleNames.any((moduleName) => modules?[moduleName] == true);
    }
    return _stationModulesByStationId.values.any(
      (modules) => moduleNames.any((moduleName) => modules[moduleName] == true),
    );
  }

  String get enabledOptionalModuleLabel {
    final moduleLabels = <String>[];
    for (final entry in {
      'pos': 'POS',
      'mart': 'Mart',
      'tanker_operations': 'Tankers',
      'hardware': 'Hardware',
      'meter_adjustments': 'Meter adjustments',
    }.entries) {
      if (isModuleEnabledForNavigation([entry.key])) {
        moduleLabels.add(entry.value);
      }
    }
    return moduleLabels.isEmpty ? 'None' : moduleLabels.join(', ');
  }

  List<TenantWorkspace> workspacesForCurrentSession() {
    return workspaceDestinationsForRole(roleName)
        .where(
          (workspace) =>
              isModuleEnabledForNavigation(workspace.requiredModules),
        )
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> loadRoles() async {
    return _apiClient.roles(baseUrl: _baseUrl, accessToken: _accessToken());
  }

  Future<List<Map<String, dynamic>>> loadUsers() async {
    return _apiClient.users(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      organizationId: organizationId,
    );
  }

  Future<Map<String, dynamic>> loadOrganizationSetupFoundation() async {
    final resolvedOrganizationId = organizationId;
    if (resolvedOrganizationId == null) {
      throw TenantApiException(
        'No organization is available for this session.',
      );
    }
    return _apiClient.organizationSetupFoundation(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      organizationId: resolvedOrganizationId,
    );
  }

  Future<Map<String, dynamic>> loadStationSetupFoundation() async {
    final resolvedStationId = workingStationId;
    if (resolvedStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    return _apiClient.stationSetupFoundation(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: resolvedStationId,
    );
  }

  Future<List<Map<String, dynamic>>> loadShifts() {
    return _apiClient.shifts(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
    );
  }

  Future<Map<String, dynamic>?> loadOpenShiftForCurrentUser() async {
    final shifts = await _apiClient.shifts(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
    );
    for (final shift in shifts) {
      if (shift['status'] == 'open' && shift['user_id'] == currentUserId) {
        return shift;
      }
    }
    return null;
  }

  Future<void> openShift({required double initialCash, String? notes}) async {
    final resolvedStationId = workingStationId;
    if (resolvedStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    await _apiClient.openShift(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {
        'station_id': resolvedStationId,
        'initial_cash': initialCash,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<void> closeShift({
    required int shiftId,
    required double actualCashCollected,
    String? notes,
  }) async {
    await _apiClient.closeShift(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      shiftId: shiftId,
      body: {
        'actual_cash_collected': actualCashCollected,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<Map<String, dynamic>> loadShiftCash(int shiftId) {
    return _apiClient.shiftCash(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      shiftId: shiftId,
    );
  }

  Future<List<Map<String, dynamic>>> loadCashSubmissions(int shiftId) {
    return _apiClient.cashSubmissions(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      shiftId: shiftId,
    );
  }

  Future<void> createCashSubmission({
    required int shiftId,
    required double amount,
    String? notes,
  }) async {
    await _apiClient.createCashSubmission(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      shiftId: shiftId,
      body: {
        'amount': amount,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadExpenses() {
    return _apiClient.expenses(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
    );
  }

  Future<void> createExpense({
    required String title,
    required String category,
    required double amount,
    String? notes,
  }) async {
    final resolvedStationId = workingStationId;
    if (resolvedStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    await _apiClient.createExpense(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {
        'title': title,
        'category': category,
        'amount': amount,
        'station_id': resolvedStationId,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadTankDips() {
    return _apiClient.tankDips(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
    );
  }

  Future<void> createTankDip({
    required int tankId,
    required double dipReadingMm,
    required double calculatedVolume,
    String? notes,
  }) async {
    await _apiClient.createTankDip(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {
        'tank_id': tankId,
        'dip_reading_mm': dipReadingMm,
        'calculated_volume': calculatedVolume,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadPurchases() {
    return _apiClient.purchases(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
    );
  }

  Future<List<Map<String, dynamic>>> loadSuppliers() {
    return _apiClient.suppliers(baseUrl: _baseUrl, accessToken: _accessToken());
  }

  Future<Map<String, dynamic>> createSupplier({
    required String name,
    required String code,
  }) {
    return _apiClient.createSupplier(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {'name': name, 'code': code},
    );
  }

  Future<void> createPurchase({
    required int supplierId,
    required int tankId,
    required int fuelTypeId,
    required double quantity,
    required double ratePerLiter,
    String? referenceNo,
    String? notes,
  }) async {
    await _apiClient.createPurchase(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {
        'supplier_id': supplierId,
        'tank_id': tankId,
        'fuel_type_id': fuelTypeId,
        'quantity': quantity,
        'rate_per_liter': ratePerLiter,
        if (referenceNo != null && referenceNo.trim().isNotEmpty)
          'reference_no': referenceNo.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadFuelSales({int? shiftId}) {
    return _apiClient.fuelSales(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      stationId: workingStationId,
      shiftId: shiftId,
    );
  }

  Future<List<Map<String, dynamic>>> loadListPath(String path) {
    return _apiClient.listApiPath(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      path: path,
    );
  }

  Future<Map<String, dynamic>> loadMapPath(String path) {
    return _apiClient.getApiPath(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      path: path,
    );
  }

  Future<void> createFuelSale({
    required int nozzleId,
    required int fuelTypeId,
    required double closingMeter,
    required double ratePerLiter,
    int? shiftId,
    String saleType = 'cash',
  }) async {
    final resolvedStationId = workingStationId;
    if (resolvedStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    final body = <String, dynamic>{
      'nozzle_id': nozzleId,
      'station_id': resolvedStationId,
      'fuel_type_id': fuelTypeId,
      'closing_meter': closingMeter,
      'rate_per_liter': ratePerLiter,
      'sale_type': saleType,
    };
    if (shiftId != null) {
      body['shift_id'] = shiftId;
    }
    await _apiClient.createFuelSale(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: body,
    );
  }

  Future<void> createWorkerUser({
    required String fullName,
    required String username,
    required String password,
    required Map<String, dynamic> role,
    required double monthlySalary,
    required bool payrollEnabled,
  }) async {
    final roleId = role['id'] as int?;
    if (roleId == null) {
      throw TenantApiException('Selected role is missing an ID.');
    }
    if (organizationId == null) {
      throw TenantApiException(
        'No organization is available for this session.',
      );
    }
    if (workingStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    await _apiClient.createUser(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      body: {
        'full_name': fullName,
        'username': username,
        'password': password,
        'role_id': roleId,
        'organization_id': organizationId,
        'station_id': workingStationId,
        'scope_level': 'station',
        'is_platform_user': false,
        'monthly_salary': monthlySalary,
        'payroll_enabled': payrollEnabled,
      },
    );
  }

  Future<void> updateWorkerUser({
    required int userId,
    required String fullName,
    required Map<String, dynamic> role,
    required double monthlySalary,
    required bool payrollEnabled,
    required bool isActive,
  }) async {
    final roleId = role['id'] as int?;
    if (roleId == null) {
      throw TenantApiException('Selected role is missing an ID.');
    }
    if (organizationId == null) {
      throw TenantApiException(
        'No organization is available for this session.',
      );
    }
    if (workingStationId == null) {
      throw TenantApiException(
        'No working station is available for this user.',
      );
    }
    await _apiClient.updateUser(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      userId: userId,
      body: {
        'full_name': fullName,
        'role_id': roleId,
        'organization_id': organizationId,
        'station_id': workingStationId,
        'scope_level': 'station',
        'is_platform_user': false,
        'monthly_salary': monthlySalary,
        'payroll_enabled': payrollEnabled,
        'is_active': isActive,
      },
    );
  }

  Future<void> deleteWorkerUser(int userId) async {
    if (userId == currentUserId) {
      throw TenantApiException(
        'You cannot delete your own active user account.',
      );
    }
    await _apiClient.deleteUser(
      baseUrl: _baseUrl,
      accessToken: _accessToken(),
      userId: userId,
    );
  }

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
    _stationModulesByStationId = const {};
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
    final modulesByStation = <int, Map<String, bool>>{};
    for (final station in _stations) {
      final stationId = station['id'] as int?;
      if (stationId == null) continue;
      try {
        final settings = await _apiClient.stationModules(
          baseUrl: _baseUrl,
          accessToken: accessToken,
          stationId: stationId,
        );
        modulesByStation[stationId] = {
          for (final setting in settings)
            if (setting['module_name'] != null)
              setting['module_name'].toString():
                  setting['is_enabled'] as bool? ?? false,
        };
      } on TenantApiException {
        modulesByStation[stationId] = const {};
      }
    }
    _stationModulesByStationId = modulesByStation;
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

  String _accessToken() {
    final accessToken = _tokens?['access_token'] as String?;
    if (accessToken == null) {
      throw TenantApiException('No access token is available.');
    }
    return accessToken;
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

  static const _phase9Logins = [
    _QuickLogin(label: 'HeadOffice', username: 'check', password: 'office123'),
    _QuickLogin(
      label: 'Manager',
      username: 'check_manager',
      password: 'manager123',
    ),
    _QuickLogin(
      label: 'Accountant',
      username: 'check_accountant',
      password: 'accountant123',
    ),
    _QuickLogin(
      label: 'Operator',
      username: 'check_operator',
      password: 'operator123',
    ),
    _QuickLogin(
      label: 'Multi HeadOffice',
      username: 'p9_multi',
      password: 'office123',
    ),
    _QuickLogin(
      label: 'StationAdmin A',
      username: 'p9_multi_station_a_admin',
      password: 'station123',
    ),
    _QuickLogin(
      label: 'StationAdmin B',
      username: 'p9_multi_station_b_admin',
      password: 'station123',
    ),
    _QuickLogin(
      label: 'Minimal HeadOffice',
      username: 'p9_minimal',
      password: 'office123',
    ),
  ];

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

  Future<void> _quickLogin(_QuickLogin login) async {
    _usernameController.text = login.username;
    _passwordController.text = login.password;
    await _submit();
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
                      'Use check first, then p9_multi and p9_minimal for scope/module checks.',
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Quick login',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final login in _phase9Logins)
                          FilledButton.tonalIcon(
                            onPressed: widget.sessionController.isBusy
                                ? null
                                : () => _quickLogin(login),
                            icon: const Icon(Icons.login_outlined),
                            label: Text(login.label),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
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

class _QuickLogin {
  const _QuickLogin({
    required this.label,
    required this.username,
    required this.password,
  });

  final String label;
  final String username;
  final String password;
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
    final workspaces = sessionController.workspacesForCurrentSession();
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
    final isSetupWorkspace = {
      'tenant_setup',
      'station_setup',
      'inventory',
      'inventory_dips',
    }.contains(workspace.id);
    final isManagerOperationsWorkspace = {
      'shifts',
      'fuel_sales',
      'sales_review',
      'cash',
      'purchases',
      'expenses',
      'inventory_dips',
    }.contains(workspace.id);
    final isOperatorFuelWorkspace = workspace.id == 'fuel_sale';
    final isOperatorShiftWorkspace = workspace.id == 'shift';
    final isReadOnlyApiWorkspace = {
      'finance',
      'finance_overview',
      'parties',
      'payments',
      'payroll',
      'attendance',
      'tankers',
      'pos',
      'pos_sale',
      'reports',
      'documents',
      'notifications',
      'cash',
      'sales_review',
    }.contains(workspace.id);

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
            _ContextChip(
              label: 'Enabled optional modules',
              value: sessionController.enabledOptionalModuleLabel,
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
          const SizedBox(height: 12),
          _UserManagementPanel(sessionController: sessionController),
        ],
        if (isSetupWorkspace) ...[
          const SizedBox(height: 12),
          _SetupFoundationPanel(
            sessionController: sessionController,
            workspaceId: workspace.id,
          ),
        ],
        if (isManagerOperationsWorkspace &&
            sessionController.roleName == 'Manager') ...[
          const SizedBox(height: 12),
          _ManagerOperationsPanel(
            sessionController: sessionController,
            workspaceId: workspace.id,
          ),
        ],
        if (isOperatorFuelWorkspace &&
            sessionController.roleName == 'Operator') ...[
          const SizedBox(height: 12),
          _OperatorFuelSalePanel(sessionController: sessionController),
        ],
        if (isOperatorShiftWorkspace &&
            sessionController.roleName == 'Operator') ...[
          const SizedBox(height: 12),
          _OperatorShiftPanel(sessionController: sessionController),
        ],
        if (isReadOnlyApiWorkspace &&
            !_usesSpecialActionPanel(sessionController.roleName, workspace.id)) ...[
          const SizedBox(height: 12),
          _ApiBackedOverviewPanel(
            sessionController: sessionController,
            workspaceId: workspace.id,
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

  bool _usesSpecialActionPanel(String roleName, String workspaceId) {
    if (roleName == 'Manager' &&
        {
          'shifts',
          'fuel_sales',
          'sales_review',
          'cash',
          'purchases',
          'expenses',
          'inventory_dips',
        }.contains(workspaceId)) {
      return true;
    }
    if (roleName == 'Operator' && {'shift', 'fuel_sale'}.contains(workspaceId)) {
      return true;
    }
    return false;
  }
}

class _ApiBackedOverviewPanel extends StatefulWidget {
  const _ApiBackedOverviewPanel({
    required this.sessionController,
    required this.workspaceId,
  });

  final TenantSessionController sessionController;
  final String workspaceId;

  @override
  State<_ApiBackedOverviewPanel> createState() => _ApiBackedOverviewPanelState();
}

class _ApiBackedOverviewPanelState extends State<_ApiBackedOverviewPanel> {
  bool _isLoading = true;
  String? _error;
  final List<_OverviewDataset> _datasets = [];

  int? get _stationId => widget.sessionController.workingStationId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _ApiBackedOverviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _datasets.clear();
    });
    try {
      final datasets = await _loadWorkspaceDatasets();
      if (!mounted) return;
      setState(() {
        _datasets.addAll(datasets);
        _isLoading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<List<_OverviewDataset>> _loadWorkspaceDatasets() async {
    final stationId = _stationId;
    final stationQuery = stationId == null ? '' : '?station_id=$stationId';
    final encodedStationQuery = stationId == null ? '' : '?station_id=$stationId';
    final today = DateTime.now().toIso8601String().split('T').first;
    final dailyClosingQuery = stationId == null
        ? '?report_date=$today'
        : '?report_date=$today&station_id=$stationId';
    switch (widget.workspaceId) {
      case 'finance':
      case 'finance_overview':
        return [
          await _list('Purchases', '/purchases/$stationQuery'),
          await _list('Expenses', '/expenses/$stationQuery'),
          await _list('Customer payments', '/customer-payments/$stationQuery'),
          await _list('Supplier payments', '/supplier-payments/$stationQuery'),
        ];
      case 'parties':
        return [
          await _list('Customers', '/customers/'),
          await _list('Suppliers', '/suppliers/'),
        ];
      case 'payments':
        return [
          await _list('Customer payments', '/customer-payments/$stationQuery'),
          await _list('Supplier payments', '/supplier-payments/$stationQuery'),
        ];
      case 'payroll':
        return [await _list('Payroll runs', '/payroll/runs$stationQuery')];
      case 'attendance':
        return [await _list('Attendance records', '/attendance/$stationQuery')];
      case 'tankers':
        return [
          await _list('Tankers', '/tankers/$stationQuery'),
          await _list('Tanker trips', '/tankers/trips$stationQuery'),
        ];
      case 'pos':
      case 'pos_sale':
        return [
          await _list('POS products', '/pos-products/$stationQuery'),
          await _list('POS sales', '/pos-sales/$stationQuery'),
        ];
      case 'reports':
        return [
          await _map('Daily closing', '/reports/daily-closing$dailyClosingQuery'),
          await _list('Report definitions', '/report-definitions/$stationQuery'),
          await _list('Report exports', '/report-exports/$stationQuery'),
        ];
      case 'documents':
        return [
          await _list('Document templates', stationId == null ? '/document-templates/0' : '/document-templates/$stationId'),
          await _list('Document dispatches', '/financial-documents/dispatches$encodedStationQuery'),
        ];
      case 'notifications':
        return [
          await _map('Notification summary', '/notifications/summary'),
          await _list('Notifications', '/notifications/'),
          await _list('Notification deliveries', '/notifications/deliveries'),
          await _list('Notification preferences', '/notifications/preferences'),
        ];
      case 'cash':
        return [await _list('Station shifts', '/shifts/$stationQuery')];
      case 'sales_review':
        return [await _list('Fuel sales', '/fuel-sales/$stationQuery')];
      default:
        return [];
    }
  }

  Future<_OverviewDataset> _list(String title, String path) async {
    try {
      final rows = await widget.sessionController.loadListPath(path);
      return _OverviewDataset(title: title, rows: rows);
    } on Object catch (error) {
      return _OverviewDataset(
        title: title,
        rows: [
          {'status': 'error', 'message': error.toString()},
        ],
      );
    }
  }

  Future<_OverviewDataset> _map(String title, String path) async {
    try {
      final row = await widget.sessionController.loadMapPath(path);
      return _OverviewDataset(title: title, rows: [row]);
    } on Object catch (error) {
      return _OverviewDataset(
        title: title,
        rows: [
          {'status': 'error', 'message': error.toString()},
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SectionCard(
        title: 'Loading real backend data',
        body: 'Reading scoped tenant data...',
      );
    }
    if (_error != null) {
      return _SectionCard(title: 'Backend error', body: _error!);
    }
    if (_datasets.isEmpty) {
      return const _SectionCard(
        title: 'No API dataset configured yet',
        body: 'This workspace is visible, but no read packet has been added yet.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final dataset in _datasets) ...[
          _SectionCard(
            title: '${dataset.title}: ${dataset.rows.length}',
            body: dataset.rows.isEmpty
                ? 'No records found for this scope.'
                : dataset.rows.take(5).map(_summarizeRow).join('\n'),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  String _summarizeRow(Map<String, dynamic> row) {
    final label =
        row['name'] ??
        row['title'] ??
        row['code'] ??
        row['document_type'] ??
        row['report_type'] ??
        row['status'] ??
        row['id'] ??
        'record';
    final parts = <String>[
      '#${row['id'] ?? '-'}',
      label.toString(),
      if (row['status'] != null) 'status=${row['status']}',
      if (row['amount'] != null) 'amount=${row['amount']}',
      if (row['total_amount'] != null) 'total=${row['total_amount']}',
      if (row['net_amount'] != null) 'net=${row['net_amount']}',
      if (row['station_id'] != null) 'station=${row['station_id']}',
    ];
    return parts.join(' | ');
  }
}

class _OverviewDataset {
  const _OverviewDataset({required this.title, required this.rows});

  final String title;
  final List<Map<String, dynamic>> rows;
}

class _UserManagementPanel extends StatefulWidget {
  const _UserManagementPanel({required this.sessionController});

  final TenantSessionController sessionController;

  @override
  State<_UserManagementPanel> createState() => _UserManagementPanelState();
}

class _UserManagementPanelState extends State<_UserManagementPanel> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController(text: 'worker123');
  final _salaryController = TextEditingController(text: '0');

  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _users = const [];
  Map<String, dynamic>? _selectedRole;
  bool _payrollEnabled = true;
  bool _isActive = true;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _editingUser;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final roles = await widget.sessionController.loadRoles();
      final users = await widget.sessionController.loadUsers();
      final allowedRoleNames = widget.sessionController.creatableRoles.toSet();
      final workerRoles = roles.where((role) {
        final roleName = role['name'] as String? ?? '';
        if (!allowedRoleNames.contains(roleName)) return false;
        if (roleName == 'StationAdmin') {
          return widget.sessionController.isMultiStationTenant;
        }
        return true;
      }).toList();
      setState(() {
        _roles = workerRoles;
        _users = users;
        _selectedRole = _selectedRole == null
            ? (workerRoles.isEmpty ? null : workerRoles.first)
            : workerRoles.firstWhere(
                (role) => role['id'] == _selectedRole?['id'],
                orElse: () => workerRoles.isEmpty ? {} : workerRoles.first,
              );
        if (_selectedRole?.isEmpty ?? false) {
          _selectedRole = null;
        }
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not load users: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createWorker() async {
    final selectedRole = _selectedRole;
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0;
    if (selectedRole == null) {
      setState(() => _error = 'Choose a worker role first.');
      return;
    }
    if (_fullNameController.text.trim().isEmpty ||
        _usernameController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      setState(
        () => _error = 'Full name, username, and password are required.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.createWorkerUser(
        fullName: _fullNameController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        role: selectedRole,
        monthlySalary: salary,
        payrollEnabled: _payrollEnabled,
      );
      _fullNameController.clear();
      _usernameController.clear();
      _passwordController.text = 'worker123';
      _salaryController.text = '0';
      await _load();
      setState(() {
        _message =
            'Created ${selectedRole['name']} for ${widget.sessionController.workingStationLabel}.';
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not create worker: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveWorker() async {
    if (_editingUser == null) {
      await _createWorker();
      return;
    }
    final selectedRole = _selectedRole;
    final userId = _editingUser?['id'] as int?;
    final salary = double.tryParse(_salaryController.text.trim()) ?? 0;
    if (userId == null || selectedRole == null) {
      setState(() => _error = 'Choose a worker user and role first.');
      return;
    }
    if (_fullNameController.text.trim().isEmpty) {
      setState(() => _error = 'Full name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.updateWorkerUser(
        userId: userId,
        fullName: _fullNameController.text.trim(),
        role: selectedRole,
        monthlySalary: salary,
        payrollEnabled: _payrollEnabled,
        isActive: _isActive,
      );
      _clearForm();
      await _load();
      setState(() {
        _message = 'Updated worker user.';
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not update worker: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteWorker(Map<String, dynamic> user) async {
    final userId = user['id'] as int?;
    if (userId == null) {
      setState(() => _error = 'Selected user is missing an ID.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete worker?'),
        content: Text(
          'Delete ${user['username']}? This should only be used for test users or accounts with no operational history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.deleteWorkerUser(userId);
      if (_editingUser?['id'] == userId) {
        _clearForm();
      }
      await _load();
      setState(() => _message = 'Deleted worker user.');
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not delete worker: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _editWorker(Map<String, dynamic> user) {
    final role = _roles.firstWhere(
      (role) => role['id'] == user['role_id'],
      orElse: () => _roles.isEmpty ? {} : _roles.first,
    );
    if (role.isEmpty) {
      setState(() => _error = 'This user role is not editable from this flow.');
      return;
    }
    setState(() {
      _editingUser = user;
      _selectedRole = role;
      _fullNameController.text = user['full_name'] as String? ?? '';
      _usernameController.text = user['username'] as String? ?? '';
      _passwordController.clear();
      _salaryController.text = (user['monthly_salary'] ?? 0).toString();
      _payrollEnabled = user['payroll_enabled'] as bool? ?? true;
      _isActive = user['is_active'] as bool? ?? true;
      _error = null;
      _message = null;
    });
  }

  void _clearForm() {
    setState(() {
      _editingUser = null;
      _fullNameController.clear();
      _usernameController.clear();
      _passwordController.text = 'worker123';
      _salaryController.text = '0';
      _payrollEnabled = true;
      _isActive = true;
      _selectedRole = _roles.isEmpty ? null : _roles.first;
    });
  }

  String _roleNameFor(Map<String, dynamic> user) {
    final roleId = user['role_id'];
    final role = _roles.firstWhere(
      (role) => role['id'] == roleId,
      orElse: () => const <String, dynamic>{},
    );
    return role['name'] as String? ?? 'Role $roleId';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _editingUser == null
                  ? 'Create Worker Login'
                  : 'Edit Worker Login',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.sessionController.isSingleStationTenant
                  ? 'Single-station tenant rule: HeadOffice acts as station admin, so StationAdmin is hidden. New workers will be assigned to ${widget.sessionController.workingStationLabel}.'
                  : 'Multi-station tenant rule: StationAdmin is available. Select/create users only for the working station once station assignment UI is added.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _usernameController,
                    enabled: _editingUser == null,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _passwordController,
                    enabled: _editingUser == null,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final role in _roles)
                        DropdownMenuItem(
                          value: role,
                          child: Text(role['name'] as String? ?? 'Role'),
                        ),
                    ],
                    onChanged: (role) => setState(() => _selectedRole = role),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextField(
                    controller: _salaryController,
                    decoration: const InputDecoration(
                      labelText: 'Monthly salary',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Payroll enabled'),
                    value: _payrollEnabled,
                    onChanged: (value) {
                      setState(() => _payrollEnabled = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() => _isActive = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving ? null : _saveWorker,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editingUser == null
                              ? Icons.person_add_alt_outlined
                              : Icons.save_outlined,
                        ),
                  label: Text(
                    _isSaving
                        ? 'Saving...'
                        : (_editingUser == null
                              ? 'Create Worker'
                              : 'Update Worker'),
                  ),
                ),
                if (_editingUser != null)
                  OutlinedButton.icon(
                    onPressed: _isSaving ? null : _clearForm,
                    icon: const Icon(Icons.close_outlined),
                    label: const Text('Cancel Edit'),
                  ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Tenant Users',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_users.isEmpty)
              const Text('No users found for this tenant.')
            else
              for (final user in _users)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(user['full_name'] as String? ?? '-'),
                  subtitle: Text(
                    '${user['username']} - ${_roleNameFor(user)} - scope ${user['scope_level']} - station ${user['station_id'] ?? 'org'}',
                  ),
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      (user['is_active'] as bool? ?? false)
                          ? const Chip(label: Text('Active'))
                          : const Chip(label: Text('Inactive')),
                      IconButton(
                        tooltip: 'Edit worker',
                        onPressed: _isSaving ? null : () => _editWorker(user),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete worker',
                        onPressed: _isSaving ? null : () => _deleteWorker(user),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SetupFoundationPanel extends StatefulWidget {
  const _SetupFoundationPanel({
    required this.sessionController,
    required this.workspaceId,
  });

  final TenantSessionController sessionController;
  final String workspaceId;

  @override
  State<_SetupFoundationPanel> createState() => _SetupFoundationPanelState();
}

class _SetupFoundationPanelState extends State<_SetupFoundationPanel> {
  Map<String, dynamic>? _organizationSetup;
  Map<String, dynamic>? _stationSetup;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final organizationSetup = await widget.sessionController
          .loadOrganizationSetupFoundation();
      final stationSetup = await widget.sessionController
          .loadStationSetupFoundation();
      setState(() {
        _organizationSetup = organizationSetup;
        _stationSetup = stationSetup;
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not load setup data: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }
    if (_error != null) {
      return _StatusCard(
        title: 'Setup data error',
        message: _error!,
        isError: true,
      );
    }

    final organizationSetup = _organizationSetup ?? const <String, dynamic>{};
    final stationSetup = _stationSetup ?? const <String, dynamic>{};
    final tanks = _list(stationSetup['tanks']);
    final dispensers = _list(stationSetup['dispensers']);
    final fuelTypes = _list(stationSetup['fuel_types']);
    final stationRows = _list(organizationSetup['stations']);
    final nozzleCount = stationSetup['nozzle_count'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              label: 'Organization',
              value:
                  '${organizationSetup['organization_name'] ?? '-'} (${organizationSetup['organization_code'] ?? '-'})',
            ),
            _SummaryTile(
              label: 'Legal name',
              value: organizationSetup['legal_name']?.toString() ?? '-',
            ),
            _SummaryTile(
              label: 'Brand',
              value: _nestedText(
                organizationSetup['resolved_branding'],
                'brand_name',
              ),
            ),
            _SummaryTile(
              label: 'Stations',
              value: stationRows.length.toString(),
            ),
            _SummaryTile(label: 'Tanks', value: tanks.length.toString()),
            _SummaryTile(
              label: 'Dispensers',
              value: dispensers.length.toString(),
            ),
            _SummaryTile(label: 'Nozzles', value: nozzleCount.toString()),
            _SummaryTile(
              label: 'Fuel types',
              value: fuelTypes.length.toString(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (widget.workspaceId == 'tenant_setup') ...[
          _DataCard(
            title: 'Organization Setup',
            rows: [
              _DataRowText('ID', organizationSetup['organization_id']),
              _DataRowText('Name', organizationSetup['organization_name']),
              _DataRowText('Code', organizationSetup['organization_code']),
              _DataRowText('Legal name', organizationSetup['legal_name']),
              _DataRowText(
                'Onboarding',
                organizationSetup['onboarding_status'],
              ),
              _DataRowText(
                'Target station count',
                organizationSetup['station_target_count'],
              ),
              _DataRowText(
                'Branding inherited to stations',
                organizationSetup['inherit_branding_to_stations'],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SimpleListCard(
            title: 'Stations In This Tenant',
            emptyText: 'No stations found.',
            items: [
              for (final station in stationRows)
                '${station['name']} (${station['code']}) - ${station['setup_status']}',
            ],
          ),
        ] else ...[
          _DataCard(
            title: 'Station Setup',
            rows: [
              _DataRowText('ID', stationSetup['station_id']),
              _DataRowText('Name', stationSetup['station_name']),
              _DataRowText('Code', stationSetup['station_code']),
              _DataRowText('Setup status', stationSetup['setup_status']),
              _DataRowText(
                'Resolved legal name',
                stationSetup['resolved_legal_name'],
              ),
              _DataRowText(
                'Invoice business',
                _nestedText(stationSetup['invoice_identity'], 'business_name'),
              ),
              _DataRowText(
                'Invoice legal',
                _nestedText(stationSetup['invoice_identity'], 'legal_name'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SimpleListCard(
            title: 'Fuel Types',
            emptyText: 'No fuel types found.',
            items: [
              for (final fuelType in fuelTypes)
                '${fuelType['name']} - ID ${fuelType['id']}',
            ],
          ),
          const SizedBox(height: 12),
          _SimpleListCard(
            title: 'Tanks',
            emptyText: 'No tanks found.',
            items: [
              for (final tank in tanks)
                '${tank['name']} (${tank['code']}) - fuel ${tank['fuel_type_id']} - volume ${tank['current_volume']} / ${tank['capacity']}',
            ],
          ),
          const SizedBox(height: 12),
          _SimpleListCard(
            title: 'Dispensers And Nozzles',
            emptyText: 'No dispensers found.',
            items: [
              for (final dispenser in dispensers)
                '${dispenser['name']} (${dispenser['code']}) - ${_list(dispenser['nozzles']).length} nozzles',
            ],
          ),
        ],
        const SizedBox(height: 12),
        _StatusCard(
          title: 'Phase 9 rule',
          message:
              'This packet is read-only on purpose. We first prove tenant setup data is scoped correctly, then add edit/delete setup actions intentionally.',
        ),
      ],
    );
  }

  static List<dynamic> _list(Object? value) {
    return value is List ? value : const [];
  }

  static String _nestedText(Object? value, String key) {
    if (value is Map<String, dynamic>) {
      return value[key]?.toString() ?? '-';
    }
    if (value is Map) {
      return value[key]?.toString() ?? '-';
    }
    return '-';
  }
}

class _DataRowText {
  const _DataRowText(this.label, this.value);

  final String label;
  final Object? value;
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.title, required this.rows});

  final String title;
  final List<_DataRowText> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(
                        row.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Expanded(child: Text(row.value?.toString() ?? '-')),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SimpleListCard extends StatelessWidget {
  const _SimpleListCard({
    required this.title,
    required this.emptyText,
    required this.items,
  });

  final String title;
  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Text(emptyText)
            else
              for (final item in items)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(item),
                ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.message,
    this.isError = false,
  });

  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer;
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );
  }
}

class _ManagerOperationsPanel extends StatefulWidget {
  const _ManagerOperationsPanel({
    required this.sessionController,
    required this.workspaceId,
  });

  final TenantSessionController sessionController;
  final String workspaceId;

  @override
  State<_ManagerOperationsPanel> createState() =>
      _ManagerOperationsPanelState();
}

class _ManagerOperationsPanelState extends State<_ManagerOperationsPanel> {
  final _cashController = TextEditingController(text: '0');
  final _notesController = TextEditingController();
  final _expenseTitleController = TextEditingController(text: 'Test expense');
  final _expenseCategoryController = TextEditingController(text: 'general');
  final _expenseAmountController = TextEditingController(text: '100');
  final _dipMmController = TextEditingController(text: '100');
  final _dipVolumeController = TextEditingController(text: '1000');
  final _purchaseQtyController = TextEditingController(text: '100');
  final _purchaseRateController = TextEditingController(text: '250');
  final _purchaseRefController = TextEditingController();

  Map<String, dynamic>? _stationSetup;
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _suppliers = const [];
  int? _selectedTankId;
  int? _selectedSupplierId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _notesController.dispose();
    _expenseTitleController.dispose();
    _expenseCategoryController.dispose();
    _expenseAmountController.dispose();
    _dipMmController.dispose();
    _dipVolumeController.dispose();
    _purchaseQtyController.dispose();
    _purchaseRateController.dispose();
    _purchaseRefController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final stationSetup = await widget.sessionController
          .loadStationSetupFoundation();
      final rows = switch (widget.workspaceId) {
        'shifts' => await widget.sessionController.loadShifts(),
        'fuel_sales' ||
        'sales_review' => await widget.sessionController.loadFuelSales(),
        'cash' => await widget.sessionController.loadShifts(),
        'purchases' => await widget.sessionController.loadPurchases(),
        'expenses' => await widget.sessionController.loadExpenses(),
        'inventory_dips' => await widget.sessionController.loadTankDips(),
        _ => const <Map<String, dynamic>>[],
      };
      final suppliers = widget.workspaceId == 'purchases'
          ? await widget.sessionController.loadSuppliers()
          : const <Map<String, dynamic>>[];
      final tanks = _list(stationSetup['tanks']);
      setState(() {
        _stationSetup = stationSetup;
        _rows = rows;
        _suppliers = suppliers;
        _selectedTankId ??= tanks.isEmpty
            ? null
            : (tanks.first as Map)['id'] as int?;
        _selectedSupplierId ??= suppliers.isEmpty
            ? null
            : suppliers.first['id'] as int?;
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not load manager data: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      switch (widget.workspaceId) {
        case 'shifts':
          await widget.sessionController.openShift(
            initialCash: double.tryParse(_cashController.text.trim()) ?? 0,
            notes: _notesController.text,
          );
          _message = 'Opened shift.';
        case 'cash':
          final openShift = _firstOpenShift();
          if (openShift == null) {
            throw TenantApiException(
              'No open station shift is visible for cash submission.',
            );
          }
          await widget.sessionController.createCashSubmission(
            shiftId: openShift['id'] as int,
            amount: double.tryParse(_cashController.text.trim()) ?? 0,
            notes: _notesController.text,
          );
          _message = 'Recorded cash submission.';
        case 'fuel_sales' || 'sales_review':
          throw TenantApiException('Sales review is read-only in this packet.');
        case 'expenses':
          await widget.sessionController.createExpense(
            title: _expenseTitleController.text.trim(),
            category: _expenseCategoryController.text.trim(),
            amount: double.tryParse(_expenseAmountController.text.trim()) ?? 0,
            notes: _notesController.text,
          );
          _message = 'Created expense.';
        case 'inventory_dips':
          final tank = _selectedTank(_currentTanks());
          if (tank == null) throw TenantApiException('Choose a tank first.');
          await widget.sessionController.createTankDip(
            tankId: tank['id'] as int,
            dipReadingMm: double.tryParse(_dipMmController.text.trim()) ?? 0,
            calculatedVolume:
                double.tryParse(_dipVolumeController.text.trim()) ?? 0,
            notes: _notesController.text,
          );
          _message = 'Recorded tank dip.';
        case 'purchases':
          await _ensureSupplier();
          final tank = _selectedTank(_currentTanks());
          final supplier = _selectedSupplier();
          if (tank == null) throw TenantApiException('Choose a tank first.');
          if (supplier == null) {
            throw TenantApiException('Choose or create a supplier first.');
          }
          await widget.sessionController.createPurchase(
            supplierId: supplier['id'] as int,
            tankId: tank['id'] as int,
            fuelTypeId: tank['fuel_type_id'] as int,
            quantity: double.tryParse(_purchaseQtyController.text.trim()) ?? 0,
            ratePerLiter:
                double.tryParse(_purchaseRateController.text.trim()) ?? 0,
            referenceNo: _purchaseRefController.text,
            notes: _notesController.text,
          );
          _message = 'Created purchase.';
      }
      await _load();
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not save manager action: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _ensureSupplier() async {
    if (_selectedSupplierId != null) return;
    final code = 'PHASE9-${DateTime.now().millisecondsSinceEpoch}';
    final supplier = await widget.sessionController.createSupplier(
      name: 'Phase 9 Test Supplier',
      code: code,
    );
    _selectedSupplierId = supplier['id'] as int?;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }
    final stationSetup = _stationSetup ?? const <String, dynamic>{};
    final tanks = [
      for (final tank in _list(stationSetup['tanks']))
        Map<String, dynamic>.from(tank as Map),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager Action Packet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Station: ${widget.sessionController.workingStationLabel}. These are real API-backed Manager actions.',
            ),
            if (widget.workspaceId == 'cash') ...[
              const SizedBox(height: 8),
              Text(
                _firstOpenShift() == null
                    ? 'No open station shift found. Open an operator or manager shift first.'
                    : 'Cash target shift: ${_firstOpenShift()?['id']} owned by user ${_firstOpenShift()?['user_id']} with expected cash ${_firstOpenShift()?['expected_cash']}.',
              ),
            ],
            const SizedBox(height: 16),
            _buildActionForm(tanks),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_isSaving ? 'Saving...' : _buttonLabel()),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            _SimpleListCard(
              title: _listTitle(),
              emptyText: 'No records yet.',
              items: _rows.map(_describeRow).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionForm(List<Map<String, dynamic>> tanks) {
    final fields = <Widget>[];
    if (widget.workspaceId == 'shifts') {
      fields.addAll([
        _field(_cashController, 'Initial cash'),
        _field(_notesController, 'Notes'),
      ]);
    } else if (widget.workspaceId == 'cash') {
      fields.addAll([
        _field(_cashController, 'Cash submission amount'),
        _field(_notesController, 'Notes'),
      ]);
    } else if (widget.workspaceId == 'fuel_sales' ||
        widget.workspaceId == 'sales_review') {
      fields.add(
        const _StatusCard(
          title: 'Read-only sales review',
          message:
              'Operator records meter sales. Manager reviews station sales here.',
        ),
      );
    } else if (widget.workspaceId == 'expenses') {
      fields.addAll([
        _field(_expenseTitleController, 'Title'),
        _field(_expenseCategoryController, 'Category'),
        _field(_expenseAmountController, 'Amount'),
        _field(_notesController, 'Notes'),
      ]);
    } else if (widget.workspaceId == 'inventory_dips') {
      fields.addAll([
        _tankDropdown(tanks),
        _field(_dipMmController, 'Dip reading mm'),
        _field(_dipVolumeController, 'Calculated volume'),
        _field(_notesController, 'Notes'),
      ]);
    } else if (widget.workspaceId == 'purchases') {
      fields.addAll([
        _supplierDropdown(),
        _tankDropdown(tanks),
        _field(_purchaseQtyController, 'Quantity'),
        _field(_purchaseRateController, 'Rate per liter'),
        _field(_purchaseRefController, 'Reference'),
        _field(_notesController, 'Notes'),
      ]);
    }
    return Wrap(spacing: 12, runSpacing: 12, children: fields);
  }

  Widget _field(TextEditingController controller, String label) {
    return SizedBox(
      width: 260,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _tankDropdown(List<Map<String, dynamic>> tanks) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedTankId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Tank',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final tank in tanks)
            DropdownMenuItem(
              value: tank['id'] as int?,
              child: Text(
                '${tank['name']} (${tank['code']})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (tankId) => setState(() => _selectedTankId = tankId),
      ),
    );
  }

  Widget _supplierDropdown() {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<int>(
        initialValue: _selectedSupplierId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Supplier',
          helperText: 'Auto-creates test supplier if empty',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final supplier in _suppliers)
            DropdownMenuItem(
              value: supplier['id'] as int?,
              child: Text(
                '${supplier['name']} (${supplier['code']})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (supplierId) {
          setState(() => _selectedSupplierId = supplierId);
        },
      ),
    );
  }

  List<Map<String, dynamic>> _currentTanks() {
    final stationSetup = _stationSetup ?? const <String, dynamic>{};
    return [
      for (final tank in _list(stationSetup['tanks']))
        Map<String, dynamic>.from(tank as Map),
    ];
  }

  Map<String, dynamic>? _selectedTank(List<Map<String, dynamic>> tanks) {
    for (final tank in tanks) {
      if (tank['id'] == _selectedTankId) return tank;
    }
    return null;
  }

  Map<String, dynamic>? _selectedSupplier() {
    for (final supplier in _suppliers) {
      if (supplier['id'] == _selectedSupplierId) return supplier;
    }
    return null;
  }

  String _buttonLabel() => switch (widget.workspaceId) {
    'shifts' => 'Open Shift',
    'cash' => 'Submit Cash',
    'fuel_sales' || 'sales_review' => 'Read-only',
    'expenses' => 'Create Expense',
    'inventory_dips' => 'Record Dip',
    'purchases' => 'Create Purchase',
    _ => 'Save',
  };

  String _listTitle() => switch (widget.workspaceId) {
    'shifts' => 'Recent Shifts',
    'cash' => 'Open And Recent Shifts',
    'fuel_sales' || 'sales_review' => 'Recent Fuel Sales',
    'expenses' => 'Recent Expenses',
    'inventory_dips' => 'Recent Tank Dips',
    'purchases' => 'Recent Purchases',
    _ => 'Recent Records',
  };

  String _describeRow(Map<String, dynamic> row) => switch (widget.workspaceId) {
    'shifts' =>
      'Shift ${row['id']} - ${row['status']} - opening ${row['initial_cash']} - expected ${row['expected_cash']}',
    'cash' =>
      'Shift ${row['id']} - ${row['status']} - expected ${row['expected_cash']} - actual ${row['actual_cash_collected'] ?? '-'}',
    'fuel_sales' || 'sales_review' =>
      'Sale ${row['id']} - nozzle ${row['nozzle_id']} - ${row['quantity']} L - total ${row['total_amount']} - shift ${row['shift_id'] ?? '-'}',
    'expenses' =>
      'Expense ${row['id']} - ${row['title']} - ${row['amount']} - ${row['status']}',
    'inventory_dips' =>
      'Dip ${row['id']} - tank ${row['tank_id']} - physical ${row['calculated_volume']} - system ${row['system_volume']} - diff ${row['loss_gain']}',
    'purchases' =>
      'Purchase ${row['id']} - tank ${row['tank_id']} - qty ${row['quantity']} - total ${row['total_amount']} - ${row['status']}',
    _ => row.toString(),
  };

  static List<dynamic> _list(Object? value) => value is List ? value : const [];

  Map<String, dynamic>? _firstOpenShift() {
    for (final shift in _rows) {
      if (shift['status'] == 'open') {
        return shift;
      }
    }
    return null;
  }
}

class _OperatorShiftPanel extends StatefulWidget {
  const _OperatorShiftPanel({required this.sessionController});

  final TenantSessionController sessionController;

  @override
  State<_OperatorShiftPanel> createState() => _OperatorShiftPanelState();
}

class _OperatorShiftPanelState extends State<_OperatorShiftPanel> {
  final _cashController = TextEditingController(text: '0');
  final _actualCashController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _shifts = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _actualCashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final shifts = await widget.sessionController.loadShifts();
      setState(() {
        _shifts = shifts;
        final openShift = _openShift;
        if (openShift != null) {
          _actualCashController.text = '${openShift['expected_cash'] ?? 0}';
        }
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not load operator shifts: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _open() async {
    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.openShift(
        initialCash: double.tryParse(_cashController.text.trim()) ?? 0,
        notes: _notesController.text,
      );
      await _load();
      setState(() => _message = 'Opened operator shift.');
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not open shift: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _close() async {
    final openShift = _openShift;
    if (openShift == null) {
      setState(() => _error = 'No open operator shift to close.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.closeShift(
        shiftId: openShift['id'] as int,
        actualCashCollected:
            double.tryParse(_actualCashController.text.trim()) ?? 0,
        notes: _notesController.text,
      );
      await _load();
      setState(() => _message = 'Closed operator shift.');
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not close shift: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }
    final openShift = _openShift;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator Shift',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              openShift == null
                  ? 'No open operator shift. Open this before recording fuel sales so sales attach to the shift.'
                  : 'Open shift ${openShift['id']} with expected cash ${openShift['expected_cash']}.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _field(_cashController, 'Opening cash'),
                _field(_actualCashController, 'Actual closing cash'),
                _field(_notesController, 'Notes'),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _isSaving || openShift != null ? null : _open,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Open Shift'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _isSaving || openShift == null ? null : _close,
                  icon: const Icon(Icons.stop_outlined),
                  label: const Text('Close Shift'),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            _SimpleListCard(
              title: 'Recent Operator Shifts',
              emptyText: 'No shifts yet.',
              items: [
                for (final shift in _shifts)
                  'Shift ${shift['id']} - ${shift['status']} - opening ${shift['initial_cash']} - expected ${shift['expected_cash']} - actual ${shift['actual_cash_collected'] ?? '-'}',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Map<String, dynamic>? get _openShift {
    for (final shift in _shifts) {
      if (shift['status'] == 'open' &&
          shift['user_id'] == widget.sessionController.currentUserId) {
        return shift;
      }
    }
    return null;
  }
}

class _OperatorFuelSalePanel extends StatefulWidget {
  const _OperatorFuelSalePanel({required this.sessionController});

  final TenantSessionController sessionController;

  @override
  State<_OperatorFuelSalePanel> createState() => _OperatorFuelSalePanelState();
}

class _OperatorFuelSalePanelState extends State<_OperatorFuelSalePanel> {
  final _closingMeterController = TextEditingController();
  final _rateController = TextEditingController(text: '250');

  Map<String, dynamic>? _stationSetup;
  Map<String, dynamic>? _openShift;
  List<Map<String, dynamic>> _sales = const [];
  int? _selectedNozzleId;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _message;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _closingMeterController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _message = null;
    });
    try {
      final stationSetup = await widget.sessionController
          .loadStationSetupFoundation();
      final openShift = await widget.sessionController
          .loadOpenShiftForCurrentUser();
      final sales = await widget.sessionController.loadFuelSales(
        shiftId: openShift?['id'] as int?,
      );
      final nozzles = _nozzlesFrom(stationSetup);
      setState(() {
        _stationSetup = stationSetup;
        _openShift = openShift;
        _sales = sales;
        _selectedNozzleId ??= nozzles.isEmpty
            ? null
            : nozzles.first['id'] as int?;
        final selectedNozzle = _selectedNozzle(nozzles);
        if (selectedNozzle != null && _closingMeterController.text.isEmpty) {
          final meter =
              double.tryParse('${selectedNozzle['meter_reading']}') ?? 0;
          _closingMeterController.text = (meter + 1).toStringAsFixed(2);
        }
      });
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not load fuel sale data: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSale() async {
    final nozzles = _nozzlesFrom(_stationSetup ?? const <String, dynamic>{});
    final nozzle = _selectedNozzle(nozzles);
    if (nozzle == null) {
      setState(() => _error = 'Choose a nozzle first.');
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.sessionController.createFuelSale(
        nozzleId: nozzle['id'] as int,
        fuelTypeId: nozzle['fuel_type_id'] as int,
        closingMeter: double.tryParse(_closingMeterController.text.trim()) ?? 0,
        ratePerLiter: double.tryParse(_rateController.text.trim()) ?? 0,
        shiftId: _openShift?['id'] as int?,
      );
      _closingMeterController.clear();
      await _load();
      setState(() => _message = 'Recorded meter-based cash fuel sale.');
    } on TenantApiException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = 'Could not record fuel sale: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
      );
    }
    final stationSetup = _stationSetup ?? const <String, dynamic>{};
    final nozzles = _nozzlesFrom(stationSetup);
    final selectedNozzle = _selectedNozzle(nozzles);
    final openingMeter = selectedNozzle == null
        ? '-'
        : '${selectedNozzle['meter_reading']}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Operator Meter Fuel Sale',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _openShift == null
                  ? 'No open operator shift found. The backend can still record a sale, but the docs prefer opening a shift first.'
                  : 'Open shift: ${_openShift?['id']} at ${widget.sessionController.workingStationLabel}.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedNozzleId,
                    decoration: const InputDecoration(
                      labelText: 'Nozzle',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final nozzle in nozzles)
                        DropdownMenuItem(
                          value: nozzle['id'] as int?,
                          child: Text(
                            '${nozzle['name']} (${nozzle['code']}) - meter ${nozzle['meter_reading']}',
                          ),
                        ),
                    ],
                    onChanged: (nozzleId) {
                      setState(() {
                        _selectedNozzleId = nozzleId;
                        final nozzle = _selectedNozzle(nozzles);
                        if (nozzle != null) {
                          final meter =
                              double.tryParse('${nozzle['meter_reading']}') ??
                              0;
                          _closingMeterController.text = (meter + 1)
                              .toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                ),
                _readOnlyValue('Opening meter', openingMeter),
                _field(_closingMeterController, 'Closing meter'),
                _field(_rateController, 'Rate per liter'),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSaving ? null : _createSale,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.local_gas_station_outlined),
              label: Text(_isSaving ? 'Saving...' : 'Record Fuel Sale'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(
                _message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            _SimpleListCard(
              title: 'Recent Fuel Sales',
              emptyText: 'No fuel sales yet.',
              items: [
                for (final sale in _sales)
                  'Sale ${sale['id']} - nozzle ${sale['nozzle_id']} - ${sale['quantity']} L - total ${sale['total_amount']} - shift ${sale['shift_id'] ?? '-'}',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _readOnlyValue(String label, String value) {
    return SizedBox(
      width: 180,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value),
      ),
    );
  }

  List<Map<String, dynamic>> _nozzlesFrom(Map<String, dynamic> stationSetup) {
    final nozzles = <Map<String, dynamic>>[];
    final dispensers = stationSetup['dispensers'];
    if (dispensers is! List) return nozzles;
    for (final dispenser in dispensers) {
      if (dispenser is! Map) continue;
      final dispenserNozzles = dispenser['nozzles'];
      if (dispenserNozzles is! List) continue;
      for (final nozzle in dispenserNozzles) {
        if (nozzle is Map) {
          nozzles.add(Map<String, dynamic>.from(nozzle));
        }
      }
    }
    return nozzles;
  }

  Map<String, dynamic>? _selectedNozzle(List<Map<String, dynamic>> nozzles) {
    for (final nozzle in nozzles) {
      if (nozzle['id'] == _selectedNozzleId) return nozzle;
    }
    return null;
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
