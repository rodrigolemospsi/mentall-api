import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Conecta/consulta o WhatsApp do profissional pelo backend.
///
/// O app NUNCA fala direto com o wuzapi: só com o backend, que guarda o token
/// da instância. Aqui ficam apenas as chamadas aos endpoints `/wuzapi/*`.
class WuzapiService {
  WuzapiService._();

  static const Duration _timeout = Duration(seconds: 30);

  /// Estado da conexão (configurado/conectado/logado/numero).
  static Future<Map<String, dynamic>> status() =>
      _get('/wuzapi/status', erroPadrao: 'Não foi possível consultar o WhatsApp.');

  /// Gera o código de pareamento (vincula sem QR, no mesmo celular).
  static Future<Map<String, dynamic>> parear(String telefone) => _post(
        '/wuzapi/parear',
        body: {'telefone': telefone},
        erroPadrao: 'Não foi possível gerar o código de pareamento.',
      );

  /// QR Code (data URI) como alternativa ao código.
  static Future<Map<String, dynamic>> qr() =>
      _get('/wuzapi/qr', erroPadrao: 'Não foi possível obter o QR Code.');

  /// Desconecta a sessão ou desvincula o aparelho.
  static Future<bool> desconectar({bool logout = false}) async {
    final r = await _post(
      '/wuzapi/desconectar',
      body: {'logout': logout},
      erroPadrao: 'Não foi possível desconectar o WhatsApp.',
    );
    return r['sucesso'] == true;
  }

  /// Envia uma mensagem de teste pelo WhatsApp conectado.
  static Future<Map<String, dynamic>> testar(String telefone) => _post(
        '/wuzapi/testar',
        body: {'telefone': telefone},
        erroPadrao: 'Não foi possível enviar a mensagem de teste.',
      );

  static Future<Map<String, dynamic>> _get(
    String path, {
    required String erroPadrao,
  }) async {
    if (!await ApiClient.ensureAuthenticated()) {
      return {'sucesso': false, 'erro': 'Sem conexão com o servidor.'};
    }
    try {
      final res = await ApiClient.get(path, customTimeout: _timeout);
      return _parse(res, erroPadrao);
    } catch (_) {
      return {'sucesso': false, 'erro': erroPadrao};
    }
  }

  static Future<Map<String, dynamic>> _post(
    String path, {
    Map<String, dynamic>? body,
    required String erroPadrao,
  }) async {
    if (!await ApiClient.ensureAuthenticated()) {
      return {'sucesso': false, 'erro': 'Sem conexão com o servidor.'};
    }
    try {
      final res = await ApiClient.post(path, body: body, customTimeout: _timeout);
      return _parse(res, erroPadrao);
    } catch (_) {
      return {'sucesso': false, 'erro': erroPadrao};
    }
  }

  static Map<String, dynamic> _parse(http.Response res, String erroPadrao) {
    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    if (res.statusCode == 200 && data['sucesso'] == true) {
      return {...data, 'sucesso': true};
    }
    final detalhe = data['erro'] ?? data['detail'] ?? erroPadrao;
    return {'sucesso': false, 'erro': detalhe.toString()};
  }
}
