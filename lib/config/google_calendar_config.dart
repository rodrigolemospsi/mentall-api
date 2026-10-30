import 'package:flutter/foundation.dart' show kReleaseMode;

class GoogleCalendarConfig {
  /// Visibilidade da integração Google Calendar no app.
  ///
  /// Decisão 0.8 (30/10/2026 — opção 1): enquanto a verificação de escopos
  /// sensíveis do Google estiver em análise, os builds de **release** escondem
  /// a integração — ninguém passa pelo aviso "app não verificado" nem consome o
  /// limite vitalício de 100 usuários do projeto OAuth. Depois da aprovação, o
  /// build de loja é gerado com `--dart-define=GOOGLE_CALENDAR_VISIVEL=true`.
  ///
  /// Em debug/profile o padrão é visível, para desenvolvimento e testes.
  static const bool visivel = bool.fromEnvironment(
    'GOOGLE_CALENDAR_VISIVEL',
    defaultValue: !kReleaseMode,
  );

  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '938362319829-r59tc67bbc8h1m82ugtvkpqd8qj64a1d.apps.googleusercontent.com',
  );

  static const String androidClientId = String.fromEnvironment(
    'GOOGLE_ANDROID_CLIENT_ID',
    defaultValue:
        '938362319829-05novcp20p9mmp4utlorg5j6m21c4s5t.apps.googleusercontent.com',
  );

  static const List<String> scopes = [
    'https://www.googleapis.com/auth/calendar.events.owned',
    'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
  ];

  static const String defaultCalendarId = 'primary';
}
