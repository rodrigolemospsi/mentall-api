import 'package:flutter/material.dart';

import '../utils/mentall_colors.dart';

class SessaoInfoChip extends StatelessWidget {
  final String texto;
  final String codigo;
  final IconData icone;
  final bool discreto;

  const SessaoInfoChip({
    super.key,
    required this.texto,
    required this.codigo,
    required this.icone,
    this.discreto = false,
  });

  Color _obterCor(BuildContext context) {
    if (discreto) {
      return context.corCancelled;
    }

    switch (codigo) {
      case 'vazia':
        return context.corCancelled;
      case 'relato_disponivel':
        return context.corScheduled;
      case 'transcricao_pendente':
        return context.corPrimaria;
      case 'ia_pendente':
        return context.corWarning;
      case 'revisao_pendente':
        return context.corWarning;
      case 'concluida':
        return context.corSuccess;
      case 'erro':
        return context.corError;
      case 'acao_necessaria':
        return context.corDanger;
      default:
        return context.corPrimaria;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color cor = _obterCor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: cor),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
