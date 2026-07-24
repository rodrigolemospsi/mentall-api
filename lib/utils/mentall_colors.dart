import 'package:flutter/material.dart';

extension MentAllColors on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;

  Color get corPrimaria => cs.primary;
  Color get corOnPrimaria => cs.onPrimary;

  Color get corFundo => cs.surface;
  Color get corSuperficie => cs.surfaceContainerLow;
  Color get corCard => cs.surface;
  Color get corContainerPrimario => cs.primaryContainer;

  Color get corTextoHeading => cs.onSurface;
  Color get corTextoBody => cs.onSurface.withValues(alpha: 0.87);
  Color get corTextoSecondary => cs.onSurface.withValues(alpha: 0.6);
  Color get corTextoMuted => cs.onSurface.withValues(alpha: 0.5);
  Color get corTextoPlaceholder => cs.onSurface.withValues(alpha: 0.38);
  Color get corTextoDisabled => cs.onSurface.withValues(alpha: 0.25);

  Color get corDivider => cs.outlineVariant;
  Color get corBorda => cs.outlineVariant;

  Color get corSuccess => const Color(0xFF2E7D32);
  Color get corError => cs.error;
  Color get corOnError => cs.onError;
  Color get corWarning => const Color(0xFFE65100);
  Color get corDanger => const Color(0xFFC62828);
  Color get corScheduled => const Color(0xFF1976D2);
  Color get corCancelled => const Color(0xFF757575);

  Color get corWhatsAppBg => const Color(0xFF25D366);
  Color get corWhatsAppText => const Color(0xFF075E54);

  Color get corAppBarBg => cs.surface;
  Color get corAppBarFg => cs.primary;
}
