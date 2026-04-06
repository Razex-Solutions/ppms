import 'package:ppms_flutter/core/session/session_controller.dart';

class SessionCapabilities {
  SessionCapabilities(this._session);

  static const Set<String> _readOnlyActions = {'read', 'read_meter_history'};

  final SessionController _session;

  bool get isPlatformUser => _session.isPlatformUser;
  bool get isTenantUser => !isPlatformUser;

  List<String> permissionActions(String module) {
    final actions = _session.permissions[module];
    if (actions is List) {
      return actions.whereType<String>().toList(growable: false);
    }
    return const [];
  }

  bool moduleEnabled(String module) =>
      _session.enabledModules.contains(module) ||
      _session.featureFlags[module] == true;

  bool hasPermission(String module, [String? action]) {
    final actions = permissionActions(module);
    if (action == null) {
      return actions.isNotEmpty;
    }
    return actions.contains(action);
  }

  bool hasAnyPermission(Iterable<String> modules, {Iterable<String>? actions}) {
    for (final module in modules) {
      final moduleActions = permissionActions(module);
      if (moduleActions.isEmpty) {
        continue;
      }
      if (actions == null) {
        return true;
      }
      if (actions.any(moduleActions.contains)) {
        return true;
      }
    }
    return false;
  }

  bool hasAnyEnabledModule(Iterable<String> modules) {
    for (final module in modules) {
      if (moduleEnabled(module)) {
        return true;
      }
    }
    return false;
  }

  bool hasAllEnabledModules(Iterable<String> modules) {
    for (final module in modules) {
      if (!moduleEnabled(module)) {
        return false;
      }
    }
    return true;
  }

  bool featureVisible({
    required bool platformFeature,
    List<String> modules = const [],
    List<String> requiredModules = const [],
    List<String> permissionModules = const [],
    Iterable<String>? permissionActions,
    bool hideWhenModulesOff = false,
  }) {
    if (platformFeature != isPlatformUser) {
      return false;
    }

    if (hideWhenModulesOff &&
        modules.isNotEmpty &&
        !hasAnyEnabledModule(modules)) {
      return false;
    }

    if (requiredModules.isNotEmpty && !hasAllEnabledModules(requiredModules)) {
      return false;
    }

    if (permissionModules.isEmpty) {
      return true;
    }

    return hasAnyPermission(permissionModules, actions: permissionActions);
  }

  bool featureReadOnly(List<String> permissionModules) {
    if (!hasAnyPermission(permissionModules)) {
      return false;
    }
    for (final module in permissionModules) {
      final actions = permissionActions(module);
      if (actions.any((action) => !_readOnlyActions.contains(action))) {
        return false;
      }
    }
    return true;
  }
}
