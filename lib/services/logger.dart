import 'package:flutter/foundation.dart';

class Log {
  static void erro(Object erro, {String? contexto}) {
    final prefixo = contexto != null ? '[$contexto]' : '';
    debugPrint('$prefixo ERRO: $erro');
  }

  static void info(String mensagem, {String? contexto}) {
    final prefixo = contexto != null ? '[$contexto]' : '';
    debugPrint('$prefixo INFO: $mensagem');
  }

  static void auditoria(String mensagem, {String? contexto}) {
    final prefixo = contexto != null ? '[$contexto]' : '';
    debugPrint('$prefixo AUDITORIA: $mensagem');
  }
}
