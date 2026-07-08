import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'hive_registrar.g.dart';
import 'models/lgpd/registro_auditoria.dart';
import 'models/paciente.dart';
import 'models/perfil_profissional.dart';
import 'models/sessao.dart';
import 'screens/app_start_page.dart';
import 'services/api_client.dart';
import 'services/hive_migration_service.dart';
import 'services/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    final port = Uri.base.port;
    debugPrint(
      '🌐 MentAll rodando na porta $port — '
      'use --web-port 5000 para manter os dados entre execuções.',
    );
  }

  await Hive.initFlutter();
  Hive.registerAdapters();

  await Hive.openBox<Paciente>('pacientes');
  await Hive.openBox<Sessao>('sessoes');
  await Hive.openBox<PerfilProfissional>('perfil_profissional');
  await Hive.openBox<RegistroAuditoria>('auditoria');
  await Hive.openBox<String>('app_config');

  await HiveMigrationService().executar();

  await _inicializarBackendAuth();

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      child: Container(
        color: const Color(0xFFF7F9FA),
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
              style: TextStyle(color: Colors.black54, height: 1.4),
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

Future<void> _inicializarBackendAuth() async {
  final authBox = await Hive.openBox<String>('auth_meta');
  final tokenExistente = authBox.get('jwt_token');

  if (tokenExistente != null && tokenExistente.isNotEmpty) {
    ApiClient.authToken = tokenExistente;
  }

  try {
    final response = await http.post(
      Uri.parse('${ApiClient.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': 'admin', 'password': 'admin'}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['access_token'] as String;
      await authBox.put('jwt_token', token);
      ApiClient.authToken = token;
    }
  } catch (e) {
    Log.erro(e, contexto: 'main:auth');
  }

  await authBox.close();
}

class MentAllApp extends StatelessWidget {
  const MentAllApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return MaterialApp(
      title: 'MentAll',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: corPrincipal),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F9FA),
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
