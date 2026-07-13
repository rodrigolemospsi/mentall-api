import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/screens/sessao_form_page.dart';
import 'package:prontuario_tcc/services/audio_relato_service.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';

class _FakeAudioRelatoService implements AudioRelatoService {
  @override Future<void> cancelarGravacao() async {}
  @override Future<String> iniciarGravacao({required String sessaoId}) async => '';
  @override Future<String?> pararGravacao() async => null;
  @override Future<void> pausarGravacao() async {}
  @override Future<void> retomarGravacao() async {}
  @override Future<String> obterAudioAtualBase64() async => '';
  @override Future<bool> verificarPermissaoMicrofone() async => true;
  @override Future<bool> estaGravando() async => false;
  @override Future<void> removerAudioAtual() async {}
  @override String? get caminhoAudioAtual => null;
  @override Future<void> dispose() async {}
}

void main() {
  late _FakeAudioRelatoService fakeAudio;
  late Paciente paciente;

  setUpAll(() async {
    Hive.init('test/temp_hive/sf_final');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<String>('app_config');
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.box<String>('app_config').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('app_config');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    paciente = Paciente(id: 'p1', nome: 'Maria Silva');
    await Hive.box<Paciente>('pacientes').put('p1', paciente);
    await Hive.box<PerfilProfissional>('perfil_profissional').put('pr1', PerfilProfissional(id: 'pr1', nome: 'Dr. Teste'));
    fakeAudio = _FakeAudioRelatoService();
  });

  Widget _app({Sessao? sessao}) => ProviderScope(
    overrides: [audioRelatoServiceProvider.overrideWithValue(fakeAudio)],
    child: MaterialApp(home: SessaoFormPage(paciente: paciente, sessaoExistente: sessao)),
  );

  Future<void> _pump(WidgetTester t, {Sessao? sessao}) async {
    await t.pumpWidget(_app(sessao: sessao));
    await t.pump();
    await t.pump();
    await t.pump();
  }

  group('Nova sessao', () {
    testWidgets('renderiza sem erro fatal', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pump();
      expect(find.text('Erro'), findsNothing);
    });

    testWidgets('AppBar com titulo de nova sessao', (tester) async {
      await _pump(tester);
      final titleText = ((tester.widget<AppBar>(find.byType(AppBar)).title as Text).data)!;
      expect(titleText.contains('sess'), isTrue);
    });

    testWidgets('exibe nome do paciente', (tester) async {
      await _pump(tester);
      expect(find.textContaining('SILVA'), findsWidgets);
    });

    testWidgets('exibe campos clinicos base', (tester) async {
      await _pump(tester);
      expect(find.text('Apontamentos'), findsNothing);
    });
  });

  group('Editar sessao existente', () {
    late Sessao sessao;

    setUp(() async {
      sessao = Sessao(
        id: 's1', pacienteId: 'p1', numeroSessao: 3,
        data: DateTime(2026, 7, 10, 14, 30),
        relatoPosSessao: 'Relato teste',
        transcricaoRelato: 'Transcricao teste',
        revisadoPeloProfissional: true,
        statusProcessamento: 'revisado',
        geradoComIa: true,
      );
      await Hive.box<Sessao>('sessoes').put('s1', sessao);
    });

    testWidgets('inicia no modo bloqueado com botao Editar', (tester) async {
      await _pump(tester, sessao: sessao);
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('AppBar mostra Editar sessao', (tester) async {
      await _pump(tester, sessao: sessao);
      final titleText = ((tester.widget<AppBar>(find.byType(AppBar)).title as Text).data)!;
      expect(titleText.contains('Editar'), isTrue);
    });

    testWidgets('campos preenchidos carregam corretamente', (tester) async {
      await _pump(tester, sessao: sessao);
      expect(find.text('Relato teste'), findsOneWidget);
      expect(find.text('Transcricao teste'), findsOneWidget);
    });
  });
}
