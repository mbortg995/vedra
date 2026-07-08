// Modelos tipados de la cartera de licencias. La conversión desde JSON vive
// aquí (capa de datos), y la UI solo lee campos: evita el acceso dinámico a
// mapas en el árbol de widgets (gotcha dart2js).

/// Tipo de requisito del catálogo (el mismo que exigen las reglas). Es lo que el
/// usuario puede declarar tener.
class TipoRequisito {
  final String id;
  final String slug;
  final String nombre;
  final String? urlTramite;
  const TipoRequisito({
    required this.id,
    required this.slug,
    required this.nombre,
    this.urlTramite,
  });

  factory TipoRequisito.desdeJson(Map<String, dynamic> j) => TipoRequisito(
        id: j['id'] as String,
        slug: j['slug'] as String,
        nombre: j['nombre'] as String,
        urlTramite: j['url_tramite'] as String?,
      );
}

/// Una licencia que el usuario declara tener, con su vencimiento opcional.
class Licencia {
  final String id;
  final String tipoRequisitoId;
  final String tipoNombre;
  final DateTime? vence;
  const Licencia({
    required this.id,
    required this.tipoRequisitoId,
    required this.tipoNombre,
    this.vence,
  });

  factory Licencia.desdeJson(Map<String, dynamic> j) {
    final tipo = j['tipos_requisito'] as Map<String, dynamic>?;
    final venceRaw = j['vence'] as String?;
    return Licencia(
      id: j['id'] as String,
      tipoRequisitoId: j['tipo_requisito_id'] as String,
      tipoNombre: tipo?['nombre'] as String? ?? 'Licencia',
      vence: venceRaw != null ? DateTime.parse(venceRaw) : null,
    );
  }
}

/// Estado de vencimiento para el aviso de caducidad.
enum EstadoVencimiento { sinFecha, vigente, caducaPronto, caducada }

/// Umbral de "caduca pronto": 30 días o menos (para el aviso in-app).
const int diasAvisoCaducidad = 30;

/// Clasifica el vencimiento comparando solo fechas (sin horas). `hoy` se inyecta
/// en los tests; por defecto, la fecha actual.
EstadoVencimiento estadoVencimiento(DateTime? vence, {DateTime? hoy}) {
  if (vence == null) return EstadoVencimiento.sinFecha;
  final ahora = hoy ?? DateTime.now();
  final h = DateTime(ahora.year, ahora.month, ahora.day);
  final v = DateTime(vence.year, vence.month, vence.day);
  final dias = v.difference(h).inDays;
  if (dias < 0) return EstadoVencimiento.caducada;
  if (dias <= diasAvisoCaducidad) return EstadoVencimiento.caducaPronto;
  return EstadoVencimiento.vigente;
}

/// Días que faltan para el vencimiento (negativo si ya caducó; null sin fecha).
int? diasHastaVencimiento(DateTime? vence, {DateTime? hoy}) {
  if (vence == null) return null;
  final ahora = hoy ?? DateTime.now();
  final h = DateTime(ahora.year, ahora.month, ahora.day);
  final v = DateTime(vence.year, vence.month, vence.day);
  return v.difference(h).inDays;
}
