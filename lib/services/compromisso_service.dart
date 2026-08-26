import 'package:hive_ce/hive.dart';

import '../models/compromisso.dart';
import '../models/enums.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';
import 'lembrete_service.dart';

class CompromissoService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;

  CompromissoService({this.encryption});

  final Box<Compromisso> _box = Hive.box<Compromisso>('compromissos');
  final LembreteService _lembreteService = LembreteService();

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  Compromisso _decryptCompromisso(Compromisso c) {
    c.titulo = _decrypt(c.titulo);
    c.observacoes = _decrypt(c.observacoes);
    return c;
  }

  void _encryptCompromisso(Compromisso c) {
    c.titulo = _encrypt(c.titulo);
    c.observacoes = _encrypt(c.observacoes);
  }

  List<Compromisso> listarTodos() {
    final compromissos = _box.values.map(_decryptCompromisso).toList();
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
        .map(_decryptCompromisso)
        .toList();
    compromissos.sort((a, b) => a.dataHoraInicio.compareTo(b.dataHoraInicio));
    return compromissos;
  }

  List<Compromisso> listarPorPaciente(String pacienteId) {
    final compromissos = _box.values
        .where((c) => c.pacienteId == pacienteId)
        .map(_decryptCompromisso)
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
        .map(_decryptCompromisso)
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
        .map(_decryptCompromisso)
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
        .map(_decryptCompromisso)
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
    return match.isNotEmpty ? _decryptCompromisso(match.first) : null;
  }

  Compromisso? obterPorId(String id) {
    try {
      return _decryptCompromisso(_box.values.firstWhere((c) => c.id == id));
    } catch (_) {
      return null;
    }
  }

  List<Compromisso> verificarConflitos(
    DateTime inicio,
    DateTime fim, {
    String? ignorarId,
  }) {
    return _box.values.where((c) {
      if (c.status == 'cancelado') return false;
      if (ignorarId != null && c.id == ignorarId) return false;
      return c.dataHoraInicio.isBefore(fim) &&
          c.dataHoraFim.isAfter(inicio);
    }).map(_decryptCompromisso).toList();
  }

  Future<void> adicionar(Compromisso compromisso) async {
    await _box.add(Compromisso(
      id: compromisso.id,
      pacienteId: compromisso.pacienteId,
      dataHoraInicio: compromisso.dataHoraInicio,
      dataHoraFim: compromisso.dataHoraFim,
      titulo: _encrypt(compromisso.titulo),
      observacoes: _encrypt(compromisso.observacoes),
      status: compromisso.status,
      sessaoId: compromisso.sessaoId,
      dataCriacao: compromisso.dataCriacao,
      dataAtualizacao: compromisso.dataAtualizacao,
      lembreteAtivado: compromisso.lembreteAtivado,
      minutosAntecedencia: compromisso.minutosAntecedencia,
      mensagemLembrete: compromisso.mensagemLembrete,
      recorrencia: compromisso.recorrencia,
      dataLimiteRecorrencia: compromisso.dataLimiteRecorrencia,
      compromissoPaiId: compromisso.compromissoPaiId,
      canalLembrete: compromisso.canalLembrete,
    ));
  }

  Future<List<Compromisso>> adicionarComRecorrencia(
    Compromisso compromisso,
  ) async {
    final gerados = <Compromisso>[];
    await adicionar(compromisso);
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
        titulo: _encrypt(compromisso.titulo),
        observacoes: _encrypt(compromisso.observacoes),
        status: compromisso.status,
        sessaoId: compromisso.sessaoId,
        dataCriacao: DateTime.now(),
        lembreteAtivado: compromisso.lembreteAtivado,
        minutosAntecedencia: compromisso.minutosAntecedencia,
        mensagemLembrete: compromisso.mensagemLembrete,
        recorrencia: '',
        compromissoPaiId: compromisso.id,
        canalLembrete: compromisso.canalLembrete,
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
    final original = _box.values.where((c) => c.id == compromisso.id);
    final key = original.isNotEmpty ? original.first.key : compromisso.key;
    await _box.put(
      key,
      Compromisso(
        id: compromisso.id,
        pacienteId: compromisso.pacienteId,
        dataHoraInicio: compromisso.dataHoraInicio,
        dataHoraFim: compromisso.dataHoraFim,
        titulo: _encrypt(compromisso.titulo),
        observacoes: _encrypt(compromisso.observacoes),
        status: compromisso.status,
        sessaoId: compromisso.sessaoId,
        dataCriacao: compromisso.dataCriacao,
        dataAtualizacao: compromisso.dataAtualizacao,
        lembreteAtivado: compromisso.lembreteAtivado,
        minutosAntecedencia: compromisso.minutosAntecedencia,
        mensagemLembrete: compromisso.mensagemLembrete,
        recorrencia: compromisso.recorrencia,
        dataLimiteRecorrencia: compromisso.dataLimiteRecorrencia,
        compromissoPaiId: compromisso.compromissoPaiId,
        canalLembrete: compromisso.canalLembrete,
      ),
    );
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
    _encryptCompromisso(compromisso);
    await compromisso.save();
    _decryptCompromisso(compromisso);
  }

  Future<void> marcarComoCancelado(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    compromisso.statusEnum = StatusCompromisso.cancelado;
    compromisso.dataAtualizacao = DateTime.now();
    _encryptCompromisso(compromisso);
    await compromisso.save();
    _decryptCompromisso(compromisso);
  }

  Future<void> marcarComoFaltou(Compromisso compromisso) async {
    try {
      await _lembreteService.cancelarLembrete(compromisso.id);
    } catch (_) {}
    compromisso.statusEnum = StatusCompromisso.faltou;
    compromisso.dataAtualizacao = DateTime.now();
    _encryptCompromisso(compromisso);
    await compromisso.save();
    _decryptCompromisso(compromisso);
  }

  Future<void> marcarComoAgendado(Compromisso compromisso) async {
    compromisso.statusEnum = StatusCompromisso.agendado;
    compromisso.dataAtualizacao = DateTime.now();
    _encryptCompromisso(compromisso);
    await compromisso.save();
    _decryptCompromisso(compromisso);
  }

  Future<void> vincularSessao(Compromisso compromisso, String sessaoId) async {
    compromisso.sessaoId = sessaoId;
    compromisso.dataAtualizacao = DateTime.now();
    _encryptCompromisso(compromisso);
    await compromisso.save();
    _decryptCompromisso(compromisso);
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    if (encryption == null || !encryption!.configurado) return;
    final todos = _box.values.toList();
    for (final c in todos) {
      if (c.titulo.startsWith('2:') || c.titulo.startsWith('3:') ||
          c.observacoes.startsWith('2:') || c.observacoes.startsWith('3:')) {
        await _box.put(
          c.key,
          Compromisso(
            id: c.id,
            pacienteId: c.pacienteId,
            dataHoraInicio: c.dataHoraInicio,
            dataHoraFim: c.dataHoraFim,
            titulo: _decrypt(c.titulo),
            observacoes: _decrypt(c.observacoes),
            status: c.status,
            sessaoId: c.sessaoId,
            dataCriacao: c.dataCriacao,
            dataAtualizacao: c.dataAtualizacao,
            lembreteAtivado: c.lembreteAtivado,
            minutosAntecedencia: c.minutosAntecedencia,
            mensagemLembrete: c.mensagemLembrete,
            recorrencia: c.recorrencia,
            dataLimiteRecorrencia: c.dataLimiteRecorrencia,
            compromissoPaiId: c.compromissoPaiId,
            canalLembrete: c.canalLembrete,
          ),
        );
      }
    }
  }
}
