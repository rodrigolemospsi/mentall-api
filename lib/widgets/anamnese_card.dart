import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/avaliacao_inicial.dart';
import '../models/paciente.dart';
import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

class AnamneseCard extends ConsumerWidget {
  final String pacienteId;
  final String termoSingular;
  final Paciente? paciente;
  final Map<String, dynamic>? respostasAnamnese;

  const AnamneseCard({
    super.key,
    required this.pacienteId,
    required this.termoSingular,
    this.paciente,
    this.respostasAnamnese,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avaliacaoAsync = ref.watch(avaliacaoInicialPorPacienteProvider(pacienteId));
    final avaliacao = avaliacaoAsync.valueOrNull;

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Raio.lg)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: context.corPrimaria, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Avaliação Inicial',
                  style: TextStyle(
                    fontSize: Tipografia.md,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _abrirFormAnamnese(context, ref, avaliacao),
                  icon: Icon(Icons.edit_outlined, size: 16, color: context.corPrimaria),
                  label: Text(
                    avaliacao != null ? 'Editar' : 'Preencher',
                    style: TextStyle(fontSize: Tipografia.smMd, color: context.corPrimaria),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (avaliacao == null || !avaliacao.preenchida)
              Text(
                'Registre a queixa principal, histórico clínico, medicamentos e hipótese diagnóstica.',
                style: TextStyle(fontSize: Tipografia.smMd, color: context.corTextoMuted, height: 1.4),
              )
            else ...[
              _campoResumo(context, 'Queixa principal', avaliacao.queixaPrincipal),
              _campoResumo(context, 'Histórico', avaliacao.historicoClinico),
              if (avaliacao.medicamentos.isNotEmpty)
                _campoResumo(context, 'Medicamentos', avaliacao.medicamentos),
              if (avaliacao.hipoteseDiagnostica.isNotEmpty)
                _campoResumo(context, 'Hipótese diagnóstica', avaliacao.hipoteseDiagnostica),
              if (avaliacao.objetivosTerapeuticos.isNotEmpty)
                _campoResumo(context, 'Objetivos terapêuticos', avaliacao.objetivosTerapeuticos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campoResumo(BuildContext context, String label, String valor) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: Tipografia.xs, fontWeight: FontWeight.w600, color: context.corPrimaria),
          ),
          const SizedBox(height: 3),
          Text(
            valor.length > 200 ? '${valor.substring(0, 200)}...' : valor,
            style: TextStyle(fontSize: Tipografia.smMd, color: context.corTextoBody, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormAnamnese(BuildContext context, WidgetRef ref, AvaliacaoInicial? existente) async {
    final auto = existente == null ? _montarAutoPreenchimento(paciente, respostasAnamnese) : const {};

    final queixaCtrl = TextEditingController(text: existente?.queixaPrincipal ?? auto['queixaPrincipal'] ?? '');
    final histCtrl = TextEditingController(text: existente?.historicoClinico ?? auto['historicoClinico'] ?? '');
    final medCtrl = TextEditingController(text: existente?.medicamentos ?? auto['medicamentos'] ?? '');
    final diagCtrl = TextEditingController(text: existente?.hipoteseDiagnostica ?? auto['hipoteseDiagnostica'] ?? '');
    final objCtrl = TextEditingController(text: existente?.objetivosTerapeuticos ?? auto['objetivosTerapeuticos'] ?? '');
    final obsCtrl = TextEditingController(text: existente?.observacoes ?? auto['observacoes'] ?? '');

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avaliação Inicial'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _campoTexto('Queixa principal', queixaCtrl, maxLines: 4),
                const SizedBox(height: 12),
                _campoTexto('Histórico clínico', histCtrl, maxLines: 4),
                const SizedBox(height: 12),
                _campoTexto('Medicamentos', medCtrl, maxLines: 2),
                const SizedBox(height: 12),
                _campoTexto('Hipótese diagnóstica', diagCtrl, maxLines: 3),
                const SizedBox(height: 12),
                _campoTexto('Objetivos terapêuticos', objCtrl, maxLines: 3),
                const SizedBox(height: 12),
                _campoTexto('Observações', obsCtrl, maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvo != true) return;

    final service = ref.read(avaliacaoInicialServiceProvider);
    final avaliacao = AvaliacaoInicial(
      id: existente?.id ?? '',
      pacienteId: pacienteId,
      queixaPrincipal: queixaCtrl.text.trim(),
      historicoClinico: histCtrl.text.trim(),
      medicamentos: medCtrl.text.trim(),
      hipoteseDiagnostica: diagCtrl.text.trim(),
      objetivosTerapeuticos: objCtrl.text.trim(),
      observacoes: obsCtrl.text.trim(),
      dataCriacao: existente?.dataCriacao ?? DateTime.now(),
    );

    await service.salvar(avaliacao);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação inicial salva com sucesso.')),
      );
    }
  }

  Map<String, String> _montarAutoPreenchimento(Paciente? paciente, Map<String, dynamic>? respostas) {
    final result = <String, String>{};

    if (respostas == null && paciente == null) return result;

    final partesHist = <String>[];
    final partesObs = <String>[];
    final partesObj = <String>[];

    if (paciente != null) {
      final nomeLinha = 'Paciente: ${paciente.nomeExibicao}';
      if (paciente.idade != null) {
        partesHist.add('$nomeLinha, ${paciente.idadeExibicao}');
      } else {
        partesHist.add(nomeLinha);
      }
      if (paciente.contatoExibicao.isNotEmpty && paciente.contatoExibicao != 'Contato não informado') {
        partesHist.add('Contato: ${paciente.contatoExibicao}');
      }
      if (paciente.email.isNotEmpty) {
        partesHist.add('Email: ${paciente.email.trim()}');
      }
      try {
        if (paciente.enderecoJson.isNotEmpty) {
          final end = jsonDecode(paciente.enderecoJson) as Map<String, dynamic>;
          final endPartes = <String>[];
          if (end['logradouro'] != null && end['logradouro'].toString().isNotEmpty) {
            var rua = end['logradouro'].toString().trim();
            if (end['numero'] != null && end['numero'].toString().isNotEmpty) {
              rua += ', ${end['numero']}';
            }
            if (end['complemento'] != null && end['complemento'].toString().isNotEmpty) {
              rua += ' - ${end['complemento']}';
            }
            endPartes.add(rua);
          }
          if (end['bairro'] != null && end['bairro'].toString().isNotEmpty) {
            endPartes.add(end['bairro'].toString().trim());
          }
          final String cidade = end['cidade']?.toString().trim() ?? '';
          final String estado = end['estado']?.toString().trim() ?? '';
          if (cidade.isNotEmpty || estado.isNotEmpty) {
            endPartes.add('$cidade${cidade.isNotEmpty && estado.isNotEmpty ? '/' : ''}$estado');
          }
          if (endPartes.isNotEmpty) {
            partesHist.add('Endereço: ${endPartes.join(', ')}');
          }
        }
      } catch (_) {}
    }

    if (respostas != null) {
      final motivoAberto = respostas['motivo_aberto']?.toString().trim();
      final motivos = respostas['motivos'];
      if (motivoAberto != null && motivoAberto.isNotEmpty) {
        result['queixaPrincipal'] = 'Relato do paciente:\n"$motivoAberto"';
      }
      if (motivos is List && motivos.isNotEmpty) {
        final motivosStr = motivos.map((m) => m.toString().trim()).where((m) => m.isNotEmpty).join(', ');
        if (motivosStr.isNotEmpty) {
          final existente = result['queixaPrincipal'] ?? '';
          result['queixaPrincipal'] = '${existente.isNotEmpty ? '$existente\n\n' : ''}Motivos indicados: $motivosStr.';
        }
      }

      final fezTerapia = respostas['fez_terapia'];
      if (fezTerapia != null) {
        partesHist.add('Já fez terapia: ${fezTerapia == true || fezTerapia == 'true' || fezTerapia == 'sim' ? 'Sim' : 'Não'}');
      }
      final foiPsiq = respostas['foi_psiquiatra'];
      if (foiPsiq != null) {
        partesHist.add('Já foi ao psiquiatra: ${foiPsiq == true || foiPsiq == 'true' || foiPsiq == 'sim' ? 'Sim' : 'Não'}');
      }
      final temDiag = respostas['tem_diagnostico'];
      final diagQual = respostas['tem_diagnostico_qual']?.toString().trim();
      if (temDiag != null) {
        partesHist.add('Possui diagnóstico: ${temDiag == true || temDiag == 'true' || temDiag == 'sim' ? 'Sim${diagQual != null && diagQual.isNotEmpty ? ' - $diagQual' : ''}' : 'Não'}');
      }
      if (diagQual != null && diagQual.isNotEmpty) {
        result['hipoteseDiagnostica'] = diagQual;
      }
      final usaMed = respostas['usa_medicacao'];
      final medQuais = respostas['usa_medicacao_quais']?.toString().trim();
      if (usaMed != null) {
        partesHist.add('Usa medicação: ${usaMed == true || usaMed == 'true' || usaMed == 'sim' ? 'Sim${medQuais != null && medQuais.isNotEmpty ? ' - $medQuais' : ''}' : 'Não'}');
      }
      if (medQuais != null && medQuais.isNotEmpty) {
        result['medicamentos'] = medQuais;
      }
      final sono = respostas['sono']?.toString().trim();
      if (sono != null && sono.isNotEmpty) {
        partesHist.add('Qualidade do sono: $sono');
      }
      final subst = respostas['substancias'];
      final substQuais = respostas['substancias_quais']?.toString().trim();
      if (subst != null) {
        partesHist.add('Uso de substâncias: ${subst == true || subst == 'true' || subst == 'sim' ? 'Sim${substQuais != null && substQuais.isNotEmpty ? ' - $substQuais' : ''}' : 'Não'}');
      }

      final objetivos = respostas['objetivos'];
      if (objetivos is List && objetivos.isNotEmpty) {
        final objStr = objetivos.map((o) => o.toString().trim()).where((o) => o.isNotEmpty).join(', ');
        if (objStr.isNotEmpty) {
          partesObj.add('Objetivos indicados: $objStr.');
        }
      }
      final oQueMudar = respostas['o_que_mudar']?.toString().trim();
      if (oQueMudar != null && oQueMudar.isNotEmpty) {
        partesObj.add('O que gostaria de mudar: "$oQueMudar"');
      }

      final sofrimento = respostas['sofrimento'];
      if (sofrimento != null) {
        partesObs.add('Intensidade do sofrimento: ${sofrimento.toString()}/10');
      }
      final frequencia = respostas['frequencia']?.toString().trim();
      if (frequencia != null && frequencia.isNotEmpty) {
        partesObs.add('Frequência dos sintomas: $frequencia');
      }
      final pensamentos = respostas['pensamentos']?.toString().trim();
      if (pensamentos != null && pensamentos.isNotEmpty) {
        partesObs.add('Pensamentos frequentes: "$pensamentos"');
      }
      final emocoes = respostas['emocoes_frequentes']?.toString().trim();
      if (emocoes != null && emocoes.isNotEmpty) {
        partesObs.add('Emoções frequentes: "$emocoes"');
      }
      final situacoes = respostas['situacoes_pioram']?.toString().trim();
      if (situacoes != null && situacoes.isNotEmpty) {
        partesObs.add('Situações que pioram: "$situacoes"');
      }
      final quandoMal = respostas['quando_mal']?.toString().trim();
      if (quandoMal != null && quandoMal.isNotEmpty) {
        partesObs.add('O que faz quando está mal: "$quandoMal"');
      }
    }

    if (partesHist.isNotEmpty) {
      result['historicoClinico'] = partesHist.join('\n');
    }
    if (partesObj.isNotEmpty) {
      result['objetivosTerapeuticos'] = partesObj.join('\n');
    }
    if (partesObs.isNotEmpty) {
      result['observacoes'] = partesObs.join('\n');
    }

    return result;
  }

  Widget _campoTexto(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
