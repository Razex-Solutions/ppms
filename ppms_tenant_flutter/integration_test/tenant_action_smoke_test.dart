import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ppms_tenant_flutter/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final matrix = _loadMatrix();

  for (final accountEntry in matrix.entries) {
    final accountKey = accountEntry.key;
    final account = accountEntry.value;
    testWidgets('Phase 9 tenant UI action smoke: $accountKey', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1920, 1400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const PpmsTenantApp());
      await tester.pumpAndSettle();

      await _login(
        tester,
        username: account.username,
        password: account.password,
      );

      for (final text in account.mustSee) {
        await _expectEventuallyVisible(
          tester,
          text,
          reason: '$accountKey should see $text after login',
        );
      }
      for (final text in account.mustNotSee) {
        expect(
          find.text(text),
          findsNothing,
          reason: '$accountKey should not see $text after login',
        );
      }

      for (final screenEntry in account.screens.entries) {
        await _openWorkspace(tester, screenEntry.key);
        for (final text in screenEntry.value.mustSee) {
          await _expectEventuallyVisible(
            tester,
            text,
            reason: '$accountKey ${screenEntry.key} should show $text',
          );
        }
        for (final buttonText in screenEntry.value.tapSafe) {
          await _tapText(tester, buttonText);
          await tester.pumpAndSettle(const Duration(seconds: 2));
          expect(
            find.textContaining('setState() called after dispose'),
            findsNothing,
            reason:
                '$accountKey ${screenEntry.key} must not crash after $buttonText',
          );
          expect(
            find.textContaining('Unhandled Exception'),
            findsNothing,
            reason:
                '$accountKey ${screenEntry.key} must not throw after $buttonText',
          );
        }
      }

      await _tapTooltip(tester, 'Sign out');
      await tester.pumpAndSettle();
      expect(find.text('PPMS Tenant Login'), findsOneWidget);
    });
  }
}

Map<String, _AccountFlow> _loadMatrix() {
  final raw = File(
    '../scripts/tenant_ui_action_matrix.json',
  ).readAsStringSync();
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final accounts = decoded['accounts'] as Map<String, dynamic>;
  return {
    for (final entry in accounts.entries)
      entry.key: _AccountFlow.fromJson(entry.value as Map<String, dynamic>),
  };
}

class _AccountFlow {
  const _AccountFlow({
    required this.username,
    required this.password,
    required this.mustSee,
    required this.mustNotSee,
    required this.screens,
  });

  factory _AccountFlow.fromJson(Map<String, dynamic> json) {
    final screensJson = json['screens'] as Map<String, dynamic>? ?? const {};
    return _AccountFlow(
      username: json['username'].toString(),
      password: json['password'].toString(),
      mustSee: _stringList(json['must_see']),
      mustNotSee: _stringList(json['must_not_see']),
      screens: {
        for (final entry in screensJson.entries)
          entry.key: _ScreenFlow.fromJson(entry.value as Map<String, dynamic>),
      },
    );
  }

  final String username;
  final String password;
  final List<String> mustSee;
  final List<String> mustNotSee;
  final Map<String, _ScreenFlow> screens;
}

class _ScreenFlow {
  const _ScreenFlow({required this.mustSee, required this.tapSafe});

  factory _ScreenFlow.fromJson(Map<String, dynamic> json) {
    return _ScreenFlow(
      mustSee: _stringList(json['must_see']),
      tapSafe: _stringList(json['tap_safe']),
    );
  }

  final List<String> mustSee;
  final List<String> tapSafe;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

Future<void> _login(
  WidgetTester tester, {
  required String username,
  required String password,
}) async {
  await tester.enterText(find.byType(EditableText).at(1), username);
  await tester.enterText(find.byType(EditableText).at(2), password);
  await _tapText(tester, 'Sign In');
  await tester.pumpAndSettle(const Duration(seconds: 3));
  await _expectEventuallyVisible(tester, 'PPMS Tenant -');
}

Future<void> _openWorkspace(WidgetTester tester, String label) async {
  await _tapText(tester, label);
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _makeTextVisible(tester, text);
  final exact = find.text(text);
  final containing = find.textContaining(text);
  final finder = exact.evaluate().isNotEmpty ? exact : containing;
  expect(finder, findsWidgets, reason: 'Expected to tap "$text"');
  await tester.tap(finder.last);
  await tester.pumpAndSettle();
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  await tester.tap(find.byTooltip(tooltip));
  await tester.pumpAndSettle();
}

Future<void> _expectEventuallyVisible(
  WidgetTester tester,
  String text, {
  String? reason,
}) async {
  await _makeTextVisible(tester, text);
  expect(find.textContaining(text), findsWidgets, reason: reason);
}

Future<void> _makeTextVisible(WidgetTester tester, String text) async {
  final exact = find.text(text);
  final containing = find.textContaining(text);
  if (exact.evaluate().isNotEmpty || containing.evaluate().isNotEmpty) {
    return;
  }
  final scrollables = find.byType(Scrollable);
  if (scrollables.evaluate().isEmpty) {
    return;
  }
  final scrollableCount = scrollables.evaluate().length;
  for (
    var scrollableIndex = 0;
    scrollableIndex < scrollableCount;
    scrollableIndex += 1
  ) {
    final scrollable = scrollables.at(scrollableIndex);
    for (var i = 0; i < 12; i += 1) {
      await tester.drag(scrollable, const Offset(0, -350));
      await tester.pumpAndSettle();
      if (exact.evaluate().isNotEmpty || containing.evaluate().isNotEmpty) {
        return;
      }
    }
  }
}
