import 'package:hive_ce/hive.dart';

part 'avaliacao_inicial.g.dart';

@HiveType(typeId: 6)
class AvaliacaoInicial extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  String queixaPrincipal;

  @HiveField(3)
  String historicoClinico;

  @HiveField(4)
  String medicamentos;

  @HiveField(5)
  String hipoteseDiagnostica;

  @HiveField(6)
  String objetivosTerapeuticos;

  @HiveField(7)
  String observacoes;

  @HiveField(8)
  DateTime dataCriacao;

  @HiveField(9)
  DateTime? dataAtualizacao;

  AvaliacaoInicial({
    required this.id,
    required this.pacienteId,
    this.queixaPrincipal = '',
    this.historicoClinico = '',
    this.medicamentos = '',
    this.hipoteseDiagnostica = '',
    this.objetivosTerapeuticos = '',
    this.observacoes = '',
    required this.dataCriacao,
    this.dataAtualizacao,
  });

  bool get preenchida =>
      queixaPrincipal.isNotEmpty ||
      historicoClinico.isNotEmpty ||
      medicamentos.isNotEmpty ||
      hipoteseDiagnostica.isNotEmpty ||
      objetivosTerapeuticos.isNotEmpty;

  AvaliacaoInicial copyWith({
    String? id,
    String? pacienteId,
    String? queixaPrincipal,
    String? historicoClinico,
    String? medicamentos,
    String? hipoteseDiagnostica,
    String? objetivosTerapeuticos,
    String? observacoes,
    DateTime? dataCriacao,
    DateTime? dataAtualizacao,
  }) {
    return AvaliacaoInicial(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      queixaPrincipal: queixaPrincipal ?? this.queixaPrincipal,
      historicoClinico: historicoClinico ?? this.historicoClinico,
      medicamentos: medicamentos ?? this.medicamentos,
      hipoteseDiagnostica: hipoteseDiagnostica ?? this.hipoteseDiagnostica,
      objetivosTerapeuticos: objetivosTerapeuticos ?? this.objetivosTerapeuticos,
      observacoes: observacoes ?? this.observacoes,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}
