import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'hive_registrar.g.dart';
import 'models/paciente.dart';
import 'models/perfil_profissional.dart';
import 'models/sessao.dart';
import 'screens/app_start_page.dart';

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

  runApp(const MentAllApp());
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: corPrincipal,
        ),
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
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 14,
            ),
          ),
        ),
      ),
      home: const AppStartPage()
    );
  }
}