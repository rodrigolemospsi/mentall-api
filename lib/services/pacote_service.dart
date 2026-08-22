import 'package:hive_ce/hive.dart';

import '../models/pacote.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class PacoteService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;

  PacoteService({this.encryption});

  final Box<Pacote> _box = Hive.box<Pacote>('pacotes');

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

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
      observacoes: _encrypt(observacoes),
    );
    _box.add(pacote);
    return pacote;
  }

  List<Pacote> obterPacotesAtivos(String pacienteId) {
    return _box.values
        .where((p) => p.pacienteId == pacienteId && p.ativo && !p.esgotado)
        .map(_decryptPacote)
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

    final pacote = _box.values.firstWhere((p) => p.id == pacotes.first.id);
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
        .map(_decryptPacote)
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
  }

  Pacote _decryptPacote(Pacote p) {
    return Pacote(
      id: p.id,
      pacienteId: p.pacienteId,
      totalSessoes: p.totalSessoes,
      sessoesRestantes: p.sessoesRestantes,
      valorTotal: p.valorTotal,
      dataCriacao: p.dataCriacao,
      ativo: p.ativo,
      observacoes: _decrypt(p.observacoes),
    );
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    if (encryption == null || !encryption!.configurado) return;
    final todos = _box.values.toList();
    for (final p in todos) {
      if (p.observacoes.startsWith('2:') || p.observacoes.startsWith('3:')) {
        await _box.put(
          p.key,
          Pacote(
            id: p.id,
            pacienteId: p.pacienteId,
            totalSessoes: p.totalSessoes,
            sessoesRestantes: p.sessoesRestantes,
            valorTotal: p.valorTotal,
            dataCriacao: p.dataCriacao,
            ativo: p.ativo,
            observacoes: _decrypt(p.observacoes),
          ),
        );
      }
    }
  }
}
