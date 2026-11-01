import 'package:hive_ce/hive.dart';

part 'contrato_terapeutico.g.dart';

@HiveType(typeId: 5)
class ContratoTerapeutico extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  String token;

  @HiveField(3)
  DateTime dataCriacao;

  @HiveField(4)
  DateTime? dataEnvio;

  @HiveField(5)
  DateTime? dataAceite;

  @HiveField(6)
  String status;

  @HiveField(7)
  String nomeAceite;

  @HiveField(8)
  String url;

  @HiveField(9)
  bool arquivado;

  // -- Evidências da assinatura eletrônica simples (Fase A) --
  @HiveField(10, defaultValue: '')
  String aceiteCodigo;

  @HiveField(11, defaultValue: '')
  String aceiteHash;

  @HiveField(12, defaultValue: '')
  String aceiteVersao;

  @HiveField(13, defaultValue: '')
  String aceiteCpfMascarado;

  @HiveField(14, defaultValue: '')
  String aceiteIp;

  @HiveField(15, defaultValue: '')
  String aceiteUserAgent;

  @HiveField(16, defaultValue: '')
  String verificacaoUrl;

  /// Conteúdo canônico assinado (retornado pelo backend ao dono autenticado).
  @HiveField(17, defaultValue: '')
  String documentoTexto;

  ContratoTerapeutico({
    required this.id,
    required this.pacienteId,
    required this.token,
    required this.dataCriacao,
    this.dataEnvio,
    this.dataAceite,
    this.status = 'pendente',
    this.nomeAceite = '',
    this.url = '',
    this.arquivado = false,
    this.aceiteCodigo = '',
    this.aceiteHash = '',
    this.aceiteVersao = '',
    this.aceiteCpfMascarado = '',
    this.aceiteIp = '',
    this.aceiteUserAgent = '',
    this.verificacaoUrl = '',
    this.documentoTexto = '',
  });

  bool get isPendente => status == 'pendente';
  bool get isEnviado => status == 'enviado';
  bool get isAceito => status == 'aceito';
  bool get isRecusado => status == 'recusado';

  String get statusExibicao {
    switch (status) {
      case 'pendente':
        return 'Pendente';
      case 'enviado':
        return 'Aguardando aceite';
      case 'aceito':
        return 'Aceito';
      case 'recusado':
        return 'Recusado';
      default:
        return status;
    }
  }

  String get dataAceiteFormatada {
    if (dataAceite == null) return '';
    final d = dataAceite!;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  ContratoTerapeutico copyWith({
    String? id,
    String? pacienteId,
    String? token,
    DateTime? dataCriacao,
    DateTime? dataEnvio,
    DateTime? dataAceite,
    String? status,
    String? nomeAceite,
    String? url,
    bool? arquivado,
    String? aceiteCodigo,
    String? aceiteHash,
    String? aceiteVersao,
    String? aceiteCpfMascarado,
    String? aceiteIp,
    String? aceiteUserAgent,
    String? verificacaoUrl,
    String? documentoTexto,
  }) {
    return ContratoTerapeutico(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      token: token ?? this.token,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataEnvio: dataEnvio ?? this.dataEnvio,
      dataAceite: dataAceite ?? this.dataAceite,
      status: status ?? this.status,
      nomeAceite: nomeAceite ?? this.nomeAceite,
      url: url ?? this.url,
      arquivado: arquivado ?? this.arquivado,
      aceiteCodigo: aceiteCodigo ?? this.aceiteCodigo,
      aceiteHash: aceiteHash ?? this.aceiteHash,
      aceiteVersao: aceiteVersao ?? this.aceiteVersao,
      aceiteCpfMascarado: aceiteCpfMascarado ?? this.aceiteCpfMascarado,
      aceiteIp: aceiteIp ?? this.aceiteIp,
      aceiteUserAgent: aceiteUserAgent ?? this.aceiteUserAgent,
      verificacaoUrl: verificacaoUrl ?? this.verificacaoUrl,
      documentoTexto: documentoTexto ?? this.documentoTexto,
    );
  }
}
