import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/avaliacao_inicial.dart';
import 'encryption_service.dart';

class AvaliacaoInicialService {
  final EncryptionService? _encryption;
  Box<AvaliacaoInicial> get _box => Hive.box<AvaliacaoInicial>('avaliacoes_iniciais');

  AvaliacaoInicialService({EncryptionService? encryption}) : _encryption = encryption;

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption.descriptografar(value);
  }

  AvaliacaoInicial? obterPorPaciente(String pacienteId) {
    return _box.values.cast<AvaliacaoInicial?>().firstWhere(
      (a) => a!.pacienteId == pacienteId,
      orElse: () => null,
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

  void removerCriptografiaExistente() {
    if (_encryption == null || !_encryption.configurado) return;
    for (final a in _box.values) {
      a.queixaPrincipal = _decrypt(a.queixaPrincipal);
      a.historicoClinico = _decrypt(a.historicoClinico);
      a.medicamentos = _decrypt(a.medicamentos);
      a.hipoteseDiagnostica = _decrypt(a.hipoteseDiagnostica);
      a.objetivosTerapeuticos = _decrypt(a.objetivosTerapeuticos);
      a.observacoes = _decrypt(a.observacoes);
    }
  }

}
