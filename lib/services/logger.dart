import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

class Log {
  static const String _boxName = 'logs_tecnicos';
  static const int _maxLogLines = 500;

  static Future<void> erro(Object erro, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final mensagem = '$prefixo ERRO: $erro';
    debugPrint(mensagem);
    await _persistir(mensagem);
  }

  static Future<void> info(String mensagem, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final msg = '$prefixo INFO: $mensagem';
    debugPrint(msg);
    await _persistir(msg);
  }

  static Future<void> auditoria(String mensagem, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final msg = '$prefixo AUDITORIA: $mensagem';
    debugPrint(msg);
    await _persistir(msg);
  }

  static Future<void> _persistir(String mensagem) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final linha = '[$timestamp] $mensagem';

      if (kIsWeb) {
        _persistirWeb(linha);
        return;
      }

      final box = Hive.box<String>(_boxName);
      final linhas = (box.get('log') ?? '').split('\n').where((l) => l.isNotEmpty).toList();
      linhas.add(linha);
      if (linhas.length > _maxLogLines) {
        linhas.removeRange(0, linhas.length - _maxLogLines);
      }
      await box.put('log', linhas.join('\n'));

      await _persistirArquivo(linha);
    } catch (_) {}
  }

  static void _persistirWeb(String linha) {
    try {
      final box = Hive.box<String>(_boxName);
      final linhas = (box.get('log') ?? '').split('\n').where((l) => l.isNotEmpty).toList();
      linhas.add(linha);
      if (linhas.length > _maxLogLines) {
        linhas.removeRange(0, linhas.length - _maxLogLines);
      }
      box.put('log', linhas.join('\n'));
    } catch (_) {}
  }

  static Future<void> _persistirArquivo(String linha) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/mentall_tecnicos.log');
      final existe = await arquivo.exists();
      if (!existe) {
        await arquivo.writeAsString('$linha\n');
        return;
      }
      final tamanho = await arquivo.length();
      if (tamanho > 1024 * 1024) {
        await arquivo.writeAsString('$linha\n');
        return;
      }
      await arquivo.writeAsString('$linha\n', mode: FileMode.append);
    } catch (_) {}
  }

  static Future<String> obterLogs() async {
    try {
      if (kIsWeb) {
        final box = Hive.box<String>(_boxName);
        return box.get('log') ?? '';
      }
      final box = Hive.box<String>(_boxName);
      return box.get('log') ?? '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> limparLogs() async {
    try {
      final box = Hive.box<String>(_boxName);
      await box.delete('log');
    } catch (_) {}
  }
}
