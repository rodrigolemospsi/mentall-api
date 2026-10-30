import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Pasta escolhida pelo usuário para os backups automáticos.
///
/// No Android, [valor] é uma URI de árvore do Storage Access Framework
/// (`content://...`), gravada via canal nativo — caminhos de arquivo comuns
/// não são graváveis por `dart:io` fora do diretório privado do app. Nas
/// demais plataformas, [valor] é um caminho de diretório.
class PastaBackup {
  final String valor;
  final String nome;

  const PastaBackup({required this.valor, required this.nome});
}

/// Erro amigável ao escolher/validar a pasta de backup.
class PastaBackupException implements Exception {
  final String mensagem;

  const PastaBackupException(this.mensagem);

  @override
  String toString() => mensagem;
}

const MethodChannel _canalBackupSaf = MethodChannel('mentall/backup_saf');

/// Salva um arquivo de backup em um diretório.
///
/// - Se [diretorio] for vazio, usa o diretório de documentos do app.
/// - Pasta escolhida no Android (`content://`) é gravada via SAF (canal nativo).
/// - Retorna o caminho/URI do arquivo salvo, ou `null` em erro.
Future<String?> salvarBackupArquivo(
  String conteudo,
  String nomeArquivo, {
  String? diretorio,
}) async {
  try {
    final local = (diretorio ?? '').trim();
    if (Platform.isAndroid && local.startsWith('content://')) {
      final salvo = await _canalBackupSaf.invokeMethod<String>('writeFile', {
        'uri': local,
        'name': nomeArquivo,
        'content': conteudo,
      });
      return (salvo == null || salvo.isEmpty) ? null : salvo;
    }
    final pasta = local.isNotEmpty
        ? await Directory(local).create(recursive: true)
        : await getApplicationDocumentsDirectory();
    final arquivo = File('${pasta.path}${Platform.pathSeparator}$nomeArquivo');
    await arquivo.writeAsString(conteudo);
    return arquivo.path;
  } catch (_) {
    return null;
  }
}

/// Abre o seletor de pasta para o backup automático.
///
/// [PastaBackup.valor] deve ser salvo em `ConfiguracoesService.backupLocal` e
/// [PastaBackup.nome] em `ConfiguracoesService.backupLocalNome`.
/// Lança [PastaBackupException] quando a pasta escolhida não permite gravação.
Future<PastaBackup?> escolherPastaBackup() async {
  if (Platform.isAndroid) {
    final Map<String, dynamic>? dados;
    try {
      dados = await _canalBackupSaf.invokeMapMethod<String, dynamic>(
        'pickDirectory',
      );
    } on PlatformException catch (e) {
      throw PastaBackupException(
        e.message ?? 'Não foi possível abrir o seletor de pastas.',
      );
    } catch (_) {
      throw const PastaBackupException(
        'Não foi possível abrir o seletor de pastas.',
      );
    }
    if (dados == null) return null;
    final uri = (dados['uri'] as String?)?.trim();
    if (uri == null || uri.isEmpty) return null;
    final nome = (dados['name'] as String?)?.trim();
    await _validarPastaSaf(uri);
    return PastaBackup(
      valor: uri,
      nome: (nome == null || nome.isEmpty) ? 'Pasta escolhida' : nome,
    );
  }

  final caminho = await FilePicker.platform.getDirectoryPath();
  if (caminho == null || caminho.isEmpty) return null;
  await _validarCaminhoPasta(caminho);
  return PastaBackup(valor: caminho, nome: _nomeDaPasta(caminho));
}

Future<void> _validarPastaSaf(String uri) async {
  try {
    final ok = await _canalBackupSaf.invokeMethod<bool>('testDirectory', {
      'uri': uri,
    });
    if (ok != true) {
      throw const PastaBackupException(
        'A pasta escolhida não permite gravação direta.',
      );
    }
  } on PlatformException catch (e) {
    throw PastaBackupException(
      e.message ?? 'A pasta escolhida não permite gravação direta.',
    );
  }
}

Future<void> _validarCaminhoPasta(String caminho) async {
  try {
    final pasta = Directory(caminho);
    if (!await pasta.exists()) {
      throw const PastaBackupException('A pasta escolhida não existe.');
    }
    final teste = File(
      '${pasta.path}${Platform.pathSeparator}.mentall-teste-escrita.json',
    );
    await teste.writeAsString('{}');
    await teste.delete();
  } catch (e) {
    if (e is PastaBackupException) rethrow;
    throw const PastaBackupException(
      'A pasta escolhida não permite gravação direta.',
    );
  }
}

String _nomeDaPasta(String caminho) {
  final normalizado = caminho.replaceAll('\\', '/');
  final partes = normalizado
      .split('/')
      .where((p) => p.trim().isNotEmpty)
      .toList();
  if (partes.isEmpty) return 'Pasta escolhida';
  return partes.last;
}

/// Nome amigável para exibir no app a partir do valor salvo (URI ou caminho).
String nomePastaBackupParaExibir(String valor, {String nomeSalvo = ''}) {
  if (nomeSalvo.trim().isNotEmpty) return nomeSalvo.trim();
  final v = valor.trim();
  if (v.isEmpty) return '';
  if (v.startsWith('content://')) {
    final partes = Uri.tryParse(v)?.pathSegments ?? const <String>[];
    if (partes.isNotEmpty) {
      final ultimo = Uri.decodeComponent(partes.last);
      if (ultimo.isNotEmpty) return ultimo;
    }
    return 'Pasta escolhida';
  }
  return _nomeDaPasta(v);
}

/// Converte um [Map] em JSON legível (usado para exibir o conteúdo do backup).
String? jsonParaTexto(Map<String, dynamic> dados) {
  try {
    return jsonEncode(dados);
  } catch (_) {
    return null;
  }
}
