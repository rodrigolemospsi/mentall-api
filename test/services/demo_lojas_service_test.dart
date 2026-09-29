import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/services/demo_lojas_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/perfil_profissional_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';

void main() {
  late EncryptionService encryption;

  setUpAll(() async {
    Hive.init('test/temp_hive/demo_lojas');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<Compromisso>('compromissos');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('encryption_meta');
  });

  tearDownAll(() async {
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('compromissos');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('encryption_meta');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<Compromisso>('compromissos').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<String>('app_config').clear();
    await Hive.box<String>('encryption_meta').clear();

    encryption = EncryptionService();
    await encryption.gerarChave();
  });

  DemoLojasService criar({bool ativo = true}) => DemoLojasService(
        encryption: encryption,
        ativo: ativo,
        fotoLoader: () async => 'Zm90bw==',
      );

  test('semeia 23 pacientes ativos', () async {
    await criar().semearSeNecessario();
    final pacientes = Hive.box<Paciente>('pacientes').values.toList();
    expect(pacientes.length, DemoLojasService.totalPacientes);
    expect(pacientes.every((p) => p.ativo), isTrue);
  });

  test('semeia 7 agendamentos para hoje', () async {
    await criar().semearSeNecessario();
    final now = DateTime.now();
    final hoje = Hive.box<Compromisso>('compromissos').values.where((c) =>
        c.dataHoraInicio.year == now.year &&
        c.dataHoraInicio.month == now.month &&
        c.dataHoraInicio.day == now.day &&
        c.status != 'cancelado');
    expect(hoje.length, DemoLojasService.agendamentosHoje);
  });

  test('receita do mes = R\$ 5.780 e pendente = R\$ 380', () async {
    await criar().semearSeNecessario();
    final now = DateTime.now();
    final r = SessaoService(encryption: encryption).somarFinanceiroPorPeriodo(
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 1),
    );
    expect(r.receita, 5780.0);
    expect(r.pendente, 380.0);
  });

  test('cria o perfil da psicologa Helena com foto', () async {
    await criar().semearSeNecessario();
    final perfil = PerfilProfissionalService(encryption: encryption).obterPerfil();
    expect(perfil, isNotNull);
    expect(perfil!.nome, contains('Helena'));
    expect(perfil.fotoBase64, isNotEmpty);
  });

  test('eh idempotente', () async {
    await criar().semearSeNecessario();
    await criar().semearSeNecessario();
    expect(Hive.box<Paciente>('pacientes').length,
        DemoLojasService.totalPacientes);
  });

  test('nao semeia quando a flag esta desligada', () async {
    await criar(ativo: false).semearSeNecessario();
    expect(Hive.box<Paciente>('pacientes').isEmpty, isTrue);
  });
}
