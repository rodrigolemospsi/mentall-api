import 'package:hive_ce/hive.dart';

part 'progresso_sessao.g.dart';

@HiveType(typeId: 12)
class ProgressoSessao extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  String sessaoId;

  @HiveField(3)
  int numeroSessao;

  @HiveField(4)
  String sintomasJson;

  @HiveField(5)
  String metasJson;

  @HiveField(6)
  String avaliacaoGeral;

  @HiveField(7)
  String tendencia;

  @HiveField(8)
  DateTime dataProcessamento;

  ProgressoSessao({
    required this.id,
    required this.pacienteId,
    required this.sessaoId,
    required this.numeroSessao,
    this.sintomasJson = '[]',
    this.metasJson = '[]',
    this.avaliacaoGeral = '',
    this.tendencia = 'estavel',
    required this.dataProcessamento,
  });

  ProgressoSessao copyWith({
    String? id,
    String? pacienteId,
    String? sessaoId,
    int? numeroSessao,
    String? sintomasJson,
    String? metasJson,
    String? avaliacaoGeral,
    String? tendencia,
    DateTime? dataProcessamento,
  }) {
    return ProgressoSessao(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      sessaoId: sessaoId ?? this.sessaoId,
      numeroSessao: numeroSessao ?? this.numeroSessao,
      sintomasJson: sintomasJson ?? this.sintomasJson,
      metasJson: metasJson ?? this.metasJson,
      avaliacaoGeral: avaliacaoGeral ?? this.avaliacaoGeral,
      tendencia: tendencia ?? this.tendencia,
      dataProcessamento: dataProcessamento ?? this.dataProcessamento,
    );
  }
}
