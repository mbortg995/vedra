import 'package:flutter_test/flutter_test.dart';
import 'package:vedra/semaforo.dart';
import 'package:vedra/supabase_api.dart';

/// Fake del acceso a datos: un punto en la CV, sin condición diaria, y las
/// reglas que le pasemos. Sirve para probar la lógica del semáforo sin red.
class _FakeApi extends SupabaseApi {
  _FakeApi(this.reglasData);
  final List<Map<String, dynamic>> reglasData;

  @override
  Future<List<Map<String, dynamic>>> territoriosEnPunto(double lat, double lon) async =>
      [
        {'id': 'cv', 'nombre': 'Comunitat Valenciana'}
      ];

  @override
  Future<Map<String, dynamic>?> condicionDiaria(
          List<String> ids, String fecha) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> reglas(
          String actividad, List<String> ids) async =>
      reglasData;
}

Map<String, dynamic> _reglaRequiereLicencia(String tipoId) => {
      'territorio_id': 'cv',
      'capa': 'permanente',
      'efecto': 'requiere',
      'parametros': <String, dynamic>{},
      'detalle': 'Necesitas la licencia de pesca.',
      'fuentes': {'organismo': 'BOE', 'url': null, 'fecha_publicacion': null},
      'regla_requisitos': [
        {'tipo_requisito_id': tipoId}
      ],
    };

void main() {
  test('Regla requiere sin la licencia -> amarillo', () async {
    final api = _FakeApi([_reglaRequiereLicencia('lic-pesca')]);
    final r = await evaluar(api, 'pesca', 39.98, -0.05);
    expect(r.semaforo, 'amarillo');
    expect(r.requisitos, isNotEmpty);
  });

  test('Regla requiere con la licencia declarada -> verde', () async {
    final api = _FakeApi([_reglaRequiereLicencia('lic-pesca')]);
    final r = await evaluar(api, 'pesca', 39.98, -0.05,
        requisitosCumplidos: {'lic-pesca'});
    expect(r.semaforo, 'verde');
    expect(r.requisitos, isEmpty);
  });

  test('Otra licencia distinta no cuenta -> sigue amarillo', () async {
    final api = _FakeApi([_reglaRequiereLicencia('lic-pesca')]);
    final r = await evaluar(api, 'pesca', 39.98, -0.05,
        requisitosCumplidos: {'lic-caza'});
    expect(r.semaforo, 'amarillo');
  });
}
