import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'hive_registrar.g.dart';
import 'models/compromisso.dart';
import 'models/lgpd/registro_auditoria.dart';
import 'models/paciente.dart';
import 'models/perfil_profissional.dart';
import 'models/sessao.dart';
import 'screens/app_start_page.dart';
import 'services/api_client.dart';
import 'services/hive_migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final port = Uri.base.port;
    debugPrint(
      '\u{1F310} MentAll rodando na porta $port \u{2014} '
      'use --web-port 5000 para manter os dados entre execu\u00E7\u00F5es.',
    );
  }

  await Hive.initFlutter();
  Hive.registerAdapters();

  await Future.wait([
    Hive.openBox<Paciente>('pacientes'),
    Hive.openBox<Sessao>('sessoes'),
    Hive.openBox<Compromisso>('compromissos'),
    Hive.openBox<PerfilProfissional>('perfil_profissional'),
    Hive.openBox<RegistroAuditoria>('auditoria'),
    Hive.openBox<String>('app_config'),
    Hive.openBox<String>('auth_meta'),
    Hive.openBox<String>('encryption_meta'),
  ]);

  await HiveMigrationService().executar();

  _inicializarBackendAuth();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 48),
            const SizedBox(height: 16),
            const Text(
              'Erro inesperado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD32F2F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ocorreu um erro ao exibir esta tela. Isso pode ser causado por dados incompat\u00EDveis de uma vers\u00E3o anterior do app.',
              style: const TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            Text(
              details.exceptionAsString(),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: MentAllApp()));
}

void _inicializarBackendAuth() {
  try {
    final token = Hive.box<String>('auth_meta').get('jwt_token');
    if (token != null && token.isNotEmpty) {
      ApiClient.authToken = token;
    }
  } catch (_) {}
}

class MentAllApp extends StatelessWidget {
  const MentAllApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);

    return MaterialApp(
      title: 'MentAll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: corPrincipal),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: corPrincipal,
          foregroundColor: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: corPrincipal,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
        ),
      ),
      home: const AppStartPage(),
    );
  }
}

