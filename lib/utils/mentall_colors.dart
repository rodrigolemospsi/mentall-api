import 'package:flutter/material.dart';

/// Paleta e gradientes do painel de controle (backend/admin_ui.py, tema v2).
///
/// Fonte única de verdade da identidade visual "MentAll Painel" aplicada ao
/// app. Os nomes espelham as variáveis CSS `--v2-*` do painel do dono.
class PainelCores {
  PainelCores._();

  // Roxos do painel.
  static const Color roxo = Color(0xFF7C3AED); // --v2-roxo
  static const Color roxoEscuro = Color(0xFF5B21B6); // --v2-roxo-esc
  static const Color roxoClaro = Color(0xFFA78BFA); // destaque do painel
  static const Color sidebar1 = Color(0xFF6D28D9); // --v2-sidebar-1
  static const Color sidebar2 = Color(0xFF4C1D95); // --v2-sidebar-2

  // Superfícies do painel (tema claro).
  static const Color fundo = Color(0xFFF3F5FB); // --v2-fundo
  static const Color card = Color(0xFFFFFFFF); // --v2-card
  static const Color superficie = Color(0xFFF8FAFC);
  static const Color chip = Color(0xFFF1F4FA);
  static const Color borda = Color(0xFFE6EAF2); // --v2-borda
  static const Color bordaForte = Color(0xFFCBD5E1);

  // Texto do painel (tema claro).
  static const Color texto = Color(0xFF0F172A); // --v2-texto
  static const Color textoMuted = Color(0xFF64748B); // --v2-muted

  // Semânticas do painel.
  static const Color ok = Color(0xFF16A34A); // --v2-ok
  static const Color atencao = Color(0xFFD97706); // --v2-warn
  static const Color erro = Color(0xFFDC2626); // --v2-erro
  static const Color info = Color(0xFF312E81);

  // Semânticas próprias do app (não vêm do painel).
  static const Color agendado = Color(0xFF2563EB);
  static const Color cancelado = Color(0xFF64748B);
  static const Color pacote = Color(0xFF0D9488);

  // Superfícies do modo escuro (adaptação dos mesmos matizes do painel).
  static const Color escuroFundo = Color(0xFF0F172A);
  static const Color escuroSuperficie = Color(0xFF172033);
  static const Color escuroCard = Color(0xFF1E293B);
  static const Color escuroBorda = Color(0xFF334155);
  static const Color escuroTexto = Color(0xFFE2E8F0);
  static const Color escuroTextoMuted = Color(0xFF94A3B8);
  static const Color escuroPrimaria = Color(0xFFA78BFA);

  /// Gradiente da sidebar do painel (usado na navbar inferior do app).
  static const LinearGradient gradienteSidebar = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [sidebar1, sidebar2],
  );

  /// Gradiente das telas de entrada do painel (login/2FA).
  static const LinearGradient gradienteEntrada = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [roxoClaro, roxo, roxoEscuro],
  );

  static const LinearGradient gradienteEntradaEscuro = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF5B21B6), Color(0xFF2E1065), escuroFundo],
  );

  static LinearGradient gradienteEntradaPara(Brightness brightness) =>
      brightness == Brightness.dark ? gradienteEntradaEscuro : gradienteEntrada;
}

extension MentAllProColors on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
  bool get _escuro => cs.brightness == Brightness.dark;

  Color get corPrimaria => cs.primary;
  Color get corOnPrimaria => cs.onPrimary;

  Color get corFundo => cs.surface;
  Color get corSuperficie =>
      _escuro ? PainelCores.escuroSuperficie : cs.surfaceContainerLow;
  Color get corCard =>
      _escuro ? PainelCores.escuroCard : cs.surfaceContainerLowest;
  Color get corContainerPrimario => cs.primaryContainer;

  Color get corTextoHeading => cs.onSurface;
  Color get corOnSurface => cs.onSurface;
  Color get corTextoBody => cs.onSurface.withValues(alpha: 0.87);
  Color get corTextoSecondary => cs.onSurface.withValues(alpha: 0.6);
  Color get corTextoMuted => cs.onSurfaceVariant;
  Color get corTextoPlaceholder => cs.onSurface.withValues(alpha: 0.38);
  Color get corTextoDisabled => cs.onSurface.withValues(alpha: 0.25);

  Color get corDivider => cs.outlineVariant;
  Color get corBorda => cs.outlineVariant;

  /// Sombra suave do painel: `0 10px 30px rgba(15, 23, 42, 0.06)`.
  List<BoxShadow>? get corCardSombra => _escuro
      ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ]
      : [
          BoxShadow(
            color: PainelCores.texto.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

  Border get corCardBorda =>
      Border.all(color: _escuro ? PainelCores.escuroBorda : PainelCores.borda);

  Color get corSuccess => _escuro ? const Color(0xFF4ADE80) : PainelCores.ok;
  Color get corError => cs.error;
  Color get corOnError => cs.onError;
  Color get corWarning =>
      _escuro ? const Color(0xFFFBBF24) : PainelCores.atencao;
  Color get corDanger => _escuro ? const Color(0xFFF87171) : PainelCores.erro;
  Color get corScheduled =>
      _escuro ? const Color(0xFF60A5FA) : PainelCores.agendado;
  Color get corCancelled =>
      _escuro ? const Color(0xFF94A3B8) : PainelCores.cancelado;
  Color get corPacote => _escuro ? const Color(0xFF2DD4BF) : PainelCores.pacote;

  Color get corWhatsAppBg => const Color(0xFF25D366);
  Color get corWhatsAppText => const Color(0xFF075E54);

  Color get corAcaoFundo =>
      _escuro ? cs.surfaceContainerHigh : cs.surfaceContainer;
  Color get corAcaoBorda => cs.outlineVariant;
  Color get corAcaoFg => cs.onSurfaceVariant;

  Color get corAtividadeIconeFundo => cs.primaryContainer;
  Color get corAtividadeIcone => cs.primary;

  Color get corAppBarBg =>
      _escuro ? PainelCores.escuroCard : cs.surfaceContainerLowest;
  Color get corAppBarFg => cs.onSurfaceVariant;
}
