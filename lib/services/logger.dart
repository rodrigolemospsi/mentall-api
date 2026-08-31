import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'encryption_service.dart';

class Log {
  static const String _boxName = 'logs_tecnicos';
  static const int _maxLogLines = 500;
  static EncryptionService? _encryptionService;

  static void setEncryptionService(EncryptionService service) {
    _encryptionService = service;
  }

  static Future<void> erro(Object erro, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final mensagem = '$prefixo ERRO: $erro';
    if (kDebugMode) debugPrint(mensagem);
    await _persistir(mensagem);
  }

  static Future<void> info(String mensagem, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final msg = '$prefixo INFO: $mensagem';
    if (kDebugMode) debugPrint(msg);
    await _persistir(msg);
  }

  static Future<void> auditoria(String mensagem, {String? contexto}) async {
    final prefixo = contexto != null ? '[$contexto]' : '';
    final msg = '$prefixo AUDITORIA: $mensagem';
    if (kDebugMode) debugPrint(msg);
    await _persistir(msg);
  }

  static Future<void> _persistir(String mensagem) async {
    try {
      final timestamp = DateTime.now().toIso8601String();
      final linha = '[$timestamp] $mensagem';

      // Criptografa a linha para o box Hive (sem nunca logar PII em claro
      // quando a proteção está ativa). O arquivo continua sendo cifrado
      // individualmente por _persistirArquivo.
      String linhaParaBox = linha;
      final enc = _encryptionService;
      if (enc != null && enc.configurado && linha.isNotEmpty) {
        try {
          linhaParaBox = enc.criptografar(linha);
        } catch (_) {
          // Se a criptografia falhar, mantém a linha original (o box de logs
          // é técnico; a auditoria PII já fica cifrada no box de auditoria).
        }
      }

      if (kIsWeb) {
        _persistirWeb(linhaParaBox);
        return;
      }

      final box = Hive.box<String>(_boxName);
      final linhas = (box.get('log') ?? '').split('\n').where((l) => l.isNotEmpty).toList();
      linhas.add(linhaParaBox);
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

      String linhaParaEscrever = linha;
      if (_encryptionService != null && _encryptionService!.configurado) {
        final encrypted = _encryptionService!.criptografar(linha);
        if (encrypted != linha) {
          linhaParaEscrever = encrypted;
        }
      }

      if (!existe) {
        await arquivo.writeAsString('$linhaParaEscrever\n');
        return;
      }
      final tamanho = await arquivo.length();
      if (tamanho > 1024 * 1024) {
        await arquivo.writeAsString('$linhaParaEscrever\n');
        return;
      }
      await arquivo.writeAsString('$linhaParaEscrever\n', mode: FileMode.append);
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
