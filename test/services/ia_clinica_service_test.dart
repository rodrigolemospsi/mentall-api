import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/ia_clinica_service.dart';

void main() {
  test('progresso envia URI unica, payload e interpreta resposta clinica', () async {
    final dir = await Directory.systemTemp.createTemp('ia_clinica_test_');
    Hive.init(dir.path);
    await Hive.openBox<String>('app_config');
    addTearDown(() async {
      ApiClient.authToken = null;
      await Hive.close();
      await dir.delete(recursive: true);
    });
    await ApiClient.setBaseUrl('https://clinica.example/api');
    ApiClient.authToken = 'test.${base64Url.encode(utf8.encode(jsonEncode({
      'exp': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000,
    })))}.signature';
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode({
        'sucesso': true,
        'sintomas': [{'nome': 'Ansiedade', 'tendencia': 'melhora'}],
        'metas': [{'descricao': 'Retomar atividades', 'progresso': 60}],
        'avaliacao_geral': 'Melhora gradual',
        'tendencia': 'melhora',
        'recomendacoes': 'Monitorar evolucao',
      }), 200);
    });
    addTearDown(client.close);

    final result = await IaClinicaService(client: client).gerarProgresso(
      pacienteId: 'p1',
      numeroSessao: 2,
      sessoesAnteriores: [{'numero': 1, 'data': '2026-09-01', 'sintese': 'Inicio'}],
      sessaoAtual: {'data': '2026-09-06', 'sintese': 'Retomou atividades'},
    );

    expect(requests, hasLength(1));
    expect(requests.single.url, Uri.parse('https://clinica.example/api/gerar-progresso'));
    expect(requests.single.method, 'POST');
    expect(requests.single.headers['Authorization'], 'Bearer ${ApiClient.authToken}');
    expect(jsonDecode(requests.single.body)['paciente_id'], 'p1');
    expect(result.sucesso, isTrue);
    expect(result.sintomas.single['nome'], 'Ansiedade');
    expect(result.metas.single['progresso'], 60);
    expect(result.avaliacaoGeral, 'Melhora gradual');
    expect(result.tendencia, 'melhora');
    expect(result.recomendacoes, 'Monitorar evolucao');
  });
}
