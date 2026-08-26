import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/mentall_colors.dart';
import '../utils/tipografia.dart';

class WhatsAppService {
  WhatsAppService._();

  static const String _pacoteRegular = 'com.whatsapp';
  static const String _pacoteBusiness = 'com.whatsapp.w4b';

  static Future<bool> _abrir({
    required String numero,
    String? texto,
    required bool business,
  }) async {
    final query = (texto != null && texto.isNotEmpty)
        ? '?text=${Uri.encodeComponent(texto)}'
        : '';
    final url = 'https://wa.me/$numero$query';

    // iOS/Web: só há um WhatsApp (sem distinção de pacote)
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return _abrirComUrl(url);
    }

    // Android: intent direcionado ao pacote específico (comum ou Business)
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: url,
        package: business ? _pacoteBusiness : _pacoteRegular,
      );
      await intent.launch();
      return true;
    } catch (_) {
      return _abrirComUrl(url);
    }
  }

  static Future<bool> _abrirComUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Mostra o seletor "WhatsApp / WhatsApp Business" e abre o escolhido.
  ///
  /// Retorna `true` se o app foi aberto, `false` se o usuário cancelou ou
  /// não foi possível abrir.
  static Future<bool> escolher({
    required BuildContext context,
    required String numero,
    String? texto,
    String titulo = 'Abrir com...',
  }) async {
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(
                titulo,
                style: TextStyle(
                  fontSize: Tipografia.base,
                  fontWeight: FontWeight.w600,
                  color: ctx.corTextoMuted,
                ),
              ),
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/logo_whats_grande.png',
                width: 28,
                height: 28,
              ),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(ctx, 'whatsapp'),
            ),
            ListTile(
              leading: Image.asset(
                'assets/images/logo_whats_business.png',
                width: 28,
                height: 28,
              ),
              title: const Text('WhatsApp Business'),
              onTap: () => Navigator.pop(ctx, 'business'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (escolha == null) return false;
    return _abrir(numero: numero, texto: texto, business: escolha == 'business');
  }
}
