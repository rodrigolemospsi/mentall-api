
import 'package:flutter/material.dart';

import '../models/paciente.dart';
import '../services/whatsapp_service.dart';
import '../utils/imagem_cache.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import 'demo_badge.dart';
import 'status_chip.dart';
import '../utils/tipografia.dart';

class PacienteCardHome extends StatelessWidget {
  final Paciente paciente;
  final String termoSingular;
  final bool listaArquivada;
  final int sessoesPendentes;
  final VoidCallback onTap;
  final VoidCallback onArquivar;
  final VoidCallback onRestaurar;

  const PacienteCardHome({
    super.key,
    required this.paciente,
    required this.termoSingular,
    required this.listaArquivada,
    this.sessoesPendentes = 0,
    required this.onTap,
    required this.onArquivar,
    required this.onRestaurar,
  });

  String get _nomeExibicao {
    final nomeLimpo = paciente.nome.trim();
    if (nomeLimpo.isEmpty) return 'Sem nome';
    final primeiroNome = nomeLimpo.split(' ').first;
    return primeiroNome;
  }

  String get _modalidadeExibicao => paciente.modoAtendimento.trim();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Raio.lg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.corCard,
            borderRadius: BorderRadius.circular(Raio.lg),
            boxShadow: context.corCardSombra,
            border: context.corCardBorda,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: listaArquivada
                    ? context.corSuperficie
                    : context.corContainerPrimario,
                backgroundImage: paciente.possuiFoto
                    ? fotoMemoria(paciente.fotoBase64)
                    : null,
                child: paciente.possuiFoto
                    ? null
                    : Text(
                        paciente.inicial,
                        style: TextStyle(
                          color: listaArquivada ? context.corTextoMuted : context.corPrimaria,
                          fontWeight: FontWeight.w600,
                          fontSize: Tipografia.md,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: listaArquivada ? 0.6 : 1,
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: _nomeExibicao,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: Tipografia.baseMd,
                                color: context.corTextoHeading,
                              ),
                            ),
                            if (_modalidadeExibicao.isNotEmpty)
                              TextSpan(
                                text: ' - $_modalidadeExibicao',
                                style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontSize: Tipografia.smMd,
                                  color: context.corTextoMuted,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          StatusChip(
                            label: paciente.ativo ? 'Ativo' : 'Arquivado',
                            cor: paciente.ativo
                                ? context.corSuccess
                                : context.corTextoMuted,
                          ),
                          if (paciente.ehDemo) ...[
                            const SizedBox(width: 8),
                            const DemoBadge(),
                          ],
                          if (sessoesPendentes > 0) ...[
                            const SizedBox(width: 8),
                            StatusChip(
                              label: '$sessoesPendentes',
                              cor: context.corWarning,
                              icone: Icons.rate_review_outlined,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (paciente.possuiContato && !listaArquivada)
                _WhatsAppLogoButton(contato: paciente.contato.trim()),
              PopupMenuButton<String>(
                tooltip: 'Opções $termoSingular',
                icon: Icon(Icons.more_vert, color: context.corTextoMuted, size: 20),
                onSelected: (value) {
                  if (value == 'arquivar') onArquivar();
                  if (value == 'restaurar') onRestaurar();
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
              Icon(Icons.chevron_right, color: context.corTextoDisabled, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _WhatsAppLogoButton extends StatelessWidget {
  final String contato;

  const _WhatsAppLogoButton({required this.contato});

  String get _numeroLimpo {
    return contato.replaceAll(RegExp(r'[^\d]'), '');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final numero = _numeroLimpo;
        if (numero.isEmpty) return;
        WhatsAppService.escolher(context: context, numero: numero);
      },
      child: const SizedBox(
        width: 52,
        height: 52,
        child: Center(
          child: Image(
            image: AssetImage('assets/images/logo_whats.png'),
            width: 44,
            height: 44,
          ),
        ),
      ),
    );
  }
}
