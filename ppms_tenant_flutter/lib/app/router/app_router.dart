import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shell/app_shell.dart';
import '../../features/common/forbidden_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/station_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/workspaces/workspace_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/forbidden',
        builder: (context, state) => const ForbiddenScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const AppShell(child: WorkspaceScreen()),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const AppShell(child: ProfileScreen()),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) =>
            const AppShell(child: NotificationsScreen()),
      ),
      GoRoute(
        path: '/workspace/:type',
        builder: (context, state) => AppShell(
          child: WorkspaceScreen(
            requestedType: state.pathParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: '/station-setup/:stationId',
        builder: (context, state) => AppShell(
          child: StationSetupScreen(
            stationId: int.parse(state.pathParameters['stationId']!),
          ),
        ),
      ),
    ],
  );
});
