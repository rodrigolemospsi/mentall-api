import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import 'sessao_card.dart';
import 'sem_sessoes_card.dart';

class ListaSessoesAtivas extends StatelessWidget {
  final List<Sessao> sessoes;
  final Paciente paciente;
  final String termoSingular;
  final String doOuDa;
  final void Function(Sessao sessao) onArquivar;

  const ListaSessoesAtivas({
    super.key,
    required this.sessoes,
    required this.paciente,
    required this.termoSingular,
    required this.doOuDa,
    required this.onArquivar,
  });

  @override
  Widget build(BuildContext context) {
    if (sessoes.isEmpty) {
      return SemSessoesCard(
        titulo: 'Nenhuma sessão ativa',
        mensagem:
            'Quando uma sessão for cadastrada, ela aparecerá aqui no histórico clínico ativo $doOuDa $termoSingular.',
        icone: Icons.history_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessoes.length,
      itemBuilder: (context, index) {
        final sessao = sessoes[index];

        return SessaoCard(
          sessao: sessao,
          paciente: paciente,
          arquivada: false,
          onArquivar: () => onArquivar(sessao),
        );
      },
    );
  }
}

class ListaSessoesArquivadas extends StatelessWidget {
  final List<Sessao> sessoes;
  final Paciente paciente;
  final String termoSingular;
  final String desteOuDesta;
  final void Function(Sessao sessao) onRestaurar;

  const ListaSessoesArquivadas({
    super.key,
    required this.sessoes,
    required this.paciente,
    required this.termoSingular,
    required this.desteOuDesta,
    required this.onRestaurar,
  });

  @override
  Widget build(BuildContext context) {
    if (sessoes.isEmpty) {
      return SemSessoesCard(
        titulo: 'Nenhuma sessão arquivada',
        mensagem:
            'Sessões arquivadas $desteOuDesta $termoSingular aparecerão aqui e poderão ser restauradas quando necessário.',
        icone: Icons.archive_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessoes.length,
      itemBuilder: (context, index) {
        final sessao = sessoes[index];

        return SessaoCard(
          sessao: sessao,
          paciente: paciente,
          arquivada: true,
          onRestaurar: () => onRestaurar(sessao),
        );
      },
    );
  }
}
