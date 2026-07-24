import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/contrato_terapeutico.dart';
import '../models/paciente.dart';
import '../utils/mentall_colors.dart';
import 'info_linha.dart';
import 'status_paciente_chip.dart';

class PacienteResumoCard extends StatelessWidget {
  final Paciente paciente;
  final String termoSingular;
  final bool usaPessoaAtendida;
  final int quantidadeSessoes;
  final int quantidadeSessoesArquivadas;
  final ContratoTerapeutico? contrato;

  const PacienteResumoCard({
    super.key,
    required this.paciente,
    required this.termoSingular,
    required this.usaPessoaAtendida,
    required this.quantidadeSessoes,
    required this.quantidadeSessoesArquivadas,
    this.contrato,
  });

  String get _nomeExibicao {
    final nomeLimpo = paciente.nome.trim();
    if (nomeLimpo.isEmpty) {
      return 'Sem nome';
    }
    return nomeLimpo;
  }

  String get _contatoExibicao {
    final contatoLimpo = paciente.contato.trim();
    if (contatoLimpo.isEmpty) {
      return 'Não informado';
    }
    return contatoLimpo;
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

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: context.corPrimaria.withValues(alpha: 0.12),
                  backgroundImage: paciente.possuiFoto
                      ? MemoryImage(base64Decode(paciente.fotoBase64))
                      : null,
                  child: paciente.possuiFoto
                      ? null
                      : Text(
                          paciente.inicial,
                          style: TextStyle(
                            color: context.corPrimaria,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _nomeExibicao,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tipoAtendimentoExibicao,
                        style: TextStyle(color: context.corTextoSecondary),
                      ),
                    ],
                  ),
                ),
                StatusPacienteChip(
                  ativo: paciente.ativo,
                  usaPessoaAtendida: usaPessoaAtendida,
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),
            InfoLinha(
              icone: Icons.phone_outlined,
              titulo: 'Contato',
              valor: _contatoExibicao,
            ),
            if (paciente.modoAtendimento.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              InfoLinha(
                icone: Icons.location_on_outlined,
                titulo: 'Modalidade',
                valor: paciente.modoAtendimento.trim(),
              ),
            ],
            if (paciente.possuiEmail) ...[
              const SizedBox(height: 10),
              InfoLinha(
                icone: Icons.email_outlined,
                titulo: 'E-mail',
                valor: paciente.email.trim(),
              ),
            ],
            if (contrato != null) ...[
              const SizedBox(height: 10),
              InfoLinha(
                icone: contrato!.isAceito
                    ? Icons.check_circle_outline
                    : contrato!.isEnviado
                        ? Icons.hourglass_empty
                        : Icons.description_outlined,
                titulo: 'Contrato',
                valor: contrato!.isAceito
                    ? 'Aceito em ${contrato!.dataAceiteFormatada}'
                    : contrato!.isEnviado
                        ? 'Aguardando aceite'
                        : 'Pendente',
                corValor: contrato!.isAceito
                    ? const Color(0xFF2E7D32)
                    : contrato!.isEnviado
                        ? const Color(0xFFE65100)
                        : null,
              ),
            ],
            const SizedBox(height: 10),
            InfoLinha(
              icone: Icons.event_note_outlined,
              titulo: 'Sessões ativas',
              valor: quantidadeSessoes.toString(),
            ),
            if (quantidadeSessoesArquivadas > 0) ...[
              const SizedBox(height: 10),
              InfoLinha(
                icone: Icons.archive_outlined,
                titulo: 'Sessões arquivadas',
                valor: quantidadeSessoesArquivadas.toString(),
              ),
            ],
            if (paciente.observacoes.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Observações',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                paciente.observacoes.trim(),
                style: TextStyle(
                  color: context.corTextoBody,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
