import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'main_shell.dart';
import 'perfil_profissional_form_page.dart';

final _pageIndexProvider = StateProvider<int>((ref) => 0);

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();

  void _concluir() {
    ref.read(configuracoesServiceProvider).onboardingConcluido = true;
    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => perfil == null
            ? const PerfilProfissionalFormPage()
            : const MainShell(),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(_pageIndexProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _concluir,
                child: Text(
                  'Pular',
                  style: TextStyle(color: context.corTextoBody),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (i) =>
                    ref.read(_pageIndexProvider.notifier).state = i,
                children: [
                  Image.asset(
                    'assets/images/prontuario_inteligente.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  Image.asset(
                    'assets/images/sua_abordagem_001_1.jpeg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                  Image.asset(
                    'assets/images/seguranca_app.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final ativo = i == pageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: ativo ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: ativo
                        ? context.corPrimaria
                        : context.corTextoDisabled,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            if (pageIndex == 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _concluir,
                    child: const Text('Começar'),
                  ),
                ),
              )
            else
              const SizedBox(height: 48),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
