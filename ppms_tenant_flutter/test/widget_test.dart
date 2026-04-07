import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ppms_tenant_flutter/main.dart';

void main() {
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
