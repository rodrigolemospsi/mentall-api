import 'package:flutter/material.dart';

import '../utils/raio.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color cor;
  final IconData? icone;
  final double fontSize;
  final bool pill;
  final bool borda;

  const StatusChip({
    super.key,
    required this.label,
    required this.cor,
    this.icone,
    this.fontSize = 11,
    this.pill = true,
    this.borda = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: pill ? 10 : 8,
        vertical: pill ? 4 : 3,
      ),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(pill ? 999 : Raio.xs),
        border: borda ? Border.all(color: cor.withValues(alpha: 0.25)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: fontSize + 1, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: cor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
