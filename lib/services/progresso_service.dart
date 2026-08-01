import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/progresso_sessao.dart';

class ProgressoService {
  final Box<ProgressoSessao> _box = Hive.box<ProgressoSessao>('progresso_sessoes');

  void salvar({
    required String pacienteId,
    required String sessaoId,
    required int numeroSessao,
    required List<Map<String, dynamic>> sintomas,
    required List<Map<String, dynamic>> metas,
    required String avaliacaoGeral,
    required String tendencia,
  }) {
    _box.put(
      sessaoId,
      ProgressoSessao(
        id: sessaoId,
        pacienteId: pacienteId,
        sessaoId: sessaoId,
        numeroSessao: numeroSessao,
        sintomasJson: jsonEncode(sintomas),
        metasJson: jsonEncode(metas),
        avaliacaoGeral: avaliacaoGeral,
        tendencia: tendencia,
        dataProcessamento: DateTime.now(),
      ),
    );
  }

  ProgressoSessao? obterPorSessao(String sessaoId) {
    return _box.get(sessaoId);
  }

  List<ProgressoSessao> obterPorPaciente(String pacienteId, {int limite = 20}) {
    return _box.values
        .where((p) => p.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.numeroSessao.compareTo(a.numeroSessao))
      ..take(limite);
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
