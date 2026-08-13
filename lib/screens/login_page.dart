import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'main_shell.dart';
import 'perfil_profissional_form_page.dart';

final _erroProvider = StateProvider<String>((ref) => '');
final _processandoProvider = StateProvider<bool>((ref) => false);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  List<BiometricType> _tiposBiometria = [];
  bool _jaTentouAuto = false;

  @override
  void initState() {
    super.initState();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final authService = ref.read(authServiceProvider);
    final tipos = await authService.tiposBiometriaDisponiveis;
    if (mounted) {
      setState(() {
        _tiposBiometria = tipos;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _autenticar());
    }
  }

  Future<void> _autenticar() async {
    if (_jaTentouAuto) return;
    _jaTentouAuto = true;

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      final sucesso = await authService.desbloquearComBiometria();
      if (!mounted) return;
      if (sucesso) {
        _navegarParaHome();
      } else {
        ref.read(_erroProvider.notifier).state =
            'Nao foi possivel autenticar. Tente novamente.';
        _jaTentouAuto = false;
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
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  void _mostrarMigracaoPin() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoMigracaoPin(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final erro = ref.watch(_erroProvider);
    final processando = ref.watch(_processandoProvider);
    final possuiPinLegado = ref.read(authServiceProvider).possuiPinLegado;

    final face = _tiposBiometria.contains(BiometricType.face);
    final icon = face ? Icons.face : Icons.fingerprint;
    final label = face ? 'Usar reconhecimento facial' : 'Usar digital / face';

    return Scaffold(
      backgroundColor: context.corFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  Theme.of(context).brightness == Brightness.dark
                      ? 'assets/images/logo_mentall_escuro.png'
                      : 'assets/images/logo_mentall_pro_claro.png',
                  height: 120,
                  cacheHeight: 240,
                  semanticLabel: 'Logo MentAll PRO',
                ),
                const SizedBox(height: 20),
                Text(
                  'Acesso protegido',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.corTextoHeading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Autentique-se para acessar o prontuario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.corTextoMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                Semantics(
                  label: 'Autenticar com biometria',
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: processando ? null : _autenticar,
                      icon: processando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.corOnPrimaria,
                              ),
                            )
                          : Icon(icon, size: 28),
                      label: Text(
                        processando ? 'Autenticando...' : label,
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (erro.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      erro,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.corError, fontSize: 13),
                    ),
                  ),
                if (possuiPinLegado)
                  TextButton(
                    onPressed: processando ? null : _mostrarMigracaoPin,
                    child: const Text('Migrar do PIN antigo'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogoMigracaoPin extends ConsumerStatefulWidget {
  const _DialogoMigracaoPin();

  @override
  ConsumerState<_DialogoMigracaoPin> createState() => _DialogoMigracaoPinState();
}

class _DialogoMigracaoPinState extends ConsumerState<_DialogoMigracaoPin> {
  final _pinController = TextEditingController();
  bool _processando = false;
  String? _erro;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _migrar() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) return;

    setState(() {
      _processando = true;
      _erro = null;
    });

    final sucesso =
        await ref.read(authServiceProvider).migrarChaveDoPinLegado(pin);
    if (!mounted) return;

    if (sucesso) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _processando = false;
        _erro = 'PIN incorreto. Tente novamente.';
        _pinController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Migrar do PIN antigo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Informe seu PIN antigo uma ultima vez para migrar seus dados '
            'para o novo desbloqueio por biometria.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 16,
            textAlign: TextAlign.center,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PIN antigo',
              errorText: _erro,
              counterText: '',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _migrar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed:
              _processando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _processando ? null : _migrar,
          child: Text(_processando ? 'Migrando...' : 'Migrar'),
        ),
      ],
    );
  }
}
