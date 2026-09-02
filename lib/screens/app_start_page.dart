import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../services/api_client.dart';
import '../services/encryption_service.dart';
import 'conta_page.dart';
import 'login_page.dart';
import 'main_shell.dart';
import 'perfil_profissional_form_page.dart';

import '../utils/mentall_colors.dart';
import '../utils/tipografia.dart';

class AppStartPage extends ConsumerStatefulWidget {
  const AppStartPage({super.key});

  /// Callback disparado a cada toque do usuário (registrado via Listener no
  /// MaterialApp) para resetar o timer de inatividade.
  static void Function()? onUserActivity;

  @override
  ConsumerState<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends ConsumerState<AppStartPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const int _inactivityTimeoutMinutos = 5;

  bool _bloqueadoPeloCicloDeVida = false;
  bool _mostrarSplash = true;
  bool _splashPodePular = false;
  bool _autoLoginTentado = false;
  Timer? _splashTimer;
  Timer? _inactivityTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    final perfilExiste =
        ref.read(perfilProfissionalServiceProvider).obterPerfil() != null;
    final duracao = perfilExiste ? 1 : 3;

    _splashTimer = Timer(Duration(seconds: duracao), () {
      _splashPodePular = true;
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() => _mostrarSplash = false);
        }
      });
    });

    AppStartPage.onUserActivity = _resetarInactivityTimer;
    _resetarInactivityTimer();
  }

  void _resetarInactivityTimer() {
    _inactivityTimer?.cancel();
    final authService = ref.read(authServiceProvider);
    if (!authService.requerAutenticacao || !authService.desbloqueado) return;
    _inactivityTimer = Timer(
      const Duration(minutes: _inactivityTimeoutMinutos),
      _bloquearPorInatividade,
    );
  }

  void _bloquearPorInatividade() {
    final authService = ref.read(authServiceProvider);
    if (authService.desbloqueado && authService.requerAutenticacao) {
      authService.bloquear();
      _autoLoginTentado = false; // Permite novo auto-login após reautenticar
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _pularSplash() {
    if (!_splashPodePular) return;
    _splashTimer?.cancel();
    _fadeController.forward().then((_) {
      if (mounted) {
        setState(() => _mostrarSplash = false);
      }
    });
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    _inactivityTimer?.cancel();
    AppStartPage.onUserActivity = null;
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final authService = ref.read(authServiceProvider);
      if (authService.desbloqueado && authService.requerAutenticacao) {
        authService.bloquear();
        _bloqueadoPeloCicloDeVida = true;
        _autoLoginTentado = false; // Permite novo auto-login no próximo desbloqueio
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_bloqueadoPeloCicloDeVida) {
        _bloqueadoPeloCicloDeVida = false;
        if (mounted) {
          setState(() {});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarSplash) {
      return _buildSplash(context);
    }

    // Fail-closed (vuln-0013): sem proteção durável, bloqueia o uso em vez de
    // gravar dados clínicos em texto puro.
    if (EncryptionService.protecaoIndisponivel) {
      return _buildProtecaoIndisponivel(context);
    }

    ref.watch(contaRevisaoProvider);

    final authService = ref.read(authServiceProvider);

    // Tenta auto-login com credenciais salvas no SecureStorage após desbloqueio
    if (authService.desbloqueado && !_autoLoginTentado) {
      _autoLoginTentado = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          authService.tentarAutoLoginServidor();
        }
      });
    }

    if (!ApiClient.possuiConta) {
      return const ContaPage();
    }

    if (!authService.desbloqueado && authService.requerAutenticacao) {
      return const LoginPage();
    }

    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();

    if (perfil == null) {
      return const PerfilProfissionalFormPage();
    }

    return const MainShell();
  }

  Widget _buildSplash(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: _pularSplash,
      child: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          );
        },
        child: Scaffold(
          backgroundColor: context.corFundo,
          body: Center(
              child: Image.asset(
                isDark
                    ? 'assets/images/logo_mentallpro_fundoescuro_01.png'
                    : 'assets/images/logo_mentallpro_fundoclaro_01.png',
                height: 128,
                cacheHeight: 256,
                semanticLabel: 'Logo MentAll PRO',
              ),
          ),
        ),
      ),
    );
  }

  Widget _buildProtecaoIndisponivel(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.gpp_maybe_outlined,
                    size: 64, color: Color(0xFFE65100)),
                const SizedBox(height: 20),
                Text(
                  'Proteção de dados indisponível',
                  style: TextStyle(
                    fontSize: Tipografia.xl,
                    fontWeight: FontWeight.bold,
                    color: context.corTextoHeading,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Este dispositivo não permite armazenar a chave de '
                  'criptografia de forma segura (sem biometria ou tela '
                  'bloqueada). Para proteger o prontuário, configure o '
                  'bloqueio de tela/biometria no aparelho e reinicie o app.',
                  style: TextStyle(
                    color: context.corTextoBody,
                    fontSize: Tipografia.base,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () {
                    // Reavalia para permitir novo boot após configurar o aparelho.
                    EncryptionService.protecaoIndisponivel = false;
                    setState(() {});
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
