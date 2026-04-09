import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'models/session_models.dart';
import 'session_repository.dart';

class SessionState {
  const SessionState({
    this.isInitializing = true,
    this.isSubmitting = false,
    this.errorMessage,
    this.session,
  });

  final bool isInitializing;
  final bool isSubmitting;
  final String? errorMessage;
  final AppSession? session;

  bool get isAuthenticated => session != null;

  SessionState copyWith({
    bool? isInitializing,
    bool? isSubmitting,
    String? errorMessage,
    AppSession? session,
    bool clearError = false,
  }) {
    return SessionState(
      isInitializing: isInitializing ?? this.isInitializing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      session: session ?? this.session,
    );
  }
}

final sessionRepositoryProvider = Provider((ref) => SessionRepository());

final appLocaleProvider =
    NotifierProvider<AppLocaleController, Locale>(AppLocaleController.new);

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

final dioProvider = Provider<Dio>((ref) {
  final session = ref.watch(sessionControllerProvider).session;
  return Dio(
    BaseOptions(
      baseUrl: AppEnvironment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        if (session != null)
          'Authorization': 'Bearer ${session.tokens.accessToken}',
      },
    ),
  );
});

class AppLocaleController extends Notifier<Locale> {
  @override
  Locale build() {
    _restore();
    return const Locale('en');
  }

  Future<void> _restore() async {
    final localeCode = await ref.read(sessionRepositoryProvider).loadLocaleCode();
    if (localeCode == null) {
      return;
    }
    state = Locale(localeCode);
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    await ref.read(sessionRepositoryProvider).saveLocaleCode(locale.languageCode);
  }
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  Future<void> restoreSession() async {
    state = state.copyWith(isInitializing: true, clearError: true);
    final repository = ref.read(sessionRepositoryProvider);
    final tokens = await repository.loadTokens();

    if (tokens == null) {
      state = const SessionState(isInitializing: false);
      return;
    }

    try {
      final session = await _loadSession(tokens);
      state = SessionState(
        isInitializing: false,
        session: session,
      );
    } catch (_) {
      await repository.clearTokens();
      state = const SessionState(isInitializing: false);
    }
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      isInitializing: false,
      clearError: true,
    );

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: AppEnvironment.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );

      final tokenResponse = await dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );
      final tokenJson = tokenResponse.data ?? <String, dynamic>{};
      final tokens = AuthTokens.fromJson(tokenJson);
      final session = await _loadSession(tokens);
      await ref.read(sessionRepositoryProvider).saveTokens(tokens);

      state = SessionState(
        isInitializing: false,
        isSubmitting: false,
        session: session,
      );
    } on DioException catch (error) {
      final message = error.response?.data is Map<String, dynamic>
          ? (error.response?.data['detail'] as String? ?? 'Login failed')
          : 'Login failed';
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: message,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Login failed',
      );
    }
  }

  Future<void> logout() async {
    final session = state.session;
    if (session == null) {
      state = const SessionState(isInitializing: false);
      return;
    }

    try {
      await ref.read(dioProvider).post('/auth/logout');
    } catch (_) {
      // Best-effort logout; local session is still cleared below.
    }

    await ref.read(sessionRepositoryProvider).clearTokens();
    state = const SessionState(isInitializing: false);
  }

  Future<AppSession> _loadSession(AuthTokens tokens) async {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnvironment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Authorization': 'Bearer ${tokens.accessToken}',
        },
      ),
    );

    final meResponse = await dio.get<Map<String, dynamic>>('/auth/me');
    return AppSession.fromAuthPayload(
      tokenJson: tokens.toJson(),
      meJson: meResponse.data ?? <String, dynamic>{},
    );
  }
}
