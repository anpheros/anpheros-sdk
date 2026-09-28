import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Verifies the `Anpheros-Signature` header of a webhook delivery.
///
/// ```dart
/// if (!verifyWebhookSignature(secret: secret, header: req.headers['anpheros-signature'], body: rawBodyBytes)) {
///   return Response(400);
/// }
/// ```
/// `t` in the header is the Unix time of the delivery; deliveries older than
/// [tolerance] are rejected so a captured request cannot be replayed later.
bool verifyWebhookSignature({
  required String secret,
  required String? header,
  required List<int> body,
  Duration tolerance = const Duration(minutes: 5),
  DateTime? now,
}) {
  if (header == null || header.isEmpty) return false;
  final parts = <String, String>{};
  for (final p in header.split(',')) {
    final i = p.indexOf('=');
    if (i > 0) parts[p.substring(0, i).trim()] = p.substring(i + 1).trim();
  }
  final ts = int.tryParse(parts['t'] ?? '');
  final given = parts['v1'];
  if (ts == null || given == null) return false;
  final at = (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 1000;
  if ((at - ts).abs() > tolerance.inSeconds) return false;
  final expected = Hmac(sha256, utf8.encode(secret)).convert([...utf8.encode('$ts.'), ...body]).toString();
  if (expected.length != given.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= expected.codeUnitAt(i) ^ given.codeUnitAt(i);
  }
  return diff == 0;
}
