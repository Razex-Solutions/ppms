import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/loading_screen.dart';
import '../features/auth/login_screen.dart';
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
    final sessionState = ref.watch(sessionControllerProvider);
    final locale = ref.watch(appLocaleProvider);
    final theme = buildAppTheme(locale);

    if (sessionState.isInitializing) {
      return MaterialApp(
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
        home: const LoadingScreen(),
      );
    }

    if (!sessionState.isAuthenticated) {
      return MaterialApp(
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
        home: const LoginScreen(),
      );
    }

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
