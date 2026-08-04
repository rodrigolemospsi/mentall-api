import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class CrpService {
  Future<Map<String, dynamic>> verificarCrp(String registro) async {
    final autenticado = await ApiClient.ensureAuthenticated();
    if (!autenticado) {
      return {'ativo': false, 'erro': 'Nao foi possivel autenticar com o servidor.'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/verificar-crp'),
            headers: ApiClient.defaultHeaders(),
            body: jsonEncode({'registro': registro}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'ativo': data['ativo'] as bool? ?? false,
          'nome_oficial': data['nome_oficial'] as String? ?? '',
          'data_inscricao': data['data_inscricao'] as String? ?? '',
          'erro': data['erro'] as String? ?? '',
        };
      }

      return {'ativo': false, 'erro': 'Erro HTTP ${response.statusCode}'};
    } catch (e) {
      return {'ativo': false, 'erro': 'Erro de conexao: $e'};
    }
  }
}
