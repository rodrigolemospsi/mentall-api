import 'package:flutter/material.dart';

class SecaoFormulario extends StatelessWidget {
  final String? titulo;
  final String? subtitulo;
  final List<Widget> children;

  const SecaoFormulario({
    super.key,
    this.titulo,
    required this.children,
    this.subtitulo,
  });

  @override
  Widget build(BuildContext context) {
    final temTitulo = titulo != null && titulo!.trim().isNotEmpty;
    final temSubtitulo = subtitulo != null && subtitulo!.trim().isNotEmpty;

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
            if (temTitulo)
              Text(
                titulo!,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (temSubtitulo) ...[
              const SizedBox(height: 6),
              Text(
                subtitulo!,
                style: const TextStyle(
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ],
            if (temTitulo || temSubtitulo) const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
