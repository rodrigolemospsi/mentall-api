import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessao_form_providers.dart';
import '../providers/service_providers.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Card "Financeiro" da tela de sessão.
///
/// ConsumerWidget autocontido: lê/escreve os providers de estado financeiro
/// (valor, status, data e método de pagamento) e usa o `pacoteServiceProvider`
/// global. Recebe apenas o `pacienteId` (para consultar pacotes) e o
/// `valorController` (TextEditingController mantido pela página).
class SecaoFinanceiroWidget extends ConsumerWidget {
  final String pacienteId;
  final TextEditingController valorController;

  const SecaoFinanceiroWidget({
    super.key,
    required this.pacienteId,
    required this.valorController,
  });

  void _rebuild(WidgetRef ref) {
    ref.read(sessaoFormRebuildProvider.notifier).state++;
  }

  String _formatarData(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pacoteService = ref.read(pacoteServiceProvider);
    final sessoesRestantes = pacoteService.totalSessoesRestantes(pacienteId);
    final temPacoteAtivo = sessoesRestantes > 0;
    final statusPagamento = ref.watch(sessaoStatusPagamentoProvider);
    final ehPacote = statusPagamento == 'pacote';
    final metodoPagamento = ref.watch(sessaoMetodoPagamentoProvider);
    final dataPagamento = ref.watch(sessaoDataPagamentoProvider);

    return Card(
      margin: EdgeInsets.zero,
      color: context.corCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.payments_outlined,
                  color: context.corPrimaria,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Financeiro',
                  style: TextStyle(
                    fontSize: Tipografia.base,
                    fontWeight: FontWeight.w700,
                    color: context.corTextoHeading,
                  ),
                ),
              ],
            ),
            if (temPacoteAtivo) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.corPacote.withAlpha(20),
                  borderRadius: BorderRadius.circular(Raio.xs),
                  border: Border.all(color: context.corPacote.withAlpha(60)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: context.corPacote,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Pacote ativo: $sessoesRestantes ${sessoesRestantes == 1 ? 'sessão restante' : 'sessões restantes'}',
                      style: TextStyle(
                        fontSize: Tipografia.sm,
                        fontWeight: FontWeight.w600,
                        color: context.corPacote,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            IgnorePointer(
              ignoring: ehPacote,
              child: TextField(
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Valor da sessão (R\$)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                controller: valorController,
                onChanged: (v) {
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null) {
                    ref.read(sessaoValorSessaoProvider.notifier).state = parsed;
                  }
                },
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: statusPagamento,
              decoration: const InputDecoration(
                labelText: 'Status do pagamento',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'pendente',
                  child: Text('Pendente'),
                ),
                const DropdownMenuItem(value: 'pago', child: Text('Pago')),
                const DropdownMenuItem(
                  value: 'convenio',
                  child: Text('Convênio'),
                ),
                if (temPacoteAtivo || ehPacote)
                  const DropdownMenuItem(
                    value: 'pacote',
                    child: Text('Pacote'),
                  ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(sessaoStatusPagamentoProvider.notifier).state = v;
                  if (v == 'pago') {
                    ref.read(sessaoDataPagamentoProvider.notifier).state =
                        DateTime.now();
                  } else if (v == 'pacote') {
                    ref.read(sessaoDataPagamentoProvider.notifier).state = null;
                    ref.read(sessaoMetodoPagamentoProvider.notifier).state = '';
                    final valorPorSessao =
                        pacoteService.valorPorSessaoAtivo(pacienteId) ?? 0.0;
                    if (valorPorSessao > 0) {
                      ref.read(sessaoValorSessaoProvider.notifier).state =
                          valorPorSessao;
                    }
                  } else {
                    ref.read(sessaoDataPagamentoProvider.notifier).state = null;
                    ref.read(sessaoMetodoPagamentoProvider.notifier).state = '';
                  }
                  _rebuild(ref);
                }
              },
            ),
            if (statusPagamento == 'pago') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metodoPagamento.isEmpty ? null : metodoPagamento,
                decoration: const InputDecoration(
                  labelText: 'Método de pagamento',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'pix', child: Text('Pix')),
                  DropdownMenuItem(value: 'dinheiro', child: Text('Dinheiro')),
                  DropdownMenuItem(
                    value: 'cartao_credito',
                    child: Text('Cartão de crédito'),
                  ),
                  DropdownMenuItem(
                    value: 'cartao_debito',
                    child: Text('Cartão de débito'),
                  ),
                  DropdownMenuItem(
                    value: 'transferencia',
                    child: Text('Transferência'),
                  ),
                ],
                onChanged: (v) {
                  ref.read(sessaoMetodoPagamentoProvider.notifier).state =
                      v ?? '';
                  _rebuild(ref);
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: dataPagamento ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    cancelText: 'Cancelar',
                    confirmText: 'OK',
                  );
                  if (date != null) {
                    ref.read(sessaoDataPagamentoProvider.notifier).state = date;
                    _rebuild(ref);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Data do pagamento',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    dataPagamento == null
                        ? 'Selecionar data'
                        : _formatarData(dataPagamento),
                    style: TextStyle(
                      fontSize: Tipografia.base,
                      color: dataPagamento != null
                          ? context.corTextoBody
                          : context.corTextoMuted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
