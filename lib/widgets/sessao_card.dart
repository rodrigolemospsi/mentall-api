import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../models/sessao.dart';
import '../screens/sessao_form_page.dart';
import '../utils/mentall_colors.dart';
import 'sessao_info_chip.dart';

class SessaoCard extends StatelessWidget {
  final Sessao sessao;
  final Paciente paciente;
  final bool arquivada;
  final VoidCallback? onArquivar;
  final VoidCallback? onRestaurar;

  const SessaoCard({
    super.key,
    required this.sessao,
    required this.paciente,
    required this.arquivada,
    this.onArquivar,
    this.onRestaurar,
  });

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final ano = data.year.toString();
    return '$dia/$mes/$ano';
  }

  String _formatarHorario(DateTime data) {
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$hora:$minuto';
  }

  IconData _iconeStatus(String codigo) {
    switch (codigo) {
      case 'vazia':
        return Icons.radio_button_unchecked_outlined;
      case 'relato_disponivel':
        return Icons.mic_none_outlined;
      case 'transcricao_pendente':
        return Icons.pending_actions_outlined;
      case 'ia_pendente':
        return Icons.auto_awesome_outlined;
      case 'revisao_pendente':
        return Icons.rate_review_outlined;
      case 'concluida':
        return Icons.check_circle_outline;
      case 'erro':
        return Icons.error_outline;
      default:
        return Icons.flag_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {

    final dataFormatada = _formatarData(sessao.data);
    final horarioFormatado = _formatarHorario(sessao.data);
    final statusInfo = sessao.statusClinicoInfo;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: arquivada
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SessaoFormPage(
                      paciente: paciente,
                      sessaoExistente: sessao,
                    ),
                  ),
                );
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: arquivada
                    ? context.corSuperficie
                    : context.corPrimaria.withValues(alpha: 0.12),
                child: Text(
                  sessao.numeroSessao.toString(),
                  style: TextStyle(
                    color: arquivada
                        ? context.corTextoSecondary
                        : context.corPrimaria,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Opacity(
                  opacity: arquivada ? 0.75 : 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sessão ${sessao.numeroSessao} - $dataFormatada',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.corTextoHeading,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$horarioFormatado',
                        style: TextStyle(color: context.corTextoSecondary),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SessaoInfoChip(
                            texto: statusInfo.titulo,
                            codigo: statusInfo.codigo,
                            icone: _iconeStatus(statusInfo.codigo),
                          ),
                          if (statusInfo.exigeAcaoProfissional)
                            const SessaoInfoChip(
                              texto: 'Ação necessária',
                              codigo: 'acao_necessaria',
                              icone: Icons.priority_high_outlined,
                            ),
                          if (arquivada)
                            const SessaoInfoChip(
                              texto: 'Arquivada',
                              codigo: 'arquivada',
                              icone: Icons.archive_outlined,
                              discreto: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opções da sessão',
                icon: Icon(Icons.more_vert, color: context.corTextoMuted),
                onSelected: (value) {
                  if (value == 'arquivar' && onArquivar != null) {
                    onArquivar!();
                  }
                  if (value == 'restaurar' && onRestaurar != null) {
                    onRestaurar!();
                  }
                },
                itemBuilder: (context) {
                  if (arquivada) {
                    return const [
                      PopupMenuItem(
                        value: 'restaurar',
                        child: Row(
                          children: [
                            Icon(Icons.restore_outlined),
                            SizedBox(width: 8),
                            Text('Restaurar sessão'),
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
                          Text('Arquivar sessão'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
