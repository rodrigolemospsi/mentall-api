import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../screens/login_page.dart';

/// Controla o bloqueio de segurança em um nível acima do Navigator.
///
/// O `AppStartPage` é o `home`; quando o usuário desbloqueia, a `LoginPage`
/// navega para a `MainShell` e a rota raiz é substituída. Um observer de
/// ciclo de vida/timer colocado no `AppStartPage` seria descartado junto.
///
/// Este widget vive no `MaterialApp.builder`, que não é substituído pela
/// navegação, e por isso garante que:
/// 1. Pausa e inatividade bloqueiam mesmo após o primeiro desbloqueio.
/// 2. Ao bloquear, TODAS as rotas clínicas empilhadas são removidas e a tela
///    de login volta a ser exibida.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.lockScreenBuilder,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  /// Tela exibida após o bloqueio. Padrão: [LoginPage], que reavalia o estado
  /// e pede a autenticação sem reexecutar o boot/splash. Injetável em testes.
  final Widget Function(BuildContext)? lockScreenBuilder;

  /// Callback disparado a cada toque do usuário (via Listener no MaterialApp)
  /// para resetar o timer de inatividade.
  static void Function()? onUserActivity;

  static const int inactivityTimeoutMinutos = 5;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockGate.onUserActivity = _resetarInactivityTimer;
    _resetarInactivityTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    AppLockGate.onUserActivity = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _resetarInactivityTimer() {
    _inactivityTimer?.cancel();
    final auth = ref.read(authServiceProvider);
    if (!auth.requerAutenticacao || !auth.desbloqueado) return;
    _inactivityTimer = Timer(
      const Duration(minutes: AppLockGate.inactivityTimeoutMinutos),
      _bloquear,
    );
  }

  Future<void> _bloquear() async {
    _inactivityTimer?.cancel();
    final auth = ref.read(authServiceProvider);
    if (!auth.requerAutenticacao || !auth.desbloqueado) return;
    await auth.bloquear();
    if (!mounted) return;

    // Remove as rotas clínicas empilhadas e volta à tela de login, que
    // reavalia o estado e pede a autenticação sem reexecutar o boot/splash.
    widget.navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: widget.lockScreenBuilder ?? (_) => const LoginPage(),
      ),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _bloquear();
    } else if (state == AppLifecycleState.resumed) {
      _resetarInactivityTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-arma o timer quando o app volta a ser usado (ex.: após desbloquear).
    ref.listen(lockRefreshProvider, (_, _) {
      _resetarInactivityTimer();
    });
    return widget.child;
  }
}
