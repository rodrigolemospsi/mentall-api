import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/anamnese_enviada.dart';
import 'api_client.dart';
import 'logger.dart';

class AnamneseEnviadaService {
  static const String _boxName = 'anamneses_enviadas';

  Box<AnamneseEnviada> get _box => Hive.box<AnamneseEnviada>(_boxName);

  AnamneseEnviada? obterPorPaciente(String pacienteId) {
    final anamneses = _box.values
        .where((a) => a.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    return anamneses.isNotEmpty ? anamneses.first : null;
  }

  Future<AnamneseEnviada> criar({
    required String pacienteId,
    required String abordagem,
    required String templateJson,
    required String nomePaciente,
    required String nomeProfissional,
    required String registro,
  }) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) {
      Log.erro('Autenticacao falhou ao criar anamnese', contexto: 'AnamneseEnviadaService.criar');
      throw Exception('Falha na autenticacao com o servidor. Verifique credenciais em Configuracoes > Avancado.');
    }

    final response = await ApiClient.post(
      '/anamneses',
      body: {
        'template_json': templateJson,
        'abordagem': abordagem,
        'nome_paciente': nomePaciente,
        'nome_profissional': nomeProfissional,
        'registro': registro,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['sucesso'] == true) {
        final anamnese = AnamneseEnviada(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pacienteId: pacienteId,
          token: data['token'] as String,
          abordagem: abordagem,
          status: 'pendente',
          url: data['url'] as String,
          dataCriacao: DateTime.now(),
        );
        await _box.put(anamnese.id, anamnese);
        _box.toMap();
        return anamnese;
      }
      Log.erro('Resposta inesperada do servidor: ${response.body}', contexto: 'AnamneseEnviadaService.criar');
      throw Exception('Servidor retornou sucesso=false: ${response.body}');
    }

    Log.erro(
      'Erro HTTP ${response.statusCode} ao criar anamnese: ${response.body}',
      contexto: 'AnamneseEnviadaService.criar',
    );
    throw Exception('Erro HTTP ${response.statusCode} do servidor: ${response.body}');
  }

  Future<void> marcarComoEnviada(AnamneseEnviada anamnese) async {
    final atualizada = anamnese.copyWith(
      status: 'enviado',
      dataEnvio: DateTime.now(),
    );
    await _box.put(atualizada.id, atualizada);
    _box.toMap();
  }

  Future<bool> verificarStatus(AnamneseEnviada anamnese) async {
    try {
      final autenticado = await ApiClient.ensureAuthenticated();
      if (!autenticado) {
        Log.erro('Autenticacao falhou ao verificar status', contexto: 'AnamneseEnviadaService.verificarStatus');
        return false;
      }

      final response = await ApiClient.get('/anamneses/${anamnese.token}/status');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['sucesso'] == true && data['status'] == 'respondido') {
          final respostas = data['respostas_json'] as String? ?? '';
          String dataRespostaStr = data['data_resposta'] as String? ?? '';
          DateTime? dataResposta;
          if (dataRespostaStr.isNotEmpty) {
            dataResposta = DateTime.tryParse(dataRespostaStr);
          }

          final atualizada = anamnese.copyWith(
            status: 'respondido',
            respostasJson: respostas,
            dataResposta: dataResposta,
          );
          await _box.put(atualizada.id, atualizada);
          _box.toMap();
          return true;
        }
      }
      return false;
    } catch (e) {
      Log.erro(e, contexto: 'AnamneseEnviadaService.verificarStatus');
      return false;
    }
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }
}
