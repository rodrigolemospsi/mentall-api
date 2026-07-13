import 'package:flutter/material.dart';

class AvisoPrivacidadeIaCard extends StatelessWidget {
  const AvisoPrivacidadeIaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEFF6FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDBEAFE)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_outlined,
                color: Color(0xFF64748B), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'A IA atua apenas como apoio documental. '
                'Todo conteudo gerado deve ser revisado e validado '
                'pelo profissional antes de integrar o prontuario.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF475569),
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
