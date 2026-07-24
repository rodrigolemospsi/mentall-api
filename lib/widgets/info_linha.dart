import 'package:flutter/material.dart';

import '../utils/mentall_colors.dart';

class InfoLinha extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String valor;
  final Color? corValor;

  const InfoLinha({
    super.key,
    required this.icone,
    required this.titulo,
    required this.valor,
    this.corValor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 20, color: context.corPrimaria),
        const SizedBox(width: 10),
        Text(
          '$titulo: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            valor,
            style: TextStyle(color: corValor ?? context.corTextoBody),
          ),
        ),
      ],
    );
  }
}
