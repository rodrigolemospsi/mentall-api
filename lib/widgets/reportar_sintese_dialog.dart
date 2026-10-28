import 'package:flutter/material.dart';

/// Motivos aceitos no reporte de saída de IA.
///
/// A lista é a mesma do backend (`backend/models/schemas.py`,
/// `MOTIVOS_REPORTE_IA`); o valor vai no corpo da requisição e o rótulo é o
/// texto exibido ao profissional.
const Map<String, String> motivosReporteSintese = {
  'conteudo_incorreto': 'Conteúdo incorreto ou inventado',
  'tom_inadequado': 'Tom ou linguagem inadequada',
  'dado_sensivel': 'Exposição de dado sensível',
  'conteudo_ofensivo': 'Conteúdo ofensivo ou discriminatório',
  'outro': 'Outro problema',
};

/// Resultado do diálogo de reporte de saída de IA.
class ReporteSintese {
  final String motivo;
  final String detalhe;

  const ReporteSintese({required this.motivo, this.detalhe = ''});
}

/// Abre o diálogo de reporte de saída de IA (requisito do Google Play, item 3.4).
///
/// Devolve `null` se o profissional cancelar. Nenhum conteúdo clínico entra no
/// reporte: só o motivo e uma observação opcional.
Future<ReporteSintese?> mostrarDialogoReportarSintese(BuildContext context) {
  return showDialog<ReporteSintese>(
    context: context,
    builder: (_) => const ReportarSinteseDialog(),
  );
}

/// Diálogo com os motivos e uma observação opcional.
class ReportarSinteseDialog extends StatefulWidget {
  const ReportarSinteseDialog({super.key});

  @override
  State<ReportarSinteseDialog> createState() => _ReportarSinteseDialogState();
}

class _ReportarSinteseDialogState extends State<ReportarSinteseDialog> {
  static const int _maxDetalhe = 500;

  final TextEditingController _detalheController = TextEditingController();
  String? _motivo;

  @override
  void dispose() {
    _detalheController.dispose();
    super.dispose();
  }

  void _enviar() {
    final motivo = _motivo;
    if (motivo == null) return;
    Navigator.pop(
      context,
      ReporteSintese(motivo: motivo, detalhe: _detalheController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar problema com o texto gerado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O relato e a síntese não são enviados no reporte — só o motivo e '
              'sua observação (se quiser).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _motivo,
              onChanged: (valor) => setState(() => _motivo = valor),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entrada in motivosReporteSintese.entries)
                    RadioListTile<String>(
                      value: entrada.key,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(entrada.value),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _detalheController,
              maxLength: _maxDetalhe,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _motivo == null ? null : _enviar,
          child: const Text('Enviar reporte'),
        ),
      ],
    );
  }
}
