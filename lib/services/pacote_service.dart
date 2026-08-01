import 'package:hive_ce/hive.dart';

import '../models/pacote.dart';

class PacoteService {
  final Box<Pacote> _box = Hive.box<Pacote>('pacotes');

  Pacote criar({
    required String pacienteId,
    required int totalSessoes,
    required double valorTotal,
    String observacoes = '',
  }) {
    final pacote = Pacote(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      pacienteId: pacienteId,
      totalSessoes: totalSessoes,
      sessoesRestantes: totalSessoes,
      valorTotal: valorTotal,
      dataCriacao: DateTime.now(),
      ativo: true,
      observacoes: observacoes,
    );
    _box.add(pacote);
    return pacote;
  }

  List<Pacote> obterPacotesAtivos(String pacienteId) {
    return _box.values
        .where((p) => p.pacienteId == pacienteId && p.ativo && !p.esgotado)
        .toList()
      ..sort((a, b) => a.dataCriacao.compareTo(b.dataCriacao));
  }

  int totalSessoesRestantes(String pacienteId) {
    return obterPacotesAtivos(pacienteId)
        .fold(0, (sum, p) => sum + p.sessoesRestantes);
  }

  double? valorPorSessaoAtivo(String pacienteId) {
    final pacotes = obterPacotesAtivos(pacienteId);
    if (pacotes.isEmpty) return null;
    return pacotes.first.valorPorSessao;
  }

  void consumirSessao(String pacienteId) {
    final pacotes = obterPacotesAtivos(pacienteId);
    if (pacotes.isEmpty) return;

    final pacote = pacotes.first;
    pacote.sessoesRestantes -= 1;
    if (pacote.sessoesRestantes <= 0) {
      pacote.sessoesRestantes = 0;
      pacote.ativo = false;
    }
    pacote.save();
  }

  List<Pacote> listarPorPaciente(String pacienteId) {
    return _box.values
        .where((p) => p.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
