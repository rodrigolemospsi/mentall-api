import 'package:hive_ce/hive.dart';

import '../models/sessao.dart';

class SessaoService {
  final Box<Sessao> _box = Hive.box<Sessao>('sessoes');

  List<Sessao> listarTodasSessoes() {
    final sessoes = _box.values.toList();

    sessoes.sort((a, b) => b.data.compareTo(a.data));

    return sessoes;
  }

  List<Sessao> listarTodasSessoesAtivas() {
    final sessoes = _box.values
        .where((sessao) => !sessao.arquivada)
        .toList();

    sessoes.sort((a, b) => b.data.compareTo(a.data));

    return sessoes;
  }

  List<Sessao> listarTodasSessoesArquivadas() {
    final sessoes = _box.values
        .where((sessao) => sessao.arquivada)
        .toList();

    sessoes.sort((a, b) => b.data.compareTo(a.data));

    return sessoes;
  }

  List<Sessao> listarSessoesDoPaciente(String pacienteId) {
    final sessoes = _box.values
        .where(
          (sessao) =>
              sessao.pacienteId == pacienteId && !sessao.arquivada,
        )
        .toList();

    sessoes.sort((a, b) => b.data.compareTo(a.data));

    return sessoes;
  }

  List<Sessao> listarSessoesArquivadasDoPaciente(String pacienteId) {
    final sessoes = _box.values
        .where(
          (sessao) =>
              sessao.pacienteId == pacienteId && sessao.arquivada,
        )
        .toList();

    sessoes.sort((a, b) => b.data.compareTo(a.data));

    return sessoes;
  }

  Future<void> adicionarSessao(Sessao sessao) async {
    sessao.arquivada = false;
    await _box.add(sessao);
  }

  Future<void> atualizarSessao(Sessao sessao) async {
    await sessao.save();
  }

  Future<void> arquivarSessao(Sessao sessao) async {
    sessao.arquivada = true;
    await sessao.save();
  }

  Future<void> restaurarSessao(Sessao sessao) async {
    sessao.arquivada = false;
    await sessao.save();
  }

  int proximoNumeroSessao(String pacienteId) {
    final sessoes = _box.values
        .where((sessao) => sessao.pacienteId == pacienteId)
        .toList();

    if (sessoes.isEmpty) {
      return 1;
    }

    final maiorNumero = sessoes
        .map((sessao) => sessao.numeroSessao)
        .reduce((a, b) => a > b ? a : b);

    return maiorNumero + 1;
  }

  Sessao? buscarSessaoPorId(String id) {
    final match = _box.values.where((sessao) => sessao.id == id);
    return match.isNotEmpty ? match.first : null;
  }

  int contarSessoesDoPaciente(String pacienteId) {
    return _box.values
        .where(
          (sessao) =>
              sessao.pacienteId == pacienteId && !sessao.arquivada,
        )
        .length;
  }

  int contarSessoesArquivadasDoPaciente(String pacienteId) {
    return _box.values
        .where(
          (sessao) =>
              sessao.pacienteId == pacienteId && sessao.arquivada,
        )
        .length;
  }

  int contarSessoesPendentesRevisao() {
    return _box.values
        .where((s) => !s.arquivada && s.revisaoPendente)
        .length;
  }

  Stream<BoxEvent> observarSessoes() {
    return _box.watch();
  }
}