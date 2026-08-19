import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import '../providers/service_providers.dart';
import '../services/logger.dart';
import '../widgets/lista_sessoes.dart';

// ---------------------------------------------------------------------------
// Top-level archive / restore helpers
// ---------------------------------------------------------------------------

Future<void> _confirmarArquivamentoSessao(
  BuildContext context,
  WidgetRef ref,
  Sessao sessao,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Arquivar sessão'),
        content: Text(
          'Deseja arquivar a sessão ${sessao.numeroSessao}?\n\n'
          'Ela deixará de aparecer no histórico principal, mas continuará preservada no prontuário.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.archive_outlined),
            label: const Text('Arquivar'),
          ),
        ],
      );
    },
  );

  if (confirmar != true) return;

  try {
    await ref.read(sessaoServiceProvider).arquivarSessao(sessao);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão arquivada com sucesso.')),
      );
    }
  } catch (erro) {
    Log.erro(erro, contexto: 'paciente_sessoes_tab:arquivarSessao');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível arquivar a sessão. Tente novamente.')),
      );
    }
  }
}

Future<void> _confirmarRestauracaoSessao(
  BuildContext context,
  WidgetRef ref,
  Sessao sessao,
  String doOuDa,
  String termoSingular,
) async {
  final confirmar = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Restaurar sessão'),
        content: Text(
          'Deseja restaurar a sessão ${sessao.numeroSessao}?\n\n'
          'Ela voltará a aparecer no histórico ativo $doOuDa $termoSingular.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context, true);
            },
            icon: const Icon(Icons.restore_outlined),
            label: const Text('Restaurar'),
          ),
        ],
      );
    },
  );

  if (confirmar != true) return;

  try {
    await ref.read(sessaoServiceProvider).restaurarSessao(sessao);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão restaurada com sucesso.')),
      );
    }
  } catch (erro) {
    Log.erro(erro, contexto: 'paciente_sessoes_tab:restaurarSessao');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível restaurar a sessão. Tente novamente.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// PacienteSessoesTab
// ---------------------------------------------------------------------------

class PacienteSessoesTab extends ConsumerWidget {
  final Paciente paciente;

  const PacienteSessoesTab({super.key, required this.paciente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessaoService = ref.watch(sessaoServiceProvider);

    final perfil = ref.read(perfilProfissionalServiceProvider).obterPerfil();
    final termoSingular = perfil?.termoSingular ?? 'paciente';
    final usaPessoaAtendida = termoSingular == 'pessoa atendida';
    final doOuDa = usaPessoaAtendida ? 'da' : 'do';
    final desteOuDesta = usaPessoaAtendida ? 'desta' : 'deste';

    return StreamBuilder(
      stream: sessaoService.observarSessoes(),
      builder: (context, snapshot) {
        final sessoesAtivas = sessaoService.listarSessoesDoPaciente(paciente.id);
        final sessoesArquivadas = sessaoService.listarSessoesArquivadasDoPaciente(paciente.id);

        if (sessoesArquivadas.isEmpty) {
          return Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: ListaSessoesAtivas(
                sessoes: sessoesAtivas,
                paciente: paciente,
                termoSingular: termoSingular,
                doOuDa: doOuDa,
                onArquivar: (s) => _confirmarArquivamentoSessao(context, ref, s),
              ),
            ),
          );
        }

        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              TabBar(
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3,
                tabs: [
                  Tab(text: 'Ativas (${sessoesAtivas.length})'),
                  Tab(text: 'Arquivadas (${sessoesArquivadas.length})'),
                ],
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.55,
                child: TabBarView(
                  children: [
                    ListaSessoesAtivas(
                      sessoes: sessoesAtivas,
                      paciente: paciente,
                      termoSingular: termoSingular,
                      doOuDa: doOuDa,
                      onArquivar: (s) => _confirmarArquivamentoSessao(context, ref, s),
                    ),
                    ListaSessoesArquivadas(
                      sessoes: sessoesArquivadas,
                      paciente: paciente,
                      termoSingular: termoSingular,
                      desteOuDesta: desteOuDesta,
                      onRestaurar: (s) => _confirmarRestauracaoSessao(context, ref, s, doOuDa, termoSingular),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
