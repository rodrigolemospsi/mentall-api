import 'package:hive_ce/hive.dart';

import '../models/sessao.dart';
import 'encryption_service.dart';

class SessaoService {
  final Box<Sessao> _box = Hive.box<Sessao>('sessoes');
  final EncryptionService? _encryption;

  SessaoService({EncryptionService? encryption}) : _encryption = encryption;

  List<Sessao> listarTodasSessoes() {
    final sessoes = _box.values.toList();
    sessoes.sort((a, b) => b.data.compareTo(a.data));
    _decryptSessoes(sessoes);
    return sessoes;
  }

  List<Sessao> listarTodasSessoesAtivas() {
    final sessoes = _box.values
        .where((sessao) => !sessao.arquivada)
        .toList();
    sessoes.sort((a, b) => b.data.compareTo(a.data));
    _decryptSessoes(sessoes);
    return sessoes;
  }

  List<Sessao> listarTodasSessoesArquivadas() {
    final sessoes = _box.values
        .where((sessao) => sessao.arquivada)
        .toList();
    sessoes.sort((a, b) => b.data.compareTo(a.data));
    _decryptSessoes(sessoes);
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
    _decryptSessoes(sessoes);
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
    _decryptSessoes(sessoes);
    return sessoes;
  }

  Future<void> adicionarSessao(Sessao sessao) async {
    sessao.arquivada = false;
    _encryptSessao(sessao);
    await _box.add(sessao);
    _decryptSessao(sessao);
  }

  Future<void> atualizarSessao(Sessao sessao) async {
    _encryptSessao(sessao);
    await sessao.save();
    _decryptSessao(sessao);
  }

  Future<void> arquivarSessao(Sessao sessao) async {
    sessao.arquivada = true;
    _encryptSessao(sessao);
    await sessao.save();
    _decryptSessao(sessao);
  }

  Future<void> restaurarSessao(Sessao sessao) async {
    sessao.arquivada = false;
    _encryptSessao(sessao);
    await sessao.save();
    _decryptSessao(sessao);
  }

  int proximoNumeroSessao(String pacienteId) {
    final sessoes = _box.values
        .where((sessao) => sessao.pacienteId == pacienteId)
        .toList();

    if (sessoes.isEmpty) return 1;

    final maiorNumero = sessoes
        .map((sessao) => sessao.numeroSessao)
        .reduce((a, b) => a > b ? a : b);

    return maiorNumero + 1;
  }

  Sessao? buscarSessaoPorId(String id) {
    final match = _box.values.where((sessao) => sessao.id == id);
    if (match.isEmpty) return null;
    final sessao = match.first;
    _decryptSessao(sessao);
    return sessao;
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

  String _encrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption!.criptografar(value);
  }

  String _decrypt(String value) {
    if (_encryption == null || value.isEmpty) return value;
    return _encryption!.descriptografar(value);
  }

  void _encryptSessao(Sessao s) {
    s.temaPrincipal = _encrypt(s.temaPrincipal);
    s.eventosImportantes = _encrypt(s.eventosImportantes);
    s.pensamentosAutomaticos = _encrypt(s.pensamentosAutomaticos);
    s.emocoes = _encrypt(s.emocoes);
    s.comportamentos = _encrypt(s.comportamentos);
    s.intervencoes = _encrypt(s.intervencoes);
    s.tecnicasTcc = _encrypt(s.tecnicasTcc);
    s.tarefaCasa = _encrypt(s.tarefaCasa);
    s.evolucaoClinica = _encrypt(s.evolucaoClinica);
    s.planoProximaSessao = _encrypt(s.planoProximaSessao);
    s.observacoes = _encrypt(s.observacoes);
    s.relatoPosSessao = _encrypt(s.relatoPosSessao);
    s.apontamentosCopiloto = _encrypt(s.apontamentosCopiloto);
    s.transcricaoRelato = _encrypt(s.transcricaoRelato);
    s.transcricaoRevisada = _encrypt(s.transcricaoRevisada);
    s.erroProcessamentoIa = _encrypt(s.erroProcessamentoIa);
    s.audioRelatoBase64 = _encrypt(s.audioRelatoBase64);
    s.audioRelatoPath = _encrypt(s.audioRelatoPath);
    s.artigosSugeridos = _encrypt(s.artigosSugeridos);
  }

  void _decryptSessao(Sessao s) {
    s.temaPrincipal = _decrypt(s.temaPrincipal);
    s.eventosImportantes = _decrypt(s.eventosImportantes);
    s.pensamentosAutomaticos = _decrypt(s.pensamentosAutomaticos);
    s.emocoes = _decrypt(s.emocoes);
    s.comportamentos = _decrypt(s.comportamentos);
    s.intervencoes = _decrypt(s.intervencoes);
    s.tecnicasTcc = _decrypt(s.tecnicasTcc);
    s.tarefaCasa = _decrypt(s.tarefaCasa);
    s.evolucaoClinica = _decrypt(s.evolucaoClinica);
    s.planoProximaSessao = _decrypt(s.planoProximaSessao);
    s.observacoes = _decrypt(s.observacoes);
    s.relatoPosSessao = _decrypt(s.relatoPosSessao);
    s.apontamentosCopiloto = _decrypt(s.apontamentosCopiloto);
    s.transcricaoRelato = _decrypt(s.transcricaoRelato);
    s.transcricaoRevisada = _decrypt(s.transcricaoRevisada);
    s.erroProcessamentoIa = _decrypt(s.erroProcessamentoIa);
    s.audioRelatoBase64 = _decrypt(s.audioRelatoBase64);
    s.audioRelatoPath = _decrypt(s.audioRelatoPath);
    s.artigosSugeridos = _decrypt(s.artigosSugeridos);
  }

  void _decryptSessoes(List<Sessao> sessoes) {
    for (final s in sessoes) {
      _decryptSessao(s);
    }
  }
}
