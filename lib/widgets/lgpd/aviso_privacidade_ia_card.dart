import 'package:flutter/material.dart';
import '../../utils/mentall_colors.dart';

class AvisoPrivacidadeIaCard extends StatelessWidget {
  const AvisoPrivacidadeIaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.corContainerPrimario,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.corPrimaria.withValues(alpha: 0.15)),
      ),
      child: Semantics(
        label: 'Aviso de privacidade: A IA atua apenas como apoio documental',
        child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined,
                color: context.corTextoMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'A IA atua apenas como apoio documental. '
                'Todo conteúdo gerado deve ser revisado e validado '
                'pelo profissional antes de integrar o prontuário.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.corTextoSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
