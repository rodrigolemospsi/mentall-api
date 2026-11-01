/// Utilitários de documentos fiscais/pessoais (CPF/CNPJ).
class Documentos {
  Documentos._();

  /// Remove tudo que não for dígito.
  static String limpar(String valor) => valor.replaceAll(RegExp(r'\D'), '');

  /// Formata CPF (11 dígitos) como `000.000.000-00`; devolve o original limpo
  /// quando o tamanho não confere.
  static String formatarCpf(String cpf) {
    final numeros = limpar(cpf);
    if (numeros.length != 11) return numeros;
    return '${numeros.substring(0, 3)}.${numeros.substring(3, 6)}.'
        '${numeros.substring(6, 9)}-${numeros.substring(9)}';
  }

  /// Formata CNPJ (14 dígitos) como `00.000.000/0000-00`.
  static String formatarCnpj(String cnpj) {
    final numeros = limpar(cnpj);
    if (numeros.length != 14) return numeros;
    return '${numeros.substring(0, 2)}.${numeros.substring(2, 5)}.'
        '${numeros.substring(5, 8)}/${numeros.substring(8, 12)}-'
        '${numeros.substring(12)}';
  }

  static bool cpfPreenchido(String cpf) => limpar(cpf).length == 11;
}
