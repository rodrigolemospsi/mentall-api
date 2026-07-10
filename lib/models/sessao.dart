import 'package:hive_ce/hive.dart';

import '../services/status_clinico_sessao_service.dart';
import 'enums.dart';

part 'sessao.g.dart';

@HiveType(typeId: 2)
class Sessao extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  int numeroSessao;

  @HiveField(3)
  DateTime data;

  /// Escala subjetiva de humor.
  /// Sugestão de uso: 0 a 10.
  @HiveField(4)
  int humor;

  @HiveField(5)
  String temaPrincipal;

  @HiveField(6)
  String eventosImportantes;

  @HiveField(7)
  String pensamentosAutomaticos;

  @HiveField(8)
  String emocoes;

  @HiveField(9)
  String comportamentos;

  @HiveField(10)
  String intervencoes;

  /// Nome interno legado da fase inicial focada em TCC.
  ///
  /// Mantido para preservar compatibilidade com o Hive.
  /// A interface pode exibir rótulos diferentes conforme a abordagem clínica
  /// configurada pelo profissional.
  @HiveField(11)
  String tecnicasTcc;

  @HiveField(12)
  String tarefaCasa;

  @HiveField(13)
  String evolucaoClinica;

  @HiveField(14)
  String planoProximaSessao;

  @HiveField(15)
  String observacoes;

  /// Relato clínico pós-sessão.
  ///
  /// Deve representar o relato organizado e revisável pelo profissional,
  /// não necessariamente a transcrição bruta do áudio.
  @HiveField(16)
  String relatoPosSessao;

  /// Apontamentos gerados pelo Copiloto/IA para revisão do profissional.
  @HiveField(17)
  String apontamentosCopiloto;

  /// Quando true, a sessão deixa de aparecer no histórico principal,
  /// mas continua preservada no prontuário.
  @HiveField(18)
  bool arquivada;

  /// Caminho local ou URL temporária do arquivo de áudio usado no relato pós-sessão.
  ///
  /// No Web, esse caminho pode ser temporário, especialmente quando for uma URL
  /// do tipo blob. Por isso, o conteúdo persistente do áudio deve ser guardado
  /// também em [audioRelatoBase64].
  @HiveField(19)
  String audioRelatoPath;

  /// Transcrição bruta ou semibruta gerada a partir do áudio.
  ///
  /// Deve ser mantida separada do [relatoPosSessao], pois a transcrição pode
  /// conter erros, repetições ou trechos ainda não organizados clinicamente.
  @HiveField(20)
  String transcricaoRelato;

  /// Data e horário do último processamento por IA.
  @HiveField(21)
  DateTime? dataProcessamentoIa;

  /// Indica se algum conteúdo da sessão foi gerado ou auxiliado por IA.
  @HiveField(22)
  bool geradoComIa;

  /// Estado atual do fluxo de processamento da sessão.
  ///
  /// Valores sugeridos:
  /// - 'manual'
  /// - 'audio_gravado'
  /// - 'transcrevendo'
  /// - 'transcrito'
  /// - 'ia_processando'
  /// - 'ia_processada'
  /// - 'revisado'
  /// - 'erro'
  @HiveField(23)
  String statusProcessamento;

  /// Indica se o áudio original foi mantido após a transcrição/processamento.
  @HiveField(24)
  bool audioMantido;

  /// Indica se o conteúdo gerado, transcrito ou organizado foi revisado
  /// pelo profissional antes de ser considerado parte do prontuário.
  @HiveField(25)
  bool revisadoPeloProfissional;

  /// Mensagem de erro relacionada à transcrição ou ao processamento por IA.
  ///
  /// Deve permanecer vazia quando não houver erro.
  @HiveField(26)
  String erroProcessamentoIa;

  /// Origem principal do relato da sessão.
  ///
  /// Valores sugeridos:
  /// - 'manual'
  /// - 'audio'
  /// - 'importado'
  /// - 'ia'
  @HiveField(27)
  String origemRelato;

  /// Conteúdo persistente do áudio em Base64.
  ///
  /// Este campo é especialmente importante para a versão Web, porque URLs do tipo
  /// blob podem deixar de funcionar depois que o navegador é fechado.
  ///
  /// Quando vazio, significa que não há áudio persistido em Base64.
  @HiveField(28)
  String audioRelatoBase64;

  @HiveField(29)
  String transcricaoRevisada;

  @HiveField(30)
  String artigosSugeridos;

  Sessao({
    required this.id,
    required this.pacienteId,
    required this.numeroSessao,
    required this.data,
    this.humor = 5,
    this.temaPrincipal = '',
    this.eventosImportantes = '',
    this.pensamentosAutomaticos = '',
    this.emocoes = '',
    this.comportamentos = '',
    this.intervencoes = '',
    this.tecnicasTcc = '',
    this.tarefaCasa = '',
    this.evolucaoClinica = '',
    this.planoProximaSessao = '',
    this.observacoes = '',
    this.relatoPosSessao = '',
    this.apontamentosCopiloto = '',
    this.arquivada = false,
    this.audioRelatoPath = '',
    this.transcricaoRelato = '',
    this.transcricaoRevisada = '',
    this.dataProcessamentoIa,
    this.geradoComIa = false,
    this.statusProcessamento = 'manual',
    this.audioMantido = false,
    this.revisadoPeloProfissional = false,
    this.erroProcessamentoIa = '',
    this.origemRelato = 'manual',
    this.audioRelatoBase64 = '',
    this.artigosSugeridos = '',
  });

  bool get possuiRelatoPosSessao => relatoPosSessao.trim().isNotEmpty;

  bool get possuiApontamentosCopiloto =>
      apontamentosCopiloto.trim().isNotEmpty;

  bool get estaAtiva => !arquivada;

  bool get possuiAudioRelato {
    return audioRelatoPath.trim().isNotEmpty ||
        audioRelatoBase64.trim().isNotEmpty;
  }

  StatusProcessamento get statusProcessamentoEnum =>
      StatusProcessamento.fromString(statusProcessamento);

  set statusProcessamentoEnum(StatusProcessamento v) =>
      statusProcessamento = v.value;

  OrigemRelato get origemRelatoEnum =>
      OrigemRelato.fromString(origemRelato);

  set origemRelatoEnum(OrigemRelato v) => origemRelato = v.value;

  bool get possuiAudioRelatoPersistido {
    return audioRelatoBase64.trim().isNotEmpty;
  }

  bool get possuiTranscricaoRelato => transcricaoRelato.trim().isNotEmpty;

  bool get possuiTranscricaoRevisada => transcricaoRevisada.trim().isNotEmpty;

  bool get possuiErroProcessamentoIa =>
      erroProcessamentoIa.trim().isNotEmpty;

  bool get foiCriadaPorAudio =>
      origemRelatoEnum == OrigemRelato.audio;

  bool get estaAguardandoRevisao =>
      statusProcessamentoEnum.estaAguardandoRevisao;

  bool get processamentoConcluido =>
      statusProcessamentoEnum.processamentoConcluido;

  bool get possuiConteudoClinico {
    return temaPrincipal.trim().isNotEmpty ||
        eventosImportantes.trim().isNotEmpty ||
        pensamentosAutomaticos.trim().isNotEmpty ||
        emocoes.trim().isNotEmpty ||
        comportamentos.trim().isNotEmpty ||
        intervencoes.trim().isNotEmpty ||
        tecnicasTcc.trim().isNotEmpty ||
        tarefaCasa.trim().isNotEmpty ||
        evolucaoClinica.trim().isNotEmpty ||
        planoProximaSessao.trim().isNotEmpty ||
        observacoes.trim().isNotEmpty ||
        relatoPosSessao.trim().isNotEmpty ||
        apontamentosCopiloto.trim().isNotEmpty ||
        transcricaoRelato.trim().isNotEmpty ||
        transcricaoRevisada.trim().isNotEmpty;
  }

  /// Indica se existe conteúdo gerado pela IA.
  bool get possuiIaGerada {
    return geradoComIa ||
        apontamentosCopiloto.trim().isNotEmpty;
  }

  /// Indica se existe relato ou áudio disponível.
  bool get possuiRelatoOuAudio {
    return possuiRelatoPosSessao || possuiAudioRelato;
  }

  /// Status clínico calculado da sessão.
  ///
  /// Não é persistido no Hive.
  /// É derivado automaticamente a partir dos dados existentes por meio do
  /// [StatusClinicoSessaoService].
  String get statusClinico {
    return const StatusClinicoSessaoService().codigo(this);
  }

  StatusClinicoSessaoInfo get statusClinicoInfo {
    return const StatusClinicoSessaoService().calcular(this);
  }

  bool get sessaoVazia {
    return statusClinicoInfo.status == StatusClinicoSessao.vazia;
  }

  bool get relatoDisponivel {
    return statusClinicoInfo.status == StatusClinicoSessao.relatoDisponivel;
  }

  bool get transcricaoPendente {
    return statusClinicoInfo.status == StatusClinicoSessao.transcricaoPendente;
  }

  bool get iaPendente {
    return statusClinicoInfo.status == StatusClinicoSessao.iaPendente;
  }

  bool get revisaoPendente {
    return statusClinicoInfo.status == StatusClinicoSessao.revisaoPendente;
  }

  bool get sessaoConcluida {
    return statusClinicoInfo.status == StatusClinicoSessao.concluida;
  }

  bool get sessaoComErro {
    return statusClinicoInfo.status == StatusClinicoSessao.erro;
  }

  bool get possuiPendenciaClinica {
    return statusClinicoInfo.possuiPendencia;
  }

  bool get exigeAcaoProfissional {
    return statusClinicoInfo.exigeAcaoProfissional;
  }

  bool get podeGerarIa {
    return statusClinicoInfo.podeGerarIa;
  }

  bool get podeMarcarComoRevisada {
    return statusClinicoInfo.podeMarcarComoRevisada;
  }

  bool get iaClinicaValida {
    return statusClinicoInfo.iaValida;
  }

  Sessao copyWith({
    String? id,
    String? pacienteId,
    int? numeroSessao,
    DateTime? data,
    int? humor,
    String? temaPrincipal,
    String? eventosImportantes,
    String? pensamentosAutomaticos,
    String? emocoes,
    String? comportamentos,
    String? intervencoes,
    String? tecnicasTcc,
    String? tarefaCasa,
    String? evolucaoClinica,
    String? planoProximaSessao,
    String? observacoes,
    String? relatoPosSessao,
    String? apontamentosCopiloto,
    bool? arquivada,
    String? audioRelatoPath,
    String? transcricaoRelato,
    DateTime? dataProcessamentoIa,
    bool? geradoComIa,
    String? statusProcessamento,
    bool? audioMantido,
    bool? revisadoPeloProfissional,
    String? erroProcessamentoIa,
    String? origemRelato,
    String? audioRelatoBase64,
    String? transcricaoRevisada,
    String? artigosSugeridos,
  }) {
    return Sessao(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      numeroSessao: numeroSessao ?? this.numeroSessao,
      data: data ?? this.data,
      humor: humor ?? this.humor,
      temaPrincipal: temaPrincipal ?? this.temaPrincipal,
      eventosImportantes: eventosImportantes ?? this.eventosImportantes,
      pensamentosAutomaticos:
          pensamentosAutomaticos ?? this.pensamentosAutomaticos,
      emocoes: emocoes ?? this.emocoes,
      comportamentos: comportamentos ?? this.comportamentos,
      intervencoes: intervencoes ?? this.intervencoes,
      tecnicasTcc: tecnicasTcc ?? this.tecnicasTcc,
      tarefaCasa: tarefaCasa ?? this.tarefaCasa,
      evolucaoClinica: evolucaoClinica ?? this.evolucaoClinica,
      planoProximaSessao: planoProximaSessao ?? this.planoProximaSessao,
      observacoes: observacoes ?? this.observacoes,
      relatoPosSessao: relatoPosSessao ?? this.relatoPosSessao,
      apontamentosCopiloto:
          apontamentosCopiloto ?? this.apontamentosCopiloto,
      arquivada: arquivada ?? this.arquivada,
      audioRelatoPath: audioRelatoPath ?? this.audioRelatoPath,
      transcricaoRelato: transcricaoRelato ?? this.transcricaoRelato,
      transcricaoRevisada: transcricaoRevisada ?? this.transcricaoRevisada,
      artigosSugeridos: artigosSugeridos ?? this.artigosSugeridos,
      dataProcessamentoIa:
          dataProcessamentoIa ?? this.dataProcessamentoIa,
      geradoComIa: geradoComIa ?? this.geradoComIa,
      statusProcessamento:
          statusProcessamento ?? this.statusProcessamento,
      audioMantido: audioMantido ?? this.audioMantido,
      revisadoPeloProfissional:
          revisadoPeloProfissional ?? this.revisadoPeloProfissional,
      erroProcessamentoIa:
          erroProcessamentoIa ?? this.erroProcessamentoIa,
      origemRelato: origemRelato ?? this.origemRelato,
      audioRelatoBase64: audioRelatoBase64 ?? this.audioRelatoBase64,
    );
  }
}