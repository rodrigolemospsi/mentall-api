import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/progresso_sessao.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class ProgressoService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;

  ProgressoService({this.encryption});

  final Box<ProgressoSessao> _box = Hive.box<ProgressoSessao>('progresso_sessoes');

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

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
        sintomasJson: _encrypt(jsonEncode(sintomas)),
        metasJson: _encrypt(jsonEncode(metas)),
        avaliacaoGeral: _encrypt(avaliacaoGeral),
        tendencia: _encrypt(tendencia),
        dataProcessamento: DateTime.now(),
      ),
    );
  }

  ProgressoSessao? obterPorSessao(String sessaoId) {
    final p = _box.get(sessaoId);
    if (p == null) return null;
    return _decryptProgresso(p);
  }

  List<ProgressoSessao> obterPorPaciente(String pacienteId, {int limite = 20}) {
    return _box.values
        .where((p) => p.pacienteId == pacienteId)
        .map(_decryptProgresso)
        .toList()
      ..sort((a, b) => b.numeroSessao.compareTo(a.numeroSessao))
      ..take(limite);
  }

  ProgressoSessao _decryptProgresso(ProgressoSessao p) {
    return ProgressoSessao(
      id: p.id,
      pacienteId: p.pacienteId,
      sessaoId: p.sessaoId,
      numeroSessao: p.numeroSessao,
      sintomasJson: _decrypt(p.sintomasJson),
      metasJson: _decrypt(p.metasJson),
      avaliacaoGeral: _decrypt(p.avaliacaoGeral),
      tendencia: _decrypt(p.tendencia),
      dataProcessamento: p.dataProcessamento,
    );
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    if (encryption == null || !encryption!.configurado) return;
    final todos = _box.values.toList();
    for (final p in todos) {
      if (p.sintomasJson.startsWith('2:') || p.sintomasJson.startsWith('3:') ||
          p.metasJson.startsWith('2:') || p.metasJson.startsWith('3:') ||
          p.avaliacaoGeral.startsWith('2:') || p.avaliacaoGeral.startsWith('3:') ||
          p.tendencia.startsWith('2:') || p.tendencia.startsWith('3:')) {
        await _box.put(
          p.key,
          ProgressoSessao(
            id: p.id,
            pacienteId: p.pacienteId,
            sessaoId: p.sessaoId,
            numeroSessao: p.numeroSessao,
            sintomasJson: _decrypt(p.sintomasJson),
            metasJson: _decrypt(p.metasJson),
            avaliacaoGeral: _decrypt(p.avaliacaoGeral),
            tendencia: _decrypt(p.tendencia),
            dataProcessamento: p.dataProcessamento,
          ),
        );
      }
    }
  }
}
