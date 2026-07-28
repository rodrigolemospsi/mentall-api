import 'package:hive_ce/hive.dart';

part 'resposta_escala.g.dart';

@HiveType(typeId: 7)
class RespostaEscala extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  String escalaId;

  @HiveField(3)
  String respostasJson;

  @HiveField(4)
  int pontuacao;

  @HiveField(5)
  String interpretacao;

  @HiveField(6)
  DateTime dataAplicacao;

  @HiveField(7)
  String observacoes;

  RespostaEscala({
    required this.id,
    required this.pacienteId,
    required this.escalaId,
    this.respostasJson = '[]',
    this.pontuacao = 0,
    this.interpretacao = '',
    required this.dataAplicacao,
    this.observacoes = '',
  });

  RespostaEscala copyWith({
    String? id,
    String? pacienteId,
    String? escalaId,
    String? respostasJson,
    int? pontuacao,
    String? interpretacao,
    DateTime? dataAplicacao,
    String? observacoes,
  }) {
    return RespostaEscala(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      escalaId: escalaId ?? this.escalaId,
      respostasJson: respostasJson ?? this.respostasJson,
      pontuacao: pontuacao ?? this.pontuacao,
      interpretacao: interpretacao ?? this.interpretacao,
      dataAplicacao: dataAplicacao ?? this.dataAplicacao,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
