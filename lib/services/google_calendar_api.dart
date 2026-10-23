class GoogleCalendarAccount {
  final String email;
  final String? displayName;

  const GoogleCalendarAccount({required this.email, this.displayName});
}

class GoogleCalendarInfo {
  final String id;
  final String summary;
  final bool primary;

  const GoogleCalendarInfo({
    required this.id,
    required this.summary,
    this.primary = false,
  });
}

class GoogleCalendarEventData {
  final String summary;
  final String? location;
  final String? description;
  final DateTime start;
  final DateTime end;
  final Map<String, String> privateProperties;

  const GoogleCalendarEventData({
    required this.summary,
    required this.start,
    required this.end,
    this.location,
    this.description,
    this.privateProperties = const {},
  });
}

class GoogleCalendarAuthRequiredException implements Exception {
  const GoogleCalendarAuthRequiredException();

  @override
  String toString() => 'Autorização do Google Calendar necessária.';
}

class GoogleCalendarHttpException implements Exception {
  final int status;
  final String message;

  const GoogleCalendarHttpException(this.status, this.message);

  @override
  String toString() => 'Google Calendar HTTP $status: $message';
}

abstract class GoogleCalendarApi {
  Future<GoogleCalendarAccount?> currentAccount();

  Future<GoogleCalendarAccount> connect();

  Future<void> disconnect();

  Future<List<GoogleCalendarInfo>> listCalendars();

  Future<String> createEvent(String calendarId, GoogleCalendarEventData data);

  Future<void> updateEvent(
    String calendarId,
    String eventId,
    GoogleCalendarEventData data,
  );

  Future<void> deleteEvent(String calendarId, String eventId);
}
