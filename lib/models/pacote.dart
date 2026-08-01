import 'package:hive_ce/hive.dart';

part 'pacote.g.dart';

@HiveType(typeId: 11)
class Pacote extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  int totalSessoes;

  @HiveField(3)
  int sessoesRestantes;

  @HiveField(4)
  double valorTotal;

  @HiveField(5)
  DateTime dataCriacao;

  @HiveField(6)
  bool ativo;

  @HiveField(7)
  String observacoes;

  Pacote({
    required this.id,
    required this.pacienteId,
    required this.totalSessoes,
    required this.sessoesRestantes,
    required this.valorTotal,
    required this.dataCriacao,
    this.ativo = true,
    this.observacoes = '',
  });

  double get valorPorSessao =>
      totalSessoes > 0 ? valorTotal / totalSessoes : 0.0;

  bool get esgotado => sessoesRestantes <= 0;

  Pacote copyWith({
    String? id,
    String? pacienteId,
    int? totalSessoes,
    int? sessoesRestantes,
    double? valorTotal,
    DateTime? dataCriacao,
    bool? ativo,
    String? observacoes,
  }) {
    return Pacote(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      totalSessoes: totalSessoes ?? this.totalSessoes,
      sessoesRestantes: sessoesRestantes ?? this.sessoesRestantes,
      valorTotal: valorTotal ?? this.valorTotal,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      ativo: ativo ?? this.ativo,
      observacoes: observacoes ?? this.observacoes,
    );
  }
}
