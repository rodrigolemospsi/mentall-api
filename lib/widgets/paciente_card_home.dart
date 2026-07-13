import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/paciente.dart';

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
    if (nomeLimpo.isEmpty) {
      return 'Sem nome';
    }
    return nomeLimpo;
  }

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF2563EB);

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
                radius: 24,
                backgroundColor: listaArquivada
                    ? Colors.grey.withValues(alpha: 0.14)
                    : corPrincipal.withValues(alpha: 0.12),
                backgroundImage: paciente.possuiFoto
                    ? MemoryImage(base64Decode(paciente.fotoBase64))
                    : null,
                child: paciente.possuiFoto
                    ? null
                    : Text(
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
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _StatusPacienteChip(
                            ativo: paciente.ativo,
                          ),
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
              if (paciente.possuiContato)
                _WhatsAppLogoButton(contato: paciente.contato.trim()),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Opções $termoSingular',
                icon: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF64748B),
                  size: 20,
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
                color: Color(0xFFCBD5E1),
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

class _PendenciasBadge extends StatelessWidget {
  final int pendentes;

  const _PendenciasBadge({required this.pendentes});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withValues(alpha: 0.12),
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
        width: 48,
        height: 48,
        child: Center(
          child: Image(
            image: AssetImage('assets/images/logo_whats.png'),
            width: 28,
            height: 28,
          ),
        ),
      ),
    );
  }
}
