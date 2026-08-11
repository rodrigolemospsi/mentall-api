import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'main_shell.dart';
import 'perfil_profissional_form_page.dart';

final _digitosProvider = StateProvider<List<String>>((ref) => ['', '', '', '']);
final _modoRecuperacaoProvider = StateProvider<bool>((ref) => false);
final _emailControllerProvider = Provider.autoDispose<TextEditingController>((ref) {
  return TextEditingController();
});
final _codigoControllerProvider = Provider.autoDispose<TextEditingController>((ref) {
  return TextEditingController();
});
final _erroProvider = StateProvider<String>((ref) => '');
final _processandoProvider = StateProvider<bool>((ref) => false);
final _codigoEnviadoProvider = StateProvider<bool>((ref) => false);
final _codigoVerificadoProvider = StateProvider<bool>((ref) => false);
final _recoveryTokenProvider = StateProvider<String?>((ref) => null);

class LoginPage extends ConsumerStatefulWidget {
  final bool modoConfiguracao;

  const LoginPage({super.key, this.modoConfiguracao = false});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _pinFocusNode = FocusNode();
  bool _biometriaDisponivel = false;
  List<BiometricType> _tiposBiometria = [];

  @override
  void initState() {
    super.initState();
    _verificarBiometria();
  }

  Future<void> _verificarBiometria() async {
    final authService = ref.read(authServiceProvider);
    final disponivel = await authService.dispositivoPossuiBiometria;
    final tipos = await authService.tiposBiometriaDisponiveis;
    if (mounted) {
      setState(() {
        _biometriaDisponivel = disponivel;
        _tiposBiometria = tipos;
      });
    }
  }

  @override
  void dispose() {
    _pinFocusNode.dispose();
    super.dispose();
  }

  String get _pin {
    final digitos = ref.read(_digitosProvider);
    return digitos.join();
  }

  void _adicionarDigito(String d) {
    final digitos = ref.read(_digitosProvider).toList();
    for (int i = 0; i < 4; i++) {
      if (digitos[i].isEmpty) {
        digitos[i] = d;
        ref.read(_digitosProvider.notifier).state = digitos;
        if (i == 3) {
          _processarPin();
        }
        return;
      }
    }
  }

  void _removerDigito() {
    final digitos = ref.read(_digitosProvider).toList();
    for (int i = 3; i >= 0; i--) {
      if (digitos[i].isNotEmpty) {
        digitos[i] = '';
        ref.read(_digitosProvider.notifier).state = digitos;
        return;
      }
    }
  }

  void _limparDigitos() {
    ref.read(_digitosProvider.notifier).state = ['', '', '', ''];
  }

  Future<void> _processarPin() async {
    final pin = _pin;
    if (pin.length != 4) return;

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    final authService = ref.read(authServiceProvider);

    final recoveryToken = ref.read(_recoveryTokenProvider);
    if (recoveryToken != null) {
      try {
        final sucesso = await authService.redefinirPinComRecuperacao(recoveryToken, pin);
        if (!mounted) return;
        if (sucesso) {
          _navegarParaHome();
        } else {
          ref.read(_erroProvider.notifier).state =
              'Não foi possível redefinir o PIN. Tente novamente.';
          _limparDigitos();
        }
      } finally {
        if (mounted) ref.read(_processandoProvider.notifier).state = false;
      }
      return;
    }

    final configurando = widget.modoConfiguracao || !authService.requerPin;

    try {
      if (configurando) {
        await authService.configurarPin(pin);
        if (!mounted) return;
        _navegarParaHome();
      } else {
        final sucesso = await authService.desbloquearComPin(pin);
        if (!mounted) return;
        if (sucesso) {
          _navegarParaHome();
        } else {
          final tentativas = authService.tentativasRestantes;
          if (tentativas > 0) {
            ref.read(_erroProvider.notifier).state =
                'PIN incorreto. $tentativas tentativas restantes.';
          } else {
            ref.read(
                _erroProvider.notifier).state = 'Muitas tentativas. Aguarde para tentar novamente.';
          }
          _limparDigitos();
        }
      }
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  Future<void> _autenticarComBiometria() async {
    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      final sucesso = await authService.autenticarComBiometria();
      if (!mounted) return;
      if (sucesso) {
        _navegarParaHome();
      } else {
        ref.read(_erroProvider.notifier).state =
            'Nao foi possivel usar a biometria. Use o PIN para desbloquear.';
      }
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  void _entrarModoRecuperacao() {
    ref.read(_modoRecuperacaoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';
    ref.read(_codigoEnviadoProvider.notifier).state = false;
    _limparDigitos();
  }

  void _sairModoRecuperacao() {
    ref.read(_modoRecuperacaoProvider.notifier).state = false;
    ref.read(_erroProvider.notifier).state = '';
    ref.read(_codigoEnviadoProvider.notifier).state = false;
    ref.read(_codigoVerificadoProvider.notifier).state = false;
    ref.read(_recoveryTokenProvider.notifier).state = null;
    _limparDigitos();
  }

  Future<void> _enviarCodigoRecuperacao() async {
    final email = ref.read(_emailControllerProvider).text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ref.read(_erroProvider.notifier).state = 'Informe um email valido.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      final sucesso = await authService.solicitarCodigoRecuperacao(email);
      if (!mounted) return;
      if (sucesso) {
        ref.read(_codigoEnviadoProvider.notifier).state = true;
        ref.read(_erroProvider.notifier).state = '';
      } else {
        ref.read(_erroProvider.notifier).state =
            'Nao foi possivel enviar o codigo. Verifique o email e tente novamente.';
      }
    } finally {
      if (mounted) {
        ref.read(_processandoProvider.notifier).state = false;
      }
    }
  }

  Future<void> _verificarCodigoRecuperacao() async {
    final email = ref.read(_emailControllerProvider).text.trim();
    final codigo = ref.read(_codigoControllerProvider).text.trim();

    if (codigo.length != 6) {
      ref.read(_erroProvider.notifier).state = 'Informe o codigo de 6 digitos.';
      return;
    }

    ref.read(_processandoProvider.notifier).state = true;
    ref.read(_erroProvider.notifier).state = '';

    try {
      final authService = ref.read(authServiceProvider);
      final recoveryToken = await authService.verificarCodigoRecuperacao(email, codigo);
      if (!mounted) return;

      if (recoveryToken != null) {
        ref.read(_codigoVerificadoProvider.notifier).state = true;
        ref.read(_recoveryTokenProvider.notifier).state = recoveryToken;
        ref.read(_erroProvider.notifier).state = '';
        _limparDigitos();
      } else {
        ref.read(_erroProvider.notifier).state = 'Codigo invalido ou expirado.';
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

  @override
  Widget build(BuildContext context) {
    final erro = ref.watch(_erroProvider);
    final processando = ref.watch(_processandoProvider);
    final modoRecuperacao = ref.watch(_modoRecuperacaoProvider);
    final codigoEnviado = ref.watch(_codigoEnviadoProvider);
    final codigoVerificado = ref.watch(_codigoVerificadoProvider);
    final authService = ref.read(authServiceProvider);
    final configurando = widget.modoConfiguracao || !authService.requerPin;
    final cs = Theme.of(context).colorScheme;

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
                if (modoRecuperacao) ...[
                  _buildRecuperacao(context, codigoEnviado, codigoVerificado, processando, cs),
                ] else ...[
                  _buildTitulo(context, configurando),
                  const SizedBox(height: 28),
                  _buildPinPad(cs, processando),
                  const SizedBox(height: 12),
                  _buildBiometria(context, cs, processando),
                  const SizedBox(height: 8),
                  if (erro.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        erro,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.corError, fontSize: 13),
                      ),
                    ),
                  if (!configurando)
                    TextButton(
                      onPressed: processando ? null : _entrarModoRecuperacao,
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

  Widget _buildTitulo(BuildContext context, bool configurando) {
    return Text(
      configurando
          ? 'Configure um PIN de 4 digitos para proteger seus dados clinicos.'
          : 'Informe seu PIN para acessar o prontuario.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: context.corTextoMuted,
        fontSize: 14,
      ),
    );
  }

  Widget _buildPinPad(ColorScheme cs, bool processando) {
    final digitos = ref.watch(_digitosProvider);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            return Container(
              width: 48,
              height: 56,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: digitos[i].isNotEmpty ? cs.primary : cs.outline,
                  width: digitos[i].isNotEmpty ? 2 : 1,
                ),
              ),
              child: Center(
                child: digitos[i].isNotEmpty
                    ? Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 28),
        KeyboardListener(
          focusNode: _pinFocusNode,
          onKeyEvent: (event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.backspace ||
                  event.logicalKey == LogicalKeyboardKey.delete) {
                _removerDigito();
              }
            }
          },
          child: Column(
            children: [
              for (int row = 0; row < 4; row++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (col) {
                    final num = row * 3 + col + 1;
                    if (row == 3 && col == 0) {
                      return const SizedBox(width: 64, height: 56);
                    }
                    if (row == 3 && col == 2) {
                      return _botaoTeclado(
                        null,
                        Icons.backspace_outlined,
                        processando ? null : () => _removerDigito(),
                      );
                    }
                    final label = row == 3 && col == 1 ? '0' : '$num';
                    return _botaoTeclado(
                      label,
                      null,
                      processando ? null : () => _adicionarDigito(label),
                    );
                  }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botaoTeclado(String? label, IconData? icon, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 64,
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 24, color: Theme.of(context).colorScheme.onSurface)
                  : Text(
                      label!,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometria(BuildContext context, ColorScheme cs, bool processando) {
    if (!_biometriaDisponivel) return const SizedBox.shrink();

    final configurando = widget.modoConfiguracao ||
        !ref.read(authServiceProvider).requerPin;
    if (configurando) return const SizedBox.shrink();

    final config = ref.read(configuracoesServiceProvider);
    if (!config.biometriaAtivada) return const SizedBox.shrink();

    final face = _tiposBiometria.contains(BiometricType.face);
    final icon = face ? Icons.face : Icons.fingerprint;
    final label = face ? 'Usar reconhecimento facial' : 'Usar digital / face';

    return Semantics(
      label: 'Autenticar com biometria',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: processando ? null : _autenticarComBiometria,
          icon: Icon(
            icon,
            color: cs.primary,
            size: 28,
          ),
          label: Text(
            label,
            style: TextStyle(color: cs.primary),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecuperacao(
    BuildContext context,
    bool codigoEnviado,
    bool codigoVerificado,
    bool processando,
    ColorScheme cs,
  ) {
    final emailController = ref.read(_emailControllerProvider);
    final codigoController = ref.read(_codigoControllerProvider);

    return Column(
      children: [
        Text(
          'Recuperar PIN',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.corTextoHeading,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          codigoEnviado
              ? 'Digite o codigo de 6 digitos enviado para seu email.'
              : 'Informe seu email profissional para receber um codigo de recuperacao.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.corTextoMuted, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: emailController,
          enabled: !codigoEnviado,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Email profissional',
            hintText: 'seu@email.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        if (!codigoEnviado) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: processando ? null : _enviarCodigoRecuperacao,
              icon: processando
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(processando ? 'Enviando...' : 'Enviar codigo'),
              style: FilledButton.styleFrom(
                backgroundColor: context.corPrimaria,
                foregroundColor: context.corOnPrimaria,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        if (codigoEnviado && !codigoVerificado) ...[
          const SizedBox(height: 16),
          TextField(
            controller: codigoController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: processando ? null : _verificarCodigoRecuperacao,
              icon: processando
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check_circle_outlined),
              label: Text(processando ? 'Verificando...' : 'Verificar código'),
              style: FilledButton.styleFrom(
                backgroundColor: context.corPrimaria,
                foregroundColor: context.corOnPrimaria,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
        if (codigoVerificado) ...[
          const SizedBox(height: 8),
          Text(
            'Código confirmado. Defina um novo PIN de 4 dígitos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.corSuccess, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildPinPad(cs, processando),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: processando ? null : _sairModoRecuperacao,
          child: const Text('Voltar'),
        ),
      ],
    );
  }
}
