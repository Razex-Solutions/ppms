import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'localization/app_localizations.dart';
import 'router/app_router.dart';
import 'session/session_controller.dart';
import 'theme/app_theme.dart';

class PpmsTenantApp extends ConsumerStatefulWidget {
  const PpmsTenantApp({super.key});

  @override
  ConsumerState<PpmsTenantApp> createState() => _PpmsTenantAppState();
}

class _PpmsTenantAppState extends ConsumerState<PpmsTenantApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(sessionControllerProvider.notifier).restoreSession(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(appLocaleProvider);
    final theme = buildAppTheme(locale);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'PPMS Tenant',
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme,
      routerConfig: router,
    );
  }
}
