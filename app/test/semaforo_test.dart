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
          List<Map<String, dynamic>> cadena, String fecha) async =>
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

Map<String, dynamic> _reglaLimita(String detalle, String? vigencia) => {
      'territorio_id': 'cv',
      'capa': 'estacional',
      'efecto': 'limita',
      'parametros': <String, dynamic>{},
      'detalle': detalle,
      'vigencia': vigencia,
      'fuentes': {'organismo': 'GVA', 'url': null, 'fecha_publicacion': null},
      'regla_requisitos': const [],
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

  group('Preemergencia conservadora (interino #18)', () {
    test('masRestrictiva elige el nivel más alto entre las zonas', () {
      final r = SupabaseApi.masRestrictiva([
        {'nivel': '1', 'obtenido_en': 'a'},
        {'nivel': '3', 'obtenido_en': 'b'},
        {'nivel': '2', 'obtenido_en': 'c'},
      ]);
      expect(r?['nivel'], '3');
    });

    test('masRestrictiva de lista vacía es null (sin dato -> rojo por regla 1)', () {
      expect(SupabaseApi.masRestrictiva([]), isNull);
    });
  });

  group('Vigencia de reglas estacionales (#30)', () {
    final hoy = DateTime(2026, 7, 9);

    test('enVigencia: null siempre; dentro sí; fuera no', () {
      expect(enVigencia(null, hoy), isTrue);
      expect(enVigencia('[2026-06-01,2026-10-16)', hoy), isTrue);
      expect(enVigencia('[2020-06-01,2020-10-16)', hoy), isFalse);
      // alto exclusivo: el 16-10 ya queda fuera
      expect(enVigencia('[2026-01-01,2026-07-09)', hoy), isFalse);
      expect(enVigencia('[2026-07-09,2026-08-01)', hoy), isTrue);
    });

    test('Regla fuera de vigencia se descarta (no genera aviso)', () async {
      final api = _FakeApi([_reglaLimita('Aviso de temporada', '[2020-01-01,2020-02-01)')]);
      final r = await evaluar(api, 'setas', 39.98, -0.05);
      expect(r.avisos, isEmpty);
    });

    test('Regla dentro de vigencia se aplica', () async {
      final api = _FakeApi([_reglaLimita('Aviso de temporada', '[2000-01-01,2100-01-01)')]);
      final r = await evaluar(api, 'setas', 39.98, -0.05);
      expect(r.avisos.map((a) => a.texto), contains('Aviso de temporada'));
    });
  });

  group('Ventana de peligro de incendios (#31)', () {
    final invierno = DateTime(2026, 1, 15);
    final verano = DateTime(2026, 8, 1);

    test('enVentanaPeligro: bordes 1-jun y 15-oct inclusive', () {
      expect(enVentanaPeligro(DateTime(2026, 6, 1)), isTrue);
      expect(enVentanaPeligro(DateTime(2026, 10, 15)), isTrue);
      expect(enVentanaPeligro(DateTime(2026, 10, 16)), isFalse);
      expect(enVentanaPeligro(invierno), isFalse);
    });

    test('Quema en invierno sin boletín NO es rojo (fuera de la ventana)', () async {
      final api = _FakeApi([]);
      final r = await evaluar(api, 'quema', 39.98, -0.05, ahora: invierno);
      expect(r.semaforo, isNot('rojo'));
    });

    test('Quema en verano sin boletín sigue siendo rojo', () async {
      final api = _FakeApi([]);
      final r = await evaluar(api, 'quema', 39.98, -0.05, ahora: verano);
      expect(r.semaforo, 'rojo');
    });

    test('Fuego recreativo depende del boletín todo el año', () async {
      final api = _FakeApi([]);
      final r = await evaluar(api, 'fuego_recreativo', 39.98, -0.05, ahora: invierno);
      expect(r.semaforo, 'rojo');
    });
  });
}
