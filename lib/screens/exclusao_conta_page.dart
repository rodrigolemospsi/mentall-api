import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';
import 'conta_page.dart';
import 'exportar_tudo_page.dart';

/// Exclusão de conta dentro do app (item 2.4a do checklist de publicação).
///
/// Três passos, como as duas lojas exigem:
/// 1. aviso do que será apagado no servidor e do que permanece no aparelho;
/// 2. confirmação digitada ("EXCLUIR");
/// 3. recibo com o que foi eliminado e o que foi retido.
///
/// O prontuário clínico é cifrado no aparelho e NÃO é apagado pelo servidor:
/// a tela diz isso com todas as letras e não promete "exclusão total".
/// O prazo de guarda do prontuário é remetido à Política de Privacidade —
/// decisão de 23/10 para não cravar um prazo ainda em validação jurídica.
class ExclusaoContaPage extends StatefulWidget {
  const ExclusaoContaPage({
    super.key,
    this.contaEmail,
    this.excluirConta,
    this.limparSessao,
    this.aoConcluir,
  });

  /// E-mail exibido na confirmação. Em produção vem do [ApiClient].
  final String? contaEmail;

  /// Injetável nos testes; em produção usa [ApiClient.excluirConta].
  final Future<Map<String, dynamic>> Function(String confirmacao)? excluirConta;

  /// Injetável nos testes; em produção usa [ApiClient.limparSessaoLocal].
  final Future<void> Function()? limparSessao;

  /// Injetável nos testes; em produção navega para a tela de login/cadastro.
  final VoidCallback? aoConcluir;

  @override
  State<ExclusaoContaPage> createState() => _ExclusaoContaPageState();
}

enum _Etapa { aviso, confirmar, recibo }

class _ExclusaoContaPageState extends State<ExclusaoContaPage> {
  static const String _palavraConfirmacao = 'EXCLUIR';

  static const Map<String, String> _rotulosEliminados = {
    'usuarios': 'Conta e login',
    'contratos': 'Contratos terapêuticos',
    'anamneses': 'Respostas de anamnese',
    'lembretes': 'Lembretes e telefones',
    'dispositivos': 'Dispositivos conectados',
    'eventos': 'Registros técnicos (telemetria)',
    'wuzapi_instancias': 'Conexão do WhatsApp',
    'recuperacoes': 'Pedidos de recuperação',
    'resets_senha': 'Códigos de redefinição de senha',
  };

  final TextEditingController _confirmacaoController = TextEditingController();

  _Etapa _etapa = _Etapa.aviso;
  bool _processando = false;
  bool _confirmacaoOk = false;
  String? _erro;
  Map<String, dynamic>? _recibo;

  @override
  void initState() {
    super.initState();
    _confirmacaoController.addListener(_verificarConfirmacao);
  }

  @override
  void dispose() {
    _confirmacaoController.dispose();
    super.dispose();
  }

  void _verificarConfirmacao() {
    final ok =
        _confirmacaoController.text.trim().toUpperCase() == _palavraConfirmacao;
    if (ok != _confirmacaoOk) {
      setState(() => _confirmacaoOk = ok);
    }
  }

  Future<void> _excluir() async {
    if (!_confirmacaoOk || _processando) return;
    setState(() {
      _processando = true;
      _erro = null;
    });

    final excluir = widget.excluirConta ??
        (String confirmacao) =>
            ApiClient.excluirConta(confirmacao: confirmacao);

    Map<String, dynamic> resultado;
    try {
      resultado = await excluir(_palavraConfirmacao);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _processando = false;
        _erro = 'Erro inesperado ao excluir a conta. Tente novamente.';
      });
      return;
    }
    if (!mounted) return;

    if (resultado['sucesso'] == true) {
      try {
        final limpar = widget.limparSessao ?? ApiClient.limparSessaoLocal;
        await limpar();
      } catch (_) {
        // A conta já foi excluída no servidor; seguir para o recibo é mais
        // seguro do que esconder a exclusão por falha de limpeza local.
      }
      if (!mounted) return;
      setState(() {
        _processando = false;
        _recibo = (resultado['recibo'] as Map?)?.cast<String, dynamic>();
        _etapa = _Etapa.recibo;
      });
      return;
    }

    final erro = resultado['erro'];
    setState(() {
      _processando = false;
      _erro = erro is String && erro.isNotEmpty
          ? erro
          : 'Não foi possível excluir a conta agora. Tente novamente.';
    });
  }

  void _irParaConfirmacao() {
    setState(() {
      _erro = null;
      _etapa = _Etapa.confirmar;
    });
  }

  void _voltarParaAviso() {
    if (_processando) return;
    setState(() {
      _erro = null;
      _etapa = _Etapa.aviso;
    });
  }

  void _concluir() {
    final aoConcluir = widget.aoConcluir;
    if (aoConcluir != null) {
      aoConcluir();
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ContaPage()),
      (route) => false,
    );
  }

  String? _emailDaConta() {
    if (widget.contaEmail != null) return widget.contaEmail;
    try {
      return ApiClient.accountEmail;
    } catch (_) {
      return null;
    }
  }

  String _formatarQuando(Object? quando) {
    if (quando is! String) return '';
    final data = DateTime.tryParse(quando)?.toLocal();
    if (data == null) return '';
    String dois(int valor) => valor.toString().padLeft(2, '0');
    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        'às ${dois(data.hour)}:${dois(data.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final noRecibo = _etapa == _Etapa.recibo;
    return PopScope(
      canPop: !noRecibo,
      child: Scaffold(
        backgroundColor: context.corFundo,
        appBar: AppBar(
          title: const Text('Excluir minha conta'),
          backgroundColor: context.corFundo,
          foregroundColor: context.corPrimaria,
          elevation: 0,
          automaticallyImplyLeading: !noRecibo,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _passoIndicador(context),
              const SizedBox(height: 12),
              if (_etapa == _Etapa.aviso) ..._conteudoAviso(context),
              if (_etapa == _Etapa.confirmar) ..._conteudoConfirmacao(context),
              if (_etapa == _Etapa.recibo) ..._conteudoRecibo(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passoIndicador(BuildContext context) {
    final texto = switch (_etapa) {
      _Etapa.aviso => 'Passo 1 de 3 — Aviso',
      _Etapa.confirmar => 'Passo 2 de 3 — Confirmação',
      _Etapa.recibo => 'Passo 3 de 3 — Recibo',
    };
    return Text(
      texto,
      style: TextStyle(
        fontSize: Tipografia.sm,
        fontWeight: FontWeight.w600,
        color: context.corPrimaria,
      ),
    );
  }

  List<Widget> _conteudoAviso(BuildContext context) {
    return [
      Text(
        'Esta ação apaga a sua conta e os dados do servidor. Ela não pode ser '
        'desfeita depois da confirmação.',
        style: TextStyle(
          fontSize: Tipografia.base,
          fontWeight: FontWeight.w600,
          color: context.corError,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      _card(
        context,
        titulo: 'O que será apagado do servidor',
        icone: Icons.delete_outline,
        corIcone: context.corError,
        linhas: const [
          'Sua conta e o acesso (e-mail, senha e nome).',
          'Contratos terapêuticos e respostas de anamnese enviados ao servidor.',
          'Lembretes agendados e telefones cadastrados para envio.',
          'Dispositivos conectados, registros técnicos (telemetria) e a conexão do WhatsApp.',
          'Códigos de recuperação e de redefinição de senha.',
        ],
      ),
      const SizedBox(height: 12),
      _card(
        context,
        titulo: 'O que NÃO é apagado por esta ação',
        icone: Icons.shield_outlined,
        linhas: [
          'O prontuário clínico cifrado neste aparelho (pacientes, sessões, '
              'históricos e agenda local). O servidor não armazena conteúdo '
              'clínico, e a guarda do prontuário é responsabilidade legal do '
              'profissional. O prazo de guarda está descrito na Política de '
              'Privacidade.',
          'Arquivos de backup que você já exportou.',
          'Eventos já criados no seu Google Calendar (a conexão com o Google é '
              'encerrada; os eventos podem ser removidos no próprio Google, se '
              'você quiser).',
        ],
      ),
      const SizedBox(height: 12),
      _card(
        context,
        titulo: 'Antes de continuar',
        icone: Icons.info_outline,
        linhas: const [
          'Esta ação é definitiva: a conta não pode ser recuperada depois da exclusão.',
          'Antes de continuar, você pode exportar TUDO em PDF (prontuário e '
              'documentos) e/ou um backup cifrado. O PDF serve para leitura e '
              'arquivo; o backup serve para restauração.',
          'A exclusão no servidor é imediata e o recibo aparece no fim do processo.',
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExportarTudoPage()),
        ),
        icon: const Icon(Icons.picture_as_pdf_outlined),
        label: const Text('Exportar tudo em PDF antes de continuar'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _irParaConfirmacao,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Raio.lg),
          ),
        ),
        child: const Text('Continuar'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).maybePop(),
        child: const Text('Cancelar'),
      ),
    ];
  }

  List<Widget> _conteudoConfirmacao(BuildContext context) {
    final email = _emailDaConta();
    return [
      Text(
        'Para confirmar, digite a palavra EXCLUIR. A conta e os dados do '
        'servidor serão apagados de forma definitiva.',
        style: TextStyle(
          fontSize: Tipografia.base,
          color: context.corTextoSecondary,
          height: 1.4,
        ),
      ),
      if (email != null && email.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          'Conta: $email',
          style: TextStyle(
            fontSize: Tipografia.sm,
            color: context.corTextoMuted,
          ),
        ),
      ],
      const SizedBox(height: 16),
      TextField(
        controller: _confirmacaoController,
        enabled: !_processando,
        autocorrect: false,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Digite EXCLUIR para confirmar',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _excluir(),
      ),
      if (_erro != null) ...[
        const SizedBox(height: 12),
        Text(
          _erro!,
          style: TextStyle(color: context.corError, fontSize: Tipografia.smMd),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _confirmacaoOk && !_processando ? _excluir : null,
        style: FilledButton.styleFrom(
          backgroundColor: context.corError,
          foregroundColor: context.corOnPrimaria,
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
            : const Text('Excluir conta definitivamente'),
      ),
      TextButton(
        onPressed: _processando ? null : _voltarParaAviso,
        child: const Text('Voltar'),
      ),
    ];
  }

  List<Widget> _conteudoRecibo(BuildContext context) {
    final recibo = _recibo ?? const <String, dynamic>{};
    final jaExcluida = recibo['ja_excluida'] == true;
    final quando = _formatarQuando(recibo['quando']);
    final eliminado =
        (recibo['eliminado'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{};
    final retido = (recibo['retido'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};

    final itens = <String>[];
    for (final entrada in eliminado.entries) {
      final valor = entrada.value;
      final quantidade =
          valor is int ? valor : int.tryParse('$valor') ?? 0;
      if (quantidade > 0) {
        itens.add(
          '${_rotulosEliminados[entrada.key] ?? entrada.key}: $quantidade',
        );
      }
    }

    final prontuario = retido['prontuario'];
    final linhasRetido = <String>[
      if (prontuario is String && prontuario.isNotEmpty)
        prontuario
      else
        'O prontuário clínico cifrado permanece neste aparelho.',
      'A exclusão da conta não apaga os dados clínicos do aparelho.',
      'O prazo de guarda do prontuário é o previsto na legislação e está '
          'descrito na Política de Privacidade (em Privacidade e Segurança).',
    ];

    return [
      Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 32,
            color: context.corSuccess,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              jaExcluida ? 'A conta já estava excluída' : 'Conta excluída',
              style: TextStyle(
                fontSize: Tipografia.xl,
                fontWeight: FontWeight.bold,
                color: context.corTextoHeading,
              ),
            ),
          ),
        ],
      ),
      if (quando.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          'Concluído em $quando.',
          style: TextStyle(
            fontSize: Tipografia.sm,
            color: context.corTextoMuted,
          ),
        ),
      ],
      const SizedBox(height: 16),
      _card(
        context,
        titulo: 'Apagado do servidor',
        icone: Icons.delete_sweep_outlined,
        corIcone: context.corSuccess,
        linhas: itens.isEmpty
            ? const ['Nenhum registro residual foi encontrado no servidor.']
            : itens,
      ),
      const SizedBox(height: 12),
      _card(
        context,
        titulo: 'Mantido no aparelho',
        icone: Icons.phone_android_outlined,
        linhas: linhasRetido,
      ),
      const SizedBox(height: 12),
      _card(
        context,
        titulo: 'Como apagar também os dados deste aparelho',
        icone: Icons.help_outline,
        linhas: const [
          'Se não precisar manter o prontuário neste aparelho, exporte um '
              'backup (se quiser uma cópia) e desinstale o app ou limpe os '
              'dados do aplicativo nas configurações do aparelho.',
          'Depois da exclusão, esta conta não pode ser recuperada. Criar uma '
              'nova conta com o mesmo e-mail não restaura os dados apagados no '
              'servidor.',
        ],
      ),
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _concluir,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Raio.lg),
          ),
        ),
        child: const Text('Concluir'),
      ),
    ];
  }

  Widget _card(
    BuildContext context, {
    required String titulo,
    required IconData icone,
    required List<String> linhas,
    Color? corIcone,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icone, size: 20, color: corIcone ?? context.corPrimaria),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: Tipografia.md,
                      fontWeight: FontWeight.bold,
                      color: context.corTextoHeading,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final linha in linhas)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(color: context.corTextoMuted),
                    ),
                    Expanded(
                      child: Text(
                        linha,
                        style: TextStyle(
                          fontSize: Tipografia.sm,
                          color: context.corTextoSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
