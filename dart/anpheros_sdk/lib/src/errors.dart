/// Errors raised by the SDK. Every server error carries the platform's error type,
/// the human message, the offending field when known and the request id to quote
/// when writing to support.
class AnpherosException implements Exception {
  AnpherosException({
    required this.status,
    required this.type,
    required this.message,
    this.field,
    this.requestId,
    this.body,
  });

  /// HTTP status (0 when the request never reached the server).
  final int status;

  /// Platform error type: `invalid`, `not-found`, `forbidden`, `login`, `conflict`,
  /// `throttled`, `structure`, `exception`, `network`, …
  final String type;
  final String message;
  final String? field;
  final String? requestId;

  /// Raw response body, when any.
  final Object? body;

  bool get isUnauthorized => status == 401;
  bool get isForbidden => status == 403;
  bool get isNotFound => status == 404;
  bool get isRateLimited => status == 429;
  bool get isRetryable => status == 429 || status == 502 || status == 503 || status == 504 || status == 0;

  /// Builds an exception from a JSON body in either the `/v1` shape
  /// (`{"error": {...}}`) or the FHIR `OperationOutcome` shape.
  factory AnpherosException.fromResponse(int status, Object? body, String? requestId) {
    String type = 'error';
    String message = 'HTTP $status';
    String? field;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        type = (err['type'] ?? type).toString();
        message = (err['message'] ?? message).toString();
        field = err['field']?.toString();
      } else if (body['resourceType'] == 'OperationOutcome') {
        final issues = body['issue'];
        if (issues is List && issues.isNotEmpty && issues.first is Map) {
          final first = issues.first as Map;
          type = (first['code'] ?? type).toString();
          message = (first['diagnostics'] ?? message).toString();
          final expr = first['expression'];
          if (expr is List && expr.isNotEmpty) field = expr.first.toString();
        }
      } else if (body['error'] is String) {
        // OAuth error shape
        type = body['error'] as String;
        message = (body['error_description'] ?? message).toString();
      }
    }
    return AnpherosException(status: status, type: type, message: message, field: field, requestId: requestId, body: body);
  }

  @override
  String toString() => 'AnpherosException($status $type: $message${field != null ? ' at $field' : ''}${requestId != null ? ', request $requestId' : ''})';
}
