import 'package:flutter_test/flutter_test.dart';

import 'package:ppms_tenant_flutter/main.dart';

void main() {
  testWidgets('tenant rebuild landing page renders', (tester) async {
    await tester.pumpWidget(const PpmsTenantApp());

    expect(find.text('PPMS Tenant App'), findsOneWidget);
    expect(find.text('Current slice'), findsOneWidget);
    expect(find.text('Rules'), findsOneWidget);
    expect(find.textContaining('HeadOffice'), findsWidgets);
  });
}
