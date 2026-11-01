import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import 'api_client.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';
import 'logger.dart';

class ContratoService with EncryptedServiceMixin {
  final Box<ContratoTerapeutico> _box = Hive.box<ContratoTerapeutico>('contratos');
  @override
  final EncryptionService? encryption;

  ContratoService({this.encryption});

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  ContratoTerapeutico? obterPorPaciente(String pacienteId) {
    final match = _box.values.where((c) => c.pacienteId == pacienteId && !c.arquivado);
    if (match.isEmpty) return null;
    final contratos = match.toList()..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    final c = contratos.first.copyWith();
    _decryptContrato(c);
    return c;
  }

  List<ContratoTerapeutico> listarPorPaciente(String pacienteId) {
    final lista = _box.values
        .where((c) => c.pacienteId == pacienteId)
        .map((c) => c.copyWith())
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    _decryptContratos(lista);
    return lista;
  }

  List<ContratoTerapeutico> listarPendentes() {
    final lista = _box.values
        .where((c) => c.status == 'pendente' || c.status == 'enviado')
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    _decryptContratos(lista);
    return lista;
  }

  int contarPendentes() {
    return _box.values.where((c) => c.status == 'pendente' || c.status == 'enviado').length;
  }

  /// Consulta o backend o status dos contratos pendentes/enviados e atualiza o
  /// Hive quando o aceite ocorreu. Se [pacienteId] for nulo, verifica todos os
  /// pacientes. Retorna quantos contratos foram atualizados.
  Future<int> sincronizarPendencias({String? pacienteId}) async {
    var atualizados = 0;
    final pendentes = _box.values
        .where((c) =>
            (pacienteId == null || c.pacienteId == pacienteId) &&
            (c.status == 'pendente' || c.status == 'enviado'))
        .toList();
    for (final contrato in pendentes) {
      // O box guarda token/url criptografados; descriptografa antes de usar.
      _decryptContrato(contrato);
      if (await verificarStatus(contrato)) {
        atualizados++;
      }
    }
    return atualizados;
  }

  Future<ContratoTerapeutico> criarContrato({
    required Paciente paciente,
    required PerfilProfissional perfil,
    String templateContrato = '',
  }) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) {
      Log.erro('Autenticação falhou ao criar contrato', contexto: 'ContratoService.criarContrato');
      throw Exception('Falha na autenticação com o servidor. Verifique credenciais em Configurações > Avançado.');
    }

    Log.auditoria('POST /contratos', contexto: 'ContratoService');
    final body = {
      'nome_paciente': paciente.nome,
      'nome_profissional': perfil.nome,
      'registro_profissional': perfil.registroProfissional,
      'termo_pessoa': perfil.termoSingular,
      'template_contrato': templateContrato,
      'tratamento': perfil.tratamento,
      'crp_verificado': perfil.crpVerificado,
      'cpf_profissional': perfil.cpf,
      'cnpj_profissional': perfil.cnpj,
    };
    var response = await ApiClient.post(
      '/contratos',
      body: body,
      customTimeout: const Duration(seconds: 30),
    );
    if (response.statusCode == 401) {
      // Token expirado/inválido: reautentica uma vez e repete.
      await ApiClient.forceReauthenticate();
      response = await ApiClient.post(
        '/contratos',
        body: body,
        customTimeout: const Duration(seconds: 30),
      );
    }

    Log.auditoria('POST /contratos response: ${response.statusCode}', contexto: 'ContratoService');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final contrato = ContratoTerapeutico(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pacienteId: paciente.id,
          token: data['token'] as String,
          url: data['url'] as String,
          dataCriacao: DateTime.now(),
          status: 'pendente',
        );
        final paraSalvar = contrato.copyWith();
        _encryptContrato(paraSalvar);
        await _box.add(paraSalvar);
        return contrato;
      }
      Log.erro('POST /contratos sucesso=false: ${response.body}', contexto: 'ContratoService');
      throw Exception('Servidor retornou sucesso=false: ${response.body}');
    }

    Log.erro('POST /contratos ${response.statusCode}: ${response.body}', contexto: 'ContratoService');
    throw Exception('Erro HTTP ${response.statusCode} do servidor: ${response.body}');
  }

  /// Persiste um contrato localmente (criptografa token/url antes de salvar).
  /// Usado por testes e pelo fluxo de restauração quando não há roundtrip
  /// com o backend.
  Future<void> criarLocalmente(ContratoTerapeutico contrato) async {
    final paraSalvar = contrato.copyWith();
    _encryptContrato(paraSalvar);
    await _box.add(paraSalvar);
  }

  /// Descobre a chave real do contrato no Hive (registros antigos usam
  /// chaves inteiras de `add`). Sem isso, `put(id)` criaria registro duplicado.
  dynamic _chaveDoContrato(String id) {
    for (final chave in _box.keys) {
      final valor = _box.get(chave);
      if (valor != null && valor.id == id) return chave;
    }
    return null;
  }

  Future<bool> marcarComoEnviado(ContratoTerapeutico contrato) async {
    // Atualiza o objeto do chamador (em texto claro) e persiste uma cópia
    // cifrada — evita que o cache do Hive guarde token/url sem cifra.
    contrato.status = 'enviado';
    contrato.dataEnvio = DateTime.now();
    final atual = contrato.copyWith();
    _encryptContrato(atual);
    final chave = _chaveDoContrato(atual.id);
    if (chave == null) return false;
    await _box.put(chave, atual);
    return true;
  }

  Future<bool> verificarStatus(ContratoTerapeutico contrato) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) return false;

    try {
      final path = '/contratos/${contrato.token}/status';
      var response = await ApiClient.get(path, customTimeout: const Duration(seconds: 30));
      if (response.statusCode == 401) {
        await ApiClient.forceReauthenticate();
        response = await ApiClient.get(path, customTimeout: const Duration(seconds: 30));
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['sucesso'] == true) {
          final novoStatus = data['status'] as String?;
          if (novoStatus == 'aceito') {
            final atual = contrato.copyWith();
            _decryptContrato(atual);
            final eraAceito = atual.isAceito;
            atual.status = 'aceito';
            atual.dataAceite = data['aceito_em'] != null
                ? DateTime.parse(data['aceito_em'] as String).toLocal()
                : atual.dataAceite ?? DateTime.now();
            atual.nomeAceite = data['nome_aceite'] as String? ?? '';
            atual.aceiteCodigo = data['aceite_codigo'] as String? ?? '';
            atual.aceiteHash = data['aceite_hash'] as String? ?? '';
            atual.aceiteVersao = data['aceite_versao'] as String? ?? '';
            atual.aceiteCpfMascarado =
                data['aceite_cpf_mascarado'] as String? ?? '';
            atual.aceiteIp = data['aceite_ip'] as String? ?? '';
            atual.aceiteUserAgent =
                data['aceite_user_agent'] as String? ?? '';
            atual.verificacaoUrl =
                data['verificacao_url'] as String? ?? '';
            atual.documentoTexto =
                data['documento_texto'] as String? ?? '';
            final paraSalvar = atual.copyWith();
            _encryptContrato(paraSalvar);
            final chave = _chaveDoContrato(paraSalvar.id);
            if (chave == null) return false;
            await _box.put(chave, paraSalvar);
            return !eraAceito || atual.aceiteCodigo.isNotEmpty;
          }
        }
      }
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'ContratoService.verificarStatus');
      return false;
    }
  }

  Future<void> arquivarContrato(ContratoTerapeutico contrato) async {
    contrato.arquivado = true;
    final atual = contrato.copyWith();
    _encryptContrato(atual);
    final chave = _chaveDoContrato(atual.id);
    if (chave != null) await _box.put(chave, atual);
  }

  Future<void> restaurarContrato(ContratoTerapeutico contrato) async {
    contrato.arquivado = false;
    final atual = contrato.copyWith();
    _encryptContrato(atual);
    final chave = _chaveDoContrato(atual.id);
    if (chave != null) await _box.put(chave, atual);
  }

  ContratoTerapeutico? obterArquivadoPorPaciente(String pacienteId) {
    final match = _box.values.where((c) => c.pacienteId == pacienteId && c.arquivado);
    if (match.isEmpty) return null;
    final contratos = match.toList()..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    final c = contratos.first.copyWith();
    _decryptContrato(c);
    return c;
  }

  Future<void> removerCriptografiaExistente() async {
    final enc = encryption; if (enc == null || !enc.configurado) return;
    for (final c in _box.values) {
      _decryptContrato(c);
      await c.save();
    }
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  void _encryptContrato(ContratoTerapeutico c) {
    c.nomeAceite = _encrypt(c.nomeAceite);
    c.token = _encrypt(c.token);
    c.url = _encrypt(c.url);
    c.aceiteCodigo = _encrypt(c.aceiteCodigo);
    c.aceiteHash = _encrypt(c.aceiteHash);
    c.aceiteVersao = _encrypt(c.aceiteVersao);
    c.aceiteCpfMascarado = _encrypt(c.aceiteCpfMascarado);
    c.aceiteIp = _encrypt(c.aceiteIp);
    c.aceiteUserAgent = _encrypt(c.aceiteUserAgent);
    c.verificacaoUrl = _encrypt(c.verificacaoUrl);
    c.documentoTexto = _encrypt(c.documentoTexto);
  }

  void _decryptContrato(ContratoTerapeutico c) {
    c.nomeAceite = _decrypt(c.nomeAceite);
    c.token = _decrypt(c.token);
    c.url = _decrypt(c.url);
    c.aceiteCodigo = _decrypt(c.aceiteCodigo);
    c.aceiteHash = _decrypt(c.aceiteHash);
    c.aceiteVersao = _decrypt(c.aceiteVersao);
    c.aceiteCpfMascarado = _decrypt(c.aceiteCpfMascarado);
    c.aceiteIp = _decrypt(c.aceiteIp);
    c.aceiteUserAgent = _decrypt(c.aceiteUserAgent);
    c.verificacaoUrl = _decrypt(c.verificacaoUrl);
    c.documentoTexto = _decrypt(c.documentoTexto);
  }

  void _decryptContratos(List<ContratoTerapeutico> lista) {
    for (final c in lista) {
      _decryptContrato(c);
    }
  }
}
