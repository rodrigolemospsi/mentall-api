import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sessao_form_providers.dart';
import '../utils/mentall_colors.dart';
import 'campo_texto_widget.dart';
import 'secao_formulario.dart';
import 'sessao_audio_controls.dart';
import 'sessao_form_widgets.dart';

/// Callbacks das ações da seção "Relato + IA" da tela de sessão.
///
/// Agrupados num objeto para evitar passar 15+ parâmetros soltos ao
/// [SecaoRelatoIaWidget] (padrão do plano de refatoração).
class SessaoFormActions {
  final VoidCallback onLimparErroProcessamento;
  final VoidCallback onLimparErroAudio;
  final VoidCallback onGravar;
  final VoidCallback onPausar;
  final VoidCallback onRetomar;
  final VoidCallback onFinalizar;
  final VoidCallback onCancelar;
  final VoidCallback onOuvirParar;
  final VoidCallback onRemover;
  final VoidCallback onTranscrever;
  final VoidCallback onGerarSintese;
  final VoidCallback onMarcarRevisado;
  final ValueChanged<bool> onAudioMantidoChanged;

  const SessaoFormActions({
    required this.onLimparErroProcessamento,
    required this.onLimparErroAudio,
    required this.onGravar,
    required this.onPausar,
    required this.onRetomar,
    required this.onFinalizar,
    required this.onCancelar,
    required this.onOuvirParar,
    required this.onRemover,
    required this.onTranscrever,
    required this.onGerarSintese,
    required this.onMarcarRevisado,
    required this.onAudioMantidoChanged,
  });
}

/// Seção "Relato + IA" da tela de sessão (áudio, transcrição e síntese).
///
/// ConsumerWidget: lê os providers globais de áudio/IA (de
/// `sessao_audio_controls.dart`) e os de estado do form
/// (`sessao_form_providers.dart`). Recebe os controllers de texto e as ações
/// via [SessaoFormActions] — não depende do `_SessaoFormPageState`.
class SecaoRelatoIaWidget extends ConsumerWidget {
  final TextEditingController transcricaoController;
  final TextEditingController relatoPosSessaoController;
  final SessaoFormActions acoes;

  const SecaoRelatoIaWidget({
    super.key,
    required this.transcricaoController,
    required this.relatoPosSessaoController,
    required this.acoes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final possuiAudio =
        ref.watch(audioRelatoPathProvider).trim().isNotEmpty ||
        ref.watch(audioRelatoBase64Provider).trim().isNotEmpty;
    final transcrevendo = ref.watch(transcrevendoRelatoProvider);
    final gerandoSintese = ref.watch(gerandoSinteseIaProvider);
    final geradoComIa = ref.watch(sessaoGeradoComIaProvider);
    final revisado = ref.watch(sessaoRevisadoProvider);
    final audioMantido = ref.watch(sessaoAudioMantidoProvider);
    final possuiTranscricao = transcricaoController.text.trim().isNotEmpty;
    final acaoEmAndamento =
        ref.watch(gravandoAudioProvider) ||
        ref.watch(transcrevendoRelatoProvider) ||
        ref.watch(gerandoSinteseIaProvider) ||
        ref.watch(preparandoAudioProvider);

    return SecaoFormulario(
      children: [
        const TimerGravacaoWidget(),
        const ProcessamentoIaWidget(),
        ErroProcessamentoIaWidget(
          onLimparErro: acoes.onLimparErroProcessamento,
        ),
        ErroAudioWidget(onLimparErro: acoes.onLimparErroAudio),
        BotoesAudioWidget(
          existeAcaoEmAndamento: acaoEmAndamento,
          onGravar: acoes.onGravar,
          onPausar: acoes.onPausar,
          onRetomar: acoes.onRetomar,
          onFinalizar: acoes.onFinalizar,
          onCancelar: acoes.onCancelar,
          onOuvirParar: acoes.onOuvirParar,
          onRemover: acoes.onRemover,
        ),
        if (possuiAudio) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: AudioMantidoSwitch(
              valor: audioMantido,
              desabilitado: acaoEmAndamento,
              onChanged: acoes.onAudioMantidoChanged,
            ),
          ),
        ],
        if (possuiAudio && !transcrevendo) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'Transcrever áudio',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: acaoEmAndamento ? null : acoes.onTranscrever,
                icon: const Icon(Icons.subtitles_rounded),
                label: const Text('Transcrever com IA'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        CampoTextoWidget(
          controller: transcricaoController,
          label: 'Transcrição',
        ),
        if (possuiTranscricao) ...[
          const SizedBox(height: 12),
          Semantics(
            label: 'Gerar síntese',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: acaoEmAndamento ? null : acoes.onGerarSintese,
                icon: gerandoSintese
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.corOnPrimaria,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(gerandoSintese ? 'Gerando...' : 'Gerar síntese'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
        if (geradoComIa) ...[
          const SizedBox(height: 12),
          CampoTextoWidget(
            controller: relatoPosSessaoController,
            label: 'Relato clínico organizado',
          ),
        ],
        if (!revisado && geradoComIa) ...[
          const SizedBox(height: 4),
          Semantics(
            label: 'Marcar como revisado',
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: acaoEmAndamento ? null : acoes.onMarcarRevisado,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Marcar como revisado'),
                style: FilledButton.styleFrom(
                  backgroundColor: context.corPrimaria,
                  foregroundColor: context.corOnPrimaria,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
