import 'package:flutter/scheduler.dart';
import 'package:hive_ce/hive.dart';

import '../models/sessao.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';

class SessaoService with EncryptedServiceMixin {
  final Box<Sessao> _box = Hive.box<Sessao>('sessoes');
  @override
  final EncryptionService? encryption;
  final Map<String, int> _cacheProximoNumero = {};

  int? _cacheFrameHash;
  List<Sessao>? _cacheSessoes;

  SessaoService({this.encryption});

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

  List<Sessao> listarSessoesPorPeriodo(DateTime inicio, DateTime fim) {
    final cacheKey = Object.hash(
      inicio.millisecondsSinceEpoch,
      fim.millisecondsSinceEpoch,
      inicio.hour,
      fim.hour,
    );

    if (_cacheFrameHash == cacheKey && _cacheSessoes != null) {
      return _cacheSessoes!;
    }

    final sessoes = _box.values
        .where((s) =>
            !s.arquivada &&
            s.data.isAfter(inicio.subtract(const Duration(seconds: 1))) &&
            s.data.isBefore(fim.add(const Duration(seconds: 1))))
        .toList();
    sessoes.sort((a, b) => a.data.compareTo(b.data));
    _decryptSessoes(sessoes);

    _cacheFrameHash = cacheKey;
    _cacheSessoes = sessoes;

    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _cacheFrameHash = null;
        _cacheSessoes = null;
      });
    } catch (_) {}

    return sessoes;
  }

  List<Sessao> listarSessoesRecentes(String pacienteId, {int limite = 5}) {
    final sessoes = _box.values
        .where((s) => s.pacienteId == pacienteId && !s.arquivada)
        .toList();
    sessoes.sort((a, b) => b.data.compareTo(a.data));
    _decryptSessoes(sessoes);
    return sessoes.take(limite).toList();
  }

  /// Soma receita (pago) e pendente (a receber) das sessões ativas num período,
  /// **sem** descriptografar os campos clínicos. Os campos financeiros
  /// (`data`, `statusPagamento`, `valorSessao`) não são criptografados.
  ({double receita, double pendente}) somarFinanceiroPorPeriodo(
      DateTime inicio, DateTime fim) {
    double receita = 0;
    double pendente = 0;
    for (final s in _box.values) {
      if (s.arquivada) continue;
      if (!s.data.isAfter(inicio.subtract(const Duration(seconds: 1))) ||
          !s.data.isBefore(fim.add(const Duration(seconds: 1)))) {
        continue;
      }
      if (s.statusPagamento == 'pago') {
        receita += s.valorSessao;
      } else if (s.statusPagamento != 'convenio' && s.statusPagamento != 'pacote') {
        pendente += s.valorSessao;
      }
    }
    return (receita: receita, pendente: pendente);
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
    _cacheProximoNumero.remove(sessao.pacienteId);
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
    if (_cacheProximoNumero.containsKey(pacienteId)) {
      return _cacheProximoNumero[pacienteId]!;
    }

    int maiorNumero = 0;
    for (final sessao in _box.values) {
      if (sessao.pacienteId == pacienteId && sessao.numeroSessao > maiorNumero) {
        maiorNumero = sessao.numeroSessao;
      }
    }

    final proximo = maiorNumero + 1;
    _cacheProximoNumero[pacienteId] = proximo;
    return proximo;
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

  /// Conta sessões ativas (não arquivadas) dos últimos 30 dias **sem**
  /// descriptografar os campos clínicos (que não são necessários para a contagem).
  /// Evita o custo de N×20 decrypts AES-GCM na UI thread a cada evento.
  int contarSessoesAtivasUltimos30Dias() {
    final limite = DateTime.now().subtract(const Duration(days: 30));
    return _box.values
        .where((s) => !s.arquivada && s.data.isAfter(limite))
        .length;
  }

  int contarSessoesPendentesPorPaciente(String pacienteId) {
    return _box.values
        .where((s) =>
            s.pacienteId == pacienteId &&
            !s.arquivada &&
            s.revisaoPendente)
        .length;
  }

  Map<String, int> contarSessoesPendentesAgrupadas() {
    final mapa = <String, int>{};
    for (final s in _box.values) {
      if (!s.arquivada && s.revisaoPendente) {
        mapa[s.pacienteId] = (mapa[s.pacienteId] ?? 0) + 1;
      }
    }
    return mapa;
  }

  List<Sessao> listarSessoesPendentesRevisao() {
    final pendentes = _box.values
        .where((s) => !s.arquivada && s.revisaoPendente)
        .toList();
    pendentes.sort((a, b) => b.data.compareTo(a.data));
    _decryptSessoes(pendentes);
    return pendentes;
  }

  Stream<BoxEvent> observarSessoes() {
    return _box.watch();
  }

  Future<void> removerCriptografiaExistente() async {
    final enc = encryption; if (enc == null || !enc.configurado) return;

    for (final s in _box.values) {
      _decryptSessao(s);
      await s.save();
    }
  }

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

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
