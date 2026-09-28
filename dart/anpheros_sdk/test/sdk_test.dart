import 'dart:convert';

import 'package:anpheros_sdk/anpheros_sdk.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A fake platform: records requests, answers from a script.
class Fake {
  final List<http.Request> requests = [];
  final List<http.Response Function(http.Request)> script = [];
  int calls = 0;

  MockClient get client => MockClient((req) async {
        requests.add(req);
        final handler = script.isEmpty ? null : script[calls < script.length ? calls : script.length - 1];
        calls++;
        return handler == null ? http.Response('{}', 200, headers: {'content-type': 'application/json'}) : handler(req);
      });

  static http.Response json(Object body, {int status = 200, Map<String, String>? headers}) => http.Response(jsonEncode(body), status,
      headers: {'content-type': 'application/json', 'anpheros-request-id': 'req-1', ...?headers});
}

void main() {
  group('client', () {
    test('sends the key, parses pages and models', () async {
      final fake = Fake()
        ..script.add((_) => Fake.json({
              'data': [
                {'id': 'p1', 'given': 'Elena', 'family': 'Ionescu', 'birth_date': '1985-09-03', 'gender': 'female', 'identifiers': [], 'fhir': 'Patient/p1'}
              ],
              'total': 5,
              'next_cursor': 'NTA'
            }));
      final a = Anpheros(auth: AnpherosAuth.apiKey('sk_test_x'), baseUrl: 'https://api.test', httpClient: fake.client);
      final page = await a.patients.list(limit: 1);
      expect(fake.requests.single.headers['Authorization'], 'Bearer sk_test_x');
      expect(fake.requests.single.url.toString(), 'https://api.test/v1/patients?limit=1');
      expect(page.total, 5);
      expect(page.hasMore, isTrue);
      expect(page.data.single.displayName, 'Elena Ionescu');
      expect(a.lastRequestId, 'req-1');
    });

    test('creates with Idempotency-Key and author headers', () async {
      final fake = Fake()
        ..script.add((req) => Fake.json({
              'id': 'o1', 'patient': 'p1', 'code': '2339-0', 'category': 'laboratory', 'effective_at': '2026-09-19T08:10:00Z', 'value': 112.0,
              'unit': 'mg/dL', 'components': [], 'derived_from': [], 'fhir': 'Observation/o1'
            }, status: 201));
      final a = Anpheros(auth: AnpherosAuth.apiKey('sk_test_x'), baseUrl: 'https://api.test', httpClient: fake.client);
      final obs = await a.observations.createObservation(
          'p1',
          ObservationInput(code: '2339-0', category: 'laboratory', effectiveAt: DateTime.utc(2026, 9, 19, 8, 10), value: 112, unit: 'mg/dL', authorType: AuthorType.device),
          sourceSystem: 'glucometer');
      final req = fake.requests.single;
      expect(req.method, 'POST');
      expect(req.headers['Idempotency-Key'], hasLength(36));
      expect(req.headers['X-Anpheros-Source-System'], 'glucometer');
      final sent = jsonDecode(req.body) as Map<String, dynamic>;
      expect(sent['author_type'], 'device');
      expect(sent['effective_at'], '2026-09-19T08:10:00.000Z');
      expect(obs.value, 112.0);
      expect(obs.fhir, 'Observation/o1');
    });

    test('turns v1 and FHIR errors into AnpherosException', () async {
      final fake = Fake()
        ..script.add((_) => Fake.json({'error': {'type': 'invalid', 'message': 'given is required', 'field': 'given'}}, status: 400))
        ..script.add((_) => Fake.json({'resourceType': 'OperationOutcome', 'issue': [{'severity': 'error', 'code': 'not-found', 'diagnostics': 'Patient/x does not exist.'}]}, status: 404));
      final a = Anpheros(auth: AnpherosAuth.apiKey('sk_test_x'), baseUrl: 'https://api.test', httpClient: fake.client, maxRetries: 0);
      await expectLater(a.patients.create(const PatientInput(given: '', family: 'x')),
          throwsA(isA<AnpherosException>().having((e) => e.field, 'field', 'given').having((e) => e.status, 'status', 400)));
      await expectLater(a.fhir.read('Patient', 'x'), throwsA(isA<AnpherosException>().having((e) => e.isNotFound, 'notFound', isTrue).having((e) => e.type, 'type', 'not-found')));
    });

    test('retries on 429 then succeeds', () async {
      final fake = Fake()
        ..script.add((_) => Fake.json({'error': {'type': 'throttled', 'message': 'slow down'}}, status: 429, headers: {'retry-after': '0'}))
        ..script.add((_) => Fake.json({'data': [], 'total': 0, 'next_cursor': null}));
      final a = Anpheros(auth: AnpherosAuth.apiKey('sk_test_x'), baseUrl: 'https://api.test', httpClient: fake.client);
      final page = await a.patients.list();
      expect(fake.requests, hasLength(2));
      expect(page.total, 0);
    });

    test('refreshes an OAuth token once on 401 and retries', () async {
      var refreshed = 0;
      final fake = Fake()
        ..script.add((_) => Fake.json({'error': {'type': 'login', 'message': 'expired'}}, status: 401))
        ..script.add((_) => Fake.json({'data': [], 'total': 0, 'next_cursor': null}));
      final auth = AnpherosAuth.oauth(
        accessToken: 'at_old',
        refreshToken: 'rt_1',
        onRefresh: (rt) async {
          refreshed++;
          return OAuthTokens(accessToken: 'at_new', refreshToken: 'rt_2', expiresIn: 1800);
        },
      );
      final a = Anpheros(auth: auth, baseUrl: 'https://api.test', httpClient: fake.client);
      await a.patients.list();
      expect(refreshed, 1);
      expect(fake.requests[0].headers['Authorization'], 'Bearer at_old');
      expect(fake.requests[1].headers['Authorization'], 'Bearer at_new');
      expect((auth as OAuthTokenAuth).refreshToken, 'rt_2');
    });

    test('listAll walks every page', () async {
      final fake = Fake()
        ..script.add((_) => Fake.json({'data': [{'id': 'a', 'fhir': 'Patient/a', 'identifiers': []}], 'total': 2, 'next_cursor': 'x'}))
        ..script.add((_) => Fake.json({'data': [{'id': 'b', 'fhir': 'Patient/b', 'identifiers': []}], 'total': 2, 'next_cursor': null}));
      final a = Anpheros(auth: AnpherosAuth.apiKey('sk_test_x'), baseUrl: 'https://api.test', httpClient: fake.client);
      final ids = await a.patients.listAll().map((p) => p.id).toList();
      expect(ids, ['a', 'b']);
      expect(fake.requests[1].url.queryParameters['cursor'], 'x');
    });
  });

  group('me (patient API)', () {
    test('lists my records, grants with counts, the access log and revokes', () async {
      final calls = <String>[];
      final mock = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}?${req.url.query} auth=${req.headers['authorization']}');
        if (req.url.path == '/me/patients') {
          return http.Response(jsonEncode({'data': [{'id': 'p1', 'given': 'Ana', 'family': 'Pop', 'birth_date': '1990-01-01', 'relationship': 'self'}]}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/grants')) {
          return http.Response(jsonEncode({'data': [{'id': 'g1', 'status': 'active', 'purpose': 'care', 'scopes': ['patient/Observation.r'], 'scopes_text': ['Citește analizele'],
                'granted_at': '2026-09-01T00:00:00Z', 'expires_at': null, 'revoked_at': null, 'granted_by': 'patient', 'consent': null,
                'application': {'id': 'app_1', 'name': 'Clinica X', 'kind': 'confidential', 'organization': 'X SRL', 'privacy_url': 'https://x/privacy'},
                'access_count': 3, 'last_access_at': '2026-09-18T10:00:00Z'}]}), 200, headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/access-log')) {
          return http.Response(jsonEncode({'data': [{'ts': '2026-09-18T10:00:00Z', 'action': 'search', 'resource_type': 'Observation', 'resource_id': null, 'status': 'ok'}]}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/revoke')) {
          return http.Response(jsonEncode({'id': 'g1', 'status': 'revoked', 'scopes': [], 'scopes_text': [], 'granted_by': 'patient', 'revoked_at': '2026-09-19T00:00:00Z'}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('{}', 404);
      });
      final c = Anpheros(baseUrl: 'https://p', auth: AnpherosAuth.bearer('firebase-id-token'), httpClient: mock);
      final mine = await c.me.patients();
      expect(mine.single.displayName, 'Ana Pop');
      final grants = await c.me.grants('p1', lang: 'ro');
      expect(grants.single.organization, 'X SRL');
      expect(grants.single.accessCount, 3);
      expect(grants.single.byCreator, isFalse);
      final log = await c.me.accessLog('p1', 'g1');
      expect(log.single.resourceType, 'Observation');
      final revoked = await c.me.revoke('p1', 'g1', reason: 'patient');
      expect(revoked.status, 'revoked');
      expect(calls.first, contains('auth=Bearer firebase-id-token'));
      expect(calls[1], contains('lang=ro'));
    });
  });

  group('webhooks', () {
    test('creates, lists, pings, reads deliveries and verifies signatures', () async {
      final calls = <String>[];
      final mock = MockClient((req) async {
        calls.add('${req.method} ${req.url.path}${req.url.query.isEmpty ? '' : '?${req.url.query}'}');
        if (req.method == 'POST' && req.url.path == '/v1/webhooks') {
          return http.Response(jsonEncode({'id': 'whe_1', 'url': 'https://x/hook', 'events': ['*'], 'active': true, 'environment': 'sandbox', 'secret': 'whsec_abc'}), 201,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/ping')) {
          return http.Response(jsonEncode({'id': 'whd_1', 'endpoint_id': 'whe_1', 'event_id': 'evt_1', 'event_type': 'ping', 'status': 'delivered', 'attempts': 1, 'payload': {}}), 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path.endsWith('/deliveries')) {
          return http.Response(jsonEncode({'data': [{'id': 'whd_1', 'endpoint_id': 'whe_1', 'event_id': 'evt_1', 'event_type': 'resource.created', 'status': 'failed', 'attempts': 2, 'last_status_code': 500, 'payload': {'type': 'resource.created'}}]}), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode({'data': []}), 200, headers: {'content-type': 'application/json'});
      });
      final c = Anpheros(baseUrl: 'https://p', auth: AnpherosAuth.apiKey('sk_test_x'), httpClient: mock);
      final ep = await c.webhooks.create('https://x/hook', events: ['*']);
      expect(ep.secret, 'whsec_abc');
      expect((await c.webhooks.ping(ep.id)).status, 'delivered');
      final log = await c.webhooks.deliveries(ep.id, status: 'failed');
      expect(log.single.lastStatusCode, 500);
      expect(calls.last, 'GET /v1/webhooks/whe_1/deliveries?status=failed&limit=50');
      // semnătura: t=<unix>,v1=<hmac sha256 over "<t>.<body>">
      final body = utf8.encode('{"a":1}');
      final ts = DateTime.utc(2026, 9, 19, 12).millisecondsSinceEpoch ~/ 1000;
      final sig = Hmac(sha256, utf8.encode('whsec_abc')).convert([...utf8.encode('$ts.'), ...body]).toString();
      final header = 't=$ts,v1=$sig';
      final at = DateTime.utc(2026, 9, 19, 12, 1);
      expect(verifyWebhookSignature(secret: 'whsec_abc', header: header, body: body, now: at), isTrue);
      expect(verifyWebhookSignature(secret: 'whsec_other', header: header, body: body, now: at), isFalse);
      expect(verifyWebhookSignature(secret: 'whsec_abc', header: header, body: body, now: at.add(const Duration(minutes: 10))), isFalse);
    });
  });

  group('oauth', () {
    test('builds the authorize url with PKCE and exchanges the code', () async {
      final fake = Fake()..script.add((_) => Fake.json({'access_token': 'at_1', 'refresh_token': 'rt_1', 'expires_in': 1800, 'scope': 'patient/*.r', 'patient': 'pw', 'grant_id': 'grant_1'}));
      final flow = OAuthFlow(baseUrl: 'https://api.test', clientId: 'client_1', redirectUri: 'app://cb', httpClient: fake.client);
      final pkce = Pkce.generate();
      final url = flow.authorizeUrl(scopes: ['patient/Observation.rs?category=laboratory', 'offline_access'], state: 's', pkce: pkce, lang: 'ro', purpose: 'treatment');
      expect(url.path, '/oauth/authorize');
      expect(url.queryParameters['code_challenge'], pkce.challenge);
      expect(url.queryParameters['scope'], 'patient/Observation.rs?category=laboratory offline_access');
      final tokens = await flow.exchange(code: 'c', pkce: pkce);
      expect(fake.requests.single.bodyFields['code_verifier'], pkce.verifier);
      expect(fake.requests.single.bodyFields['grant_type'], 'authorization_code');
      expect(tokens.patient, 'pw');
      expect(tokens.expiresAt.isAfter(DateTime.now()), isTrue);
    });

    test('identity exchange for first-party apps', () async {
      final fake = Fake()..script.add((_) => Fake.json({'access_token': 'at_1', 'expires_in': 1800, 'patient': 'pw'}));
      final flow = OAuthFlow(baseUrl: 'https://api.test', clientId: 'client_1', redirectUri: 'app://cb', httpClient: fake.client);
      await flow.exchangeIdentity('firebase-id-token');
      expect(fake.requests.single.bodyFields['grant_type'], 'urn:anpheros:params:oauth:grant-type:identity');
      expect(fake.requests.single.bodyFields['subject_token'], 'firebase-id-token');
    });
  });
}
