import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/services/telemetria_service.dart';
import 'package:prontuario_tcc/widgets/app_lock_gate.dart';

void main() {
  testWidgets('pausa bloqueia mas PRESERVA as rotas clinicas empilhadas', (
    tester,
  ) async {
    var bloqueou = false;
    final auth = _FakeAuth(
      onBloquear: () => bloqueou = true,
      desbloqueado: true,
      requerAutenticacao: true,
    );
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) => AppLockGate(
            lockScreenBuilder: (_, _) => const _TelaBloqueioFake(),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );

    Navigator.of(
      key.currentContext!,
    ).push(MaterialPageRoute(builder: (_) => const _TelaB()));
    await tester.pumpAndSettle();
    final navState = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navState.canPop(), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(bloqueou, isTrue);
    // O overlay aparece, mas as rotas continuam empilhadas (nada e destruido):
    // uma operacao em andamento na tela de sessao nao e perdida.
    expect(find.text('BLOQUEADO'), findsOneWidget);
    expect(navState.canPop(), isTrue);
  });

  testWidgets('overlay some ao concluir o desbloqueio', (tester) async {
    final auth = _FakeAuth(
      onBloquear: () {},
      desbloqueado: true,
      requerAutenticacao: true,
    );
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) => AppLockGate(
            lockScreenBuilder: (_, onDesbloqueado) =>
                _TelaBloqueioComBotao(onDesbloqueado: onDesbloqueado),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('BLOQUEADO'), findsOneWidget);

    await tester.tap(find.text('DESBLOQUEAR'));
    await tester.pumpAndSettle();

    expect(find.text('BLOQUEADO'), findsNothing);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('bloqueia por inatividade apos 5 minutos desbloqueado', (
    tester,
  ) async {
    var bloqueou = false;
    final auth = _FakeAuth(
      onBloquear: () => bloqueou = true,
      desbloqueado: true,
      requerAutenticacao: true,
    );
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) => AppLockGate(
            lockScreenBuilder: (_, _) => const _TelaBloqueioFake(),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );
    await tester.pump();

    expect(bloqueou, isFalse);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();

    expect(bloqueou, isTrue);
  });

  testWidgets('ao pausar envia heartbeat (visto por ultimo) antes de bloquear', (
    tester,
  ) async {
    final eventos = <String>[];
    final auth = _FakeAuth(
      onBloquear: () => eventos.add('bloquear'),
      desbloqueado: true,
      requerAutenticacao: true,
    );
    final telemetria = _FakeTelemetria(
      onHeartbeat: () => eventos.add('heartbeat'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          telemetriaServiceProvider.overrideWithValue(telemetria),
        ],
        child: MaterialApp(
          builder: (context, child) => AppLockGate(
            lockScreenBuilder: (_, _) => const _TelaBloqueioFake(),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );
    await tester.pump();
    eventos.clear(); // ignora o heartbeat do boot

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();

    expect(eventos, ['heartbeat', 'bloquear']);
  });

  testWidgets('nao bloqueia quando autenticacao nao e exigida', (tester) async {
    var bloqueou = false;
    final auth = _FakeAuth(
      onBloquear: () => bloqueou = true,
      desbloqueado: true,
      requerAutenticacao: false,
    );
    final key = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(auth)],
        child: MaterialApp(
          navigatorKey: key,
          builder: (context, child) => AppLockGate(
            lockScreenBuilder: (_, _) => const _TelaBloqueioFake(),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(bloqueou, isFalse);
    expect(find.text('BLOQUEADO'), findsNothing);
  });
}

class _TelaA extends StatelessWidget {
  const _TelaA();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('A'));
}

class _TelaB extends StatelessWidget {
  const _TelaB();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('B'));
}

class _TelaBloqueioFake extends StatelessWidget {
  const _TelaBloqueioFake();
  @override
  Widget build(BuildContext context) =>
      const Material(child: Center(child: Text('BLOQUEADO')));
}

class _TelaBloqueioComBotao extends StatelessWidget {
  const _TelaBloqueioComBotao({required this.onDesbloqueado});
  final VoidCallback onDesbloqueado;
  @override
  Widget build(BuildContext context) => Material(
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('BLOQUEADO'),
          TextButton(
            onPressed: onDesbloqueado,
            child: const Text('DESBLOQUEAR'),
          ),
        ],
      ),
    ),
  );
}

class _FakeAuth extends AuthService {
  _FakeAuth({
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

class _FakeTelemetria extends TelemetriaService {
  _FakeTelemetria({required this.onHeartbeat});

  final void Function() onHeartbeat;

  @override
  Future<void> heartbeat() async => onHeartbeat();
}
