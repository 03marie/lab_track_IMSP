import 'package:flutter_test/flutter_test.dart';
import 'package:labtrack/core/api/preferences.dart';

void main() {
  group('normaliserServeur', () {
    test('ajoute le schéma et le port 8000 par défaut', () {
      expect(normaliserServeur('192.168.1.20'), 'http://192.168.1.20:8000');
    });
    test('conserve un port explicite et retire le chemin', () {
      expect(normaliserServeur(' 192.168.1.20:8077/api/ '), 'http://192.168.1.20:8077');
    });
    test('accepte une adresse complète', () {
      expect(normaliserServeur('https://labtrack.imsp.bj:443'), 'https://labtrack.imsp.bj');
      expect(normaliserServeur('http://10.0.0.5:80'), 'http://10.0.0.5');
    });
    test('vide reste vide', () {
      expect(normaliserServeur('   '), '');
    });
  });
}
