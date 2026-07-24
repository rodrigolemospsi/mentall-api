import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:prontuario_tcc/hive_registrar.g.dart';
import 'package:prontuario_tcc/models/compromisso.dart';
import 'package:prontuario_tcc/models/paciente.dart';
import 'package:prontuario_tcc/models/perfil_profissional.dart';
import 'package:prontuario_tcc/models/sessao.dart';
import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/screens/app_start_page.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/app_start');
    Hive.registerAdapters();
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<Compromisso>('compromissos');
  });

  tearDownAll(() async {
    await Hive.box<PerfilProfissional>('perfil_profissional').close();
    await Hive.box<Paciente>('pacientes').close();
    await Hive.box<Sessao>('sessoes').close();
    await Hive.box<Compromisso>('compromissos').close();
    await Hive.deleteBoxFromDisk('perfil_profissional');
    await Hive.deleteBoxFromDisk('pacientes');
    await Hive.deleteBoxFromDisk('sessoes');
    await Hive.deleteBoxFromDisk('compromissos');
  });

  setUp(() async {
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<Compromisso>('compromissos').clear();
  });

  testWidgets('sem perfil mostra configuracao', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AppStartPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Bem-vindo ao MentAll'), findsOneWidget);
  });

  testWidgets('com perfil mostra HomePage', (tester) async {
    await tester.runAsync(() async {
      await Hive.box<PerfilProfissional>('perfil_profissional')
          .put('1', PerfilProfissional(id: '1', nome: 'Dr. Teste'));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pacientesAtivosProvider.overrideWith(
            (ref) => Stream<List<Paciente>>.value([]),
          ),
          pacientesArquivadosProvider.overrideWith(
            (ref) => Stream<List<Paciente>>.value([]),
          ),
        ],
        child: const MaterialApp(home: AppStartPage()),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('Bem-vindo ao MentAll'), findsNothing);
    expect(find.textContaining('Dr. Teste'), findsOneWidget);
  });
}
