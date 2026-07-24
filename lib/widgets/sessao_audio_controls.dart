import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/mentall_colors.dart';

final gravandoAudioProvider = StateProvider<bool>((ref) => false);
final audioPausadoProvider = StateProvider<bool>((ref) => false);
final reproduzindoAudioProvider = StateProvider<bool>((ref) => false);
final duracaoGravacaoProvider = StateProvider<Duration>((ref) => Duration.zero);
final audioRelatoPathProvider = StateProvider<String>((ref) => '');
final audioRelatoBase64Provider = StateProvider<String>((ref) => '');
final erroAudioProvider = StateProvider<String>((ref) => '');
final transcrevendoRelatoProvider = StateProvider<bool>((ref) => false);
final gerandoSinteseIaProvider = StateProvider<bool>((ref) => false);
final erroProcessamentoIaProvider = StateProvider<String>((ref) => '');
final artigosSugeridosProvider = StateProvider<String>((ref) => '');

String formatarDuracaoGravacao(Duration duracao) {
  final minutos = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');
  final segundos = duracao.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutos:$segundos';
}

class BotaoAudioCircular extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final Color cor;
  final VoidCallback? onPressed;
  final bool preenchido;
  final bool destaque;
  final double? tamanhoCustomizado;
  final Widget? iconeCustomizado;

  const BotaoAudioCircular({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.cor,
    this.onPressed,
    this.preenchido = false,
    this.destaque = false,
    this.tamanhoCustomizado,
    this.iconeCustomizado,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onPressed != null;
    final corEfetiva = habilitado ? cor : context.corTextoDisabled;
    final corFundo =
        preenchido && habilitado ? corEfetiva : context.corFundo;
    final corIcone = preenchido && habilitado ? context.corOnPrimaria : corEfetiva;
    final tamanho = tamanhoCustomizado ?? (destaque ? 60.0 : 48.0);

    return Tooltip(
      message: rotulo,
      child: Semantics(
        label: rotulo,
        button: true,
        enabled: habilitado,
        child: Material(
          color: corFundo,
          elevation: habilitado ? (preenchido ? 3 : 1) : 0,
          shadowColor: corEfetiva.withValues(alpha: 0.35),
          shape: CircleBorder(
            side: preenchido
                ? BorderSide.none
                : BorderSide(color: corEfetiva.withValues(alpha: 0.35)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: tamanho,
              height: tamanho,
              child: Center(
                child: iconeCustomizado ??
                    Icon(icone, color: corIcone, size: destaque ? 28 : 22),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TimerGravacaoWidget extends ConsumerWidget {
  const TimerGravacaoWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gravando = ref.watch(gravandoAudioProvider);
    final pausado = ref.watch(audioPausadoProvider);
    final duracao = ref.watch(duracaoGravacaoProvider);

    if (!gravando && duracao <= Duration.zero) {
      return const SizedBox.shrink();
    }

    return Column(children: [
      const SizedBox(height: 12),
      Semantics(
        label: pausado
            ? 'Gravação pausada, $duracao'
            : 'Tempo de gravação, $duracao',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.corWarning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.corWarning.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Icon(
                pausado
                    ? Icons.pause_circle_outline
                    : Icons.fiber_manual_record,
                color: context.corWarning,
              ),
              const SizedBox(width: 10),
              Text(
                pausado ? 'Pausado' : 'Tempo de gravação',
                style: TextStyle(
                  color: context.corTextoSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                formatarDuracaoGravacao(duracao),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.corWarning,
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class ProcessamentoIaWidget extends ConsumerWidget {
  const ProcessamentoIaWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transcrevendo = ref.watch(transcrevendoRelatoProvider);
    final gerandoSintese = ref.watch(gerandoSinteseIaProvider);

    if (!transcrevendo && !gerandoSintese) {
      return const SizedBox.shrink();
    }

    return Column(children: [
      const SizedBox(height: 12),
      Semantics(
        label: gerandoSintese
            ? 'Gerando síntese clínica'
            : 'Transcrevendo relato',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.corPrimaria.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.corPrimaria.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.corPrimaria,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  gerandoSintese
                      ? 'Gerando síntese clínica a partir da transcrição. Aguarde...'
                      : 'Transcrevendo o relato. Aguarde...',
                  style: TextStyle(
                    color: context.corTextoSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class ErroProcessamentoIaWidget extends ConsumerWidget {
  final VoidCallback onLimparErro;

  const ErroProcessamentoIaWidget({
    super.key,
    required this.onLimparErro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final erro = ref.watch(erroProcessamentoIaProvider);

    if (erro.trim().isEmpty) return const SizedBox.shrink();

    return Column(children: [
      const SizedBox(height: 12),
      Semantics(
        label: 'Erro de processamento: $erro',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.corError.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.corError.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: context.corError),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  erro,
                  style: TextStyle(
                    color: context.corError,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: onLimparErro,
                icon: const Icon(Icons.close),
                color: context.corError,
                tooltip: 'Limpar erro',
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class ErroAudioWidget extends ConsumerWidget {
  final VoidCallback onLimparErro;

  const ErroAudioWidget({
    super.key,
    required this.onLimparErro,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final erro = ref.watch(erroAudioProvider);

    if (erro.trim().isEmpty) return const SizedBox.shrink();

    return Column(children: [
      const SizedBox(height: 12),
      Semantics(
        label: 'Erro de áudio: $erro',
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.corWarning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.corWarning.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.volume_off_outlined, color: context.corWarning),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  erro,
                  style: TextStyle(
                    color: context.corWarning,
                    height: 1.4,
                  ),
                ),
              ),
              IconButton(
                onPressed: onLimparErro,
                icon: const Icon(Icons.close),
                color: context.corWarning,
                tooltip: 'Limpar erro de áudio',
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class BotoesAudioWidget extends ConsumerWidget {
  final bool existeAcaoEmAndamento;
  final VoidCallback? onGravar;
  final VoidCallback? onPausar;
  final VoidCallback? onRetomar;
  final VoidCallback? onFinalizar;
  final VoidCallback? onCancelar;
  final VoidCallback? onOuvirParar;
  final VoidCallback? onRemover;

  const BotoesAudioWidget({
    super.key,
    required this.existeAcaoEmAndamento,
    this.onGravar,
    this.onPausar,
    this.onRetomar,
    this.onFinalizar,
    this.onCancelar,
    this.onOuvirParar,
    this.onRemover,
  });

  bool _checkPossuiAudio(WidgetRef ref) {
    return ref.read(audioRelatoPathProvider).trim().isNotEmpty ||
        ref.read(audioRelatoBase64Provider).trim().isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gravando = ref.watch(gravandoAudioProvider);
    final pausado = ref.watch(audioPausadoProvider);
    final reproduzindo = ref.watch(reproduzindoAudioProvider);
    final possuiAudio = _checkPossuiAudio(ref);
    ref.watch(audioRelatoPathProvider);
    ref.watch(audioRelatoBase64Provider);

    return Semantics(
      label: 'Controles de áudio',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.corSuperficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.corDivider),
        ),
        child: Wrap(
          spacing: 14,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (!gravando)
              BotaoAudioCircular(
                icone: Icons.mic_rounded,
                rotulo: possuiAudio ? 'Regravar áudio' : 'Gravar áudio',
                cor: context.corPrimaria,
                preenchido: true,
                destaque: true,
                tamanhoCustomizado: 90,
                onPressed: existeAcaoEmAndamento ? null : onGravar,
              ),
            if (gravando && !pausado)
              BotaoAudioCircular(
                icone: Icons.pause_rounded,
                rotulo: 'Pausar gravação',
                cor: context.corWarning,
                onPressed: onPausar,
              ),
            if (gravando && pausado)
              BotaoAudioCircular(
                icone: Icons.play_arrow_rounded,
                rotulo: 'Retomar gravação',
                cor: context.corPrimaria,
                onPressed: onRetomar,
              ),
            if (gravando)
              BotaoAudioCircular(
                icone: Icons.stop_rounded,
                rotulo: 'Finalizar gravação',
                cor: context.corError,
                preenchido: true,
                destaque: true,
                onPressed: onFinalizar,
              ),
            if (gravando)
              BotaoAudioCircular(
                icone: Icons.close_rounded,
                rotulo: 'Cancelar gravação',
                cor: context.corTextoMuted,
                onPressed: onCancelar,
              ),
            if (possuiAudio && !gravando)
              BotaoAudioCircular(
                icone: reproduzindo
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                rotulo: reproduzindo ? 'Parar áudio' : 'Ouvir áudio',
                cor: reproduzindo ? context.corError : context.corPrimaria,
                onPressed: existeAcaoEmAndamento ? null : onOuvirParar,
              ),
            if (possuiAudio && !gravando)
              BotaoAudioCircular(
                icone: Icons.delete_outline_rounded,
                rotulo: 'Remover áudio',
                cor: context.corError,
                onPressed: existeAcaoEmAndamento ? null : onRemover,
              ),
          ],
        ),
      ),
    );
  }
}
