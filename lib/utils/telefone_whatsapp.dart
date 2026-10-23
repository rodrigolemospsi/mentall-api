// Exibição amigável de números/JIDs do WhatsApp.

/// Formata um número/JID do WhatsApp para exibição.
///
/// Aceita formatos como `557592298347@s.whatsapp.net`,
/// `557592298347:10@s.whatsapp.net` ou apenas os dígitos. Retorna
/// `(DD) 9XXXX-XXXX` quando reconhece um número brasileiro; caso contrário,
/// devolve os dígitos como vieram.
String formatarNumeroWhatsapp(String bruto) {
  final texto = bruto.trim();
  if (texto.isEmpty) return '';

  // JID: "numero@s.whatsapp.net" (com possível sufixo de dispositivo ":10").
  final semDominio = texto.split('@').first.split(':').first;
  final digitos = semDominio.replaceAll(RegExp(r'\D'), '');
  if (digitos.isEmpty) return texto;

  var local = digitos;
  if (local.startsWith('55') && (local.length == 12 || local.length == 13)) {
    local = local.substring(2);
  }
  if (local.length == 11) {
    return '(${local.substring(0, 2)}) '
        '${local.substring(2, 7)}-${local.substring(7)}';
  }
  if (local.length == 10) {
    return '(${local.substring(0, 2)}) '
        '${local.substring(2, 6)}-${local.substring(6)}';
  }
  return digitos;
}
