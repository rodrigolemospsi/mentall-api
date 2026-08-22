import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;

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
    final c = contratos.first;
    _decryptContrato(c);
    return c;
  }

  List<ContratoTerapeutico> listarPorPaciente(String pacienteId) {
    final lista = _box.values
        .where((c) => c.pacienteId == pacienteId)
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

  Future<ContratoTerapeutico> criarContrato({
    required Paciente paciente,
    required PerfilProfissional perfil,
    String templateContrato = '',
  }) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) {
      Log.erro('Autenticacao falhou ao criar contrato', contexto: 'ContratoService.criarContrato');
      throw Exception('Falha na autenticacao com o servidor. Verifique credenciais em Configuracoes > Avancado.');
    }

    final url = '${ApiClient.baseUrl}/contratos';
    Log.auditoria('POST $url', contexto: 'ContratoService');
    final response = await http
        .post(
          Uri.parse(url),
          headers: ApiClient.defaultHeaders(),
          body: jsonEncode({
            'nome_paciente': paciente.nome,
            'nome_profissional': perfil.nome,
            'registro_profissional': perfil.registroProfissional,
            'termo_pessoa': perfil.termoSingular,
            'template_contrato': templateContrato,
            'tratamento': perfil.tratamento,
            'crp_verificado': perfil.crpVerificado,
          }),
        )
          .timeout(const Duration(seconds: 30));

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
        _encryptContrato(contrato);
        await _box.add(contrato);
        _decryptContrato(contrato);
        return contrato;
      }
      Log.erro('POST /contratos sucesso=false: ${response.body}', contexto: 'ContratoService');
      throw Exception('Servidor retornou sucesso=false: ${response.body}');
    }

    Log.erro('POST /contratos ${response.statusCode}: ${response.body}', contexto: 'ContratoService');
    throw Exception('Erro HTTP ${response.statusCode} do servidor: ${response.body}');
  }

  Future<bool> marcarComoEnviado(ContratoTerapeutico contrato) async {
    contrato.status = 'enviado';
    contrato.dataEnvio = DateTime.now();
    _encryptContrato(contrato);
    await contrato.save();
    _decryptContrato(contrato);
    return true;
  }

  Future<bool> verificarStatus(ContratoTerapeutico contrato) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) return false;

    try {
      final response = await http
          .get(
            Uri.parse('${ApiClient.baseUrl}/contratos/${contrato.token}/status'),
            headers: ApiClient.defaultHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['sucesso'] == true) {
          final novoStatus = data['status'] as String?;
          if (novoStatus == 'aceito' && !contrato.isAceito) {
            _decryptContrato(contrato);
            contrato.status = 'aceito';
            contrato.dataAceite = data['aceito_em'] != null
                ? DateTime.parse(data['aceito_em'] as String).toLocal()
                : DateTime.now();
            contrato.nomeAceite = data['nome_aceite'] as String? ?? '';
            _encryptContrato(contrato);
            await contrato.save();
            _decryptContrato(contrato);
            return true;
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
    _decryptContrato(contrato);
    contrato.arquivado = true;
    _encryptContrato(contrato);
    await contrato.save();
    _decryptContrato(contrato);
  }

  Future<void> restaurarContrato(ContratoTerapeutico contrato) async {
    _decryptContrato(contrato);
    contrato.arquivado = false;
    _encryptContrato(contrato);
    await contrato.save();
    _decryptContrato(contrato);
  }

  ContratoTerapeutico? obterArquivadoPorPaciente(String pacienteId) {
    final match = _box.values.where((c) => c.pacienteId == pacienteId && c.arquivado);
    if (match.isEmpty) return null;
    final contratos = match.toList()..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    final c = contratos.first;
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
  }

  void _decryptContrato(ContratoTerapeutico c) {
    c.nomeAceite = _decrypt(c.nomeAceite);
  }

  void _decryptContratos(List<ContratoTerapeutico> lista) {
    for (final c in lista) {
      _decryptContrato(c);
    }
  }
}
