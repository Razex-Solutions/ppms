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

class TenantHomePage extends StatelessWidget {
  const TenantHomePage({super.key, required this.sessionController});

  final TenantSessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConfig.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppConfig.backgroundColor,
        title: const Text('PPMS Tenant'),
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Tenant Context',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'This is the first clean rebuild slice. No dashboards yet.',
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ContextChip(label: 'User', value: sessionController.username),
                _ContextChip(label: 'Role', value: sessionController.roleName),
                _ContextChip(
                  label: 'Scope',
                  value: sessionController.scopeLevel,
                ),
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
            _SectionCard(
              title: 'Allowed next roles',
              body: sessionController.creatableRoles.isEmpty
                  ? 'No role-creation capabilities returned for this session.'
                  : sessionController.creatableRoles.join(', '),
            ),
            const SizedBox(height: 12),
            const _SectionCard(
              title: 'Next slice',
              body:
                  'Add simple role-aware navigation, then HeadOffice worker creation for Manager, Accountant, and Operator.',
            ),
          ],
        ),
      ),
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
