import 'package:flutter/material.dart';
import 'package:ppms_flutter/app/theme.dart';
import 'package:ppms_flutter/core/session/session_controller.dart';
import 'package:ppms_flutter/features/auth/presentation/login_screen.dart';
import 'package:ppms_flutter/features/shell/presentation/app_shell.dart';

class PpmsApp extends StatefulWidget {
  const PpmsApp({super.key});

  @override
  State<PpmsApp> createState() => _PpmsAppState();
}

class _PpmsAppState extends State<PpmsApp> {
  final SessionController _sessionController = SessionController();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _sessionController.restore();
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sessionController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'PPMS Flutter',
          theme: buildPpmsTheme(),
          home: !_isReady
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _sessionController.isAuthenticated
              ? AppShell(sessionController: _sessionController)
              : LoginScreen(sessionController: _sessionController),
        );
      },
    );
  }
}
