import 'package:flutter/material.dart';

import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/tipografia.dart';

class MentAllCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const MentAllCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = Raio.xl,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final card = Container(
      padding: padding ?? const EdgeInsets.all(Espacamento.base),
      decoration: BoxDecoration(
        color: color ?? context.corCard,
        borderRadius: radius,
        boxShadow: context.corCardSombra,
        border: context.corCardBorda,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: card,
      ),
    );
  }
}
