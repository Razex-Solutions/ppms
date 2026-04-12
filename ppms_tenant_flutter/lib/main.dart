import 'package:flutter/widgets.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/app_environment.dart';

// Kept alive for the lifetime of the app so Flutter web exposes semantics in E2E mode.
SemanticsHandle? e2eSemanticsHandle;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppEnvironment.enableE2E) {
    e2eSemanticsHandle = WidgetsBinding.instance.ensureSemantics();
  }
  runApp(const ProviderScope(child: PpmsTenantApp()));
}
