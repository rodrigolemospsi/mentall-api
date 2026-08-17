import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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
import 'models/pacote.dart';
import 'models/perfil_profissional.dart';
import 'models/progresso_sessao.dart';
import 'models/sessao.dart';
import 'providers/service_providers.dart';
import 'screens/app_start_page.dart';
import 'services/auth_service.dart';
import 'services/demo_data_service.dart';
import 'services/encryption_service.dart';
import 'services/hive_migration_service.dart';
import 'services/logger.dart';

class _SecureHttpOverrides extends HttpOverrides {
  // SHA-256 fingerprints of allowed certificates (PEM format).
  // To obtain: openssl s_client -connect mentall-api.fly.dev:443 -servername mentall-api.fly.dev </dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout
  // Format: "SHA256 Fingerprint=XX:XX:XX:..."
  static const _certFingerprints = <String>[
    // Produção Fly.io - mentall-api.fly.dev
    // Atualize ao renovar certificado (geralmente a cada 90 dias via Let's Encrypt)
    // 'SHA256 Fingerprint=XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      // Permite localhost e redes locais para desenvolvimento
      if (host == 'localhost' || host.startsWith('192.168') || host == '127.0.0.1') {
        return true;
      }
      // Se não há pins configurados, usa validação padrão do sistema (não falha aberto)
      if (_certFingerprints.isEmpty) {
        return false;
      }
      try {
        final der = cert.der;
        final digest = sha256.convert(der);
        final hex = digest.toString();
        // Formata como "XX:XX:XX:..." para comparação
        final formatted = hex.replaceAllMapped(RegExp(r'.{2}'), (m) => '${m.group(0)}:').substring(0, 95);
        return _certFingerprints.any((fp) => fp.contains(formatted) || fp.contains(hex));
      } catch (_) {
        return false;
      }
    };
    return client;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _SecureHttpOverrides();

  final sw = Stopwatch()..start();

  if (kIsWeb) {
    final port = Uri.base.port;
    if (kDebugMode) {
      debugPrint(
        '\u{1F310} MentAll rodando na porta $port \u{2014} '
        'use --web-port 5000 para manter os dados entre execu\u00E7\u00F5es.',
      );
    }
  }

  await Hive.initFlutter();
  if (kDebugMode) debugPrint('[startup] initFlutter: ${sw.elapsedMilliseconds}ms');
  Hive.registerAdapters();
  if (kDebugMode) debugPrint('[startup] registerAdapters: ${sw.elapsedMilliseconds}ms');

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
    Hive.openBox('avaliacoes_iniciais'),
    Hive.openBox('anamneses_enviadas'),
    Hive.openBox('respostas_escalas'),
    Hive.openBox<Pacote>('pacotes'),
    Hive.openBox<ProgressoSessao>('progresso_sessoes'),
  ]);
  debugPrint('[startup] openBoxes: ${sw.elapsedMilliseconds}ms');

  await HiveMigrationService().executar();
  debugPrint('[startup] migration: ${sw.elapsedMilliseconds}ms');

  final encryption = EncryptionService();
  EncryptionService.setInstance(encryption);
  await encryption.inicializar();
  Log.setEncryptionService(encryption);

  final auth = AuthService(encryption);
  await auth.inicializar();
  if (!encryption.possuiChaveProtegida) {
    await auth.gerarChave();
  }
  debugPrint('[startup] auth: ${sw.elapsedMilliseconds}ms');

  await DemoDataService(encryption: encryption).semearSeNecessario();
  debugPrint('[startup] demo: ${sw.elapsedMilliseconds}ms');

  ErrorWidget.builder = (FlutterErrorDetails details) {
    final mensagemTecnica = kDebugMode ? details.exceptionAsString() : null;
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
              'Ocorreu um erro ao exibir esta tela. Tente reiniciar o aplicativo.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            if (mensagemTecnica != null) ...[
              const SizedBox(height: 16),
              Text(
                mensagemTecnica,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  };

  runApp(
    ProviderScope(
      overrides: [
        encryptionServiceProvider.overrideWithValue(encryption),
        authServiceProvider.overrideWithValue(auth),
      ],
      child: const MentAllApp(),
    ),
  );
}

class MentAllApp extends ConsumerWidget {
  const MentAllApp({super.key});

  static const Color _corPrimaria = Color(0xFF2066FF);

  ThemeData _criarTema(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _corPrimaria,
      brightness: brightness,
    );

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16),
        bodyMedium: TextStyle(fontSize: 14),
        bodySmall: TextStyle(fontSize: 12),
        labelSmall: TextStyle(fontSize: 10),
      ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
      title: 'MentAll PRO',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaleFactor:
                MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.5),
          ),
          child: child!,
        );
      },
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
