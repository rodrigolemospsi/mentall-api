import 'package:flutter/material.dart';

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

  Color _obterCor() {
    if (discreto) {
      return Colors.grey;
    }

    switch (codigo) {
      case 'vazia':
        return Colors.grey;
      case 'relato_disponivel':
        return Colors.blue;
      case 'transcricao_pendente':
        return Colors.deepPurple;
      case 'ia_pendente':
        return Colors.orange;
      case 'revisao_pendente':
        return Colors.amber.shade800;
      case 'concluida':
        return Colors.green;
      case 'erro':
        return Colors.red;
      case 'acao_necessaria':
        return Colors.deepOrange;
      default:
        return const Color(0xFF1F6F78);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color cor = _obterCor();

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
