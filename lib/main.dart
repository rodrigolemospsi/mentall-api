import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'hive_registrar.g.dart';
import 'models/compromisso.dart';
import 'models/contrato_terapeutico.dart';
import 'models/lgpd/registro_auditoria.dart';
import 'models/paciente.dart';
import 'models/perfil_profissional.dart';
import 'models/sessao.dart';
import 'providers/service_providers.dart';
import 'screens/app_start_page.dart';
import 'services/api_client.dart';
import 'services/hive_migration_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sw = Stopwatch()..start();

  if (kIsWeb) {
    final port = Uri.base.port;
    debugPrint(
      '\u{1F310} MentAll rodando na porta $port \u{2014} '
      'use --web-port 5000 para manter os dados entre execu\u00E7\u00F5es.',
    );
  }

  await Hive.initFlutter();
  debugPrint('[startup] initFlutter: ${sw.elapsedMilliseconds}ms');
  Hive.registerAdapters();
  debugPrint('[startup] registerAdapters: ${sw.elapsedMilliseconds}ms');

  await Future.wait([
    Hive.openBox<Paciente>('pacientes'),
    Hive.openBox<Sessao>('sessoes'),
    Hive.openBox<Compromisso>('compromissos'),
    Hive.openBox<PerfilProfissional>('perfil_profissional'),
    Hive.openBox<RegistroAuditoria>('auditoria'),
    Hive.openBox<String>('app_config'),
    Hive.openBox<String>('auth_meta'),
    Hive.openBox<String>('encryption_meta'),
    Hive.openBox<ContratoTerapeutico>('contratos'),
    Hive.openBox<String>('logs_tecnicos'),
    Hive.openBox('schema_meta'),
  ]);
  debugPrint('[startup] openBoxes: ${sw.elapsedMilliseconds}ms');

  await HiveMigrationService().executar();
  debugPrint('[startup] migration: ${sw.elapsedMilliseconds}ms');

  _inicializarBackendAuth();
  debugPrint('[startup] auth: ${sw.elapsedMilliseconds}ms');

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: const Color(0xFFFFFFFF),
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
              'Ocorreu um erro ao exibir esta tela. Isso pode ser causado por dados incompatíveis de uma versão anterior do app.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
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

class MentAllApp extends ConsumerWidget {
  const MentAllApp({super.key});

  static const Color _corPrimaria = Color(0xFF2563EB);

  ThemeData _criarTema(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _corPrimaria,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: brightness == Brightness.light ? 1 : 4,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(configuracoesRevisaoProvider);
    final config = ref.watch(configuracoesServiceProvider);
    final temaEscuro = config.temaEscuro;

    return MaterialApp(
      title: 'MentAll',
      debugShowCheckedModeBanner: false,
      theme: _criarTema(Brightness.light),
      darkTheme: _criarTema(Brightness.dark),
      themeMode: temaEscuro ? ThemeMode.dark : ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      locale: const Locale('pt', 'BR'),
      home: const AppStartPage(),
    );
  }
}
