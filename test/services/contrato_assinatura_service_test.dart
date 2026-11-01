import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/services/api_client.dart';
import 'package:prontuario_tcc/services/contrato_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/utils/documentos.dart';

const _chaveMestraBase64 = 'MTIzNDU2Nzg5MDEyMzQ1Njc4OTA=';

void main() {
  late EncryptionService encryption;
  late ContratoService service;

  setUpAll(() async {
    Hive.init('test/temp_hive/contrato_assinatura_service');
    Hive.registerAdapters();
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('contratos');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<ContratoTerapeutico>('contratos').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('auth_meta').clear();
    await Hive.box<String>('encryption_meta').clear();

    final duravel = _MemStorage()
      ..data['aes_master_key_duravel'] = _chaveMestraBase64;
    encryption = EncryptionService(pin: _MemStorage(), duravel: duravel);
    EncryptionService.setInstance(encryption);
    await encryption.inicializar();
    if (!encryption.configurado) {
      await encryption.gerarChave();
    }
    service = ContratoService(encryption: encryption);
    final payload = base64UrlEncode(utf8.encode(jsonEncode({'exp': 4102444800})));
    ApiClient.authToken = 'x.$payload.y';
  });

  ContratoTerapeutico contrato() => ContratoTerapeutico(
        id: 'c1',
        pacienteId: 'p1',
        token: 'token-assinado',
        dataCriacao: DateTime(2026, 11, 1),
        status: 'enviado',
        url: 'https://mentall-api.fly.dev/contratos/token-assinado',
      );

  void mockStatus({required bool aceito}) {
    ApiClient.httpClient = MockClient((request) async {
      expect(request.url.path, '/contratos/token-assinado/status');
      return http.Response(
        jsonEncode({
          'sucesso': true,
          'status': aceito ? 'aceito' : 'enviado',
          if (aceito) ...{
            'aceito_em': '2026-11-01T15:00:00+00:00',
            'nome_aceite': 'Maria Teste Silva',
            'aceite_codigo': 'ABCDE-FGHIJ',
            'aceite_hash': 'a' * 64,
            'aceite_versao': 'contrato-v1',
            'aceite_cpf_mascarado': '***.***.777-**',
            'aceite_ip': '203.0.113.10',
            'aceite_user_agent': 'Mozilla/5.0 teste',
            'verificacao_url': 'https://mentall-api.fly.dev/verificar/ABCDE-FGHIJ',
            'documento_texto': 'ACORDO TERAPÊUTICO\n\nCompromissos\nTexto do acordo.',
            'cpf_profissional': '11144477735',
            'cnpj_profissional': '11222333000181',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
  }

  test('verificarStatus guarda evidências e documento (cifrados no Hive)', () async {
    await Hive.box<ContratoTerapeutico>('contratos').put('c1', contrato());
    mockStatus(aceito: true);
    final c = Hive.box<ContratoTerapeutico>('contratos').get('c1')!;

    final atualizou = await service.verificarStatus(c);
    expect(atualizou, isTrue);

    final salvo = Hive.box<ContratoTerapeutico>('contratos').get('c1')!;
    expect(salvo.status, 'aceito');
    expect(salvo.aceiteCodigo, isNot('ABCDE-FGHIJ'));
    expect(salvo.aceiteCodigo, startsWith('3:'));

    final lido = service.listarPorPaciente('p1').first;
    expect(lido.status, 'aceito');
    expect(lido.aceiteCodigo, 'ABCDE-FGHIJ');
    expect(lido.aceiteHash, 'a' * 64);
    expect(lido.aceiteVersao, 'contrato-v1');
    expect(lido.aceiteCpfMascarado, '***.***.777-**');
    expect(lido.aceiteIp, '203.0.113.10');
    expect(lido.aceiteUserAgent, 'Mozilla/5.0 teste');
    expect(lido.verificacaoUrl,
        'https://mentall-api.fly.dev/verificar/ABCDE-FGHIJ');
    expect(lido.documentoTexto, contains('Compromissos'));
    expect(lido.dataAceite, isNotNull);
    expect(lido.nomeAceite, 'Maria Teste Silva');
  });

  test('status pendente não altera o contrato', () async {
    await Hive.box<ContratoTerapeutico>('contratos').put('c1', contrato());
    mockStatus(aceito: false);
    final c = Hive.box<ContratoTerapeutico>('contratos').get('c1')!;
    expect(await service.verificarStatus(c), isFalse);
    expect(Hive.box<ContratoTerapeutico>('contratos').get('c1')!.status,
        'enviado');
  });

  test('criarContrato envia CPF/CNPJ do profissional', () async {
    Map<String, dynamic>? corpo;
    ApiClient.httpClient = MockClient((request) async {
      corpo = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'sucesso': true,
          'token': 'novo-token',
          'url': 'https://mentall-api.fly.dev/contratos/novo-token',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final contratoCriado = await service.criarContrato(
      paciente: Paciente(id: 'p1', nome: 'Maria Teste'),
      perfil: PerfilProfissional(
        id: 'perf1',
        nome: 'Rodrigo Lemos',
        registroProfissional: '06/123456',
        cpf: '11144477735',
        cnpj: '11222333000181',
      ),
      templateContrato: '',
    );
    expect(corpo!['cpf_profissional'], '11144477735');
    expect(corpo!['cnpj_profissional'], '11222333000181');
    expect(contratoCriado.token, 'novo-token');
  });

  test('Documentos formata CPF/CNPJ', () {
    expect(Documentos.formatarCpf('11144477735'), '111.444.777-35');
    expect(Documentos.formatarCnpj('11222333000181'),
        '11.222.333/0001-81');
    expect(Documentos.limpar('111.444.777-35'), '11144477735');
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
  }) async =>
      data[key];

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
