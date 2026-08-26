import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

/// Card "Buscando artigos científicos..." exibido durante a busca em background.
/// Puramente visual — não depende de estado da página de sessão.
class CardBuscandoArtigos extends StatelessWidget {
  const CardBuscandoArtigos({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.corContainerPrimario,
        borderRadius: BorderRadius.circular(Raio.md),
        border: Border.all(color: context.cs.primaryContainer, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.corPrimaria,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Buscando artigos científicos...',
              style: TextStyle(
                fontSize: Tipografia.sm,
                height: 1.5,
                color: context.corTextoSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Switch "Manter áudio salvo".
class AudioMantidoSwitch extends StatelessWidget {
  final bool valor;
  final bool desabilitado;
  final ValueChanged<bool> onChanged;

  const AudioMantidoSwitch({
    super.key,
    required this.valor,
    required this.desabilitado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(
        'Manter áudio salvo',
        style: TextStyle(color: context.corTextoSecondary, fontSize: Tipografia.smMd),
      ),
      value: valor,
      activeTrackColor: context.corPrimaria.withValues(alpha: 0.4),
      activeThumbColor: context.corPrimaria,
      contentPadding: EdgeInsets.zero,
      dense: true,
      onChanged: desabilitado ? null : onChanged,
    );
  }
}

/// Botão "Salvar sessão" (com loading).
class BotaoSalvarSessao extends ConsumerWidget {
  final bool salvando;
  final VoidCallback onPressed;

  const BotaoSalvarSessao({
    super.key,
    required this.salvando,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: 'Salvar sessão',
      child: FilledButton.icon(
        onPressed: salvando ? null : onPressed,
        icon: salvando
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.corOnPrimaria,
                ),
              )
            : const Icon(Icons.save_outlined),
        label: Text(salvando ? 'Salvando...' : 'Salvar sessão'),
        style: FilledButton.styleFrom(
          backgroundColor: context.corPrimaria,
          foregroundColor: context.corOnPrimaria,
          disabledBackgroundColor: context.corPrimaria.withValues(alpha: 0.6),
          disabledForegroundColor: context.corOnPrimaria,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
