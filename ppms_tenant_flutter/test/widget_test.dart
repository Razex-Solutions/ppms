import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ppms_tenant_flutter/main.dart';

void main() {
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

  testWidgets('tenant login page renders', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const PpmsTenantApp());
    await tester.pumpAndSettle();

    expect(find.text('PPMS Tenant Login'), findsOneWidget);
    expect(find.text('Backend URL'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
