import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../utils/mentall_colors.dart';

final contaRevisaoProvider = StateProvider<int>((ref) => 0);

class ContaPage extends ConsumerStatefulWidget {
  const ContaPage({super.key});

  @override
  ConsumerState<ContaPage> createState() => _ContaPageState();
}

class _ContaPageState extends ConsumerState<ContaPage> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _nomeController = TextEditingController();

  bool _modoCadastro = false;
  bool _processando = false;
  bool _aguardandoConfirmacao = false;
  String? _erro;
  String? _mensagem;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _nomeController.dispose();
    super.dispose();
  }

  void _alternarModo() {
    setState(() {
      _modoCadastro = !_modoCadastro;
      _erro = null;
    });
  }

  Future<void> _enviar() async {
    final email = _emailController.text.trim();
    final senha = _senhaController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Informe um e-mail valido.');
      return;
    }
    if (senha.length < 6) {
      setState(() => _erro = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
    });

    Map<String, dynamic> resultado;
    if (_modoCadastro) {
      resultado = await ApiClient.registrarConta(
        email: email,
        senha: senha,
        nome: _nomeController.text.trim(),
      );
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        setState(() {
          _processando = false;
          _aguardandoConfirmacao = true;
          _mensagem = (resultado['mensagem'] as String?) ?? '';
        });
        return;
      }
    } else {
      resultado = await ApiClient.entrarComEmailSenha(
        email: email,
        senha: senha,
      );
      if (!mounted) return;
      if (resultado['sucesso'] == true) {
        ref.read(contaRevisaoProvider.notifier).state++;
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _processando = false;
      _erro = (resultado['erro'] as String?) ?? 'Nao foi possivel concluir.';
    });
  }

  Future<void> _confirmar() async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final resultado = await ApiClient.entrarComEmailSenha(
      email: _emailController.text.trim(),
      senha: _senhaController.text.trim(),
    );
    if (!mounted) return;
    if (resultado['sucesso'] == true) {
      ref.read(contaRevisaoProvider.notifier).state++;
      return;
    }
    setState(() {
      _processando = false;
      _erro = (resultado['erro'] as String?) ?? 'Nao foi possivel confirmar.';
    });
  }

  Future<void> _reenviar() async {
    setState(() {
      _processando = true;
      _erro = null;
    });
    final resultado = await ApiClient.registrarConta(
      email: _emailController.text.trim(),
      senha: _senhaController.text.trim(),
      nome: _nomeController.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _processando = false;
      if (resultado['sucesso'] == true) {
        _mensagem = (resultado['mensagem'] as String?) ?? '';
      } else {
        _erro = (resultado['erro'] as String?) ?? 'Nao foi possivel reenviar.';
      }
    });
  }

  void _voltarForm() {
    setState(() {
      _aguardandoConfirmacao = false;
      _erro = null;
      _mensagem = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_aguardandoConfirmacao) {
      return _buildConfirmacao(context);
    }
    return _buildForm(context);
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _logo(context),
                const SizedBox(height: 20),
                Text(
                  _modoCadastro ? 'Criar sua conta' : 'Bem-vindo de volta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.corTextoHeading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _modoCadastro
                      ? 'Crie sua conta para usar o MentAll PRO.'
                      : 'Entre com seu e-mail para acessar o prontuario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.corTextoMuted, fontSize: 14),
                ),
                const SizedBox(height: 28),
                if (_modoCadastro) ...[
                  TextField(
                    controller: _nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome completo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _processando ? null : _enviar(),
                ),
                const SizedBox(height: 20),
                Semantics(
                  label: _modoCadastro ? 'Criar conta' : 'Entrar',
                  child: FilledButton(
                    onPressed: _processando ? null : _enviar,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _processando
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: context.corOnPrimaria,
                            ),
                          )
                        : Text(_modoCadastro ? 'Criar conta' : 'Entrar'),
                  ),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.corError, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _processando ? null : _alternarModo,
                  child: Text(
                    _modoCadastro
                        ? 'Ja tenho uma conta. Entrar'
                        : 'Nao tenho conta. Criar conta',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmacao(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _logo(context),
                const SizedBox(height: 20),
                Icon(Icons.mark_email_read_outlined,
                    size: 56, color: context.corPrimaria),
                const SizedBox(height: 16),
                Text(
                  'Confirme seu e-mail',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: context.corTextoHeading,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enviamos um link de confirmacao para ${_emailController.text.trim()}. '
                  'Abra o e-mail, toque no link e depois volte aqui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.corTextoMuted, fontSize: 14, height: 1.4),
                ),
                if (_mensagem != null && _mensagem!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _mensagem!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.corTextoSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _processando ? null : _confirmar,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _processando
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.corOnPrimaria,
                          ),
                        )
                      : const Text('Ja confirmei'),
                ),
                if (_erro != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.corError, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _processando ? null : _reenviar,
                  child: const Text('Reenviar link'),
                ),
                TextButton(
                  onPressed: _processando ? null : _voltarForm,
                  child: const Text('Voltar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo(BuildContext context) {
    return Image.asset(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/images/logo_mentallpro_fundoescuro1.png'
          : 'assets/images/logo_mentallpro_fundoclaro1.png',
      height: 96,
      cacheHeight: 192,
      semanticLabel: 'Logo MentAll PRO',
    );
  }
}
