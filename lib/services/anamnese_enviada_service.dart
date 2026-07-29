import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/anamnese_enviada.dart';
import 'api_client.dart';
import 'logger.dart';

class AnamneseEnviadaService {
  static const String _boxName = 'anamneses_enviadas';

  late final Box _box;

  Box _abrirBox() {
    try {
      return Hive.box(_boxName);
    } catch (_) {
      final box = Hive.box<AnamneseEnviada>(_boxName);
      return box;
    }
  }

  AnamneseEnviada? obterPorPaciente(String pacienteId) {
    _box = _abrirBox();
    final anamneses = _box.values
        .whereType<AnamneseEnviada>()
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
    String tratamento = 'masculino',
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
        'tratamento': tratamento,
      },
      customTimeout: const Duration(seconds: 30),
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
        _box = _abrirBox();
        await _box.put(anamnese.id, anamnese);
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
    _box = _abrirBox();
    await _box.put(atualizada.id, atualizada);
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
          _box = _abrirBox();
          await _box.put(atualizada.id, atualizada);
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
    _box = _abrirBox();
    return _box.watch();
  }
}