import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import 'home_page.dart';
import 'perfil_profissional_form_page.dart';

class AppStartPage extends ConsumerWidget {
  const AppStartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();

    if (perfil == null) {
      return const PerfilProfissionalFormPage();
    }

    return const HomePage();
  }
}
