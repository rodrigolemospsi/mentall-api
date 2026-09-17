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

  @override
  ConsumerState<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends ConsumerState<AppStartPage>
    with TickerProviderStateMixin {
  bool _mostrarSplash = true;
  bool _splashPodePular = false;
  bool _autoLoginTentado = false;
  Timer? _splashTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

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
    _fadeController.dispose();
    super.dispose();
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
