import 'dart:async';

/// How the client authenticates.
///
/// * [AnpherosAuth.apiKey] — a project key (`sk_test_…` / `sk_live_…`), for servers.
/// * [AnpherosAuth.oauth] — tokens obtained with a person's consent; give it an
///   `onRefresh` callback and the SDK renews the access token when it expires.
/// * [AnpherosAuth.bearer] — any static bearer token (tests, short scripts).
abstract class AnpherosAuth {
  const AnpherosAuth();

  factory AnpherosAuth.apiKey(String key) = _ApiKeyAuth;
  factory AnpherosAuth.bearer(String token) = _BearerAuth;
  factory AnpherosAuth.oauth({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    Future<OAuthTokens> Function(String refreshToken)? onRefresh,
    void Function(OAuthTokens tokens)? onTokens,
  }) = OAuthTokenAuth;

  /// The current bearer token, refreshing first when needed.
  Future<String> token();

  /// Called after a 401 so a refreshable auth can renew once and let the caller retry.
  Future<bool> recover() async => false;
}

class _ApiKeyAuth extends AnpherosAuth {
  const _ApiKeyAuth(this.key);
  final String key;
  @override
  Future<String> token() async => key;
}

class _BearerAuth extends AnpherosAuth {
  const _BearerAuth(this.value);
  final String value;
  @override
  Future<String> token() async => value;
}

/// Tokens as returned by the token endpoint.
class OAuthTokens {
  OAuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresIn,
    this.scope,
    this.patient,
    this.grantId,
    DateTime? obtainedAt,
  }) : obtainedAt = obtainedAt ?? DateTime.now();

  final String accessToken;
  final String? refreshToken;
  final int expiresIn;
  final String? scope;

  /// The patient id your application sees for this person (pairwise).
  final String? patient;
  final String? grantId;
  final DateTime obtainedAt;

  DateTime get expiresAt => obtainedAt.add(Duration(seconds: expiresIn));

  factory OAuthTokens.fromJson(Map<String, dynamic> json) => OAuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String?,
        expiresIn: (json['expires_in'] as num?)?.toInt() ?? 1800,
        scope: json['scope'] as String?,
        patient: json['patient'] as String?,
        grantId: json['grant_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        if (refreshToken != null) 'refresh_token': refreshToken,
        'expires_in': expiresIn,
        if (scope != null) 'scope': scope,
        if (patient != null) 'patient': patient,
        if (grantId != null) 'grant_id': grantId,
        'obtained_at': obtainedAt.toIso8601String(),
      };
}

/// OAuth tokens with automatic refresh.
class OAuthTokenAuth extends AnpherosAuth {
  OAuthTokenAuth({
    required String accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    this.onRefresh,
    this.onTokens,
  })  : _accessToken = accessToken,
        _refreshToken = refreshToken,
        _expiresAt = expiresAt;

  String _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;
  Future<OAuthTokens>? _inflight;

  /// Exchanges a refresh token for new tokens (typically `OAuthFlow.refresh`).
  final Future<OAuthTokens> Function(String refreshToken)? onRefresh;

  /// Called whenever tokens change, so the app can persist them.
  final void Function(OAuthTokens tokens)? onTokens;

  String get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get _expiringSoon => _expiresAt != null && DateTime.now().isAfter(_expiresAt!.subtract(const Duration(seconds: 60)));

  @override
  Future<String> token() async {
    if (_expiringSoon && _refreshToken != null && onRefresh != null) {
      await _refresh();
    }
    return _accessToken;
  }

  @override
  Future<bool> recover() async {
    if (_refreshToken == null || onRefresh == null) return false;
    try {
      await _refresh();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh() async {
    _inflight ??= onRefresh!(_refreshToken!).whenComplete(() => _inflight = null);
    final tokens = await _inflight!;
    _accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken ?? _refreshToken;
    _expiresAt = tokens.expiresAt;
    onTokens?.call(tokens);
  }
}
