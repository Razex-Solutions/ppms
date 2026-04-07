import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ppms_tenant_flutter/main.dart';

void main() {
  Map<String, dynamic> tenantRoleMatrix() {
    final raw = File('../scripts/tenant_role_matrix.json').readAsStringSync();
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  test('workspace destinations are scoped by tenant role', () {
    final headOfficeIds = workspaceDestinationsForRole(
      'HeadOffice',
    ).map((workspace) => workspace.id);
    final operatorIds = workspaceDestinationsForRole(
      'Operator',
    ).map((workspace) => workspace.id);
    final accountantIds = workspaceDestinationsForRole(
      'Accountant',
    ).map((workspace) => workspace.id);

    expect(
      headOfficeIds,
      containsAll([
        'context',
        'tenant_setup',
        'users',
        'inventory',
        'tankers',
        'pos',
        'hardware',
        'reports',
      ]),
    );
    expect(headOfficeIds, isNot(contains('station_admin')));
    expect(
      operatorIds,
      containsAll(['context', 'shift', 'fuel_sale', 'tank_dips']),
    );
    expect(operatorIds, isNot(contains('users')));
    expect(
      accountantIds,
      containsAll(['finance', 'parties', 'payments', 'payroll', 'documents']),
    );
    expect(accountantIds, isNot(contains('fuel_sale')));
  });

  test('role matrix visible screens are present in navigation definitions', () {
    final matrix = tenantRoleMatrix();
    final roles = matrix['roles'] as Map<String, dynamic>;

    for (final entry in roles.entries) {
      final roleName = entry.key;
      final role = entry.value as Map<String, dynamic>;
      final screens = role['screens'] as Map<String, dynamic>;
      final destinationIds = workspaceDestinationsForRole(
        roleName,
      ).map((workspace) => workspace.id).toSet();

      for (final screenEntry in screens.entries) {
        final screen = screenEntry.value as Map<String, dynamic>;
        final isVisible = screen['visible'] == true ||
            screen.containsKey('visible_when_modules');
        if (isVisible) {
          expect(
            destinationIds,
            contains(screenEntry.key),
            reason: '$roleName is missing ${screenEntry.key}',
          );
        }
      }
    }
  });

  testWidgets('tenant login page renders', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PpmsTenantApp());
    await tester.pumpAndSettle();

    expect(find.text('PPMS Tenant Login'), findsOneWidget);
    expect(find.text('Backend URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Quick login'), findsOneWidget);
    expect(find.text('HeadOffice'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
    expect(find.text('Accountant'), findsOneWidget);
    expect(find.text('Operator'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('minimal tenant navigation hides disabled optional modules', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = TenantSessionController(_fakeTenantClient('HeadOffice'));
    await controller.signIn(
      baseUrl: 'http://example.test',
      username: 'p9_minimal',
      password: 'office123',
    );

    await tester.pumpWidget(
      MaterialApp(home: TenantHomePage(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    final workspaceIds = controller
        .workspacesForCurrentSession()
        .map((workspace) => workspace.id)
        .toSet();
    expect(workspaceIds, contains('tenant_setup'));
    expect(workspaceIds, contains('reports'));
    expect(workspaceIds, isNot(contains('tankers')));
    expect(workspaceIds, isNot(contains('pos')));
    expect(workspaceIds, isNot(contains('hardware')));
    expect(find.text('Tenant Setup'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('station admin navigation is scoped and module-aware', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = TenantSessionController(
      _fakeTenantClient('StationAdmin'),
    );
    await controller.signIn(
      baseUrl: 'http://example.test',
      username: 'p9_multi_station_a_admin',
      password: 'station123',
    );

    await tester.pumpWidget(
      MaterialApp(home: TenantHomePage(sessionController: controller)),
    );
    await tester.pumpAndSettle();

    final workspaceIds = controller
        .workspacesForCurrentSession()
        .map((workspace) => workspace.id)
        .toSet();
    expect(workspaceIds, contains('users'));
    expect(workspaceIds, contains('station_setup'));
    expect(workspaceIds, contains('tankers'));
    expect(workspaceIds, isNot(contains('tenant_setup')));
    expect(workspaceIds, isNot(contains('finance_overview')));
    expect(find.text('Users'), findsOneWidget);

    controller.dispose();
  });
}

TenantApiClient _fakeTenantClient(String roleName) {
  return TenantApiClient(
    httpClient: MockClient((request) async {
      final path = request.url.path;
      final query = request.url.query;
      if (path == '/auth/login') {
        return _jsonResponse({'access_token': 'token', 'token_type': 'bearer'});
      }
      if (path == '/auth/me') {
        return _jsonResponse(_fakeCurrentUser(roleName));
      }
      if (path == '/stations/') {
        final stations = roleName == 'HeadOffice'
            ? [
                {'id': 7, 'name': 'PHASE9-MINIMAL-A', 'code': 'P9-MIN-A'},
              ]
            : [
                {'id': 5, 'name': 'PHASE9-MULTI-A', 'code': 'P9-MULTI-A'},
              ];
        return _jsonResponse(stations);
      }
      if (path == '/station-modules/7') {
        return _jsonResponse([
          {'module_name': 'pos', 'is_enabled': false},
          {'module_name': 'mart', 'is_enabled': false},
          {'module_name': 'tanker_operations', 'is_enabled': false},
          {'module_name': 'hardware', 'is_enabled': false},
        ]);
      }
      if (path == '/station-modules/5') {
        return _jsonResponse([
          {'module_name': 'pos', 'is_enabled': true},
          {'module_name': 'mart', 'is_enabled': true},
          {'module_name': 'tanker_operations', 'is_enabled': true},
          {'module_name': 'hardware', 'is_enabled': false},
        ]);
      }
      return _jsonResponse(
        {'detail': 'Unhandled fake route $path?$query'},
        statusCode: 404,
      );
    }),
  );
}

Map<String, dynamic> _fakeCurrentUser(String roleName) {
  if (roleName == 'StationAdmin') {
    return {
      'id': 103,
      'username': 'p9_multi_station_a_admin',
      'role_name': 'StationAdmin',
      'scope_level': 'station',
      'organization_id': 5,
      'station_id': 5,
      'creatable_roles': ['Accountant', 'Manager', 'Operator'],
    };
  }
  return {
    'id': 120,
    'username': 'p9_minimal',
    'role_name': 'HeadOffice',
    'scope_level': 'organization',
    'organization_id': 6,
    'station_id': null,
    'creatable_roles': ['Accountant', 'Manager', 'Operator'],
  };
}

http.Response _jsonResponse(Object body, {int statusCode = 200}) {
  return http.Response(jsonEncode(body), statusCode, headers: {
    'content-type': 'application/json',
  });
}
