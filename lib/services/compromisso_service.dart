import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import 'lembrete_service.dart';

class CompromissoService {
  final Box<Compromisso> _box = Hive.box<Compromisso>('compromissos');
  final LembreteService _lembreteService = LembreteService();

  List<Compromisso> listarTodos() {
    final compromissos = _box.values.toList();
    compromissos.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return compromissos;
  }

  List<Compromisso> listarPorData(DateTime data) {
    final inicioDia = DateTime(data.year, data.month, data.day);
    final fimDia = inicioDia.add(const Duration(days: 1));

    final compromissos = _box.values
        .where((c) =>
            c.dataHoraInicio.isAfter(inicioDia.subtract(const Duration(seconds: 1))) &&
            c.dataHoraInicio.isBefore(fimDia))
        .toList();
    compromissos.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return compromissos;
  }

  List<Compromisso> listarPorPaciente(String pacienteId) {
    final compromissos = _box.values
        .where((c) => c.pacienteId == pacienteId)
        .toList();
    compromissos.sort((a, b) => b.dataHoraInicio.compareTo(a.dataHoraInicio));
    return compromissos;
  }

  List<Compromisso> listarPorSemana(DateTime data) {
    final segunda = data.subtract(Duration(days: data.weekday - 1));
    final inicio = DateTime(segunda.year, segunda.month, segunda.day);
    final fim = inicio.add(const Duration(days: 7));

    final compromissos = _box.values
        .where((c) =>
            c.dataHoraInicio.isAfter(
                inicio.subtract(const Duration(seconds: 1))) &&
            c.dataHoraInicio.isBefore(fim))
        .toList();
    compromissos.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return compromissos;
  }

  List<Compromisso> listarPorMes(DateTime data) {
    final inicioMes = DateTime(data.year, data.month, 1);
    final fimMes = DateTime(data.year, data.month + 1, 0, 23, 59, 59);
    return _box.values
        .where((c) =>
            c.dataHoraInicio.isAfter(inicioMes.subtract(const Duration(seconds: 1))) &&
            c.dataHoraInicio.isBefore(fimMes.add(const Duration(seconds: 1))))
        .toList();
  }

  List<Compromisso> listarHoje() {
    return listarPorData(DateTime.now());
  }

  List<Compromisso> listarProximos() {
    final agora = DateTime.now();
    final inicioHoje = DateTime(agora.year, agora.month, agora.day);
    final fimHoje = inicioHoje.add(const Duration(days: 1));

    final compromissos = _box.values
        .where((c) =>
            c.dataHoraInicio.isAfter(fimHoje.subtract(const Duration(seconds: 1))) &&
            c.statusEnum == StatusCompromisso.agendado)
        .toList();
    compromissos.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return compromissos;
  }

  int contarHoje() {
    return listarHoje().length;
  }

  bool temCompromissosHoje() {
    return contarHoje() > 0;
  }

  Compromisso? buscarPorSessaoId(String sessaoId) {
    final match = _box.values.where((c) => c.sessaoId == sessaoId);
    return match.isEmpty ? null : match.first;
  }

  Future<void> adicionar(Compromisso compromisso) async {
    await _box.add(compromisso);
  }

  Future<List<Compromisso>> adicionarComRecorrencia(
    Compromisso compromisso,
  ) async {
    final gerados = <Compromisso>[];
    await _box.add(compromisso);
    gerados.add(compromisso);

    final freq = compromisso.recorrenciaEnum;
    if (!freq.temRecorrencia) return gerados;

    final limite = compromisso.dataLimiteRecorrencia ??
        compromisso.dataHoraInicio
            .add(const Duration(days: 180));

    var index = 1;
    while (true) {
      final proxima = _proximaData(
        compromisso.dataHoraInicio,
        freq,
        index,
      );
      if (proxima.isAfter(limite)) break;
      if (index > 52) break;

      final copia = Compromisso(
        id: '${compromisso.id}_$index',
        pacienteId: compromisso.pacienteId,
        dataHoraInicio: proxima,
        dataHoraFim: proxima.add(
          compromisso.dataHoraFim.difference(compromisso.dataHoraInicio),
        ),
        titulo: compromisso.titulo,
        observacoes: compromisso.observacoes,
        lembreteAtivado: compromisso.lembreteAtivado,
        minutosAntecedencia: compromisso.minutosAntecedencia,
        mensagemLembrete: compromisso.mensagemLembrete,
        recorrencia: '',
        compromissoPaiId: compromisso.id,
      );
      await _box.add(copia);
      gerados.add(copia);
      index++;
    }

    return gerados;
  }

  DateTime _proximaData(
    DateTime base,
    FrequenciaRecorrencia freq,
    int indice,
  ) {
    switch (freq) {
      case FrequenciaRecorrencia.semanal:
        return base.add(Duration(days: 7 * indice));
      case FrequenciaRecorrencia.quinzenal:
        return base.add(Duration(days: 14 * indice));
      case FrequenciaRecorrencia.mensal:
        return DateTime(
          base.year,
          base.month + indice,
          base.day,
          base.hour,
          base.minute,
        );
      case FrequenciaRecorrencia.nenhuma:
        return base;
    }
  }

  Future<void> atualizar(Compromisso compromisso) async {
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> remover(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    await compromisso.delete();
  }

  Future<void> marcarComoRealizado(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    compromisso.statusEnum = StatusCompromisso.realizado;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> marcarComoCancelado(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    compromisso.statusEnum = StatusCompromisso.cancelado;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> marcarComoFaltou(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    compromisso.statusEnum = StatusCompromisso.faltou;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> marcarComoAgendado(Compromisso compromisso) async {
    compromisso.statusEnum = StatusCompromisso.agendado;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> vincularSessao(Compromisso compromisso, String sessaoId) async {
    compromisso.sessaoId = sessaoId;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
