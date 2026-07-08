import 'package:hive_ce/hive.dart';

part 'registro_auditoria.g.dart';

@HiveType(typeId: 10)
class RegistroAuditoria extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String tipoEvento;

  @HiveField(2)
  String descricao;

  @HiveField(3)
  DateTime dataHora;

  @HiveField(4)
  String pacienteId;

  RegistroAuditoria({
    required this.id,
    required this.tipoEvento,
    required this.descricao,
    required this.dataHora,
    this.pacienteId = '',
  });
}
