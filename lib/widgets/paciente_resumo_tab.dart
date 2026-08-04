import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anamnese_enviada.dart';
import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../models/pacote.dart';
import '../models/progresso_sessao.dart';
import '../providers/service_providers.dart';
import '../services/anamnese_templates.dart';
import '../utils/mentall_colors.dart';
import '../utils/responsivo.dart';
import '../widgets/anamnese_card.dart';
import '../widgets/escalas_section.dart';
import '../widgets/paciente_resumo_card.dart';
import '../screens/sessao_form_page.dart';

// ---------------------------------------------------------------------------
// Top-level async helpers (accept BuildContext + WidgetRef explicitly so that
// they can be called from inside a ConsumerWidget's build closure).
// ---------------------------------------------------------------------------

Future<void> _enviarAnamneseWhatsApp({
  required BuildContext context,
  required WidgetRef ref,
  required AnamneseEnviada anamnese,
  required Paciente paciente,
}) async {
  final contato = paciente.contatoExibicao.replaceAll(RegExp(r'[^\d]'), '');
  if (contato.length < 8) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cadastre um telefone válido para o paciente.')),
      );
    }
    return;
  }

  final mensagem = Uri.encodeComponent(
    'Olá ${paciente.nome.trim()}! Antes da nossa consulta, gostaria que você respondesse este questionário. '
    'Leva cerca de 10 minutos e me ajuda a conhecer você melhor:\n\n'
    '${anamnese.url}',
  );
  final uri = Uri.parse('https://wa.me/$contato?text=$mensagem');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    final service = ref.read(anamneseEnviadaServiceProvider);
    await service.marcarComoEnviada(anamnese);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

Future<void> _criarEnviarAnamnese({
  required BuildContext context,
  required WidgetRef ref,
  required Paciente paciente,
}) async {
  try {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure o perfil profissional primeiro.')),
        );
      }
      return;
    }

    final abordagem = perfil.abordagemClinica;
    final template = AnamneseTemplates.templatePadrao(abordagem);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Criando questionário...'), duration: Duration(seconds: 30)),
      );
    }

    final service = ref.read(anamneseEnviadaServiceProvider);
    final anamnese = await service.criar(
      pacienteId: paciente.id,
      abordagem: abordagem,
      templateJson: template,
      nomePaciente: paciente.nome,
      nomeProfissional: perfil.nomeExibicao,
      registro: perfil.registroProfissional,
      tratamento: perfil.tratamento,
      crpVerificado: perfil.crpVerificado,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    await _enviarAnamneseWhatsApp(
      context: context,
      ref: ref,
      anamnese: anamnese,
      paciente: paciente,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar questionário: $e'), duration: const Duration(seconds: 8)),
      );
    }
  }
}

Future<void> _verificarOuReenviarAnamnese({
  required BuildContext context,
  required WidgetRef ref,
  required Paciente paciente,
  required AnamneseEnviada anamnese,
}) async {
  final service = ref.read(anamneseEnviadaServiceProvider);
  final existente = service.obterPorPaciente(paciente.id);
  if (existente != null && existente.isEnviado) {
    await service.verificarStatus(existente);
    ref.invalidate(anamnesePorPacienteProvider(paciente.id));
  }

  if (!context.mounted) return;
  final atual = ref.read(anamnesePorPacienteProvider(paciente.id)).valueOrNull;
  if (atual != null && atual.isRespondido) return;

  await _enviarAnamneseWhatsApp(
    context: context,
    ref: ref,
    anamnese: anamnese,
    paciente: paciente,
  );
}

Future<void> _enviarContratoWhatsApp({
  required BuildContext context,
  required WidgetRef ref,
  required ContratoTerapeutico contrato,
  required Paciente paciente,
}) async {
  final contato = paciente.contato.trim();
  if (!paciente.possuiContato) {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final termoCapitalizado = perfil?.termoSingularCapitalizado ?? 'Paciente';
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$termoCapitalizado não possui telefone cadastrado.')),
      );
    }
    return;
  }

  final mensagem = Uri.encodeComponent(
    'Olá ${paciente.nome.trim()}! Segue o Acordo Terapêutico para sua leitura. '
    'Por favor, acesse o link, leia com atenção e, se estiver de acordo, '
    'digite seu nome ao final para confirmar:\n\n'
    '${contrato.url}',
  );
  final numero = contato.replaceAll(RegExp(r'[^\d]'), '');
  final uri = Uri.parse('https://wa.me/$numero?text=$mensagem');

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    final contratoService = ref.read(contratoServiceProvider);
    await contratoService.marcarComoEnviado(contrato);

    final auditoria = ref.read(auditoriaServiceProvider);
    auditoria.registrar(
      tipoEvento: 'contrato_enviado',
      descricao: 'Acordo Terapêutico enviado para ${paciente.nome} via WhatsApp',
      pacienteId: paciente.id,
    );

    ref.invalidate(contratoPorPacienteProvider(paciente.id));
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o WhatsApp.')),
      );
    }
  }
}

Future<void> _criarEnviarContrato({
  required BuildContext context,
  required WidgetRef ref,
  required Paciente paciente,
}) async {
  try {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    if (perfil == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configure o perfil profissional primeiro.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.onInverseSurface,
            )),
            const SizedBox(width: 12),
            const Text('Criando contrato...'),
          ]),
          duration: const Duration(seconds: 120),
        ),
      );
    }

    final contratoService = ref.read(contratoServiceProvider);
    final config = ref.read(configuracoesServiceProvider);
    final contrato = await contratoService.criarContrato(
      paciente: paciente,
      perfil: perfil,
      templateContrato: config.contratoTemplate,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    await _enviarContratoWhatsApp(
      context: context,
      ref: ref,
      contrato: contrato,
      paciente: paciente,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao criar contrato: $e'),
          backgroundColor: context.corError,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Helper accessors (avoid recomputing from Perfil repeatedly inside build)
// ---------------------------------------------------------------------------

String _termo(WidgetRef ref) {
  final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
  return perfil?.termoSingular ?? 'paciente';
}

bool _usaPessoaAtendida(WidgetRef ref) {
  return _termo(ref) == 'pessoa atendida';
}

// ---------------------------------------------------------------------------
// PacienteResumoTab
// ---------------------------------------------------------------------------

class PacienteResumoTab extends ConsumerWidget {
  final Paciente paciente;

  const PacienteResumoTab({super.key, required this.paciente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessaoService = ref.watch(sessaoServiceProvider);
    final sessoesAtivas = sessaoService.listarSessoesDoPaciente(paciente.id);
    final sessoesArquivadas = sessaoService.listarSessoesArquivadasDoPaciente(paciente.id);

    final termoSingular = _termo(ref);
    final usaPessoaAtendida = _usaPessoaAtendida(ref);

    final anamnese = ref.watch(anamnesePorPacienteProvider(paciente.id)).valueOrNull;
    final contrato = ref.watch(contratoPorPacienteProvider(paciente.id)).valueOrNull;
    final pacotes = ref.watch(pacotesAtivosPorPacienteProvider(paciente.id)).valueOrNull ?? <Pacote>[];
    final progressos = ref.watch(progressoPorPacienteProvider(paciente.id)).valueOrNull ?? <ProgressoSessao>[];

    return LayoutBuilder(
      builder: (_, constraints) {
        if (Responsivo.isTablet(context)) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      PacienteResumoCard(
                        paciente: paciente,
                        termoSingular: termoSingular,
                        usaPessoaAtendida: usaPessoaAtendida,
                        quantidadeSessoes: sessoesAtivas.length,
                        quantidadeSessoesArquivadas: sessoesArquivadas.length,
                        contrato: contrato,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SessaoFormPage(paciente: paciente),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Nova sessão'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _botaoAnamnese(context, ref, paciente, anamnese)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _pacoteCard(context, ref, paciente, pacotes),
                      _contratoCard(context, ref, paciente, contrato, termoSingular),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _secaoEvolucao(context, ref, paciente, progressos),
                      const SizedBox(height: 14),
                      AnamneseCard(
                        pacienteId: paciente.id,
                        termoSingular: termoSingular,
                        paciente: paciente,
                        respostasAnamnese: anamnese != null && anamnese.isRespondido ? anamnese.respostas : null,
                      ),
                      const SizedBox(height: 14),
                      EscalasSection(pacienteId: paciente.id),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            PacienteResumoCard(
              paciente: paciente,
              termoSingular: termoSingular,
              usaPessoaAtendida: usaPessoaAtendida,
              quantidadeSessoes: sessoesAtivas.length,
              quantidadeSessoesArquivadas: sessoesArquivadas.length,
              contrato: contrato,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SessaoFormPage(paciente: paciente),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Nova sessão'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _botaoAnamnese(context, ref, paciente, anamnese)),
              ],
            ),
            const SizedBox(height: 14),
            _pacoteCard(context, ref, paciente, pacotes),
            _contratoCard(context, ref, paciente, contrato, termoSingular),
            const SizedBox(height: 14),
            _secaoEvolucao(context, ref, paciente, progressos),
            const SizedBox(height: 14),
            AnamneseCard(
              pacienteId: paciente.id,
              termoSingular: termoSingular,
              paciente: paciente,
              respostasAnamnese: anamnese != null && anamnese.isRespondido ? anamnese.respostas : null,
            ),
            const SizedBox(height: 14),
            EscalasSection(pacienteId: paciente.id),
            const SizedBox(height: 60),
          ],
        );
      },
    );
  }

  // -- botao anamnese --

  Widget _botaoAnamnese(
    BuildContext context,
    WidgetRef ref,
    Paciente paciente,
    AnamneseEnviada? anamnese,
  ) {
    final corPrimaria = context.corPrimaria;

    if (anamnese != null && anamnese.isRespondido) {
      return OutlinedButton.icon(
        onPressed: () => _verAnamnese(context, paciente, anamnese),
        icon: Icon(Icons.check_circle_outline, color: context.corSuccess, size: 20),
        label: Text(
          anamnese.dataResposta != null
              ? 'Respondido em ${anamnese.dataResposta!.day.toString().padLeft(2, '0')}/${anamnese.dataResposta!.month.toString().padLeft(2, '0')}'
              : 'Respondido',
          style: TextStyle(color: context.corSuccess),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          side: BorderSide(color: context.corSuccess),
        ),
      );
    }

    if (anamnese != null && anamnese.isEnviado) {
      return OutlinedButton.icon(
        onPressed: () => _verificarOuReenviarAnamnese(
          context: context,
          ref: ref,
          paciente: paciente,
          anamnese: anamnese,
        ),
        icon: Icon(Icons.hourglass_empty, color: context.corWarning, size: 20),
        label: Text('Reenviar anamnese', style: TextStyle(color: context.corWarning)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          side: BorderSide(color: context.corWarning),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _criarEnviarAnamnese(
        context: context,
        ref: ref,
        paciente: paciente,
      ),
      icon: const Icon(Icons.assignment_outlined, size: 20),
      label: const Text('Anamnese'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        side: BorderSide(color: corPrimaria),
      ),
    );
  }

  // -- pacote card --

  Widget _pacoteCard(
    BuildContext context,
    WidgetRef ref,
    Paciente paciente,
    List<Pacote> pacotes,
  ) {
    final corPrimaria = context.corPrimaria;
    final corCard = context.corCard;
    final corTextoHeading = context.corTextoHeading;
    final corTextoBody = context.corTextoBody;
    final corTextoMuted = context.corTextoMuted;

    final totalRestantes = pacotes.fold<int>(0, (sum, p) => sum + p.sessoesRestantes);
    final totalSessoes = pacotes.fold<int>(0, (sum, p) => sum + p.totalSessoes);
    final qtdPacotes = pacotes.length;

    if (qtdPacotes == 0) {
      return OutlinedButton.icon(
        onPressed: () => _criarPacote(context, ref, paciente),
        icon: const Icon(Icons.inventory_2_outlined, size: 20),
        label: const Text('Criar pacote'),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          side: BorderSide(color: corPrimaria),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: corPrimaria, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Pacotes ativos',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: corTextoHeading),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _criarPacote(context, ref, paciente),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Novo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$totalRestantes de $totalSessoes sessões restantes',
              style: TextStyle(fontSize: 13, color: corTextoBody),
            ),
            const SizedBox(height: 2),
            Text(
              '$qtdPacotes ${qtdPacotes == 1 ? 'pacote' : 'pacotes'} ativos',
              style: TextStyle(fontSize: 12, color: corTextoMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _criarPacote(BuildContext context, WidgetRef ref, Paciente paciente) async {
    final totalController = TextEditingController(text: '10');
    final valorController = TextEditingController(text: '');

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Criar Pacote de Sessões'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total de sessões',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Valor total (R\$)',
                  border: OutlineInputBorder(),
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
              onPressed: () {
                final total = int.tryParse(totalController.text);
                final valor = double.tryParse(valorController.text.replaceAll(',', '.'));
                if (total != null && total > 0 && valor != null && valor > 0) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Criar Pacote'),
            ),
          ],
        );
      },
    );

    if (result == true && context.mounted) {
      final total = int.tryParse(totalController.text);
      final valor = double.tryParse(valorController.text.replaceAll(',', '.'));
      if (total != null && total > 0 && valor != null && valor > 0) {
        ref.read(pacoteServiceProvider).criar(
          pacienteId: paciente.id,
          totalSessoes: total,
          valorTotal: valor,
        );
      }
    }
  }

  // -- contrato card --

  Widget _contratoCard(
    BuildContext context,
    WidgetRef ref,
    Paciente paciente,
    ContratoTerapeutico? contrato,
    String termoSingular,
  ) {
    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description_outlined, color: context.corPrimaria, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Acordo Terapêutico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                if (contrato != null && contrato.isAceito) ...[
                  TextButton.icon(
                    onPressed: () => _verContrato(context, contrato),
                    icon: Icon(Icons.visibility_outlined, size: 16, color: context.corSuccess),
                    label: Text('Ver', style: TextStyle(fontSize: 13, color: context.corSuccess)),
                  ),
                  IconButton(
                    tooltip: 'Arquivar acordo',
                    icon: Icon(Icons.archive_outlined, size: 18, color: context.corTextoMuted),
                    onPressed: () => _arquivarContrato(context, ref, paciente, contrato),
                  ),
                ]
                else if (contrato != null)
                  TextButton.icon(
                    onPressed: () => _enviarContratoWhatsApp(
                      context: context,
                      ref: ref,
                      contrato: contrato,
                      paciente: paciente,
                    ),
                    icon: Icon(Icons.send_outlined, size: 16, color: context.corPrimaria),
                    label: Text('Enviar', style: TextStyle(fontSize: 13, color: context.corPrimaria)),
                  )
                else
                  TextButton.icon(
                    onPressed: () => _criarEnviarContrato(
                      context: context,
                      ref: ref,
                      paciente: paciente,
                    ),
                    icon: Icon(Icons.send_outlined, size: 16, color: context.corPrimaria),
                    label: Text('Enviar', style: TextStyle(fontSize: 13, color: context.corPrimaria)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (contrato == null)
              Text(
                'Envie o Acordo Terapêutico para leitura e aceite do $termoSingular.',
                style: TextStyle(fontSize: 13, color: context.corTextoMuted, height: 1.4),
              )
            else ...[
              Row(
                children: [
                  _statusBadge(context, contrato),
                  const SizedBox(width: 10),
                  if (contrato.isAceito && contrato.nomeAceite.isNotEmpty)
                    Expanded(
                      child: Text(
                        'por ${contrato.nomeAceite} em ${contrato.dataAceiteFormatada}',
                        style: TextStyle(fontSize: 12, color: context.corTextoSecondary),
                      ),
                    )
                  else if (contrato.isEnviado)
                    Expanded(
                      child: Text(
                        'Enviado em ${contrato.dataCriacao.day.toString().padLeft(2, '0')}/${contrato.dataCriacao.month.toString().padLeft(2, '0')}/${contrato.dataCriacao.year}',
                        style: TextStyle(fontSize: 12, color: context.corTextoSecondary),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(BuildContext context, ContratoTerapeutico contrato) {
    final Color cor;
    final String texto;
    if (contrato.isAceito) {
      cor = context.corSuccess;
      texto = 'Aceito';
    } else if (contrato.isEnviado) {
      cor = context.corWarning;
      texto = 'Aguardando';
    } else {
      cor = context.corTextoMuted;
      texto = 'Pendente';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texto,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor),
      ),
    );
  }

  Future<void> _verContrato(BuildContext context, ContratoTerapeutico contrato) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acordo Terapêutico'),
        content: const Text(
          'Este acordo já foi aceito pelo paciente.\n\n'
          'Para visualizar ou editar o modelo do documento, '
          'acesse Configurações > Contrato.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  Future<void> _arquivarContrato(
    BuildContext context,
    WidgetRef ref,
    Paciente paciente,
    ContratoTerapeutico contrato,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar acordo'),
        content: const Text('O Acordo Terapêutico será removido desta tela e ficará disponível no menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    final service = ref.read(contratoServiceProvider);
    await service.arquivarContrato(contrato);
    ref.invalidate(contratoPorPacienteProvider(paciente.id));
    ref.invalidate(contratoArquivadoPorPacienteProvider(paciente.id));
  }

  // -- evolucao clinica --

  Widget _secaoEvolucao(
    BuildContext context,
    WidgetRef ref,
    Paciente paciente,
    List<ProgressoSessao> progressos,
  ) {
    if (progressos.isEmpty) {
      return const SizedBox.shrink();
    }

    final ultimo = progressos.first;
    final sintomas = _parseJsonList(ultimo.sintomasJson);

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up, color: context.corPrimaria, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Evolucao Clinica',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                Text(
                  'Sessao ${ultimo.numeroSessao}',
                  style: TextStyle(fontSize: 12, color: context.corTextoMuted),
                ),
              ],
            ),
            if (sintomas.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...sintomas.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          s['tendencia'] == 'melhora'
                              ? Icons.arrow_downward
                              : s['tendencia'] == 'piora'
                                  ? Icons.arrow_upward
                                  : Icons.remove,
                          size: 14,
                          color: s['tendencia'] == 'melhora'
                              ? context.corSuccess
                              : s['tendencia'] == 'piora'
                                  ? context.corError
                                  : context.corTextoMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s['nome']} (${s['intensidade']}/10)',
                            style: TextStyle(fontSize: 12, color: context.corTextoBody),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (ultimo.avaliacaoGeral.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ultimo.avaliacaoGeral,
                style: TextStyle(fontSize: 11, color: context.corTextoMuted, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseJsonList(String json) {
    if (json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // -- ver anamnese --

  void _verAnamnese(BuildContext context, Paciente paciente, AnamneseEnviada anamnese) {
    final respostas = anamnese.respostas;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anamnese - ${paciente.nome}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: _buildRespostasAnamnese(context, respostas),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRespostasAnamnese(BuildContext context, Map<String, dynamic> respostas) {
    if (respostas.isEmpty) {
      return const Text('Nenhuma resposta disponível.');
    }

    final blocos = <Widget>[];
    final segurancaIds = ['pensou_morte', 'pensou_machucar', 'esta_seguro'];

    blocos.add(Text(
      'Segurança emocional',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.corTextoHeading),
    ));
    blocos.add(const SizedBox(height: 8));

    for (final segId in segurancaIds) {
      if (respostas.containsKey(segId)) {
        final valor = respostas[segId];
        final texto = valor == true ? 'Sim' : 'Não';
        final isRisco = segId != 'esta_seguro' && valor == true;
        blocos.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isRisco ? context.corWarning.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(8),
              border: isRisco ? Border.all(color: context.corWarning.withValues(alpha: 0.5)) : null,
            ),
            child: Row(
              children: [
                if (isRisco)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(Icons.warning_amber_rounded, color: context.corWarning, size: 20),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelResposta(segId),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isRisco ? context.corWarning : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        texto,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isRisco ? context.corDanger : (valor == true ? context.corWarning : context.corSuccess),
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

    blocos.insert(0, const SizedBox(height: 16));
    final outrosIds = respostas.keys.where((k) => !segurancaIds.contains(k)).toList();
    for (final id in outrosIds) {
      final valor = respostas[id];
      blocos.insert(0, Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_labelResposta(id), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.corTextoMuted)),
            const SizedBox(height: 2),
            Text(
              valor is List ? valor.join(', ') : (valor is bool ? (valor ? 'Sim' : 'Não') : '${valor ?? ''}'),
              style: TextStyle(fontSize: 14, color: context.corTextoHeading),
            ),
          ],
        ),
      ));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocos);
  }

  String _labelResposta(String id) {
    const labels = {
      'nome': 'Nome',
      'nascimento': 'Data de nascimento',
      'telefone': 'Telefone',
      'email': 'E-mail',
      'cidade': 'Cidade',
      'como_chamar': 'Como prefere ser chamado(a)',
      'motivos': 'O que te trouxe à terapia',
      'motivo_aberto': 'Motivo da procura',
      'sofrimento': 'Nível de sofrimento (0-10)',
      'frequencia': 'Frequência',
      'afeta_rotina': 'Afeta rotina (0-10)',
      'afeta_relacoes': 'Afeta relacionamentos (0-10)',
      'afeta_trabalho': 'Afeta trabalho/estudos (0-10)',
      'fez_terapia': 'Já fez terapia',
      'foi_psiquiatra': 'Já foi ao psiquiatra',
      'usa_medicacao': 'Usa medicação',
      'tem_diagnostico': 'Tem diagnóstico',
      'sono': 'Sono',
      'substancias': 'Usa álcool/substâncias',
      'situacoes_pioram': 'Situações que pioram',
      'pensamentos': 'Pensamentos que aparecem',
      'emocoes_frequentes': 'Emoções frequentes',
      'quando_mal': 'O que faz quando se sente mal',
      'evita': 'Evita situações',
      'busca_confirmacao': 'Busca aprovação',
      'se_cobra': 'Se cobra demais',
      'o_que_mudar': 'O que gostaria de mudar',
      'pensou_morte': 'Pensamentos de não querer viver',
      'pensou_machucar': 'Pensou em se machucar',
      'esta_seguro': 'Está em segurança',
      'objetivos': 'Objetivos',
      'expectativa': 'O que espera da terapia',
    };
    return labels[id] ?? id;
  }
}
