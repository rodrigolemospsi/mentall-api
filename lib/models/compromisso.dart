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

  @HiveField(10)
  bool lembreteAtivado;

  @HiveField(11)
  int minutosAntecedencia;

  @HiveField(12)
  String mensagemLembrete;

  @HiveField(13)
  String recorrencia;

  @HiveField(14)
  DateTime? dataLimiteRecorrencia;

  @HiveField(15)
  String? compromissoPaiId;

  @HiveField(16)
  String canalLembrete;

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
    this.lembreteAtivado = false,
    this.minutosAntecedencia = 1440,
    this.mensagemLembrete = '',
    this.recorrencia = '',
    this.dataLimiteRecorrencia,
    this.compromissoPaiId,
    this.canalLembrete = 'whatsapp',
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

  FrequenciaRecorrencia get recorrenciaEnum =>
      FrequenciaRecorrencia.fromString(recorrencia);

  bool get temRecorrencia => recorrenciaEnum.temRecorrencia;

  bool get ehFilhoDeRecorrencia => compromissoPaiId != null;

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
    bool? lembreteAtivado,
    int? minutosAntecedencia,
    String? mensagemLembrete,
    String? recorrencia,
    DateTime? dataLimiteRecorrencia,
    String? compromissoPaiId,
    String? canalLembrete,
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
      lembreteAtivado: lembreteAtivado ?? this.lembreteAtivado,
      minutosAntecedencia: minutosAntecedencia ?? this.minutosAntecedencia,
      mensagemLembrete: mensagemLembrete ?? this.mensagemLembrete,
      recorrencia: recorrencia ?? this.recorrencia,
      dataLimiteRecorrencia:
          dataLimiteRecorrencia ?? this.dataLimiteRecorrencia,
      compromissoPaiId: compromissoPaiId ?? this.compromissoPaiId,
      canalLembrete: canalLembrete ?? this.canalLembrete,
    );
  }

  String gerarMensagemLembretePadrao(String nomePaciente, String nomeProfissional) {
    return 'Olá {nome}, lembrete da sua sessao com {profissional} '
        'em {data} as {hora}. Ate la!';
  }

  String formatarMensagemLembrete(String nomePaciente, String nomeProfissional) {
    final data = '${dataHoraInicio.day.toString().padLeft(2, '0')}/'
        '${dataHoraInicio.month.toString().padLeft(2, '0')}/'
        '${dataHoraInicio.year}';
    final hora = horarioInicioFormatado;
    var msg = mensagemLembrete.isNotEmpty
        ? mensagemLembrete
        : gerarMensagemLembretePadrao(nomePaciente, nomeProfissional);
    return msg
        .replaceAll('{nome}', nomePaciente)
        .replaceAll('{profissional}', nomeProfissional)
        .replaceAll('{data}', data)
        .replaceAll('{hora}', hora);
  }

  DateTime get horarioLembrete =>
      dataHoraInicio.subtract(Duration(minutes: minutosAntecedencia));

  String get antecedenciaFormatada {
    if (minutosAntecedencia < 60) return '${minutosAntecedencia}min';
    final horas = minutosAntecedencia ~/ 60;
    final mins = minutosAntecedencia % 60;
    if (mins == 0) return '${horas}h';
    return '${horas}h${mins}min';
  }
}
