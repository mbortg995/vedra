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

  /// Condición diaria (preemergencia) del territorio de mayor nivel que la tenga.
  Future<Map<String, dynamic>?> condicionDiaria(
      List<String> territorioIds, String fechaIso) async {
    if (territorioIds.isEmpty) return null;
    final ids = territorioIds.join(',');
    final rows = await _get('condiciones_diarias?territorio_id=in.($ids)'
        '&fecha=eq.$fechaIso&tipo=eq.preemergencia_incendios'
        '&select=territorio_id,nivel,obtenido_en,fuente_url');
    for (final tid in territorioIds) {
      final m = rows.where((r) => r['territorio_id'] == tid);
      if (m.isNotEmpty) return m.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _get(String path) async =>
      _lista(await http.get(_u(path), headers: _headers));

  List<Map<String, dynamic>> _lista(http.Response r) {
    if (r.statusCode >= 400) {
      throw Exception('Supabase ${r.statusCode}: ${r.body}');
    }
    return (jsonDecode(r.body) as List).cast<Map<String, dynamic>>();
  }
}
