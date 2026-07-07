import 'package:flutter/material.dart';

import '../services/perfil_profissional_service.dart';
import 'home_page.dart';
import 'perfil_profissional_form_page.dart';

class AppStartPage extends StatefulWidget {
  const AppStartPage({super.key});

  @override
  State<AppStartPage> createState() => _AppStartPageState();
}

class _AppStartPageState extends State<AppStartPage> {
  final PerfilProfissionalService _perfilService =
      PerfilProfissionalService();

  @override
  Widget build(BuildContext context) {
    final perfil = _perfilService.obterPerfil();

    if (perfil == null) {
      return const PerfilProfissionalFormPage();
    }

    return const HomePage();
  }
}