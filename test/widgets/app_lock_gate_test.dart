import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prontuario_tcc/providers/service_providers.dart';
import 'package:prontuario_tcc/services/auth_service.dart';
import 'package:prontuario_tcc/services/encryption_service.dart';
import 'package:prontuario_tcc/widgets/app_lock_gate.dart';

void main() {
  testWidgets('pausa bloqueia e remove rotas clinicas empilhadas',
      (tester) async {
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
            navigatorKey: key,
            // Em produção o padrão é AppStartPage; aqui injetamos para testar
            // a limpeza de rotas sem acoplar o gate a boxes Hive.
            lockScreenBuilder: (_) => const _TelaA(),
            child: child!,
          ),
          home: const _TelaA(),
        ),
      ),
    );

    Navigator.of(key.currentContext!).push(
      MaterialPageRoute(builder: (_) => const _TelaB()),
    );
    await tester.pumpAndSettle();
    final navState = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navState.canPop(), isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));

    expect(bloqueou, isTrue);
    expect(navState.canPop(), isFalse);
  });

  testWidgets('bloqueia por inatividade apos 5 minutos desbloqueado',
      (tester) async {
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
            navigatorKey: key,
            lockScreenBuilder: (_) => const _TelaA(),
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

  testWidgets('nao bloqueia quando autenticacao nao e exigida',
      (tester) async {
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
            navigatorKey: key,
            lockScreenBuilder: (_) => const _TelaA(),
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
