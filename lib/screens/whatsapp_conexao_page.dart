import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/wuzapi_service.dart';
import '../utils/mentall_colors.dart';
import '../utils/raio.dart';
import '../utils/telefone_whatsapp.dart';
import '../utils/tipografia.dart';

/// Conecta o WhatsApp do profissional (via wuzapi) e mostra se está funcionando.
///
/// A vinculação usa **código de pareamento** (funciona no mesmo celular); o QR
/// Code é a alternativa para quem vai escanear de outro aparelho.
class WhatsappConexaoPage extends StatefulWidget {
  const WhatsappConexaoPage({super.key});

  @override
  State<WhatsappConexaoPage> createState() => _WhatsappConexaoPageState();
}

class _WhatsappConexaoPageState extends State<WhatsappConexaoPage> {
  final _numeroController = TextEditingController();

  bool _carregando = true;
  bool _processando = false;
  Map<String, dynamic> _status = const {};
  String? _codigo;
  String? _qrCode;
  String? _erro;
  String? _numeroAutoPreenchido;

  bool get _logado => _status['logado'] == true;

  String get _numero {
    final digitado = _numeroController.text.trim();
    if (digitado.isNotEmpty) return digitado;
    return (_status['numero'] ?? '').toString();
  }

  @override
  void initState() {
    super.initState();
    _carregarStatus();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    super.dispose();
  }

  Future<void> _carregarStatus() async {
    setState(() => _carregando = true);
    final r = await WuzapiService.status();
    if (!mounted) return;
    setState(() {
      _carregando = false;
      if (r['sucesso'] == true) {
        _status = r;
        _erro = null;
        _sincronizarCampoNumero();
      } else {
        _erro = (r['erro'] ?? '').toString();
      }
    });
  }

  /// Preenche o campo com o número já conectado (e limpa ao desconectar),
  /// sem sobrescrever um número que o usuário tenha digitado manualmente.
  void _sincronizarCampoNumero() {
    final numeroConectado =
        formatarNumeroWhatsapp((_status['numero'] ?? '').toString());
    final digitado = _numeroController.text.trim();
    if (_logado && numeroConectado.isNotEmpty && digitado.isEmpty) {
      _numeroController.text = numeroConectado;
      _numeroAutoPreenchido = numeroConectado;
      return;
    }
    if (!_logado &&
        _numeroAutoPreenchido != null &&
        digitado == _numeroAutoPreenchido) {
      _numeroController.clear();
      _numeroAutoPreenchido = null;
    }
  }

  Future<void> _gerarCodigo() async {
    if (_numero.isEmpty) {
      _mostrar('Informe o número do WhatsApp.');
      return;
    }
    setState(() {
      _processando = true;
      _erro = null;
      _qrCode = null;
    });
    final r = await WuzapiService.parear(_numero);
    if (!mounted) return;
    setState(() {
      _processando = false;
      if (r['sucesso'] == true) {
        _codigo = (r['codigo'] ?? '').toString();
      } else {
        _erro = (r['erro'] ?? '').toString();
      }
    });
    if (_erro != null) _mostrar(_erro!);
  }

  Future<void> _carregarQr() async {
    setState(() {
      _processando = true;
      _codigo = null;
      _erro = null;
    });
    final r = await WuzapiService.qr();
    if (!mounted) return;
    setState(() {
      _processando = false;
      if (r['sucesso'] == true) {
        _qrCode = (r['qr_code'] ?? '').toString();
      } else {
        _erro = (r['erro'] ?? '').toString();
      }
    });
  }

  Future<void> _testar() async {
    if (_numero.isEmpty) {
      _mostrar('Informe o número do WhatsApp.');
      return;
    }
    setState(() => _processando = true);
    final r = await WuzapiService.testar(_numero);
    if (!mounted) return;
    setState(() => _processando = false);
    _mostrar(
      r['sucesso'] == true
          ? 'Mensagem de teste enviada.'
          : (r['erro'] ?? 'Falha ao enviar a mensagem de teste.').toString(),
    );
  }

  Future<void> _desconectar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desconectar o WhatsApp?'),
        content: const Text(
          'Os lembretes automáticos deixarão de ser enviados até que você '
          'conecte novamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Desconectar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;

    setState(() => _processando = true);
    await WuzapiService.desconectar(logout: true);
    if (!mounted) return;
    setState(() {
      _processando = false;
      _codigo = null;
      _qrCode = null;
    });
    _mostrar('WhatsApp desconectado.');
    await _carregarStatus();
  }

  void _mostrar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.corFundo,
      appBar: AppBar(
        title: const Text('WhatsApp dos lembretes'),
        actions: [
          IconButton(
            tooltip: 'Atualizar status',
            onPressed: _carregando || _processando ? null : _carregarStatus,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _cardStatus(context),
                const SizedBox(height: 16),
                Text(
                  'Número do WhatsApp',
                  style: TextStyle(
                    fontSize: Tipografia.smMd,
                    fontWeight: FontWeight.w600,
                    color: context.corTextoBody,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _numeroController,
                  enabled: !_processando,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '(11) 99999-9999',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                if (_processando)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  if (_logado) ...[
                    FilledButton.icon(
                      onPressed: _testar,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Enviar mensagem de teste'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _desconectar,
                      icon: const Icon(Icons.link_off),
                      label: const Text('Desconectar'),
                    ),
                  ] else ...[
                    FilledButton.icon(
                      onPressed: _gerarCodigo,
                      icon: const Icon(Icons.dialpad),
                      label: const Text('Gerar código de pareamento'),
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: _carregarQr,
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Usar QR Code'),
                    ),
                  ],
                ],
                if (_codigo != null) ...[
                  const SizedBox(height: 8),
                  _cardCodigo(context, _codigo!),
                ],
                if (_qrCode != null) ...[
                  const SizedBox(height: 8),
                  _cardQr(context, _qrCode!),
                ],
                if (_erro != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _erro!,
                    style: TextStyle(color: context.corError, fontSize: Tipografia.smMd),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _cardStatus(BuildContext context) {
    final cor = _logado ? context.corSuccess : context.corWarning;
    final numero = formatarNumeroWhatsapp((_status['numero'] ?? '').toString());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Raio.lg),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            _logado ? Icons.check_circle_outline : Icons.error_outline,
            color: cor,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _logado ? 'Conectado' : 'Desconectado',
                  style: TextStyle(
                    fontSize: Tipografia.md,
                    fontWeight: FontWeight.bold,
                    color: cor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _logado
                      ? 'Os lembretes automáticos estão sendo enviados pelo seu WhatsApp.'
                      : 'Conecte seu WhatsApp para enviar lembretes automáticos.',
                  style: TextStyle(
                    fontSize: Tipografia.smMd,
                    color: context.corTextoSecondary,
                  ),
                ),
                if (_logado && numero.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    numero,
                    style: TextStyle(
                      fontSize: Tipografia.sm,
                      color: context.corTextoMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardCodigo(BuildContext context, String codigo) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.corCard,
        borderRadius: BorderRadius.circular(Raio.lg),
        border: context.corCardBorda,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Código de pareamento',
            style: TextStyle(
              fontSize: Tipografia.base,
              fontWeight: FontWeight.w600,
              color: context.corTextoBody,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            codigo,
            style: TextStyle(
              fontSize: Tipografia.xxl,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: context.corPrimaria,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No WhatsApp do celular: toque em Aparelhos conectados → '
            'Vincular com número de telefone e digite o código acima. '
            'Depois toque em "Atualizar status".',
            style: TextStyle(
              fontSize: Tipografia.sm,
              color: context.corTextoSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _carregarStatus,
              icon: const Icon(Icons.refresh),
              label: const Text('Verificar conexão'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardQr(BuildContext context, String dataUri) {
    final base64Data = dataUri.contains(',') ? dataUri.split(',').last : dataUri;
    Uint8List? bytes;
    try {
      bytes = base64Decode(base64Data);
    } catch (_) {
      bytes = null;
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.corCard,
        borderRadius: BorderRadius.circular(Raio.lg),
        border: context.corCardBorda,
      ),
      child: Column(
        children: [
          Text(
            'Escaneie o QR Code com o WhatsApp (Aparelhos conectados)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: Tipografia.sm, color: context.corTextoSecondary),
          ),
          const SizedBox(height: 12),
          if (bytes != null)
            Image.memory(bytes, width: 220, height: 220, fit: BoxFit.contain)
          else
            Text(
              'QR Code indisponível.',
              style: TextStyle(color: context.corError, fontSize: Tipografia.sm),
            ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _carregarStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Verificar conexão'),
          ),
        ],
      ),
    );
  }
}
