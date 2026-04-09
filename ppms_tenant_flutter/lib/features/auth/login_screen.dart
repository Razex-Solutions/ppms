import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_environment.dart';
import '../../app/localization/app_localizations.dart';
import '../../app/session/session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController(text: 'manager');
  final _passwordController = TextEditingController(text: 'password123');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Wrap(
              spacing: 24,
              runSpacing: 24,
              children: [
                SizedBox(
                  width: 420,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.text('loginTitle'),
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            Text(context.l10n.text('loginSubtitle')),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: context.l10n.text('username'),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return context.l10n.text('username');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: context.l10n.text('password'),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return context.l10n.text('password');
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: sessionState.isSubmitting
                                    ? null
                                    : () {
                                        if (!_formKey.currentState!.validate()) {
                                          return;
                                        }
                                        ref
                                            .read(sessionControllerProvider.notifier)
                                            .login(
                                              username: _usernameController.text,
                                              password: _passwordController.text,
                                            );
                                      },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  child: sessionState.isSubmitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(context.l10n.text('signIn')),
                                ),
                              ),
                            ),
                            if (sessionState.errorMessage != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                sessionState.errorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.text('demoAccounts'),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          const _SeedAccountTile('masteradmin'),
                          const _SeedAccountTile('headoffice'),
                          const _SeedAccountTile('stationadmin'),
                          const _SeedAccountTile('manager'),
                          const _SeedAccountTile('operator'),
                          const _SeedAccountTile('accountant'),
                          const SizedBox(height: 16),
                          Text(
                            '${context.l10n.text('apiBaseUrl')}: ${AppEnvironment.apiBaseUrl}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SeedAccountTile extends StatelessWidget {
  const _SeedAccountTile(this.username);

  final String username;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(username)),
          const Text('password123'),
        ],
      ),
    );
  }
}
