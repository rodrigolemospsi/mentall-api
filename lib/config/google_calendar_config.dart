class GoogleCalendarConfig {
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
