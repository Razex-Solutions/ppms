import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/loading_screen.dart';
import '../../features/auth/login_screen.dart';
import '../shell/app_shell.dart';
import '../../features/common/forbidden_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/onboarding/station_setup_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/workspaces/workspace_screen.dart';
import '../session/session_controller.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionState = ref.watch(sessionControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final path = state.uri.path;
      final isLoading = path == '/loading';
      final isLogin = path == '/login';

      if (sessionState.isInitializing) {
        return isLoading ? null : '/loading';
      }

      if (!sessionState.isAuthenticated) {
        return isLogin ? null : '/login';
      }

      if (isLoading || isLogin) {
        return _defaultRouteForSession(sessionState.session?.role.backendName);
      }

      if (path == '/') {
        return _defaultRouteForSession(sessionState.session?.role.backendName);
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
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

String _defaultRouteForSession(String? roleName) {
  switch (roleName) {
    case 'Operator':
      return '/workspace/operator';
    case 'Manager':
      return '/workspace/manager';
    case 'Accountant':
      return '/workspace/accountant';
    case 'StationAdmin':
      return '/workspace/station-admin';
    case 'HeadOffice':
      return '/workspace/head-office';
    case 'MasterAdmin':
      return '/workspace/master-admin';
    default:
      return '/workspace/manager';
  }
}
