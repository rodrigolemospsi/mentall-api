import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/avaliacao_inicial.dart';
import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';

class AnamneseCard extends ConsumerWidget {
  final String pacienteId;
  final String termoSingular;

  const AnamneseCard({
    super.key,
    required this.pacienteId,
    required this.termoSingular,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avaliacaoAsync = ref.watch(avaliacaoInicialPorPacienteProvider(pacienteId));
    final avaliacao = avaliacaoAsync.valueOrNull;

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      elevation: Theme.of(context).brightness == Brightness.dark ? 4 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_outlined, color: context.corPrimaria, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Avaliação Inicial',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _abrirFormAnamnese(context, ref, avaliacao),
                  icon: Icon(Icons.edit_outlined, size: 16, color: context.corPrimaria),
                  label: Text(
                    avaliacao != null ? 'Editar' : 'Preencher',
                    style: TextStyle(fontSize: 13, color: context.corPrimaria),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (avaliacao == null || !avaliacao.preenchida)
              Text(
                'Registre a queixa principal, histórico clínico, medicamentos e hipótese diagnóstica.',
                style: TextStyle(fontSize: 13, color: context.corTextoMuted, height: 1.4),
              )
            else ...[
              _campoResumo(context, 'Queixa principal', avaliacao.queixaPrincipal),
              _campoResumo(context, 'Histórico', avaliacao.historicoClinico),
              if (avaliacao.medicamentos.isNotEmpty)
                _campoResumo(context, 'Medicamentos', avaliacao.medicamentos),
              if (avaliacao.hipoteseDiagnostica.isNotEmpty)
                _campoResumo(context, 'Hipótese diagnóstica', avaliacao.hipoteseDiagnostica),
              if (avaliacao.objetivosTerapeuticos.isNotEmpty)
                _campoResumo(context, 'Objetivos terapêuticos', avaliacao.objetivosTerapeuticos),
            ],
          ],
        ),
      ),
    );
  }

  Widget _campoResumo(BuildContext context, String label, String valor) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.corPrimaria),
          ),
          const SizedBox(height: 3),
          Text(
            valor.length > 200 ? '${valor.substring(0, 200)}...' : valor,
            style: TextStyle(fontSize: 13, color: context.corTextoBody, height: 1.4),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormAnamnese(BuildContext context, WidgetRef ref, AvaliacaoInicial? existente) async {
    final queixaCtrl = TextEditingController(text: existente?.queixaPrincipal ?? '');
    final histCtrl = TextEditingController(text: existente?.historicoClinico ?? '');
    final medCtrl = TextEditingController(text: existente?.medicamentos ?? '');
    final diagCtrl = TextEditingController(text: existente?.hipoteseDiagnostica ?? '');
    final objCtrl = TextEditingController(text: existente?.objetivosTerapeuticos ?? '');
    final obsCtrl = TextEditingController(text: existente?.observacoes ?? '');

    final salvo = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Avaliação Inicial'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _campoTexto('Queixa principal', queixaCtrl, maxLines: 4),
                const SizedBox(height: 12),
                _campoTexto('Histórico clínico', histCtrl, maxLines: 4),
                const SizedBox(height: 12),
                _campoTexto('Medicamentos', medCtrl, maxLines: 2),
                const SizedBox(height: 12),
                _campoTexto('Hipótese diagnóstica', diagCtrl, maxLines: 3),
                const SizedBox(height: 12),
                _campoTexto('Objetivos terapêuticos', objCtrl, maxLines: 3),
                const SizedBox(height: 12),
                _campoTexto('Observações', obsCtrl, maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (salvo != true) return;

    final service = ref.read(avaliacaoInicialServiceProvider);
    final avaliacao = AvaliacaoInicial(
      id: existente?.id ?? '',
      pacienteId: pacienteId,
      queixaPrincipal: queixaCtrl.text.trim(),
      historicoClinico: histCtrl.text.trim(),
      medicamentos: medCtrl.text.trim(),
      hipoteseDiagnostica: diagCtrl.text.trim(),
      objetivosTerapeuticos: objCtrl.text.trim(),
      observacoes: obsCtrl.text.trim(),
      dataCriacao: existente?.dataCriacao ?? DateTime.now(),
    );

    await service.salvar(avaliacao);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avaliação inicial salva com sucesso.')),
      );
    }
  }

  Widget _campoTexto(String label, TextEditingController ctrl, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }
}
