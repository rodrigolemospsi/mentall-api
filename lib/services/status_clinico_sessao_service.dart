import '../models/sessao.dart';

enum StatusClinicoSessao {
  vazia,
  relatoDisponivel,
  transcricaoPendente,
  iaPendente,
  revisaoPendente,
  concluida,
  erro,
}

class StatusClinicoSessaoInfo {
  final StatusClinicoSessao status;
  final String codigo;
  final String titulo;
  final String descricao;
  final bool exigeAcaoProfissional;
  final bool podeGerarIa;
  final bool podeMarcarComoRevisada;
  final bool possuiPendencia;
  final bool iaValida;

  const StatusClinicoSessaoInfo({
    required this.status,
    required this.codigo,
    required this.titulo,
    required this.descricao,
    required this.exigeAcaoProfissional,
    required this.podeGerarIa,
    required this.podeMarcarComoRevisada,
    required this.possuiPendencia,
    required this.iaValida,
  });
}

class StatusClinicoSessaoService {
  const StatusClinicoSessaoService();

  StatusClinicoSessaoInfo calcular(Sessao sessao) {
    if (sessao.possuiErroProcessamentoIa) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.erro,
        codigo: 'erro',
        titulo: 'Erro no processamento',
        descricao:
            'Houve uma falha na transcrição ou no processamento por IA desta sessão.',
        exigeAcaoProfissional: true,
        podeGerarIa: false,
        podeMarcarComoRevisada: false,
        possuiPendencia: true,
        iaValida: false,
      );
    }

    if (!_possuiQualquerConteudo(sessao)) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.vazia,
        codigo: 'vazia',
        titulo: 'Sessão vazia',
        descricao:
            'A sessão ainda não possui relato, áudio, transcrição ou conteúdo clínico registrado.',
        exigeAcaoProfissional: false,
        podeGerarIa: false,
        podeMarcarComoRevisada: false,
        possuiPendencia: false,
        iaValida: false,
      );
    }

    if (_possuiRelatoOuAudio(sessao) && !sessao.possuiTranscricaoRelato) {
      return StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.relatoDisponivel,
        codigo: 'relato_disponivel',
        titulo: sessao.possuiAudioRelato
            ? 'Relato em áudio disponível'
            : 'Relato disponível',
        descricao: sessao.possuiAudioRelato
            ? 'Existe um relato em áudio disponível para transcrição ou revisão.'
            : 'Existe um relato clínico disponível para revisão ou processamento.',
        exigeAcaoProfissional: true,
        podeGerarIa: false,
        podeMarcarComoRevisada: true,
        possuiPendencia: true,
        iaValida: false,
      );
    }

    if (_estaTranscrevendo(sessao)) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.transcricaoPendente,
        codigo: 'transcricao_pendente',
        titulo: 'Transcrição pendente',
        descricao:
            'O relato está em fluxo de transcrição e ainda precisa ser concluído.',
        exigeAcaoProfissional: false,
        podeGerarIa: false,
        podeMarcarComoRevisada: false,
        possuiPendencia: true,
        iaValida: false,
      );
    }

    if (sessao.possuiTranscricaoRelato && !sessao.possuiIaGerada) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.iaPendente,
        codigo: 'ia_pendente',
        titulo: 'IA pendente',
        descricao:
            'A transcrição está disponível, mas os apontamentos do Copiloto ainda não foram gerados.',
        exigeAcaoProfissional: false,
        podeGerarIa: true,
        podeMarcarComoRevisada: true,
        possuiPendencia: true,
        iaValida: false,
      );
    }

    if (sessao.possuiIaGerada && !sessao.revisadoPeloProfissional) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.revisaoPendente,
        codigo: 'revisao_pendente',
        titulo: 'Revisão pendente',
        descricao:
            'Há conteúdo gerado ou auxiliado por IA que precisa ser revisado pelo profissional.',
        exigeAcaoProfissional: true,
        podeGerarIa: true,
        podeMarcarComoRevisada: true,
        possuiPendencia: true,
        iaValida: true,
      );
    }

    if (sessao.revisadoPeloProfissional) {
      return const StatusClinicoSessaoInfo(
        status: StatusClinicoSessao.concluida,
        codigo: 'concluida',
        titulo: 'Sessão revisada',
        descricao:
            'A sessão foi revisada pelo profissional e está clinicamente finalizada.',
        exigeAcaoProfissional: false,
        podeGerarIa: true,
        podeMarcarComoRevisada: false,
        possuiPendencia: false,
        iaValida: true,
      );
    }

    return const StatusClinicoSessaoInfo(
      status: StatusClinicoSessao.relatoDisponivel,
      codigo: 'relato_disponivel',
      titulo: 'Relato disponível',
      descricao:
          'A sessão possui conteúdo clínico disponível, mas ainda não foi concluída.',
      exigeAcaoProfissional: true,
      podeGerarIa: false,
      podeMarcarComoRevisada: true,
      possuiPendencia: true,
      iaValida: false,
    );
  }

  String codigo(Sessao sessao) {
    return calcular(sessao).codigo;
  }

  String titulo(Sessao sessao) {
    return calcular(sessao).titulo;
  }

  String descricao(Sessao sessao) {
    return calcular(sessao).descricao;
  }

  bool possuiPendencia(Sessao sessao) {
    return calcular(sessao).possuiPendencia;
  }

  bool exigeAcaoProfissional(Sessao sessao) {
    return calcular(sessao).exigeAcaoProfissional;
  }

  bool podeGerarIa(Sessao sessao) {
    return calcular(sessao).podeGerarIa;
  }

  bool podeMarcarComoRevisada(Sessao sessao) {
    return calcular(sessao).podeMarcarComoRevisada;
  }

  bool iaValida(Sessao sessao) {
    return calcular(sessao).iaValida;
  }

  bool _possuiQualquerConteudo(Sessao sessao) {
    return sessao.possuiConteudoClinico ||
        sessao.possuiAudioRelato ||
        sessao.possuiTranscricaoRelato;
  }

  bool _possuiRelatoOuAudio(Sessao sessao) {
    return sessao.possuiRelatoPosSessao || sessao.possuiAudioRelato;
  }

  bool _estaTranscrevendo(Sessao sessao) {
    return sessao.statusProcessamento == 'transcrevendo';
  }
}