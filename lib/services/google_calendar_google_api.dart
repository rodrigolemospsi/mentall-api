import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../config/google_calendar_config.dart';
import 'google_calendar_api.dart';

class GoogleCalendarGoogleApi implements GoogleCalendarApi {
  Future<void>? _initFuture;
  GoogleSignInAccount? _account;

  Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      serverClientId: GoogleCalendarConfig.serverClientId,
    );
  }

  Future<GoogleSignInAccount?> _currentAccount() async {
    await _ensureInitialized();
    if (_account != null) return _account;

    final future = GoogleSignIn.instance.attemptLightweightAuthentication();
    if (future == null) return null;
    _account = await future;
    return _account;
  }

  Future<GoogleSignInClientAuthorization> _authorization({
    bool prompt = false,
  }) async {
    final account = await _currentAccount();
    if (account == null) {
      throw const GoogleCalendarAuthRequiredException();
    }

    final GoogleSignInClientAuthorization? authorization = prompt
        ? await account.authorizationClient.authorizeScopes(
            GoogleCalendarConfig.scopes,
          )
        : await account.authorizationClient.authorizationForScopes(
            GoogleCalendarConfig.scopes,
          );

    if (authorization == null) {
      throw const GoogleCalendarAuthRequiredException();
    }
    return authorization;
  }

  Future<auth.AuthClient> _client({bool prompt = false}) async {
    final authorization = await _authorization(prompt: prompt);
    return authorization.authClient(scopes: GoogleCalendarConfig.scopes);
  }

  GoogleCalendarAccount _toAccount(GoogleSignInAccount account) {
    return GoogleCalendarAccount(
      email: account.email,
      displayName: account.displayName,
    );
  }

  @override
  Future<GoogleCalendarAccount?> currentAccount() async {
    final account = await _currentAccount();
    return account == null ? null : _toAccount(account);
  }

  @override
  Future<GoogleCalendarAccount> connect() async {
    await _ensureInitialized();

    try {
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        _account = await GoogleSignIn.instance.authenticate(
          scopeHint: GoogleCalendarConfig.scopes,
        );
      } else {
        _account = await _currentAccount();
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleCalendarAuthRequiredException();
      }
      throw GoogleCalendarHttpException(0, e.description ?? e.code.name);
    }

    final account = _account;
    if (account == null) {
      throw const GoogleCalendarAuthRequiredException();
    }

    await _authorization(prompt: true);
    return _toAccount(account);
  }

  @override
  Future<void> disconnect() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
    _account = null;
  }

  @override
  Future<List<GoogleCalendarInfo>> listCalendars() async {
    final client = await _client();
    try {
      final api = CalendarApi(client);
      final list = await api.calendarList.list();
      return (list.items ?? [])
          .where((item) => item.id != null && item.id!.isNotEmpty)
          .map(
            (item) => GoogleCalendarInfo(
              id: item.id!,
              summary: item.summary ?? item.id!,
              primary: item.primary ?? false,
            ),
          )
          .toList();
    } on DetailedApiRequestError catch (e) {
      throw GoogleCalendarHttpException(e.status ?? 0, e.message ?? 'Erro');
    } finally {
      client.close();
    }
  }

  @override
  Future<String> createEvent(
    String calendarId,
    GoogleCalendarEventData data,
  ) async {
    final client = await _client();
    try {
      final api = CalendarApi(client);
      final created = await api.events.insert(
        _toEvent(data),
        calendarId,
        sendUpdates: 'none',
      );
      if (created.id == null || created.id!.isEmpty) {
        throw const GoogleCalendarHttpException(
          0,
          'Evento criado sem ID retornado.',
        );
      }
      return created.id!;
    } on DetailedApiRequestError catch (e) {
      throw GoogleCalendarHttpException(e.status ?? 0, e.message ?? 'Erro');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> updateEvent(
    String calendarId,
    String eventId,
    GoogleCalendarEventData data,
  ) async {
    final client = await _client();
    try {
      final api = CalendarApi(client);
      await api.events.update(
        _toEvent(data),
        calendarId,
        eventId,
        sendUpdates: 'none',
      );
    } on DetailedApiRequestError catch (e) {
      throw GoogleCalendarHttpException(e.status ?? 0, e.message ?? 'Erro');
    } finally {
      client.close();
    }
  }

  @override
  Future<void> deleteEvent(String calendarId, String eventId) async {
    final client = await _client();
    try {
      final api = CalendarApi(client);
      await api.events.delete(calendarId, eventId, sendUpdates: 'none');
    } on DetailedApiRequestError catch (e) {
      throw GoogleCalendarHttpException(e.status ?? 0, e.message ?? 'Erro');
    } finally {
      client.close();
    }
  }

  Event _toEvent(GoogleCalendarEventData data) {
    return Event(
      summary: data.summary,
      location: data.location,
      description: data.description,
      status: 'confirmed',
      start: EventDateTime(dateTime: data.start.toUtc(), timeZone: 'UTC'),
      end: EventDateTime(dateTime: data.end.toUtc(), timeZone: 'UTC'),
      extendedProperties: EventExtendedProperties(
        private: data.privateProperties,
      ),
    );
  }
}
