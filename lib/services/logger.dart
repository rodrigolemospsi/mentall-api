import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'encryption_service.dart';

class Log {
  static const String _boxName = 'logs_tecnicos';
  static const int _maxLogLines = 500;
  static const String _purgeKey = 'purge_log_claro_v1';
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

      // Fail-closed, como no EncryptedServiceMixin.encrypt: uma linha de log
      // tecnico pode carregar PII (ex.: `response.body` com nome e telefone do
      // paciente). Se a cifra nao estiver disponivel, grava-se apenas o rotulo
      // (quando, onde e de que tipo) e NUNCA o texto. Antes desta correcao a
      // linha ia em claro para o box e para mentall_tecnicos.log.
      final enc = _encryptionService;
      String? linhaCifrada;
      if (enc != null && enc.configurado && linha.isNotEmpty) {
        try {
          linhaCifrada = enc.criptografar(linha);
        } catch (_) {
          linhaCifrada = null;
        }
      }
      final linhaSegura = linhaCifrada ?? '[$timestamp] ${_redigir(mensagem)}';

      if (kIsWeb) {
        _persistirWeb(linhaSegura);
        return;
      }

      final box = Hive.box<String>(_boxName);
      final linhas = (box.get('log') ?? '').split('\n').where((l) => l.isNotEmpty).toList();
      linhas.add(linhaSegura);
      if (linhas.length > _maxLogLines) {
        linhas.removeRange(0, linhas.length - _maxLogLines);
      }
      await box.put('log', linhas.join('\n'));

      await _persistirArquivo(linhaSegura);
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

  /// Grava no arquivo tecnico uma linha **ja protegida** (cifrada ou redigida).
  ///
  /// A decisao de protecao e tomada em [_persistir]: aqui nunca chega texto em
  /// claro, e por isso este metodo nao cifra nada por conta propria.
  static Future<void> _persistirArquivo(String linhaParaEscrever) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final arquivo = File('${dir.path}/mentall_tecnicos.log');
      final existe = await arquivo.exists();

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

  /// Versao sem conteudo da linha: preserva o nivel e o contexto (o valor de
  /// diagnostico) e descarta a mensagem, que pode conter PII.
  static String _redigir(String mensagem) {
    for (final marcador in const ['ERRO: ', 'INFO: ', 'AUDITORIA: ']) {
      final posicao = mensagem.indexOf(marcador);
      if (posicao != -1) {
        return '${mensagem.substring(0, posicao + marcador.length)}'
            '(conteudo nao registrado: cifra indisponivel)';
      }
    }
    return '(conteudo nao registrado: cifra indisponivel)';
  }

  /// Expurgo **único** do log técnico gravado em texto puro por versões
  /// anteriores à correção de 06/10/2026 — aqueles arquivos podem conter nome e
  /// telefone de paciente. Roda no boot e grava uma flag no próprio box, então
  /// não depende da chave de cifra (que ainda não existe neste ponto do boot).
  ///
  /// Idempotente: depois da primeira execução não toca mais no log, para não
  /// apagar diagnóstico novo.
  static Future<void> purgarHistoricoLegado() async {
    try {
      final box = Hive.box<String>(_boxName);
      if (box.get(_purgeKey) == 'ok') return;

      // Preserva o que JÁ estava cifrado (começa com '3:' ou '2:') e descarta o
      // resto, que é texto puro. A distinção é confiável: a linha cifrada não
      // carrega timestamp, então texto claro sempre começa com '['.
      bool segura(String l) => l.startsWith('3:') || l.startsWith('2:');
      final linhas = (box.get('log') ?? '')
          .split('\n')
          .where((l) => l.isNotEmpty && segura(l))
          .toList();
      if (linhas.isEmpty) {
        await box.delete('log');
      } else {
        await box.put('log', linhas.join('\n'));
      }

      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final arquivo = File('${dir.path}/mentall_tecnicos.log');
          if (await arquivo.exists()) {
            final seguras = (await arquivo.readAsString())
                .split('\n')
                .where((l) => l.isNotEmpty && segura(l))
                .toList();
            if (seguras.isEmpty) {
              await arquivo.delete();
            } else {
              await arquivo.writeAsString('${seguras.join('\n')}\n');
            }
          }
        } catch (_) {
          // Sem acesso ao diretório (ou sem plugin): o box já foi limpo.
        }
      }

      await box.put(_purgeKey, 'ok');
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
