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
    );
  }
}
