import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'auth.dart';
import 'errors.dart';
import 'resources.dart';

/// Entry point. One instance per credential.
///
/// ```dart
/// final anpheros = Anpheros(auth: AnpherosAuth.apiKey('sk_test_…'));
/// ```
class Anpheros {
  Anpheros({
    required this.auth,
    this.baseUrl = 'https://platform.anpheros.com',
    http.Client? httpClient,
    this.maxRetries = 2,
    this.userAgent = 'anpheros_sdk/0.1.0 dart',
  })  : _http = httpClient ?? http.Client(),
        _rnd = Random() {
    patients = PatientsResource(this);
    observations = ClinicalResource<dynamic>(this, 'observations');
    conditions = ClinicalResource<dynamic>(this, 'conditions');
    medications = ClinicalResource<dynamic>(this, 'medications');
    documents = DocumentsResource(this);
    timeline = TimelineResource(this);
    provenance = ProvenanceResource(this);
    context = ContextResource(this);
    grants = GrantsResource(this);
    me = MeResource(this);
    webhooks = WebhooksResource(this);
    labs = LabsResource(this);
    terminology = TerminologyResource(this);
    fhir = FhirResource(this);
  }

  final AnpherosAuth auth;
  final String baseUrl;
  final int maxRetries;
  final String userAgent;
  final http.Client _http;
  final Random _rnd;

  late final PatientsResource patients;
  late final ClinicalResource observations;
  late final ClinicalResource conditions;
  late final ClinicalResource medications;
  late final DocumentsResource documents;
  late final TimelineResource timeline;
  late final ProvenanceResource provenance;
  late final ContextResource context;
  late final GrantsResource grants;
  late final MeResource me;
  late final WebhooksResource webhooks;
  late final LabsResource labs;
  late final TerminologyResource terminology;
  late final FhirResource fhir;

  /// The request id of the last response, to quote in support requests.
  String? lastRequestId;

  void close() => _http.close();

  /// Low-level call used by every resource. Adds auth, retries on 429/5xx with
  /// backoff, renews OAuth tokens once on 401, and turns errors into
  /// [AnpherosException].
  Future<AnpherosResponse> request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? json,
    List<int>? bytes,
    String? contentType,
    Map<String, String>? headers,
    bool idempotent = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query == null || query.isEmpty ? null : query);
    final idemKey = idempotent ? _uuid() : null;
    var recovered = false;
    for (var attempt = 0;; attempt++) {
      final req = http.Request(method, uri);
      req.headers['Authorization'] = 'Bearer ${await auth.token()}';
      req.headers['Accept'] = 'application/json';
      req.headers['User-Agent'] = userAgent;
      if (idemKey != null) req.headers['Idempotency-Key'] = idemKey;
      if (headers != null) req.headers.addAll(headers);
      if (json != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(json);
      } else if (bytes != null) {
        req.headers['Content-Type'] = contentType ?? 'application/octet-stream';
        req.bodyBytes = bytes;
      }
      http.Response res;
      try {
        res = await http.Response.fromStream(await _http.send(req));
      } catch (e) {
        if (attempt < maxRetries) {
          await _backoff(attempt);
          continue;
        }
        throw AnpherosException(status: 0, type: 'network', message: e.toString());
      }
      lastRequestId = res.headers['anpheros-request-id'];
      if (res.statusCode == 401 && !recovered && await auth.recover()) {
        recovered = true;
        continue;
      }
      if ((res.statusCode == 429 || res.statusCode >= 502) && attempt < maxRetries) {
        await _backoff(attempt, retryAfter: res.headers['retry-after']);
        continue;
      }
      final body = _decode(res);
      if (res.statusCode >= 400) {
        throw AnpherosException.fromResponse(res.statusCode, body, lastRequestId);
      }
      return AnpherosResponse(res.statusCode, body, res.headers, res.bodyBytes);
    }
  }

  Object? _decode(http.Response res) {
    final ct = res.headers['content-type'] ?? '';
    if (res.bodyBytes.isEmpty) return null;
    if (ct.contains('json')) {
      try {
        return jsonDecode(utf8.decode(res.bodyBytes));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _backoff(int attempt, {String? retryAfter}) {
    final ra = int.tryParse(retryAfter ?? '');
    final ms = ra != null ? ra * 1000 : (300 * (1 << attempt)) + _rnd.nextInt(200);
    return Future<void>.delayed(Duration(milliseconds: ms));
  }

  String _uuid() {
    final b = List<int>.generate(16, (_) => _rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}

class AnpherosResponse {
  AnpherosResponse(this.status, this.body, this.headers, this.bytes);
  final int status;
  final Object? body;
  final Map<String, String> headers;
  final List<int> bytes;
  Map<String, dynamic> get json => body as Map<String, dynamic>;
}
