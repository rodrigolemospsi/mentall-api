import 'package:flutter/material.dart';

import '../config/configuracao_abordagem_clinica.dart';
import 'campo_texto_widget.dart';
import 'secao_formulario.dart';

class SecaoCamposClinicosWidget extends StatelessWidget {
  final ConfiguracaoAbordagemClinica configuracao;
  final TextEditingController eventosController;
  final TextEditingController evolucaoController;
  final TextEditingController observacoesController;
  final TextEditingController pensamentosController;
  final TextEditingController emocoesController;
  final TextEditingController comportamentosController;
  final TextEditingController intervencoesController;
  final TextEditingController tecnicasController;
  final TextEditingController tarefaController;
  final TextEditingController planoController;
  final TextEditingController apontamentosCopilotoController;

  const SecaoCamposClinicosWidget({
    super.key,
    required this.configuracao,
    required this.eventosController,
    required this.evolucaoController,
    required this.observacoesController,
    required this.pensamentosController,
    required this.emocoesController,
    required this.comportamentosController,
    required this.intervencoesController,
    required this.tecnicasController,
    required this.tarefaController,
    required this.planoController,
    required this.apontamentosCopilotoController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _secaoSinteseClinica(),
        const SizedBox(height: 16),
        _secaoFormulaClinica(),
        const SizedBox(height: 16),
        _secaoIntervencoes(),
        const SizedBox(height: 16),
        _secaoPlano(),
        const SizedBox(height: 16),
        _secaoApontamentosCopiloto(),
      ],
    );
  }

  Widget _secaoSinteseClinica() {
    return SecaoFormulario(
      titulo: 'Síntese clínica',
      subtitulo:
          'Campos estruturados que futuramente poderão ser sugeridos pela IA e revisados pelo profissional.',
      children: [
        CampoTextoWidget(
          controller: eventosController,
          label: configuracao.eventosLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: evolucaoController,
          label: configuracao.evolucaoLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: observacoesController,
          label: 'Observações livres',
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _secaoFormulaClinica() {
    return SecaoFormulario(
      titulo: configuracao.tituloFormulaClinica,
      subtitulo: configuracao.subtituloFormulaClinica,
      children: [
        CampoTextoWidget(
          controller: pensamentosController,
          label: configuracao.campo1Label,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: emocoesController,
          label: configuracao.campo2Label,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: comportamentosController,
          label: configuracao.campo3Label,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _secaoIntervencoes() {
    return SecaoFormulario(
      titulo: configuracao.tituloIntervencoes,
      children: [
        CampoTextoWidget(
          controller: intervencoesController,
          label: configuracao.intervencoesLabel,
          maxLines: 4,
        ),
        CampoTextoWidget(
          controller: tecnicasController,
          label: configuracao.tecnicasLabel,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _secaoPlano() {
    return SecaoFormulario(
      titulo: configuracao.tituloPlano,
      children: [
        CampoTextoWidget(
          controller: tarefaController,
          label: configuracao.tarefaLabel,
          maxLines: 3,
        ),
        CampoTextoWidget(
          controller: planoController,
          label: configuracao.planoLabel,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _secaoApontamentosCopiloto() {
    return SecaoFormulario(
      titulo: 'Apontamentos do Copiloto',
      subtitulo:
          'Espaço para hipóteses, focos de atenção e possibilidades clínicas sugeridas pela IA, sempre para revisão do profissional e considerando a abordagem ${configuracao.nomeAbordagem}.',
      children: [
        CampoTextoWidget(
          controller: apontamentosCopilotoController,
          label: configuracao.apontamentosCopilotoLabel,
          maxLines: 6,
        ),
      ],
    );
  }
}
