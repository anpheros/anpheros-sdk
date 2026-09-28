// Server-side use with a project key: list patients and read a patient's labs.
import 'package:anpheros_sdk/anpheros_sdk.dart';

Future<void> main() async {
  final anpheros = Anpheros(auth: AnpherosAuth.apiKey('sk_test_…'));
  final page = await anpheros.patients.list(limit: 5);
  for (final p in page.data) {
    final labs = await anpheros.observations.list(p.id, category: 'laboratory', limit: 3);
    print('${p.given} ${p.family}: ${labs.data.length} lab results');
  }
  anpheros.close();
}
