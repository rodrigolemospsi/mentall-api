import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'home_page.dart';
import 'login_page.dart';
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

    Timer(const Duration(seconds: 2), () {
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() => _mostrarSplash = false);
        }
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final authService = ref.read(authServiceProvider);
      if (authService.desbloqueado && authService.requerPin) {
        authService.bloquear();
        _bloqueadoPeloCicloDeVida = true;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_bloqueadoPeloCicloDeVida) {
        _bloqueadoPeloCicloDeVida = false;
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mostrarSplash) {
      return _buildSplash(context);
    }

    final authService = ref.read(authServiceProvider);

    if (!authService.desbloqueado && authService.requerPin) {
      return const LoginPage();
    }

    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();

    if (perfil == null) {
      return const PerfilProfissionalFormPage();
    }

    return const HomePage();
  }

  Widget _buildSplash(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
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
                : 'assets/images/logo_mentall_claro.png',
            height: 160,
          ),
        ),
      ),
    );
  }
}
