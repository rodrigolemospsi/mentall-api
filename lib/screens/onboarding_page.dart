import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import 'main_shell.dart';

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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
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
                children: const [
                  _Slide(
                    emoji: '📋',
                    title: 'Prontuário inteligente',
                    description:
                        'Registre sessões com transcrição automática e síntese clínica por IA adaptada à sua abordagem.',
                  ),
                  _Slide(
                    emoji: '🧠',
                    title: 'Sua abordagem, suas regras',
                    description:
                        '14 abordagens clínicas disponíveis. O prontuário se adapta à sua linha terapêutica.',
                  ),
                  _Slide(
                    emoji: '🔒',
                    title: 'Segurança e privacidade',
                    description:
                        'Criptografia AES-256. PIN de acesso. Seus dados nunca saem do app sem sua autorização.',
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

class _Slide extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _Slide({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: context.corTextoHeading,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 16,
              color: context.corTextoBody,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
