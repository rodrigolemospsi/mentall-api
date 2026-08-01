import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/avaliacao_inicial.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class AvaliacaoInicialService with EncryptedServiceMixin {
  @override
  final EncryptionService? encryption;
  Box get _box => Hive.box('avaliacoes_iniciais');

  AvaliacaoInicialService({EncryptionService? encryption}) : encryption = encryption;

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  AvaliacaoInicial? obterPorPaciente(String pacienteId) {
    for (final a in _box.values.whereType<AvaliacaoInicial>()) {
      if (a.pacienteId == pacienteId) return _decryptAvaliacao(a);
    }
    return null;
  }

  AvaliacaoInicial _decryptAvaliacao(AvaliacaoInicial a) {
    return a.copyWith(
      queixaPrincipal: _decrypt(a.queixaPrincipal),
      historicoClinico: _decrypt(a.historicoClinico),
      medicamentos: _decrypt(a.medicamentos),
      hipoteseDiagnostica: _decrypt(a.hipoteseDiagnostica),
      objetivosTerapeuticos: _decrypt(a.objetivosTerapeuticos),
      observacoes: _decrypt(a.observacoes),
    );
  }

  Future<void> salvar(AvaliacaoInicial avaliacao) async {
    avaliacao.queixaPrincipal = _encrypt(avaliacao.queixaPrincipal);
    avaliacao.historicoClinico = _encrypt(avaliacao.historicoClinico);
    avaliacao.medicamentos = _encrypt(avaliacao.medicamentos);
    avaliacao.hipoteseDiagnostica = _encrypt(avaliacao.hipoteseDiagnostica);
    avaliacao.objetivosTerapeuticos = _encrypt(avaliacao.objetivosTerapeuticos);
    avaliacao.observacoes = _encrypt(avaliacao.observacoes);
    avaliacao.dataAtualizacao = DateTime.now();

    final existente = obterPorPaciente(avaliacao.pacienteId);
    if (existente != null) {
      avaliacao.id = existente.id;
    } else {
      avaliacao.id = avaliacao.id.isEmpty ? const Uuid().v4() : avaliacao.id;
      avaliacao.dataCriacao = DateTime.now();
    }
    await _box.put(avaliacao.id, avaliacao);
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    final enc = encryption; if (enc == null || !enc.configurado) return;
    for (final a in _box.values.whereType<AvaliacaoInicial>()) {
      a.queixaPrincipal = _decrypt(a.queixaPrincipal);
      a.historicoClinico = _decrypt(a.historicoClinico);
      a.medicamentos = _decrypt(a.medicamentos);
      a.hipoteseDiagnostica = _decrypt(a.hipoteseDiagnostica);
      a.objetivosTerapeuticos = _decrypt(a.objetivosTerapeuticos);
      a.observacoes = _decrypt(a.observacoes);
      await a.save();
    }
  }
}
