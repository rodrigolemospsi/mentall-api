import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Redefinição de senha da conta por código enviado ao e-mail.
///
/// Fluxo: informa o e-mail -> recebe um código -> define a nova senha. Ao
/// concluir, salva as credenciais no app (cofre durável) para que a
/// reautenticação volte a funcionar sem o usuário redigitar a senha.
class RedefinirSenhaPage extends StatefulWidget {
  const RedefinirSenhaPage({super.key, this.emailInicial = ''});

  final String emailInicial;

  @override
  State<RedefinirSenhaPage> createState() => _RedefinirSenhaPageState();
}

class _RedefinirSenhaPageState extends State<RedefinirSenhaPage> {
  final _emailController = TextEditingController();
  final _codigoController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarController = TextEditingController();

  int _etapa = 0; // 0 = e-mail, 1 = código + nova senha
  bool _processando = false;
  String? _erro;
  String? _mensagem;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.emailInicial.trim();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codigoController.dispose();
    _senhaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  bool _senhaForte(String s) =>
      s.length >= 10 &&
      s.contains(RegExp(r'[A-Z]')) &&
      s.contains(RegExp(r'[a-z]')) &&
      s.contains(RegExp(r'[0-9]'));

  Future<void> _enviarCodigo() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _erro = 'Informe um e-mail válido.');
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
      _mensagem = null;
    });

    final ok = await ApiClient.solicitarResetSenha(email);
    if (!mounted) return;

    setState(() {
      _processando = false;
      if (ok) {
        _etapa = 1;
        _mensagem =
            'Se o e-mail estiver cadastrado, enviamos um código. Confira sua caixa de entrada.';
      } else {
        _erro = 'Não foi possível enviar o código. Verifique sua conexão.';
      }
    });
  }

  Future<void> _redefinir() async {
    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();
    final senha = _senhaController.text;

    if (codigo.isEmpty) {
      setState(() => _erro = 'Informe o código recebido por e-mail.');
      return;
    }
    if (!_senhaForte(senha)) {
      setState(() => _erro =
          'A senha deve ter ao menos 10 caracteres, com maiúsculas, minúsculas e números.');
      return;
    }
    if (senha != _confirmarController.text) {
      setState(() => _erro = 'As senhas não conferem.');
      return;
    }

    setState(() {
      _processando = true;
      _erro = null;
    });

    final resultado = await ApiClient.redefinirSenha(
      email: email,
      codigo: codigo,
      novaSenha: senha,
    );
    if (!mounted) return;

    if (resultado['sucesso'] == true) {
      // Salva a credencial nova (cofre durável) para a reautenticação funcionar.
      await ApiClient.setCredentials(email, senha);
      await ApiClient.salvarConta(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha redefinida com sucesso!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _processando = false;
      _erro = (resultado['erro'] as String?)?.isNotEmpty == true
          ? resultado['erro'] as String
          : 'Não foi possível redefinir a senha.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('Redefinir senha'),
        backgroundColor: context.corFundo,
        foregroundColor: context.corPrimaria,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _etapa == 0
                    ? 'Informe o e-mail da sua conta para receber um código de redefinição.'
                    : 'Digite o código recebido e defina sua nova senha.',
                style: TextStyle(color: context.corTextoMuted, fontSize: Tipografia.base, height: 1.4),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                enabled: _etapa == 0 && !_processando,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'E-mail',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_etapa == 1) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _codigoController,
                  enabled: !_processando,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Código recebido',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _senhaController,
                  enabled: !_processando,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova senha',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmarController,
                  enabled: !_processando,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar nova senha',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _processando ? null : _redefinir(),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _processando
                    ? null
                    : (_etapa == 0 ? _enviarCodigo : _redefinir),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Raio.lg),
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
                    : Text(_etapa == 0 ? 'Enviar código' : 'Redefinir senha'),
              ),
              if (_mensagem != null) ...[
                const SizedBox(height: 14),
                Text(
                  _mensagem!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.corTextoSecondary, fontSize: Tipografia.smMd),
                ),
              ],
              if (_erro != null) ...[
                const SizedBox(height: 14),
                Text(
                  _erro!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.corError, fontSize: Tipografia.smMd),
                ),
              ],
              if (_etapa == 1)
                TextButton(
                  onPressed: _processando
                      ? null
                      : () => setState(() {
                            _etapa = 0;
                            _erro = null;
                          }),
                  child: const Text('Trocar e-mail'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
