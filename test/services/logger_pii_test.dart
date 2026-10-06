// Testes de PII no log tecnico (achado M3 da auditoria).
//
// Contexto: quando a cifra falhava ou nao estava configurada, a linha ia em
// CLARO para o box `logs_tecnicos` e para `mentall_tecnicos.log` em disco. As
// linhas podem conter `response.body` com nome e telefone do paciente
// (anamnese_enviada_service.dart:112, api_client.dart:227).
// Ver AGENTS.md (secao 06/10/2026).
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/logger.dart';

void main() {
  const box = 'logs_tecnicos';
  const pii = 'Maria Silva, telefone (11) 99999-1234';

  String conteudo() => Hive.box<String>(box).get('log') ?? '';

  setUpAll(() async {
    Hive.init('test/temp_hive/logger_pii');
    await Hive.openBox<String>(box);
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk(box);
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<String>(box).clear();
  });

  test('sem cifra configurada, o conteudo NAO vai em claro para o box',
      () async {
    // Servico sem inicializar: `configurado` falso, como no boot antes do
    // desbloqueio — exatamente a janela em que o vazamento acontecia.
    Log.setEncryptionService(EncryptionService());

    await Log.erro('Resposta inesperada do servidor: $pii',
        contexto: 'AnamneseEnviadaService.criar');

    final linha = conteudo();
    expect(linha, isNot(contains('Maria Silva')));
    expect(linha, isNot(contains('99999-1234')));
    expect(linha, isNot(contains('Resposta inesperada')));
    // O rotulo continua, para o log seguir util no diagnostico.
    expect(linha, contains('ERRO'));
    expect(linha, contains('AnamneseEnviadaService.criar'));
    expect(linha, contains('cifra indisponivel'));
  });

  test('com cifra configurada, a linha vai cifrada e continua legivel',
      () async {
    final enc = EncryptionService();
    await enc.inicializar();
    await enc.gerarChave();
    Log.setEncryptionService(enc);

    await Log.erro('Resposta inesperada do servidor: $pii',
        contexto: 'AnamneseEnviadaService.criar');

    final linha = conteudo();
    expect(linha, isNot(contains('Maria Silva')));
    expect(enc.estaCifrado(linha), isTrue);
    expect(enc.descriptografar(linha), contains('Maria Silva'));
  });

  test('auditoria e info seguem a mesma regra', () async {
    Log.setEncryptionService(EncryptionService());
    await Log.info('paciente $pii', contexto: 'Teste');
    await Log.auditoria('acesso a $pii', contexto: 'Teste');

    final linhas = conteudo();
    expect(linhas, isNot(contains('Maria Silva')));
    expect(linhas, contains('INFO'));
    expect(linhas, contains('AUDITORIA'));
  });
}
