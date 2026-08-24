import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'encryption_service.dart';
import 'logger.dart';

class AudioRelatoService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _inicializado = true;
  String? _caminhoAudioAtual;

  StreamSubscription<Uint8List>? _webAudioStreamSubscription;
  final List<int> _webAudioBytes = [];
  String _webAudioBase64Atual = '';

  static const int _webSampleRate = 44100;
  static const int _webNumChannels = 1;
  static const int _webBitsPerSample = 16;

  /// Verifica e solicita permissão de microfone quando necessário.
  ///
  /// Retorna true quando o app tem permissão para gravar.
  Future<bool> verificarPermissaoMicrofone() async {
    if (!_inicializado) {
      return false;
    }

    return _recorder.hasPermission();
  }

  /// Inicia a gravação do relato pós-sessão.
  ///
  /// Na Web, a gravação é feita por stream de bytes para permitir persistência
  /// real em Base64, sem depender de URLs temporárias do tipo blob.
  ///
  /// Em Android/iOS/Desktop, a gravação continua sendo feita em arquivo local.
  Future<String> iniciarGravacao({
    required String sessaoId,
  }) async {
    if (!_inicializado) {
      throw Exception('O gravador de áudio já foi finalizado.');
    }

    final temPermissao = await verificarPermissaoMicrofone();

    if (!temPermissao) {
      throw Exception('Permissão de microfone não concedida.');
    }

    final estaGravando = await _recorder.isRecording();

    if (estaGravando) {
      throw Exception('Já existe uma gravação em andamento.');
    }

    _webAudioBytes.clear();
    _webAudioBase64Atual = '';

    if (kIsWeb) {
      await _webAudioStreamSubscription?.cancel();
      _webAudioStreamSubscription = null;

      final caminhoInterno = _gerarIdentificadorAudioWeb(sessaoId: sessaoId);

      final stream = await _recorder.startStream(
        _gerarConfiguracaoGravacaoWebStream(),
      );

      _webAudioStreamSubscription = stream.listen(
        (bytes) {
          if (bytes.isNotEmpty) {
            _webAudioBytes.addAll(bytes);
          }
        },
      );

      _caminhoAudioAtual = caminhoInterno;
      return caminhoInterno;
    }

    final caminhoArquivo = await _gerarCaminhoArquivoAudio(sessaoId: sessaoId);
    final configuracao = _gerarConfiguracaoGravacaoArquivo();

    await _recorder.start(
      configuracao,
      path: caminhoArquivo,
    );

    try {
      await WakelockPlus.enable();
    } catch (_) {}

    _caminhoAudioAtual = caminhoArquivo;

    return caminhoArquivo;
  }

  /// Pausa a gravação atual.
  Future<void> pausarGravacao() async {
    if (!_inicializado) return;

    final estaGravando = await _recorder.isRecording();

    if (!estaGravando) return;

    await _recorder.pause();
  }

  /// Retoma uma gravação pausada.
  Future<void> retomarGravacao() async {
    if (!_inicializado) return;

    await _recorder.resume();
  }

  /// Finaliza a gravação e retorna o caminho/identificador do áudio gerado.
  Future<String?> pararGravacao() async {
    if (!_inicializado) return null;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    if (kIsWeb) {
      final caminhoAntesDeParar = _caminhoAudioAtual;

      await _recorder.stop();
      await _webAudioStreamSubscription?.cancel();
      _webAudioStreamSubscription = null;

      if (_webAudioBytes.isNotEmpty) {
        final wavBytes = _montarArquivoWav(
          pcmBytes: Uint8List.fromList(_webAudioBytes),
          sampleRate: _webSampleRate,
          channels: _webNumChannels,
          bitsPerSample: _webBitsPerSample,
        );

        _webAudioBase64Atual = base64Encode(wavBytes);
      }

      _caminhoAudioAtual = caminhoAntesDeParar;
      return _caminhoAudioAtual;
    }

    final caminhoFinal = await _recorder.stop();

    if (caminhoFinal != null && caminhoFinal.trim().isNotEmpty) {
      _caminhoAudioAtual = caminhoFinal.trim();

      final file = File(_caminhoAudioAtual!);
      if (!await file.exists()) {
        Log.erro('Arquivo de audio nao encontrado apos gravacao: $_caminhoAudioAtual');
        return _caminhoAudioAtual;
      }
      final fileSize = await file.length();
      Log.info('Gravacao finalizada: caminho=$_caminhoAudioAtual tamanho=$fileSize bytes');
      if (fileSize == 0) {
        Log.erro('Arquivo de audio vazio apos gravacao: $_caminhoAudioAtual');
        return _caminhoAudioAtual;
      }

      await _criptografarArquivo(_caminhoAudioAtual!);
      return _caminhoAudioAtual;
    }

    return _caminhoAudioAtual;
  }

  /// Tenta obter o áudio atual como Base64.
  ///
  /// Na Web, retorna o WAV montado em memória a partir dos bytes capturados
  /// durante a gravação. Isso evita depender de blob temporário do navegador.
  ///
  /// Em Android/iOS/Desktop, nesta fase retorna string vazia porque o áudio
  /// principal já fica disponível via arquivo local.
  Future<String> obterAudioAtualBase64() async {
    if (!_inicializado) {
      return '';
    }

    if (!kIsWeb) {
      return '';
    }

    final base64Atual = _webAudioBase64Atual.trim();

    if (base64Atual.isNotEmpty) {
      return base64Atual;
    }

    if (_webAudioBytes.isEmpty) {
      return '';
    }

    final wavBytes = _montarArquivoWav(
      pcmBytes: Uint8List.fromList(_webAudioBytes),
      sampleRate: _webSampleRate,
      channels: _webNumChannels,
      bitsPerSample: _webBitsPerSample,
    );

    _webAudioBase64Atual = base64Encode(wavBytes);

    return _webAudioBase64Atual;
  }

  /// Cancela a gravação atual.
  ///
  /// Se houver uma gravação em andamento, ela será descartada pelo gravador.
  /// Caso já exista um áudio anterior vinculado à sessão, a tela decide se
  /// mantém ou remove esse vínculo. Este método limpa apenas o áudio corrente
  /// controlado pelo serviço.
  Future<void> cancelarGravacao() async {
    if (!_inicializado) return;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    await _recorder.cancel();
    await _webAudioStreamSubscription?.cancel();

    _webAudioStreamSubscription = null;
    _webAudioBytes.clear();
    _webAudioBase64Atual = '';
    if (_caminhoAudioAtual != null) {
      _cacheAudioDescriptografado.remove(_caminhoAudioAtual);
    }
    _caminhoAudioAtual = null;
  }

  /// Remove a referência ao áudio atualmente vinculado ao serviço.
  ///
  /// Este método é usado pela tela da sessão quando o profissional decide
  /// remover o áudio do relato pós-sessão.
  ///
  /// Nesta fase do MentAll PRO, este método:
  /// - cancela qualquer gravação em andamento;
  /// - limpa a referência interna ao áudio atual;
  /// - não tenta excluir fisicamente arquivos do dispositivo.
  ///
  /// A limpeza clínica completa deve ser feita pela tela/model da sessão:
  /// - limpar audioRelatoPath;
  /// - limpar audioRelatoBase64;
  /// - limpar transcrição;
  /// - limpar apontamentos do Copiloto;
  /// - limpar processamento de IA;
  /// - marcar como não revisado.
  Future<void> removerAudioAtual() async {
    if (!_inicializado) return;

    final estaGravando = await _recorder.isRecording();

    if (estaGravando) {
      await _recorder.cancel();
    }

    await _webAudioStreamSubscription?.cancel();

    _webAudioStreamSubscription = null;
    _webAudioBytes.clear();
    _webAudioBase64Atual = '';
    if (_caminhoAudioAtual != null) {
      _cacheAudioDescriptografado.remove(_caminhoAudioAtual);
    }
    _caminhoAudioAtual = null;
  }

  /// Informa se há gravação em andamento.
  Future<bool> estaGravando() async {
    if (!_inicializado) return false;

    return _recorder.isRecording();
  }

  /// Retorna o caminho/identificador do áudio atualmente vinculado ao serviço.
  String? get caminhoAudioAtual => _caminhoAudioAtual;

  /// Libera os recursos do gravador.
  Future<void> dispose() async {
    if (!_inicializado) return;

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    await _webAudioStreamSubscription?.cancel();
    await _recorder.dispose();

    _webAudioStreamSubscription = null;
    _webAudioBytes.clear();
    _webAudioBase64Atual = '';
    _inicializado = false;
  }

  /// Configuração usada na Web para captura em stream.
  ///
  /// O stream é capturado em PCM 16-bit e depois encapsulado manualmente como
  /// WAV para permitir reprodução posterior via Base64.
  RecordConfig _gerarConfiguracaoGravacaoWebStream() {
    return const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _webSampleRate,
      numChannels: _webNumChannels,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );
  }

  /// Configuração usada em plataformas com arquivo local.
  ///
  /// Em Android/iOS/Desktop, mantemos AAC LC em arquivo M4A, que é mais leve
  /// e mais adequado para armazenamento local e envio futuro para transcrição.
  ///
  /// 16 kHz / 32 kbps é a taxa nativa do Whisper (transcrição) com qualidade
  /// adequada para fala e arquivo ~3x menor que o antigo (44,1 kHz / 96 kbps).
  RecordConfig _gerarConfiguracaoGravacaoArquivo() {
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 32000,
      sampleRate: 16000,
      numChannels: 1,
      autoGain: true,
      echoCancel: true,
      noiseSuppress: true,
    );
  }

  Future<String> _gerarCaminhoArquivoAudio({
    required String sessaoId,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final diretorioBase = await getApplicationDocumentsDirectory();

    return '${diretorioBase.path}/relato_${sessaoId}_$timestamp.m4a';
  }

  String _gerarIdentificadorAudioWeb({
    required String sessaoId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    return 'mentall-web-audio://relato_${sessaoId}_$timestamp.wav';
  }

  Uint8List _montarArquivoWav({
    required Uint8List pcmBytes,
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLength = pcmBytes.length;
    final fileSize = 36 + dataLength;

    final header = BytesBuilder();

    header.add(_asciiBytes('RIFF'));
    header.add(_uint32LittleEndian(fileSize));
    header.add(_asciiBytes('WAVE'));

    header.add(_asciiBytes('fmt '));
    header.add(_uint32LittleEndian(16));
    header.add(_uint16LittleEndian(1));
    header.add(_uint16LittleEndian(channels));
    header.add(_uint32LittleEndian(sampleRate));
    header.add(_uint32LittleEndian(byteRate));
    header.add(_uint16LittleEndian(blockAlign));
    header.add(_uint16LittleEndian(bitsPerSample));

    header.add(_asciiBytes('data'));
    header.add(_uint32LittleEndian(dataLength));
    header.add(pcmBytes);

    return header.toBytes();
  }

  Future<void> _criptografarArquivo(String caminho) async {
    final file = File(caminho);
    if (!await file.exists()) return;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;
    Log.info('Criptografando audio: $caminho (${bytes.length} bytes)');

    final sw = Stopwatch()..start();
    final encrypted = await EncryptionService.criptografarBytes(bytes);
    sw.stop();
    Log.info('Criptografia concluida em ${sw.elapsedMilliseconds}ms');

    if (encrypted == null) {
      throw Exception('PIN não configurado. Configure o PIN nas Configurações > Segurança para gravar áudio.');
    }
    await file.writeAsBytes(encrypted);
    Log.info('Audio criptografado com sucesso: $caminho');
  }

  static final Map<String, Uint8List> _cacheAudioDescriptografado = {};

  static bool _ehFormatoBinario(Uint8List bytes) {
    return bytes.length >= 4 &&
        bytes[0] == 0x4D &&
        bytes[1] == 0x41 &&
        bytes[2] == 0x56 &&
        bytes[3] == 0x31;
  }

  static Future<Uint8List> lerAudioDescriptografado(String caminho) async {
    final cacheado = _cacheAudioDescriptografado[caminho];
    if (cacheado != null) {
      Log.info('Audio recuperado do cache: $caminho');
      return cacheado;
    }

    final file = File(caminho);
    if (!await file.exists()) {
      throw Exception('Arquivo de audio nao encontrado: $caminho');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('Arquivo de audio vazio.');
    }
    Log.info('Lendo audio: $caminho (${bytes.length} bytes, primeiro byte=0x${bytes[0].toRadixString(16)})');

    // 1) Novo formato binario "MAV1"
    if (_ehFormatoBinario(bytes)) {
      final sw = Stopwatch()..start();
      final decrypted = await EncryptionService.descriptografarBytes(bytes);
      sw.stop();
      Log.info('Audio descriptografado (binario) em ${sw.elapsedMilliseconds}ms');
      if (decrypted == null || decrypted.isEmpty) {
        throw Exception(
          'Audio criptografado e app bloqueado. Desbloqueie o PIN para reproduzir.',
        );
      }
      _cacheAudioDescriptografado[caminho] = decrypted;
      return decrypted;
    }

    // 2) Formato antigo base64 "3:"/"2:"
    if (bytes.length >= 2 && bytes[1] == 0x3A && (bytes[0] == 0x33 || bytes[0] == 0x32)) {
      final content = utf8.decode(bytes, allowMalformed: true);
      final decrypted = EncryptionService.tryDecrypt(content);
      if (decrypted.isEmpty || decrypted == content) {
        throw Exception(
          'Audio criptografado e app bloqueado. Desbloqueie o PIN para reproduzir.',
        );
      }
      try {
        final resultado = base64Decode(decrypted);
        Log.info('Audio descriptografado (legado): ${resultado.length} bytes');
        _cacheAudioDescriptografado[caminho] = resultado;
        return resultado;
      } catch (_) {
        throw Exception('Falha ao descriptografar o arquivo de audio.');
      }
    }

    // 3) Arquivo nao criptografado
    Log.info('Audio nao criptografado (bytes brutos): ${bytes.length} bytes');
    _cacheAudioDescriptografado[caminho] = bytes;
    return bytes;
  }

  static Future<String> prepararAudioParaPlayback(String caminho) async {
    final bytes = await lerAudioDescriptografado(caminho);
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}/mentall_playback_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
    await tempFile.writeAsBytes(bytes);
    return tempFile.path;
  }

  List<int> _asciiBytes(String value) {
    return ascii.encode(value);
  }

  List<int> _uint16LittleEndian(int value) {
    final data = ByteData(2);
    data.setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  List<int> _uint32LittleEndian(int value) {
    final data = ByteData(4);
    data.setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }
}