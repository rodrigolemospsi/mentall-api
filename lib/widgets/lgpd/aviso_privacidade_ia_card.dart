import 'package:flutter/material.dart';

class AvisoPrivacidadeIaCard extends StatelessWidget {
  const AvisoPrivacidadeIaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blueGrey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined,
                color: Colors.blueGrey.shade600, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'A IA atua apenas como apoio documental. '
                'Todo conteudo gerado deve ser revisado e validado '
                'pelo profissional antes de integrar o prontuario.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blueGrey.shade700,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
