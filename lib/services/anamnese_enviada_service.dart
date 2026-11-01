import 'dart:convert';

import 'package:hive_ce/hive.dart';

import '../models/anamnese_enviada.dart';
import 'anamnese_e2e_crypto.dart';
import 'api_client.dart';
import 'encrypted_service_mixin.dart';
import 'encryption_service.dart';
import 'logger.dart';

class AnamneseEnviadaService with EncryptedServiceMixin {
  static const String _boxName = 'anamneses_enviadas';
  @override
  final EncryptionService? encryption;

  AnamneseEnviadaService({this.encryption});

  Box get _box => Hive.box(_boxName);

  String _encrypt(String value) => encrypt(value);
  String _decrypt(String value) => decrypt(value);

  AnamneseEnviada? obterPorPaciente(String pacienteId) {
    final anamneses = _box.values
        .whereType<AnamneseEnviada>()
        .where((a) => a.pacienteId == pacienteId)
        .toList()
      ..sort((a, b) => b.dataCriacao.compareTo(a.dataCriacao));
    if (anamneses.isEmpty) return null;
    // Decifra uma cópia: mutar o objeto do cache do Hive com texto claro
    // arriscaria persistir dados clínicos sem cifra na próxima gravação.
    final a = anamneses.first.copyWith();
    _decryptAnamnese(a);
    return a;
  }

  /// Consulta o backend o status das anamneses pendentes/enviadas e atualiza o
  /// Hive quando o paciente responder. Se [pacienteId] for nulo, verifica todos
  /// os pacientes. Retorna quantas foram atualizadas.
  Future<int> sincronizarPendencias({String? pacienteId}) async {
    var atualizadas = 0;
    final pendentes = _box.values
        .whereType<AnamneseEnviada>()
        .where((a) =>
            (pacienteId == null || a.pacienteId == pacienteId) &&
            (a.status == 'pendente' || a.status == 'enviado'))
        .toList();
    for (final anamnese in pendentes) {
      if (await verificarStatus(anamnese)) {
        atualizadas++;
      }
    }
    return atualizadas;
  }

  Future<AnamneseEnviada> criar({
    required String pacienteId,
    required String abordagem,
    required String templateJson,
    required String nomePaciente,
    required String nomeProfissional,
    required String registro,
    String tratamento = 'masculino',
    bool crpVerificado = false,
  }) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) {
      Log.erro('Autenticação falhou ao criar anamnese', contexto: 'AnamneseEnviadaService.criar');
      throw Exception('Falha na autenticação com o servidor. Verifique credenciais em Configurações > Avançado.');
    }

    // Criptografia ponta-a-ponta: a chave fica só neste aparelho e viaja no
    // fragmento do link (#k=...), nunca no corpo da requisição ao servidor.
    final chaveE2e = AnamneseE2ECrypto.gerarChaveBase64Url();

    final body = {
      'template_json': templateJson,
      'abordagem': abordagem,
      'nome_paciente': nomePaciente,
      'nome_profissional': nomeProfissional,
      'registro': registro,
      'tratamento': tratamento,
      'crp_verificado': crpVerificado,
      'e2e': true,
    };
    var response = await ApiClient.post(
      '/anamneses',
      body: body,
      customTimeout: const Duration(seconds: 30),
    );
    if (response.statusCode == 401) {
      // Token expirado/inválido: reautentica uma vez e repete (paridade com
      // transcrição/síntese, que já retentam em 401).
      await ApiClient.forceReauthenticate();
      response = await ApiClient.post(
        '/anamneses',
        body: body,
        customTimeout: const Duration(seconds: 30),
      );
    }

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
          chaveCripto: chaveE2e,
          e2e: true,
        );
        // Persiste uma cópia cifrada; o objeto devolvido fica em texto claro e
        // não compartilha referência com o cache do Hive.
        final paraSalvar = anamnese.copyWith();
        _encryptAnamnese(paraSalvar);
        await _box.put(paraSalvar.id, paraSalvar);
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
    _encryptAnamnese(atualizada);
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
          _decryptAnamnese(anamnese);
          var respostas = data['respostas_json'] as String? ?? '';
          var falhaDecifrar = false;
          if (data['cifrada'] == true) {
            final claro = AnamneseE2ECrypto.decifrarRespostas(
              chaveBase64Url: anamnese.chaveCripto,
              ivBase64: data['iv'] as String? ?? '',
              ctBase64: data['ct'] as String? ?? '',
            );
            if (claro == null) {
              falhaDecifrar = true;
              respostas = '';
              Log.erro(
                'Resposta de anamnese cifrada não pôde ser decifrada neste aparelho (token ${anamnese.token.substring(0, 8)}).',
                contexto: 'AnamneseEnviadaService.verificarStatus',
              );
            } else {
              respostas = claro;
            }
          }
          String dataRespostaStr = data['data_resposta'] as String? ?? '';
          DateTime? dataResposta;
          if (dataRespostaStr.isNotEmpty) {
            dataResposta = DateTime.tryParse(dataRespostaStr);
          }

          final atualizada = anamnese.copyWith(
            status: 'respondido',
            respostasJson: respostas,
            dataResposta: dataResposta,
            falhaDecifrar: falhaDecifrar,
          );
          _encryptAnamnese(atualizada);
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

  Future<void> removerCriptografiaExistente() async {
    final enc = encryption; if (enc == null || !enc.configurado) return;
    for (final a in _box.values.whereType<AnamneseEnviada>()) {
      _decryptAnamnese(a);
      await a.save();
    }
  }

  Stream<BoxEvent> observar() {
    return _box.watch();
  }

  void _encryptAnamnese(AnamneseEnviada a) {
    a.respostasJson = _encrypt(a.respostasJson);
    a.chaveCripto = _encrypt(a.chaveCripto);
  }

  void _decryptAnamnese(AnamneseEnviada a) {
    a.respostasJson = _decrypt(a.respostasJson);
    a.chaveCripto = _decrypt(a.chaveCripto);
  }
}
