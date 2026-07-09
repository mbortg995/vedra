import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Acceso de solo lectura a Supabase (PostgREST + RPC) con la clave anon.
/// La RLS garantiza que solo llegan reglas publicadas.
class SupabaseApi {
  Map<String, String> get _headers => {
        'apikey': Config.supabaseAnonKey,
        'Authorization': 'Bearer ${Config.supabaseAnonKey}',
        'Content-Type': 'application/json',
      };

  Uri _u(String path) => Uri.parse('${Config.supabaseUrl}/rest/v1/$path');

  /// Cadena de territorios (mayor a menor) que contienen el punto.
  Future<List<Map<String, dynamic>>> territoriosEnPunto(double lat, double lon) async {
    final r = await http.post(_u('rpc/territorios_en_punto'),
        headers: _headers, body: jsonEncode({'lat': lat, 'lon': lon}));
    return _lista(r);
  }

  /// Reglas PUBLICADAS de una actividad en unos territorios (RLS filtra).
  Future<List<Map<String, dynamic>>> reglas(
      String actividadSlug, List<String> territorioIds) async {
    final act = await _get('actividades?slug=eq.$actividadSlug&select=id');
    if (act.isEmpty || territorioIds.isEmpty) return [];
    final aid = act.first['id'];
    final ids = territorioIds.join(',');
    return _get('reglas?actividad_id=eq.$aid&territorio_id=in.($ids)'
        '&select=territorio_id,capa,efecto,parametros,detalle,'
        'fuentes(organismo,url,fecha_publicacion),'
        'regla_requisitos(tipo_requisito_id)');
  }

  /// Nivel de preemergencia del día, de forma CONSERVADORA (interino, #18):
  /// devuelve la condición MÁS RESTRICTIVA (nivel más alto) entre TODAS las zonas
  /// del CCAA del punto, no la de su zona concreta.
  ///
  /// Mientras la geometría de las 7 zonas Previfoc sea provisional (bandas), un
  /// punto puede caer en la zona equivocada; tomar el máximo del CCAA garantiza
  /// que nunca recibe MENOS restricción de la real (regla de oro). Basta con que
  /// el punto caiga en el CCAA (geometría IGN oficial), así que las bandas dejan
  /// de influir en el nivel. Con la geometría oficial se volverá al nivel por
  /// zona exacta.
  Future<Map<String, dynamic>?> condicionDiaria(
      List<Map<String, dynamic>> cadena, String fechaIso) async {
    final ccaa = cadena.where((t) => t['nivel'] == 'ccaa');
    if (ccaa.isEmpty) return null; // punto fuera de un CCAA cubierto
    final ccaaId = ccaa.first['id'];
    final rows = await _get(
        'condiciones_diarias?fecha=eq.$fechaIso&tipo=eq.preemergencia_incendios'
        '&select=nivel,obtenido_en,fuente_url,territorios!inner(padre_id)'
        '&territorios.padre_id=eq.$ccaaId');
    return masRestrictiva(rows);
  }

  /// De varias condiciones diarias, la más restrictiva (mayor nivel). La frescura
  /// se juzga después sobre la devuelta. Público (static) para poder testearlo.
  static Map<String, dynamic>? masRestrictiva(List<Map<String, dynamic>> filas) {
    if (filas.isEmpty) return null;
    final orden = [...filas]
      ..sort((a, b) => _nivelInt(b['nivel']).compareTo(_nivelInt(a['nivel'])));
    return orden.first;
  }

  static int _nivelInt(dynamic n) => int.tryParse('$n') ?? 0;

  Future<List<Map<String, dynamic>>> _get(String path) async =>
      _lista(await http.get(_u(path), headers: _headers));

  List<Map<String, dynamic>> _lista(http.Response r) {
    if (r.statusCode >= 400) {
      throw Exception('Supabase ${r.statusCode}: ${r.body}');
    }
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }
}
