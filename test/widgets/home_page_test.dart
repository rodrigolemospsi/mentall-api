import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/lgpd/registro_auditoria.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/screens/home_page.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/home_page');
    Hive.registerAdapters();
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<Compromisso>('compromissos');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox<RegistroAuditoria>('auditoria');
  });

  tearDownAll(() async {
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.box<Compromisso>('compromissos').close();
    await Hive.box<RegistroAuditoria>('auditoria').close();
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('compromissos');
    await Hive.deleteBoxFromDisk('encryption_meta');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auditoria');
  });

  setUp(() async {
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<Compromisso>('compromissos').clear();
  });

  ProviderScope criarApp(List<Paciente> pacientes) {
    return ProviderScope(
      overrides: [
        pacientesAtivosProvider.overrideWith(
          (ref) => Stream<List<Paciente>>.value(pacientes.where((p) => p.ativo).toList()),
        ),
        pacientesArquivadosProvider.overrideWith(
          (ref) => Stream<List<Paciente>>.value(pacientes.where((p) => !p.ativo).toList()),
        ),
      ],
      child: const MaterialApp(
        home: HomePage(),
      ),
    );
  }

  testWidgets('deve exibir saudacao padrao quando sem perfil', (tester) async {
    await tester.pumpWidget(criarApp([]));
    await tester.pump();

    expect(find.byType(Image), findsWidgets);
  });

  testWidgets('deve exibir saudacao com nome do profissional', (tester) async {
    await tester.runAsync(() async {
      await Hive.box<PerfilProfissional>('perfil_profissional')
          .put('1', PerfilProfissional(id: '1', nome: 'Dr. Teste'));
    });

    await tester.pumpWidget(criarApp([]));
    await tester.pump();

    expect(find.textContaining('Dr. Teste'), findsOneWidget);
  });

  testWidgets('deve exibir estado vazio quando sem pacientes', (tester) async {
    await tester.runAsync(() async {
      await Hive.box<PerfilProfissional>('perfil_profissional')
          .put('1', PerfilProfissional(id: '1', nome: 'Dr. Teste'));
    });

    await tester.pumpWidget(criarApp([]));
    await tester.pump();
    await tester.pump();

    expect(find.text('Hoje'), findsOneWidget);
  });

  testWidgets('deve mostrar indicador de sessoes pendentes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    await tester.runAsync(() async {
      await Hive.box<PerfilProfissional>('perfil_profissional')
          .put('1', PerfilProfissional(id: '1', nome: 'Dr. Teste'));
      await Hive.box<Paciente>('pacientes')
          .put('1', Paciente(id: '1', nome: 'Maria'));
      await Hive.box<Sessao>('sessoes').put('1', Sessao(
        id: '1',
        pacienteId: '1',
        numeroSessao: 1,
        data: DateTime.now(),
        apontamentosCopiloto: 'conteudo gerado pela ia',
        geradoComIa: true,
      ));
    });

    final pacientes = [
      Paciente(id: '1', nome: 'Maria'),
    ];

    await tester.pumpWidget(criarApp(pacientes));
    await tester.pump();
    await tester.pump();

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -800),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('pendente'), findsWidgets);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
