/// Rótulos em pt-BR para os ids de respostas da anamnese enviada ao paciente.
///
/// Usado pela ficha do paciente (visualização) e pela exportação em PDF para
/// exibir um nome legível em vez do id interno.
const Map<String, String> anamneseLabels = {
  'nome': 'Nome',
  'nascimento': 'Data de nascimento',
  'telefone': 'Telefone',
  'email': 'E-mail',
  'cidade': 'Cidade',
  'como_chamar': 'Como prefere ser chamado(a)',
  'motivos': 'O que te trouxe à terapia',
  'motivo_aberto': 'Motivo da procura',
  'sofrimento': 'Nível de sofrimento (0-10)',
  'frequencia': 'Frequência',
  'afeta_rotina': 'Afeta rotina (0-10)',
  'afeta_relacoes': 'Afeta relacionamentos (0-10)',
  'afeta_trabalho': 'Afeta trabalho/estudos (0-10)',
  'fez_terapia': 'Já fez terapia',
  'foi_psiquiatra': 'Já foi ao psiquiatra',
  'usa_medicacao': 'Usa medicação',
  'tem_diagnostico': 'Tem diagnóstico',
  'sono': 'Sono',
  'substancias': 'Usa álcool/substâncias',
  'situacoes_pioram': 'Situações que pioram',
  'pensamentos': 'Pensamentos que aparecem',
  'emocoes_frequentes': 'Emoções frequentes',
  'quando_mal': 'O que faz quando se sente mal',
  'evita': 'Evita situações',
  'busca_confirmacao': 'Busca aprovação',
  'se_cobra': 'Se cobra demais',
  'o_que_mudar': 'O que gostaria de mudar',
  'pensou_morte': 'Pensamentos de não querer viver',
  'pensou_machucar': 'Pensou em se machucar',
  'esta_seguro': 'Está em segurança',
  'objetivos': 'Objetivos',
  'expectativa': 'O que espera da terapia',
  'usa_medicacao_quais': 'Quais medicações',
  'tem_diagnostico_qual': 'Qual diagnóstico',
  'substancias_quais': 'Quais substâncias',
};

/// Formata o valor de uma resposta para exibição legível.
///
/// - Listas (checklists) → "item1, item2"
/// - bool → "Sim" / "Não"
/// - demais → toString
String formatarValorResposta(dynamic valor) {
  if (valor is List) {
    final itens = valor.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    return itens.isEmpty ? '-' : itens.join(', ');
  }
  if (valor is bool) return valor ? 'Sim' : 'Não';
  if (valor == null) return '-';
  final texto = valor.toString().trim();
  return texto.isEmpty ? '-' : texto;
}
