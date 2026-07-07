import 'package:flutter/foundation.dart';

class Log {
  static void erro(Object erro, {String? contexto}) {
    final prefixo = contexto != null ? '[$contexto]' : '';
    debugPrint('$prefixo ERRO: $erro');
  }
}
