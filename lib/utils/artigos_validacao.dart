/// Validação/limpeza do campo `artigosSugeridos` de sessões.
///
/// Entre 13/07 e 15/07/2026 o campo era gerado diretamente pelo LLM com
/// títulos/DOIs inventados (formato `1. Título: ... Link: ...`). Esses dados
/// ficaram persistidos e, ao reabrir a sessão, eram exibidos como artigos.
/// O pipeline atual gera apenas artigos reais (OpenAlex) ou buscas sugeridas.
///
/// `limparArtigosAntigos` detecta o formato legado e retorna uma string vazia,
/// para que o app não exiba conteúdo alucinado de sessões antigas.
library;

/// Retorna true se o texto parece ser do formato antigo (LLM gerava direto).
bool pareceFormatoAntigo(String? texto) {
  if (texto == null || texto.trim().isEmpty) return false;
  final t = texto.trim();

  // Formato novo sempre tem ou "Busca sugerida" (fallback) ou link real
  // (doi.org / openalex.org / search.scielo.org / periodicos.capes / oasisbr).
  if (t.contains('Busca sugerida')) return false;
  final temLinkReal = RegExp(
    r'https?://(doi\.org|openalex\.org|search\.scielo\.org|periodicos\.capes|oasisbr\.ibict)',
  ).hasMatch(t);
  if (temLinkReal) return false;

  // Padrões do formato antigo: "1. Título: ..." com "Link:" ou "Acesse:".
  final temTituloLegado = RegExp(r'^\d+\.\s*Título:', caseSensitive: false)
      .hasMatch(t);
  final temLinkLegado = RegExp(r'Link:\s*https?://', caseSensitive: false)
      .hasMatch(t);
  final temAcesseLegado = RegExp(r'Acesse\s*:', caseSensitive: false)
      .hasMatch(t);

  // Se o texto tem URLs mas nenhuma é de fonte confiável e tem padrão legado,
  // considera antigo.
  if (temTituloLegado || temLinkLegado || temAcesseLegado) return true;

  // Último recurso: conteúdo com numeração "1. ..." e alguma URL de link curto
  // (ex.: bit.ly, doi sem domínio confiável) — provável legado.
  return RegExp(r'^\d+\.\s').hasMatch(t);
}

/// Retorna o texto limpo: vazio se parecer antigo, senão o original.
String limparArtigosAntigos(String? texto) {
  if (texto == null) return '';
  return pareceFormatoAntigo(texto) ? '' : texto.trim();
}
