import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/screens/app_start_page.dart';
import 'package:prontuario_tcc/screens/login_page.dart';
import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/perfil_profissional_service.dart';

void main() {
  setUpAll(() async {
    Hive.init('test/temp_hive/app_start');
    Hive.registerAdapters();
    await Hive.openBox<PerfilProfissional>('perfil_profissional');
    await Hive.openBox<Paciente>('pacientes');
    await Hive.openBox<Sessao>('sessoes');
    await Hive.openBox<Compromisso>('compromissos');
    await Hive.openBox<ContratoTerapeutico>('contratos');
    await Hive.openBox<Pacote>('pacotes');
    await Hive.openBox<ProgressoSessao>('progresso_sessoes');
    await Hive.openBox<String>('app_config');
    await Hive.openBox<String>('auth_meta');
    await Hive.openBox<String>('encryption_meta');
    await Hive.openBox('auditoria');
    await Hive.openBox('anamneses_enviadas');
    await Hive.openBox('avaliacoes_iniciais');
    await Hive.openBox('respostas_escalas');
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
    await Hive.deleteBoxFromDisk('contratos');
    await Hive.deleteBoxFromDisk('pacotes');
    await Hive.deleteBoxFromDisk('progresso_sessoes');
    await Hive.deleteBoxFromDisk('app_config');
    await Hive.deleteBoxFromDisk('auth_meta');
    await Hive.deleteBoxFromDisk('encryption_meta');
    await Hive.deleteBoxFromDisk('auditoria');
    await Hive.deleteBoxFromDisk('anamneses_enviadas');
    await Hive.deleteBoxFromDisk('avaliacoes_iniciais');
    await Hive.deleteBoxFromDisk('respostas_escalas');
  });

  setUp(() async {
    await Hive.box<PerfilProfissional>('perfil_profissional').clear();
    await Hive.box<Paciente>('pacientes').clear();
    await Hive.box<Sessao>('sessoes').clear();
    await Hive.box<Compromisso>('compromissos').clear();
    await Hive.box<String>('auth_meta')
        .put('account_email', 'teste@exemplo.com');
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

    expect(
      find.text(
          'O app MentAll Pro valoriza a abordagem psicológica que você atua! Configure agora o seu perfil profissional:'),
      findsOneWidget,
    );
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

    expect(
      find.text(
          'O app MentAll Pro valoriza a abordagem psicológica que você atua! Configure agora o seu perfil profissional:'),
      findsNothing,
    );
    expect(find.textContaining('Dr. Teste'), findsOneWidget);
  });

  testWidgets('bloqueia por inatividade apos 5 minutos desbloqueado',
      (tester) async {
    var bloqueado = false;
    final authFake = _FakeAuthService(
      onBloquear: () => bloqueado = true,
      desbloqueado: true,
      requerAutenticacao: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authFake),
          perfilProfissionalServiceProvider.overrideWith(
            (_) => PerfilProfissionalService(encryption: null),
          ),
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

    expect(find.byType(LoginPage), findsNothing);
    expect(bloqueado, isFalse);

    // Nenhum toque por 5 minutos dispara o bloqueio por inatividade.
    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(bloqueado, isTrue);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required this.onBloquear,
    required this.desbloqueado,
    required this.requerAutenticacao,
  }) : super(EncryptionService());

  final void Function() onBloquear;
  @override
  final bool desbloqueado;
  @override
  final bool requerAutenticacao;

  @override
  Future<void> bloquear() async => onBloquear();
}
