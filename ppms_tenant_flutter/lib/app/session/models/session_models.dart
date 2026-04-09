import 'app_role.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
  });

  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
      };

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
    );
  }
}

class AppSession {
  const AppSession({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.role,
    required this.scopeLevel,
    required this.tokens,
    required this.permissions,
    required this.effectiveEnabledModules,
    required this.featureFlags,
    this.email,
    this.organizationId,
    this.stationId,
  });

  final int userId;
  final String username;
  final String fullName;
  final String? email;
  final AppRole role;
  final String scopeLevel;
  final int? organizationId;
  final int? stationId;
  final AuthTokens tokens;
  final Map<String, List<String>> permissions;
  final List<String> effectiveEnabledModules;
  final Map<String, bool> featureFlags;

  factory AppSession.fromAuthPayload({
    required Map<String, dynamic> tokenJson,
    required Map<String, dynamic> meJson,
  }) {
    final permissionsMap = <String, List<String>>{};
    final rawPermissions = (meJson['permissions'] as Map<String, dynamic>? ?? {});
    for (final entry in rawPermissions.entries) {
      permissionsMap[entry.key] =
          (entry.value as List<dynamic>).map((item) => '$item').toList();
    }

    final rawFeatureFlags =
        (meJson['feature_flags'] as Map<String, dynamic>? ?? {});
    final featureFlags = <String, bool>{};
    for (final entry in rawFeatureFlags.entries) {
      featureFlags[entry.key] = entry.value == true;
    }

    return AppSession(
      userId: meJson['id'] as int,
      username: meJson['username'] as String,
      fullName: meJson['full_name'] as String,
      email: meJson['email'] as String?,
      role: AppRole.fromBackend(meJson['role_name'] as String),
      scopeLevel: (meJson['scope_level'] as String?) ?? 'station',
      organizationId: meJson['organization_id'] as int?,
      stationId: meJson['station_id'] as int?,
      tokens: AuthTokens.fromJson(tokenJson),
      permissions: permissionsMap,
      effectiveEnabledModules:
          (meJson['effective_enabled_modules'] as List<dynamic>? ?? [])
              .map((item) => '$item')
              .toList(),
      featureFlags: featureFlags,
    );
  }
}
