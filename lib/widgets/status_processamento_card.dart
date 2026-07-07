import 'package:flutter/material.dart';

class StatusProcessamentoCard extends StatelessWidget {
  final String status;
  final Color cor;
  final IconData icone;
  final String origemRelato;
  final bool geradoComIa;
  final bool revisadoPeloProfissional;
  final String? dataProcessamentoIa;
  final bool possuiAudioRelato;
  final bool audioMantido;

  const StatusProcessamentoCard({
    super.key,
    required this.status,
    required this.cor,
    required this.icone,
    required this.origemRelato,
    required this.geradoComIa,
    required this.revisadoPeloProfissional,
    required this.dataProcessamentoIa,
    required this.possuiAudioRelato,
    required this.audioMantido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status,
                  style: TextStyle(
                    color: cor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Origem do relato: $origemRelato',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                Text(
                  geradoComIa
                      ? 'Conteúdo auxiliado por IA'
                      : 'Sem processamento por IA',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                Text(
                  revisadoPeloProfissional
                      ? 'Revisado pelo profissional'
                      : 'Ainda não marcado como revisado',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
                if (dataProcessamentoIa != null)
                  Text(
                    'Último processamento: $dataProcessamentoIa',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
                if (possuiAudioRelato)
                  Text(
                    audioMantido
                        ? 'Áudio original mantido'
                        : 'Áudio original poderá ser descartado',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
