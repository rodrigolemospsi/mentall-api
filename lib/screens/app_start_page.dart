import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'login_page.dart';
import 'main_shell.dart';
import 'onboarding_page.dart';
import 'perfil_profissional_form_page.dart';

class AppStartPage extends ConsumerStatefulWidget {
  const AppStartPage({super.key});

  @override
  ConsumerState<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends ConsumerState<AppStartPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _bloqueadoPeloCicloDeVida = false;
  bool _mostrarSplash = true;
  bool _splashPodePular = false;
  Timer? _splashTimer;
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

    final authService = ref.read(authServiceProvider);

    if (!authService.desbloqueado && authService.requerAutenticacao) {
      return const LoginPage();
    }

    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final config = ref.read(configuracoesServiceProvider);

    if (!config.onboardingConcluido) {
      return const OnboardingPage();
    }

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
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: Center(
              child: Image.asset(
                isDark
                    ? 'assets/images/logo_mentall_escuro.png'
                    : 'assets/images/logo_mentall_pro_claro.png',
                height: 160,
                cacheHeight: 320,
                semanticLabel: 'Logo MentAll PRO',
              ),
          ),
        ),
      ),
    );
  }
}
