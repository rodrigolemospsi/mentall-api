import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'app_start_page.dart';

final _pinControllerProvider = StateProvider<TextEditingController>(
  (ref) => TextEditingController(),
);
final _erroProvider = StateProvider<String>((ref) => '');
final _processandoProvider = StateProvider<bool>((ref) => false);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  @override
  void dispose() {
    ref.read(_pinControllerProvider).dispose();
    super.dispose();
  }

  Future<void> _desbloquear() async {
    final pinController = ref.read(_pinControllerProvider);
    final pin = pinController.text.trim();

    if (pin.isEmpty) {
      ref.read(_erroProvider.notifier).state = 'Informe o PIN de acesso.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      await authService.desbloquearComPin(pin);

      if (!mounted) return;

      if (authService.desbloqueado) {
        pinController.clear();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppStartPage()),
        );
      } else {
        ref.read(_erroProvider.notifier).state = 'PIN incorreto.';
      }
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  Future<void> _configurarPin() async {
    final pinController = ref.read(_pinControllerProvider);
    final pin = pinController.text.trim();

    if (pin.isEmpty) {
      ref.read(_erroProvider.notifier).state = 'Informe um PIN de acesso.';
      return;
    }

    if (pin.length < 4) {
      ref.read(_erroProvider.notifier).state =
          'O PIN deve ter no minimo 4 caracteres.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      await authService.configurarPin(pin);

      if (!mounted) return;

      pinController.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AppStartPage()),
      );
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);
    final erro = ref.watch(_erroProvider);
    final processando = ref.watch(_processandoProvider);
    final authService = ref.read(authServiceProvider);
    final configurandoPin = !authService.requerPin;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: corPrincipal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    size: 64,
                    color: corPrincipal,
                  ),
                ),
                const SizedBox(height: 24),
                Image.asset(
                  'assets/images/logo_mentall.png',
                  height: 48,
                ),
                const SizedBox(height: 8),
                Text(
                  configurandoPin
                      ? 'Configure um PIN para proteger seus dados clinicos.'
                      : 'Informe seu PIN para acessar o prontuario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: ref.read(_pinControllerProvider),
                  obscureText: true,
                  textAlign: TextAlign.center,
                  maxLength: 16,
                  keyboardType: TextInputType.visiblePassword,
                  onSubmitted: (_) =>
                      configurandoPin ? _configurarPin() : _desbloquear(),
                  decoration: InputDecoration(
                    labelText: 'PIN de acesso',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                if (erro.isNotEmpty)
                  Text(
                    erro,
                    style: const TextStyle(color: Colors.red, fontSize: 13),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        processando ? null : (configurandoPin ? _configurarPin : _desbloquear),
                    icon: processando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(configurandoPin
                            ? Icons.shield_outlined
                            : Icons.lock_open_outlined),
                    label: Text(
                      processando
                          ? 'Processando...'
                          : (configurandoPin ? 'Configurar PIN' : 'Desbloquear'),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: corPrincipal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
