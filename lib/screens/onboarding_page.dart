import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'main_shell.dart';
import 'perfil_profissional_form_page.dart';

class OnboardingPage extends ConsumerWidget {
  const OnboardingPage({super.key});

  void _concluir(BuildContext context, WidgetRef ref) {
    ref.read(configuracoesServiceProvider).setOnboardingConcluido(true);
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            perfil == null ? const PerfilProfissionalFormPage() : const MainShell(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/sua_abordagem_001_1.jpeg',
            fit: BoxFit.cover,
            semanticLabel: 'Apresentação MentAll PRO',
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () => _concluir(context, ref),
                  child: Text(
                    'Pular',
                    style: TextStyle(
                      color: context.corTextoBody,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}