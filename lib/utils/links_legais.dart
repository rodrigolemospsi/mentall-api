import 'package:url_launcher/url_launcher.dart';

/// URLs públicas oficiais do MentAll PRO (site publicado em 23/10/2026).
///
/// Fonte única: o texto in-app aponta para as mesmas páginas publicadas em
/// mentallpro.com.br (itens 1.2/1.3/1.4 do checklist de publicação).
class LinksLegais {
  const LinksLegais._();

  static const String site = 'https://mentallpro.com.br';
  static const String privacidade = '$site/privacidade/';
  static const String termos = '$site/termos/';
  static const String exclusaoConta = '$site/exclusao/';
  static const String contato = 'mailto:contato@mentallpro.com.br';
  static const String suporte = 'mailto:suporte@mentallpro.com.br';

  /// Versão/data do texto publicado (deve bater com o site).
  static const String versaoPublicada = '1.2 — 23/10/2026';

  /// Abre a URL no navegador/app externo. Devolve `false` quando não foi
  /// possível abrir (a tela mostra a mensagem de erro).
  static Future<bool> abrir(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
