import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/paciente.dart';
import '../utils/mentall_colors.dart';

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
    return nomeLimpo;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: listaArquivada
                    ? context.corSuperficie
                    : cs.primaryContainer,
                backgroundImage: paciente.possuiFoto
                    ? MemoryImage(base64Decode(paciente.fotoBase64))
                    : null,
                child: paciente.possuiFoto
                    ? null
                    : Text(
                        paciente.inicial,
                        style: TextStyle(
                          color: listaArquivada ? context.corTextoMuted : cs.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
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
                      Text(
                        _nomeExibicao,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: context.corTextoHeading,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _StatusPacienteChip(ativo: paciente.ativo),
                          if (sessoesPendentes > 0) ...[
                            const SizedBox(width: 8),
                            _PendenciasBadge(pendentes: sessoesPendentes),
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

class _StatusPacienteChip extends StatelessWidget {
  final bool ativo;

  const _StatusPacienteChip({required this.ativo});

  @override
  Widget build(BuildContext context) {
    final Color cor = ativo ? const Color(0xFF2E7D32) : context.corTextoMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Arquivado',
        style: TextStyle(
          color: cor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PendenciasBadge extends StatelessWidget {
  final int pendentes;

  const _PendenciasBadge({required this.pendentes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.rate_review_outlined,
              size: 11, color: Color(0xFFE65100)),
          const SizedBox(width: 3),
          Text(
            '$pendentes',
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

  Future<void> _abrirWhatsApp() async {
    final numero = _numeroLimpo;
    if (numero.isEmpty) return;

    final uri = Uri.parse('https://wa.me/$numero');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _abrirWhatsApp,
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
