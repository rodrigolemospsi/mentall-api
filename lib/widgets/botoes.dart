import 'package:flutter/material.dart';

import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

Widget botaoPrimario({
  required BuildContext context,
  required String label,
  required VoidCallback onPressed,
  IconData? icone,
  bool carregando = false,
}) {
  return FilledButton.icon(
    onPressed: carregando ? null : onPressed,
    icon: carregando
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.corOnPrimaria,
            ),
          )
        : Icon(icone, size: 20),
    label: Text(label),
    style: FilledButton.styleFrom(
      backgroundColor: context.corPrimaria,
      foregroundColor: context.corOnPrimaria,
      padding: const EdgeInsets.symmetric(
        horizontal: Espacamento.lg,
        vertical: Espacamento.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
    ),
  );
}

Widget botaoSecundario({
  required BuildContext context,
  required String label,
  required VoidCallback onPressed,
  IconData? icone,
  Color? corBorda,
}) {
  return OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icone, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: corBorda ?? context.corPrimaria,
      side: BorderSide(color: corBorda ?? context.corPrimaria),
      padding: const EdgeInsets.symmetric(
        horizontal: Espacamento.lg,
        vertical: Espacamento.md,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Raio.lg),
      ),
    ),
  );
}
