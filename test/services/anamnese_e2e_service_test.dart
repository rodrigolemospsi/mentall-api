import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/anamnese_enviada.dart';
import 'package:prontuario_tcc/services/anamnese_e2e_crypto.dart';
import 'package:prontuario_tcc/services/anamnese_enviada_service.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';

const _chaveMestraBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

void main() {
  late EncryptionService encryption;
  late AnamneseEnviadaService service;

  setUpAll(() async {
    Hive.init('test/temp_hive/anamnese_e2e_service');
    Hive.registerAdapters();
    await Hive.openBox('anamneses_enviadas');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('anamneses_enviadas');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box('anamneses_enviadas').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    await Hive.box<String>('encryption_meta').clear();

    final duravel = _MemStorage()..data['aes_master_key_duravel'] = _chaveMestraBase64;
    encryption = EncryptionService(pin: _MemStorage(), duravel: duravel);
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    if (!encryption.configurado) {
      await encryption.gerarChave();
    }
    expect(encryption.configurado, isTrue,
        reason: 'teste precisa da chave mestra configurada para cifrar campos');
    service = AnamneseEnviadaService(encryption: encryption);

    // Token válido (exp no futuro) para `ensureAuthenticated` não reautenticar.
    final payload = base64UrlEncode(utf8.encode(jsonEncode({'exp': 4102444800})));
    ApiClient.authToken = 'x.$payload.y';
  });

  AnamneseEnviada ficha({String chave = '', bool e2e = true, String status = 'enviado'}) {
    return AnamneseEnviada(
      id: 'a1',
      pacienteId: 'p1',
      token: 'token-e2e',
      abordagem: 'TCC',
      status: status,
      url: 'https://mentall-api.fly.dev/anamneses/token-e2e',
      dataCriacao: DateTime(2026, 11, 1),
      chaveCripto: chave,
      e2e: e2e,
    );
  }

  void mockStatus(Map<String, dynamic> body) {
    ApiClient.httpClient = MockClient((request) async {
      expect(request.url.path, '/anamneses/token-e2e/status');
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  group('AnamneseEnviadaService — resposta E2E', () {
    test('decifra envelope e persiste respostas em texto claro só localmente', () async {
      final chave = AnamneseE2ECrypto.gerarChaveBase64Url();
      final envelope = AnamneseE2ECrypto.cifrarJson(
        chaveBase64Url: chave,
        json: jsonEncode({'queixa': 'conteúdo clínico', 'risco': false}),
      );
      await Hive.box('anamneses_enviadas').put('a1', ficha(chave: chave));
      mockStatus({
        'sucesso': true,
        'status': 'respondido',
        'data_resposta': '2026-11-01T12:00:00Z',
        'respostas_json': '',
        'cifrada': true,
        'iv': envelope['iv'],
        'ct': envelope['ct'],
      });

      final anamnese = Hive.box('anamneses_enviadas').get('a1') as AnamneseEnviada;
      final atualizou = await service.verificarStatus(anamnese);
      expect(atualizou, isTrue);

      // No Hive, o conteúdo continua cifrado pelo EncryptionService.
      final salvo = Hive.box('anamneses_enviadas').get('a1') as AnamneseEnviada;
      expect(salvo.status, 'respondido');
      expect(salvo.falhaDecifrar, isFalse);
      expect(salvo.respostasJson, isNot(contains('conteúdo clínico')));
      expect(salvo.chaveCripto, isNot(chave));

      // Lido pela API do serviço, volta em texto claro.
      final lido = service.obterPorPaciente('p1')!;
      expect(lido.respostas['queixa'], 'conteúdo clínico');
      expect(lido.respostas['risco'], isFalse);
      expect(lido.chaveCripto, chave);
    });

    test('chave diferente marca falhaDecifrar e não vaza conteúdo', () async {
      final chaveDaFicha = AnamneseE2ECrypto.gerarChaveBase64Url();
      final chaveOutra = AnamneseE2ECrypto.gerarChaveBase64Url();
      final envelope = AnamneseE2ECrypto.cifrarJson(
        chaveBase64Url: chaveOutra,
        json: jsonEncode({'queixa': 'sigiloso'}),
      );
      await Hive.box('anamneses_enviadas').put('a1', ficha(chave: chaveDaFicha));
      mockStatus({
        'sucesso': true,
        'status': 'respondido',
        'respostas_json': '',
        'cifrada': true,
        'iv': envelope['iv'],
        'ct': envelope['ct'],
      });

      final anamnese = Hive.box('anamneses_enviadas').get('a1') as AnamneseEnviada;
      expect(await service.verificarStatus(anamnese), isTrue);

      final lido = service.obterPorPaciente('p1')!;
      expect(lido.status, 'respondido');
      expect(lido.falhaDecifrar, isTrue);
      expect(lido.respostasJson, isEmpty);
      expect(lido.respostas, isEmpty);
    });

    test('ficha legada continua lendo respostas em texto claro', () async {
      await Hive.box('anamneses_enviadas').put('a1', ficha(e2e: false));
      mockStatus({
        'sucesso': true,
        'status': 'respondido',
        'data_resposta': '2026-11-01T12:00:00Z',
        'respostas_json': jsonEncode({'legado': 'ok'}),
        'cifrada': false,
      });

      final anamnese = Hive.box('anamneses_enviadas').get('a1') as AnamneseEnviada;
      expect(await service.verificarStatus(anamnese), isTrue);
      final lido = service.obterPorPaciente('p1')!;
      expect(lido.falhaDecifrar, isFalse);
      expect(lido.respostas['legado'], 'ok');
    });
  });

  group('AnamneseEnviadaService.criar — E2E', () {
    test('envia e2e=true, não envia a chave e guarda chave local cifrada', () async {
      Map<String, dynamic>? corpoEnviado;
      ApiClient.httpClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/anamneses');
        corpoEnviado = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'sucesso': true,
            'token': 'token-novo',
            'url': 'https://mentall-api.fly.dev/anamneses/token-novo',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final anamnese = await service.criar(
        pacienteId: 'p1',
        abordagem: 'TCC',
        templateJson: '{"secoes": []}',
        nomePaciente: 'Paciente',
        nomeProfissional: 'Profissional',
        registro: '06/123456',
      );

      expect(corpoEnviado!['e2e'], isTrue);
      expect(corpoEnviado!.containsKey('chave'), isFalse);
      expect(corpoEnviado!.containsKey('chave_cripto'), isFalse);
      expect(anamnese.e2e, isTrue);
      expect(anamnese.chaveCripto.length, greaterThanOrEqualTo(42));
      expect(anamnese.urlComChave, contains('#k=${anamnese.chaveCripto}'));

      // No Hive a chave fica cifrada em repouso.
      final salvo = Hive.box('anamneses_enviadas').get(anamnese.id) as AnamneseEnviada;
      expect(salvo.chaveCripto, isNot(anamnese.chaveCripto));
      expect(salvo.chaveCripto, startsWith('3:'));
      expect(salvo.e2e, isTrue);
    });
  });
}

class _MemStorage extends FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}
