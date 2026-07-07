import 'package:flutter/material.dart';

class InfoLinha extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;

  const InfoLinha({
    super.key,
    required this.icone,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    const Color corPrincipal = Color(0xFF1F6F78);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: corPrincipal),
        const SizedBox(width: 10),
        Text(
          '$titulo: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(color: Colors.black87),
          ),
        ),
      ],
    );
  }
}
