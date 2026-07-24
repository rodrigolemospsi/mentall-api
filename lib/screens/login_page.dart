import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'home_page.dart';
import 'perfil_profissional_form_page.dart';

final _pinControllerProvider = Provider.autoDispose<TextEditingController>((ref) {
  return TextEditingController();
});
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
        _navegarParaHome();
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
          'O PIN deve ter no mínimo 4 caracteres.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      final frase = await authService.configurarPinComFraseRecuperacao(pin);

      if (!mounted) return;

      pinController.clear();
      _mostrarFraseRecuperacao(frase);
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  void _mostrarFraseRecuperacao(String frase) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Frase de recuperação'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guarde esta frase em local seguro. Ela será necessária caso você esqueça seu PIN.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                frase,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(ctx).colorScheme.onPrimaryContainer,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Copie ou anote estas 12 palavras. Sem elas, seus dados serão permanentemente inacessíveis em caso de esquecimento do PIN.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _navegarParaHome();
            },
            child: const Text('Eu anotei. Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> _recuperarPin() async {
    final fraseController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar acesso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Digite a frase de recuperação de 12 palavras que foi gerada quando você configurou o PIN.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: fraseController,
              maxLines: 3,
              textCapitalization: TextCapitalization.none,
              decoration: const InputDecoration(
                hintText: 'Ex: casa carro flor livro mesa ...',
                border: OutlineInputBorder(),
                labelText: 'Frase de recuperação',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verificar'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    final frase = fraseController.text.trim().toLowerCase();
    if (frase.isEmpty) {
      ref.read(_erroProvider.notifier).state = 'Informe a frase de recuperação.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      if (!authService.verificarFraseRecuperacao(frase)) {
        ref.read(_erroProvider.notifier).state =
            'Frase de recuperação incorreta. Verifique as palavras e a ordem.';
        return;
      }

      final sucesso = await authService.recuperarComFrase(frase);
      if (!mounted) return;

      if (sucesso) {
        ref.read(_pinControllerProvider).clear();
        _navegarParaHome();
      } else {
        ref.read(_erroProvider.notifier).state =
            'Não foi possível recuperar o acesso.';
      }
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  void _navegarParaHome() {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PerfilProfissionalFormPage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = ref.watch(_erroProvider);
    final processando = ref.watch(_processandoProvider);
    final authService = ref.read(authServiceProvider);
    final configurandoPin = !authService.requerPin;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: context.corFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/logo_mentall_escuro.png'
                      : 'assets/images/logo_mentall_claro.png',
                  height: 144,
                  semanticLabel: 'Logo MentAll',
                ),
                const SizedBox(height: 24),
                Text(
                  configurandoPin
                      ? 'Configure um PIN para proteger seus dados clínicos.'
                      : 'Informe seu PIN para acessar o prontuário.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.corTextoMuted,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                Semantics(
                  label: 'Campo de PIN de acesso',
                  child: TextField(
                    controller: ref.read(_pinControllerProvider),
                    obscureText: true,
                    textAlign: TextAlign.center,
                    maxLength: 16,
                    keyboardType: TextInputType.number,
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
                ),
                const SizedBox(height: 8),
                if (erro.isNotEmpty)
                  Text(
                    erro,
                    style: TextStyle(color: context.corError, fontSize: 13),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        processando ? null : (configurandoPin ? _configurarPin : _desbloquear),
                    icon: processando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
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
                      backgroundColor: context.corPrimaria,
                      foregroundColor: context.corOnPrimaria,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                if (!configurandoPin) ...[
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: processando ? null : _recuperarPin,
                    child: const Text('Esqueci meu PIN'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
