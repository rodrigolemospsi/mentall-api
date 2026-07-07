import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';

class ResultadoTranscricaoRelato {
  final bool sucesso;
  final String transcricao;
  final String erro;

  const ResultadoTranscricaoRelato({
    required this.sucesso,
    required this.transcricao,
    required this.erro,
  });

  factory ResultadoTranscricaoRelato.sucesso({
    required String transcricao,
  }) {
    return ResultadoTranscricaoRelato(
      sucesso: true,
      transcricao: transcricao,
      erro: '',
    );
  }

  factory ResultadoTranscricaoRelato.falha({
    required String erro,
  }) {
    return ResultadoTranscricaoRelato(
      sucesso: false,
      transcricao: '',
      erro: erro,
    );
  }
}

class TranscricaoRelatoService {
  Future<ResultadoTranscricaoRelato> transcreverAudio({
    required String audioRelatoPath,
    required String audioRelatoBase64,
    required String sessaoId,
  }) async {
    final caminhoLimpo = audioRelatoPath.trim();
    final base64Limpo = _normalizarAudioBase64(audioRelatoBase64);

    final possuiCaminhoAudio = caminhoLimpo.isNotEmpty;
    final possuiAudioBase64 = base64Limpo.isNotEmpty;

    if (!possuiCaminhoAudio && !possuiAudioBase64) {
      return ResultadoTranscricaoRelato.falha(
        erro: 'Nenhum áudio foi informado para transcrição.',
      );
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiClient.baseUrl}/transcrever'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'audio_base64': base64Limpo,
              'formato': 'wav',
            }),
          )
          .timeout(ApiClient.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final sucesso = data['sucesso'] as bool;

        if (sucesso) {
          return ResultadoTranscricaoRelato.sucesso(
            transcricao: data['transcricao'] as String,
          );
        } else {
          return ResultadoTranscricaoRelato.falha(
            erro: data['erro'] as String? ?? 'Erro do servidor.',
          );
        }
      } else {
        return ResultadoTranscricaoRelato.falha(
          erro: 'Servidor retornou código ${response.statusCode}.',
        );
      }
    } catch (erro) {
      return ResultadoTranscricaoRelato.falha(
        erro: 'Não foi possível transcrever o relato. Detalhes: $erro',
      );
    }
  }

  String _normalizarAudioBase64(String valor) {
    final texto = valor.trim();

    if (texto.startsWith('data:') && texto.contains(',')) {
      return texto.split(',').last.trim();
    }

    return texto;
  }
}
