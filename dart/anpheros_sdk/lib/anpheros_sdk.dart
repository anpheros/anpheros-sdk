/// Anpheros Platform client for Dart and Flutter.
///
/// ```dart
/// final anpheros = Anpheros(auth: AnpherosAuth.apiKey('sk_test_…'));
/// final page = await anpheros.patients.list();
/// final labs = await anpheros.observations.list(page.data.first.id, category: 'laboratory');
/// ```
///
/// For an app acting on behalf of a person, use [AnpherosAuth.oauth] with tokens
/// obtained through [OAuthFlow] (authorization code + PKCE) and the SDK refreshes
/// them for you.
library anpheros_sdk;

export 'src/auth.dart';
export 'src/client.dart';
export 'src/errors.dart';
export 'src/models.dart';
export 'src/oauth.dart';
export 'src/resources.dart';
export 'src/webhook_signature.dart';
