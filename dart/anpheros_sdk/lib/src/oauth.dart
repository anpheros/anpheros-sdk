import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import 'auth.dart';
import 'errors.dart';

/// PKCE verifier/challenge pair for the authorization code flow.
class Pkce {
  Pkce._(this.verifier, this.challenge);

  final String verifier;
  final String challenge;

  factory Pkce.generate() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(48, (_) => rnd.nextInt(256));
    final verifier = base64UrlEncode(bytes).replaceAll('=', '');
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(verifier)).bytes).replaceAll('=', '');
    return Pkce._(verifier, challenge);
  }
}

/// The consent flow for applications acting on behalf of a person
/// (OAuth 2.1 authorization code + PKCE, SMART on FHIR scopes).
///
/// ```dart
/// final flow = OAuthFlow(baseUrl: 'https://…', clientId: 'client_…', redirectUri: 'myapp://callback');
/// final pkce = Pkce.generate();
/// final url = flow.authorizeUrl(scopes: ['patient/Observation.rs?category=laboratory', 'offline_access'],
///                               state: 'abc', pkce: pkce, lang: 'ro');
/// // open `url` in a browser; when it comes back with ?code=…&state=…:
/// final tokens = await flow.exchange(code: code, pkce: pkce);
/// ```
class OAuthFlow {
  OAuthFlow({required this.baseUrl, required this.clientId, required this.redirectUri, this.clientSecret, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String baseUrl;
  final String clientId;
  final String redirectUri;

  /// Only for confidential (server-side) clients. Never ship it in an app.
  final String? clientSecret;
  final http.Client _http;

  Uri authorizeUrl({
    required List<String> scopes,
    required String state,
    required Pkce pkce,
    String? purpose,
    String? patient,
    String lang = 'en',
  }) =>
      Uri.parse('$baseUrl/oauth/authorize').replace(queryParameters: {
        'response_type': 'code',
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'scope': scopes.join(' '),
        'state': state,
        'code_challenge': pkce.challenge,
        'code_challenge_method': 'S256',
        if (purpose != null) 'purpose': purpose,
        if (patient != null) 'patient': patient,
        'lang': lang,
      });

  Future<OAuthTokens> exchange({required String code, required Pkce pkce}) => _token({
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': pkce.verifier,
        'redirect_uri': redirectUri,
      });

  Future<OAuthTokens> refresh(String refreshToken) => _token({'grant_type': 'refresh_token', 'refresh_token': refreshToken});

  /// Server-to-server access as the project (confidential clients only).
  Future<OAuthTokens> clientCredentials({List<String> scopes = const ['read', 'write']}) =>
      _token({'grant_type': 'client_credentials', 'scope': scopes.join(' ')});

  /// First-party apps whose users sign in with Anpheros identity: turn the person's
  /// Firebase ID token into platform tokens for their own record (trusted clients only).
  /// Pass [patient] (a pairwise id) to get tokens for a dependent's record instead of the person's own.
  Future<OAuthTokens> exchangeIdentity(String firebaseIdToken, {List<String> scopes = const ['patient/*.cruds', 'offline_access'], String? patient}) =>
      _token({
        'grant_type': 'urn:anpheros:params:oauth:grant-type:identity',
        'subject_token': firebaseIdToken,
        'scope': scopes.join(' '),
        if (patient != null) 'patient': patient,
      });

  Future<void> revoke(String token) async {
    await _http.post(Uri.parse('$baseUrl/oauth/revoke'), body: {
      'token': token,
      'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret!,
    });
  }

  Future<OAuthTokens> _token(Map<String, String> form) async {
    final res = await _http.post(Uri.parse('$baseUrl/oauth/token'), body: {
      ...form,
      'client_id': clientId,
      if (clientSecret != null) 'client_secret': clientSecret!,
    });
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw AnpherosException.fromResponse(res.statusCode, body, res.headers['anpheros-request-id']);
    }
    return OAuthTokens.fromJson(body as Map<String, dynamic>);
  }
}
