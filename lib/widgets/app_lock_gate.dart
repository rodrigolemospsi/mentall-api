import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Controla o bloqueio de segurança em um nível acima do Navigator.
///
/// Vive no `MaterialApp.builder`, que não é substituído pela navegação, e por
/// isso garante que pausa e inatividade bloqueiem mesmo após o primeiro
/// desbloqueio.
///
/// IMPORTANTE: ao bloquear, NÃO remove as rotas clínicas empilhadas. A tela de
/// bloqueio é um overlay renderizado por cima. Isso preserva o estado da tela
/// de sessão — antes, um `pushAndRemoveUntil` destruía a `SessaoFormPage`
/// quando a tela apagava durante uma operação longa (a síntese de IA leva até
/// 150s, mais que o tempo de tela padrão), descartando o trabalho do
/// profissional. Com o overlay, a operação continua e o usuário volta a ela
/// após o desbloqueio.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child, this.lockScreenBuilder});

  final Widget child;

  /// Tela exibida enquanto bloqueado. Recebe o callback a ser chamado quando o
  /// desbloqueio for concluído. Injetável em testes.
  final Widget Function(BuildContext context, VoidCallback onDesbloqueado)?
  lockScreenBuilder;

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
  Timer? _heartbeatTimer;
  bool _bloqueado = false;

  // 60s: margem folgada dentro da janela de presença do painel (10 min), para
  // um único beat perdido não derrubar o usuário para "offline".
  static const Duration _heartbeatIntervalo = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLockGate.onUserActivity = _resetarInactivityTimer;
    _resetarInactivityTimer();
    _iniciarTelemetria();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _heartbeatTimer?.cancel();
    AppLockGate.onUserActivity = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Presença (Fase 2): heartbeat no boot e a cada [_heartbeatIntervalo].
  void _iniciarTelemetria() {
    _enviarHeartbeat();
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatIntervalo, (_) => _enviarHeartbeat());
  }

  void _enviarHeartbeat() {
    unawaited(ref.read(telemetriaServiceProvider).heartbeat());
  }

  void _resetarInactivityTimer() {
    _inactivityTimer?.cancel();
    if (_bloqueado) return;
    final auth = ref.read(authServiceProvider);
    if (!auth.requerAutenticacao || !auth.desbloqueado) return;
    _inactivityTimer = Timer(
      const Duration(minutes: AppLockGate.inactivityTimeoutMinutos),
      _bloquear,
    );
  }

  Future<void> _bloquear() async {
    _inactivityTimer?.cancel();
    if (_bloqueado) return;
    final auth = ref.read(authServiceProvider);
    if (!auth.requerAutenticacao || !auth.desbloqueado) return;
    await auth.bloquear();
    if (!mounted) return;
    // Overlay: mantém as rotas e o estado (operações em andamento continuam).
    setState(() => _bloqueado = true);
  }

  void _desbloquear() {
    if (!mounted) return;
    setState(() => _bloqueado = false);
    _resetarInactivityTimer();
    // Presença imediata após desbloquear (o heartbeat do boot pode ter falhado
    // por o JWT ainda não existir).
    _enviarHeartbeat();
  }

  /// "Visto por último" ANTES de apagar o JWT: o `bloquear()` zera o token, e
  /// sem isso o painel marcaria offline assim que o Android suspende o app
  /// (tela apagada / troca de app). O timeout curto evita atrasar o bloqueio
  /// se a rede estiver ruim.
  Future<void> _aoPausar() async {
    try {
      await ref
          .read(telemetriaServiceProvider)
          .heartbeat()
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // Best-effort: bloqueia mesmo sem conseguir avisar a nuvem.
    }
    await _bloquear();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      unawaited(_aoPausar());
    } else if (state == AppLifecycleState.resumed) {
      _resetarInactivityTimer();
      _enviarHeartbeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-arma o timer quando o app volta a ser usado (ex.: após desbloquear).
    ref.listen(lockRefreshProvider, (_, _) {
      _resetarInactivityTimer();
    });

    return Stack(
      children: [
        widget.child,
        if (_bloqueado)
          Positioned.fill(
            child:
                widget.lockScreenBuilder?.call(context, _desbloquear) ??
                _TelaBloqueio(onDesbloqueado: _desbloquear),
          ),
      ],
    );
  }
}

/// Tela de bloqueio em overlay. Autentica automaticamente ao ser exibida e
/// permite nova tentativa em caso de falha, sem sair da tela atual.
class _TelaBloqueio extends ConsumerStatefulWidget {
  const _TelaBloqueio({required this.onDesbloqueado});

  final VoidCallback onDesbloqueado;

  @override
  ConsumerState<_TelaBloqueio> createState() => _TelaBloqueioState();
}

class _TelaBloqueioState extends ConsumerState<_TelaBloqueio> {
  List<BiometricType> _tiposBiometria = [];
  bool _processando = false;
  String _erro = '';
  bool _jaTentouAuto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autenticar());
    _carregarTiposBiometria();
  }

  Future<void> _carregarTiposBiometria() async {
    try {
      final tipos = await ref
          .read(authServiceProvider)
          .tiposBiometriaDisponiveis;
      if (mounted) setState(() => _tiposBiometria = tipos);
    } catch (_) {
      // Sem biometria enumerável: o botão usa o ícone padrão.
    }
  }

  Future<void> _autenticar() async {
    if (_jaTentouAuto || !mounted) return;
    _jaTentouAuto = true;

    setState(() {
      _processando = true;
      _erro = '';
    });

    try {
      final auth = ref.read(authServiceProvider);
      final sucesso = await auth.desbloquearComBiometria();
      if (!mounted) return;
      if (sucesso) {
        unawaited(auth.estabelecerSessaoServidor());
        widget.onDesbloqueado();
      } else {
        setState(() {
          _erro = 'Não foi possível autenticar. Tente novamente.';
          _jaTentouAuto = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = e.toString().replaceFirst('Exception: ', '');
        _jaTentouAuto = false;
      });
    } finally {
      if (mounted) {
        setState(() => _processando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final face = _tiposBiometria.contains(BiometricType.face);
    final icon = face ? Icons.face : Icons.fingerprint;
    final label = face ? 'Usar reconhecimento facial' : 'Usar digital / face';

    return Material(
      color: context.corFundo,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/logo_mentallpro_fundoescuro_01.png'
                      : 'assets/images/logo_mentallpro_fundoclaro_01.png',
                  height: 96,
                  cacheHeight: 192,
                  semanticLabel: 'Logo MentAll PRO',
                ),
                const SizedBox(height: 20),
                Text(
                  'Acesso protegido',
                  style: TextStyle(
                    fontSize: Tipografia.xl,
                    fontWeight: FontWeight.bold,
                    color: context.corTextoHeading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Autentique-se para continuar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.corTextoMuted,
                    fontSize: Tipografia.base,
                  ),
                ),
                const SizedBox(height: 28),
                Semantics(
                  label: 'Autenticar com biometria',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _processando ? null : _autenticar,
                      icon: _processando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.corOnPrimaria,
                              ),
                            )
                          : Icon(icon, size: 28),
                      label: Text(_processando ? 'Autenticando...' : label),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Raio.lg),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_erro.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _erro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.corError,
                        fontSize: Tipografia.smMd,
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
