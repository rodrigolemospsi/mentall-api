import 'package:flutter/material.dart';

import '../models/paciente.dart';

class PacienteCardHome extends StatelessWidget {
  final Paciente paciente;
  final String termoSingular;
  final bool listaArquivada;
  final VoidCallback onTap;
  final VoidCallback onArquivar;
  final VoidCallback onRestaurar;

  const PacienteCardHome({
    super.key,
    required this.paciente,
    required this.termoSingular,
    required this.listaArquivada,
    required this.onTap,
    required this.onArquivar,
    required this.onRestaurar,
  });

  String get _nomeExibicao {
    final nomeLimpo = paciente.nome.trim();
    if (nomeLimpo.isEmpty) {
      return 'Sem nome';
    }
    return nomeLimpo;
  }

  String get _tipoAtendimentoExibicao {
    final tipoLimpo = paciente.tipoAtendimento.trim();
    if (tipoLimpo.isEmpty) {
      return 'Particular';
    }
    return tipoLimpo;
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: listaArquivada
                    ? Colors.grey.withValues(alpha: 0.14)
                    : corPrincipal.withValues(alpha: 0.12),
                child: Text(
                  paciente.inicial,
                  style: TextStyle(
                    color: listaArquivada
                        ? Colors.grey.shade700
                        : corPrincipal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: listaArquivada ? 0.75 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomeExibicao,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tipoAtendimentoExibicao,
                        style: const TextStyle(
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _StatusPacienteChip(
                        ativo: paciente.ativo,
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções $termoSingular',
                icon: const Icon(
                  Icons.more_vert,
                  color: Colors.black45,
                ),
                onSelected: (value) {
                  if (value == 'arquivar') {
                    onArquivar();
                  }
                  if (value == 'restaurar') {
                    onRestaurar();
                  }
                },
                itemBuilder: (context) {
                  if (listaArquivada) {
                    return const [
                      PopupMenuItem(
                        value: 'restaurar',
                        child: Row(
                          children: [
                            Icon(Icons.restore_outlined),
                            SizedBox(width: 8),
                            Text('Restaurar cadastro'),
                          ],
                        ),
                      ),
                    ];
                  }
                  return const [
                    PopupMenuItem(
                      value: 'arquivar',
                      child: Row(
                        children: [
                          Icon(Icons.archive_outlined),
                          SizedBox(width: 8),
                          Text('Arquivar cadastro'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPacienteChip extends StatelessWidget {
  final bool ativo;

  const _StatusPacienteChip({
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) {
    final Color cor = ativo ? const Color(0xFF2E7D32) : Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Arquivado',
        style: TextStyle(
          color: cor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
