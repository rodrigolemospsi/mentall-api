import 'package:flutter/material.dart';

class StatusPacienteChip extends StatelessWidget {
  final bool ativo;
  final bool usaPessoaAtendida;

  const StatusPacienteChip({
    super.key,
    required this.ativo,
    required this.usaPessoaAtendida,
  });

  @override
  Widget build(BuildContext context) {
    final Color cor = ativo ? const Color(0xFF2E7D32) : Colors.grey;

    final textoAtivo = usaPessoaAtendida ? 'Ativa' : 'Ativo';
    final textoInativo = usaPessoaAtendida ? 'Inativa' : 'Inativo';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? textoAtivo : textoInativo,
        style: TextStyle(
          color: cor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
