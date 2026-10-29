import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

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
import 'services/demo_lojas_service.dart';
import 'services/encryption_service.dart';
import 'services/hive_migration_service.dart';
import 'services/logger.dart';
import 'services/pdf_export_service.dart';
import 'utils/mentall_colors.dart';
import 'utils/raio.dart';
import 'utils/tipografia.dart';
import 'widgets/app_lock_gate.dart';

class _SecureHttpOverrides extends HttpOverrides {
  // SHA-256 fingerprints of allowed certificates (PEM format).
  // To obtain: openssl s_client -connect mentall-api.fly.dev:443 -servername mentall-api.fly.dev </dev/null 2>/dev/null | openssl x509 -fingerprint -sha256 -noout
  // Format: "SHA256 Fingerprint=XX:XX:XX:..."
  static const _certFingerprints = <String>[
    // Produção Fly.io - mentall-api.fly.dev (Let's Encrypt, renova a cada ~90 dias).
    // Manter os 2 últimos fingerprints (o anterior + o atual) para tolerância de
    // transição durante a renovação.
    'SHA256 Fingerprint=25:9A:3B:9C:DA:F4:BA:BB:BE:5E:B7:81:BE:23:8A:52:12:15:DF:90:AF:E8:F5:15:17:99:30:F2:A6:A8:59:B4',
    'SHA256 Fingerprint=F6:3E:15:49:6D:97:94:61:45:C9:E5:D5:CC:21:C8:3F:12:DD:2E:35:14:DD:9A:B2:21:40:85:69:53:71:9B:19',
  ];

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      // Permite loopback para desenvolvimento local (HTTP local já é liberado
      // via network_security_config; aqui cobre HTTPS em 127.0.0.1).
      if (host == 'localhost' || host == '127.0.0.1') {
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

/// DSN do Sentry, definido em build via `--dart-define=SENTRY_DSN=...`.
///
/// Vazio (padrão) = relatório de erros DESATIVADO: o app se comporta exatamente
/// como antes e nada é enviado para fora. Só ativa quando o dono informar o DSN.
const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

Future<void> main() async {
  if (_sentryDsn.isEmpty) {
    await _iniciarApp();
    return;
  }
  await SentryFlutter.init(_configurarSentry, appRunner: _iniciarApp);
}

/// Configura o relatório de erros priorizando a privacidade (LGPD).
///
/// Nunca envia PII nem conteúdo clínico: sem usuário, sem corpo de requisição
/// e sem breadcrumbs. A mensagem + stack trace bastam para diagnosticar.
void _configurarSentry(SentryFlutterOptions options) {
  options
    ..dsn = _sentryDsn
    ..sendDefaultPii = false
    ..maxRequestBodySize = MaxRequestBodySize.never
    ..environment = kReleaseMode ? 'production' : 'debug'
    ..beforeSend = _removerDadosSensiveis;
}

SentryEvent? _removerDadosSensiveis(SentryEvent event, Hint hint) {
  event.user = null;
  event.request = null;
  event.breadcrumbs = [];
  return event;
}

Future<void> _iniciarApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _SecureHttpOverrides();
  // Fontes Unicode dos PDFs (sem elas, travessão/aspas saem como quadrados).
  await PdfExportService.carregarAssets();

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

  // Expurgo unico do log tecnico em texto puro deixado por versoes anteriores.
  await Log.purgarHistoricoLegado();

  final encryption = EncryptionService();
  EncryptionService.setInstance(encryption);
  await encryption.inicializar();
  Log.setEncryptionService(encryption);

  final auth = AuthService(encryption);
  await auth.inicializar();
  if (!encryption.possuiChaveProtegida) {
    final chaveDuravel = await auth.gerarChave();
    if (!chaveDuravel) {
      // Proteção de dados em repouso indisponível. Em vez de gravar dados
      // clínicos em texto puro (falha fail-open da vuln-0013), sinalizamos o
      // fail-closed: o AppStartPage irá bloquear o uso até o dispositivo ser
      // configurado (biometria/tela bloqueada).
      EncryptionService.protecaoIndisponivel = true;
      debugPrint(
        'AVISO: criptografia não durável — dados clínicos NÃO serão persistidos '
        'em texto puro neste dispositivo.',
      );
      Log.auditoria(
        'Criptografia não durável: uso bloqueado para não gravar dados clínicos '
        'em texto puro (sem bloqueio de tela/biometria).',
        contexto: 'Seguranca',
      );
    }
  } else if (!encryption.protecaoDuravel) {
    // Instalações antigas (pré-vuln-0013): a chave já persiste (ex.: cofre
    // protegido por biometria/tela bloqueada). Considera proteção durável para
    // não gerar falso fail-closed no upgrade.
    await encryption.marcarProtecaoDuravel();
  }
  debugPrint('[startup] auth: ${sw.elapsedMilliseconds}ms');

  // `DEMO_LOJAS=true` semeia um dataset para as capturas de tela das lojas
  // (Helena, 23 pacientes, agenda e financeiro) no lugar do paciente demo.
  if (DemoLojasService.ativoPorPadrao) {
    await DemoLojasService(encryption: encryption).semearSeNecessario();
  } else {
    await DemoDataService(encryption: encryption).semearSeNecessario();
  }
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
                fontSize: Tipografia.xl,
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
                  fontSize: Tipografia.sm,
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
      child: MentAllApp(),
    ),
  );
}

class MentAllApp extends ConsumerWidget {
  MentAllApp({super.key});

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ThemeData _criarTema(Brightness brightness) {
    final escuro = brightness == Brightness.dark;
    final colorScheme = _esquemaPainel(brightness);
    final corCard = escuro
        ? PainelCores.escuroCard
        : colorScheme.surfaceContainerLowest;
    final raioBotao = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Raio.md),
    );

    return ThemeData(
      colorScheme: colorScheme,
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontSize: Tipografia.xxl, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontSize: Tipografia.xl, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: Tipografia.lg, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: Tipografia.md),
        bodyMedium: TextStyle(fontSize: Tipografia.base),
        bodySmall: TextStyle(fontSize: Tipografia.sm),
        labelSmall: TextStyle(fontSize: Tipografia.xxs),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: corCard,
        elevation: 0,
        shadowColor: escuro
            ? Colors.black
            : PainelCores.texto.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.xl),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: raioBotao,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: Tipografia.baseMd,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: raioBotao,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: Tipografia.baseMd,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: raioBotao,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: Tipografia.baseMd,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: corCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          borderSide: BorderSide(color: colorScheme.error, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: Tipografia.smMd,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: corCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.xl),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        titleTextStyle: TextStyle(
          fontSize: Tipografia.lg,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        contentTextStyle: TextStyle(
          fontSize: Tipografia.base,
          color: colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: corCard,
        modalBackgroundColor: corCard,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Raio.xl),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        actionTextColor: colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.md),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: colorScheme.surfaceContainerHigh,
        circularTrackColor: colorScheme.surfaceContainerHigh,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.xl),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: corCard,
        indicatorColor: colorScheme.primaryContainer,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: Tipografia.sm,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: corCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Raio.md),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        textStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: Tipografia.base,
        ),
      ),
    );
  }

  /// Esquema de cores do painel do dono (backend/admin_ui.py, tema v2).
  ColorScheme _esquemaPainel(Brightness brightness) {
    final base = ColorScheme.fromSeed(
      seedColor: PainelCores.roxo,
      brightness: brightness,
    );

    if (brightness == Brightness.dark) {
      return base.copyWith(
        primary: PainelCores.escuroPrimaria,
        onPrimary: const Color(0xFF1E1B4B),
        primaryContainer: PainelCores.sidebar2,
        onPrimaryContainer: const Color(0xFFEDE9FE),
        secondary: const Color(0xFFC4B5FD),
        onSecondary: const Color(0xFF1E1B4B),
        secondaryContainer: const Color(0xFF3B2A72),
        onSecondaryContainer: const Color(0xFFEDE9FE),
        tertiary: const Color(0xFFDDD6FE),
        onTertiary: const Color(0xFF1E1B4B),
        tertiaryContainer: PainelCores.roxoEscuro,
        onTertiaryContainer: const Color(0xFFEDE9FE),
        error: const Color(0xFFF87171),
        onError: const Color(0xFF450A0A),
        errorContainer: const Color(0xFF7F1D1D),
        onErrorContainer: const Color(0xFFFEE2E2),
        surface: PainelCores.escuroFundo,
        onSurface: PainelCores.escuroTexto,
        onSurfaceVariant: PainelCores.escuroTextoMuted,
        surfaceContainerLowest: const Color(0xFF111C2E),
        surfaceContainerLow: PainelCores.escuroSuperficie,
        surfaceContainer: PainelCores.escuroCard,
        surfaceContainerHigh: const Color(0xFF243447),
        surfaceContainerHighest: PainelCores.escuroBorda,
        outline: const Color(0xFF475569),
        outlineVariant: PainelCores.escuroBorda,
        inverseSurface: PainelCores.escuroTexto,
        onInverseSurface: PainelCores.escuroFundo,
        inversePrimary: PainelCores.roxo,
        shadow: Colors.black,
        scrim: Colors.black,
      );
    }

    return base.copyWith(
      primary: PainelCores.roxo,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFEDE9FE),
      onPrimaryContainer: const Color(0xFF2E1065),
      secondary: PainelCores.sidebar1,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFEDE9FE),
      onSecondaryContainer: const Color(0xFF2E1065),
      tertiary: PainelCores.roxoClaro,
      onTertiary: const Color(0xFF2E1065),
      tertiaryContainer: const Color(0xFFDDD6FE),
      onTertiaryContainer: const Color(0xFF2E1065),
      error: PainelCores.erro,
      onError: Colors.white,
      errorContainer: const Color(0xFFFDECEC),
      onErrorContainer: const Color(0xFF7F1D1D),
      surface: PainelCores.fundo,
      onSurface: PainelCores.texto,
      onSurfaceVariant: PainelCores.textoMuted,
      surfaceContainerLowest: PainelCores.card,
      surfaceContainerLow: PainelCores.superficie,
      surfaceContainer: PainelCores.chip,
      surfaceContainerHigh: const Color(0xFFE8ECF7),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: PainelCores.bordaForte,
      outlineVariant: PainelCores.borda,
      inverseSurface: PainelCores.texto,
      onInverseSurface: const Color(0xFFF1F5F9),
      inversePrimary: PainelCores.roxoClaro,
      shadow: PainelCores.texto,
      scrim: PainelCores.texto,
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
      navigatorKey: _navigatorKey,
      builder: (context, child) {
        return AppLockGate(
          child: MediaQuery(
            // Não limita a ampliação de texto do sistema (acessibilidade). O
            // textScaler vem do dispositivo e os layouts devem se adaptar por
            // rolagem; a validação em 200% faz parte da matriz visual.
            data: MediaQuery.of(context).copyWith(
              textScaler: MediaQuery.of(context).textScaler.clamp(
                minScaleFactor: 0.8,
                maxScaleFactor: 2.0,
              ),
            ),
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => AppLockGate.onUserActivity?.call(),
              child: child!,
            ),
          ),
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
