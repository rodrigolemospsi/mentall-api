import 'package:hive_ce/hive.dart';

import 'enums.dart';

part 'compromisso.g.dart';

@HiveType(typeId: 4)
class Compromisso extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String pacienteId;

  @HiveField(2)
  DateTime dataHoraInicio;

  @HiveField(3)
  DateTime dataHoraFim;

  @HiveField(4)
  String titulo;

  @HiveField(5)
  String observacoes;

  @HiveField(6)
  String status;

  @HiveField(7)
  String? sessaoId;

  @HiveField(8)
  DateTime dataCriacao;

  @HiveField(9)
  DateTime? dataAtualizacao;

  Compromisso({
    required this.id,
    required this.pacienteId,
    required this.dataHoraInicio,
    DateTime? dataHoraFim,
    this.titulo = '',
    this.observacoes = '',
    this.status = 'agendado',
    this.sessaoId,
    DateTime? dataCriacao,
    this.dataAtualizacao,
  })  : dataHoraFim = dataHoraFim ??
            dataHoraInicio.add(const Duration(minutes: 50)),
        dataCriacao = dataCriacao ?? DateTime.now();

  StatusCompromisso get statusEnum => StatusCompromisso.fromString(status);

  set statusEnum(StatusCompromisso s) => status = s.value;

  bool get isAgendado => statusEnum == StatusCompromisso.agendado;
  bool get isRealizado => statusEnum == StatusCompromisso.realizado;
  bool get isCancelado => statusEnum == StatusCompromisso.cancelado;
  bool get isFaltou => statusEnum == StatusCompromisso.faltou;

  bool get isPendente => isAgendado;
  bool get isConcluido => isRealizado;

  String get horarioInicioFormatado {
    return '${dataHoraInicio.hour.toString().padLeft(2, '0')}:${dataHoraInicio.minute.toString().padLeft(2, '0')}';
  }

  String get horarioFimFormatado {
    return '${dataHoraFim.hour.toString().padLeft(2, '0')}:${dataHoraFim.minute.toString().padLeft(2, '0')}';
  }

  String get duracaoFormatada {
    final duracao = dataHoraFim.difference(dataHoraInicio);
    final horas = duracao.inHours;
    final minutos = duracao.inMinutes % 60;
    if (horas > 0 && minutos > 0) return '${horas}h ${minutos}min';
    if (horas > 0) return '${horas}h';
    return '${minutos}min';
  }

  Compromisso copyWith({
    String? id,
    String? pacienteId,
    DateTime? dataHoraInicio,
    DateTime? dataHoraFim,
    String? titulo,
    String? observacoes,
    String? status,
    String? sessaoId,
    DateTime? dataCriacao,
    DateTime? dataAtualizacao,
  }) {
    return Compromisso(
      id: id ?? this.id,
      pacienteId: pacienteId ?? this.pacienteId,
      dataHoraInicio: dataHoraInicio ?? this.dataHoraInicio,
      dataHoraFim: dataHoraFim ?? this.dataHoraFim,
      titulo: titulo ?? this.titulo,
      observacoes: observacoes ?? this.observacoes,
      status: status ?? this.status,
      sessaoId: sessaoId ?? this.sessaoId,
      dataCriacao: dataCriacao ?? this.dataCriacao,
      dataAtualizacao: dataAtualizacao ?? this.dataAtualizacao,
    );
  }
}
