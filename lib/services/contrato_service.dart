import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;

import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../models/perfil_profissional.dart';
import 'api_client.dart';
import 'logger.dart';

class ContratoService {
  final Box<ContratoTerapeutico> _box = Hive.box<ContratoTerapeutico>('contratos');

  ContratoTerapeutico? obterPorPaciente(String pacienteId) {
    final match = _box.values.where((c) => c.pacienteId == pacienteId);
    if (match.isEmpty) return null;
    final contratos = match.toList()..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    return contratos.first;
  }

  List<ContratoTerapeutico> listarPorPaciente(String pacienteId) {
    return _box.values
        .where((c) => c.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
  }

  List<ContratoTerapeutico> listarPendentes() {
    return _box.values
        .where((c) => c.status == 'pendente' || c.status == 'enviado')
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
  }

  int contarPendentes() {
    return _box.values.where((c) => c.status == 'pendente' || c.status == 'enviado').length;
  }

  Future<ContratoTerapeutico?> criarContrato({
    required Paciente paciente,
    required PerfilProfissional perfil,
  }) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) return null;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/contratos'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode({
              'nome_paciente': paciente.nome,
              'nome_profissional': perfil.nome,
              'registro_profissional': perfil.registroProfissional,
              'termo_pessoa': perfil.termoSingular,
            }),
          )
          .timeout(ApiClient.timeout);

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
          await _box.add(contrato);
          return contrato;
        }
      }
      return null;
    } catch (e) {
      Log.erro(e, contexto: 'ContratoService.criarContrato');
      return null;
    }
  }

  Future<bool> marcarComoEnviado(ContratoTerapeutico contrato) async {
    contrato.status = 'enviado';
    contrato.dataEnvio = DateTime.now();
    await contrato.save();
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
            contrato.status = 'aceito';
            contrato.dataAceite = data['aceito_em'] != null
                ? DateTime.parse(data['aceito_em'] as String).toLocal()
                : DateTime.now();
            contrato.nomeAceite = data['nome_aceite'] as String? ?? '';
            await contrato.save();
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

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
