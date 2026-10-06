import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/pacote.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/progresso_sessao.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/screens/sessao_form_page.dart';
import 'package:prontuario_tcc/services/audio_relato_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/sessao_service.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';

class _FakeAudioRelatoService implements AudioRelatoService {
  final List<String> audiosExcluidos = [];

  @override Future<void> cancelarGravacao() async {}
  @override Future<String> iniciarGravacao({required String sessaoId}) async => '';
  @override Future<String?> pararGravacao() async => null;
  @override Future<void> pausarGravacao() async {}
  @override Future<void> retomarGravacao() async {}
  @override Future<String> obterAudioAtualBase64() async => '';
  @override Future<bool> verificarPermissaoMicrofone() async => true;
  @override Future<bool> estaGravando() async => false;
  @override Future<void> removerAudioAtual() async {}
  @override Future<void> excluirArquivoAudio(String? caminho) async {
    if (caminho != null && caminho.isNotEmpty) audiosExcluidos.add(caminho);
  }
  @override String? get caminhoAudioAtual => null;
  @override Future<void> dispose() async {}
}

class _FakeAudioPlayer implements AudioPlayer {
  final complete = StreamController<void>.broadcast();
  bool disposed = false;
  int plays = 0;
  int stops = 0;

  void checkAlive() {
    if (disposed) throw StateError('AudioPlayer usado apos dispose');
  }

  @override
  Stream<void> get onPlayerComplete {
    checkAlive();
    return complete.stream;
  }
  @override
  Future<void> stop() async {
    checkAlive();
    stops++;
  }
  @override
  Future<void> play(Source source, {double? volume, double? balance, AudioContext? ctx, Duration? position, PlayerMode? mode}) async {
    checkAlive();
    plays++;
  }
  @override
  Future<void> dispose() async {
    checkAlive();
    disposed = true;
    await complete.close();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SessaoServiceComErro extends SessaoService {
  @override
  int proximoNumeroSessao(String pacienteId) => throw StateError('Falha sintetica');
}

void main() {
  late _FakeAudioRelatoService fakeAudio;
  late Paciente paciente;
  late EncryptionService encryption;
  late SessaoService sessaoService;

  setUpAll(() async {
    Hive.init('test/temp_hive/sf_final');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
    encryption = EncryptionService();
    await encryption.gerarChave();
    sessaoService = SessaoService(encryption: encryption);
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.box<String>('app_config').close();
    await Hive.box<Pacote>('pacotes').close();
    await Hive.box<ProgressoSessao>('progresso_sessoes').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('pacotes');
    await Hive.deleteBoxFromDisk('progresso_sessoes');
  });

  setUp(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    paciente = Paciente(id: 'p1', nome: 'Maria Silva');
    await Hive.box<Paciente>('pacientes').put('p1', paciente);
    await Hive.box<PerfilProfissional>('perfil_profissional').put('pr1', PerfilProfissional(id: 'pr1', nome: 'Dr. Teste'));
    fakeAudio = _FakeAudioRelatoService();
  });

  tearDown(() {
    WidgetController.hitTestWarningShouldBeFatal = false;
  });

  Widget app({Sessao? sessao}) => ProviderScope(
    overrides: [
      audioRelatoServiceProvider.overrideWithValue(fakeAudio),
      sessaoServiceProvider.overrideWithValue(sessaoService),
      audioPlayerProvider.overrideWith((ref) {
        final player = _FakeAudioPlayer();
        ref.onDispose(player.dispose);
        return player;
      }),
    ],
    child: MaterialApp(home: SessaoFormPage(paciente: paciente, sessaoExistente: sessao)),
  );

  Future<void> pump(WidgetTester t, {Sessao? sessao}) async {
    await t.pumpWidget(app(sessao: sessao));
    await t.pump();
    await t.pump();
    await t.pump();
  }

  group('Nova sessao', () {
    testWidgets('renderiza sem erro fatal', (tester) async {
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('Erro'), findsNothing);
    });

    testWidgets('AppBar com titulo de nova sessao', (tester) async {
      await pump(tester);
      final titleText = ((tester.widget<AppBar>(find.byType(AppBar)).title as Text).data)!;
      expect(titleText.contains('sess'), isTrue);
    });

    testWidgets('exibe titulo da sessao', (tester) async {
      await pump(tester);
      expect(find.textContaining('SESSÃO'), findsWidgets);
    });

    testWidgets('exibe campos clinicos base', (tester) async {
      await pump(tester);
      expect(find.text('Apontamentos'), findsNothing);
    });
  });

  testWidgets('erro de abertura orienta suporte e permite voltar sem apagar dados', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioRelatoServiceProvider.overrideWithValue(fakeAudio),
        audioPlayerProvider.overrideWith((ref) {
          final player = _FakeAudioPlayer();
          ref.onDispose(player.dispose);
          return player;
        }),
        sessaoServiceProvider.overrideWithValue(_SessaoServiceComErro()),
      ],
      child: MaterialApp(home: Scaffold(body: Builder(builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => SessaoFormPage(paciente: paciente),
        )),
        child: const Text('Abrir'),
      )))),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o prontuário'), findsOneWidget);
    expect(find.textContaining('Tente limpar os dados'), findsNothing);
    expect(find.textContaining('suporte'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Voltar'), 400);
    final voltar = find.widgetWithText(FilledButton, 'Voltar');
    await tester.ensureVisible(voltar);
    await tester.tap(voltar);
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    expect(Hive.box<Paciente>('pacientes').get('p1')!.nome, 'Maria Silva');
  });

  testWidgets('abre ouve sai e ouve outra sessao no mesmo scope sem player descartado', (tester) async {
    final players = <_FakeAudioPlayer>[];
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        audioRelatoServiceProvider.overrideWithValue(fakeAudio),
        audioPlayerProvider.overrideWith((ref) {
          final player = _FakeAudioPlayer();
          players.add(player);
          ref.onDispose(player.dispose);
          return player;
        }),
      ],
      child: MaterialApp(navigatorKey: navigator, home: const Scaffold()),
    ));
    for (var i = 0; i < 2; i++) {
      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => SessaoFormPage(
        paciente: paciente,
        sessaoExistente: Sessao(
          id: 'audio$i', pacienteId: paciente.id, numeroSessao: i + 1,
          data: DateTime(2026, 9, 6), audioRelatoBase64: 'AQIDBA==',
        ),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Ouvir áudio'));
      await tester.tap(find.byTooltip('Ouvir áudio'));
      await tester.pumpAndSettle();
      expect(players.last.plays, 1);
      expect(players.last.disposed, isFalse);
      expect(players.last.complete.hasListener, isTrue);
      // Parar pelo controle evita misturar a regressao com estado global do editor.
      await tester.tap(find.byTooltip('Parar áudio'));
      await tester.pumpAndSettle();
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(players.last.complete.hasListener, isFalse);
      expect(players.last.disposed, isTrue);
    }
    expect(players, hasLength(2));
    expect(players.every((player) => player.stops >= 3), isTrue);
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
      await pump(tester, sessao: sessao);
      expect(find.text('Editar'), findsOneWidget);
    });

    testWidgets('AppBar mostra numero da sessao', (tester) async {
      await pump(tester, sessao: sessao);
      final titleText = ((tester.widget<AppBar>(find.byType(AppBar)).title as Text).data)!;
      expect(titleText, 'Sessão 3');
    });

    testWidgets('campos preenchidos carregam corretamente', (tester) async {
      await pump(tester, sessao: sessao);
      expect(find.text('Relato teste'), findsOneWidget);
      expect(find.text('Transcricao teste'), findsOneWidget);
    });
  });

  group('Persistencia de artigos sugeridos', () {
    late Sessao sessao;

    setUp(() async {
      sessao = Sessao(
        id: 's2', pacienteId: 'p1', numeroSessao: 4,
        data: DateTime(2026, 7, 14, 10, 0),
        relatoPosSessao: 'Relato teste',
        transcricaoRelato: 'Transcricao teste',
        geradoComIa: true,
        statusProcessamento: 'ia_processada',
        // Sessao de IA so chega ao fluxo de editar+salvar depois de revisada:
        // salvar sem revisao e bloqueado pelo gate (ver AGENTS.md 06/10/2026).
        revisadoPeloProfissional: true,
        artigosSugeridos:
            '1. Artigo Teste (2020) — Autor A\n   https://doi.org/10.1234/teste',
      );
      await Hive.box<Sessao>('sessoes').put('s2', sessao);
    });

    testWidgets('referencias aparecem ao abrir sessao salva', (tester) async {
      await pump(tester, sessao: sessao);
      expect(find.textContaining('Artigo Teste'), findsOneWidget);
    });

    testWidgets('referencias permanecem apos editar e salvar', (tester) async {
      await pump(tester, sessao: sessao);

      await tester.tap(find.text('Editar'));
      await tester.pump();
      await tester.pump();

      final relato = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.controller?.text == 'Relato teste');
      await tester.ensureVisible(relato);
      await tester.enterText(relato, 'Relato alterado e persistido');
      await tester.scrollUntilVisible(
        find.text('Salvar sessão'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final salvar = find.widgetWithText(FilledButton, 'Salvar sessão');
      await tester.ensureVisible(salvar);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(salvar);
        await Hive.box<Sessao>('sessoes').flush();
      });
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(() async {
        await Hive.box<Sessao>('sessoes').close();
        await Hive.openBox<Sessao>('sessoes');
      });
      final salva = Hive.box<Sessao>('sessoes').get('s2')!;
      expect(encryption.descriptografar(salva.relatoPosSessao), 'Relato alterado e persistido');
      expect(encryption.descriptografar(salva.artigosSugeridos), contains('Artigo Teste'));

      await pump(tester, sessao: SessaoService(encryption: encryption).buscarSessaoPorId('s2'));
      expect(find.textContaining('Artigo Teste'), findsOneWidget);
    });
  });

  group('Botao Marcar como revisado', () {
    late Sessao semSintese;
    late Sessao comSintese;
    late Sessao jaRevisada;

    setUp(() async {
      semSintese = Sessao(
        id: 's3', pacienteId: 'p1', numeroSessao: 5,
        data: DateTime(2026, 7, 20, 10, 0),
        relatoPosSessao: 'Relato teste',
        transcricaoRelato: 'Transcricao teste',
        geradoComIa: false,
        statusProcessamento: 'transcrito',
        revisadoPeloProfissional: false,
      );
      comSintese = Sessao(
        id: 's4', pacienteId: 'p1', numeroSessao: 6,
        data: DateTime(2026, 7, 21, 10, 0),
        relatoPosSessao: 'Relato teste',
        transcricaoRelato: 'Transcricao teste',
        eventosImportantes: 'Sintese gerada',
        geradoComIa: true,
        statusProcessamento: 'ia_processada',
        revisadoPeloProfissional: false,
      );
      jaRevisada = Sessao(
        id: 's5', pacienteId: 'p1', numeroSessao: 7,
        data: DateTime(2026, 7, 22, 10, 0),
        relatoPosSessao: 'Relato teste',
        transcricaoRelato: 'Transcricao teste',
        eventosImportantes: 'Sintese gerada',
        geradoComIa: true,
        statusProcessamento: 'revisado',
        revisadoPeloProfissional: true,
      );
      await Hive.box<Sessao>('sessoes').putAll({
        's3': semSintese,
        's4': comSintese,
        's5': jaRevisada,
      });
    });

    testWidgets('nao aparece quando ha apenas transcricao (sem sintese)', (tester) async {
      await pump(tester, sessao: semSintese);

      expect(find.text('Marcar como revisado'), findsNothing);
    });

    testWidgets('aparece quando a sintese foi gerada', (tester) async {
      await pump(tester, sessao: comSintese);

      expect(find.text('Marcar como revisado'), findsOneWidget);
    });

    testWidgets('nao aparece quando a sessao ja foi revisada', (tester) async {
      await pump(tester, sessao: jaRevisada);

      expect(find.text('Marcar como revisado'), findsNothing);
    });

    testWidgets('salvar e BLOQUEADO enquanto a sintese de IA nao for revisada',
        (tester) async {
      await pump(tester, sessao: comSintese);

      await tester.tap(find.text('Editar'));
      await tester.pump();
      await tester.pump();

      final relato = find.byWidgetPredicate((widget) =>
          widget is TextField && widget.controller?.text == 'Relato teste');
      await tester.ensureVisible(relato);
      await tester.enterText(relato, 'Nao deve ser persistido');
      await tester.scrollUntilVisible(
        find.text('Salvar sessão'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final salvar = find.widgetWithText(FilledButton, 'Salvar sessão');
      await tester.ensureVisible(salvar);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(salvar);
        await Hive.box<Sessao>('sessoes').flush();
      });
      await tester.pump(const Duration(milliseconds: 500));

      // O gate avisou...
      expect(find.textContaining('Confira e use'), findsOneWidget);

      // ...e nada foi gravado.
      await tester.runAsync(() async {
        await Hive.box<Sessao>('sessoes').close();
        await Hive.openBox<Sessao>('sessoes');
      });
      final salva = Hive.box<Sessao>('sessoes').get('s4')!;
      expect(
        encryption.descriptografar(salva.relatoPosSessao),
        'Relato teste',
        reason: 'o salvamento bloqueado nao pode ter alterado o registro',
      );
    });
  });

  group('Audio nao mantido (item 12)', () {
    const caminhoAudio = '/tmp/mentall/relato_s9_1.m4a';
    late Sessao sessao;

    setUp(() async {
      sessao = Sessao(
        id: 's9', pacienteId: 'p1', numeroSessao: 9,
        data: DateTime(2026, 7, 30, 10, 0),
        relatoPosSessao: 'Relato teste',
        audioRelatoPath: caminhoAudio,
        audioMantido: false,
      );
      await Hive.box<Sessao>('sessoes').put('s9', sessao);
    });

    testWidgets('salvar com "nao manter" exclui o arquivo fisico',
        (tester) async {
      await pump(tester, sessao: sessao);
      await tester.tap(find.text('Editar'));
      await tester.pump();
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Salvar sessão'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      final salvar = find.widgetWithText(FilledButton, 'Salvar sessão');
      await tester.ensureVisible(salvar);
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(salvar);
        await Hive.box<Sessao>('sessoes').flush();
      });
      await tester.pump(const Duration(milliseconds: 500));

      expect(fakeAudio.audiosExcluidos, contains(caminhoAudio));

      await tester.runAsync(() async {
        await Hive.box<Sessao>('sessoes').close();
        await Hive.openBox<Sessao>('sessoes');
      });
      final salva = Hive.box<Sessao>('sessoes').get('s9')!;
      expect(salva.audioRelatoPath, isEmpty);
    });
  });
}
