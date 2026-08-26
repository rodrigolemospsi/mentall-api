import 'package:flutter/material.dart';

import '../utils/mentall_colors.dart';
import '../utils/tipografia.dart';

class SemSessoesCard extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final IconData icone;

  const SemSessoesCard({
    super.key,
    required this.titulo,
    required this.mensagem,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 64, color: context.corPrimaria.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              titulo,
              style: TextStyle(
                fontSize: Tipografia.lg,
                fontWeight: FontWeight.w600,
                color: context.corTextoHeading,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.corTextoMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
