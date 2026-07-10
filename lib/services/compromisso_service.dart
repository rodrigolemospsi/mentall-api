import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';

class CompromissoService {
  final Box<Compromisso> _box = Hive.box<Compromisso>('compromissos');

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

  Future<void> atualizar(Compromisso compromisso) async {
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> remover(Compromisso compromisso) async {
    await compromisso.delete();
  }

  Future<void> marcarComoRealizado(Compromisso compromisso) async {
    compromisso.statusEnum = StatusCompromisso.realizado;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> marcarComoCancelado(Compromisso compromisso) async {
    compromisso.statusEnum = StatusCompromisso.cancelado;
    compromisso.dataAtualizacao = DateTime.now();
    await compromisso.save();
  }

  Future<void> marcarComoFaltou(Compromisso compromisso) async {
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
