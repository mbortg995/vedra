import 'supabase_api.dart';

/// Port de la lógica del semáforo (motor.py). MISMO contrato: orden estricto,
/// ante la duda rojo. NOTA: en el diseño final esta lógica vive en una Edge
/// Function de Supabase (cacheable en CDN); aquí, de forma interina, se ejecuta
/// en el cliente sobre los mismos datos.
const _dependeDeDia = {'fuego_recreativo', 'quema'};
const _afectadasPreemergencia3 = {'fuego_recreativo', 'acampada', 'setas', 'quema'};
const _frescuraMax = Duration(hours: 30);

class Resultado {
  String semaforo = 'verde';
  String titulo = '';
  List<Map<String, dynamic>> territorios = [];
  List<String> avisos = [];
  List<Map<String, dynamic>> bloqueos = [];
  List<Map<String, dynamic>> requisitos = [];
  Map<String, dynamic>? condicion;
  bool condicionFresca = false;
  final disclaimer =
      'Información orientativa. Consulta siempre la fuente oficial antes de actuar.';
}

Future<Resultado> evaluar(
    SupabaseApi api, String actividad, double lat, double lon) async {
  final now = DateTime.now();
  final fechaIso =
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final r = Resultado();

  final cadena = await api.territoriosEnPunto(lat, lon);
  r.territorios = cadena;
  final ids = cadena.map((t) => t['id'] as String).toList();

  final condicion = await api.condicionDiaria(ids, fechaIso);
  r.condicion = condicion;
  if (condicion != null) {
    final obtenido = DateTime.parse(condicion['obtenido_en']).toUtc();
    r.condicionFresca = DateTime.now().toUtc().difference(obtenido) <= _frescuraMax;
  }

  // REGLA 1: dato diario ausente/caduco en actividad que lo requiere -> rojo.
  if (_dependeDeDia.contains(actividad) &&
      (condicion == null || !r.condicionFresca)) {
    r.semaforo = 'rojo';
    r.titulo = 'No podemos confirmarlo — trátalo como prohibido';
    r.avisos.add(
        'No hay dato oficial de preemergencia fresco para hoy. Por seguridad, no lo hagas.');
    return r;
  }

  // REGLA 2: preemergencia 3 sobre actividades afectadas -> rojo.
  if (condicion != null &&
      condicion['nivel'] == '3' &&
      _afectadasPreemergencia3.contains(actividad)) {
    r.semaforo = 'rojo';
    r.titulo = 'Prohibido hoy por nivel de preemergencia 3';
    r.bloqueos.add({
      'detalle': 'Medidas extraordinarias de obligado cumplimiento en terreno forestal.',
    });
    return r;
  }

  // Reglas publicadas aplicables.
  for (final regla in await api.reglas(actividad, ids)) {
    final efecto = regla['efecto'];
    final p = (regla['parametros'] as Map?) ?? {};
    final detalle = regla['detalle'] ?? '';
    if (efecto == 'prohibe') {
      r.bloqueos.add({'detalle': detalle, 'fuente': regla['fuentes']});
    } else if (efecto == 'requiere') {
      r.requisitos.add({'detalle': detalle, 'cumplido': false, 'fuente': regla['fuentes']});
    } else if (efecto == 'limita') {
      if (p.containsKey('solo_si_preemergencia') && condicion != null) {
        if (condicion['nivel'] != p['solo_si_preemergencia']) {
          r.bloqueos.add({
            'detalle':
                'Solo permitido con preemergencia ${p['solo_si_preemergencia']} (hoy: nivel ${condicion['nivel']}).',
            'fuente': regla['fuentes'],
          });
        } else if (detalle.isNotEmpty) {
          r.avisos.add(detalle);
        }
      } else if (detalle.isNotEmpty) {
        r.avisos.add(detalle);
      }
    }
  }

  if (r.bloqueos.isNotEmpty) {
    r.semaforo = 'rojo';
    r.titulo = 'Hoy no puedes aquí';
  } else if (r.requisitos.any((req) => req['cumplido'] == false)) {
    r.semaforo = 'amarillo';
    r.titulo = 'Puedes, pero te falta algo o inicia sesión';
  } else {
    r.semaforo = 'verde';
    r.titulo = 'Adelante — cumples todo';
  }
  return r;
}
