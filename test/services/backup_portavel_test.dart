import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/contrato_terapeutico.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/pacote.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/progresso_sessao.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/backup_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/paciente_service.dart';

void main() {
  late EncryptionService encryption;
  late BackupService backup;

  setUpAll(() async {
    Hive.init('test/temp_hive/backup_portavel');
    Hive.registerAdapters();
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox<Compromisso>('compromissos');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
  });

  tearDownAll(() async {
    for (final nome in [
      'pacientes',
      'sessoes',
      'perfil_profissional',
      'contratos',
      'compromissos',
      'pacotes',
      'progresso_sessoes',
      'encryption_meta',
    ]) {
      await Hive.deleteBoxFromDisk(nome);
    }
  });

  setUp(() async {
    await Hive.box<String>('encryption_meta').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<Compromisso>('compromissos').clear();
    encryption = EncryptionService();
    await encryption.inicializar();
    await encryption.gerarChave();
    backup = BackupService(encryption: encryption);
  });

  Future<void> adicionarPaciente() async {
    final servico = PacienteService(encryption: encryption);
    await servico.adicionarPaciente(
      Paciente(
        id: 'p1',
        nome: 'Paciente Portátil',
        contato: '11999999999',
        email: 'a@b.com',
        tipoAtendimento: 'Particular',
        observacoes: 'Obs',
        ativo: true,
        dataCadastro: DateTime(2026, 10, 1),
      ),
    );
  }

  Future<BackupService> novoAparelho() async {
    final outro = EncryptionService();
    await outro.inicializar();
    await outro.gerarChave(); // chave nova (aparelho novo)
    return BackupService(encryption: outro);
  }

  group('envelope cifrado por senha', () {
    test('exporta v2, não contém texto claro e restaura em outro aparelho', () async {
      await adicionarPaciente();
      final portavel = await backup.exportarParaJsonPortavel('senha-super-123');

      final envelope = jsonDecode(portavel) as Map<String, dynamic>;
      expect(envelope['tipo'], 'mentall_backup_v2');
      expect(envelope['kdf'], 'pbkdf2-sha256');
      expect(envelope['iteracoes'], greaterThanOrEqualTo(100000));
      expect(portavel, isNot(contains('Paciente Portátil')));

      // simula aparelho novo: chave diferente, mesmas caixas vazias
      await Hive.box<Paciente>('pacientes').clear();
      final outro = await novoAparelho();
      final resultado = await outro.importarDeJson(portavel, senha: 'senha-super-123');
      expect(resultado, contains('1 paciente(s)'));
      // os campos são cifrados com a chave do aparelho novo: ler pelo service
      final servicoNovo = PacienteService(encryption: outro.encryption!);
      final pacientes = servicoNovo.listarPacientes();
      expect(pacientes.first.nome, 'Paciente Portátil');
    });

    test('senha errada não abre o backup', () async {
      await adicionarPaciente();
      final portavel = await backup.exportarParaJsonPortavel('senha-super-123');
      final outro = await novoAparelho();
      final resultado = await outro.importarDeJson(portavel, senha: 'senha-errada-9');
      expect(resultado.toLowerCase(), contains('senha incorreta'));
    });

    test('arquivo adulterado é rejeitado (integridade)', () async {
      await adicionarPaciente();
      final portavel = await backup.exportarParaJsonPortavel('senha-super-123');
      final envelope = jsonDecode(portavel) as Map<String, dynamic>;
      final cifrado = base64Decode(envelope['cifrado'] as String);
      cifrado[0] = cifrado[0] ^ 0xFF; // corrompe 1 byte
      envelope['cifrado'] = base64Encode(cifrado);
      final adulterado = jsonEncode(envelope);

      final outro = await novoAparelho();
      final resultado = await outro.importarDeJson(adulterado, senha: 'senha-super-123');
      expect(resultado.toLowerCase(), contains('senha incorreta'));
    });

    test('backup sem senha (v1) continua funcionando no mesmo aparelho', () async {
      await adicionarPaciente();
      final v1 = backup.exportarParaJson();
      expect(jsonDecode(v1)['tipo'], 'mentall_backup_v1');
      final resultado = await backup.importarDeJson(v1);
      expect(resultado, contains('1 paciente(s)'));
    });
  });

  group('chave de recuperação', () {
    test('exporta e importa em outro aparelho, abrindo backup v1 antigo', () async {
      await adicionarPaciente();
      final backupAntigo = backup.exportarParaJson();

      final chave = await backup.exportarChaveRecuperacao('senha-chave-123');
      expect(chave, isNotNull);
      expect(jsonDecode(chave!)['tipo'], 'mentall_chave_v1');

      final outroEncryption = EncryptionService();
      await outroEncryption.inicializar();
      await outroEncryption.gerarChave();
      final outro = BackupService(encryption: outroEncryption);

      expect(await outro.importarChaveRecuperacao(chave, 'senha-chave-123'), isTrue);
      final claro = outroEncryption.descriptografarEnvelope(backupAntigo);
      expect(claro, isNotNull);
      expect(claro, contains('Paciente Portátil'));
    });

    test('senha errada na chave não substitui nada', () async {
      final chave = await backup.exportarChaveRecuperacao('senha-chave-123');
      final outro = await novoAparelho();
      expect(await outro.importarChaveRecuperacao(chave!, 'errada-123'), isFalse);
    });
  });
}
