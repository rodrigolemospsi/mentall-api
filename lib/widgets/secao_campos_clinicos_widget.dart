import 'package:flutter/material.dart';

import '../config/configuracao_abordagem_clinica.dart';
import 'campo_texto_widget.dart';
import 'secao_formulario.dart';

class SecaoCamposClinicosWidget extends StatelessWidget {
  final ConfiguracaoAbordagemClinica configuracao;
  final TextEditingController sinteseController;
  final TextEditingController formulacaoController;
  final TextEditingController intervencoesController;
  final TextEditingController apontamentosController;

  const SecaoCamposClinicosWidget({
    super.key,
    required this.configuracao,
    required this.sinteseController,
    required this.formulacaoController,
    required this.intervencoesController,
    required this.apontamentosController,
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
        _secaoApontamentos(),
      ],
    );
  }

  Widget _secaoSinteseClinica() {
    return SecaoFormulario(
      children: [
        CampoTextoWidget(
          controller: sinteseController,
          label: 'Síntese clínica',
        ),
      ],
    );
  }

  Widget _secaoFormulaClinica() {
    return SecaoFormulario(
      children: [
        CampoTextoWidget(
          controller: formulacaoController,
          label: configuracao.tituloFormulaClinica,
        ),
      ],
    );
  }

  Widget _secaoIntervencoes() {
    return SecaoFormulario(
      children: [
        CampoTextoWidget(
          controller: intervencoesController,
          label: configuracao.tituloIntervencoes,
        ),
      ],
    );
  }

  Widget _secaoApontamentos() {
    return SecaoFormulario(
      children: [
        CampoTextoWidget(
          controller: apontamentosController,
          label: 'Apontamentos',
        ),
      ],
    );
  }
}
